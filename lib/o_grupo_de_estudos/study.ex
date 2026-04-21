defmodule OGrupoDeEstudos.Study do
  @moduledoc """
  Contexto da área de estudos: vínculos professor-aluno e diários.
  """

  import Ecto.Query

  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Study.{Note, NoteStep, TeacherStudentLink}

  def accept_invite(%User{id: student_id}, invite_slug) when is_binary(invite_slug) do
    invite_slug = String.trim(invite_slug)

    case Repo.get_by(User, invite_slug: invite_slug, is_teacher: true) do
      nil ->
        {:error, :teacher_not_found}

      %User{id: teacher_id} when teacher_id == student_id ->
        {:error, :cannot_link_self}

      teacher ->
        case Repo.get_by(TeacherStudentLink, teacher_id: teacher.id, student_id: student_id) do
          nil ->
            %TeacherStudentLink{}
            |> TeacherStudentLink.changeset(%{
              teacher_id: teacher.id,
              student_id: student_id,
              active: true,
              ended_at: nil
            })
            |> Repo.insert()

          link ->
            link
            |> TeacherStudentLink.changeset(%{active: true, ended_at: nil})
            |> Repo.update()
        end
    end
  end

  def get_personal_note(user_id, date) do
    Repo.get_by(Note, kind: "personal", owner_user_id: user_id, note_date: date)
    |> preload_note()
  end

  def list_teachers_for_student(student_id) do
    from(link in TeacherStudentLink,
      join: teacher in assoc(link, :teacher),
      where: link.student_id == ^student_id and link.active == true,
      order_by: [asc: teacher.name],
      select: teacher
    )
    |> Repo.all()
  end

  def list_students_for_teacher(teacher_id) do
    from(link in TeacherStudentLink,
      join: student in assoc(link, :student),
      where: link.teacher_id == ^teacher_id and link.active == true,
      order_by: [asc: student.name],
      select: student
    )
    |> Repo.all()
  end

  def upsert_personal_note(%User{id: user_id}, date, attrs) do
    content = normalize_content(Map.get(attrs, :content) || Map.get(attrs, "content"))
    step_ids = normalize_step_ids(Map.get(attrs, :step_ids) || Map.get(attrs, "step_ids"))
    existing_note = Repo.get_by(Note, kind: "personal", owner_user_id: user_id, note_date: date)

    if blank_note?(content, step_ids) do
      delete_note_if_present(existing_note)
    else
      note =
        existing_note ||
          %Note{kind: "personal", owner_user_id: user_id, note_date: date, content: content}

      Repo.transaction(fn ->
        {:ok, saved_note} =
          note
          |> Note.changeset(%{
            kind: "personal",
            owner_user_id: user_id,
            note_date: date,
            content: content
          })
          |> Repo.insert_or_update()

        replace_note_steps(saved_note, step_ids)

        saved_note
      end)
      |> case do
        {:ok, note} -> {:ok, preload_note(note)}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  def replace_note_steps(%Note{id: note_id}, step_ids) do
    Repo.delete_all(from ns in NoteStep, where: ns.study_note_id == ^note_id)

    Enum.each(step_ids, fn step_id ->
      %NoteStep{}
      |> NoteStep.changeset(%{study_note_id: note_id, step_id: step_id})
      |> Repo.insert!()
    end)
  end

  defp delete_note_if_present(nil), do: {:ok, nil}

  defp delete_note_if_present(%Note{} = note) do
    case Repo.delete(note) do
      {:ok, _deleted} -> {:ok, nil}
      {:error, reason} -> {:error, reason}
    end
  end

  defp preload_note(nil), do: nil
  defp preload_note(%Note{} = note), do: Repo.preload(note, :related_steps)

  defp normalize_content(nil), do: ""
  defp normalize_content(content), do: String.trim(content)

  defp normalize_step_ids(step_ids) when is_list(step_ids) do
    step_ids
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.uniq()
  end

  defp normalize_step_ids(_), do: []

  defp blank_note?(content, step_ids), do: content == "" and step_ids == []
end
