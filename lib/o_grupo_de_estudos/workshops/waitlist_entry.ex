defmodule OGrupoDeEstudos.Workshops.WaitlistEntry do
  @moduledoc """
  A place in the waitlist of a full workshop.

  The position is not stored: it is the arrival order (`inserted_at`). Storing a
  number would require renumbering the whole queue on every exit, and the queue
  changes more than it is read.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.Workshops.Workshop

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "workshop_waitlist_entries" do
    belongs_to :workshop, Workshop
    belongs_to :user, User

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:workshop_id, :user_id])
    |> validate_required([:workshop_id, :user_id])
    |> unique_constraint([:workshop_id, :user_id])
    |> foreign_key_constraint(:workshop_id)
    |> foreign_key_constraint(:user_id)
  end
end
