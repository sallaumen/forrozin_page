defmodule OGrupoDeEstudos.Repo.Migrations.CreateWorkshopPrograms do
  use Ecto.Migration

  # Program: a handful of workshops under one name (a weekend, a festival). A
  # workshop belongs to zero or one program.
  #
  # No starts_at/ends_at here on purpose: the program dates are the min and max of
  # its children, and a denormalized column lies as soon as a workshop is
  # rescheduled or cancelled.
  def change do
    create table(:workshop_programs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :owner_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :slug, :string, null: false
      add :title, :string, null: false
      add :description, :text
      add :location, :string
      add :status, :string, null: false, default: "draft"

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists unique_index(:workshop_programs, [:slug])
    create_if_not_exists index(:workshop_programs, [:owner_id])

    # nilify_all: deleting the program releases the workshops, it does not destroy them.
    alter table(:workshops) do
      add :program_id, references(:workshop_programs, type: :binary_id, on_delete: :nilify_all)
    end

    create_if_not_exists index(:workshops, [:program_id, :starts_at])
  end
end
