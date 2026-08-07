defmodule OGrupoDeEstudos.Workshops.PackageQuery do
  @moduledoc """
  Reads of `ProgramEnrollment`, the package membership.

  As in `EnrollmentQuery`, the listing projects the fields explicitly: the payment
  state is private to whoever administers, and an explicit `select` keeps it from
  leaking through an absent-minded preload.
  """

  import Ecto.Query

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Workshops.{ProgramEnrollment, Workshop, WorkshopEnrollment}

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
        receipt_sent_at: e.receipt_sent_at,
        enrolled_at: e.inserted_at
      }
    )
    |> Repo.all()
  end

  @doc """
  Whoever enrolled in every published workshop by hand, with no package behind.

  The `is_nil` filter is what excludes package buyers: their enrollments point
  at the membership, so none of their rows count here.
  """
  @spec list_candidates(Ecto.UUID.t()) :: [map()]
  def list_candidates(program_id) do
    case published_count(program_id) do
      0 -> []
      total -> Repo.all(candidates_query(program_id, total))
    end
  end

  defp candidates_query(program_id, total) do
    from(e in WorkshopEnrollment,
      join: w in assoc(e, :workshop),
      join: u in assoc(e, :user),
      where: w.program_id == ^program_id and w.status != :draft,
      where: is_nil(e.program_enrollment_id),
      group_by: [u.id, u.name, u.username],
      having: count(e.id) == ^total,
      order_by: [asc: min(e.inserted_at)],
      select: %{
        user_id: u.id,
        name: u.name,
        username: u.username,
        enrolled_at: min(e.inserted_at)
      }
    )
  end

  @doc "Whether the person holds an enrollment in every published workshop."
  @spec fully_enrolled?(Ecto.UUID.t(), Ecto.UUID.t()) :: boolean()
  def fully_enrolled?(program_id, user_id) do
    case published_count(program_id) do
      0 -> false
      total -> enrolled_count(program_id, user_id) == total
    end
  end

  defp published_count(program_id) do
    from(w in Workshop, where: w.program_id == ^program_id and w.status != :draft)
    |> Repo.aggregate(:count)
  end

  defp enrolled_count(program_id, user_id) do
    from(e in WorkshopEnrollment,
      join: w in assoc(e, :workshop),
      where: w.program_id == ^program_id and w.status != :draft,
      where: e.user_id == ^user_id
    )
    |> Repo.aggregate(:count)
  end

  @doc "The membership the person holds over this workshop's program, or nil."
  @spec held_for_workshop(Ecto.UUID.t(), Ecto.UUID.t()) :: ProgramEnrollment.t() | nil
  def held_for_workshop(workshop_id, user_id) do
    from(pe in ProgramEnrollment,
      join: w in Workshop,
      on: w.program_id == pe.program_id,
      where: w.id == ^workshop_id and pe.user_id == ^user_id
    )
    |> Repo.one()
  end

  @doc "Package membership of a person, or `nil`."
  @spec get_for_user(Ecto.UUID.t(), Ecto.UUID.t()) :: ProgramEnrollment.t() | nil
  def get_for_user(program_id, user_id) do
    Repo.get_by(ProgramEnrollment, program_id: program_id, user_id: user_id)
  end

  @doc "Membership by id, or nil. Permission is asked afterwards, by the caller."
  @spec get(Ecto.UUID.t()) :: ProgramEnrollment.t() | nil
  def get(enrollment_id) do
    case Ecto.UUID.cast(enrollment_id) do
      {:ok, uuid} -> Repo.get(ProgramEnrollment, uuid)
      :error -> nil
    end
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
    numbers =
      from(e in ProgramEnrollment,
        where: e.program_id == ^program_id,
        select: %{
          packages: count(e.id),
          paid: filter(count(e.id), e.payment_status == :paid),
          waived: filter(count(e.id), e.payment_status == :waived)
        }
      )
      |> Repo.one()

    Map.put(numbers, :revenue_cents, numbers.paid * (price_cents || 0))
  end
end
