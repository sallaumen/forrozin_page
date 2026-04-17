defmodule OGrupoDeEstudosWeb.CommunityLive do
  @moduledoc """
  Community page — shows suggested steps and public sequences.

  Steps tabs: all | pending (admin only) | approved.
  Sequences tab: all public sequences sorted by like count, with inline
  comment expansion (lazy-loaded) and YouTube embeds.
  Accessible to all authenticated users.
  """

  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.{Accounts, Encyclopedia, Engagement, Sequences}
  alias OGrupoDeEstudos.Engagement.Comments.SequenceCommentQuery

  on_mount {OGrupoDeEstudosWeb.UserAuth, :ensure_authenticated}
  on_mount {OGrupoDeEstudosWeb.Navigation, :primary}
  on_mount {OGrupoDeEstudosWeb.Hooks.NotificationSubscriber, :default}

  import OGrupoDeEstudosWeb.UI.TopNav
  import OGrupoDeEstudosWeb.UI.BottomNav
  import OGrupoDeEstudosWeb.UI.CommentThread
  import OGrupoDeEstudosWeb.CoreComponents, only: [icon: 1]

  use OGrupoDeEstudosWeb.NotificationHandlers

  @impl true
  def mount(_params, _session, socket) do
    admin = Accounts.admin?(socket.assigns.current_user)
    steps = Encyclopedia.list_suggested_steps_filtered(filter: "all")

    {:ok,
     assign(socket,
       page_title: "Comunidade",
       is_admin: admin,
       active_section: "steps",
       active_tab: "all",
       steps: steps,
       sequences: [],
       sequence_likes: %{liked_ids: MapSet.new(), counts: %{}},
       expanded_seq: nil,
       expanded_seq_comments: [],
       expanded_seq_comment_likes: %{liked_ids: MapSet.new(), counts: %{}},
       expanded_seq_replies_map: %{},
       expanded_seq_replying_to: nil
     )}
  end

  @impl true
  def handle_event("switch_section", %{"section" => "sequences"}, socket) do
    sequences = Sequences.list_all_public_sequences()

    sequence_ids = Enum.map(sequences, & &1.id)
    current_user = socket.assigns.current_user
    sequence_likes = Engagement.likes_map(current_user.id, "sequence", sequence_ids)

    sorted =
      Enum.sort_by(
        sequences,
        fn seq ->
          {-seq.like_count, seq.inserted_at}
        end
      )

    {:noreply,
     assign(socket,
       active_section: "sequences",
       sequences: sorted,
       sequence_likes: sequence_likes,
       expanded_seq: nil,
       expanded_seq_comments: [],
       expanded_seq_comment_likes: %{liked_ids: MapSet.new(), counts: %{}},
       expanded_seq_replies_map: %{},
       expanded_seq_replying_to: nil
     )}
  end

  def handle_event("switch_section", %{"section" => "steps"}, socket) do
    {:noreply, assign(socket, active_section: "steps")}
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    # Non-admins cannot access the pending tab
    tab = if tab == "pending" and not socket.assigns.is_admin, do: "all", else: tab
    steps = Encyclopedia.list_suggested_steps_filtered(filter: tab)
    {:noreply, assign(socket, active_tab: tab, steps: steps)}
  end

  def handle_event("toggle_like", %{"type" => "sequence", "id" => id}, socket) do
    current_user = socket.assigns.current_user

    case Engagement.toggle_like(current_user.id, "sequence", id) do
      {:ok, _action} ->
        sequences = socket.assigns.sequences
        sequence_ids = Enum.map(sequences, & &1.id)
        sequence_likes = Engagement.likes_map(current_user.id, "sequence", sequence_ids)

        sorted =
          Enum.sort_by(
            sequences,
            fn seq ->
              {-seq.like_count, seq.inserted_at}
            end
          )

        {:noreply, assign(socket, sequences: sorted, sequence_likes: sequence_likes)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Não foi possível registrar o like.")}
    end
  end

  # ── Inline expansion: sequence comments ────────────────────────────────

  def handle_event("toggle_seq_expand", %{"seq-id" => seq_id}, socket) do
    if socket.assigns.expanded_seq == seq_id do
      {:noreply,
       assign(socket,
         expanded_seq: nil,
         expanded_seq_comments: [],
         expanded_seq_comment_likes: %{liked_ids: MapSet.new(), counts: %{}},
         expanded_seq_replies_map: %{},
         expanded_seq_replying_to: nil
       )}
    else
      user = socket.assigns.current_user
      comments = Engagement.list_sequence_comments(seq_id, limit: 5)
      comment_ids = Enum.map(comments, & &1.id)
      comment_likes = Engagement.likes_map(user.id, "sequence_comment", comment_ids)

      {:noreply,
       assign(socket,
         expanded_seq: seq_id,
         expanded_seq_comments: comments,
         expanded_seq_comment_likes: comment_likes,
         expanded_seq_replies_map: %{},
         expanded_seq_replying_to: nil
       )}
    end
  end

  def handle_event("create_comment", %{"body" => body}, socket) do
    user = socket.assigns.current_user
    seq_id = socket.assigns.expanded_seq

    case Engagement.create_sequence_comment(user, seq_id, %{body: body}) do
      {:ok, _} -> {:noreply, reload_seq_expanded(socket)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Erro ao postar comentário.")}
    end
  end

  def handle_event("create_reply", %{"body" => body, "parent-id" => parent_id}, socket) do
    user = socket.assigns.current_user
    seq_id = socket.assigns.expanded_seq

    case Engagement.create_sequence_comment(user, seq_id, %{
           body: body,
           parent_sequence_comment_id: parent_id
         }) do
      {:ok, _} ->
        {:noreply, socket |> reload_seq_expanded() |> assign(:expanded_seq_replying_to, nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao postar resposta.")}
    end
  end

  def handle_event("toggle_comment_like", %{"type" => type, "id" => id}, socket) do
    user = socket.assigns.current_user

    case Engagement.toggle_like(user.id, type, id) do
      {:ok, _} -> {:noreply, reload_seq_expanded(socket)}
      {:error, _} -> {:noreply, socket}
    end
  end

  def handle_event("start_reply", %{"id" => comment_id}, socket) do
    {:noreply, assign(socket, :expanded_seq_replying_to, comment_id)}
  end

  def handle_event("toggle_replies", %{"id" => comment_id}, socket) do
    replies_map = socket.assigns.expanded_seq_replies_map

    if Map.has_key?(replies_map, comment_id) do
      {:noreply,
       assign(socket, :expanded_seq_replies_map, Map.delete(replies_map, comment_id))}
    else
      replies = Engagement.list_replies(SequenceCommentQuery, comment_id)
      new_map = Map.put(replies_map, comment_id, replies)
      socket = assign(socket, :expanded_seq_replies_map, new_map)
      {:noreply, reload_seq_expanded_likes(socket)}
    end
  end

  def handle_event("delete_comment", %{"id" => id, "type" => "sequence_comment"}, socket) do
    user = socket.assigns.current_user
    alias OGrupoDeEstudos.Engagement.Comments.SequenceComment
    comment = OGrupoDeEstudos.Repo.get!(SequenceComment, id)

    case Engagement.delete_sequence_comment(user, comment) do
      {:ok, _} -> {:noreply, reload_seq_expanded(socket)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Sem permissão.")}
    end
  end

  # ── Private helpers ─────────────────────────────────────────────────────

  defp reload_seq_expanded(socket) do
    seq_id = socket.assigns.expanded_seq
    user = socket.assigns.current_user

    comments = Engagement.list_sequence_comments(seq_id, limit: 5)
    comment_ids = Enum.map(comments, & &1.id)

    replies_map =
      socket.assigns.expanded_seq_replies_map
      |> Map.keys()
      |> Enum.reduce(%{}, fn parent_id, acc ->
        replies = Engagement.list_replies(SequenceCommentQuery, parent_id)
        Map.put(acc, parent_id, replies)
      end)

    reply_ids =
      replies_map |> Map.values() |> List.flatten() |> Enum.map(& &1.id)

    all_ids = comment_ids ++ reply_ids
    comment_likes = Engagement.likes_map(user.id, "sequence_comment", all_ids)

    assign(socket,
      expanded_seq_comments: comments,
      expanded_seq_comment_likes: comment_likes,
      expanded_seq_replies_map: replies_map
    )
  end

  defp reload_seq_expanded_likes(socket) do
    user = socket.assigns.current_user
    comment_ids = Enum.map(socket.assigns.expanded_seq_comments, & &1.id)

    reply_ids =
      socket.assigns.expanded_seq_replies_map
      |> Map.values()
      |> List.flatten()
      |> Enum.map(& &1.id)

    all_ids = comment_ids ++ reply_ids
    comment_likes = Engagement.likes_map(user.id, "sequence_comment", all_ids)
    assign(socket, :expanded_seq_comment_likes, comment_likes)
  end

  # ── View helpers ────────────────────────────────────────────────────────

  def category_color(%{category: %{color: color}}), do: color
  def category_color(_), do: "#7f8c8d"

  def category_label(%{category: %{label: label}}), do: label
  def category_label(_), do: ""

  def connection_count(%{connections_as_source: conns_out, connections_as_target: conns_in}) do
    length(conns_out) + length(conns_in)
  end

  def connection_count(_), do: 0

  def youtube_embed_url(url) when is_binary(url) do
    cond do
      Regex.match?(~r/youtu\.be\/([a-zA-Z0-9_-]+)/, url) ->
        [_, id] = Regex.run(~r/youtu\.be\/([a-zA-Z0-9_-]+)/, url)
        {:embed, "https://www.youtube.com/embed/#{id}"}

      Regex.match?(~r/youtube\.com\/watch\?v=([a-zA-Z0-9_-]+)/, url) ->
        [_, id] = Regex.run(~r/youtube\.com\/watch\?v=([a-zA-Z0-9_-]+)/, url)
        {:embed, "https://www.youtube.com/embed/#{id}"}

      Regex.match?(~r/youtube\.com\/shorts\/([a-zA-Z0-9_-]+)/, url) ->
        [_, id] = Regex.run(~r/youtube\.com\/shorts\/([a-zA-Z0-9_-]+)/, url)
        {:embed, "https://www.youtube.com/embed/#{id}"}

      true ->
        :external
    end
  end

  def youtube_embed_url(_), do: :external
end
