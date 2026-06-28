defmodule OGrupoDeEstudosWeb.StudyLive do
  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.{Accounts, Engagement, Study}
  alias OGrupoDeEstudos.Engagement.Notifications.Dispatcher
  alias OGrupoDeEstudos.Study.LinkError
  alias OGrupoDeEstudosWeb.ErrorMessage

  on_mount {OGrupoDeEstudosWeb.Navigation, :primary}
  on_mount {OGrupoDeEstudosWeb.Hooks.NotificationSubscriber, :default}

  import OGrupoDeEstudosWeb.UI.BottomNav
  import OGrupoDeEstudosWeb.UI.TopNav
  import OGrupoDeEstudosWeb.UI.SocialBubble
  import OGrupoDeEstudosWeb.UI.UserAvatar
  import OGrupoDeEstudosWeb.UI.StepRanking
  import OGrupoDeEstudosWeb.UI.GoalsBoard
  import OGrupoDeEstudosWeb.StudyComponents

  use OGrupoDeEstudosWeb.NotificationHandlers
  use OGrupoDeEstudosWeb.Handlers.SocialBubbleHandlers
  use OGrupoDeEstudosWeb.Handlers.ActivityToastHandlers

  import OGrupoDeEstudosWeb.UI.ActivityToast

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    today = OGrupoDeEstudos.Brazil.today()
    dashboard = build_dashboard(user, today)

    {:ok,
     socket
     |> assign(:page_title, "Estudos")
     |> assign(:is_admin, Accounts.admin?(user))
     |> assign(:today, today)
     |> assign(:today_weekday, Date.day_of_week(today))
     |> assign(:adding_teacher, false)
     |> assign(:personal_step_suggestions, [])
     |> assign(:editing_history_note_id, nil)
     |> assign(:expanded_note_ids, MapSet.new())
     |> assign(:history_step_suggestions, [])
     |> assign(:section_history_open, true)
     |> assign(:section_teachers_open, true)
     |> assign(:section_students_open, false)
     |> assign(:active_study_tab, "personal")
     |> assign(:teacher_search, "")
     |> assign(:teacher_search_results, [])
     |> assign(:bubble_open, false)
     |> assign(:bubble_tab, "following")
     |> assign(:bubble_following_list, [])
     |> assign(:bubble_followers_list, [])
     |> assign(:bubble_search, "")
     |> assign(:bubble_search_results, [])
     |> assign(:suggested_users, [])
     |> assign(:following_user_ids, Engagement.following_ids(user.id))
     |> assign(:suggested_teachers, Study.suggest_teachers(user, limit: 5))
     |> assign(:personal_goals, Study.list_personal_goals(user.id))
     |> assign(:personal_step_ranking, Study.step_frequency_ranking(:personal, user.id))
     |> assign(:goal_input, "")
     |> assign_dashboard(dashboard)}
  end

  @impl true
  def handle_event("switch_study_tab", %{"tab" => tab}, socket) do
    # Os dados do dashboard já estão carregados (mount + recarga após mutações);
    # trocar de aba é só estado de UI, não precisa re-rodar as queries.
    {:noreply, assign(socket, :active_study_tab, tab)}
  end

  def handle_event("toggle_add_teacher", _params, socket) do
    {:noreply,
     assign(socket,
       adding_teacher: not socket.assigns.adding_teacher,
       teacher_search: "",
       teacher_search_results: []
     )}
  end

  def handle_event("copy_invite_link", _params, socket) do
    user = socket.assigns.current_user

    if user.invite_slug do
      invite_url = OGrupoDeEstudosWeb.Endpoint.url() <> "/study/invite/" <> user.invite_slug

      {:noreply,
       socket
       |> push_event("clipboard:copy", %{text: invite_url})
       |> put_flash(:info, "Link copiado! Envie para seus alunos.")}
    else
      {:noreply, put_flash(socket, :error, "Link de convite não disponível.")}
    end
  end

  def handle_event("save_personal_note", %{"personal_note" => %{"content" => content}}, socket) do
    {:ok, _today_note} =
      Study.upsert_personal_note(socket.assigns.current_user, socket.assigns.today, %{
        content: content,
        step_ids: Enum.map(socket.assigns.personal_related_steps, & &1.id)
      })

    dashboard = build_dashboard(socket.assigns.current_user, socket.assigns.today)

    {:noreply, socket |> assign_dashboard(dashboard) |> assign(:today_note_content, content)}
  end

  def handle_event("save_personal_note", _params, socket), do: {:noreply, socket}

  def handle_event("toggle_section", %{"section" => section}, socket) do
    key = String.to_existing_atom("section_#{section}_open")
    {:noreply, assign(socket, key, not socket.assigns[key])}
  end

  def handle_event("toggle_note_expansion", %{"id" => note_id}, socket) do
    current = socket.assigns.expanded_note_ids

    updated =
      if MapSet.member?(current, note_id),
        do: MapSet.delete(current, note_id),
        else: MapSet.put(current, note_id)

    {:noreply, assign(socket, :expanded_note_ids, updated)}
  end

  def handle_event("search_personal_step", %{"term" => term}, socket) do
    {:noreply, assign(socket, :personal_step_suggestions, Study.search_related_steps(term))}
  end

  def handle_event("add_personal_step", %{"id" => step_id}, socket) do
    step = Enum.find(socket.assigns.personal_step_suggestions, &(&1.id == step_id))
    updated_steps = prepend_unique_step(socket.assigns.personal_related_steps, step)

    {:ok, _today_note} =
      Study.upsert_personal_note(socket.assigns.current_user, socket.assigns.today, %{
        content: socket.assigns.today_note_content,
        step_ids: Enum.map(updated_steps, & &1.id)
      })

    dashboard = build_dashboard(socket.assigns.current_user, socket.assigns.today)

    {:noreply, socket |> assign_dashboard(dashboard) |> assign(:personal_step_suggestions, [])}
  end

  def handle_event("remove_personal_step", %{"id" => step_id}, socket) do
    updated_steps = Enum.reject(socket.assigns.personal_related_steps, &(&1.id == step_id))

    {:ok, _today_note} =
      Study.upsert_personal_note(socket.assigns.current_user, socket.assigns.today, %{
        content: socket.assigns.today_note_content,
        step_ids: Enum.map(updated_steps, & &1.id)
      })

    dashboard = build_dashboard(socket.assigns.current_user, socket.assigns.today)

    {:noreply, assign_dashboard(socket, dashboard)}
  end

  # ── History note step editing ─────────────────────────────────────────

  def handle_event("edit_history_steps", %{"note-id" => note_id}, socket) do
    current = socket.assigns.editing_history_note_id
    new_id = if current == note_id, do: nil, else: note_id
    {:noreply, assign(socket, editing_history_note_id: new_id, history_step_suggestions: [])}
  end

  def handle_event("search_history_step", %{"term" => term}, socket) do
    {:noreply, assign(socket, :history_step_suggestions, Study.search_related_steps(term))}
  end

  def handle_event("add_history_step", %{"note-id" => note_id, "step-id" => step_id}, socket) do
    note = Enum.find(socket.assigns.personal_history, &(&1.id == note_id))

    if note do
      existing_ids = Enum.map(note.related_steps, & &1.id)
      Study.update_note_steps(note_id, [step_id | existing_ids])
    end

    dashboard = build_dashboard(socket.assigns.current_user, socket.assigns.today)

    {:noreply,
     socket
     |> assign_dashboard(dashboard)
     |> assign(
       :personal_step_ranking,
       Study.step_frequency_ranking(:personal, socket.assigns.current_user.id)
     )
     |> assign(:history_step_suggestions, [])}
  end

  def handle_event("remove_history_step", %{"note-id" => note_id, "step-id" => step_id}, socket) do
    note = Enum.find(socket.assigns.personal_history, &(&1.id == note_id))

    if note do
      remaining_ids =
        note.related_steps |> Enum.map(& &1.id) |> Enum.reject(&(&1 == step_id))

      Study.update_note_steps(note_id, remaining_ids)
    end

    dashboard = build_dashboard(socket.assigns.current_user, socket.assigns.today)

    {:noreply,
     socket
     |> assign_dashboard(dashboard)
     |> assign(
       :personal_step_ranking,
       Study.step_frequency_ranking(:personal, socket.assigns.current_user.id)
     )}
  end

  # ── Goals ────────────────────────────────────────────────────────────

  def handle_event("create_goal", %{"body" => body}, socket) do
    user = socket.assigns.current_user

    case Study.create_goal(%{body: body, owner_user_id: user.id}) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:personal_goals, Study.list_personal_goals(user.id))
         |> assign(:goal_input, "")}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_event("toggle_goal", %{"id" => id}, socket) do
    Study.toggle_goal(socket.assigns.current_user, id)

    {:noreply,
     assign(socket, :personal_goals, Study.list_personal_goals(socket.assigns.current_user.id))}
  end

  def handle_event("delete_goal", %{"id" => id}, socket) do
    Study.delete_goal(socket.assigns.current_user, id)

    {:noreply,
     assign(socket, :personal_goals, Study.list_personal_goals(socket.assigns.current_user.id))}
  end

  # ── Teacher search & request ──────────────────────────────────────────

  def handle_event("search_teacher", %{"term" => term}, socket) do
    results = Study.search_teachers(term, socket.assigns.current_user.id)
    {:noreply, assign(socket, teacher_search: term, teacher_search_results: results)}
  end

  def handle_event("request_teacher", %{"id" => teacher_id}, socket) do
    user = socket.assigns.current_user

    case Study.request_teacher_link(user, teacher_id) do
      {:ok, _link} ->
        {:noreply,
         socket
         |> put_flash(:info, "Pedido enviado! O professor será notificado.")
         |> assign(teacher_search: "", teacher_search_results: [], adding_teacher: false)}

      {:error, %LinkError{} = err} ->
        {:noreply, put_flash(socket, ErrorMessage.flash_level(err), ErrorMessage.to_flash(err))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Não foi possível enviar o pedido.")}
    end
  end

  def handle_event("accept_request", %{"id" => link_id}, socket) do
    user = socket.assigns.current_user
    link = Study.get_link_for_member(link_id, user.id)

    if link do
      case Study.accept_link_request(link, user) do
        {:ok, _} ->
          dashboard = build_dashboard(user, socket.assigns.today)

          {:noreply,
           socket
           |> put_flash(:info, "Aluno aceito!")
           |> assign_dashboard(dashboard)}

        _ ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("save_teacher_note", %{"link-id" => link_id, "note" => note}, socket) do
    case Study.update_teacher_note(socket.assigns.current_user, link_id, note) do
      {:ok, _link} -> {:noreply, put_flash(socket, :info, "Anotacao salva.")}
      {:error, _} -> {:noreply, socket}
    end
  end

  def handle_event("nudge_student", %{"link-id" => link_id}, socket) do
    user = socket.assigns.current_user
    link = Study.get_link_for_member(link_id, user.id)

    if link && link.active && link.teacher_id == user.id do
      Dispatcher.notify_nudge(user, link.student_id, link.id)
      {:noreply, put_flash(socket, :info, "Lembrete enviado!")}
    else
      {:noreply, socket}
    end
  end

  def handle_event("reject_request", %{"id" => link_id}, socket) do
    user = socket.assigns.current_user
    link = Study.get_link_for_member(link_id, user.id)

    if link do
      Study.reject_link_request(link, user)
      dashboard = build_dashboard(user, socket.assigns.today)

      {:noreply, assign_dashboard(socket, dashboard)}
    else
      {:noreply, socket}
    end
  end

  defp assign_dashboard(socket, dashboard) do
    socket
    |> assign(:today_note, dashboard.today_note)
    |> assign(:today_note_content, dashboard.today_note_content)
    |> assign(:personal_related_steps, dashboard.personal_related_steps)
    |> assign(:personal_history, dashboard.personal_history)
    |> assign(:weekly_note_count, dashboard.weekly_note_count)
    |> assign(:monthly_note_count, dashboard.monthly_note_count)
    |> assign(:week_weekdays, dashboard.week_weekdays)
    |> assign(:today_status, dashboard.today_status)
    |> assign(:teacher_links, dashboard.teacher_links)
    |> assign(:student_links, dashboard.student_links)
    |> assign(:wrote_today_ids, dashboard.wrote_today_ids)
    |> assign(:students_wrote_today, dashboard.students_wrote_today)
    |> assign(:pending_requests, dashboard.pending_requests)
  end

  defp build_dashboard(user, today) do
    today_note = Study.get_personal_note(user.id, today)
    personal_history = Study.list_personal_note_history(user.id)
    month_start = Date.new!(today.year, today.month, 1)
    teacher_links = Study.list_teacher_links_for_student(user.id)

    student_links =
      if user.is_teacher, do: Study.list_student_links_for_teacher(user.id), else: []

    all_link_ids = Enum.map(teacher_links, & &1.id) ++ Enum.map(student_links, & &1.id)
    wrote_today_ids = Study.shared_note_link_ids(all_link_ids, today)

    %{
      today_note: today_note,
      today_note_content: if(today_note, do: today_note.content, else: ""),
      personal_related_steps: if(today_note, do: today_note.related_steps, else: []),
      personal_history: personal_history,
      weekly_note_count: Study.personal_note_week_count(user.id, today),
      monthly_note_count:
        Enum.count(personal_history, &(Date.compare(&1.note_date, month_start) != :lt)),
      week_weekdays: week_note_weekdays(personal_history, today),
      today_status: personal_today_status(today_note),
      teacher_links: teacher_links,
      student_links: student_links,
      wrote_today_ids: wrote_today_ids,
      students_wrote_today: Enum.count(student_links, &MapSet.member?(wrote_today_ids, &1.id)),
      pending_requests:
        if(user.is_teacher, do: Study.list_pending_requests_for_teacher(user.id), else: [])
    }
  end

  # Dias da semana atual (1=segunda .. 7=domingo) que já têm registro pessoal.
  defp week_note_weekdays(history, today) do
    week_start = Date.beginning_of_week(today)
    week_end = Date.end_of_week(today)

    history
    |> Enum.filter(fn note ->
      Date.compare(note.note_date, week_start) != :lt and
        Date.compare(note.note_date, week_end) != :gt
    end)
    |> Enum.map(&Date.day_of_week(&1.note_date))
    |> MapSet.new()
  end

  defp personal_today_status(nil), do: %{label: "Sem registro ainda", tone: :warning}

  defp personal_today_status(today_note) do
    cond do
      today_note.related_steps != [] -> %{label: "Com passo vinculado", tone: :success}
      String.trim(today_note.content || "") != "" -> %{label: "Registrado hoje", tone: :success}
      true -> %{label: "Sem registro ainda", tone: :warning}
    end
  end

  defp prepend_unique_step(steps, nil), do: steps

  defp prepend_unique_step(steps, step) do
    [step | Enum.reject(steps, &(&1.id == step.id))]
  end
end
