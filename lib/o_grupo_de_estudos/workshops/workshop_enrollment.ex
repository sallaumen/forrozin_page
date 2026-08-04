defmodule OGrupoDeEstudos.Workshops.WorkshopEnrollment do
  @moduledoc """
  Enrollment of a person in a workshop.

  `payment_status` and `paid_at` are PRIVATE to the organizer: no public query
  projects those fields, and the enrollment changeset does not even accept them.
  What moves them is `payment_changeset/2`, called only by the management panel.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "workshop_enrollments" do
    field :payment_status, Ecto.Enum, values: [:pending, :paid, :waived], default: :pending
    field :paid_at, :utc_datetime
    # When the day-before reminder went out. Null means it has not gone out.
    field :reminded_at, :utc_datetime

    belongs_to :workshop, OGrupoDeEstudos.Workshops.Workshop
    belongs_to :user, OGrupoDeEstudos.Accounts.User
    # When present, this workshop is covered by the package payment.
    belongs_to :program_enrollment, OGrupoDeEstudos.Workshops.ProgramEnrollment

    timestamps(type: :utc_datetime_usec)
  end

  @doc "Enrollment: accepts nothing about payment, by construction."
  def changeset(enrollment, attrs) do
    enrollment
    |> cast(attrs, [:workshop_id, :user_id, :program_enrollment_id])
    |> validate_required([:workshop_id, :user_id])
    |> foreign_key_constraint(:workshop_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:workshop_id, :user_id],
      message: "esta pessoa já está inscrita"
    )
  end

  @doc "Internal payment control, organizer only."
  def payment_changeset(enrollment, status) when status in [:pending, :paid, :waived] do
    change(enrollment, payment_status: status, paid_at: paid_at_for(status))
  end

  defp paid_at_for(:paid), do: DateTime.utc_now() |> DateTime.truncate(:second)
  defp paid_at_for(_status), do: nil
end
