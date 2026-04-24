defmodule OGrupoDeEstudos.Suggestions.SuggestionQuery do
  import Ecto.Query

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Suggestions.Suggestion

  def list_by(opts \\ []) do
    Suggestion
    |> apply_filters(opts)
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
    |> maybe_preload(Keyword.get(opts, :preload, []))
  end

  def count_by(opts \\ []) do
    Suggestion
    |> apply_filters(opts)
    |> Repo.aggregate(:count)
  end

  def get(id) do
    Repo.get(Suggestion, id)
    |> Repo.preload([:user, :reviewed_by])
  end

  defp apply_filters(query, opts) do
    Enum.reduce(opts, query, &apply_filter/2)
  end

  defp apply_filter({:status, status}, query),
    do: where(query, [s], s.status == ^status)

  defp apply_filter({:user_id, id}, query),
    do: where(query, [s], s.user_id == ^id)

  defp apply_filter({:target_type, type}, query),
    do: where(query, [s], s.target_type == ^type)

  defp apply_filter({:action, action}, query),
    do: where(query, [s], s.action == ^action)

  defp apply_filter({:target_id, id}, query),
    do: where(query, [s], s.target_id == ^id)

  defp apply_filter({:limit, n}, query),
    do: limit(query, ^n)

  defp apply_filter(_other, query), do: query

  defp maybe_preload(results, []), do: results
  defp maybe_preload(results, preloads) when is_list(results), do: Repo.preload(results, preloads)
  defp maybe_preload(nil, _), do: nil
  defp maybe_preload(result, preloads), do: Repo.preload(result, preloads)
end
