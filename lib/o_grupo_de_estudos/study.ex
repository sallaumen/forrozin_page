defmodule OGrupoDeEstudos.Study do
  @moduledoc """
  Contexto da área de estudos: vínculos professor-aluno e diários.
  """

  import Ecto.Query

  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.Encyclopedia
  alias OGrupoDeEstudos.Engagement.Notifications.Dispatcher
  alias OGrupoDeEstudos.PubSub
  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Study.{Goal, Note, NoteStep, TeacherStudentLink}
  alias Phoenix.PubSub, as: PhoenixPubSub

  # ── Teacher search & request ──────────────────────────────────────────

  @doc "Search for teachers by name or username. Returns up to 8 results."
  def search_teachers(term, exclude_user_id \\ nil) do
    term = String.trim(term)

    if String.length(term) < 2 do
      []
    else
      pattern = "%#{term}%"

      query =
        from(u in User,
          where: u.is_teacher == true,
          where: ilike(u.name, ^pattern) or ilike(u.username, ^pattern),
          order_by: [asc: u.name],
          limit: 8,
          select: %{id: u.id, name: u.name, username: u.username, city: u.city, state: u.state}
        )

      query =
        if exclude_user_id,
          do: where(query, [u], u.id != ^exclude_user_id),
          else: query

      Repo.all(query)
    end
  end

  @doc """
  Returns a list of suggested teachers for a student.
  Excludes teachers the student already has a link with (active or pending).
  Ordered by number of students (desc), then same city, then recent activity.
  """
  def suggest_teachers(user, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)

    existing_teacher_ids =
      from(l in TeacherStudentLink,
        where: l.student_id == ^user.id,
        select: l.teacher_id
      )

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
      limit: ^limit
    )
    |> Repo.all()
    |> Enum.map(fn teacher ->
      student_count =
        from(l in TeacherStudentLink,
          where: l.teacher_id == ^teacher.id and l.active == true and l.pending == false
        )
        |> Repo.aggregate(:count)

      Map.put(teacher, :student_count, student_count)
    end)
  end

  @doc "Student sends a request to study with a teacher. Creates a pending link."
  def request_teacher_link(%User{id: student_id}, teacher_id) when student_id != teacher_id do
    case Repo.get_by(TeacherStudentLink, teacher_id: teacher_id, student_id: student_id) do
      nil ->
        result =
          %TeacherStudentLink{}
          |> TeacherStudentLink.changeset(%{
            teacher_id: teacher_id,
            student_id: student_id,
            active: false,
            pending: true,
            initiated_by_id: student_id
          })
          |> Repo.insert()

        case result do
          {:ok, link} ->
            Dispatcher.notify_study_request(student_id, teacher_id, link.id)
            {:ok, link}

          error ->
            error
        end

      %{active: true} ->
        {:error, :already_connected}

      %{pending: true} ->
        {:error, :already_pending}

      existing ->
        # Reactivate as pending
        existing
        |> TeacherStudentLink.changeset(%{pending: true, active: false, ended_at: nil})
        |> Repo.update()
    end
  end

  def request_teacher_link(%User{}, _teacher_id), do: {:error, :cannot_link_self}

  @doc "Teacher invites a student. Creates a pending link that student needs to accept."
  def invite_student_link(%User{id: teacher_id, is_teacher: true}, student_id)
      when teacher_id != student_id do
    case Repo.get_by(TeacherStudentLink, teacher_id: teacher_id, student_id: student_id) do
      nil ->
        result =
          %TeacherStudentLink{}
          |> TeacherStudentLink.changeset(%{
            teacher_id: teacher_id,
            student_id: student_id,
            active: false,
            pending: true,
            initiated_by_id: teacher_id
          })
          |> Repo.insert()

        case result do
          {:ok, link} ->
            Dispatcher.notify_study_request(teacher_id, student_id, link.id)
            {:ok, link}

          error ->
            error
        end

      %{active: true} ->
        {:error, :already_connected}

      %{pending: true} ->
        {:error, :already_pending}

      existing ->
        existing
        |> TeacherStudentLink.changeset(%{
          pending: true,
          active: false,
          ended_at: nil,
          initiated_by_id: teacher_id
        })
        |> Repo.update()
    end
  end

  def invite_student_link(_, _), do: {:error, :not_teacher}

  @doc "Accept a pending link request. Either side can accept if they didn't initiate."
  def accept_link_request(%TeacherStudentLink{pending: true} = link, %User{id: acceptor_id})
      when acceptor_id in [link.teacher_id, link.student_id] and
             acceptor_id != link.initiated_by_id do
    result =
      link
      |> TeacherStudentLink.changeset(%{pending: false, active: true})
      |> Repo.update()

    case result do
      {:ok, updated_link} ->
        # Notify the person who initiated that their request was accepted
        other_id = if acceptor_id == link.teacher_id, do: link.student_id, else: link.teacher_id
        Dispatcher.notify_study_accepted(acceptor_id, other_id, link.id)
        {:ok, updated_link}

      error ->
        error
    end
  end

  def accept_link_request(_, _), do: {:error, :invalid}

  @doc "Teacher rejects a pending request."
  def reject_link_request(%TeacherStudentLink{pending: true} = link, %User{id: teacher_id})
      when teacher_id == link.teacher_id do
    Repo.delete(link)
  end

  def reject_link_request(_, _), do: {:error, :invalid}

  @doc "List pending requests for a teacher."
  def list_pending_requests_for_teacher(teacher_id) do
    from(link in TeacherStudentLink,
      where: link.teacher_id == ^teacher_id and link.pending == true,
      preload: [:student],
      order_by: [desc: link.inserted_at]
    )
    |> Repo.all()
  end

  # ── Invite flow (existing) ────────────────────────────────────────────

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
              initiated_by_id: student_id,
              active: false,
              pending: true,
              ended_at: nil
            })
            |> Repo.insert()

          %TeacherStudentLink{pending: true} ->
            {:error, :already_pending}

          %TeacherStudentLink{active: true} ->
            {:error, :already_connected}

          link ->
            link
            |> TeacherStudentLink.changeset(%{active: false, pending: true})
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

  @doc "Returns true if a shared note exists for the given link and date."
  def shared_note_exists?(link_id, date) do
    from(n in Note,
      where: n.teacher_student_link_id == ^link_id and n.note_date == ^date and n.kind == "shared"
    )
    |> Repo.exists?()
  end

  def search_related_steps(term) when is_binary(term) do
    if String.trim(term) == "" do
      []
    else
      term
      |> Encyclopedia.search_steps()
      |> Enum.take(6)
    end
  end

  def list_personal_note_history(user_id) do
    from(note in Note,
      where: note.kind == "personal" and note.owner_user_id == ^user_id,
      order_by: [desc: note.note_date]
    )
    |> Repo.all()
    |> Repo.preload(:related_steps)
  end

  def personal_note_week_count(user_id, today \\ OGrupoDeEstudos.Brazil.today()) do
    week_start = Date.add(today, -6)

    from(note in Note,
      where: note.kind == "personal" and note.owner_user_id == ^user_id,
      where: note.note_date >= ^week_start and note.note_date <= ^today,
      select: count(note.id)
    )
    |> Repo.one()
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

  def list_shared_activity_for_user(user_or_id, today \\ OGrupoDeEstudos.Brazil.today())

  def list_shared_activity_for_user(%User{id: user_id}, today) do
    list_shared_activity_for_user(user_id, today)
  end

  def list_shared_activity_for_user(user_id, today) do
    from(link in TeacherStudentLink,
      where:
        (link.teacher_id == ^user_id or link.student_id == ^user_id) and link.pending == false,
      preload: [:teacher, :student],
      order_by: [desc: link.updated_at]
    )
    |> Repo.all()
    |> Enum.map(fn link ->
      today_note = get_shared_note(link.id, today)
      last_note = List.first(list_shared_note_history(link.id))
      counterpart = if link.teacher_id == user_id, do: link.student, else: link.teacher

      %{
        link_id: link.id,
        active: link.active,
        counterpart: counterpart,
        has_today_note?: not is_nil(today_note),
        today_note_preview: dashboard_note_preview(today_note),
        last_note_at: if(last_note, do: last_note.updated_at),
        last_note_preview: dashboard_note_preview(last_note)
      }
    end)
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

  defp dashboard_note_preview(nil), do: nil

  defp dashboard_note_preview(%Note{content: content}) do
    content
    |> String.trim()
    |> String.slice(0, 120)
  end

  defp normalize_content(nil), do: ""
  defp normalize_content(content), do: String.trim(content)

  defp normalize_step_ids(step_ids) when is_list(step_ids) do
    step_ids
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.uniq()
  end

  defp normalize_step_ids(_), do: []

  defp blank_note?(content, step_ids), do: content == "" and step_ids == []

  # ── Goals ─────────────────────────────────────────────────────────────

  def list_personal_goals(user_id) do
    from(g in Goal,
      where: g.owner_user_id == ^user_id,
      order_by: [asc: g.completed, asc: g.position, desc: g.inserted_at]
    )
    |> Repo.all()
  end

  def list_shared_goals(link_id) do
    from(g in Goal,
      where: g.teacher_student_link_id == ^link_id,
      order_by: [asc: g.completed, asc: g.position, desc: g.inserted_at]
    )
    |> Repo.all()
  end

  def create_goal(attrs) do
    %Goal{}
    |> Goal.changeset(attrs)
    |> Repo.insert()
  end

  def toggle_goal(goal_id) do
    goal = Repo.get!(Goal, goal_id)

    goal
    |> Goal.changeset(%{completed: !goal.completed})
    |> Repo.update()
  end

  def delete_goal(goal_id) do
    goal = Repo.get!(Goal, goal_id)
    Repo.delete(goal)
  end

  # ── Step frequency ranking ─────────────────────────────────────────────

  def step_frequency_ranking(:personal, user_id) do
    from(ns in NoteStep,
      join: n in Note,
      on: ns.study_note_id == n.id,
      join: s in OGrupoDeEstudos.Encyclopedia.Step,
      on: ns.step_id == s.id,
      where: n.owner_user_id == ^user_id and n.kind == "personal",
      group_by: [s.id, s.code, s.name],
      select: %{step_id: s.id, code: s.code, name: s.name, count: count(ns.id)},
      order_by: [desc: count(ns.id)]
    )
    |> Repo.all()
  end

  def step_frequency_ranking(:shared, link_id) do
    from(ns in NoteStep,
      join: n in Note,
      on: ns.study_note_id == n.id,
      join: s in OGrupoDeEstudos.Encyclopedia.Step,
      on: ns.step_id == s.id,
      where: n.teacher_student_link_id == ^link_id and n.kind == "shared",
      group_by: [s.id, s.code, s.name],
      select: %{step_id: s.id, code: s.code, name: s.name, count: count(ns.id)},
      order_by: [desc: count(ns.id)]
    )
    |> Repo.all()
  end
end
