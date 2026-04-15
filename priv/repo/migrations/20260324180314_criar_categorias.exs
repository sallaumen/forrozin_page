defmodule Forrozin.Repo.Migrations.CriarCategorias do
  use Ecto.Migration

  def change do
    create table(:categorias, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :nome, :string, null: false
      add :rotulo, :string, null: false
      add :cor, :string, null: false

      timestamps()
    end

    create unique_index(:categorias, [:nome])
  end
end
