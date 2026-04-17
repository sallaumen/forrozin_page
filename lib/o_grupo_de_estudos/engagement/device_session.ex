defmodule OGrupoDeEstudos.Engagement.DeviceSession do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "device_sessions" do
    field :device_type, :string
    field :browser, :string
    field :is_pwa, :boolean, default: false
    field :user_agent, :string
    belongs_to :user, OGrupoDeEstudos.Accounts.User
    timestamps(updated_at: false)
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:device_type, :browser, :is_pwa, :user_agent, :user_id])
    |> validate_required([:device_type, :user_id])
    |> validate_inclusion(:device_type, ~w(mobile desktop tablet))
  end
end
