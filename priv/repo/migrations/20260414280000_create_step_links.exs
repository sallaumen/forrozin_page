defmodule Forrozin.Repo.Migrations.CreateStepLinks do
  use Ecto.Migration

  def change do
    create table(:step_links, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :url, :string, null: false
      add :title, :string
      add :approved, :boolean, default: false, null: false
      add :deleted_at, :naive_datetime

      add :step_id, references(:steps, type: :binary_id, on_delete: :delete_all), null: false

      add :submitted_by_id, references(:users, type: :binary_id, on_delete: :nilify_all),
        null: false

      timestamps()
    end

    create index(:step_links, [:step_id])
    create index(:step_links, [:submitted_by_id])
    create index(:step_links, [:approved])
  end
end
