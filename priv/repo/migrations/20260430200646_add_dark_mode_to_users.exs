defmodule OGrupoDeEstudos.Repo.Migrations.AddDarkModeToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :dark_mode, :boolean, default: false, null: false
    end
  end
end
