defmodule OGrupoDeEstudos.Repo.Migrations.CreateDeviceSessions do
  use Ecto.Migration

  def change do
    create table(:device_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :device_type, :string, null: false
      add :browser, :string
      add :is_pwa, :boolean, default: false
      add :user_agent, :text
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      timestamps(updated_at: false)
    end

    create index(:device_sessions, [:user_id, :inserted_at])
  end
end
