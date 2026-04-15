defmodule Forrozin.Repo.Migrations.AddProfileFieldsAndComments do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :bio, :text
      add :instagram, :string
      add :avatar_path, :string
    end

    create table(:profile_comments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :body, :string, null: false, size: 2000
      add :deleted_at, :naive_datetime

      add :author_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :profile_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:profile_comments, [:profile_id])
    create index(:profile_comments, [:author_id])
  end
end
