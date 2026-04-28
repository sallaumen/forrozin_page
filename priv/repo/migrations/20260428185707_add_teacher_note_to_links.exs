defmodule OGrupoDeEstudos.Repo.Migrations.AddTeacherNoteToLinks do
  use Ecto.Migration

  def change do
    alter table(:teacher_student_links) do
      add :teacher_note, :text, default: ""
    end
  end
end
