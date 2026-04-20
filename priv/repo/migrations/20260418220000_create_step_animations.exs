defmodule OGrupoDeEstudos.Repo.Migrations.CreateStepAnimations do
  use Ecto.Migration

  def change do
    create table(:step_animations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :step_id, references(:steps, type: :binary_id, on_delete: :delete_all), null: false
      add :keyframes, :jsonb, null: false
      add :duration_ms, :integer, default: 2000

      timestamps()
    end

    create unique_index(:step_animations, [:step_id])

    create table(:category_pose_defaults, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :category_id, references(:categories, type: :binary_id, on_delete: :delete_all),
        null: false

      add :keyframes, :jsonb, null: false
      add :duration_ms, :integer, default: 2000

      timestamps()
    end

    create unique_index(:category_pose_defaults, [:category_id])
  end
end
