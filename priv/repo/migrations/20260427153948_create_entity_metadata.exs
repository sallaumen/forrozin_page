defmodule OGrupoDeEstudos.Repo.Migrations.CreateEntityMetadata do
  use Ecto.Migration

  def change do
    create table(:entity_metadata, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :entity_name, :string, null: false
      add :entity_key_type, :string, null: false
      add :entity_key, :string, null: false
      add :entity_value, :string, null: false, default: "0"

      timestamps()
    end

    create unique_index(:entity_metadata, [:entity_name, :entity_key_type, :entity_key])
  end
end
