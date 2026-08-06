defmodule OGrupoDeEstudos.Repo.Migrations.CreateProgramAdmins do
  use Ecto.Migration

  # Co-organizers of a program, by the same rule as `workshop_admins`: the
  # program `owner_id` stays the creator and root owner, and only whoever was
  # promoted afterwards goes in here.
  #
  # Administering a program does not administer the workshops inside it. Those
  # can belong to other teachers, and each one keeps its own invitation.
  def change do
    create table(:program_admins, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :program_id, references(:workshop_programs, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      # Who promoted them. If that account disappears, the link still holds.
      add :invited_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists unique_index(:program_admins, [:program_id, :user_id])
    create_if_not_exists index(:program_admins, [:user_id])
  end
end
