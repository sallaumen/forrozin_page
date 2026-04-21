defmodule OGrupoDeEstudosWeb.CommunityLive do
  @moduledoc """
  Community page — shows suggested steps and public sequences.

  Steps: single "Todas" tab for regular users; admins also see "Pendentes".
  Search by name/code and filter by category (steps); search by name (sequences).
  Sequences tab: all public sequences sorted by like count, with inline
  comment expansion (lazy-loaded) and YouTube embeds.
  Accessible to all authenticated users.
  """

  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.{Accounts, Encyclopedia, Engagement, Sequences}
  alias OGrupoDeEstudos.Engagement.Comments.SequenceCommentQuery
  alias OGrupoDeEstudos.Engagement.Badges

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
    step_ids = Enum.map(steps, & &1.id)
    step_likes = Engagement.likes_map(socket.assigns.current_user.id, "step", step_ids)
    step_favorites = Engagement.favorites_map(socket.assigns.current_user.id, "step", step_ids)
    categories = Encyclopedia.list_categories()

    {:ok,
     assign(socket,
       page_title: "Comunidade",
       is_admin: admin,
       active_section: "steps",
       active_tab: "all",
       steps: steps,
       steps_all: steps,
       step_likes: step_likes,
       step_favorites: step_favorites,
       step_search: "",
       step_category_filter: "all",
       categories: categories,
       sequences: [],
       sequences_all: [],
       sequence_likes: %{liked_ids: MapSet.new(), counts: %{}},
       seq_favorites: MapSet.new(),
       seq_search: "",
       expanded_seq: nil,
       expanded_seq_comments: [],
       expanded_seq_comment_likes: %{liked_ids: MapSet.new(), counts: %{}},
       expanded_seq_replies_map: %{},
       expanded_seq_replying_to: nil,
       followers_sub_tab: "following",
       followers_search: "",
       followers_list: [],
       following_count: 0,
       followers_count: 0,
       followers_following_map: MapSet.new(),
       following_user_ids: load_following_user_ids(socket.assigns.current_user.id),
       people_search: "",
       people_results: []
     )}
  end

  @impl true
  def handle_event("switch_section", %{"section" => "sequences"}, socket) do
    sequences = Sequences.list_all_public_sequences()

    sequence_ids = Enum.map(sequences, & &1.id)
    current_user = socket.assigns.current_user
    sequence_likes = Engagement.likes_map(current_user.id, "sequence", sequence_ids)
    seq_favorites = Engagement.favorites_map(current_user.id, "sequence", sequence_ids)

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
       sequences_all: sorted,
       sequence_likes: sequence_likes,
       seq_favorites: seq_favorites,
       seq_search: "",
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

  def handle_event("switch_section", %{"section" => "followers"}, socket) do
    user = socket.assigns.current_user
    following = Engagement.list_following(user.id)
    following_count = Engagement.count_following(user.id)
    followers_count = Engagement.count_followers(user.id)
    user_ids = Enum.map(following, & &1.id)
    following_map = following_ids_set(user.id, user_ids)

    {:noreply,
     assign(socket,
       active_section: "followers",
       followers_sub_tab: "following",
       followers_list: following,
       following_count: following_count,
       followers_count: followers_count,
       followers_following_map: following_map,
       followers_search: ""
     )}
  end

  def handle_event("switch_followers_tab", %{"tab" => tab}, socket) do
    user = socket.assigns.current_user

    list =
      case tab do
        "following" -> Engagement.list_following(user.id, search: socket.assigns.followers_search)
        "followers" -> Engagement.list_followers(user.id, search: socket.assigns.followers_search)
      end

    user_ids = Enum.map(list, & &1.id)

    {:noreply,
     assign(socket,
       followers_sub_tab: tab,
       followers_list: list,
       followers_following_map: following_ids_set(user.id, user_ids)
     )}
  end

  def handle_event("search_followers", params, socket) do
    term = params["value"] || params["term"] || ""
    user = socket.assigns.current_user

    list =
      case socket.assigns.followers_sub_tab do
        "following" -> Engagement.list_following(user.id, search: term)
        "followers" -> Engagement.list_followers(user.id, search: term)
      end

    user_ids = Enum.map(list, & &1.id)

    {:noreply,
     assign(socket,
       followers_search: term,
       followers_list: list,
       followers_following_map: following_ids_set(user.id, user_ids)
     )}
  end

  def handle_event("toggle_follow", %{"user-id" => target_id}, socket) do
    user = socket.assigns.current_user
    result = Engagement.toggle_follow(user.id, target_id)
    socket = OGrupoDeEstudosWeb.Helpers.RateLimit.maybe_flash_rate_limit(socket, result)

    list =
      case socket.assigns.followers_sub_tab do
        "following" -> Engagement.list_following(user.id, search: socket.assigns.followers_search)
        "followers" -> Engagement.list_followers(user.id, search: socket.assigns.followers_search)
      end

    user_ids = Enum.map(list, & &1.id)

    {:noreply,
     assign(socket,
       followers_list: list,
       following_count: Engagement.count_following(user.id),
       followers_count: Engagement.count_followers(user.id),
       followers_following_map: following_ids_set(user.id, user_ids),
       following_user_ids: load_following_user_ids(user.id)
     )}
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    # Non-admins cannot access the pending tab
    tab = if tab == "pending" and not socket.assigns.is_admin, do: "all", else: tab
    steps = Encyclopedia.list_suggested_steps_filtered(filter: tab)
    step_ids = Enum.map(steps, & &1.id)
    user = socket.assigns.current_user
    step_likes = Engagement.likes_map(user.id, "step", step_ids)
    step_favorites = Engagement.favorites_map(user.id, "step", step_ids)

    {:noreply,
     assign(socket,
       active_tab: tab,
       steps: steps,
       steps_all: steps,
       step_likes: step_likes,
       step_favorites: step_favorites,
       step_search: "",
       step_category_filter: "all"
     )}
  end

  def handle_event("search_steps", params, socket) do
    term = params["value"] || params["term"] || ""
    filtered = filter_steps(socket.assigns.steps_all, term, socket.assigns.step_category_filter)
    {:noreply, assign(socket, step_search: term, steps: filtered)}
  end

  def handle_event("filter_step_category", %{"category" => cat}, socket) do
    filtered = filter_steps(socket.assigns.steps_all, socket.assigns.step_search, cat)
    {:noreply, assign(socket, step_category_filter: cat, steps: filtered)}
  end

  def handle_event("search_sequences", params, socket) do
    term = params["value"] || params["term"] || ""

    filtered =
      if term == "" do
        socket.assigns.sequences_all
      else
        lower = String.downcase(term)

        Enum.filter(socket.assigns.sequences_all, fn seq ->
          String.contains?(String.downcase(seq.name), lower)
        end)
      end

    {:noreply, assign(socket, seq_search: term, sequences: filtered)}
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

  def handle_event("approve_step", %{"code" => code}, socket) do
    if not socket.assigns.is_admin do
      {:noreply, socket}
    else
      step = OGrupoDeEstudos.Encyclopedia.StepQuery.get_by(code: code)

      if step do
        OGrupoDeEstudos.Admin.update_step(step, %{approved: true})

        steps =
          OGrupoDeEstudos.Encyclopedia.list_suggested_steps_filtered(
            filter: socket.assigns.active_tab
          )

        {:noreply,
         socket
         |> assign(:steps, steps)
         |> assign(:steps_all, steps)
         |> put_flash(:info, "Passo '#{step.name}' aprovado!")}
      else
        {:noreply, socket}
      end
    end
  end

  def handle_event("toggle_step_like", %{"id" => step_id}, socket) do
    user = socket.assigns.current_user

    case Engagement.toggle_like(user.id, "step", step_id) do
      {:ok, _} ->
        step_ids = Enum.map(socket.assigns.steps, & &1.id)
        step_likes = Engagement.likes_map(user.id, "step", step_ids)
        step_favorites = Engagement.favorites_map(user.id, "step", step_ids)
        {:noreply, assign(socket, step_likes: step_likes, step_favorites: step_favorites)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_event("toggle_step_favorite", %{"id" => step_id}, socket) do
    user = socket.assigns.current_user

    case Engagement.toggle_favorite(user.id, "step", step_id) do
      {:ok, _} ->
        step_ids = Enum.map(socket.assigns.steps, & &1.id)
        step_likes = Engagement.likes_map(user.id, "step", step_ids)
        step_favorites = Engagement.favorites_map(user.id, "step", step_ids)
        {:noreply, assign(socket, step_likes: step_likes, step_favorites: step_favorites)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_event("toggle_seq_favorite", %{"id" => seq_id}, socket) do
    user = socket.assigns.current_user

    case Engagement.toggle_favorite(user.id, "sequence", seq_id) do
      {:ok, _} ->
        sequence_ids = Enum.map(socket.assigns.sequences, & &1.id)
        seq_favorites = Engagement.favorites_map(user.id, "sequence", sequence_ids)
        {:noreply, assign(socket, seq_favorites: seq_favorites)}

      {:error, _} ->
        {:noreply, socket}
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
      {:error, :rate_limited} -> {:noreply, put_flash(socket, :error, "Calma! Muitos comentários seguidos. Espere alguns segundinhos.")}
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
      {:noreply, assign(socket, :expanded_seq_replies_map, Map.delete(replies_map, comment_id))}
    else
      replies = Engagement.list_replies(SequenceCommentQuery, comment_id)
      new_map = Map.put(replies_map, comment_id, replies)
      socket = assign(socket, :expanded_seq_replies_map, new_map)
      {:noreply, reload_seq_expanded_likes(socket)}
    end
  end

  def handle_event("search_people", params, socket) do
    term = params["value"] || params["term"] || ""

    results =
      if String.length(term) >= 2 do
        import Ecto.Query
        term_like = "%#{String.downcase(term)}%"

        from(u in OGrupoDeEstudos.Accounts.User,
          where: ilike(u.username, ^term_like) or ilike(u.name, ^term_like),
          where: u.id != ^socket.assigns.current_user.id,
          order_by: [asc: u.username],
          limit: 5
        )
        |> OGrupoDeEstudos.Repo.all()
      else
        []
      end

    {:noreply, assign(socket, people_search: term, people_results: results)}
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

  defp following_ids_set(user_id, target_ids) do
    import Ecto.Query

    from(f in OGrupoDeEstudos.Engagement.Follow,
      where: f.follower_id == ^user_id and f.followed_id in ^target_ids,
      select: f.followed_id
    )
    |> OGrupoDeEstudos.Repo.all()
    |> MapSet.new()
  end

  defp load_following_user_ids(user_id) do
    import Ecto.Query

    from(f in OGrupoDeEstudos.Engagement.Follow,
      where: f.follower_id == ^user_id,
      select: f.followed_id
    )
    |> OGrupoDeEstudos.Repo.all()
    |> MapSet.new()
  end

  defp filter_steps(all_steps, search, category) do
    all_steps
    |> then(fn steps ->
      if search == "" do
        steps
      else
        term = String.downcase(search)

        Enum.filter(steps, fn s ->
          String.contains?(String.downcase(s.name), term) ||
            String.contains?(String.downcase(s.code), term)
        end)
      end
    end)
    |> then(fn steps ->
      if category == "all" do
        steps
      else
        Enum.filter(steps, fn s -> s.category && s.category.name == category end)
      end
    end)
  end

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
