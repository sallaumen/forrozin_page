defmodule OGrupoDeEstudos.Repo.Migrations.ClearHfStepImages do
  use Ecto.Migration

  def up do
    execute("""
    UPDATE steps
    SET image_path = NULL, updated_at = NOW()
    WHERE code LIKE 'HF-%'
      AND image_path IS NOT NULL
    """)
  end

  def down do
    :ok
  end
end
