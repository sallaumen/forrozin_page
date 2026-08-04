defmodule OGrupoDeEstudos.Repo.Migrations.CreateWorkshopWaitlist do
  use Ecto.Migration

  # A full class stops being a dead end: whoever arrives past the capacity joins a
  # waitlist, and the organizer starts seeing the pent-up demand (a long waitlist is
  # the signal that another class fits).
  #
  # Its own table, and not a status in workshop_enrollments, on purpose: dozens of
  # queries count enrolled people, and a "waiting" row living among the real
  # enrollments would make every count lie until the last one was fixed.
  def change do
    create table(:workshop_waitlist_entries, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :workshop_id, references(:workshops, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    # The waitlist order is the arrival order: no stored position, which would require
    # renumbering everyone on every exit.
    create unique_index(:workshop_waitlist_entries, [:workshop_id, :user_id])
    create index(:workshop_waitlist_entries, [:workshop_id, :inserted_at])
  end
end
