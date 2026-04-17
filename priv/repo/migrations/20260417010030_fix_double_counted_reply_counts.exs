defmodule OGrupoDeEstudos.Repo.Migrations.FixDoubleCountedReplyCounts do
  use Ecto.Migration

  def up do
    for table <- ~w(step_comments sequence_comments profile_comments) do
      parent_field = "parent_#{table |> String.replace_suffix("s", "")}_id"

      execute("""
      UPDATE #{table} t
      SET reply_count = COALESCE((
        SELECT COUNT(*) FROM #{table}
        WHERE #{parent_field} = t.id
      ), 0)
      """)
    end
  end

  def down, do: :ok
end
