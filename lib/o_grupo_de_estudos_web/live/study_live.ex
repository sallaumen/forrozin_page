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
       section_students_open: false
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
