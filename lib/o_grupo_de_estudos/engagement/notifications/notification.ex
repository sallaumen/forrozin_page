defmodule OGrupoDeEstudos.Engagement.Notifications.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "notifications" do
    field :action, :string
    field :group_key, :string
    field :target_type, :string
    field :target_id, :binary_id
    field :parent_type, :string
    field :parent_id, :binary_id
    field :read_at, :naive_datetime

    belongs_to :user, OGrupoDeEstudos.Accounts.User
    belongs_to :actor, OGrupoDeEstudos.Accounts.User

    timestamps(updated_at: false)
  end

  @valid_actions ~w(liked_comment replied_comment liked_step liked_sequence followed_user suggestion_created suggestion_approved suggestion_rejected study_request study_accepted)
  @valid_target_types ~w(step_comment sequence_comment profile_comment step sequence profile suggestion study_link)
  @valid_parent_types ~w(step sequence profile suggestion study_link)

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [
      :action,
      :group_key,
      :target_type,
      :target_id,
      :parent_type,
      :parent_id,
      :user_id,
      :actor_id,
      :read_at
    ])
    |> validate_required([
      :action,
      :group_key,
      :target_type,
      :target_id,
      :parent_type,
      :parent_id,
      :user_id,
      :actor_id
    ])
    |> validate_inclusion(:action, @valid_actions)
    |> validate_inclusion(:target_type, @valid_target_types)
    |> validate_inclusion(:parent_type, @valid_parent_types)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:actor_id)
  end
end
