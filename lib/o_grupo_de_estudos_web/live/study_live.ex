defmodule OGrupoDeEstudosWeb.StudyLive do
  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.{Accounts, Study}

  on_mount {OGrupoDeEstudosWeb.UserAuth, :ensure_authenticated}
  on_mount {OGrupoDeEstudosWeb.Navigation, :primary}
  on_mount {OGrupoDeEstudosWeb.Hooks.NotificationSubscriber, :default}

  import OGrupoDeEstudosWeb.UI.BottomNav
  import OGrupoDeEstudosWeb.UI.TopNav

  use OGrupoDeEstudosWeb.NotificationHandlers

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    today = Date.utc_today()
    today_note = Study.get_personal_note(user.id, today)

    {:ok,
     assign(socket,
       page_title: "Estudos",
       is_admin: Accounts.admin?(user),
       today: today,
       teacher_links: Study.list_teacher_links_for_student(user.id),
       student_links:
         if(user.is_teacher, do: Study.list_student_links_for_teacher(user.id), else: []),
       today_note: today_note,
       today_note_content: if(today_note, do: today_note.content, else: ""),
       personal_history: Study.list_personal_note_history(user.id),
       personal_related_steps: if(today_note, do: today_note.related_steps, else: []),
       personal_step_suggestions: [],
       section_history_open: false,
       section_teachers_open: true,
       section_students_open: false,
       teacher_search: "",
       teacher_search_results: [],
       pending_requests:
         if(user.is_teacher, do: Study.list_pending_requests_for_teacher(user.id), else: [])
     )}
  end

  @impl true
  def handle_event("save_personal_note", %{"personal_note" => %{"content" => content}}, socket) do
    {:ok, today_note} =
      Study.upsert_personal_note(socket.assigns.current_user, socket.assigns.today, %{
        content: content,
        step_ids: Enum.map(socket.assigns.personal_related_steps, & &1.id)
      })

    {:noreply,
     assign(socket,
       today_note: today_note,
       today_note_content: content,
       personal_history: Study.list_personal_note_history(socket.assigns.current_user.id)
     )}
  end

  def handle_event("save_personal_note", _params, socket), do: {:noreply, socket}

  def handle_event("toggle_section", %{"section" => section}, socket) do
    key = String.to_existing_atom("section_#{section}_open")
    {:noreply, assign(socket, key, not socket.assigns[key])}
  end

  def handle_event("search_personal_step", %{"term" => term}, socket) do
    {:noreply, assign(socket, :personal_step_suggestions, Study.search_related_steps(term))}
  end

  def handle_event("add_personal_step", %{"id" => step_id}, socket) do
    step = Enum.find(socket.assigns.personal_step_suggestions, &(&1.id == step_id))
    updated_steps = prepend_unique_step(socket.assigns.personal_related_steps, step)

    {:ok, today_note} =
      Study.upsert_personal_note(socket.assigns.current_user, socket.assigns.today, %{
        content: socket.assigns.today_note_content,
        step_ids: Enum.map(updated_steps, & &1.id)
      })

    {:noreply,
     assign(socket,
       today_note: today_note,
       personal_related_steps: updated_steps,
       personal_step_suggestions: [],
       personal_history: Study.list_personal_note_history(socket.assigns.current_user.id)
     )}
  end

  def handle_event("remove_personal_step", %{"id" => step_id}, socket) do
    updated_steps = Enum.reject(socket.assigns.personal_related_steps, &(&1.id == step_id))

    {:ok, today_note} =
      Study.upsert_personal_note(socket.assigns.current_user, socket.assigns.today, %{
        content: socket.assigns.today_note_content,
        step_ids: Enum.map(updated_steps, & &1.id)
      })

    {:noreply,
     assign(socket,
       today_note: today_note,
       personal_related_steps: updated_steps,
       personal_history: Study.list_personal_note_history(socket.assigns.current_user.id)
     )}
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
         |> assign(teacher_search: "", teacher_search_results: [])}

      {:error, :already_connected} ->
        {:noreply, put_flash(socket, :info, "Vocês já estão conectados.")}

      {:error, :already_pending} ->
        {:noreply, put_flash(socket, :info, "Pedido já enviado. Aguarde a resposta.")}

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
          {:noreply,
           socket
           |> put_flash(:info, "Aluno aceito!")
           |> assign(
             pending_requests: Study.list_pending_requests_for_teacher(user.id),
             student_links: Study.list_student_links_for_teacher(user.id)
           )}

        _ ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("reject_request", %{"id" => link_id}, socket) do
    user = socket.assigns.current_user
    link = Study.get_link_for_member(link_id, user.id)

    if link do
      Study.reject_link_request(link, user)

      {:noreply,
       assign(socket, pending_requests: Study.list_pending_requests_for_teacher(user.id))}
    else
      {:noreply, socket}
    end
  end

  defp note_preview(content) when is_binary(content) do
    content
    |> String.trim()
    |> String.slice(0, 120)
  end

  defp note_preview(_), do: ""

  defp prepend_unique_step(steps, nil), do: steps

  defp prepend_unique_step(steps, step) do
    [step | Enum.reject(steps, &(&1.id == step.id))]
  end
end
