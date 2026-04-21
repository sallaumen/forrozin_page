defmodule OGrupoDeEstudos.Repo.Migrations.AddPendingToTeacherStudentLinks do
  use Ecto.Migration

  def change do
    alter table(:teacher_student_links) do
      add :pending, :boolean, default: false, null: false
    end
  end
end
