defmodule OGrupoDeEstudos.Workshops.JoinRequest do
  @moduledoc """
  Request to join a private workshop.

  A private workshop is not secret: it shows on the agenda like any other, with
  title, date and price in plain sight. What changes is the door. Whoever wants in
  asks, and whoever organizes decides.

  Approving already enrolls: the person who asked already said what they wanted,
  and a second confirmation would be bureaucracy for the same answer.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.Workshops.Workshop

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "workshop_join_requests" do
    belongs_to :workshop, Workshop
    belongs_to :user, User
    belongs_to :reviewed_by, User

    field :status, Ecto.Enum, values: [:pending, :approved, :rejected], default: :pending
    field :reviewed_at, :utc_datetime

    timestamps(type: :utc_datetime_usec)
  end

  @doc "Pedido novo: nasce pendente, sem quem revisou."
  def changeset(request, attrs) do
    request
    |> cast(attrs, [:workshop_id, :user_id, :status])
    |> validate_required([:workshop_id, :user_id])
    |> unique_constraint([:workshop_id, :user_id])
    |> foreign_key_constraint(:workshop_id)
    |> foreign_key_constraint(:user_id)
  end

  @doc "Answer from the organizer, stamped with who decided and when."
  def review_changeset(request, status, %User{id: reviewer_id}) do
    change(request, %{
      status: status,
      reviewed_by_id: reviewer_id,
      reviewed_at: DateTime.utc_now(:second)
    })
  end
end
