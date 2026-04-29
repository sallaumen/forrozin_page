defmodule OGrupoDeEstudos.Repo.Migrations.CreateDataMigrations do
  use Ecto.Migration

  def change do
    create table(:data_migrations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :started_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec
      add :result, :string, default: "pending"

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:data_migrations, [:name])
  end
end
