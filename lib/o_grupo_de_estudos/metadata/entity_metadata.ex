defmodule OGrupoDeEstudos.Metadata.EntityMetadata do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "entity_metadata" do
    field :entity_name, :string
    field :entity_key_type, :string
    field :entity_key, :string
    field :entity_value, :string, default: "0"

    timestamps()
  end

  def changeset(metadata, attrs) do
    metadata
    |> cast(attrs, [:entity_name, :entity_key_type, :entity_key, :entity_value])
    |> validate_required([:entity_name, :entity_key_type, :entity_key, :entity_value])
    |> unique_constraint([:entity_name, :entity_key_type, :entity_key])
  end
end
