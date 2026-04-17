defmodule OGrupoDeEstudos.Engagement.Favorite do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_types ~w(step sequence step_link profile_comment step_comment sequence_comment)

  schema "favorites" do
    field :favoritable_type, :string
    field :favoritable_id, :binary_id
    belongs_to :user, OGrupoDeEstudos.Accounts.User
    timestamps(updated_at: false)
  end

  def changeset(favorite, attrs) do
    favorite
    |> cast(attrs, [:user_id, :favoritable_type, :favoritable_id])
    |> validate_required([:user_id, :favoritable_type, :favoritable_id])
    |> validate_inclusion(:favoritable_type, @valid_types)
    |> unique_constraint([:user_id, :favoritable_type, :favoritable_id],
      name: :favorites_user_id_favoritable_type_favoritable_id_index
    )
  end
end
