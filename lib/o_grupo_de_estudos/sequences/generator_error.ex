defmodule OGrupoDeEstudos.Sequences.GeneratorError do
  @moduledoc """
  Domain error for sequence generation.

  Fatal conditions return `{:error, %GeneratorError{}}` so callers can
  distinguish failure from an `{:ok, sequences, warnings}` result with
  advisory warnings. The `:code` is the discriminator the UI translates;
  it is also a proper exception so it reads sanely if ever raised.
  """

  @type code :: :start_step_not_found

  @type t :: %__MODULE__{code: code(), message: String.t(), details: map()}

  defexception [:code, :message, details: %{}]

  @doc "Builds the error for an unknown start step code."
  @spec start_step_not_found(String.t()) :: t()
  def start_step_not_found(start_code) do
    %__MODULE__{
      code: :start_step_not_found,
      message: "Passo inicial '#{start_code}' não encontrado",
      details: %{start_code: start_code}
    }
  end
end
