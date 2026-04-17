defmodule OGrupoDeEstudosWeb.AdminErrorsLive do
  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.Admin.ErrorLog
  alias OGrupoDeEstudos.{Accounts, Repo}

  import Ecto.Query

  on_mount {OGrupoDeEstudosWeb.UserAuth, :ensure_authenticated}

  import OGrupoDeEstudosWeb.UI.TopNav
  import OGrupoDeEstudosWeb.CoreComponents, only: [icon: 1]

  @page_size 50

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    unless Accounts.admin?(user) do
      {:ok, socket |> put_flash(:error, "Acesso restrito") |> redirect(to: ~p"/collection")}
    else
      errors = load_errors(0)
      {:ok, assign(socket,
        page_title: "Erros do Sistema",
        is_admin: true,
        nav_mode: :primary,
        errors: errors,
        page: 0,
        has_more: length(errors) == @page_size,
        expanded: nil
      )}
    end
  end

  @impl true
  def handle_event("load_more", _, socket) do
    page = socket.assigns.page + 1
    more = load_errors(page)
    {:noreply, assign(socket,
      page: page,
      errors: socket.assigns.errors ++ more,
      has_more: length(more) == @page_size
    )}
  end

  def handle_event("toggle_expand", %{"id" => id}, socket) do
    expanded = if socket.assigns.expanded == id, do: nil, else: id
    {:noreply, assign(socket, :expanded, expanded)}
  end

  def handle_event("clear_all", _, socket) do
    Repo.delete_all(ErrorLog)
    {:noreply, assign(socket, errors: [], page: 0, has_more: false)
     |> put_flash(:info, "Todos os erros foram limpos.")}
  end

  def handle_event("copy_error", %{"id" => id}, socket) do
    error = Enum.find(socket.assigns.errors, &(&1.id == id))
    if error do
      text = format_for_copy(error)
      {:noreply, push_event(socket, "copy_to_clipboard", %{text: text})}
    else
      {:noreply, socket}
    end
  end

  defp load_errors(page) do
    from(e in ErrorLog,
      order_by: [desc: e.inserted_at],
      limit: @page_size,
      offset: ^(page * @page_size)
    )
    |> Repo.all()
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
    Calendar.strftime(dt, "%d/%m/%Y %H:%M:%S")
  end

  defp time_ago(datetime) do
    diff = NaiveDateTime.diff(NaiveDateTime.utc_now(), datetime, :second)
    cond do
      diff < 60 -> "agora"
      diff < 3600 -> "#{div(diff, 60)}min"
      diff < 86400 -> "#{div(diff, 3600)}h"
      true -> "#{div(diff, 86400)}d"
    end
  end
end
