defmodule OGrupoDeEstudos.Sequences.Generator.PathFormat do
  @moduledoc "Pure formatting of paths (ids) into step_infos for the Generator."

  @doc "DFS builds the path reversed ([last | ... | first]); this reverses and formats it."
  def format_path(path, step_map) do
    path
    |> Enum.reverse()
    |> format_ids(step_map)
  end

  @doc "Waypoint paths already come in the right order."
  def format_path_forward(path, step_map) do
    format_ids(path, step_map)
  end

  @doc "Code of a step by id, or a question mark when unknown."
  def code_for(step_map, id) do
    case Map.get(step_map, id) do
      nil -> "?"
      step -> step.code
    end
  end

  defp format_ids(ids, step_map) do
    ids
    |> Enum.map(fn id ->
      step = Map.get(step_map, id)
      if step, do: %{id: step.id, code: step.code, name: step.name}, else: nil
    end)
    |> Enum.reject(&is_nil/1)
  end
end
