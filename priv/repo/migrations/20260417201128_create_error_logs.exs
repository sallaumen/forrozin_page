defmodule OGrupoDeEstudos.Repo.Migrations.CreateErrorLogs do
  use Ecto.Migration

  def change do
    create table(:error_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :level, :string, null: false
      add :message, :text, null: false
      add :source, :string
      add :stacktrace, :text
      add :metadata, :map, default: %{}
      timestamps(updated_at: false)
    end

    create index(:error_logs, [:inserted_at])
    create index(:error_logs, [:level])
  end
end
