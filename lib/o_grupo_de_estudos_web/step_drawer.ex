defmodule OGrupoDeEstudosWeb.StepDrawer do
  @moduledoc """
  Shared state of the step detail side panel (drawer).

  Single source of truth for the loading and the assigns the `StepDetail`
  component consumes, so CollectionLive and GraphVisualLive show the same panel.
  """

  import Phoenix.Component, only: [assign: 2, assign: 3]

  alias OGrupoDeEstudos.Engagement
  alias OGrupoDeEstudos.Encyclopedia
  alias OGrupoDeEstudosWeb.StepDetail

  @doc "Initial drawer assigns (for the mount of the host LiveView)."
  def initial_assigns do
    [
      drawer_open: false,
      drawer_item: nil,
      drawer_step_image: nil,
      drawer_connections_out: [],
      drawer_connections_in: [],
      connections_expanded: false,
      drawer_links: [],
      drawer_link_likes: %{liked_ids: MapSet.new(), counts: %{}},
      drawer_like_count: 0,
      drawer_liked: false,
      drawer_favorited: false,
      can_edit_drawer: false,
      expanded_step: nil,
      expanded_comments: [],
      expanded_comment_likes: %{liked_ids: MapSet.new(), counts: %{}},
      expanded_replies_map: %{},
      expanded_replying_to: nil,
      expanded_video: nil
    ]
  end

  @doc """
  Loads into the socket everything the step detail consumes: the step plus
  connections, links, likes and comments. Uses `socket.assigns.edit_mode` (admin
  or owner) to decide what to bring.
  """
  def load_step(socket, code) do
    user_id = socket.assigns.current_user.id

    step =
      Encyclopedia.get_step_by(
        code: code,
        preload: [:suggested_by, :category, :technical_concepts, :last_edited_by]
      )

    links =
      Encyclopedia.list_step_links_by(step_id: step.id, approved: true, preload: [:submitted_by])

    link_likes = Engagement.likes_map(user_id, "step_link", Enum.map(links, & &1.id))
    sorted_links = Enum.sort_by(links, fn link -> -Map.get(link_likes.counts, link.id, 0) end)

    comments = Engagement.list_step_comments(step.id)
    comment_likes = Engagement.likes_map(user_id, "step_comment", Enum.map(comments, & &1.id))

    assign(socket,
      drawer_item: step,
      drawer_step_image: StepDetail.resolve_step_image(step),
      drawer_connections_out:
        Encyclopedia.list_connections_by(
          source_step_id: step.id,
          preload: [target_step: :category]
        ),
      drawer_connections_in:
        Encyclopedia.list_connections_by(
          target_step_id: step.id,
          preload: [source_step: :category]
        ),
      drawer_links: sorted_links,
      drawer_link_likes: link_likes,
      drawer_like_count: step.like_count,
      connections_expanded: false,
      drawer_liked: Engagement.liked?(user_id, "step", step.id),
      drawer_favorited: Engagement.favorited?(user_id, "step", step.id),
      drawer_learned: Engagement.learned?(user_id, step.id),
      drawer_seen_in_workshops: OGrupoDeEstudos.Workshops.workshops_where_seen(user_id, step.id),
      can_edit_drawer: socket.assigns.edit_mode or step.suggested_by_id == user_id,
      expanded_step: step.id,
      expanded_comments: comments,
      expanded_comment_likes: comment_likes,
      expanded_replies_map: %{},
      expanded_replying_to: nil,
      expanded_video: nil
    )
  end

  @doc "Reloads the comments (and open replies) of the step focused in the drawer."
  def reload_comments(socket) do
    step_id = socket.assigns.expanded_step
    user = socket.assigns.current_user

    comments = Engagement.list_step_comments(step_id)
    comment_ids = Enum.map(comments, & &1.id)

    replies_map =
      socket.assigns.expanded_replies_map
      |> Map.keys()
      |> Enum.reduce(%{}, fn parent_id, acc ->
        Map.put(acc, parent_id, Engagement.list_step_comment_replies(parent_id))
      end)

    reply_ids = replies_map |> Map.values() |> List.flatten() |> Enum.map(& &1.id)
    comment_likes = Engagement.likes_map(user.id, "step_comment", comment_ids ++ reply_ids)

    assign(socket,
      expanded_comments: comments,
      expanded_comment_likes: comment_likes,
      expanded_replies_map: replies_map
    )
  end

  @doc "Reloads only the comment likes (after opening replies or liking)."
  def reload_comment_likes(socket) do
    user = socket.assigns.current_user
    comment_ids = Enum.map(socket.assigns.expanded_comments, & &1.id)

    reply_ids =
      socket.assigns.expanded_replies_map |> Map.values() |> List.flatten() |> Enum.map(& &1.id)

    comment_likes = Engagement.likes_map(user.id, "step_comment", comment_ids ++ reply_ids)
    assign(socket, :expanded_comment_likes, comment_likes)
  end

  @doc "Syncs like, favorite and count of the drawer when the touched step is the open one."
  def sync_engagement(socket, step_id) do
    case socket.assigns.drawer_item do
      %{id: ^step_id} ->
        user_id = socket.assigns.current_user.id

        assign(socket,
          drawer_liked: Engagement.liked?(user_id, "step", step_id),
          drawer_favorited: Engagement.favorited?(user_id, "step", step_id),
          drawer_learned: Engagement.learned?(user_id, step_id),
          drawer_like_count: Engagement.count_likes("step", step_id)
        )

      _ ->
        socket
    end
  end

  @doc "Reloads only the link likes (after liking a link or video)."
  def reload_link_likes(socket) do
    user_id = socket.assigns.current_user.id
    link_ids = Enum.map(socket.assigns.drawer_links, & &1.id)
    link_likes = Engagement.likes_map(user_id, "step_link", link_ids)

    sorted =
      Enum.sort_by(socket.assigns.drawer_links, fn link ->
        -Map.get(link_likes.counts, link.id, 0)
      end)

    assign(socket, drawer_link_likes: link_likes, drawer_links: sorted)
  end
end
