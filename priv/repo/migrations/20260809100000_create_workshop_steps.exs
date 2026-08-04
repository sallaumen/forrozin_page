defmodule OGrupoDeEstudos.Repo.Migrations.CreateWorkshopSteps do
  use Ecto.Migration

  # There was no relation at all between a workshop and a collection step: the diary
  # was the only place in the app where a step met a date. Whoever left a workshop
  # with five steps in their head had nowhere to record that.
  #
  # The workshop admin builds the list. Like-based curation was considered and
  # dropped: ordering by vote solves, with much more machinery, a problem the
  # permission already solves.
  def change do
    create table(:workshop_steps, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :workshop_id, references(:workshops, type: :binary_id, on_delete: :delete_all),
        null: false

      add :step_id, references(:steps, type: :binary_id, on_delete: :delete_all), null: false
      add :position, :integer, null: false, default: 0

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:workshop_steps, [:workshop_id, :step_id])
    # It is always read by workshop, in the order the teacher built.
    create index(:workshop_steps, [:workshop_id, :position])
    # And the way back: "where did I see this step?"
    create index(:workshop_steps, [:step_id])
  end
end
