defmodule OGrupoDeEstudosWeb.AdminErrorsLive do
  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.{Accounts, Admin}

  import OGrupoDeEstudosWeb.UI.TopNav
  import OGrupoDeEstudosWeb.CoreComponents, only: [flash: 1, icon: 1]

  @page_size 50

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if Accounts.admin?(user) do
      errors = load_errors(0)

      {:ok,
       socket
       |> assign(
         page_title: "Erros do Sistema",
         is_admin: true,
         nav_mode: :primary,
         page: 0,
         loaded_count: length(errors),
         has_more: length(errors) == @page_size
       )
       |> stream(:errors, errors)}
    else
      {:ok, socket |> put_flash(:error, "Acesso restrito") |> redirect(to: ~p"/collection")}
    end
  end

  @impl true
  def handle_event("load_more", _, socket) do
    page = socket.assigns.page + 1
    more = load_errors(page)

    {:noreply,
     socket
     |> assign(
       page: page,
       loaded_count: socket.assigns.loaded_count + length(more),
       has_more: length(more) == @page_size
     )
     |> stream(:errors, more)}
  end

  def handle_event("clear_all", _, socket) do
    Admin.clear_error_logs()

    {:noreply,
     socket
     |> assign(page: 0, loaded_count: 0, has_more: false)
     |> stream(:errors, [], reset: true)
     |> put_flash(:info, "Todos os erros foram limpos.")}
  end

  def handle_event("copy_error", %{"id" => id}, socket) do
    # Stream items live in the DOM, not in socket assigns, so fetch from the DB.
    case Admin.get_error_log(id) do
      nil ->
        {:noreply, socket}

      error ->
        {:noreply, push_event(socket, "copy_to_clipboard", %{text: format_for_copy(error)})}
    end
  end

  defp load_errors(page) do
    Admin.list_error_logs(limit: @page_size, offset: page * @page_size)
  end

  defp format_for_copy(error) do
    """
    [#{error.level}] #{format_time(error.inserted_at)}
    #{error.message}
    #{if error.source, do: "Source: #{error.source}", else: ""}
    #{if error.stacktrace, do: "\nStacktrace:\n#{error.stacktrace}", else: ""}
    """
    |> String.trim()
  end

  defp format_time(dt) do
    OGrupoDeEstudos.Brazil.format_datetime_full(dt)
  end

  defp time_ago(datetime) do
    diff = NaiveDateTime.diff(NaiveDateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "agora"
      diff < 3600 -> "#{div(diff, 60)}min"
      diff < 86_400 -> "#{div(diff, 3600)}h"
      true -> "#{div(diff, 86_400)}d"
    end
  end
end
