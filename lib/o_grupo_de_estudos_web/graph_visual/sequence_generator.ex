defmodule OGrupoDeEstudosWeb.GraphVisual.SequenceGenerator do
  @moduledoc """
  Helpers puros do gerador automático de sequências: resolução do passo inicial
  digitado para um código e mapeamento do modo de loop para o limite de
  repetições do mesmo par.
  """

  alias OGrupoDeEstudosWeb.GraphVisual.TextSearch

  @doc """
  Resolve uma query digitada (código, "CÓDIGO · nome" ou nome) para um código de
  passo, casando contra os nós visíveis `steps`; cai no `fallback` se não casar.
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
