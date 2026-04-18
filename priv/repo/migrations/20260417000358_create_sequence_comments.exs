defmodule OGrupoDeEstudos.Repo.Migrations.CreateSequenceComments do
  use Ecto.Migration

  def change do
    create table(:sequence_comments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :body, :text, null: false
      add :deleted_at, :naive_datetime
      add :like_count, :integer, default: 0, null: false
      add :reply_count, :integer, default: 0, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :sequence_id, references(:sequences, type: :binary_id, on_delete: :delete_all),
        null: false

      add :parent_sequence_comment_id,
          references(:sequence_comments, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create index(:sequence_comments, [:user_id])
    create index(:sequence_comments, [:parent_sequence_comment_id])

    create index(:sequence_comments, [:sequence_id, "like_count DESC", "inserted_at DESC"],
             name: :sequence_comments_engagement_idx,
             where: "deleted_at IS NULL"
           )

    create index(:sequence_comments, [:parent_sequence_comment_id, :inserted_at],
             name: :sequence_comments_parent_idx,
             where: "parent_sequence_comment_id IS NOT NULL"
           )
  end
end
