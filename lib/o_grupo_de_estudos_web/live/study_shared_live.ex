defmodule OGrupoDeEstudosWeb.StudySharedLive do
  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.{Accounts, Study}

  on_mount {OGrupoDeEstudosWeb.UserAuth, :ensure_authenticated}
  on_mount {OGrupoDeEstudosWeb.Navigation, :detail}
  on_mount {OGrupoDeEstudosWeb.Hooks.NotificationSubscriber, :default}

  import OGrupoDeEstudosWeb.UI.TopNav

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

        today = Date.utc_today()

        {:ok,
         assign(socket,
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
           shared_step_suggestions: []
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

      {:noreply,
       assign(socket,
         today_note: note,
         today_note_content: content,
         history: Study.list_shared_note_history(socket.assigns.link.id)
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

  @impl true
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

  defp counterpart(link, current_user_id) do
    if link.teacher_id == current_user_id, do: link.student, else: link.teacher
  end

  defp note_content(nil), do: ""
  defp note_content(note), do: note.content

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
