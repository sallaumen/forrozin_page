defmodule OGrupoDeEstudos.Repo.Migrations.AddWorkshopVisibility do
  use Ecto.Migration

  # Public versus private. A separate column from status on purpose: status is the
  # life cycle (draft, published, cancelled), visibility is who can see. A private
  # workshop still has to accept enrollment and conversation normally.
  def change do
    alter table(:workshops) do
      add :visibility, :string, null: false, default: "public"
    end

    create table(:workshop_invites, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :workshop_id, references(:workshops, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :invited_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists unique_index(:workshop_invites, [:workshop_id, :user_id])
    create_if_not_exists index(:workshop_invites, [:user_id])
  end
end
