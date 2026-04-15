defmodule Forrozin.Sequences.Validator do
  @moduledoc """
  Validates sequences against the current graph state.

  A sequence is valid when:
  - every step it references is still active (not soft-deleted), and
  - every consecutive pair of steps has an active connection in the graph.

  Returns `:valid` or `{:invalid, [issue]}` where each issue is a map with
  keys `:position`, `:type`, and `:code`.
  """

  alias Forrozin.Encyclopedia.{ConnectionQuery, StepQuery}

  @type issue :: %{position: integer(), type: :deleted_step | :deleted_connection | :missing_connection, code: String.t()}

  @doc """
  Validates a list of `SequenceStep` structs (must have `:step_id` loaded).

  Returns `:valid` or `{:invalid, [issue]}`.
  """
  @spec validate(list()) :: :valid | {:invalid, [issue()]}
  def validate([]), do: :valid

  def validate(sequence_steps) do
    step_ids = Enum.map(sequence_steps, & &1.step_id)

    active_steps = StepQuery.list_by(step_ids: step_ids, include_deleted: false)
    active_ids = MapSet.new(active_steps, & &1.id)

    all_steps = StepQuery.list_by(step_ids: step_ids, include_deleted: true)
    step_map = Map.new(all_steps, &{&1.id, &1})

    step_issues = collect_step_issues(sequence_steps, active_ids, step_map)
    connection_issues = collect_connection_issues(sequence_steps, step_map)

    all_issues = step_issues ++ connection_issues

    if all_issues == [] do
      :valid
    else
      {:invalid, all_issues}
    end
  end

  defp collect_step_issues(sequence_steps, active_ids, step_map) do
    sequence_steps
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {ss, pos} ->
      if MapSet.member?(active_ids, ss.step_id) do
        []
      else
        code = get_code(step_map, ss.step_id)
        [%{position: pos, type: :deleted_step, code: code}]
      end
    end)
  end

  defp collect_connection_issues(sequence_steps, step_map) do
    sequence_steps
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {[a, b], pos} ->
      conn =
        ConnectionQuery.get_by(
          source_step_id: a.step_id,
          target_step_id: b.step_id,
          include_deleted: true
        )

      code_pair = "#{get_code(step_map, a.step_id)} → #{get_code(step_map, b.step_id)}"

      cond do
        is_nil(conn) ->
          [%{position: pos, type: :missing_connection, code: code_pair}]

        conn.deleted_at != nil ->
          [%{position: pos, type: :deleted_connection, code: code_pair}]

        true ->
          []
      end
    end)
  end

  defp get_code(step_map, id) do
    case Map.get(step_map, id) do
      nil -> "?"
      step -> step.code
    end
  end
end
