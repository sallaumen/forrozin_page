defmodule OGrupoDeEstudos.Study.LessonQuery do
  @moduledoc """
  Query module de `Lesson` e `LessonDelivery`.

  Leituras do aluno são por vínculo (a lição chega via entrega); leituras
  do professor agregam contagens de entrega/leitura sem N+1.
  """

  import Ecto.Query

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Study.{Lesson, LessonDelivery}

  @type lesson_row :: %{
          id: Ecto.UUID.t(),
          title: String.t(),
          content: String.t(),
          teacher_id: Ecto.UUID.t(),
          inserted_at: DateTime.t(),
          read_at: DateTime.t() | nil
        }

  @doc "Lições entregues ao vínculo, mais recentes primeiro, com read_at da entrega."
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
  end

  @doc "Lições do professor com contagens de entrega e leitura, mais recentes primeiro."
  @spec list_for_teacher(Ecto.UUID.t()) :: [
          %{lesson: Lesson.t(), delivered_count: non_neg_integer(), read_count: non_neg_integer()}
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
  end

  @doc """
  Marca como lidas as entregas do vínculo restritas às lições dadas.
  O escopo por ids garante que só o que foi renderizado ao aluno ganha
  read_at (recibo de leitura honesto). Retorna `{count, nil}`.
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

  @doc "Vínculos que receberam a lição (para broadcasts de edição/exclusão)."
  @spec delivery_link_ids(Ecto.UUID.t()) :: [Ecto.UUID.t()]
  def delivery_link_ids(lesson_id) do
    from(d in LessonDelivery,
      where: d.lesson_id == ^lesson_id,
      select: d.teacher_student_link_id
    )
    |> Repo.all()
  end

  @doc "Total de entregas não lidas do aluno, somando todos os seus vínculos."
  @spec count_unread_for_student(Ecto.UUID.t()) :: non_neg_integer()
  def count_unread_for_student(student_id) do
    from(d in LessonDelivery,
      join: link in assoc(d, :teacher_student_link),
      where: link.student_id == ^student_id and link.active == true and is_nil(d.read_at)
    )
    |> Repo.aggregate(:count)
  end

  @doc "MapSet dos vínculos (entre os dados) com alguma lição não lida."
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
