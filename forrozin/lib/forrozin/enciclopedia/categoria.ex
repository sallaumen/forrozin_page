defmodule Forrozin.Enciclopedia.Categoria do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "categorias" do
    field :nome, :string
    field :rotulo, :string
    field :cor, :string

    timestamps()
  end

  @campos_obrigatorios [:nome, :rotulo, :cor]

  @doc """
  Valida e prepara uma categoria para inserção ou atualização.

  Campos obrigatórios: nome, rotulo, cor.
  O nome deve ser único — é o identificador interno (ex: "sacadas", "bases").
  O rótulo é o texto exibido ao usuário (ex: "Sacadas", "Bases").
  """
  def changeset(categoria, attrs) do
    categoria
    |> cast(attrs, @campos_obrigatorios)
    |> validate_required(@campos_obrigatorios)
    |> unique_constraint(:nome)
  end
end
