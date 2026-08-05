defmodule OGrupoDeEstudos.Workshops.ProgramEnrollment do
  @moduledoc """
  Membership in the package of a program.

  Whoever buys the package joins every workshop at once, and the payment becomes
  the payment of the set: the individual enrollments point at this row instead of
  each carrying its own payment state.

  `payment_status` and `paid_at` are private to whoever administers, by the same
  rule as `WorkshopEnrollment`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.Workshops.{WorkshopEnrollment, WorkshopProgram}

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "program_enrollments" do
    field :payment_status, Ecto.Enum, values: [:pending, :paid, :waived], default: :pending
    field :paid_at, :utc_datetime

    # Receipt of the package payment, by the same rule as the workshop one.
    field :receipt_key, :string
    field :receipt_content_type, :string
    field :receipt_byte_size, :integer
    field :receipt_sent_at, :utc_datetime

    belongs_to :program, WorkshopProgram
    belongs_to :user, User
    has_many :workshop_enrollments, WorkshopEnrollment

    timestamps(type: :utc_datetime_usec)
  end

  @doc "Payment is not castable here: the organizer changes it, from the panel."
  def changeset(enrollment, attrs) do
    enrollment
    |> cast(attrs, [:program_id, :user_id])
    |> validate_required([:program_id, :user_id])
    |> unique_constraint([:program_id, :user_id])
    |> foreign_key_constraint(:program_id)
    |> foreign_key_constraint(:user_id)
  end

  @doc "Changes the payment state of the package."
  def payment_changeset(enrollment, status) when status in [:pending, :paid, :waived] do
    change(enrollment, payment_status: status, paid_at: paid_at_for(status))
  end

  defp paid_at_for(:paid), do: DateTime.utc_now() |> DateTime.truncate(:second)
  defp paid_at_for(_status), do: nil
end
