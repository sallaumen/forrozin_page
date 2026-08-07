defmodule OGrupoDeEstudosWeb.StudySharedLive do
  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.{Accounts, Study}
  alias OGrupoDeEstudos.Engagement.Notifications.Dispatcher

  on_mount {OGrupoDeEstudosWeb.Navigation, :primary}
  on_mount {OGrupoDeEstudosWeb.Hooks.NotificationSubscriber, :default}
  on_mount {OGrupoDeEstudosWeb.Hooks.SocialBubble, :default}

  import OGrupoDeEstudosWeb.UI.BottomNav
  import OGrupoDeEstudosWeb.UI.SocialBubble
  import OGrupoDeEstudosWeb.UI.TopNav
  import OGrupoDeEstudosWeb.UI.StepRanking
  import OGrupoDeEstudosWeb.UI.GoalsBoard
  import OGrupoDeEstudosWeb.UI.UserAvatar
  import OGrupoDeEstudosWeb.StudyComponents

  use OGrupoDeEstudosWeb.Handlers.SocialBubbleHandlers
  use OGrupoDeEstudosWeb.Handlers.StepLearning
  use OGrupoDeEstudosWeb.NotificationHandlers

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Study.get_link_for_member(id, socket.assigns.current_user.id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Esse diário compartilhado não está disponível para você.")
         |> push_navigate(to: ~p"/study")}

      link ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(OGrupoDeEstudos.PubSub, Study.note_topic(link))
        end

        today = OGrupoDeEstudos.Brazil.today()
        {lessons, new_lesson_ids, marked_read} = load_lessons(link, socket)

        {:ok,
         socket
         |> drop_study_badge(marked_read)
         |> assign(
           note_saved_at: nil,
           lessons: lessons,
           new_lesson_ids: new_lesson_ids,
           expanded_lesson_ids: MapSet.new(),
           page_title: "Diário compartilhado",
           is_admin: Accounts.admin?(socket.assigns.current_user),
           link: link,
           counterpart: counterpart(link, socket.assigns.current_user.id),
           today: today,
           today_note: Study.get_shared_note(link.id, today),
           today_note_content: note_content(Study.get_shared_note(link.id, today)),
           history: Study.list_shared_note_history(link.id),
           shared_related_steps:
             case Study.get_shared_note(link.id, today) do
               nil -> []
               note -> note.related_steps
             end,
           shared_step_suggestions: [],
           editing_history_note_id: nil,
           history_step_suggestions: [],
           expanded_note_ids: MapSet.new(),
           shared_goals: Study.list_shared_goals(link.id),
           shared_step_ranking: Study.step_frequency_ranking(:shared, link.id),
           goal_input: ""
         )}
    end
  end

  @impl true
  def handle_event("save_shared_note", %{"shared_note" => %{"content" => content}}, socket) do
    if socket.assigns.link.active do
      {:ok, note} =
        Study.upsert_shared_note(socket.assigns.link, socket.assigns.today, %{
          content: content,
          step_ids: Enum.map(socket.assigns.shared_related_steps, & &1.id)
        })

      link = socket.assigns.link
      current_user = socket.assigns.current_user

      if current_user.id == link.teacher_id do
        Dispatcher.notify_shared_note(current_user, link.student_id, link.id)
      end

      {:noreply,
       assign(socket,
         today_note: note,
         today_note_content: content,
         history: Study.list_shared_note_history(link.id),
         note_saved_at: OGrupoDeEstudos.Brazil.now()
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_event("save_shared_note", _params, socket), do: {:noreply, socket}

  def handle_event("search_shared_step", %{"term" => term}, socket) do
    {:noreply, assign(socket, :shared_step_suggestions, Study.search_related_steps(term))}
  end

  def handle_event("add_shared_step", %{"id" => step_id}, socket) do
    step = Enum.find(socket.assigns.shared_step_suggestions, &(&1.id == step_id))
    updated_steps = prepend_unique_step(socket.assigns.shared_related_steps, step)

    {:ok, today_note} =
      Study.upsert_shared_note(socket.assigns.link, socket.assigns.today, %{
        content: socket.assigns.today_note_content,
        step_ids: Enum.map(updated_steps, & &1.id)
      })

    {:noreply,
     assign(socket,
       today_note: today_note,
       shared_related_steps: updated_steps,
       shared_step_suggestions: [],
       history: Study.list_shared_note_history(socket.assigns.link.id)
     )}
  end

  def handle_event("remove_shared_step", %{"id" => step_id}, socket) do
    updated_steps = Enum.reject(socket.assigns.shared_related_steps, &(&1.id == step_id))

    {:ok, today_note} =
      Study.upsert_shared_note(socket.assigns.link, socket.assigns.today, %{
        content: socket.assigns.today_note_content,
        step_ids: Enum.map(updated_steps, & &1.id)
      })

    {:noreply,
     assign(socket,
       today_note: today_note,
       shared_related_steps: updated_steps,
       history: Study.list_shared_note_history(socket.assigns.link.id)
     )}
  end

  def handle_event("edit_history_steps", %{"note-id" => note_id}, socket) do
    current = socket.assigns.editing_history_note_id
    new_id = if current == note_id, do: nil, else: note_id
    {:noreply, assign(socket, editing_history_note_id: new_id, history_step_suggestions: [])}
  end

  def handle_event("toggle_lesson_expansion", %{"id" => lesson_id}, socket) do
    current = socket.assigns.expanded_lesson_ids

    updated =
      if MapSet.member?(current, lesson_id),
        do: MapSet.delete(current, lesson_id),
        else: MapSet.put(current, lesson_id)

    {:noreply, assign(socket, :expanded_lesson_ids, updated)}
  end

  def handle_event("toggle_note_expansion", %{"id" => note_id}, socket) do
    current = socket.assigns.expanded_note_ids

    updated =
      if MapSet.member?(current, note_id),
        do: MapSet.delete(current, note_id),
        else: MapSet.put(current, note_id)

    {:noreply, assign(socket, :expanded_note_ids, updated)}
  end

  def handle_event("search_history_step", %{"term" => term}, socket) do
    {:noreply, assign(socket, :history_step_suggestions, Study.search_related_steps(term))}
  end

  def handle_event("add_history_step", %{"note-id" => note_id, "step-id" => step_id}, socket) do
    note = Enum.find(socket.assigns.history, &(&1.id == note_id))

    if socket.assigns.link.active && note do
      existing_ids = Enum.map(note.related_steps, & &1.id)
      Study.update_note_steps(note_id, [step_id | existing_ids])
    end

    link = socket.assigns.link
    history = Study.list_shared_note_history(link.id)
    ranking = Study.step_frequency_ranking(:shared, link.id)

    {:noreply,
     assign(socket, history: history, shared_step_ranking: ranking, history_step_suggestions: [])}
  end

  def handle_event("remove_history_step", %{"note-id" => note_id, "step-id" => step_id}, socket) do
    note = Enum.find(socket.assigns.history, &(&1.id == note_id))

    if socket.assigns.link.active && note do
      remaining_ids =
        note.related_steps |> Enum.map(& &1.id) |> Enum.reject(&(&1 == step_id))

      Study.update_note_steps(note_id, remaining_ids)
    end

    link = socket.assigns.link
    history = Study.list_shared_note_history(link.id)
    ranking = Study.step_frequency_ranking(:shared, link.id)

    {:noreply, assign(socket, history: history, shared_step_ranking: ranking)}
  end

  def handle_event("create_goal", %{"body" => body}, socket) do
    link = socket.assigns.link

    case Study.create_goal(%{body: body, teacher_student_link_id: link.id}) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:shared_goals, Study.list_shared_goals(link.id))
         |> assign(:goal_input, "")}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_event("toggle_goal", %{"id" => id}, socket) do
    Study.toggle_goal(socket.assigns.current_user, id)
    {:noreply, assign(socket, :shared_goals, Study.list_shared_goals(socket.assigns.link.id))}
  end

  def handle_event("delete_goal", %{"id" => id}, socket) do
    Study.delete_goal(socket.assigns.current_user, id)
    {:noreply, assign(socket, :shared_goals, Study.list_shared_goals(socket.assigns.link.id))}
  end

  def handle_event("save_teacher_note", %{"note" => note}, socket) do
    # Uses the link resolved at mount, never a link id coming from the client.
    case Study.update_teacher_note(socket.assigns.current_user, socket.assigns.link.id, note) do
      {:ok, _link} ->
        {:noreply, put_flash(socket, :info, "Anotacao salva.")}

      {:error, reason} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           OGrupoDeEstudosWeb.Helpers.EngagementMessages.teacher_note_error(reason)
         )}
    end
  end

  @impl true
  def handle_info(
        {:lesson_published, link_id},
        %{assigns: %{link: %{id: link_id}}} = socket
      ) do
    # Reloads but does NOT mark as read: a page open in the background is not
    # reading, and the teacher's receipt only changes when the student visits again.
    lessons = Study.list_lessons_for_link(link_id)
    unread = for l <- lessons, is_nil(l.read_at), into: MapSet.new(), do: l.id

    {:noreply,
     assign(socket,
       lessons: lessons,
       new_lesson_ids: MapSet.union(socket.assigns.new_lesson_ids, unread)
     )}
  end

  def handle_info({:study_note_updated, link_id}, %{assigns: %{link: %{id: link_id}}} = socket) do
    note = Study.get_shared_note(link_id, socket.assigns.today)

    {:noreply,
     assign(socket,
       today_note: note,
       today_note_content: note_content(note),
       history: Study.list_shared_note_history(link_id),
       shared_related_steps: if(note, do: note.related_steps, else: [])
     )}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  # Loads the lessons of the link. The "Nova" badge freezes the read state from
  # BEFORE this visit, and opening the page (connected render) marks as read ONLY
  # the lessons listed here, scoped by id, so a lesson arriving later through
  # PubSub does not get a false receipt. The context decides who may mark (only
  # the student of the link); for the teacher the call is denied there and becomes
  # a no-op. The Study tab dot is computed in on_mount, before this mount, so
  # without this it would keep showing the lesson the student just opened.
  defp drop_study_badge(socket, 0), do: socket

  defp drop_study_badge(socket, marked) do
    atual = socket.assigns[:pending_study_count] || 0
    assign(socket, :pending_study_count, max(atual - marked, 0))
  end

  defp load_lessons(link, socket) do
    lessons = Study.list_lessons_for_link(link.id)
    new_ids = for l <- lessons, is_nil(l.read_at), into: MapSet.new(), do: l.id

    marked =
      if connected?(socket) do
        case Study.mark_lessons_read(link, socket.assigns.current_user, MapSet.to_list(new_ids)) do
          {:ok, count} -> count
          {:error, _} -> 0
        end
      else
        0
      end

    {lessons, new_ids, marked}
  end

  # The visual cut is line-clamp-3 with whitespace-pre-line, and how many
  # characters fit in three lines depends on the column: 220 was measured on a
  # desktop column, so on a phone a 175-character lesson was clipped with no way
  # to open it. The threshold now follows the narrowest column (about 42
  # characters a line at 375px). Erring low only costs a button that expands
  # nothing; erring high costs content nobody can reach.
  defp lesson_long?(content) do
    String.length(content) > 120 or length(String.split(content, "\n")) > 3
  end

  defp counterpart(link, current_user_id) do
    if link.teacher_id == current_user_id, do: link.student, else: link.teacher
  end

  defp note_content(nil), do: ""
  defp note_content(note), do: note.content

  defp prepend_unique_step(steps, nil), do: steps

  defp prepend_unique_step(steps, step) do
    [step | Enum.reject(steps, &(&1.id == step.id))]
  end
end
