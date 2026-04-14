defmodule Forrozin.Repo.Migrations.AddCityStateToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :state, :string, size: 2
      add :city, :string
    end
  end
end
