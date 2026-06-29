defmodule OGrupoDeEstudosWeb.GraphVisual.StudyJourney do
  @moduledoc """
  Funções puras da jornada de estudos progressiva sobre o grafo dirigido de
  passos. Sem Repo/socket/IO: só matemática de conjuntos sobre códigos.

  Direção das arestas: `{origem, destino}` significa "sabendo `origem`,
  `destino` fica acessível" (mesma semântica do Validator/Generator). Logo a
  fronteira ("pode aprender agora") são os destinos não-aprendidos de arestas
  que saem de passos já aprendidos.
  """

  @type code :: String.t()
  @type edge :: {code, code}

  @doc "Fronteira: destinos não-aprendidos de arestas que saem de passos aprendidos."
  @spec frontier(MapSet.t(code), [edge]) :: MapSet.t(code)
  def frontier(learned, edges) do
    for {from, to} <- edges,
        MapSet.member?(learned, from),
        not MapSet.member?(learned, to),
        into: MapSet.new(),
        do: to
  end

  @doc """
  Classifica uma aresta para o disclosure progressivo: `:learned`
  (aprendido→aprendido), `:frontier` (aprendido→não-aprendido) ou `:hidden`
  (origem ainda não aprendida).
  """
  @spec edge_state(MapSet.t(code), edge) :: :learned | :frontier | :hidden
  def edge_state(learned, {from, to}) do
    cond do
      not MapSet.member?(learned, from) -> :hidden
      MapSet.member?(learned, to) -> :learned
      true -> :frontier
    end
  end

  @doc "Códigos visíveis no modo progresso: união de aprendidos e fronteira."
  @spec visible_codes(MapSet.t(code), MapSet.t(code)) :: MapSet.t(code)
  def visible_codes(learned, frontier), do: MapSet.union(learned, frontier)

  @doc "Próxima meta: primeiro passo do plano-base ainda não aprendido (ou nil)."
  @spec next_goal([code], MapSet.t(code)) :: code | nil
  def next_goal(base_plan, learned) do
    Enum.find(base_plan, fn code -> not MapSet.member?(learned, code) end)
  end
end
