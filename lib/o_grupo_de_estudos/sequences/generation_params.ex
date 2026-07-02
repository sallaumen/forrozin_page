defmodule OGrupoDeEstudos.Sequences.GenerationParams do
  @moduledoc """
  Normaliza os params crus do form do gerador em params de domínio para
  `Sequences.Generator.generate/1`.

  Cálculo puro: regras de loop_mode (repetição e loops por par), comprimento
  mínimo (8 com repetição, 4 sem) e parsing de inteiros com defaults vivem
  aqui, não na borda.
  """

  @default_length 10
  @default_count 3
  @default_max_bf_visits 3
  @min_length_with_repeats 8
  @min_length_without_repeats 4

  @type t :: %{
          start_code: String.t(),
          length: pos_integer(),
          count: pos_integer(),
          required_codes: [String.t()],
          allow_repeats: boolean(),
          cyclic: boolean(),
          max_bf_visits: pos_integer(),
          max_same_pair_loops: pos_integer()
        }

  @spec from_raw(String.t(), [String.t()], map()) :: t()
  def from_raw(start_code, required_codes, raw) do
    loop_mode = Map.get(raw, "loop_mode", "none")
    allow_repeats = allow_repeats?(loop_mode, Map.get(raw, "allow_repeats"))

    %{
      start_code: start_code,
      length: normalized_length(raw, allow_repeats),
      count: parse_int(Map.get(raw, "count"), @default_count),
      required_codes: required_codes,
      allow_repeats: allow_repeats,
      cyclic: Map.get(raw, "cyclic") in ["true", "on"],
      max_bf_visits: parse_int(Map.get(raw, "max_bf_visits"), @default_max_bf_visits),
      max_same_pair_loops: max_same_pair_loops(loop_mode)
    }
  end

  @doc "Loops permitidos no mesmo par de passos, por modo de loop."
  @spec max_same_pair_loops(String.t()) :: pos_integer()
  def max_same_pair_loops("free"), do: 3
  def max_same_pair_loops("light"), do: 2
  def max_same_pair_loops(_mode), do: 1

  defp allow_repeats?(loop_mode, checkbox) do
    loop_mode in ["light", "free"] or checkbox in ["true", "on"]
  end

  defp normalized_length(raw, allow_repeats) do
    min_length = if allow_repeats, do: @min_length_with_repeats, else: @min_length_without_repeats

    raw
    |> Map.get("length")
    |> parse_int(@default_length)
    |> max(min_length)
  end

  defp parse_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _rest} -> int
      :error -> default
    end
  end

  defp parse_int(_value, default), do: default
end
