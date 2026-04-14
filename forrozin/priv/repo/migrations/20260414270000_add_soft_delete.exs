defmodule Forrozin.Repo.Migrations.AddSoftDelete do
  use Ecto.Migration

  def change do
    alter table(:steps) do
      add :deleted_at, :naive_datetime
    end

    alter table(:step_connections) do
      add :deleted_at, :naive_datetime
    end

    alter table(:sequences) do
      add :deleted_at, :naive_datetime
    end

    alter table(:sequence_steps) do
      add :deleted_at, :naive_datetime
    end

    create index(:steps, [:deleted_at])
    create index(:step_connections, [:deleted_at])
    create index(:sequences, [:deleted_at])
  end
end
