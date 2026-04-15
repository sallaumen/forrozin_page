defmodule Forrozin.Repo.Migrations.CriarSubsecoes do
  use Ecto.Migration

  def change do
    create table(:subsecoes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :titulo, :string, null: false
      add :nota, :text
      add :posicao, :integer, null: false, default: 0
      add :secao_id, references(:secoes, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:subsecoes, [:secao_id])
    create index(:subsecoes, [:posicao])
  end
end
