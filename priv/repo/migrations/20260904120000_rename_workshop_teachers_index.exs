defmodule OGrupoDeEstudos.Repo.Migrations.RenameWorkshopTeachersIndex do
  use Ecto.Migration

  # The index name reaches the code: `unique_constraint(name: ...)` has to match
  # it exactly, otherwise a duplicate raises instead of returning a changeset error.
  def up do
    execute """
    ALTER INDEX IF EXISTS workshop_teachers_conta_unica_index
    RENAME TO workshop_teachers_account_or_name_index
    """
  end

  def down do
    execute """
    ALTER INDEX IF EXISTS workshop_teachers_account_or_name_index
    RENAME TO workshop_teachers_conta_unica_index
    """
  end
end
