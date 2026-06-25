defmodule OGrupoDeEstudosWeb.GraphVisual.SequenceLibrary do
  @moduledoc """
  Pure filtering and ranking for the sequence-library panel of `GraphVisualLive`.

  Decides which saved/community sequences show and in what order: origin
  (`"favorites"`/`"community"`/anything-else), accent-insensitive text search
  across name/description/author/steps, and category filtering; plus the
  owned > favorite ranking and recency sort keys.

  Operates on already-preloaded `Sequence` structs. Association reads are guarded
  by `Ecto.assoc_loaded?/1` (pure in-memory checks, never a DB load), so the
  module touches no Repo and no socket.
  """

  alias OGrupoDeEstudosWeb.GraphVisual.TextSearch

  def sequence_library_rank(sequence, owned_ids, favorite_ids) do
    owned? = MapSet.member?(owned_ids, sequence.id)
    favorite? = MapSet.member?(favorite_ids, sequence.id)

    cond do
      owned? and favorite? -> 0
      owned? -> 1
      favorite? -> 2
      true -> 3
    end
  end

  def normalize_sequence_date(nil), do: 0

  def normalize_sequence_date(%NaiveDateTime{} = date),
    do: -NaiveDateTime.diff(date, ~N[1970-01-01 00:00:00])

  def filter_sequence_library(
        sequences,
        search,
        origin_filter,
        category_filter,
        owned_ids,
        favorite_ids
      ) do
    search = TextSearch.normalize(search)

    Enum.filter(sequences, fn sequence ->
      sequence_matches_origin_filter?(sequence, origin_filter, owned_ids, favorite_ids) and
        (search == "" or sequence_matches_search?(sequence, search)) and
        (category_filter == "all" or sequence_has_category?(sequence, category_filter))
    end)
  end

  def sequence_matches_origin_filter?(sequence, "favorites", _owned_ids, favorite_ids),
    do: MapSet.member?(favorite_ids, sequence.id)

  def sequence_matches_origin_filter?(sequence, "community", owned_ids, _favorite_ids),
    do: not MapSet.member?(owned_ids, sequence.id) and sequence.public

  def sequence_matches_origin_filter?(_sequence, _origin_filter, _owned_ids, _favorite_ids),
    do: true

  def sequence_matches_search?(sequence, search) do
    sequence_text =
      [
        sequence.name,
        sequence.description,
        if(Ecto.assoc_loaded?(sequence.user) && sequence.user,
          do: sequence.user.username,
          else: nil
        )
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" ")
      |> TextSearch.normalize()

    steps_text =
      sequence.sequence_steps
      |> Enum.map(fn sequence_step ->
        step = sequence_step.step
        category = if Ecto.assoc_loaded?(step.category), do: step.category, else: nil

        [
          step.code,
          step.name,
          if(category, do: category.name, else: nil),
          if(category, do: category.label, else: nil)
        ]
      end)
      |> List.flatten()
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" ")
      |> TextSearch.normalize()

    String.contains?(sequence_text, search) or String.contains?(steps_text, search)
  end

  def sequence_has_category?(sequence, category_filter) do
    Enum.any?(sequence.sequence_steps, fn sequence_step ->
      step = sequence_step.step
      Ecto.assoc_loaded?(step.category) && step.category && step.category.name == category_filter
    end)
  end
end
