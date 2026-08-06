defmodule OGrupoDeEstudos.Workshops.EnrollmentQuery do
  @moduledoc """
  Reads of `WorkshopEnrollment`.

  The split here is about privacy, not convenience: `list_participants/1`
  explicitly projects only what can be public, and it is the only read the
  workshop page uses. Payment only comes out through `list_for_organizer/1`,
  which the context calls after authorizing the owner.
  """

  import Ecto.Query

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Workshops.{Workshop, WorkshopEnrollment}

  @doc """
  Enrollments in workshops happening within the range that have not received the
  day-before reminder yet.

  Returns the `{enrollment, workshop}` pair with the user already loaded, so the
  worker builds the message without N+1.
  """
  @spec pending_reminders(DateTime.t(), DateTime.t()) :: [{WorkshopEnrollment.t(), map()}]
  def pending_reminders(de, ate) do
    from(e in WorkshopEnrollment,
      join: w in assoc(e, :workshop),
      join: u in assoc(e, :user),
      where: is_nil(e.reminded_at),
      where: w.status == :published,
      where: w.starts_at >= ^de and w.starts_at <= ^ate,
      order_by: [asc: w.starts_at],
      select: {e, w, u}
    )
    |> Repo.all()
  end

  @doc "Marks that the reminder went out, so a rerun does not repeat it."
  @spec mark_reminded([Ecto.UUID.t()]) :: {non_neg_integer(), nil}
  def mark_reminded([]), do: {0, nil}

  def mark_reminded(enrollment_ids) do
    agora = DateTime.utc_now() |> DateTime.truncate(:second)

    from(e in WorkshopEnrollment, where: e.id in ^enrollment_ids)
    |> Repo.update_all(set: [reminded_at: agora])
  end

  @doc """
  Upcoming workshops the person is enrolled in, nearest first.

  A workshop happening right now still counts: whoever is in the middle of the
  event wants to see that they are in it.
  """
  @spec list_upcoming_for_user(Ecto.UUID.t(), keyword()) :: [Workshop.t()]
  def list_upcoming_for_user(user_id, opts \\ []) do
    agora = Keyword.get(opts, :now, DateTime.utc_now())

    # Part of the Workshop, not of the enrollment: preload only works over the
    # binding of the `from`.
    from(w in Workshop,
      join: e in assoc(w, :enrollments),
      where: e.user_id == ^user_id and w.status == :published,
      where: coalesce(w.ends_at, w.starts_at) >= ^agora,
      order_by: [asc: w.starts_at],
      limit: ^Keyword.get(opts, :limit, 3),
      preload: [:organizer]
    )
    |> Repo.all()
  end

  @doc "How many upcoming workshops the person has, for the and-N-more label."
  @spec count_upcoming_for_user(Ecto.UUID.t()) :: non_neg_integer()
  def count_upcoming_for_user(user_id) do
    agora = DateTime.utc_now()

    from(w in Workshop,
      join: e in assoc(w, :enrollments),
      where: e.user_id == ^user_id and w.status == :published,
      where: coalesce(w.ends_at, w.starts_at) >= ^agora
    )
    |> Repo.aggregate(:count)
  end

  @doc """
  `%{program_id => count}`: in how many workshops of each program the person is
  enrolled.

  Batched on purpose: one query per program on the agenda would be an N+1.
  """
  @spec enrolled_counts_by_program(Ecto.UUID.t() | nil, [Ecto.UUID.t()]) :: %{
          Ecto.UUID.t() => non_neg_integer()
        }
  def enrolled_counts_by_program(nil, _program_ids), do: %{}
  def enrolled_counts_by_program(_user_id, []), do: %{}

  def enrolled_counts_by_program(user_id, program_ids) do
    from(e in WorkshopEnrollment,
      join: w in assoc(e, :workshop),
      where: e.user_id == ^user_id and w.program_id in ^program_ids,
      group_by: w.program_id,
      select: {w.program_id, count(e.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc "Publicly visible participants: without any payment field."
  @spec list_participants(Ecto.UUID.t()) :: [map()]
  def list_participants(workshop_id) do
    from(e in WorkshopEnrollment,
      join: u in assoc(e, :user),
      where: e.workshop_id == ^workshop_id,
      order_by: [asc: e.inserted_at],
      select: %{
        id: e.id,
        user_id: u.id,
        name: u.name,
        username: u.username,
        avatar_path: u.avatar_path,
        enrolled_at: e.inserted_at
      }
    )
    |> Repo.all()
  end

  @doc """
  Full organizer list, with the payment state and the package behind it.

  The package fields come along because an enrollment covered by one has no
  payment of its own to report: `EnrollmentPayment` derives the state and the
  amount from them.
  """
  @spec list_for_organizer(Ecto.UUID.t()) :: [map()]
  def list_for_organizer(workshop_id) do
    from(e in WorkshopEnrollment,
      join: u in assoc(e, :user),
      left_join: pe in assoc(e, :program_enrollment),
      left_join: p in assoc(pe, :program),
      where: e.workshop_id == ^workshop_id,
      order_by: [asc: e.inserted_at],
      select: %{
        id: e.id,
        user: u,
        inserted_at: e.inserted_at,
        receipt_sent_at: e.receipt_sent_at,
        own_payment_status: e.payment_status,
        program_enrollment_id: pe.id,
        package_payment_status: pe.payment_status,
        package_price_cents: p.price_cents,
        program_title: p.title
      }
    )
    |> Repo.all()
  end

  @doc """
  `%{program_enrollment_id => [{workshop_id, price_cents}]}`: which workshops
  each package actually covers, to split what was paid across them.

  Read from the enrollments, not from the program: what a package covers is what
  it enrolled the person into, which is not the same set as the program's
  workshops today if one was published afterwards.
  """
  @spec covered_workshops_by_package([Ecto.UUID.t()]) :: %{
          Ecto.UUID.t() => [{Ecto.UUID.t(), integer() | nil}]
        }
  def covered_workshops_by_package([]), do: %{}

  def covered_workshops_by_package(program_enrollment_ids) do
    from(e in WorkshopEnrollment,
      join: w in assoc(e, :workshop),
      where: e.program_enrollment_id in ^program_enrollment_ids,
      select: {e.program_enrollment_id, w.id, w.price_cents}
    )
    |> Repo.all()
    |> Enum.group_by(&elem(&1, 0), fn {_package, id, price} -> {id, price} end)
  end

  @doc """
  Enrollment by id, restricted to the given workshop.

  The `workshop_id` always comes from the mount, never from the client: without
  that scope an organizer could mark payment on an enrollment of another event.
  """
  @spec get_scoped(Ecto.UUID.t(), Ecto.UUID.t()) :: WorkshopEnrollment.t() | nil
  def get_scoped(enrollment_id, workshop_id) do
    case Ecto.UUID.cast(enrollment_id) do
      {:ok, uuid} ->
        WorkshopEnrollment
        |> where([e], e.id == ^uuid and e.workshop_id == ^workshop_id)
        |> Repo.one()

      :error ->
        nil
    end
  end

  @doc "Enrollment by id, or nil. Permission is asked afterwards, by the caller."
  @spec get(Ecto.UUID.t()) :: WorkshopEnrollment.t() | nil
  def get(enrollment_id) do
    case Ecto.UUID.cast(enrollment_id) do
      {:ok, uuid} -> Repo.get(WorkshopEnrollment, uuid)
      :error -> nil
    end
  end

  @doc "Enrollment of a specific person in a workshop, or nil."
  @spec get_for_user(Ecto.UUID.t(), Ecto.UUID.t()) :: WorkshopEnrollment.t() | nil
  def get_for_user(workshop_id, user_id) do
    Repo.get_by(WorkshopEnrollment, workshop_id: workshop_id, user_id: user_id)
  end

  @doc "How many people are enrolled."
  @spec count(Ecto.UUID.t()) :: non_neg_integer()
  def count(workshop_id) do
    WorkshopEnrollment
    |> where([e], e.workshop_id == ^workshop_id)
    |> Repo.aggregate(:count)
  end

  @doc "Count per workshop, batched (avoids N+1 on the agenda)."
  @spec count_by_workshop([Ecto.UUID.t()]) :: %{Ecto.UUID.t() => non_neg_integer()}
  def count_by_workshop([]), do: %{}

  def count_by_workshop(workshop_ids) do
    from(e in WorkshopEnrollment,
      where: e.workshop_id in ^workshop_ids,
      group_by: e.workshop_id,
      select: {e.workshop_id, count(e.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  How many people sent the receipt through the app and how many opened WhatsApp.

  Two counts of people, never of taps: each column is stamped once per
  enrollment, so the numbers compare the two paths honestly.
  """
  @spec receipt_summary(Ecto.UUID.t()) :: %{app: integer(), whatsapp: integer()}
  def receipt_summary(workshop_id) do
    from(e in WorkshopEnrollment,
      where: e.workshop_id == ^workshop_id,
      select: %{
        app: count(e.receipt_sent_at),
        whatsapp: count(e.whatsapp_opened_at)
      }
    )
    |> Repo.one()
  end

  @doc "MapSet of the workshops the person is enrolled in."
  @spec enrolled_workshop_ids(Ecto.UUID.t()) :: MapSet.t()
  def enrolled_workshop_ids(user_id) do
    from(e in WorkshopEnrollment,
      where: e.user_id == ^user_id,
      select: e.workshop_id
    )
    |> Repo.all()
    |> MapSet.new()
  end
end
