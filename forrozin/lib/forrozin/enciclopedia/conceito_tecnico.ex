defmodule Forrozin.Enciclopedia.ConceitoTecnico do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "conceitos_tecnicos" do
    field :titulo, :string
    field :descricao, :string

    timestamps()
  end

  @campos_obrigatorios [:titulo, :descricao]

  @doc """
  Valida um conceito técnico de condução.

  Conceitos não são passos — são princípios que explicam a mecânica
  da dança (ex: intenção de sacada, elástico, transferência de peso).
  """
  def changeset(conceito, attrs) do
    conceito
    |> cast(attrs, @campos_obrigatorios)
    |> validate_required(@campos_obrigatorios)
    |> unique_constraint(:titulo)
  end
end
