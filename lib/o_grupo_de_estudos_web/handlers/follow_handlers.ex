defmodule OGrupoDeEstudosWeb.Handlers.FollowHandlers do
  @moduledoc """
  Macro providing a generic `toggle_follow` event handler.

  Usage: `use OGrupoDeEstudosWeb.Handlers.FollowHandlers`

  Requires the LiveView to have `following_user_ids` in its assigns (a MapSet).
  On toggle, refreshes `following_user_ids` from the database.
  """

  defmacro __using__(_opts) do
    quote do
      def handle_event("toggle_follow", %{"user-id" => target_id}, socket) do
        user = socket.assigns.current_user
        result = OGrupoDeEstudos.Engagement.toggle_follow(user.id, target_id)
        socket = OGrupoDeEstudosWeb.Helpers.RateLimit.maybe_flash_rate_limit(socket, result)
        following = OGrupoDeEstudos.Engagement.following_ids(user.id)
        {:noreply, assign(socket, following_user_ids: following)}
      end
    end
  end
end
