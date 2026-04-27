defmodule OGrupoDeEstudosWeb.Handlers.SocialBubbleHandlers do
  @moduledoc """
  Macro providing event handlers for the SocialBubble component.

  Usage: `use OGrupoDeEstudosWeb.Handlers.SocialBubbleHandlers`

  Provides:
  - `toggle_bubble` — opens/closes the panel, lazy-loads data
  - `close_bubble` — closes the panel (used by phx-click-away)
  - `bubble_search` — searches users within the panel

  Requires `bubble_open`, `suggested_users`, `bubble_following_list`,
  `bubble_search`, `bubble_search_results`, `following_count`,
  and `followers_count` assigns.
  """

  defmacro __using__(_opts) do
    quote do
      def handle_event("toggle_bubble", _params, socket) do
        is_open = !socket.assigns[:bubble_open]

        socket =
          if is_open do
            user = socket.assigns.current_user

            suggested =
              OGrupoDeEstudos.Engagement.suggest_users(user, limit: 5)

            following_list =
              OGrupoDeEstudos.Engagement.list_following(user.id)

            following_count =
              OGrupoDeEstudos.Engagement.count_following(user.id)

            followers_count =
              OGrupoDeEstudos.Engagement.count_followers(user.id)

            assign(socket,
              bubble_open: true,
              suggested_users: suggested,
              bubble_following_list: following_list,
              following_count: following_count,
              followers_count: followers_count,
              bubble_search: "",
              bubble_search_results: []
            )
          else
            assign(socket,
              bubble_open: false,
              bubble_search: "",
              bubble_search_results: []
            )
          end

        {:noreply, socket}
      end

      def handle_event("close_bubble", _params, socket) do
        {:noreply,
         assign(socket,
           bubble_open: false,
           bubble_search: "",
           bubble_search_results: []
         )}
      end

      def handle_event("bubble_search", params, socket) do
        term = params["value"] || params["term"] || ""

        results =
          OGrupoDeEstudos.Accounts.search_users(term,
            exclude_id: socket.assigns.current_user.id
          )

        {:noreply,
         assign(socket,
           bubble_search: term,
           bubble_search_results: results
         )}
      end
    end
  end
end
