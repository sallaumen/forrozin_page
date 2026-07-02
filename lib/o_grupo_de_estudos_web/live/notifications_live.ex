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
  alias OGrupoDeEstudosWeb.Helpers.NotificationRoutes

  on_mount {OGrupoDeEstudosWeb.Hooks.NotificationSubscriber, :default}

  import OGrupoDeEstudosWeb.UI.TopNav
  import OGrupoDeEstudosWeb.UI.BottomNav
  import OGrupoDeEstudosWeb.CoreComponents, only: [flash: 1, icon: 1]
  import OGrupoDeEstudosWeb.UI.SocialBubble

  use OGrupoDeEstudosWeb.Handlers.SocialBubbleHandlers
  use OGrupoDeEstudosWeb.Handlers.ActivityToastHandlers

  import OGrupoDeEstudosWeb.UI.ActivityToast
  import OGrupoDeEstudosWeb.Helpers.NotificationPresenter

  @page_size 20

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    raw = Engagement.list_notifications(user.id, limit: @page_size)
    grouped = Grouper.group(raw)

    notification_count =
      if connected?(socket) do
        Engagement.mark_all_read(user)

        Phoenix.PubSub.broadcast(
          OGrupoDeEstudos.PubSub,
          "notifications:#{user.id}",
          {:notifications_read, :all}
        )

        0
      else
        socket.assigns[:notification_count] || 0
      end

    {:ok,
     assign(socket,
       page_title: "Notificações",
       raw_notifications: raw,
       notifications: grouped,
       notification_targets: Engagement.notification_targets(grouped),
       page: 0,
       has_more: length(raw) == @page_size,
       nav_mode: :primary,
       is_admin: Accounts.admin?(user),
       notification_count: notification_count,
       bubble_open: false,
       bubble_tab: "following",
       suggested_users: [],
       bubble_following_list: [],
       bubble_followers_list: [],
       bubble_search: "",
       bubble_search_results: [],
       following_user_ids: Engagement.following_ids(user.id)
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

    more_raw =
      Engagement.list_notifications(user.id, limit: @page_size, offset: page * @page_size)

    all_raw = socket.assigns.raw_notifications ++ more_raw
    grouped = Grouper.group(all_raw)

    {:noreply,
     assign(socket,
       page: page,
       raw_notifications: all_raw,
       notifications: grouped,
       notification_targets: Engagement.notification_targets(grouped),
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
      notification_targets: Engagement.notification_targets(grouped),
      page: 0,
      has_more: length(raw) == @page_size,
      notification_count: unread
    )
  end

  defp target_name(%{action: "liked_sequence"}, _targets), do: nil
  defp target_name(%{action: "followed_user"}, _targets), do: nil
  defp target_name(%{action: "study_request"}, _targets), do: "Ver pedido →"
  defp target_name(%{action: "study_accepted"}, _targets), do: "Ir para estudos →"
  defp target_name(%{action: "shared_note_updated"}, _targets), do: "Ver diário →"
  defp target_name(%{action: "study_nudge"}, _targets), do: "Abrir diário →"
  defp target_name(notif, targets), do: NotificationRoutes.step_name(notif, targets)
end
