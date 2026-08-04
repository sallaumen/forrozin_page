defmodule OGrupoDeEstudosWeb.ChangesetErrors do
  @moduledoc """
  The first error of a changeset, in the language the person is reading.

  Ecto writes its built-in messages in English, so a Portuguese form was answering
  "Título can't be blank". Messages the schemas write themselves are already in
  Portuguese and pass through untouched.
  """

  @translations %{
    "can't be blank" => "não pode ficar em branco",
    "is invalid" => "está num formato que não dá para ler",
    "has already been taken" => "já está em uso",
    "does not exist" => "não existe"
  }

  @doc "The first message, translated, or a generic line when there is none."
  @spec first_message(Ecto.Changeset.t()) :: String.t()
  def first_message(%Ecto.Changeset{} = changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(&translate/1)
    |> Enum.flat_map(fn {_field, messages} -> messages end)
    |> List.first()
    |> Kernel.||("Não deu para salvar. Confira o campo e tente de novo.")
  end

  defp translate({message, opts}) do
    case Map.fetch(@translations, message) do
      {:ok, translated} -> translated
      :error -> interpolate(message, opts)
    end
  end

  # Counted messages carry the number apart, so the raw string still holds
  # `%{count}` until it is put back.
  defp interpolate("should be at most " <> _rest, opts),
    do: "é longo demais (o limite é #{opts[:count]})"

  defp interpolate("should be at least " <> _rest, opts),
    do: "é curto demais (o mínimo é #{opts[:count]})"

  defp interpolate("must be greater than " <> _rest, opts),
    do: "precisa ser maior que #{opts[:number]}"

  defp interpolate("must be greater than or equal to " <> _rest, opts),
    do: "não pode ser menor que #{opts[:number]}"

  defp interpolate(message, opts) do
    Enum.reduce(opts, message, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end
