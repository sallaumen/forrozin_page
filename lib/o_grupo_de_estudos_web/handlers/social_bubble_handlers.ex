defmodule OGrupoDeEstudosWeb.Handlers.SocialBubbleHandlers do
  @moduledoc """
  Macro providing event handlers for the SocialBubble component.

  Usage: `use OGrupoDeEstudosWeb.Handlers.SocialBubbleHandlers`

  Provides:
  - `toggle_bubble` — opens/closes the popover, lazy-loads suggestions
  - `close_bubble` — closes the popover (used by phx-click-away)

  Requires `bubble_open` and `suggested_users` assigns.
  """

  defmacro __using__(_opts) do
    quote do
      def handle_event("toggle_bubble", _params, socket) do
        is_open = !socket.assigns[:bubble_open]

        socket =
          if is_open and socket.assigns[:suggested_users] in [nil, []] do
            users =
              OGrupoDeEstudos.Engagement.suggest_users(
                socket.assigns.current_user,
                limit: 3
              )

            assign(socket, suggested_users: users, bubble_open: true)
          else
            assign(socket, bubble_open: is_open)
          end

        {:noreply, socket}
      end

      def handle_event("close_bubble", _params, socket) do
        {:noreply, assign(socket, bubble_open: false)}
      end
    end
  end
end
