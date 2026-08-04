defmodule OGrupoDeEstudos.Repo.Migrations.CreateLessonSteps do
  use Ecto.Migration

  def change do
    create table(:lesson_steps, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :lesson_id, references(:lessons, type: :binary_id, on_delete: :delete_all), null: false
      add :step_id, references(:steps, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:lesson_steps, [:lesson_id, :step_id])
    create index(:lesson_steps, [:step_id])
  end
end
