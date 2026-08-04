defmodule OGrupoDeEstudosWeb.GraphVisual.SequenceGenerator do
  @moduledoc """
  Pure helpers of the automatic sequence generator: resolving the typed starting
  step into a code, and mapping the loop mode to its limit.
  """

  alias OGrupoDeEstudosWeb.GraphVisual.TextSearch

  @doc """
  Resolves a typed query (code, "CODE · name" or name) into a step code, matching
  against the visible `steps` nodes; falls back to `fallback` when nothing matches.
  """
  def resolve_step_code(query, steps, fallback) do
    query = String.trim(to_string(query || ""))
    fallback = String.trim(to_string(fallback || ""))
    prefix = query |> String.split("·", parts: 2) |> List.first() |> String.trim()
    normalized_query = TextSearch.normalize(query)

    cond do
      query == "" ->
        fallback

      step_code?(steps, prefix) ->
        prefix

      match = Enum.find(steps, &(TextSearch.normalize(&1.code) == normalized_query)) ->
        match.code

      match = Enum.find(steps, &(TextSearch.normalize(&1.name) == normalized_query)) ->
        match.code

      true ->
        fallback
    end
  end

  defp step_code?(steps, code), do: Enum.any?(steps, &(&1.code == code))
end
