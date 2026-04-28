defmodule OGrupoDeEstudosWeb.NotificationHandlers do
  @moduledoc "Shared handle_info clauses for notification PubSub messages."

  defmacro __using__(_opts) do
    quote do
      alias OGrupoDeEstudos.Engagement
      alias OGrupoDeEstudos.Engagement.Notifications.Grouper

      @impl true
      def handle_info({:new_notification, _count}, socket) do
        if socket.assigns[:current_user] do
          if socket.assigns[:notification_dropdown_open] do
            {:noreply, open_notifications_dropdown(socket)}
          else
            unread = Engagement.unread_count(socket.assigns.current_user.id)
            {:noreply, assign(socket, :notification_count, unread)}
          end
        else
          {:noreply, socket}
        end
      end

      def handle_info({:notifications_read, _}, socket) do
        {:noreply, assign(socket, :notification_count, 0)}
      end

      @impl true
      def handle_event("toggle_notifications_dropdown", _params, socket) do
        if socket.assigns[:notification_dropdown_open] do
          {:noreply, close_notifications_dropdown(socket)}
        else
          {:noreply, open_notifications_dropdown(socket)}
        end
      end

      def handle_event("close_notifications_dropdown", _params, socket) do
        {:noreply, close_notifications_dropdown(socket)}
      end

      defp open_notifications_dropdown(socket) do
        user = socket.assigns.current_user

        raw = Engagement.list_notifications(user.id, limit: 8)
        grouped = Grouper.group(raw)

        Engagement.mark_all_read(user)

        Phoenix.PubSub.broadcast(
          OGrupoDeEstudos.PubSub,
          "notifications:#{user.id}",
          {:notifications_read, :all}
        )

        assign(socket,
          notification_dropdown_open: true,
          notification_preview_groups: grouped,
          notification_count: 0
        )
      end

      defp close_notifications_dropdown(socket) do
        assign(socket, :notification_dropdown_open, false)
      end
    end
  end
end
