defmodule Forrozin.Repo.Migrations.AddRotuloEDescricaoAConexoes do
  use Ecto.Migration

  def change do
    alter table(:conexoes_passos) do
      add :rotulo, :string, null: true
      add :descricao, :text, null: true
    end
  end
end
