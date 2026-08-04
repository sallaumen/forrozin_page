defmodule OGrupoDeEstudos.Study.LessonQuery do
  @moduledoc """
  Query module for `Lesson` and `LessonDelivery`.

  Student reads go by link (a lesson arrives through a delivery); teacher reads
  aggregate delivery and read counts without N+1.
  """

  import Ecto.Query

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Study.{Lesson, LessonDelivery, LessonStep, TeacherStudentLink}

  @type step_row :: %{id: Ecto.UUID.t(), code: String.t(), name: String.t()}

  @type lesson_row :: %{
          id: Ecto.UUID.t(),
          title: String.t(),
          content: String.t(),
          teacher_id: Ecto.UUID.t(),
          inserted_at: DateTime.t(),
          read_at: DateTime.t() | nil,
          steps: [step_row()]
        }

  @doc "Lessons delivered to the link, most recent first, with the delivery read_at."
  @spec list_for_link(Ecto.UUID.t()) :: [lesson_row()]
  def list_for_link(link_id) do
    from(d in LessonDelivery,
      join: l in Lesson,
      on: l.id == d.lesson_id,
      where: d.teacher_student_link_id == ^link_id,
      order_by: [desc: l.inserted_at],
      select: %{
        id: l.id,
        title: l.title,
        content: l.content,
        teacher_id: l.teacher_id,
        inserted_at: l.inserted_at,
        read_at: d.read_at
      }
    )
    |> Repo.all()
    |> attach_steps(& &1.id)
  end

  @doc "Teacher lessons with delivery and read counts, most recent first."
  @spec list_for_teacher(Ecto.UUID.t()) :: [
          %{
            lesson: Lesson.t(),
            delivered_count: non_neg_integer(),
            read_count: non_neg_integer(),
            steps: [step_row()]
          }
        ]
  def list_for_teacher(teacher_id) do
    from(l in Lesson,
      where: l.teacher_id == ^teacher_id,
      left_join: d in assoc(l, :deliveries),
      group_by: l.id,
      order_by: [desc: l.inserted_at],
      select: %{lesson: l, delivered_count: count(d.id), read_count: count(d.read_at)}
    )
    |> Repo.all()
    |> attach_steps(& &1.lesson.id)
  end

  @doc "Steps linked to a lesson, in the order the teacher added them."
  @spec steps_for_lesson(Ecto.UUID.t()) :: [step_row()]
  def steps_for_lesson(lesson_id) do
    [lesson_id]
    |> steps_by_lesson_ids()
    |> Map.get(lesson_id, [])
  rescue
    Ecto.Query.CastError -> []
  end

  @doc "Steps of the given lessons grouped by lesson id, in a single query."
  @spec steps_by_lesson_ids([Ecto.UUID.t()]) :: %{Ecto.UUID.t() => [step_row()]}
  def steps_by_lesson_ids([]), do: %{}

  def steps_by_lesson_ids(lesson_ids) when is_list(lesson_ids) do
    from(ls in LessonStep,
      join: s in assoc(ls, :step),
      where: ls.lesson_id in ^lesson_ids,
      order_by: [asc: ls.inserted_at, asc: s.code],
      select: {ls.lesson_id, %{id: s.id, code: s.code, name: s.name}}
    )
    |> Repo.all()
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end

  @doc "Step ids from lessons the user received or wrote, as a MapSet."
  @spec step_ids_seen_by(Ecto.UUID.t() | nil) :: MapSet.t()
  def step_ids_seen_by(nil), do: MapSet.new()

  def step_ids_seen_by(user_id) do
    from(ls in LessonStep,
      join: l in Lesson,
      on: ls.lesson_id == l.id,
      left_join: d in LessonDelivery,
      on: d.lesson_id == l.id,
      left_join: link in TeacherStudentLink,
      on: d.teacher_student_link_id == link.id,
      where: l.teacher_id == ^user_id or link.student_id == ^user_id,
      select: ls.step_id,
      distinct: true
    )
    |> Repo.all()
    |> MapSet.new()
  end

  defp attach_steps(rows, id_fun) do
    steps_by_lesson = rows |> Enum.map(id_fun) |> steps_by_lesson_ids()

    Enum.map(rows, &Map.put(&1, :steps, Map.get(steps_by_lesson, id_fun.(&1), [])))
  end

  @doc """
  Marks as read the deliveries of the link, restricted to the given lessons.
  Scoping by ids guarantees that only what was rendered to the student gets a
  read_at (an honest read receipt). Returns `{count, nil}`.
  """
  @spec mark_read(Ecto.UUID.t(), [Ecto.UUID.t()], DateTime.t()) :: {non_neg_integer(), nil}
  def mark_read(_link_id, [], _now), do: {0, nil}

  def mark_read(link_id, lesson_ids, now) do
    from(d in LessonDelivery,
      where:
        d.teacher_student_link_id == ^link_id and d.lesson_id in ^lesson_ids and
          is_nil(d.read_at)
    )
    |> Repo.update_all(set: [read_at: now, updated_at: now])
  end

  @doc "Links that received the lesson (for edit and delete broadcasts)."
  @spec delivery_link_ids(Ecto.UUID.t()) :: [Ecto.UUID.t()]
  def delivery_link_ids(lesson_id) do
    from(d in LessonDelivery,
      where: d.lesson_id == ^lesson_id,
      select: d.teacher_student_link_id
    )
    |> Repo.all()
  end

  @doc "Total unread deliveries of the student, across all their links."
  @spec count_unread_for_student(Ecto.UUID.t()) :: non_neg_integer()
  def count_unread_for_student(student_id) do
    from(d in LessonDelivery,
      join: link in assoc(d, :teacher_student_link),
      where: link.student_id == ^student_id and link.active == true and is_nil(d.read_at)
    )
    |> Repo.aggregate(:count)
  end

  @doc "MapSet of the links (among the given ones) with any unread lesson."
  @spec unread_link_ids([Ecto.UUID.t()]) :: MapSet.t()
  def unread_link_ids([]), do: MapSet.new()

  def unread_link_ids(link_ids) when is_list(link_ids) do
    from(d in LessonDelivery,
      join: link in assoc(d, :teacher_student_link),
      where: d.teacher_student_link_id in ^link_ids and link.active == true and is_nil(d.read_at),
      select: d.teacher_student_link_id,
      distinct: true
    )
    |> Repo.all()
    |> MapSet.new()
  end
end
