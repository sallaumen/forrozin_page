defmodule Forrozin.Engagement.ProfileComment do
  @moduledoc """
  A comment posted on a user's profile page.

  Supports soft-deletion via `deleted_at`. When `deleted_at` is set the
  comment is considered removed and should not be displayed publicly.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "profile_comments" do
    field :body, :string
    field :deleted_at, :naive_datetime
    belongs_to :author, Forrozin.Accounts.User
    belongs_to :profile, Forrozin.Accounts.User

    timestamps()
  end

  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:body, :author_id, :profile_id])
    |> validate_required([:body, :author_id, :profile_id])
    |> validate_length(:body, min: 1, max: 2000)
    |> foreign_key_constraint(:author_id)
    |> foreign_key_constraint(:profile_id)
  end
end
