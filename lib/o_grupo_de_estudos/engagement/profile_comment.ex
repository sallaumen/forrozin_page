defmodule OGrupoDeEstudos.Engagement.ProfileComment do
  @moduledoc """
  A comment posted on a user's profile page.

  Supports soft-deletion via `deleted_at`. When `deleted_at` is set the
  comment is considered removed and should not be displayed publicly.

  Supports nesting via `parent_profile_comment_id` (one level deep in the UI,
  but the schema is unbounded). `like_count` and `reply_count` are maintained
  automatically by database triggers.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "profile_comments" do
    field :body, :string
    field :deleted_at, :naive_datetime
    field :like_count, :integer, default: 0
    field :reply_count, :integer, default: 0

    belongs_to :author, OGrupoDeEstudos.Accounts.User
    belongs_to :profile, OGrupoDeEstudos.Accounts.User

    belongs_to :parent_comment, __MODULE__, foreign_key: :parent_profile_comment_id

    has_many :replies, __MODULE__,
      foreign_key: :parent_profile_comment_id,
      where: [deleted_at: nil]

    timestamps()
  end

  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:body, :author_id, :profile_id, :parent_profile_comment_id])
    |> validate_required([:body, :author_id, :profile_id])
    |> validate_length(:body, min: 1, max: 2000)
    |> foreign_key_constraint(:author_id)
    |> foreign_key_constraint(:profile_id)
    |> foreign_key_constraint(:parent_profile_comment_id)
  end
end
