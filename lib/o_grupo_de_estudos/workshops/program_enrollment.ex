defmodule OGrupoDeEstudos.Workshops.ProgramEnrollment do
  @moduledoc """
  Matrícula no pacote de uma programação.

  Quem compra o pacote entra em todos os workshops de uma vez, e o pagamento
  passa a ser do conjunto: as inscrições individuais apontam para esta linha
  em vez de cada uma ter o próprio estado de pagamento.

  `payment_status` e `paid_at` são privados de quem administra, pela mesma
  regra de `WorkshopEnrollment`.
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

    belongs_to :program, WorkshopProgram
    belongs_to :user, User
    has_many :workshop_enrollments, WorkshopEnrollment

    timestamps(type: :utc_datetime_usec)
  end

  @doc "Pagamento não é castável aqui: quem muda é o organizador, pelo painel."
  def changeset(enrollment, attrs) do
    enrollment
    |> cast(attrs, [:program_id, :user_id])
    |> validate_required([:program_id, :user_id])
    |> unique_constraint([:program_id, :user_id])
    |> foreign_key_constraint(:program_id)
    |> foreign_key_constraint(:user_id)
  end

  @doc "Muda o estado do pagamento do pacote."
  def payment_changeset(enrollment, status) when status in [:pending, :paid, :waived] do
    change(enrollment, payment_status: status, paid_at: paid_at_for(status))
  end

  defp paid_at_for(:paid), do: DateTime.utc_now() |> DateTime.truncate(:second)
  defp paid_at_for(_status), do: nil
end
