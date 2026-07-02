defmodule OGrupoDeEstudos.Sequences.Generator.Dfs do
  @moduledoc """
  Geração por DFS aleatorizada com backtracking (modo sem obrigatórios).

  Seleção de vizinhos ponderada (destaque, mistura de categorias,
  fechamento cíclico, penalidade de aresta repetida, ruído) e relaxamento
  progressivo de restrições quando a contagem alvo não é atingida.
  """

  alias OGrupoDeEstudos.Sequences.Generator.PathFormat

  @max_attempts 50

  # Weight constants
  @weight_base 1.0
  @weight_highlighted 2.0
  @weight_required 4.0
  @weight_category_mix 1.5
  @weight_cyclic_close 6.0
  @weight_noise_max 1.5
  @penalty_used_edge 2.0

  @doc "Gera com relaxamento progressivo. Retorna {sequences, warnings}."
  def generate_with_relaxation(ctx, params) do
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
      all_seqs = try_relaxation_level(ctx, level_params, sequences, remaining)
      finalize_relaxation(all_seqs, warnings, rest, ctx, target_count)
    end
  end

  defp try_relaxation_level(ctx, level_params, sequences, remaining) do
    used_edges = edges_from_sequences(sequences)
    new_seqs = generate_batch(ctx, level_params, remaining, used_edges)

    (sequences ++ new_seqs)
    |> Enum.uniq_by(fn seq -> Enum.map(seq, & &1.id) end)
  end

  defp finalize_relaxation(all_seqs, warnings, rest, ctx, target_count) do
    if length(all_seqs) >= target_count do
      final_warnings = if all_seqs != [] and warnings != [], do: warnings, else: []
      {Enum.take(all_seqs, target_count), final_warnings}
    else
      do_relaxation(rest, ctx, all_seqs, target_count)
    end
  end

  defp edges_from_sequences(sequences) do
    Enum.reduce(sequences, MapSet.new(), fn seq, acc ->
      seq
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.reduce(acc, fn [a, b], set -> MapSet.put(set, {a.id, b.id}) end)
    end)
  end

  # ── Batch generation ─────────────────────────────────────────────────

  defp generate_batch(ctx, params, count, used_edges) do
    max_bf = batch_max_bf(ctx, params)

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

  defp batch_max_bf(ctx, params) do
    if params.cyclic and ctx.start_id == ctx.bf_id,
      do: max(Map.get(params, :max_bf_visits, 3) + 2, 5),
      else: Map.get(params, :max_bf_visits, 3)
  end

  defp seq_edges(seq, existing) do
    seq
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.reduce(existing, fn [a, b], set -> MapSet.put(set, {a.id, b.id}) end)
  end

  # ── Single sequence generation (DFS with backtracking) ──────────────

  defp generate_one(ctx, params, max_bf, used_edges) do
    Enum.reduce_while(1..@max_attempts, nil, fn _, _acc ->
      case dfs_walk([ctx.start_id], initial_state(ctx, params, max_bf, used_edges), ctx) do
        nil -> {:cont, nil}
        path -> {:halt, PathFormat.format_path(path, ctx.step_map)}
      end
    end)
  end

  defp initial_state(ctx, params, max_bf, used_edges) do
    %{
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

  # ── Neighbor scoring ────────────────────────────────────────────────

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
    if step.category_id in state.recent_categories,
      do: 0.0,
      else: @weight_category_mix
  end

  defp bonus_cyclic(n, state, ctx, steps_remaining) do
    cond do
      state.cyclic and steps_remaining <= 3 ->
        cyclic_closing_bonus(n, ctx, steps_remaining)

      !state.cyclic and steps_remaining == 1 and n == ctx.start_id ->
        2.0

      true ->
        0.0
    end
  end

  defp cyclic_closing_bonus(n, ctx, steps_remaining) do
    dist = Map.get(ctx.dist_to_start, n, :infinity)

    cond do
      n == ctx.start_id and steps_remaining == 1 -> @weight_cyclic_close * 2
      dist == :infinity -> -3.0
      dist <= steps_remaining -> @weight_cyclic_close / max(dist, 1)
      true -> -1.0
    end
  end

  defp penalty_used_edge(current, n, state) do
    if MapSet.member?(state.used_edges, {current, n}),
      do: -@penalty_used_edge,
      else: 0.0
  end

  defp noise, do: :rand.uniform() * @weight_noise_max

  # ── Neighbor filtering ──────────────────────────────────────────────

  defp filter_neighbors(neighbors, current, state, ctx, steps_remaining) do
    Enum.filter(neighbors, fn n ->
      reachable?(ctx, n) and repeat_ok?(n, current, state, ctx, steps_remaining) and
        bf_ok?(n, state, ctx)
    end)
  end

  defp reachable?(ctx, n), do: MapSet.member?(ctx.reachable, n)

  defp repeat_ok?(n, current, state, ctx, steps_remaining) do
    if state.allow_repeats do
      Map.get(state.pair_counts, {current, n}, 0) < state.max_same_pair_loops
    else
      not MapSet.member?(state.visited, n) or
        (state.cyclic and n == ctx.start_id and steps_remaining == 1)
    end
  end

  defp bf_ok?(n, state, ctx) do
    if n == ctx.bf_id and ctx.bf_id != nil do
      Map.get(state.step_counts, n, 0) < state.max_bf
    else
      true
    end
  end
end
