defmodule OGrupoDeEstudos.Engagement.Comments.StepComment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "step_comments" do
    field :body, :string
    field :deleted_at, :naive_datetime
    field :like_count, :integer, default: 0
    field :reply_count, :integer, default: 0

    belongs_to :user, OGrupoDeEstudos.Accounts.User
    belongs_to :step, OGrupoDeEstudos.Encyclopedia.Step
    belongs_to :parent_comment, __MODULE__, foreign_key: :parent_step_comment_id

    has_many :replies, __MODULE__, foreign_key: :parent_step_comment_id, where: [deleted_at: nil]

    timestamps()
  end

  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:body, :user_id, :step_id, :parent_step_comment_id])
    |> validate_required([:body, :user_id, :step_id])
    |> validate_length(:body, min: 1, max: 2000)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:step_id)
    |> foreign_key_constraint(:parent_step_comment_id)
  end
end
