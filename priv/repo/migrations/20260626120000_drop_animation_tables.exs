defmodule OGrupoDeEstudos.Repo.Migrations.DropAnimationTables do
  use Ecto.Migration

  # Remove as tabelas da visualização 3D de sequências (feature removida).
  # O `down` recria a estrutura (sem dados) para reversibilidade do schema.
  def up do
    drop table(:step_animations)
    drop table(:category_pose_defaults)
  end

  def down do
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
