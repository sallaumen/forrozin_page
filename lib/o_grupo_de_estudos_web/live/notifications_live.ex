defmodule OGrupoDeEstudosWeb.NotificationsLive do
  @moduledoc """
  Dedicated notifications page — Instagram-style grouped display.

  Groups raw notifications via Grouper so that multiple actors
  performing the same action on the same target collapse into a
  single row (e.g. "João e mais 3 curtiram o seu comentário").

  Pagination is manual (load_more event) using a page-based offset.
  """

  use OGrupoDeEstudosWeb, :live_view
  use OGrupoDeEstudosWeb.NotificationHandlers

  alias OGrupoDeEstudos.{Accounts, Engagement}
  alias OGrupoDeEstudos.Engagement.Notifications.Grouper

  on_mount {OGrupoDeEstudosWeb.UserAuth, :ensure_authenticated}
  on_mount {OGrupoDeEstudosWeb.Hooks.NotificationSubscriber, :default}

  import OGrupoDeEstudosWeb.UI.TopNav
  import OGrupoDeEstudosWeb.UI.BottomNav
  import OGrupoDeEstudosWeb.CoreComponents, only: [icon: 1]

  @page_size 20

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    raw = Engagement.list_notifications(user.id, limit: @page_size)
    grouped = Grouper.group(raw)

    {:ok,
     assign(socket,
       page_title: "Notificações",
       raw_notifications: raw,
       notifications: grouped,
       page: 0,
       has_more: length(raw) == @page_size,
       nav_mode: :primary,
       is_admin: Accounts.admin?(user)
     )}
  end

  @impl true
  def handle_event("mark_read", %{"id" => id}, socket) do
    Engagement.mark_as_read(socket.assigns.current_user, id)
    {:noreply, reload_notifications(socket)}
  end

  @impl true
  def handle_event("mark_all_read", _, socket) do
    user = socket.assigns.current_user
    Engagement.mark_all_read(user)

    Phoenix.PubSub.broadcast(
      OGrupoDeEstudos.PubSub,
      "notifications:#{user.id}",
      {:notifications_read, :all}
    )

    {:noreply, reload_notifications(socket)}
  end

  @impl true
  def handle_event("load_more", _, socket) do
    user = socket.assigns.current_user
    page = socket.assigns.page + 1
    more_raw = Engagement.list_notifications(user.id, limit: @page_size, offset: page * @page_size)
    all_raw = socket.assigns.raw_notifications ++ more_raw
    grouped = Grouper.group(all_raw)

    {:noreply,
     assign(socket,
       page: page,
       raw_notifications: all_raw,
       notifications: grouped,
       has_more: length(more_raw) == @page_size
     )}
  end

  # ──────────────────────────────────────────────────────────────────────
  # Private helpers
  # ──────────────────────────────────────────────────────────────────────

  defp reload_notifications(socket) do
    user = socket.assigns.current_user
    raw = Engagement.list_notifications(user.id, limit: @page_size)
    grouped = Grouper.group(raw)
    unread = Engagement.unread_count(user.id)

    assign(socket,
      raw_notifications: raw,
      notifications: grouped,
      page: 0,
      has_more: length(raw) == @page_size,
      notification_count: unread
    )
  end

  defp notification_path(%{parent_type: "step", parent_id: id}) do
    case OGrupoDeEstudos.Repo.get(OGrupoDeEstudos.Encyclopedia.Step, id) do
      nil -> "/collection"
      step -> "/steps/#{step.code}"
    end
  end

  defp notification_path(%{parent_type: "sequence"}), do: "/community"

  defp notification_path(%{parent_type: "profile", parent_id: id}) do
    case OGrupoDeEstudos.Repo.get(OGrupoDeEstudos.Accounts.User, id) do
      nil -> "/collection"
      user -> "/users/#{user.username}"
    end
  end

  defp notification_path(_), do: "/collection"

  defp primary_actor_name(%{actors_data: [actor | _]}) do
    actor.name || actor.username
  end

  defp primary_actor_name(_), do: "Alguém"

  defp primary_actor_username(%{actors_data: [actor | _]}), do: actor.username
  defp primary_actor_username(_), do: nil

  defp target_name(%{parent_type: "step", parent_id: id}) when not is_nil(id) do
    case OGrupoDeEstudos.Repo.get(OGrupoDeEstudos.Encyclopedia.Step, id) do
      nil -> nil
      step -> step.name
    end
  end

  defp target_name(_), do: nil

  defp action_text(%{action: "liked_comment"}), do: " curtiu seu comentário"
  defp action_text(%{action: "replied_comment"}), do: " respondeu ao seu comentário"
  defp action_text(%{action: "liked_step"}), do: " curtiu o passo"
  defp action_text(%{action: "liked_sequence"}), do: " curtiu a sequência"
  defp action_text(%{action: "suggestion_approved"}), do: " aprovou sua sugestão ✓"
  defp action_text(%{action: "suggestion_rejected"}), do: " rejeitou sua sugestão"
  defp action_text(_), do: " interagiu"

  defp time_ago(datetime) do
    diff = NaiveDateTime.diff(NaiveDateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "agora"
      diff < 3_600 -> "#{div(diff, 60)}min"
      diff < 86_400 -> "#{div(diff, 3_600)}h"
      diff < 604_800 -> "#{div(diff, 86_400)}d"
      true -> "#{div(diff, 604_800)}sem"
    end
  end
end
