defmodule Forrozin.Repo.Migrations.CriarPassos do
  use Ecto.Migration

  def change do
    create table(:passos, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :codigo, :string, null: false
      add :nome, :string, null: false
      add :nota, :text
      add :wip, :boolean, null: false, default: false
      add :caminho_imagem, :string
      add :status, :string, null: false, default: "publicado"
      add :posicao, :integer, null: false, default: 0
      add :categoria_id, references(:categorias, type: :binary_id, on_delete: :restrict)
      add :secao_id, references(:secoes, type: :binary_id, on_delete: :restrict)
      add :subsecao_id, references(:subsecoes, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create unique_index(:passos, [:codigo])
    create index(:passos, [:categoria_id])
    create index(:passos, [:secao_id])
    create index(:passos, [:subsecao_id])
    create index(:passos, [:wip])
    create index(:passos, [:status])
  end
end
