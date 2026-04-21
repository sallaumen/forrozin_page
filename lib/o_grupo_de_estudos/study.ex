defmodule OGrupoDeEstudos.Study do
  @moduledoc """
  Contexto da área de estudos: vínculos professor-aluno e diários.
  """

  import Ecto.Query

  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.PubSub
  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Study.{Note, NoteStep, TeacherStudentLink}
  alias Phoenix.PubSub, as: PhoenixPubSub

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

  def get_shared_note(link_id, date) do
    Repo.get_by(Note, kind: "shared", teacher_student_link_id: link_id, note_date: date)
    |> preload_note()
  end

  def list_personal_note_history(user_id) do
    from(note in Note,
      where: note.kind == "personal" and note.owner_user_id == ^user_id,
      order_by: [desc: note.note_date]
    )
    |> Repo.all()
    |> Repo.preload(:related_steps)
  end

  def list_teachers_for_student(student_id) do
    list_teacher_links_for_student(student_id)
    |> Enum.map(& &1.teacher)
  end

  def list_teacher_links_for_student(student_id) do
    from(link in TeacherStudentLink,
      preload: [:teacher],
      where: link.student_id == ^student_id and link.active == true,
      order_by: [asc: link.inserted_at]
    )
    |> Repo.all()
  end

  def list_students_for_teacher(teacher_id) do
    list_student_links_for_teacher(teacher_id)
    |> Enum.map(& &1.student)
  end

  def list_student_links_for_teacher(teacher_id) do
    from(link in TeacherStudentLink,
      preload: [:student],
      where: link.teacher_id == ^teacher_id and link.active == true,
      order_by: [asc: link.inserted_at]
    )
    |> Repo.all()
  end

  def upsert_personal_note(%User{id: user_id}, date, attrs) do
    upsert_note(
      %{kind: "personal", owner_user_id: user_id, note_date: date},
      attrs,
      Repo.get_by(Note, kind: "personal", owner_user_id: user_id, note_date: date)
    )
  end

  def upsert_shared_note(%TeacherStudentLink{id: link_id} = link, date, attrs) do
    result =
      upsert_note(
        %{kind: "shared", teacher_student_link_id: link_id, note_date: date},
        attrs,
        Repo.get_by(Note, kind: "shared", teacher_student_link_id: link_id, note_date: date)
      )

    broadcast_shared_note_update(link)
    result
  end

  def list_shared_note_history(link_id) do
    from(note in Note,
      where: note.kind == "shared" and note.teacher_student_link_id == ^link_id,
      order_by: [desc: note.note_date]
    )
    |> Repo.all()
    |> Repo.preload(:related_steps)
  end

  def get_link_for_member(id, user_id) do
    from(link in TeacherStudentLink,
      where: link.id == ^id and (link.teacher_id == ^user_id or link.student_id == ^user_id),
      preload: [:teacher, :student]
    )
    |> Repo.one()
  end

  def end_link(%TeacherStudentLink{} = link, %User{id: actor_id})
      when actor_id in [link.teacher_id, link.student_id] do
    link
    |> TeacherStudentLink.changeset(%{active: false, ended_at: DateTime.utc_now()})
    |> Repo.update()
  end

  def end_link(%TeacherStudentLink{}, %User{}), do: {:error, :forbidden}

  def note_topic(%TeacherStudentLink{id: id}), do: note_topic(id)
  def note_topic(id) when is_binary(id), do: "study:shared_note:#{id}"

  def broadcast_shared_note_update(%TeacherStudentLink{id: link_id}) do
    PhoenixPubSub.broadcast(PubSub, note_topic(link_id), {:study_note_updated, link_id})
  end

  def broadcast_shared_note_update(link_id) when is_binary(link_id) do
    PhoenixPubSub.broadcast(PubSub, note_topic(link_id), {:study_note_updated, link_id})
  end

  defp upsert_note(base_attrs, attrs, existing_note) do
    content = normalize_content(Map.get(attrs, :content) || Map.get(attrs, "content"))
    step_ids = normalize_step_ids(Map.get(attrs, :step_ids) || Map.get(attrs, "step_ids"))

    if blank_note?(content, step_ids) do
      delete_note_if_present(existing_note)
    else
      note =
        existing_note ||
          struct!(Note, Map.merge(base_attrs, %{content: content}))

      Repo.transaction(fn ->
        case note
             |> Note.changeset(Map.merge(base_attrs, %{content: content}))
             |> Repo.insert_or_update() do
          {:ok, saved_note} ->
            replace_note_steps(saved_note, step_ids)

            saved_note

          {:error, changeset} ->
            Repo.rollback(changeset)
        end
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
