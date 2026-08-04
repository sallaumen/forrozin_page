defmodule OGrupoDeEstudos.Repo.Migrations.CreateSequenceCitations do
  use Ecto.Migration

  # Three tables already tie a STEP to the study side (workshop_steps, lesson_steps,
  # study_note_steps) and none tied a SEQUENCE to anything: it only existed inside the
  # map. A step is a word; a sequence is the sentence that worked on a given day, and
  # that is the thing a student most wants to find again.
  #
  # One table per host, following the project precedent for the same shape (comments
  # do it that way): no polymorphic parent.
  #
  # No position column on purpose. A note or a class cites one or two sequences, and
  # arrival order answers it; ordering can be added the day someone needs to drag them.
  #
  # The FK to sequences is delete_all in one direction only: dropping a workshop drops
  # the citation, never the sequence, which belongs to the person who built it.
  def change do
    create table(:workshop_sequences, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :workshop_id, references(:workshops, type: :binary_id, on_delete: :delete_all),
        null: false

      add :sequence_id, references(:sequences, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:workshop_sequences, [:workshop_id, :sequence_id])
    create index(:workshop_sequences, [:sequence_id])

    create table(:lesson_sequences, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :lesson_id, references(:lessons, type: :binary_id, on_delete: :delete_all), null: false

      add :sequence_id, references(:sequences, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:lesson_sequences, [:lesson_id, :sequence_id])
    create index(:lesson_sequences, [:sequence_id])

    create table(:study_note_sequences, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :study_note_id, references(:study_notes, type: :binary_id, on_delete: :delete_all),
        null: false

      add :sequence_id, references(:sequences, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:study_note_sequences, [:study_note_id, :sequence_id])
    create index(:study_note_sequences, [:sequence_id])
  end
end
