defmodule OGrupoDeEstudos.Workshops.PackageQuery do
  @moduledoc """
  Leituras de `ProgramEnrollment`, a matrícula no pacote.

  Como em `EnrollmentQuery`, a listagem projeta os campos explicitamente: o
  estado de pagamento é privado de quem administra, e um `select` explícito
  impede que ele vaze por preload distraído.
  """

  import Ecto.Query

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Workshops.ProgramEnrollment

  @doc "Quem comprou o pacote, com dados de exibição e estado de pagamento."
  @spec list_for_program(Ecto.UUID.t()) :: [map()]
  def list_for_program(program_id) do
    from(e in ProgramEnrollment,
      join: u in assoc(e, :user),
      where: e.program_id == ^program_id,
      order_by: [asc: e.inserted_at],
      select: %{
        id: e.id,
        user_id: u.id,
        name: u.name,
        username: u.username,
        payment_status: e.payment_status,
        paid_at: e.paid_at,
        enrolled_at: e.inserted_at
      }
    )
    |> Repo.all()
  end

  @doc "Matrícula de uma pessoa no pacote, ou `nil`."
  @spec get_for_user(Ecto.UUID.t(), Ecto.UUID.t()) :: ProgramEnrollment.t() | nil
  def get_for_user(program_id, user_id) do
    Repo.get_by(ProgramEnrollment, program_id: program_id, user_id: user_id)
  end

  @doc "Matrícula com escopo na programação: id forjado de outra não encontra nada."
  @spec get_scoped(Ecto.UUID.t(), Ecto.UUID.t()) :: ProgramEnrollment.t() | nil
  def get_scoped(enrollment_id, program_id) do
    case Ecto.UUID.cast(enrollment_id) do
      {:ok, uuid} -> Repo.get_by(ProgramEnrollment, id: uuid, program_id: program_id)
      :error -> nil
    end
  end

  @doc "Quantos compraram, quantos pagaram e quanto entrou."
  @spec summary(Ecto.UUID.t(), non_neg_integer() | nil) :: map()
  def summary(program_id, price_cents) do
    numeros =
      from(e in ProgramEnrollment,
        where: e.program_id == ^program_id,
        select: %{
          packages: count(e.id),
          paid: filter(count(e.id), e.payment_status == :paid),
          waived: filter(count(e.id), e.payment_status == :waived)
        }
      )
      |> Repo.one()

    Map.put(numeros, :revenue_cents, numeros.paid * (price_cents || 0))
  end
end
