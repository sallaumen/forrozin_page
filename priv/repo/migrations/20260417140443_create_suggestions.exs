defmodule OGrupoDeEstudos.Repo.Migrations.CreateSuggestions do
  use Ecto.Migration

  def change do
    create table(:suggestions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :target_type, :string, null: false
      add :target_id, :binary_id, null: false
      add :action, :string, null: false
      add :field, :string
      add :old_value, :text
      add :new_value, :text
      add :status, :string, null: false, default: "pending"
      add :reviewed_at, :naive_datetime

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :reviewed_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create index(:suggestions, [:status, :inserted_at])
    create index(:suggestions, [:user_id, :inserted_at])
    create index(:suggestions, [:target_type, :target_id])
  end
end
