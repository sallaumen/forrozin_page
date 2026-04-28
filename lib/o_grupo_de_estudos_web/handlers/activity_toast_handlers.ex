defmodule OGrupoDeEstudosWeb.Handlers.ActivityToastHandlers do
  @moduledoc """
  Macro providing real-time activity toast handling for LiveViews.

  Subscribes to the current user's activity channel on mount and
  handles incoming toast messages. Shows ephemeral toasts that
  auto-dismiss after 4 seconds.

  ## Disabling

  Remove `use ActivityToastHandlers` from LiveViews to stop showing
  toasts. The PubSub broadcasts will still happen but be ignored.
  """

  defmacro __using__(_opts) do
    quote do
      def handle_info({:activity_toast, message}, socket) do
        # Only show if not already showing a toast
        if socket.assigns[:activity_toast] == nil do
          # Auto-dismiss after 4 seconds
          Process.send_after(self(), :dismiss_activity_toast, 4000)
          {:noreply, assign(socket, :activity_toast, message)}
        else
          {:noreply, socket}
        end
      end

      def handle_info(:dismiss_activity_toast, socket) do
        {:noreply, assign(socket, :activity_toast, nil)}
      end
    end
  end
end
