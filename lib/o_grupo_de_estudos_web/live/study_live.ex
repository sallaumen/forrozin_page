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
       teachers: Study.list_teachers_for_student(user.id),
       students: if(user.is_teacher, do: Study.list_students_for_teacher(user.id), else: []),
       today_note: today_note,
       today_note_content: if(today_note, do: today_note.content, else: ""),
       personal_history: Study.list_personal_note_history(user.id)
     )}
  end

  @impl true
  def handle_event("save_personal_note", %{"personal_note" => %{"content" => content}}, socket) do
    {:ok, today_note} =
      Study.upsert_personal_note(socket.assigns.current_user, socket.assigns.today, %{
        content: content,
        step_ids: []
      })

    {:noreply,
     assign(socket,
       today_note: today_note,
       today_note_content: content,
       personal_history: Study.list_personal_note_history(socket.assigns.current_user.id)
     )}
  end

  def handle_event("save_personal_note", _params, socket), do: {:noreply, socket}

  defp note_preview(content) when is_binary(content) do
    content
    |> String.trim()
    |> String.slice(0, 120)
  end

  defp note_preview(_), do: ""
end
