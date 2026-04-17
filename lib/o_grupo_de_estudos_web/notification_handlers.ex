defmodule OGrupoDeEstudosWeb.NotificationHandlers do
  @moduledoc "Shared handle_info clauses for notification PubSub messages."

  defmacro __using__(_opts) do
    quote do
      def handle_info({:new_notification, _count}, socket) do
        if socket.assigns[:current_user] do
          unread = OGrupoDeEstudos.Engagement.unread_count(socket.assigns.current_user.id)
          {:noreply, assign(socket, :notification_count, unread)}
        else
          {:noreply, socket}
        end
      end

      def handle_info({:notifications_read, _}, socket) do
        {:noreply, assign(socket, :notification_count, 0)}
      end
    end
  end
end
