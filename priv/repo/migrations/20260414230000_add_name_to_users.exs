defmodule Forrozin.Repo.Migrations.AddNameToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :name, :string
    end

    # Backfill existing users with username as name
    execute "UPDATE users SET name = username WHERE name IS NULL"
  end
end
