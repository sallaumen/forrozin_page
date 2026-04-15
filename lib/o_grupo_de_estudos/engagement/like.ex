defmodule OGrupoDeEstudos.Engagement.Like do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "likes" do
    field :likeable_type, :string
    field :likeable_id, :binary_id
    belongs_to :user, OGrupoDeEstudos.Accounts.User
    timestamps(updated_at: false)
  end

  def changeset(like, attrs) do
    like
    |> cast(attrs, [:user_id, :likeable_type, :likeable_id])
    |> validate_required([:user_id, :likeable_type, :likeable_id])
    |> validate_inclusion(:likeable_type, ["step", "sequence", "step_link", "profile_comment"])
    |> unique_constraint([:user_id, :likeable_type, :likeable_id],
      name: :likes_user_id_likeable_type_likeable_id_index
    )
  end
end
