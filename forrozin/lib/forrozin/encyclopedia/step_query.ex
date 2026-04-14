defmodule Forrozin.Encyclopedia.StepQuery do
  @moduledoc """
  Query module for the Step schema.

  Provides `get_by/1` and `list_by/1` as the public API, both backed by the
  shared_reducer/2 pattern so every filter is defined once and reused.
  """

  import Ecto.Query

  alias Forrozin.Repo
  alias Forrozin.Encyclopedia.Step

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc "Returns the first step matching `opts`, or `nil`."
  def get_by(opts) do
    opts
    |> Enum.reduce(default_scope(), &shared_reducer/2)
    |> Repo.one()
  end

  @doc "Returns all steps matching `opts`, ordered by name by default."
  def list_by(opts \\ []) do
    opts
    |> Keyword.put_new(:order_by, asc: :name)
    |> Enum.reduce(default_scope(), &shared_reducer/2)
    |> Repo.all()
  end

  @doc "Counts steps matching `opts`."
  def count_by(opts \\ []) do
    opts
    |> Enum.reduce(default_scope(), &shared_reducer/2)
    |> Repo.aggregate(:count)
  end

  # ---------------------------------------------------------------------------
  # Base scope
  # ---------------------------------------------------------------------------

  defp default_scope, do: from(s in Step, as: :step)

  # ---------------------------------------------------------------------------
  # Shared reducer — one clause per filter
  # ---------------------------------------------------------------------------

  defp shared_reducer({:code, code}, q),
    do: where(q, [step: s], s.code == ^code)

  defp shared_reducer({:status, status}, q),
    do: where(q, [step: s], s.status == ^status)

  defp shared_reducer({:wip, wip}, q),
    do: where(q, [step: s], s.wip == ^wip)

  defp shared_reducer({:public_only, true}, q),
    do: where(q, [step: s], s.wip == false and s.status == "published")

  defp shared_reducer({:section_id, id}, q),
    do: where(q, [step: s], s.section_id == ^id)

  defp shared_reducer({:subsection_nil, true}, q),
    do: where(q, [step: s], is_nil(s.subsection_id))

  defp shared_reducer({:suggested_by_id, id}, q),
    do: where(q, [step: s], s.suggested_by_id == ^id)

  defp shared_reducer({:has_suggestions, true}, q),
    do: where(q, [step: s], not is_nil(s.suggested_by_id))

  defp shared_reducer({:step_ids, ids}, q),
    do: where(q, [step: s], s.id in ^ids)

  defp shared_reducer({:search, term}, q) do
    term_lower = String.downcase(term)

    where(
      q,
      [step: s],
      fragment(
        "lower(?) LIKE ? OR lower(?) LIKE ?",
        s.code,
        ^"%#{term_lower}%",
        s.name,
        ^"%#{term_lower}%"
      )
    )
  end

  defp shared_reducer({:order_by, ordering}, q), do: order_by(q, ^ordering)

  defp shared_reducer({:preload, preloads}, q), do: preload(q, ^preloads)

  defp shared_reducer({:limit, n}, q), do: limit(q, ^n)
end
