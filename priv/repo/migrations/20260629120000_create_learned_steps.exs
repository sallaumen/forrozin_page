defmodule OGrupoDeEstudos.Repo.Migrations.CreateLearnedSteps do
  use Ecto.Migration

  def change do
    create table(:learned_steps, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :step_id, references(:steps, type: :binary_id, on_delete: :delete_all), null: false
      timestamps(updated_at: false)
    end

    create unique_index(:learned_steps, [:user_id, :step_id])
    create index(:learned_steps, [:user_id, :inserted_at])
  end
end
