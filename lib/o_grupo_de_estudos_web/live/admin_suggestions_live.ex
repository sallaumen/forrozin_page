defmodule OGrupoDeEstudosWeb.AdminSuggestionsLive do
  @moduledoc """
  Admin page to review, approve and reject user suggestions.

  Suggestions are grouped by action type:
  - edit_field: field edits on steps (name, note, category_id)
  - create_connection: new connection proposals in "SOURCE→TARGET" format
  - remove_connection: connection removal proposals

  Filter tabs allow switching between pending-only and all suggestions.
  """

  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.{Accounts, Suggestions}

  on_mount {OGrupoDeEstudosWeb.UserAuth, :ensure_authenticated}
  on_mount {OGrupoDeEstudosWeb.Navigation, :detail}

  import OGrupoDeEstudosWeb.UI.TopNav

  @impl true
  def mount(_params, _session, socket) do
    if Accounts.admin?(socket.assigns.current_user) do
      {:ok,
       socket
       |> assign(:page_title, "Admin · Sugestões")
       |> assign(:is_admin, true)
       |> assign(:filter, :pending)
       |> load_suggestions(:pending)}
    else
      {:ok, redirect(socket, to: ~p"/collection")}
    end
  end

  @impl true
  def handle_event("approve", %{"id" => id}, socket) do
    if Accounts.admin?(socket.assigns.current_user) do
      handle_approve(id, socket)
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("reject", %{"id" => id}, socket) do
    if Accounts.admin?(socket.assigns.current_user) do
      handle_reject(id, socket)
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("filter", %{"tab" => tab}, socket) do
    filter = String.to_existing_atom(tab)
    {:noreply, socket |> assign(:filter, filter) |> load_suggestions(filter)}
  end

  # ── Admin action handlers ─────────────────────────────────

  defp handle_approve(id, socket) do
    case Suggestions.get(id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Sugestão não encontrada.")}

      suggestion ->
        admin = socket.assigns.current_user

        case Suggestions.approve(suggestion, admin) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "Sugestão aprovada.")
             |> load_suggestions(socket.assigns.filter)}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Erro ao aprovar sugestão.")}
        end
    end
  end

  defp handle_reject(id, socket) do
    case Suggestions.get(id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Sugestão não encontrada.")}

      suggestion ->
        admin = socket.assigns.current_user

        case Suggestions.reject(suggestion, admin) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "Sugestão rejeitada.")
             |> load_suggestions(socket.assigns.filter)}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Erro ao rejeitar sugestão.")}
        end
    end
  end

  # ── Private helpers ───────────────────────────────────────

  defp load_suggestions(socket, :pending) do
    suggestions = Suggestions.list_pending()
    assign_grouped(socket, suggestions)
  end

  defp load_suggestions(socket, :all) do
    suggestions = Suggestions.list_all()
    assign_grouped(socket, suggestions)
  end

  defp assign_grouped(socket, suggestions) do
    grouped = Enum.group_by(suggestions, & &1.action)
    edit_suggestions = Map.get(grouped, "edit_field", [])

    # Resolve step records for edit_field suggestions so the template
    # can build navigation links without extra DB calls per row.
    steps_by_id = Suggestions.steps_for_suggestions(suggestions)

    socket
    |> assign(:edit_field_suggestions, edit_suggestions)
    |> assign(:create_connection_suggestions, Map.get(grouped, "create_connection", []))
    |> assign(:remove_connection_suggestions, Map.get(grouped, "remove_connection", []))
    |> assign(:steps_by_id, steps_by_id)
    |> assign(:total_count, length(suggestions))
    |> assign(:pending_count, Suggestions.count_pending())
  end
end
