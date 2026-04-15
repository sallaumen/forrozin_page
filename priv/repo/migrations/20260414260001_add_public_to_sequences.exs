defmodule Forrozin.Repo.Migrations.AddPublicToSequences do
  use Ecto.Migration

  def change do
    alter table(:sequences) do
      add :public, :boolean, default: true, null: false
    end
  end
end
