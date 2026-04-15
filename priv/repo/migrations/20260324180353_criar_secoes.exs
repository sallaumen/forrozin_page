defmodule Forrozin.Repo.Migrations.CriarSecoes do
  use Ecto.Migration

  def change do
    create table(:secoes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :num, :integer
      add :titulo, :string, null: false
      add :codigo, :string
      add :descricao, :text
      add :nota, :text
      add :posicao, :integer, null: false, default: 0
      add :categoria_id, references(:categorias, type: :binary_id, on_delete: :restrict)

      timestamps()
    end

    create index(:secoes, [:categoria_id])
    create index(:secoes, [:posicao])
  end
end
