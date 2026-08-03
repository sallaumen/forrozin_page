defmodule OGrupoDeEstudos.Workshops.WorkshopEnrollment do
  @moduledoc """
  Inscrição de uma pessoa num workshop.

  `payment_status` e `paid_at` são PRIVADOS do organizador: nenhuma consulta
  pública projeta esses campos, e o changeset de inscrição nem os aceita —
  quem os move é `payment_changeset/2`, chamado só pelo painel de gestão.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "workshop_enrollments" do
    field :payment_status, Ecto.Enum, values: [:pending, :paid, :waived], default: :pending
    field :paid_at, :utc_datetime

    belongs_to :workshop, OGrupoDeEstudos.Workshops.Workshop
    belongs_to :user, OGrupoDeEstudos.Accounts.User

    timestamps(type: :utc_datetime_usec)
  end

  @doc "Inscrição: não aceita nada de pagamento, por construção."
  def changeset(enrollment, attrs) do
    enrollment
    |> cast(attrs, [:workshop_id, :user_id])
    |> validate_required([:workshop_id, :user_id])
    |> foreign_key_constraint(:workshop_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:workshop_id, :user_id],
      message: "esta pessoa já está inscrita"
    )
  end

  @doc "Controle interno de pagamento, só pelo organizador."
  def payment_changeset(enrollment, status) when status in [:pending, :paid, :waived] do
    change(enrollment, payment_status: status, paid_at: paid_at_for(status))
  end

  defp paid_at_for(:paid), do: DateTime.utc_now() |> DateTime.truncate(:second)
  defp paid_at_for(_status), do: nil
end
