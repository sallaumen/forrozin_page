defmodule OGrupoDeEstudos.Repo.Migrations.RemoveLikeNotifications do
  use Ecto.Migration

  def up do
    execute("""
    DELETE FROM notifications
    WHERE action IN ('liked_step', 'liked_sequence', 'liked_comment')
    """)
  end

  def down do
    :ok
  end
end
