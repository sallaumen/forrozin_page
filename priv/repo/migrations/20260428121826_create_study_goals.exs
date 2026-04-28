defmodule OGrupoDeEstudos.Repo.Migrations.CreateStudyGoals do
  use Ecto.Migration

  def change do
    create table(:study_goals, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :body, :text, null: false
      add :completed, :boolean, default: false, null: false
      add :position, :integer, default: 0, null: false
      add :owner_user_id, references(:users, type: :binary_id, on_delete: :delete_all)

      add :teacher_student_link_id,
          references(:teacher_student_links, type: :binary_id, on_delete: :delete_all)

      timestamps(type: :utc_datetime_usec)
    end

    create index(:study_goals, [:owner_user_id])
    create index(:study_goals, [:teacher_student_link_id])
  end
end
