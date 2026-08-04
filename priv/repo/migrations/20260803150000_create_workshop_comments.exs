defmodule OGrupoDeEstudos.Repo.Migrations.CreateWorkshopComments do
  use Ecto.Migration

  def change do
    create table(:workshop_comments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :body, :text, null: false
      add :deleted_at, :utc_datetime
      add :like_count, :integer, default: 0, null: false
      add :reply_count, :integer, default: 0, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :workshop_id, references(:workshops, type: :binary_id, on_delete: :delete_all),
        null: false

      add :parent_workshop_comment_id,
          references(:workshop_comments, type: :binary_id, on_delete: :nilify_all)

      # Naive on purpose: the thread component measures "5 min ago" with
      # NaiveDateTime.diff/3, like the other comment tables.
      timestamps()
    end

    create_if_not_exists index(:workshop_comments, [:user_id])
    create_if_not_exists index(:workshop_comments, [:parent_workshop_comment_id])

    create_if_not_exists index(
                           :workshop_comments,
                           [:workshop_id, "like_count DESC", "inserted_at DESC"],
                           name: :workshop_comments_engagement_idx,
                           where: "deleted_at IS NULL"
                         )
  end
end
