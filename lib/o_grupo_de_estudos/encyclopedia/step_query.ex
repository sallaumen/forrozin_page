defmodule OGrupoDeEstudos.Encyclopedia.StepQuery do
  @moduledoc """
  Query module for the Step schema.

  Provides `get_by/1` and `list_by/1` as the public API, both backed by the
  shared_reducer/2 pattern so every filter is defined once and reused.
  """

  import Ecto.Query

  alias OGrupoDeEstudos.Encyclopedia.Step
  alias OGrupoDeEstudos.Repo

  @type list_opt ::
          {:include_deleted, boolean()}
          | {:id, Ecto.UUID.t()}
          | {:code, String.t()}
          | {:status, String.t()}
          | {:wip, boolean()}
          | {:public_only, boolean()}
          | {:section_id, Ecto.UUID.t()}
          | {:subsection_nil, boolean()}
          | {:suggested_by_id, Ecto.UUID.t()}
          | {:has_suggestions, boolean()}
          | {:approved_only, boolean()}
          | {:pending_only, boolean()}
          | {:step_ids, [Ecto.UUID.t()]}
          | {:search, String.t()}
          | {:order_by, Keyword.t()}
          | {:preload, term()}
          | {:limit, non_neg_integer()}
  @type opts :: [list_opt()]

  @doc "Returns the first step matching `opts`, or `nil`."
  @spec get_by(opts()) :: Step.t() | nil
  def get_by(opts) do
    opts
    |> Keyword.put_new(:include_deleted, false)
    |> Enum.reduce(default_scope(), &shared_reducer/2)
    |> Repo.one()
  end

  @doc "Returns all steps matching `opts`, ordered by name by default."
  @spec list_by(opts()) :: [Step.t()]
  def list_by(opts \\ []) do
    opts
    |> Keyword.put_new(:include_deleted, false)
    |> Keyword.put_new(:order_by, asc: :name)
    |> Enum.reduce(default_scope(), &shared_reducer/2)
    |> Repo.all()
  end

  @doc "Counts steps matching `opts`."
  @spec count_by(opts()) :: non_neg_integer()
  def count_by(opts \\ []) do
    opts
    |> Keyword.put_new(:include_deleted, false)
    |> Enum.reduce(default_scope(), &shared_reducer/2)
    |> Repo.aggregate(:count)
  end

  @doc "Returns `%{id => %{code: code, name: name}}` for the given step ids."
  @spec summaries_by_ids([Ecto.UUID.t()]) :: %{
          Ecto.UUID.t() => %{code: String.t(), name: String.t()}
        }
  def summaries_by_ids([]), do: %{}

  def summaries_by_ids(ids) when is_list(ids) do
    from(s in Step,
      where: s.id in ^ids and is_nil(s.deleted_at),
      select: {s.id, %{code: s.code, name: s.name}}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc "Returns `%{id => %Step{}}` for the given ids (deleted excluded)."
  @spec map_by_ids([Ecto.UUID.t()]) :: %{Ecto.UUID.t() => Step.t()}
  def map_by_ids([]), do: %{}

  def map_by_ids(ids) when is_list(ids) do
    [step_ids: ids]
    |> list_by()
    |> Map.new(&{&1.id, &1})
  end

  @doc "Returns `%{user_id => count}` of non-deleted steps suggested by each user."
  @spec counts_by_suggester([Ecto.UUID.t()]) :: %{Ecto.UUID.t() => non_neg_integer()}
  def counts_by_suggester([]), do: %{}

  def counts_by_suggester(user_ids) when is_list(user_ids) do
    from(s in Step,
      where: s.suggested_by_id in ^user_ids and is_nil(s.deleted_at),
      group_by: s.suggested_by_id,
      select: {s.suggested_by_id, count(s.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  defp default_scope, do: from(s in Step, as: :step)

  defp shared_reducer({:include_deleted, true}, q), do: q
  defp shared_reducer({:include_deleted, false}, q), do: where(q, [step: s], is_nil(s.deleted_at))

  defp shared_reducer({:id, id}, q),
    do: where(q, [step: s], s.id == ^id)

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

  defp shared_reducer({:approved_only, true}, q),
    do: where(q, [step: s], s.approved == true)

  defp shared_reducer({:pending_only, true}, q),
    do: where(q, [step: s], s.approved == false)

  defp shared_reducer({:step_ids, ids}, q),
    do: where(q, [step: s], s.id in ^ids)

  defp shared_reducer({:search, term}, q) do
    term_like = "%#{OGrupoDeEstudos.Search.escape_like(String.downcase(term))}%"

    where(
      q,
      [step: s],
      fragment(
        "lower(?) LIKE ? OR lower(?) LIKE ?",
        s.code,
        ^term_like,
        s.name,
        ^term_like
      )
    )
  end

  defp shared_reducer({:order_by, ordering}, q), do: order_by(q, ^ordering)

  defp shared_reducer({:preload, preloads}, q), do: preload(q, ^preloads)

  defp shared_reducer({:limit, n}, q), do: limit(q, ^n)
end
