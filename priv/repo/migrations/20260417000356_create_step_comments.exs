defmodule OGrupoDeEstudos.Repo.Migrations.CreateStepComments do
  use Ecto.Migration

  def change do
    create table(:step_comments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :body, :text, null: false
      add :deleted_at, :naive_datetime
      add :like_count, :integer, default: 0, null: false
      add :reply_count, :integer, default: 0, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :step_id, references(:steps, type: :binary_id, on_delete: :delete_all), null: false

      add :parent_step_comment_id,
          references(:step_comments, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create index(:step_comments, [:user_id])
    create index(:step_comments, [:parent_step_comment_id])

    create index(:step_comments, [:step_id, "like_count DESC", "inserted_at DESC"],
             name: :step_comments_engagement_idx,
             where: "deleted_at IS NULL"
           )

    create index(:step_comments, [:parent_step_comment_id, :inserted_at],
             name: :step_comments_parent_idx,
             where: "parent_step_comment_id IS NOT NULL"
           )
  end
end
