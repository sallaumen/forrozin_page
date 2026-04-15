defmodule Forrozin.Repo.Migrations.CriarConceitosTecnicos do
  use Ecto.Migration

  def change do
    create table(:conceitos_tecnicos, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :titulo, :string, null: false
      add :descricao, :text, null: false

      timestamps()
    end

    create unique_index(:conceitos_tecnicos, [:titulo])

    create table(:conceitos_passos, primary_key: false) do
      add :conceito_id, references(:conceitos_tecnicos, type: :binary_id, on_delete: :delete_all),
        null: false

      add :passo_id, references(:passos, type: :binary_id, on_delete: :delete_all), null: false
    end

    create unique_index(:conceitos_passos, [:conceito_id, :passo_id])
  end
end
