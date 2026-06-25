defmodule OGrupoDeEstudos.Sequences.Generator.GraphTraversal do
  @moduledoc """
  Pure graph-traversal helpers over the directed step-connection graph.

  Operates on adjacency maps (`%{node_id => [neighbor_id]}`) built from a list
  of connections. No randomness except `bfs_path/3`, which shuffles neighbors
  for path variety. No I/O.
  """

  @type adjacency :: %{optional(any()) => [any()]}

  @doc "Builds a forward adjacency map (source -> [targets]) from connections."
  def build_adjacency(connections) do
    Enum.reduce(connections, %{}, fn conn, acc ->
      Map.update(acc, conn.source_step_id, [conn.target_step_id], &[conn.target_step_id | &1])
    end)
  end

  @doc "Builds a reverse adjacency map (target -> [sources]) from connections."
  def build_reverse_adjacency(connections) do
    Enum.reduce(connections, %{}, fn conn, acc ->
      Map.update(acc, conn.target_step_id, [conn.source_step_id], &[conn.source_step_id | &1])
    end)
  end

  @doc "Returns the set of nodes reachable from `start_id` (inclusive)."
  def reachable_from(start_id, adjacency) do
    do_bfs(MapSet.new([start_id]), [start_id], adjacency)
  end

  defp do_bfs(visited, [], _adjacency), do: visited

  defp do_bfs(visited, queue, adjacency) do
    next_queue =
      Enum.flat_map(queue, fn node ->
        Map.get(adjacency, node, [])
        |> Enum.reject(&MapSet.member?(visited, &1))
      end)

    new_visited = Enum.reduce(next_queue, visited, &MapSet.put(&2, &1))
    do_bfs(new_visited, Enum.uniq(next_queue), adjacency)
  end

  @doc "Returns a map of shortest hop distances from `start_id`."
  def bfs_distances(start_id, adjacency) do
    do_bfs_dist(%{start_id => 0}, [start_id], adjacency, 0)
  end

  defp do_bfs_dist(dists, [], _adj, _depth), do: dists

  defp do_bfs_dist(dists, queue, adj, depth) do
    next_queue =
      Enum.flat_map(queue, fn node ->
        Map.get(adj, node, [])
        |> Enum.reject(&Map.has_key?(dists, &1))
      end)
      |> Enum.uniq()

    new_dists =
      Enum.reduce(next_queue, dists, fn node, acc ->
        Map.put(acc, node, depth + 1)
      end)

    do_bfs_dist(new_dists, next_queue, adj, depth + 1)
  end

  @doc """
  Finds a path from `source` to `target`, shuffling neighbors for variety.

  Returns `{:ok, path}` or `:no_path`.
  """
  def bfs_path(source, target, _adj) when source == target, do: {:ok, [source]}

  def bfs_path(source, target, adjacency) do
    bfs_path_loop([source], MapSet.new([source]), %{}, target, adjacency)
  end

  defp bfs_path_loop([], _visited, _parents, _target, _adj), do: :no_path

  defp bfs_path_loop(queue, visited, parents, target, adj) do
    {next_queue, new_visited, new_parents} =
      Enum.reduce(queue, {[], visited, parents}, fn node, acc ->
        neighbors = Map.get(adj, node, []) |> Enum.shuffle()
        expand_neighbors(neighbors, node, acc)
      end)

    if MapSet.member?(new_visited, target) and not MapSet.member?(visited, target) do
      {:ok, trace_path(target, new_parents)}
    else
      bfs_path_loop(Enum.uniq(next_queue), new_visited, new_parents, target, adj)
    end
  end

  defp expand_neighbors(neighbors, node, acc) do
    Enum.reduce(neighbors, acc, fn n, {q, v, p} ->
      if MapSet.member?(v, n) do
        {q, v, p}
      else
        {[n | q], MapSet.put(v, n), Map.put(p, n, node)}
      end
    end)
  end

  defp trace_path(node, parents) do
    case Map.get(parents, node) do
      nil -> [node]
      parent -> trace_path(parent, parents) ++ [node]
    end
  end
end
