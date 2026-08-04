defmodule OGrupoDeEstudos.Repo.Migrations.AddFlyers do
  use Ecto.Migration

  # Promotional flyer. It stores only the public path: the file lives in the
  # storage, which today is the volume and tomorrow may be another adapter.
  def change do
    alter table(:workshops) do
      add :flyer_path, :string
    end

    alter table(:workshop_programs) do
      add :flyer_path, :string
    end
  end
end
