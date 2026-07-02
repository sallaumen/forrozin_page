defmodule OGrupoDeEstudos.Sequences.Generator.Warnings do
  @moduledoc "Montagem pura dos avisos (PT-BR) retornados pelo Generator."

  def length_warnings([], _target), do: []

  def length_warnings(sequences, target) do
    min_len = sequences |> Enum.map(&length/1) |> Enum.min()

    if min_len > target do
      ["Tamanho ajustado para #{min_len} passos para incluir todos os obrigatórios"]
    else
      []
    end
  end

  def count_warnings(sequences, target) do
    if length(sequences) < target do
      ["Gerou #{length(sequences)} de #{target} sequências solicitadas"]
    else
      []
    end
  end

  def dfs_warnings(sequences, required_ids, step_map, params) do
    missed_required_warnings(sequences, required_ids, step_map) ++
      count_warnings(sequences, params.count)
  end

  def unresolved_warnings([]), do: []

  def unresolved_warnings(codes) do
    ["Passo(s) obrigatório(s) não encontrado(s): #{Enum.join(codes, ", ")}"]
  end

  def unreachable_warnings([]), do: []

  def unreachable_warnings(codes) do
    [
      "Passo(s) obrigatório(s) inalcançável(is) a partir do passo inicial: #{Enum.join(codes, ", ")}"
    ]
  end

  defp missed_required_warnings(_sequences, [], _step_map), do: []

  defp missed_required_warnings(sequences, required_ids, step_map) do
    case missed_codes(sequences, required_ids, step_map) do
      [] -> []
      missed -> ["#{Enum.join(missed, ", ")} não incluído(s) em algumas sequências"]
    end
  end

  defp missed_codes(sequences, required_ids, step_map) do
    sequences
    |> Enum.flat_map(fn seq ->
      seq_ids = MapSet.new(Enum.map(seq, & &1.id))
      Enum.reject(required_ids, &MapSet.member?(seq_ids, &1))
    end)
    |> Enum.uniq()
    |> Enum.map(&Map.get(step_map, &1))
    |> Enum.reject(&is_nil/1)
    |> Enum.map(& &1.code)
  end
end
