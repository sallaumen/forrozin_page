defmodule OGrupoDeEstudosWeb.Handlers.FollowHandlers do
  @moduledoc """
  Macro providing a generic `toggle_follow` event handler.

  Usage: `use OGrupoDeEstudosWeb.Handlers.FollowHandlers`

  Requires the LiveView to have `following_user_ids` in its assigns (a MapSet).
  On toggle, refreshes `following_user_ids` and `suggested_users` (if present).
  """

  defmacro __using__(_opts) do
    quote do
      alias OGrupoDeEstudos.Engagement
      alias OGrupoDeEstudosWeb.Helpers.RateLimit

      def handle_event("toggle_follow", %{"user-id" => target_id}, socket) do
        user = socket.assigns.current_user
        result = Engagement.toggle_follow(user.id, target_id)
        socket = RateLimit.maybe_flash_rate_limit(socket, result)
        following = Engagement.following_ids(user.id)

        socket = assign(socket, following_user_ids: following)

        # Refresh bubble suggestions if bubble is present
        socket =
          if Map.has_key?(socket.assigns, :suggested_users) do
            users = Engagement.suggest_users(user, limit: 3)
            assign(socket, suggested_users: users)
          else
            socket
          end

        {:noreply, socket}
      end
    end
  end
end
