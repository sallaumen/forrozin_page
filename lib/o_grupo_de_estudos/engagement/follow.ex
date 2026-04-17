defmodule OGrupoDeEstudos.Engagement.Follow do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "follows" do
    belongs_to :follower, OGrupoDeEstudos.Accounts.User
    belongs_to :followed, OGrupoDeEstudos.Accounts.User
    timestamps(updated_at: false)
  end

  def changeset(follow, attrs) do
    follow
    |> cast(attrs, [:follower_id, :followed_id])
    |> validate_required([:follower_id, :followed_id])
    |> validate_not_self_follow()
    |> unique_constraint([:follower_id, :followed_id])
    |> foreign_key_constraint(:follower_id)
    |> foreign_key_constraint(:followed_id)
  end

  defp validate_not_self_follow(changeset) do
    follower = get_field(changeset, :follower_id)
    followed = get_field(changeset, :followed_id)

    if follower && followed && follower == followed do
      add_error(changeset, :followed_id, "não pode seguir a si mesmo")
    else
      changeset
    end
  end
end
