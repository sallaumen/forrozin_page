defmodule OGrupoDeEstudos.Study do
  @moduledoc """
  Contexto da área de estudos: vínculos professor-aluno e diários.
  """

  import Ecto.Query

  alias OGrupoDeEstudos.Accounts
  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.Encyclopedia
  alias OGrupoDeEstudos.Engagement.Notifications.Dispatcher
  alias OGrupoDeEstudos.PubSub
  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Study.{ActiveDay, Goal, LinkError, Note, NoteStep, TeacherStudentLink}

  alias OGrupoDeEstudos.Study.{
    ActiveDayQuery,
    GoalQuery,
    LinkQuery,
    NoteQuery
  }

  alias Phoenix.PubSub, as: PhoenixPubSub

  # ── Teacher search & request ──────────────────────────────────────────

  @doc "Search for teachers by name or username. Returns up to 8 results."
  def search_teachers(term, exclude_user_id \\ nil) do
    term = String.trim(term)

    if String.length(term) < 2 do
      []
    else
      Accounts.search_teachers(term, exclude_id: exclude_user_id)
    end
  end

  @doc """
  Returns a list of suggested teachers for a student.
  Excludes teachers the student already has a link with (active or pending).
  Ordered by number of students (desc), then same city, then recent activity.
  """
  def suggest_teachers(user, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)

    user
    |> LinkQuery.list_suggested_teachers(limit)
    |> Enum.map(fn %{user: teacher, student_count: student_count} ->
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
        {:error, LinkError.new(:already_connected)}

      %{pending: true} ->
        {:error, LinkError.new(:already_pending)}

      existing ->
        # Reactivate as pending
        existing
        |> TeacherStudentLink.changeset(%{pending: true, active: false, ended_at: nil})
        |> Repo.update()
    end
  end

  def request_teacher_link(%User{}, _teacher_id), do: {:error, LinkError.new(:cannot_link_self)}

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
        {:error, LinkError.new(:already_connected)}

      %{pending: true} ->
        {:error, LinkError.new(:already_pending)}

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

  def invite_student_link(_, _), do: {:error, LinkError.new(:not_teacher)}

  @doc """
  Returns the teacher/student link between two users regardless of direction,
  or `nil`. Accepts `status: :pending | :active` to narrow the lookup.
  """
  defdelegate get_link_between(user_a_id, user_b_id, opts \\ []), to: LinkQuery, as: :get_between

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

  def accept_link_request(_, _), do: {:error, LinkError.new(:invalid)}

  @doc "Teacher rejects a pending request."
  def reject_link_request(%TeacherStudentLink{pending: true} = link, %User{id: teacher_id})
      when teacher_id == link.teacher_id do
    Repo.delete(link)
  end

  def reject_link_request(_, _), do: {:error, LinkError.new(:invalid)}

  @doc "List pending requests for a teacher."
  defdelegate list_pending_requests_for_teacher(teacher_id),
    to: LinkQuery,
    as: :list_pending_for_teacher

  # ── Invite flow (existing) ────────────────────────────────────────────

  def accept_invite(%User{id: student_id}, invite_slug) when is_binary(invite_slug) do
    invite_slug = String.trim(invite_slug)

    case Repo.get_by(User, invite_slug: invite_slug, is_teacher: true) do
      nil ->
        {:error, LinkError.new(:teacher_not_found)}

      %User{id: teacher_id} when teacher_id == student_id ->
        {:error, LinkError.new(:cannot_link_self)}

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
            {:error, LinkError.new(:already_pending)}

          %TeacherStudentLink{active: true} ->
            {:error, LinkError.new(:already_connected)}

          link ->
            link
            |> TeacherStudentLink.changeset(%{active: false, pending: true})
            |> Repo.update()
        end
    end
  end

  defdelegate get_personal_note(user_id, date), to: NoteQuery, as: :get_personal

  defdelegate get_shared_note(link_id, date), to: NoteQuery, as: :get_shared

  @doc "Returns true if a shared note exists for the given link and date."
  defdelegate shared_note_exists?(link_id, date), to: NoteQuery, as: :shared_exists?

  @doc """
  Batch version of `shared_note_exists?/2`.

  Returns a MapSet of link IDs that have a shared note on the given date.
  Use this when rendering a list of student links to avoid N+1 queries.
  """
  defdelegate shared_note_link_ids(link_ids, date), to: NoteQuery, as: :shared_link_ids_on

  def search_related_steps(term) when is_binary(term) do
    if String.trim(term) == "" do
      []
    else
      term
      |> Encyclopedia.search_steps()
      |> Enum.take(6)
    end
  end

  defdelegate list_personal_note_history(user_id), to: NoteQuery, as: :list_personal_history

  def personal_note_week_count(user_id, today \\ OGrupoDeEstudos.Brazil.today()) do
    NoteQuery.count_personal_between(user_id, Date.add(today, -6), today)
  end

  @doc "Marca o usuário como ativo no dia (idempotente). Alimenta a consistência."
  def record_active_day(user_id, day) do
    Repo.insert(%ActiveDay{user_id: user_id, day: day},
      on_conflict: :nothing,
      conflict_target: [:user_id, :day]
    )
  end

  @doc "Datas (MapSet) em que o usuário esteve ativo no intervalo [from, to]."
  defdelegate active_days_between(user_id, from, to), to: ActiveDayQuery, as: :days_between

  def list_teachers_for_student(student_id) do
    list_teacher_links_for_student(student_id)
    |> Enum.map(& &1.teacher)
  end

  defdelegate list_teacher_links_for_student(student_id),
    to: LinkQuery,
    as: :list_active_for_student

  def list_students_for_teacher(teacher_id) do
    list_student_links_for_teacher(teacher_id)
    |> Enum.map(& &1.student)
  end

  defdelegate list_student_links_for_teacher(teacher_id),
    to: LinkQuery,
    as: :list_active_for_teacher

  def list_shared_activity_for_user(user_or_id, today \\ OGrupoDeEstudos.Brazil.today())

  def list_shared_activity_for_user(%User{id: user_id}, today) do
    list_shared_activity_for_user(user_id, today)
  end

  def list_shared_activity_for_user(user_id, today) do
    user_id
    |> LinkQuery.list_accepted_for_user()
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

  defdelegate list_shared_note_history(link_id), to: NoteQuery, as: :list_shared_history

  defdelegate get_link_for_member(id, user_id), to: LinkQuery, as: :get_for_member

  @doc "Updates a link's private teacher note, only by that link's teacher."
  def update_teacher_note(%User{id: actor_id}, link_id, note) do
    case Repo.get(TeacherStudentLink, link_id) do
      %TeacherStudentLink{teacher_id: ^actor_id} = link ->
        link
        |> TeacherStudentLink.changeset(%{teacher_note: note})
        |> Repo.update()

      _ ->
        {:error, :unauthorized}
    end
  end

  def end_link(%TeacherStudentLink{} = link, %User{id: actor_id})
      when actor_id in [link.teacher_id, link.student_id] do
    link
    |> TeacherStudentLink.changeset(%{active: false, ended_at: DateTime.utc_now()})
    |> Repo.update()
  end

  def end_link(%TeacherStudentLink{}, %User{}), do: {:error, LinkError.new(:forbidden)}

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
      persist_note(base_attrs, content, step_ids, existing_note)
    end
  end

  defp persist_note(base_attrs, content, step_ids, existing_note) do
    note = existing_note || struct!(Note, Map.merge(base_attrs, %{content: content}))

    Repo.transact(fn ->
      with {:ok, saved_note} <-
             note
             |> Note.changeset(Map.merge(base_attrs, %{content: content}))
             |> Repo.insert_or_update() do
        replace_note_steps(saved_note, step_ids)
        {:ok, saved_note}
      end
    end)
    |> case do
      {:ok, note} -> {:ok, preload_note(note)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Updates the linked steps on an existing note without changing the content."
  def update_note_steps(note_id, step_ids) do
    note = Repo.get!(Note, note_id)
    step_ids = step_ids |> Enum.reject(&is_nil/1) |> Enum.uniq()
    replace_note_steps(note, step_ids)
    {:ok, Repo.preload(note, :related_steps, force: true)}
  end

  def replace_note_steps(%Note{id: note_id}, step_ids) do
    NoteStep
    |> where([ns], ns.study_note_id == ^note_id)
    |> Repo.delete_all()

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

  defdelegate list_personal_goals(user_id), to: GoalQuery, as: :list_personal

  defdelegate list_shared_goals(link_id), to: GoalQuery, as: :list_shared

  def create_goal(attrs) do
    %Goal{}
    |> Goal.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Toggles a goal's completion, scoped to the actor (owner or link member)."
  def toggle_goal(%User{} = actor, goal_id) do
    case authorized_goal(actor, goal_id) do
      nil -> {:error, :not_found}
      goal -> goal |> Goal.changeset(%{completed: !goal.completed}) |> Repo.update()
    end
  end

  @doc "Deletes a goal, scoped to the actor (owner or link member)."
  def delete_goal(%User{} = actor, goal_id) do
    case authorized_goal(actor, goal_id) do
      nil -> {:error, :not_found}
      goal -> Repo.delete(goal)
    end
  end

  defp authorized_goal(%User{id: user_id}, goal_id) do
    GoalQuery.get_authorized(goal_id, user_id)
  end

  # ── Step frequency ranking ─────────────────────────────────────────────

  defdelegate step_frequency_ranking(kind, id), to: NoteQuery, as: :step_frequency
end
