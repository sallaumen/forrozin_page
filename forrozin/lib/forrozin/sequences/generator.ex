defmodule Forrozin.Sequences.Generator do
  @moduledoc """
  Generates step sequences by traversing the directed connection graph.

  Uses randomized DFS with backtracking and weighted selection for required
  steps. Each call to `generate/1` returns a list of distinct sequences and
  any warnings about constraints that could not be satisfied.
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
          allow_repeats: boolean()
        }

  @required_weight 5
  @max_attempts_per_sequence 50

  @doc """
  Generate sequences traversing the step connection graph.

  Returns `{:ok, sequences, warnings}` where:
  - `sequences` is a list of step lists (each step has `:id`, `:code`, `:name`)
  - `warnings` is a list of messages about constraints not met
  """
  @spec generate(params()) :: result()
  def generate(params) do
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
          generate_one(
            start_id,
            params.length,
            adjacency,
            required_id_set,
            params.allow_repeats,
            step_map
          )
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

  defp generate_one(start_id, length, adjacency, required_ids, allow_repeats, step_map) do
    Enum.reduce_while(1..@max_attempts_per_sequence, nil, fn _, _acc ->
      path = walk(start_id, length, adjacency, required_ids, allow_repeats, step_map)

      if path && length(path) == length do
        {:halt, path}
      else
        {:cont, nil}
      end
    end)
  end

  defp walk(start_id, target_length, adjacency, required_ids, allow_repeats, step_map) do
    do_walk(
      [start_id],
      target_length,
      adjacency,
      required_ids,
      allow_repeats,
      step_map,
      MapSet.new([start_id])
    )
  end

  defp do_walk(path, target_length, _adjacency, _required_ids, _allow_repeats, step_map, _visited)
       when length(path) == target_length do
    path
    |> Enum.reverse()
    |> Enum.map(fn id ->
      step = Map.get(step_map, id)
      if step, do: %{id: step.id, code: step.code, name: step.name}, else: nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp do_walk(
         [current | _rest] = path,
         target_length,
         adjacency,
         required_ids,
         allow_repeats,
         step_map,
         visited
       ) do
    neighbors = Map.get(adjacency, current, [])

    valid_neighbors =
      if allow_repeats do
        neighbors
      else
        Enum.reject(neighbors, &MapSet.member?(visited, &1))
      end

    if valid_neighbors == [] do
      nil
    else
      remaining_required = MapSet.difference(required_ids, visited)

      weighted =
        Enum.flat_map(valid_neighbors, fn n ->
          weight = if MapSet.member?(remaining_required, n), do: @required_weight, else: 1
          List.duplicate(n, weight)
        end)

      next = Enum.random(weighted)
      new_visited = MapSet.put(visited, next)

      do_walk([next | path], target_length, adjacency, required_ids, allow_repeats, step_map, new_visited)
    end
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
