defmodule OGrupoDeEstudosWeb.GraphVisual.StudyJourney do
  @moduledoc """
  Pure functions of the progressive study journey over the directed step graph.
  No Repo, socket or IO: only set math over codes.
  """

  @type code :: String.t()
  @type edge :: {code, code}

  @doc "Frontier: unlearned targets of edges leaving learned steps."
  @spec frontier(MapSet.t(code), [edge]) :: MapSet.t(code)
  def frontier(learned, edges) do
    for {from, to} <- edges,
        MapSet.member?(learned, from),
        not MapSet.member?(learned, to),
        into: MapSet.new(),
        do: to
  end

  @doc """
  Classifies an edge for the progressive disclosure: `:learned`
  (learned to learned), `:frontier` (learned to unlearned) or `:hidden`
  (everything else).
  """
  @spec edge_state(MapSet.t(code), edge) :: :learned | :frontier | :hidden
  def edge_state(learned, {from, to}) do
    cond do
      not MapSet.member?(learned, from) -> :hidden
      MapSet.member?(learned, to) -> :learned
      true -> :frontier
    end
  end

  @doc "Codes visible in progress mode: the union of learned and frontier."
  @spec visible_codes(MapSet.t(code), MapSet.t(code)) :: MapSet.t(code)
  def visible_codes(learned, frontier), do: MapSet.union(learned, frontier)

  @doc "Next goal: first step of the base plan not learned yet (or nil)."
  @spec next_goal([code], MapSet.t(code)) :: code | nil
  def next_goal(base_plan, learned) do
    Enum.find(base_plan, fn code -> not MapSet.member?(learned, code) end)
  end

  @doc """
  Orders the "can learn now" suggestions putting the base plan steps first (in
  pedagogical order) and caps the list. Takes the nodes (maps with code and name)
  and returns the same shape.
  """
  @spec rank_suggestions([%{code: code}], [code], pos_integer) :: [%{code: code}]
  def rank_suggestions(nodes, base_plan, limit) do
    order = base_plan |> Enum.with_index() |> Map.new()

    nodes
    |> Enum.sort_by(&Map.get(order, &1.code, length(base_plan)))
    |> Enum.take(limit)
  end

  @doc """
  Primary goal of the displayed list: the first code (in list order, already
  ranked) that belongs to the base plan. Derived from the visible list itself.
  """
  @spec primary_goal([code], [code]) :: code | nil
  def primary_goal(codes, base_plan) do
    base = MapSet.new(base_plan)
    Enum.find(codes, &MapSet.member?(base, &1))
  end
end
