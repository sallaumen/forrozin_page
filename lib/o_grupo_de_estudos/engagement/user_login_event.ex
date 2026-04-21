defmodule OGrupoDeEstudos.Engagement.UserLoginEvent do
  @moduledoc """
  Immutable audit record for each successful user login.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @methods ~w(password auto_login)
  @device_types ~w(mobile desktop tablet)

  schema "user_login_events" do
    field :method, :string
    field :device_type, :string
    field :browser, :string
    field :is_pwa, :boolean, default: false
    field :user_agent, :string
    field :occurred_at, :naive_datetime

    belongs_to :user, OGrupoDeEstudos.Accounts.User

    timestamps(updated_at: false)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :method,
      :device_type,
      :browser,
      :is_pwa,
      :user_agent,
      :occurred_at,
      :user_id
    ])
    |> validate_required([:method, :occurred_at, :user_id])
    |> validate_inclusion(:method, @methods)
    |> validate_inclusion(:device_type, @device_types)
    |> validate_length(:user_agent, max: 500)
  end
end
