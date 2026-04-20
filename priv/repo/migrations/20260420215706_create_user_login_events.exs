defmodule OGrupoDeEstudos.Repo.Migrations.CreateUserLoginEvents do
  use Ecto.Migration

  def change do
    create table(:user_login_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :method, :string, null: false
      add :device_type, :string
      add :browser, :string
      add :is_pwa, :boolean, null: false, default: false
      add :user_agent, :text
      add :occurred_at, :naive_datetime, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(updated_at: false)
    end

    create index(:user_login_events, [:user_id, :occurred_at])
    create index(:user_login_events, [:occurred_at])
    create index(:user_login_events, [:method])
  end
end
