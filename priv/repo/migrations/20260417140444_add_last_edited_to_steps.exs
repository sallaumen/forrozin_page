defmodule OGrupoDeEstudos.Repo.Migrations.AddLastEditedToSteps do
  use Ecto.Migration

  def change do
    alter table(:steps) do
      add :last_edited_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :last_edited_at, :naive_datetime
    end
  end
end
