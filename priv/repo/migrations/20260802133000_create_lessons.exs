defmodule OGrupoDeEstudos.Repo.Migrations.CreateLessons do
  use Ecto.Migration

  def change do
    create table(:lessons, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :content, :text, null: false

      add :teacher_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists index(:lessons, [:teacher_id, :inserted_at])

    create table(:lesson_deliveries, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :lesson_id, references(:lessons, type: :binary_id, on_delete: :delete_all), null: false

      add :teacher_student_link_id,
          references(:teacher_student_links, type: :binary_id, on_delete: :delete_all),
          null: false

      add :read_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists unique_index(:lesson_deliveries, [:lesson_id, :teacher_student_link_id])
    create_if_not_exists index(:lesson_deliveries, [:teacher_student_link_id, :inserted_at])
  end
end
