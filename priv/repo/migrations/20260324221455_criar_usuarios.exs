defmodule Forrozin.Repo.Migrations.CriarUsuarios do
  use Ecto.Migration

  def change do
    create table(:usuarios, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :nome_usuario, :string, null: false
      add :senha_hash, :string, null: false
      add :papel, :string, null: false, default: "user"

      timestamps()
    end

    create unique_index(:usuarios, [:nome_usuario])
  end
end
