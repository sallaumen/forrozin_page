defmodule OGrupoDeEstudos.Repo.Migrations.AddFlyers do
  use Ecto.Migration

  # Flyer de divulgacao. Guarda so o caminho publico: o arquivo mora no
  # storage, que hoje e o volume e amanha pode ser outro adapter.
  def change do
    alter table(:workshops) do
      add :flyer_path, :string
    end

    alter table(:workshop_programs) do
      add :flyer_path, :string
    end
  end
end
