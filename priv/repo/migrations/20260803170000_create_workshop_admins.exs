defmodule OGrupoDeEstudos.Repo.Migrations.CreateWorkshopAdmins do
  use Ecto.Migration

  # Co-organizers. The workshop `organizer_id` stays the creator and root owner:
  # swapping it for rows in this table would break the preload(:organizer) of four
  # queries, the search by teacher name and the whole UI, and would still require
  # a backfill. Only whoever was promoted afterwards goes in here.
  def change do
    create table(:workshop_admins, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :workshop_id, references(:workshops, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      # Who promoted them. If that account disappears, the link still holds.
      add :invited_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists unique_index(:workshop_admins, [:workshop_id, :user_id])
    create_if_not_exists index(:workshop_admins, [:user_id])
  end
end
