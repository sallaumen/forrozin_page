defmodule Forrozin.Repo.Migrations.AddCountryToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :country, :string, default: "BR"
    end

    execute "UPDATE users SET country = 'BR' WHERE country IS NULL"
  end
end
