defmodule OGrupoDeEstudos.Sequences.Generator.PathFormat do
  @moduledoc "Formatação pura de caminhos (ids) em step_infos para o Generator."

  @doc "DFS constrói o caminho invertido ([último | ... | primeiro]); reverte e formata."
  def format_path(path, step_map) do
    path
    |> Enum.reverse()
    |> format_ids(step_map)
  end

  @doc "Caminhos de waypoint já vêm na ordem correta."
  def format_path_forward(path, step_map) do
    format_ids(path, step_map)
  end

  @doc "Código de um passo pelo id, ou \"?\" se desconhecido."
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
