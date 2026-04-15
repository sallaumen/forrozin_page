defmodule OGrupoDeEstudos.Encyclopedia.Category do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @required_fields [:name, :label, :color]

  schema "categories" do
    field :name, :string
    field :label, :string
    field :color, :string
    timestamps()
  end

  def changeset(category, attrs) do
    category
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:name)
  end
end
