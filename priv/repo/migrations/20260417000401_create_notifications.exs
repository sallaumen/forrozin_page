defmodule OGrupoDeEstudos.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :action, :string, null: false
      add :group_key, :string, null: false
      add :target_type, :string, null: false
      add :target_id, :binary_id, null: false
      add :parent_type, :string, null: false
      add :parent_id, :binary_id, null: false
      add :read_at, :naive_datetime
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :actor_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(updated_at: false)
    end

    create index(:notifications, [:user_id, :read_at, :inserted_at],
             name: :notifications_user_feed_idx
           )

    create index(:notifications, [:user_id, :group_key], name: :notifications_user_group_idx)

    create index(:notifications, [:actor_id, :target_type, :target_id],
             name: :notifications_actor_target_idx
           )
  end
end
