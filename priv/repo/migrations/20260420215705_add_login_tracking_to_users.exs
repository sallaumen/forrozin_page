defmodule OGrupoDeEstudos.Repo.Migrations.AddLoginTrackingToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :last_seen_at, :naive_datetime
      add :last_login_at, :naive_datetime
    end

    create index(:users, [:last_seen_at])
    create index(:users, [:last_login_at])
  end
end
