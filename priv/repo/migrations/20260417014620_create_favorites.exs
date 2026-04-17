defmodule OGrupoDeEstudos.Repo.Migrations.CreateFavorites do
  use Ecto.Migration

  def change do
    create table(:favorites, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :favoritable_type, :string, null: false
      add :favoritable_id, :binary_id, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      timestamps(updated_at: false)
    end

    create unique_index(:favorites, [:user_id, :favoritable_type, :favoritable_id])
    create index(:favorites, [:user_id, :favoritable_type, :inserted_at])
  end
end
