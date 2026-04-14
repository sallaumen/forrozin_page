defmodule Forrozin.Repo.Migrations.CreateSequences do
  use Ecto.Migration

  def change do
    create table(:sequences, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :allow_repeats, :boolean, default: false, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:sequences, [:user_id])

    create table(:sequence_steps, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :position, :integer, null: false
      add :sequence_id, references(:sequences, type: :binary_id, on_delete: :delete_all), null: false
      add :step_id, references(:steps, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(updated_at: false)
    end

    create index(:sequence_steps, [:sequence_id])
    create unique_index(:sequence_steps, [:sequence_id, :position])
  end
end
