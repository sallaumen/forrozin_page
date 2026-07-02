defmodule OGrupoDeEstudos.Sequences.Generator.Waypoint do
  @moduledoc """
  Geração por waypoints (modo com passos obrigatórios).

  Hybrid explore-then-correct: para cada segmento entre waypoints, o
  algoritmo caminha aleatoriamente pelo grafo por um "budget" de passos
  (exploração) e depois corrige o curso via BFS até o waypoint. Isso
  produz arestas de entrada diversas em cada passo obrigatório.
  """

  alias OGrupoDeEstudos.Sequences.Generator.{GraphTraversal, PathFormat, Warnings}
  alias OGrupoDeEstudos.Sequences.Scorer

  @zones [:beginning, :middle, :end]
  @max_attempts 50
  @overgeneration_factor 5

  @doc "Gera as sequências com todos os obrigatórios. Retorna {sequences, warnings}."
  def generate(ctx, params, required_ids) do
    zones = @zones |> Stream.cycle() |> Enum.take(params.count)
    scorer_opts = %{required_ids: ctx.required_ids, bf_id: ctx.bf_id}

    {sequences, all_warnings} =
      Enum.reduce(zones, {[], []}, fn zone, {seqs, warns} ->
        {candidates, zone_warns} = generate_zone_candidates(zone, ctx, params, required_ids)

        case best_candidate(candidates, scorer_opts) do
          {seq, _score, _breakdown} -> {[seq | seqs], warns ++ zone_warns}
          nil -> {seqs, warns ++ zone_warns}
        end
      end)

    sequences = Enum.reverse(sequences)

    warnings =
      Enum.uniq(all_warnings) ++
        Warnings.length_warnings(sequences, params.length) ++
        Warnings.count_warnings(sequences, params.count)

    {sequences, warnings}
  end

  defp best_candidate(candidates, scorer_opts) do
    candidates
    |> Enum.uniq_by(fn seq -> Enum.map(seq, & &1.id) end)
    |> Scorer.rank(scorer_opts)
    |> List.first()
  end

  defp generate_zone_candidates(zone, ctx, params, required_ids) do
    perms = shuffled_permutations(required_ids, @overgeneration_factor)

    Enum.reduce(perms, {[], []}, fn perm, {seqs, warns} ->
      waypoints = waypoint_list(ctx.start_id, perm, params.cyclic)

      case build_zone_path(waypoints, params.length, zone, ctx) do
        {:ok, path} ->
          formatted = PathFormat.format_path_forward(path, ctx.step_map)
          {[formatted | seqs], warns}

        {:error, from_id, to_id} ->
          from_code = PathFormat.code_for(ctx.step_map, from_id)
          to_code = PathFormat.code_for(ctx.step_map, to_id)
          {seqs, ["Não existe caminho de #{from_code} para #{to_code} no grafo" | warns]}
      end
    end)
  end

  defp waypoint_list(start_id, required_ids, true = _cyclic) do
    [start_id | required_ids] ++ [start_id]
  end

  defp waypoint_list(start_id, required_ids, false) do
    [start_id | required_ids]
  end

  defp build_zone_path(waypoints, target_length, zone, ctx) do
    segments = Enum.chunk_every(waypoints, 2, 1, :discard)

    min_dists =
      Enum.map(segments, fn [from, to] ->
        case GraphTraversal.bfs_path(from, to, ctx.adjacency) do
          {:ok, path} -> length(path) - 1
          :no_path -> :no_path
        end
      end)

    impossible =
      Enum.zip(segments, min_dists)
      |> Enum.find(fn {_seg, dist} -> dist == :no_path end)

    case impossible do
      {[from, to], _} ->
        {:error, from, to}

      nil ->
        explore_zone_paths(segments, min_dists, target_length, zone, ctx)
    end
  end

  defp explore_zone_paths(segments, min_dists, target_length, zone, ctx) do
    total_min = Enum.sum(min_dists) + 1
    extra = max(target_length - total_min, 0)
    {pre_fraction, _post_fraction} = zone_budget_split(zone)

    result =
      Enum.reduce_while(1..@max_attempts, nil, fn _, _ ->
        attempt_exploratory(segments, extra, pre_fraction, target_length, ctx)
      end)

    case result do
      {:ok, path} -> {:ok, path}
      nil -> connect_waypoints_shortest(segments, ctx.adjacency)
    end
  end

  defp attempt_exploratory(segments, extra, pre_fraction, target_length, ctx) do
    jitter = (:rand.uniform() - 0.5) * 0.4
    actual_pre = max(min(pre_fraction + jitter, 0.95), 0.05)
    pre_budget = round(extra * actual_pre)
    post_budget = extra - pre_budget
    segment_budgets = distribute_budget(pre_budget, length(segments))

    case try_exploratory_path(segments, segment_budgets, ctx) do
      {:ok, path} ->
        with_post = pad_path(path, length(path) + post_budget, ctx)
        final = pad_path(with_post, target_length, ctx)
        trimmed = trim_to_target(final, target_length, ctx.required_ids)
        {:halt, {:ok, trimmed}}

      :retry ->
        {:cont, nil}
    end
  end

  defp zone_budget_split(:beginning), do: {0.15, 0.85}
  defp zone_budget_split(:middle), do: {0.50, 0.50}
  defp zone_budget_split(:end), do: {0.85, 0.15}

  # Trim path to target_length without cutting required steps
  defp trim_to_target(path, target_length, _required_ids) when length(path) <= target_length do
    path
  end

  defp trim_to_target(path, target_length, required_ids) do
    # Find the latest required step position — can't trim before that
    max_required_pos =
      path
      |> Enum.with_index()
      |> Enum.filter(fn {id, _idx} -> MapSet.member?(required_ids, id) end)
      |> Enum.map(fn {_id, idx} -> idx end)
      |> case do
        [] -> 0
        positions -> Enum.max(positions)
      end

    safe_length = max(target_length, max_required_pos + 2)
    Enum.take(path, safe_length)
  end

  defp try_exploratory_path(segments, budgets, ctx) do
    Enum.zip(segments, budgets)
    |> Enum.reduce_while({:ok, [ctx.start_id]}, fn {[_from, to], budget}, {:ok, path} ->
      explore_and_correct(path, to, budget, ctx)
    end)
  end

  defp explore_and_correct(path, to, budget, ctx) do
    current = List.last(path)
    explored = random_walk(current, budget, ctx)
    walk_end = List.last(explored)

    case GraphTraversal.bfs_path(walk_end, to, ctx.adjacency) do
      {:ok, correction} ->
        explore_tail = if length(explored) > 1, do: tl(explored), else: []
        correct_tail = if length(correction) > 1, do: tl(correction), else: []
        {:cont, {:ok, path ++ explore_tail ++ correct_tail}}

      :no_path ->
        {:halt, :retry}
    end
  end

  defp random_walk(_current, 0, _ctx), do: []

  defp random_walk(current, steps, ctx) do
    do_random_walk([current], steps, MapSet.new([current]), ctx)
    |> Enum.reverse()
  end

  defp do_random_walk(path, 0, _visited, _ctx), do: path

  defp do_random_walk([current | _] = path, remaining, visited, ctx) do
    neighbors =
      Map.get(ctx.adjacency, current, [])
      |> Enum.filter(&MapSet.member?(ctx.reachable, &1))

    unvisited = Enum.reject(neighbors, &MapSet.member?(visited, &1))
    candidates = if unvisited != [], do: unvisited, else: neighbors

    case candidates do
      [] ->
        path

      _ ->
        next = Enum.random(candidates)
        do_random_walk([next | path], remaining - 1, MapSet.put(visited, next), ctx)
    end
  end

  defp distribute_budget(0, n), do: List.duplicate(0, n)

  defp distribute_budget(extra, n) do
    # Distribute `extra` steps randomly across `n` segments
    slots = for _ <- 1..extra, do: :rand.uniform(n) - 1

    base = List.duplicate(0, n)

    Enum.reduce(slots, base, fn slot, acc ->
      List.update_at(acc, slot, &(&1 + 1))
    end)
  end

  defp connect_waypoints_shortest(segments, adjacency) do
    Enum.reduce_while(segments, {:ok, []}, fn [from, to], {:ok, acc} ->
      connect_segment(acc, from, to, adjacency)
    end)
  end

  defp connect_segment(acc, from, to, adjacency) do
    start_node = if acc == [], do: from, else: List.last(acc)

    case GraphTraversal.bfs_path(start_node, to, adjacency) do
      {:ok, path} ->
        trimmed = if acc == [], do: path, else: tl(path)
        {:cont, {:ok, acc ++ trimmed}}

      :no_path ->
        {:halt, {:error, from, to}}
    end
  end

  # Extends path to target_length by random walk from the last node.
  defp pad_path(path, target_length, _ctx) when length(path) >= target_length, do: path

  defp pad_path(path, target_length, ctx) do
    remaining = target_length - length(path)
    current = List.last(path)
    tail = random_walk(current, remaining, ctx)
    tail_trimmed = if length(tail) > 1, do: tl(tail), else: []
    path ++ tail_trimmed
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
end
