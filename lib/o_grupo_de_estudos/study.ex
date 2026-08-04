defmodule OGrupoDeEstudos.Study do
  @moduledoc "Study area context: teacher-student links and diaries."

  import Ecto.Query

  alias OGrupoDeEstudos.Accounts
  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.Encyclopedia
  alias OGrupoDeEstudos.Engagement.Notifications.Dispatcher
  alias OGrupoDeEstudos.PubSub
  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Sequences
  alias OGrupoDeEstudos.Sequences.CitationQuery

  alias OGrupoDeEstudos.Study.{
    ActiveDay,
    Goal,
    LessonSequence,
    LinkError,
    Note,
    NoteSequence,
    NoteStep,
    TeacherStudentLink
  }

  alias OGrupoDeEstudos.Study.{
    ActiveDayQuery,
    GoalQuery,
    LessonQuery,
    LinkQuery,
    NoteQuery
  }

  alias OGrupoDeEstudos.Study.{Lesson, LessonDelivery, LessonStep}

  alias Phoenix.PubSub, as: PhoenixPubSub

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

  @doc "Marks the user as active on the day (idempotent). Feeds the consistency count."
  def record_active_day(user_id, day) do
    Repo.insert(%ActiveDay{user_id: user_id, day: day},
      on_conflict: :nothing,
      conflict_target: [:user_id, :day]
    )
  end

  @doc "Dates (MapSet) on which the user was active in the range [from, to]."
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

  defdelegate list_lessons_for_link(link_id), to: LessonQuery, as: :list_for_link

  defdelegate list_lessons_for_teacher(teacher_id), to: LessonQuery, as: :list_for_teacher

  defdelegate unread_lesson_link_ids(link_ids), to: LessonQuery, as: :unread_link_ids

  defdelegate count_unread_lessons(student_id), to: LessonQuery, as: :count_unread_for_student

  defdelegate lesson_steps(lesson_id), to: LessonQuery, as: :steps_for_lesson

  @doc """
  Creates a lesson and delivers it to the selected links of the teacher.

  `link_ids` is filtered against the ACTIVE links of the teacher themselves: ids
  belonging to others or inactive are ignored. With no valid link it returns
  `{:error, :no_students}` and nothing is created. Notifications and the PubSub
  broadcast happen after the commit.
  """
  def broadcast_lesson(%User{id: teacher_id}, attrs, link_ids) do
    links = deliverable_links(teacher_id, link_ids)

    with :ok <- ensure_recipients(links),
         {:ok, lesson} <- insert_lesson_with_deliveries(teacher_id, attrs, links) do
      Enum.each(links, &notify_lesson_delivered(&1, lesson))
      {:ok, lesson, length(links)}
    end
  end

  @doc """
  Updates title/content of the teacher's own lesson.

  A missing `:step_ids` keeps the linked steps untouched; when present it
  replaces the whole list, an empty one included.
  """
  def update_lesson(%User{id: actor_id}, %Lesson{teacher_id: actor_id} = lesson, attrs) do
    result =
      Repo.transact(fn ->
        with {:ok, updated} <-
               lesson |> Lesson.changeset(Map.take(attrs, [:title, :content])) |> Repo.update() do
          replace_lesson_steps(updated, attrs)
          {:ok, updated}
        end
      end)

    with {:ok, updated} <- result do
      broadcast_lesson_change(updated.id)
      {:ok, updated}
    end
  end

  def update_lesson(%User{}, %Lesson{}, _attrs), do: {:error, :unauthorized}

  @doc "Removes a lesson of the teacher themselves (deliveries cascade)."
  def delete_lesson(%User{id: actor_id}, %Lesson{teacher_id: actor_id} = lesson) do
    link_ids = LessonQuery.delivery_link_ids(lesson.id)

    with {:ok, deleted} <- Repo.delete(lesson) do
      Enum.each(link_ids, &broadcast_lesson_published/1)
      {:ok, deleted}
    end
  end

  def delete_lesson(%User{}, %Lesson{}), do: {:error, :unauthorized}

  @doc "Fetches a lesson by id, or nil (a malformed id is nil too)."
  def get_lesson(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} -> Repo.get(Lesson, uuid)
      :error -> nil
    end
  end

  @doc """
  Marks the given lessons of the link as read. Only the student of the link can,
  and only the lessons they actually saw on screen (scoped by ids).
  Returns `{:ok, count}` or `{:error, :unauthorized}`.
  """
  def mark_lessons_read(
        %TeacherStudentLink{student_id: student_id} = link,
        %User{id: student_id},
        lesson_ids
      ) do
    {count, _} = LessonQuery.mark_read(link.id, lesson_ids, DateTime.utc_now())
    {:ok, count}
  end

  def mark_lessons_read(%TeacherStudentLink{}, %User{}, _lesson_ids),
    do: {:error, :unauthorized}

  defp deliverable_links(teacher_id, link_ids) do
    wanted = MapSet.new(link_ids)

    teacher_id
    |> LinkQuery.list_active_for_teacher()
    |> Enum.filter(&MapSet.member?(wanted, &1.id))
  end

  defp ensure_recipients([]), do: {:error, :no_students}
  defp ensure_recipients(_links), do: :ok

  defp insert_lesson_with_deliveries(teacher_id, attrs, links) do
    Repo.transact(fn ->
      with {:ok, lesson} <-
             %Lesson{}
             |> Lesson.changeset(Map.put(attrs, :teacher_id, teacher_id))
             |> Repo.insert() do
        Repo.insert_all(LessonDelivery, delivery_rows(lesson, links))
        replace_lesson_steps(lesson, attrs)
        {:ok, lesson}
      end
    end)
  end

  defp replace_lesson_steps(%Lesson{} = lesson, attrs) do
    case Map.get(attrs, :step_ids) || Map.get(attrs, "step_ids") do
      nil -> :ok
      step_ids -> put_lesson_steps(lesson, existing_step_ids(step_ids))
    end
  end

  defp put_lesson_steps(%Lesson{id: lesson_id}, step_ids) do
    LessonStep
    |> where([ls], ls.lesson_id == ^lesson_id)
    |> Repo.delete_all()

    Enum.each(step_ids, fn step_id ->
      %LessonStep{}
      |> LessonStep.changeset(%{lesson_id: lesson_id, step_id: step_id})
      |> Repo.insert!()
    end)
  end

  # Filtering first keeps a stale step id from aborting the whole insert.
  defp existing_step_ids(step_ids) do
    ids = normalize_step_ids(step_ids)
    found = ids |> Encyclopedia.steps_by_ids() |> Map.keys() |> MapSet.new()

    Enum.filter(ids, &MapSet.member?(found, &1))
  rescue
    Ecto.Query.CastError -> []
  end

  defp delivery_rows(lesson, links) do
    now = DateTime.utc_now()

    Enum.map(links, fn link ->
      %{
        id: Ecto.UUID.generate(),
        lesson_id: lesson.id,
        teacher_student_link_id: link.id,
        inserted_at: now,
        updated_at: now
      }
    end)
  end

  defp notify_lesson_delivered(link, lesson) do
    Dispatcher.notify_lesson(lesson.teacher_id, link.student_id, link.id, lesson.id)
    broadcast_lesson_published(link.id)
  end

  defp broadcast_lesson_published(link_id) do
    PhoenixPubSub.broadcast(PubSub, note_topic(link_id), {:lesson_published, link_id})
  end

  # Editing fixes the content for everyone who received it, and whoever has the
  # page open reloads right away (same event as publish).
  defp broadcast_lesson_change(lesson_id) do
    lesson_id
    |> LessonQuery.delivery_link_ids()
    |> Enum.each(&broadcast_lesson_published/1)
  end

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
    sequence_ids = Map.get(attrs, :sequence_ids) || Map.get(attrs, "sequence_ids")

    if blank_note?(content, step_ids, sequence_ids || kept_sequence_ids(existing_note)) do
      delete_note_if_present(existing_note)
    else
      persist_note(base_attrs, content, step_ids, sequence_ids, existing_note)
    end
  end

  defp persist_note(base_attrs, content, step_ids, sequence_ids, existing_note) do
    note = existing_note || struct!(Note, Map.merge(base_attrs, %{content: content}))

    Repo.transact(fn ->
      with {:ok, saved_note} <-
             note
             |> Note.changeset(Map.merge(base_attrs, %{content: content}))
             |> Repo.insert_or_update() do
        replace_note_steps(saved_note, step_ids)
        maybe_replace_note_sequences(saved_note, sequence_ids)
        {:ok, saved_note}
      end
    end)
    |> case do
      {:ok, note} -> {:ok, preload_note(note)}
      {:error, reason} -> {:error, reason}
    end
  end

  # nil means "leave the citations alone"; a list replaces them.
  defp maybe_replace_note_sequences(_note, nil), do: :ok
  defp maybe_replace_note_sequences(note, ids), do: replace_note_sequences(note, ids)

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

  @doc "Sequences cited by the note, oldest citation first."
  @spec note_sequences(Ecto.UUID.t()) :: [CitationQuery.row()]
  defdelegate note_sequences(note_id), to: CitationQuery, as: :list_for_note

  @doc "Sequences cited by the lesson, oldest citation first."
  @spec lesson_sequences(Ecto.UUID.t()) :: [CitationQuery.row()]
  defdelegate lesson_sequences(lesson_id), to: CitationQuery, as: :list_for_lesson

  @doc """
  Replaces the sequences cited by the note, like the step chips already work.

  Ids that no longer resolve are dropped instead of failing the whole write: the
  screen may be holding a sequence its author deleted meanwhile, and losing the
  note over that would be the worse trade.
  """
  @spec replace_note_sequences(Note.t(), [Ecto.UUID.t()]) :: :ok
  def replace_note_sequences(%Note{id: note_id}, sequence_ids) do
    replace_citations(NoteSequence, :study_note_id, note_id, sequence_ids)
  end

  @doc "Replaces the sequences cited by the lesson. Same rule as the note."
  @spec replace_lesson_sequences(Lesson.t(), [Ecto.UUID.t()]) :: :ok
  def replace_lesson_sequences(%Lesson{id: lesson_id}, sequence_ids) do
    replace_citations(LessonSequence, :lesson_id, lesson_id, sequence_ids)
  end

  defp replace_citations(schema, host_field, host_id, sequence_ids) do
    schema
    |> where([c], field(c, ^host_field) == ^host_id)
    |> Repo.delete_all()

    sequence_ids
    |> existing_sequence_ids()
    |> Enum.each(fn sequence_id ->
      schema
      |> struct()
      |> schema.changeset(%{host_field => host_id, :sequence_id => sequence_id})
      |> Repo.insert!()
    end)
  end

  defp existing_sequence_ids(sequence_ids) do
    ids = sequence_ids |> Enum.reject(&is_nil/1) |> Enum.uniq()
    found = Sequences.existing_sequence_ids(ids)
    Enum.filter(ids, &(&1 in found))
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

  # A note that only cites a sequence is not blank. Without counting them, citing
  # one on a day with nothing typed would delete the note holding the citation.
  defp blank_note?(content, step_ids, sequence_ids),
    do: content == "" and step_ids == [] and sequence_ids == []

  defp kept_sequence_ids(nil), do: []

  defp kept_sequence_ids(%Note{id: id}),
    do: Enum.map(CitationQuery.list_for_note(id), & &1.sequence_id)

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

  defdelegate step_frequency_ranking(kind, id), to: NoteQuery, as: :step_frequency

  @doc """
  Step ids the user saw through the study area (diary notes and lessons).

  This is history, not the user's own "learned" mark; the collection merges
  it with the workshops answer.
  """
  @spec step_ids_seen_by(Ecto.UUID.t() | nil) :: MapSet.t()
  def step_ids_seen_by(user_id) do
    MapSet.union(NoteQuery.step_ids_seen_by(user_id), LessonQuery.step_ids_seen_by(user_id))
  end
end
