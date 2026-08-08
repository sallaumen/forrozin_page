defmodule OGrupoDeEstudos.Engagement.Notifications.Notification do
  use Ecto.Schema

  @type t :: %__MODULE__{}
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "notifications" do
    field :action, Ecto.Enum,
      values: [
        :replied_comment,
        :liked_comment,
        :liked_step,
        :liked_sequence,
        :followed_user,
        :study_request,
        :study_accepted,
        :study_nudge,
        :shared_note_updated,
        :lesson_shared,
        :workshop_enrolled,
        :workshop_commented,
        :liked_workshop,
        :workshop_reminder,
        :workshop_today_reminder,
        :workshop_join_requested,
        :workshop_join_approved,
        :workshop_join_rejected,
        :workshop_waitlist_promoted,
        :receipt_sent,
        :suggestion_created,
        :suggestion_approved,
        :suggestion_rejected
      ]

    field :group_key, :string
    field :target_type, :string
    field :target_id, :binary_id
    field :parent_type, :string
    field :parent_id, :binary_id
    field :read_at, :utc_datetime

    belongs_to :user, OGrupoDeEstudos.Accounts.User
    belongs_to :actor, OGrupoDeEstudos.Accounts.User

    timestamps(updated_at: false)
  end

  @valid_target_types ~w(step_comment sequence_comment profile_comment workshop_comment step sequence profile workshop program suggestion study_link lesson)
  @valid_parent_types ~w(step sequence profile workshop program suggestion study_link)

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
    |> validate_inclusion(:target_type, @valid_target_types)
    |> validate_inclusion(:parent_type, @valid_parent_types)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:actor_id)
  end
end
