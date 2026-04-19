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
      user_id = socket.assigns.current_user.id
      Phoenix.PubSub.subscribe(OGrupoDeEstudos.PubSub, "notifications:#{user_id}")
      unread = OGrupoDeEstudos.Engagement.unread_count(user_id)
      {:cont, assign(socket, :notification_count, unread)}
    else
      {:cont, assign(socket, :notification_count, 0)}
    end
  end
end
