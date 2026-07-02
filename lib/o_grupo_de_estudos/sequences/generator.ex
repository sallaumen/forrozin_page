defmodule OGrupoDeEstudos.Sequences.Generator do
  @moduledoc """
  Generates step sequences by traversing the directed connection graph.

  Orquestrador: monta o contexto do grafo (passos públicos, adjacências,
  alcançabilidade) e despacha para o algoritmo:

  - **`Generator.Waypoint`** (quando há required_codes): garante todos os
    obrigatórios via caminhos BFS entre waypoints, permutando a ordem.
  - **`Generator.Dfs`** (sem obrigatórios): DFS aleatorizada com
    backtracking, seleção ponderada de vizinhos e relaxamento progressivo.
  """

  alias OGrupoDeEstudos.Encyclopedia.{ConnectionQuery, StepQuery}
  alias OGrupoDeEstudos.Sequences.Generator.{Dfs, GraphTraversal, Warnings, Waypoint}
  alias OGrupoDeEstudos.Sequences.GeneratorError

  @type step_info :: %{id: String.t(), code: String.t(), name: String.t()}
  @type sequence :: [step_info()]
  @type result :: {:ok, [sequence()], [String.t()]} | {:error, GeneratorError.t()}

  @bf_code "BF"

  @spec generate(map()) :: result()
  def generate(params) do
    params = with_defaults(params)
    graph = load_graph()

    case Map.get(graph.code_to_id, params.start_code) do
      nil -> {:error, GeneratorError.start_step_not_found(params.start_code)}
      start_id -> generate_from(start_id, graph, params)
    end
  end

  defp with_defaults(params) do
    params
    |> Map.put_new(:cyclic, false)
    |> Map.put_new(:max_bf_visits, 3)
    |> Map.put_new(:max_same_pair_loops, 3)
  end

  # Load only public steps (board decision 2026-06-25): wip/draft steps are
  # restricted and must never appear in generated sequences. Visibility is
  # owned by StepQuery, so we reuse :public_only instead of re-checking here.
  defp load_graph do
    steps = StepQuery.list_by(public_only: true, preload: [:category])
    connections = ConnectionQuery.list_by(preload: [])

    %{
      step_map: Map.new(steps, &{&1.id, &1}),
      code_to_id: Map.new(steps, &{&1.code, &1.id}),
      adjacency: GraphTraversal.build_adjacency(connections),
      reverse_adjacency: GraphTraversal.build_reverse_adjacency(connections)
    }
  end

  defp generate_from(start_id, graph, params) do
    reachable = GraphTraversal.reachable_from(start_id, graph.adjacency)

    {required_ids, unresolved_codes} =
      resolve_required_ids(params.required_codes, graph.code_to_id)

    {reachable_required_ids, unreachable_codes} =
      split_reachable(required_ids, reachable, graph.step_map)

    ctx = build_ctx(start_id, graph, reachable, reachable_required_ids)
    input_warnings = input_warnings(unresolved_codes, unreachable_codes)

    run_mode(ctx, params, reachable_required_ids, required_ids, input_warnings)
  end

  defp split_reachable(required_ids, reachable, step_map) do
    {reachable_ids, unreachable_ids} =
      Enum.split_with(required_ids, &MapSet.member?(reachable, &1))

    unreachable_codes =
      unreachable_ids
      |> Enum.map(fn id -> step_map[id] && step_map[id].code end)
      |> Enum.reject(&is_nil/1)

    {reachable_ids, unreachable_codes}
  end

  defp build_ctx(start_id, graph, reachable, reachable_required_ids) do
    %{
      start_id: start_id,
      adjacency: graph.adjacency,
      step_map: graph.step_map,
      required_ids: MapSet.new(reachable_required_ids),
      bf_id: Map.get(graph.code_to_id, @bf_code),
      dist_to_start: GraphTraversal.bfs_distances(start_id, graph.reverse_adjacency),
      reachable: reachable
    }
  end

  defp input_warnings(unresolved_codes, unreachable_codes) do
    Warnings.unresolved_warnings(unresolved_codes) ++
      Warnings.unreachable_warnings(unreachable_codes)
  end

  defp run_mode(ctx, params, [], required_ids, input_warnings) do
    {sequences, relaxation_warnings} = Dfs.generate_with_relaxation(ctx, params)

    warnings =
      Warnings.dfs_warnings(sequences, required_ids, ctx.step_map, params) ++
        input_warnings ++ relaxation_warnings

    {:ok, sequences, warnings}
  end

  defp run_mode(ctx, params, reachable_required_ids, _required_ids, input_warnings) do
    {sequences, waypoint_warnings} = Waypoint.generate(ctx, params, reachable_required_ids)

    {:ok, sequences, waypoint_warnings ++ input_warnings}
  end

  defp resolve_required_ids(nil, _code_to_id), do: {[], []}
  defp resolve_required_ids([], _code_to_id), do: {[], []}

  defp resolve_required_ids(codes, code_to_id) do
    {resolved, unresolved} = Enum.split_with(codes, &Map.has_key?(code_to_id, &1))
    {Enum.map(resolved, &Map.fetch!(code_to_id, &1)), unresolved}
  end
end
