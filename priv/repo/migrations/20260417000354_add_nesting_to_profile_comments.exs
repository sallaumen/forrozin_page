defmodule OGrupoDeEstudos.Repo.Migrations.AddNestingToProfileComments do
  use Ecto.Migration

  def change do
    alter table(:profile_comments) do
      add :parent_profile_comment_id,
          references(:profile_comments, type: :binary_id, on_delete: :nilify_all)

      add :like_count, :integer, default: 0, null: false
      add :reply_count, :integer, default: 0, null: false
    end

    create index(:profile_comments, [:parent_profile_comment_id])

    create index(:profile_comments, ["like_count DESC", "inserted_at DESC"],
      name: :profile_comments_engagement_idx,
      where: "deleted_at IS NULL"
    )

    execute(
      """
      UPDATE profile_comments pc SET like_count = COALESCE((
        SELECT COUNT(*) FROM likes WHERE likeable_type = 'profile_comment' AND likeable_id = pc.id
      ), 0)
      """,
      ""
    )
  end
end
