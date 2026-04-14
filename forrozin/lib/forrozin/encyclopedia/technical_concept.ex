defmodule Forrozin.Encyclopedia.TechnicalConcept do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @required_fields [:title, :description]

  schema "conceitos_tecnicos" do
    field :title, :string
    field :description, :string
    timestamps()
  end

  def changeset(concept, attrs) do
    concept
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
  end
end
