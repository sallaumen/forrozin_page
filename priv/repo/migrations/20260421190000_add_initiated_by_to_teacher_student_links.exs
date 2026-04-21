defmodule OGrupoDeEstudos.Repo.Migrations.AddInitiatedByToTeacherStudentLinks do
  use Ecto.Migration

  def change do
    alter table(:teacher_student_links) do
      add :initiated_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
    end
  end
end
