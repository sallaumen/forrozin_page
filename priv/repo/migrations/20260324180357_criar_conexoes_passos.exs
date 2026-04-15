defmodule Forrozin.Repo.Migrations.CriarConexoesPassos do
  use Ecto.Migration

  def change do
    create table(:conexoes_passos, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tipo, :string, null: false

      add :passo_origem_id, references(:passos, type: :binary_id, on_delete: :delete_all),
        null: false

      add :passo_destino_id, references(:passos, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps()
    end

    create index(:conexoes_passos, [:passo_origem_id])
    create index(:conexoes_passos, [:passo_destino_id])
    create unique_index(:conexoes_passos, [:passo_origem_id, :passo_destino_id, :tipo])
  end
end
