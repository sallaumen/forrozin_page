defmodule OGrupoDeEstudos.Repo.Migrations.AddTeacherRemindedAtToWorkshops do
  use Ecto.Migration

  def change do
    alter table(:workshops) do
      add :teacher_reminded_at, :utc_datetime
    end
  end
end
