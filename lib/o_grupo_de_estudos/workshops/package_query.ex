defmodule OGrupoDeEstudos.Workshops.PackageQuery do
  @moduledoc """
  Reads of `ProgramEnrollment`, the package membership.

  As in `EnrollmentQuery`, the listing projects the fields explicitly: the payment
  state is private to whoever administers, and an explicit `select` keeps it from
  leaking through an absent-minded preload.
  """

  import Ecto.Query

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Workshops.ProgramEnrollment

  @doc "Who bought the package, with display data and payment state."
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

  @doc "Package membership of a person, or `nil`."
  @spec get_for_user(Ecto.UUID.t(), Ecto.UUID.t()) :: ProgramEnrollment.t() | nil
  def get_for_user(program_id, user_id) do
    Repo.get_by(ProgramEnrollment, program_id: program_id, user_id: user_id)
  end

  @doc "Membership scoped to the program: a forged id from another finds nothing."
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
