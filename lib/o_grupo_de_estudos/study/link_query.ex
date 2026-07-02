defmodule OGrupoDeEstudos.Study.LinkQuery do
  @moduledoc """
  Query module for `TeacherStudentLink`.

  Owns every read on the teacher/student link aggregate, including the
  teacher-suggestion ranking (a link-centric query even though it selects
  users: it ranks teachers by student count and linkage exclusions).
  """

  import Ecto.Query

  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Study.TeacherStudentLink

  @doc """
  Returns the link between two users regardless of direction, or `nil`.
  Accepts `status: :pending | :active` to narrow the lookup.
  """
  @spec get_between(Ecto.UUID.t(), Ecto.UUID.t(), [{:status, :pending | :active}]) ::
          TeacherStudentLink.t() | nil
  def get_between(user_a_id, user_b_id, opts \\ []) do
    from(l in TeacherStudentLink,
      where:
        (l.teacher_id == ^user_a_id and l.student_id == ^user_b_id) or
          (l.teacher_id == ^user_b_id and l.student_id == ^user_a_id)
    )
    |> filter_status(opts[:status])
    |> Repo.one()
  end

  @doc "Returns the link by id if the user is one of its members, or `nil`."
  @spec get_for_member(Ecto.UUID.t(), Ecto.UUID.t()) :: TeacherStudentLink.t() | nil
  def get_for_member(id, user_id) do
    from(l in TeacherStudentLink,
      where: l.id == ^id and (l.teacher_id == ^user_id or l.student_id == ^user_id),
      preload: [:teacher, :student]
    )
    |> Repo.one()
  end

  @doc "Pending requests received by a teacher, newest first."
  @spec list_pending_for_teacher(Ecto.UUID.t()) :: [TeacherStudentLink.t()]
  def list_pending_for_teacher(teacher_id) do
    from(l in TeacherStudentLink,
      where: l.teacher_id == ^teacher_id and l.pending == true,
      preload: [:student],
      order_by: [desc: l.inserted_at]
    )
    |> Repo.all()
  end

  @doc "Active links of a student, with teachers preloaded."
  @spec list_active_for_student(Ecto.UUID.t()) :: [TeacherStudentLink.t()]
  def list_active_for_student(student_id) do
    from(l in TeacherStudentLink,
      where: l.student_id == ^student_id and l.active == true,
      preload: [:teacher],
      order_by: [asc: l.inserted_at]
    )
    |> Repo.all()
  end

  @doc "Active links of a teacher, with students preloaded."
  @spec list_active_for_teacher(Ecto.UUID.t()) :: [TeacherStudentLink.t()]
  def list_active_for_teacher(teacher_id) do
    from(l in TeacherStudentLink,
      where: l.teacher_id == ^teacher_id and l.active == true,
      preload: [:student],
      order_by: [asc: l.inserted_at]
    )
    |> Repo.all()
  end

  @doc "Every accepted (non-pending) link the user takes part in, most recent first."
  @spec list_accepted_for_user(Ecto.UUID.t()) :: [TeacherStudentLink.t()]
  def list_accepted_for_user(user_id) do
    from(l in TeacherStudentLink,
      where: (l.teacher_id == ^user_id or l.student_id == ^user_id) and l.pending == false,
      preload: [:teacher, :student],
      order_by: [desc: l.updated_at]
    )
    |> Repo.all()
  end

  @doc """
  Teachers suggested to a student: excludes anyone already linked (any status),
  ranked by student count, same-city bonus, then recent activity.
  """
  @spec list_suggested_teachers(User.t(), pos_integer()) :: [map()]
  def list_suggested_teachers(%User{} = user, limit) do
    existing_teacher_ids =
      from(l in TeacherStudentLink, where: l.student_id == ^user.id, select: l.teacher_id)

    from(u in User,
      where: u.is_teacher == true,
      where: u.id != ^user.id,
      where: u.id not in subquery(existing_teacher_ids),
      left_join: links in TeacherStudentLink,
      on: links.teacher_id == u.id and links.active == true and links.pending == false,
      group_by: u.id,
      order_by: [
        desc: count(links.id),
        desc: fragment("CASE WHEN ? = ? THEN 1 ELSE 0 END", u.city, ^(user.city || "")),
        desc: u.last_seen_at
      ],
      limit: ^limit,
      select: %{user: u, student_count: count(links.id)}
    )
    |> Repo.all()
  end

  defp filter_status(query, nil), do: query
  defp filter_status(query, :pending), do: where(query, [l], l.pending == true)
  defp filter_status(query, :active), do: where(query, [l], l.active == true)
end
