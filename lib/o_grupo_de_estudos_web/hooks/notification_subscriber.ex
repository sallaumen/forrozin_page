defmodule OGrupoDeEstudosWeb.Hooks.NotificationSubscriber do
  @moduledoc "on_mount hook: subscribes to notification PubSub + loads unread count."
  import Phoenix.Component, only: [assign: 2, assign: 3]

  def on_mount(:default, _params, _session, socket) do
    socket =
      assign(socket,
        notification_dropdown_open: false,
        notification_preview_groups: []
      )

    if Phoenix.LiveView.connected?(socket) && socket.assigns[:current_user] do
      user = socket.assigns.current_user
      Phoenix.PubSub.subscribe(OGrupoDeEstudos.PubSub, "notifications:#{user.id}")
      unread = OGrupoDeEstudos.Engagement.unread_count(user.id)

      pending_suggestions =
        if OGrupoDeEstudos.Accounts.admin?(user),
          do: OGrupoDeEstudos.Suggestions.count_pending(),
          else: 0

      {:cont,
       assign(socket,
         notification_count: unread,
         pending_suggestions_count: pending_suggestions
       )}
    else
      {:cont, assign(socket, notification_count: 0, pending_suggestions_count: 0)}
    end
  end
end
