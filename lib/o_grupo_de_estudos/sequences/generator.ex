defmodule OGrupoDeEstudos.Sequences.Generator do
  @moduledoc """
  Generates step sequences by traversing the directed connection graph.

  Two algorithms:
  - **Waypoint mode** (when required_codes is non-empty): guarantees all
    required steps appear by finding BFS paths between consecutive waypoints.
    Permutes waypoint order across sequences for variety.
  - **DFS mode** (no required steps): randomized DFS with backtracking,
    weighted neighbor selection, and progressive constraint relaxation.
  """

  alias OGrupoDeEstudos.Encyclopedia.{ConnectionQuery, StepQuery}

  @type step_info :: %{id: String.t(), code: String.t(), name: String.t()}
  @type sequence :: [step_info()]
  @type result :: {:ok, [sequence()], [String.t()]}

  @max_attempts 50
  @max_same_pair_loops 3
  @bf_code "BF"

  # Weight constants (DFS mode)
  @weight_base 1.0
  @weight_highlighted 2.0
  @weight_required 4.0
  @weight_category_mix 1.5
  @weight_cyclic_close 6.0
  @weight_noise_max 1.5
  @penalty_used_edge 2.0

  @spec generate(map()) :: result()
  def generate(params) do
    params =
      params
      |> Map.put_new(:cyclic, false)
      |> Map.put_new(:max_bf_visits, 3)
      |> Map.put_new(:max_same_pair_loops, @max_same_pair_loops)

    # Load all steps with connections (no public_only filter)
    steps = StepQuery.list_by(preload: [:category])
    connections = ConnectionQuery.list_by(preload: [])

    step_map = Map.new(steps, &{&1.id, &1})
    code_to_id = Map.new(steps, &{&1.code, &1.id})
    adjacency = build_adjacency(connections)

    start_id = Map.get(code_to_id, params.start_code)

    {required_ids, unresolved_codes} =
      resolve_required_ids(params.required_codes, code_to_id)

    if is_nil(start_id) do
      {:ok, [], ["Passo inicial '#{params.start_code}' não encontrado"]}
    else
      reachable = reachable_from(start_id, adjacency)

      {reachable_required_ids, unreachable_ids} =
        Enum.split_with(required_ids, &MapSet.member?(reachable, &1))

      unreachable_codes =
        unreachable_ids
        |> Enum.map(fn id -> step_map[id] && step_map[id].code end)
        |> Enum.reject(&is_nil/1)

      reverse_adj = build_reverse_adjacency(connections)
      dist_to_start = bfs_distances(start_id, reverse_adj)

      ctx = %{
        start_id: start_id,
        adjacency: adjacency,
        step_map: step_map,
        required_ids: MapSet.new(reachable_required_ids),
        bf_id: Map.get(code_to_id, @bf_code),
        dist_to_start: dist_to_start,
        reachable: reachable
      }

      if reachable_required_ids != [] do
        {sequences, waypoint_warnings} =
          generate_waypoint_sequences(ctx, params, reachable_required_ids)

        warnings =
          waypoint_warnings ++
            unresolved_warnings(unresolved_codes) ++
            unreachable_warnings(unreachable_codes)

        {:ok, sequences, warnings}
      else
        {sequences, relaxation_warnings} =
          generate_with_relaxation(ctx, params)

        warnings =
          build_dfs_warnings(sequences, required_ids, step_map, params) ++
            unresolved_warnings(unresolved_codes) ++
            unreachable_warnings(unreachable_codes) ++
            relaxation_warnings

        {:ok, sequences, warnings}
      end
    end
  end

  # ── Waypoint-based generation ────────────────────────────────────────

  defp generate_waypoint_sequences(ctx, params, required_ids) do
    perms = shuffled_permutations(required_ids, params.count)

    {sequences, path_warnings} =
      Enum.reduce(perms, {[], []}, fn perm, {seqs, warns} ->
        waypoints = waypoint_list(ctx.start_id, perm, params.cyclic)

        case connect_waypoints(waypoints, ctx.adjacency) do
          {:ok, base_path} ->
            # Pad with random walk if under target length
            path = pad_path(base_path, params.length, ctx)
            formatted = format_path_forward(path, ctx.step_map)
            {[formatted | seqs], warns}

          {:error, from_id, to_id} ->
            from_code = code_for(ctx.step_map, from_id)
            to_code = code_for(ctx.step_map, to_id)
            {seqs, ["Não existe caminho de #{from_code} para #{to_code} no grafo" | warns]}
        end
      end)

    sequences =
      sequences
      |> Enum.reverse()
      |> Enum.uniq_by(fn seq -> Enum.map(seq, & &1.id) end)
      |> Enum.take(params.count)

    warnings =
      Enum.uniq(path_warnings) ++
        length_warnings(sequences, params.length) ++
        count_warnings(sequences, params.count)

    {sequences, warnings}
  end

  defp waypoint_list(start_id, required_ids, true = _cyclic) do
    [start_id | required_ids] ++ [start_id]
  end

  defp waypoint_list(start_id, required_ids, false) do
    [start_id | required_ids]
  end

  defp connect_waypoints(waypoints, adjacency) do
    segments = Enum.chunk_every(waypoints, 2, 1, :discard)

    Enum.reduce_while(segments, {:ok, []}, fn [from, to], {:ok, acc} ->
      case bfs_path(from, to, adjacency) do
        {:ok, path} ->
          trimmed = if acc == [], do: path, else: tl(path)
          {:cont, {:ok, acc ++ trimmed}}

        :no_path ->
          {:halt, {:error, from, to}}
      end
    end)
  end

  # Extends path to target_length by random walk from the last node.
  # Allows revisiting nodes (except immediate backtrack) to explore the graph.
  defp pad_path(path, target_length, _ctx) when length(path) >= target_length, do: path

  defp pad_path(path, target_length, ctx) do
    remaining = target_length - length(path)
    visited = MapSet.new(path)

    do_pad(Enum.reverse(path), remaining, visited, ctx)
    |> Enum.reverse()
  end

  # path is reversed here: [last_added, ..., first]
  defp do_pad(path, 0, _visited, _ctx), do: path

  defp do_pad([current | _] = path, remaining, visited, ctx) do
    neighbors =
      Map.get(ctx.adjacency, current, [])
      |> Enum.filter(&MapSet.member?(ctx.reachable, &1))

    # Prefer unvisited neighbors, but allow revisits if needed
    unvisited = Enum.reject(neighbors, &MapSet.member?(visited, &1))
    candidates = if unvisited != [], do: unvisited, else: neighbors

    case candidates do
      [] ->
        # Dead end — return what we have
        path

      _ ->
        next = Enum.random(candidates)

        do_pad(
          [next | path],
          remaining - 1,
          MapSet.put(visited, next),
          ctx
        )
    end
  end

  defp code_for(step_map, id) do
    case Map.get(step_map, id) do
      nil -> "?"
      step -> step.code
    end
  end

  # ── BFS path finder (randomized for variety) ─────────────────────────

  defp bfs_path(source, target, _adj) when source == target, do: {:ok, [source]}

  defp bfs_path(source, target, adjacency) do
    bfs_path_loop([source], MapSet.new([source]), %{}, target, adjacency)
  end

  defp bfs_path_loop([], _visited, _parents, _target, _adj), do: :no_path

  defp bfs_path_loop(queue, visited, parents, target, adj) do
    {next_queue, new_visited, new_parents} =
      Enum.reduce(queue, {[], visited, parents}, fn node, {nq, vis, par} ->
        neighbors = Map.get(adj, node, []) |> Enum.shuffle()

        Enum.reduce(neighbors, {nq, vis, par}, fn n, {q, v, p} ->
          if MapSet.member?(v, n) do
            {q, v, p}
          else
            {[n | q], MapSet.put(v, n), Map.put(p, n, node)}
          end
        end)
      end)

    if MapSet.member?(new_visited, target) and not MapSet.member?(visited, target) do
      {:ok, trace_path(target, new_parents)}
    else
      bfs_path_loop(Enum.uniq(next_queue), new_visited, new_parents, target, adj)
    end
  end

  defp trace_path(node, parents) do
    case Map.get(parents, node) do
      nil -> [node]
      parent -> trace_path(parent, parents) ++ [node]
    end
  end

  # ── Permutation helpers ──────────────────────────────────────────────

  defp shuffled_permutations(list, count) when length(list) <= 6 do
    perms = all_permutations(list) |> Enum.shuffle()

    if length(perms) >= count do
      Enum.take(perms, count)
    else
      perms |> Stream.cycle() |> Enum.take(count)
    end
  end

  defp shuffled_permutations(list, count) do
    1..count |> Enum.map(fn _ -> Enum.shuffle(list) end)
  end

  defp all_permutations([]), do: [[]]

  defp all_permutations(list) do
    for elem <- list, rest <- all_permutations(list -- [elem]), do: [elem | rest]
  end

  # ── Progressive relaxation (DFS mode) ────────────────────────────────

  defp generate_with_relaxation(ctx, params) do
    relaxation_levels = [
      {params, []},
      {%{params | allow_repeats: true}, ["Algumas sequências permitem repetição de passos"]},
      {%{params | allow_repeats: true} |> Map.put(:max_bf_visits, 5),
       ["Algumas sequências permitem repetição de passos"]},
      {%{params | allow_repeats: true, length: max(params.length - 2, 3)}
       |> Map.put(:max_bf_visits, 5),
       ["Algumas sequências são mais curtas para viabilizar a geração"]}
    ]

    do_relaxation(relaxation_levels, ctx, [], params.count)
  end

  defp do_relaxation([], _ctx, sequences, _target_count), do: {sequences, []}

  defp do_relaxation([{level_params, warnings} | rest], ctx, sequences, target_count) do
    remaining = target_count - length(sequences)

    if remaining <= 0 do
      {sequences, []}
    else
      used_edges = edges_from_sequences(sequences)

      new_seqs =
        generate_batch(ctx, level_params, remaining, used_edges)

      all_seqs =
        (sequences ++ new_seqs)
        |> Enum.uniq_by(fn seq -> Enum.map(seq, & &1.id) end)

      if length(all_seqs) >= target_count do
        final_warnings = if new_seqs != [] and warnings != [], do: warnings, else: []
        {Enum.take(all_seqs, target_count), final_warnings}
      else
        do_relaxation(rest, ctx, all_seqs, target_count)
      end
    end
  end

  defp edges_from_sequences(sequences) do
    Enum.reduce(sequences, MapSet.new(), fn seq, acc ->
      seq
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.reduce(acc, fn [a, b], set -> MapSet.put(set, {a.id, b.id}) end)
    end)
  end

  # ── Batch generation (DFS mode) ──────────────────────────────────────

  defp generate_batch(ctx, params, count, used_edges) do
    bf_id = ctx.bf_id
    start_id = ctx.start_id

    max_bf =
      if params.cyclic and start_id == bf_id,
        do: max(Map.get(params, :max_bf_visits, 3) + 2, 5),
        else: Map.get(params, :max_bf_visits, 3)

    Enum.reduce(1..count, {[], used_edges}, fn _, {seqs, edges} ->
      case generate_one(ctx, params, max_bf, edges) do
        nil ->
          {seqs, edges}

        seq ->
          new_edges = seq_edges(seq, edges)
          {[seq | seqs], new_edges}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp seq_edges(seq, existing) do
    seq
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.reduce(existing, fn [a, b], set -> MapSet.put(set, {a.id, b.id}) end)
  end

  # ── Single sequence generation (DFS with backtracking) ──────────────

  defp generate_one(ctx, params, max_bf, used_edges) do
    Enum.reduce_while(1..@max_attempts, nil, fn _, _acc ->
      state = %{
        visited: MapSet.new([ctx.start_id]),
        pair_counts: %{},
        step_counts: %{ctx.start_id => 1},
        allow_repeats: params.allow_repeats,
        cyclic: params.cyclic,
        max_bf: max_bf,
        max_same_pair_loops: params.max_same_pair_loops,
        target_length: params.length,
        used_edges: used_edges,
        recent_categories: []
      }

      case dfs_walk([ctx.start_id], state, ctx) do
        nil -> {:cont, nil}
        path -> {:halt, format_path(path, ctx.step_map)}
      end
    end)
  end

  # ── DFS with backtracking ───────────────────────────────────────────

  defp dfs_walk(path, state, ctx) when length(path) == state.target_length do
    if state.cyclic do
      [current | _] = path
      if current == ctx.start_id, do: path, else: nil
    else
      path
    end
  end

  defp dfs_walk([current | _] = path, state, ctx) do
    neighbors = Map.get(ctx.adjacency, current, [])
    steps_remaining = state.target_length - length(path)
    valid = filter_neighbors(neighbors, current, state, ctx, steps_remaining)

    if valid == [] do
      nil
    else
      scored =
        valid
        |> Enum.map(fn n -> {n, score_neighbor(n, current, state, ctx, steps_remaining)} end)
        |> Enum.sort_by(fn {_, s} -> -s end)

      try_neighbors(scored, path, state, ctx)
    end
  end

  defp try_neighbors([], _path, _state, _ctx), do: nil

  defp try_neighbors([{next, _score} | rest], path, state, ctx) do
    [current | _] = path
    pair = {current, next}

    new_state = %{
      state
      | visited: MapSet.put(state.visited, next),
        pair_counts: Map.update(state.pair_counts, pair, 1, &(&1 + 1)),
        step_counts: Map.update(state.step_counts, next, 1, &(&1 + 1)),
        recent_categories: recent_cats(next, state, ctx)
    }

    case dfs_walk([next | path], new_state, ctx) do
      nil -> try_neighbors(rest, path, state, ctx)
      result -> result
    end
  end

  defp recent_cats(node_id, state, ctx) do
    cat =
      case Map.get(ctx.step_map, node_id) do
        nil -> nil
        step -> step.category_id
      end

    [cat | state.recent_categories] |> Enum.take(3)
  end

  # ── Neighbor scoring (DFS mode) ────────────────────────────────────

  defp score_neighbor(n, current, state, ctx, steps_remaining) do
    step = Map.get(ctx.step_map, n)

    bonuses = [
      bonus_highlighted(step),
      bonus_required(n, state, ctx),
      bonus_category_mix(step, state),
      bonus_cyclic(n, state, ctx, steps_remaining),
      penalty_used_edge(current, n, state),
      noise()
    ]

    max(@weight_base + Enum.sum(bonuses), 0.1)
  end

  defp bonus_highlighted(nil), do: 0.0
  defp bonus_highlighted(step), do: if(step.highlighted, do: @weight_highlighted, else: 0.0)

  defp bonus_required(n, state, ctx) do
    remaining = MapSet.difference(ctx.required_ids, state.visited)
    if MapSet.member?(remaining, n), do: @weight_required, else: 0.0
  end

  defp bonus_category_mix(nil, _state), do: 0.0

  defp bonus_category_mix(step, state) do
    if step.category_id not in state.recent_categories,
      do: @weight_category_mix,
      else: 0.0
  end

  defp bonus_cyclic(n, state, ctx, steps_remaining) do
    cond do
      state.cyclic and steps_remaining <= 3 ->
        dist = Map.get(ctx.dist_to_start, n, :infinity)

        cond do
          n == ctx.start_id and steps_remaining == 1 -> @weight_cyclic_close * 2
          dist == :infinity -> -3.0
          dist <= steps_remaining -> @weight_cyclic_close / max(dist, 1)
          true -> -1.0
        end

      not state.cyclic and steps_remaining == 1 and n == ctx.start_id ->
        2.0

      true ->
        0.0
    end
  end

  defp penalty_used_edge(current, n, state) do
    if MapSet.member?(state.used_edges, {current, n}),
      do: -@penalty_used_edge,
      else: 0.0
  end

  defp noise, do: :rand.uniform() * @weight_noise_max

  # ── Neighbor filtering (DFS mode) ──────────────────────────────────

  defp filter_neighbors(neighbors, current, state, ctx, steps_remaining) do
    Enum.filter(neighbors, fn n ->
      reachable = MapSet.member?(ctx.reachable, n)

      repeat_ok =
        if state.allow_repeats do
          pair_count = Map.get(state.pair_counts, {current, n}, 0)
          pair_count < state.max_same_pair_loops
        else
          not MapSet.member?(state.visited, n) or
            (state.cyclic and n == ctx.start_id and steps_remaining == 1)
        end

      bf_ok =
        if n == ctx.bf_id and ctx.bf_id != nil do
          Map.get(state.step_counts, n, 0) < state.max_bf
        else
          true
        end

      reachable and repeat_ok and bf_ok
    end)
  end

  # ── Graph helpers ──────────────────────────────────────────────────

  defp build_adjacency(connections) do
    Enum.reduce(connections, %{}, fn conn, acc ->
      Map.update(acc, conn.source_step_id, [conn.target_step_id], &[conn.target_step_id | &1])
    end)
  end

  defp build_reverse_adjacency(connections) do
    Enum.reduce(connections, %{}, fn conn, acc ->
      Map.update(acc, conn.target_step_id, [conn.source_step_id], &[conn.source_step_id | &1])
    end)
  end

  @doc false
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

  @doc false
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

  # ── Required code resolution ───────────────────────────────────────

  defp resolve_required_ids(nil, _code_to_id), do: {[], []}
  defp resolve_required_ids([], _code_to_id), do: {[], []}

  defp resolve_required_ids(codes, code_to_id) do
    {resolved, unresolved} =
      Enum.split_with(codes, &Map.has_key?(code_to_id, &1))

    ids = Enum.map(resolved, &Map.fetch!(code_to_id, &1))
    {ids, unresolved}
  end

  # ── Path formatting ────────────────────────────────────────────────

  # DFS builds path reversed ([last | ... | first]), so we reverse it
  defp format_path(path, step_map) do
    path
    |> Enum.reverse()
    |> format_ids(step_map)
  end

  # Waypoint paths are already in correct order
  defp format_path_forward(path, step_map) do
    format_ids(path, step_map)
  end

  defp format_ids(ids, step_map) do
    ids
    |> Enum.map(fn id ->
      step = Map.get(step_map, id)
      if step, do: %{id: step.id, code: step.code, name: step.name}, else: nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  # ── Warnings ───────────────────────────────────────────────────────

  defp length_warnings([], _target), do: []

  defp length_warnings(sequences, target) do
    lengths = Enum.map(sequences, &length/1)
    min_len = Enum.min(lengths)
    max_len = Enum.max(lengths)

    cond do
      min_len == max_len and min_len != target ->
        ["Tamanho ajustado para #{min_len} passos para incluir todos os obrigatórios"]

      min_len != target or max_len != target ->
        ["Tamanho variou entre #{min_len} e #{max_len} passos para incluir todos os obrigatórios"]

      true ->
        []
    end
  end

  defp count_warnings(sequences, target) do
    if length(sequences) < target do
      ["Gerou #{length(sequences)} de #{target} sequências solicitadas"]
    else
      []
    end
  end

  defp build_dfs_warnings(sequences, required_ids, step_map, params) do
    required_warnings =
      if required_ids != [] do
        missed =
          Enum.flat_map(sequences, fn seq ->
            seq_ids = MapSet.new(Enum.map(seq, & &1.id))
            Enum.reject(required_ids, &MapSet.member?(seq_ids, &1))
          end)
          |> Enum.uniq()
          |> Enum.map(&Map.get(step_map, &1))
          |> Enum.reject(&is_nil/1)
          |> Enum.map(& &1.code)

        if missed != [] do
          ["#{Enum.join(missed, ", ")} não incluído(s) em algumas sequências"]
        else
          []
        end
      else
        []
      end

    count_warnings = count_warnings(sequences, params.count)

    required_warnings ++ count_warnings
  end

  defp unresolved_warnings([]), do: []

  defp unresolved_warnings(codes) do
    ["Passo(s) obrigatório(s) não encontrado(s): #{Enum.join(codes, ", ")}"]
  end

  defp unreachable_warnings([]), do: []

  defp unreachable_warnings(codes) do
    [
      "Passo(s) obrigatório(s) inalcançável(is) a partir do passo inicial: #{Enum.join(codes, ", ")}"
    ]
  end
end
