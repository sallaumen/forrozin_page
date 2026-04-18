defmodule OGrupoDeEstudos.Repo.Migrations.AddLikeCountToStepsAndSequences do
  use Ecto.Migration

  def change do
    alter table(:steps) do
      add :like_count, :integer, default: 0, null: false
    end

    alter table(:sequences) do
      add :like_count, :integer, default: 0, null: false
    end

    execute(
      """
      UPDATE steps s SET like_count = COALESCE((
        SELECT COUNT(*) FROM likes WHERE likeable_type = 'step' AND likeable_id = s.id
      ), 0)
      """,
      ""
    )

    execute(
      """
      UPDATE sequences s SET like_count = COALESCE((
        SELECT COUNT(*) FROM likes WHERE likeable_type = 'sequence' AND likeable_id = s.id
      ), 0)
      """,
      ""
    )

    create index(:steps, ["like_count DESC", "inserted_at DESC"],
             name: :steps_engagement_idx,
             where: "status = 'published' AND wip = false"
           )

    create index(:sequences, ["like_count DESC", "inserted_at DESC"],
             name: :sequences_engagement_idx,
             where: "deleted_at IS NULL"
           )
  end
end
