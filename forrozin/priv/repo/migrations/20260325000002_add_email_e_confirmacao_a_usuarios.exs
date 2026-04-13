defmodule Forrozin.Repo.Migrations.AddEmailEConfirmacaoAUsuarios do
  use Ecto.Migration

  def change do
    alter table(:usuarios) do
      add :email, :string
      add :confirmation_token, :string
      add :confirmed_at, :naive_datetime
    end

    create unique_index(:usuarios, [:email])
    create unique_index(:usuarios, [:confirmation_token])
  end
end
