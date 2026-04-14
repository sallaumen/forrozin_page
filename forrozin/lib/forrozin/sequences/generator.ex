defmodule Forrozin.Sequences.Generator do
  @moduledoc """
  Generates step sequences by traversing the directed connection graph.

  Uses randomized DFS with backtracking and weighted selection for required
  steps. Supports cyclic sequences (start == end) and loop limiting.
  """

  alias Forrozin.Encyclopedia.{ConnectionQuery, StepQuery}

  @type step_info :: %{id: String.t(), code: String.t(), name: String.t()}
  @type sequence :: [step_info()]
  @type result :: {:ok, [sequence()], [String.t()]}

  @type params :: %{
          start_code: String.t(),
          length: pos_integer(),
          count: pos_integer(),
          required_codes: [String.t()],
          allow_repeats: boolean(),
          cyclic: boolean()
        }

  @required_weight 5
  @max_attempts_per_sequence 100
  @max_same_pair_loops 3

  @doc """
  Generate sequences traversing the step connection graph.

  Options:
  - `cyclic: true` (default) — sequence must end at `start_code`
  - `allow_repeats: true` — steps can appear multiple times (max #{@max_same_pair_loops} identical transitions)
  - `required_codes` — best-effort inclusion of these steps
  """
  @spec generate(params()) :: result()
  @bf_code "BF"

  def generate(params) do
    params =
      params
      |> Map.put_new(:cyclic, true)
      |> Map.put_new(:max_bf_visits, 1)

    steps = StepQuery.list_by(public_only: true, preload: [:category])
    connections = ConnectionQuery.list_by(preload: [])

    step_map = Map.new(steps, &{&1.id, &1})
    code_to_id = Map.new(steps, &{&1.code, &1.id})
    adjacency = build_adjacency(connections)

    start_id = Map.get(code_to_id, params.start_code)
    required_ids = resolve_required_ids(params.required_codes, code_to_id)
    required_id_set = MapSet.new(required_ids)

    if is_nil(start_id) do
      {:ok, [], ["Passo inicial '#{params.start_code}' não encontrado"]}
    else
      sequences =
        1..params.count
        |> Enum.map(fn _ ->
          generate_one(start_id, params.length, adjacency, required_id_set, params.allow_repeats, params.cyclic, step_map, params)
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq_by(fn seq -> Enum.map(seq, & &1.id) end)

      warnings = build_warnings(sequences, required_ids, step_map, params)
      {:ok, sequences, warnings}
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp resolve_required_ids(nil, _code_to_id), do: []

  defp resolve_required_ids(codes, code_to_id) do
    codes
    |> Enum.map(&Map.get(code_to_id, &1))
    |> Enum.reject(&is_nil/1)
  end

  defp build_adjacency(connections) do
    Enum.reduce(connections, %{}, fn conn, acc ->
      Map.update(acc, conn.source_step_id, [conn.target_step_id], &[conn.target_step_id | &1])
    end)
  end

  defp generate_one(start_id, target_length, adjacency, required_ids, allow_repeats, cyclic, step_map, params) do
    Enum.reduce_while(1..@max_attempts_per_sequence, nil, fn _, _acc ->
      path = walk(start_id, target_length, adjacency, required_ids, allow_repeats, cyclic, step_map, params)

      valid =
        cond do
          is_nil(path) -> false
          length(path) != target_length -> false
          cyclic and List.last(path).id != start_id -> false
          true -> true
        end

      if valid, do: {:halt, path}, else: {:cont, nil}
    end)
  end

  defp walk(start_id, target_length, adjacency, required_ids, allow_repeats, cyclic, step_map, params) do
    code_to_id = Map.new(Map.values(step_map), &{&1.code, &1.id})
    bf_id = Map.get(code_to_id, @bf_code)

    # BF limit: for cyclic starting at BF, allow 3 (start + end + 1 mid)
    # For others, use configurable max_bf_visits (default 1)
    max_bf =
      if cyclic and start_id == bf_id do
        3
      else
        Map.get(params, :max_bf_visits, 1)
      end

    state = %{
      visited: MapSet.new([start_id]),
      pair_counts: %{},
      step_counts: %{start_id => 1},
      adjacency: adjacency,
      required_ids: required_ids,
      allow_repeats: allow_repeats,
      cyclic: cyclic,
      start_id: start_id,
      bf_id: bf_id,
      max_bf: max_bf,
      step_map: step_map,
      target_length: target_length
    }

    do_walk([start_id], state)
  end

  defp do_walk(path, state) when length(path) == state.target_length do
    if state.cyclic do
      # Last step must be start — check if we can reach start from current
      [current | _] = path

      if current == state.start_id do
        # Already at start — this works
        format_path(path, state.step_map)
      else
        nil
      end
    else
      format_path(path, state.step_map)
    end
  end

  defp do_walk([current | _rest] = path, state) do
    neighbors = Map.get(state.adjacency, current, [])
    steps_remaining = state.target_length - length(path)

    valid_neighbors = filter_neighbors(neighbors, current, path, state, steps_remaining)

    if valid_neighbors == [] do
      nil
    else
      remaining_required = MapSet.difference(state.required_ids, state.visited)

      # If cyclic and near the end, weight start_id heavily
      weighted =
        Enum.flat_map(valid_neighbors, fn n ->
          weight = cond do
            state.cyclic and steps_remaining == 1 and n == state.start_id -> 20
            MapSet.member?(remaining_required, n) -> @required_weight
            true -> 1
          end
          List.duplicate(n, weight)
        end)

      next = Enum.random(weighted)
      pair = {current, next}

      new_state = %{state |
        visited: MapSet.put(state.visited, next),
        pair_counts: Map.update(state.pair_counts, pair, 1, &(&1 + 1)),
        step_counts: Map.update(state.step_counts, next, 1, &(&1 + 1))
      }

      do_walk([next | path], new_state)
    end
  end

  defp filter_neighbors(neighbors, current, _path, state, steps_remaining) do
    Enum.filter(neighbors, fn n ->
      # Check repeat rules
      repeat_ok =
        if state.allow_repeats do
          pair_count = Map.get(state.pair_counts, {current, n}, 0)
          pair_count < @max_same_pair_loops
        else
          not MapSet.member?(state.visited, n) or
            (state.cyclic and n == state.start_id and steps_remaining == 1)
        end

      # Check BF visit limit
      bf_ok =
        if n == state.bf_id and state.bf_id != nil do
          current_bf_count = Map.get(state.step_counts, n, 0)
          current_bf_count < state.max_bf
        else
          true
        end

      repeat_ok and bf_ok
    end)
  end

  defp format_path(path, step_map) do
    path
    |> Enum.reverse()
    |> Enum.map(fn id ->
      step = Map.get(step_map, id)
      if step, do: %{id: step.id, code: step.code, name: step.name}, else: nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp build_warnings(sequences, required_ids, step_map, params) do
    required_warnings =
      if required_ids != [] do
        missed_per_sequence =
          Enum.map(sequences, fn seq ->
            seq_ids = MapSet.new(Enum.map(seq, & &1.id))
            Enum.reject(required_ids, &MapSet.member?(seq_ids, &1))
          end)

        if Enum.any?(missed_per_sequence, &(&1 != [])) do
          missed_count = Enum.count(missed_per_sequence, &(&1 != []))

          missed_codes =
            missed_per_sequence
            |> List.flatten()
            |> Enum.uniq()
            |> Enum.map(&Map.get(step_map, &1))
            |> Enum.reject(&is_nil/1)
            |> Enum.map(& &1.code)
            |> Enum.join(", ")

          ["#{missed_codes} não incluído(s) em #{missed_count} sequência(s)"]
        else
          []
        end
      else
        []
      end

    count_warnings =
      if length(sequences) < params.count do
        ["Gerou #{length(sequences)} de #{params.count} sequências solicitadas"]
      else
        []
      end

    required_warnings ++ count_warnings
  end
end
