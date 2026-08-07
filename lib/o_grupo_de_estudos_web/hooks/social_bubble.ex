defmodule OGrupoDeEstudosWeb.Hooks.SocialBubble do
  @moduledoc """
  on_mount hook: the empty state the people bubble starts from.

  The bubble is chrome, like the tab bar and the top bar, and chrome that each
  page has to remember to seed by hand is chrome that goes missing: eight of the
  thirteen pages carrying the tab bar had lost it, one page at a time.

  Nothing here queries. The panel loads who you follow when it opens, so a page
  that never opens it pays nothing for having it.
  """

  import Phoenix.Component, only: [assign: 2]

  def on_mount(:default, _params, _session, socket) do
    {:cont,
     assign(socket,
       bubble_open: false,
       bubble_tab: "following",
       bubble_following_list: [],
       bubble_followers_list: [],
       bubble_search: "",
       bubble_search_results: [],
       suggested_users: [],
       following_count: 0,
       followers_count: 0,
       following_user_ids: MapSet.new()
     )}
  end
end
