defmodule OGrupoDeEstudosWeb.SequenceLive do
  @moduledoc """
  Sequences page — shows all public sequences sorted by like count,
  with inline comment expansion (lazy-loaded) and YouTube embeds.

  Accessible to all authenticated users.
  """

  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.{Accounts, Engagement, Sequences}
  alias OGrupoDeEstudos.Engagement.Comments.SequenceCommentQuery
  alias OGrupoDeEstudosWeb.Helpers.RateLimit

  on_mount {OGrupoDeEstudosWeb.Navigation, :primary}
  on_mount {OGrupoDeEstudosWeb.Hooks.NotificationSubscriber, :default}

  import OGrupoDeEstudosWeb.UI.TopNav
  import OGrupoDeEstudosWeb.UI.BottomNav
  import OGrupoDeEstudosWeb.UI.UserAvatar
  import OGrupoDeEstudosWeb.UI.CommentThread
  import OGrupoDeEstudosWeb.CoreComponents, only: [icon: 1]
  import OGrupoDeEstudosWeb.UI.SocialBubble

  use OGrupoDeEstudosWeb.NotificationHandlers
  use OGrupoDeEstudosWeb.Handlers.SocialBubbleHandlers
  use OGrupoDeEstudosWeb.Handlers.ActivityToastHandlers

  import OGrupoDeEstudosWeb.UI.ActivityToast

  @impl true
  def mount(_params, _session, socket) do
    admin = Accounts.admin?(socket.assigns.current_user)
    current_user = socket.assigns.current_user

    community_sequences_all =
      current_user.id
      |> list_community_sequences()
      |> sort_sequences("popular")

    selected_discovery_section_id = nil

    community_sequences =
      filter_sequences(community_sequences_all, "", selected_discovery_section_id)

    my_sequences = []

    {:ok,
     socket
     |> assign(
       page_title: "Sequências",
       is_admin: admin,
       community_sequences_all: community_sequences_all,
       community_sequences: community_sequences,
       discovery_sections: build_discovery_sections(community_sequences_all),
       selected_discovery_section_id: selected_discovery_section_id,
       create_menu_open: false,
       seq_search: "",
       seq_sort: "popular",
       active_seq_tab: "community",
       deep_linked_sequence_id: nil,
       my_sequences: my_sequences,
       expanded_seq: nil,
       expanded_seq_comments: [],
       expanded_seq_comment_likes: %{liked_ids: MapSet.new(), counts: %{}},
       expanded_seq_replies_map: %{},
       expanded_seq_replying_to: nil,
       following_user_ids: Engagement.following_ids(current_user.id),
       bubble_open: false,
       bubble_tab: "following",
       bubble_following_list: [],
       bubble_followers_list: [],
       bubble_search: "",
       bubble_search_results: [],
       suggested_users: [],
       following_count: 0,
       followers_count: 0
     )
     |> assign_sequence_social_metadata(current_user.id, community_sequences_all, my_sequences)}
  end

  @impl true
  def handle_params(%{"sequence" => sequence_id}, _uri, socket)
      when is_binary(sequence_id) and sequence_id != "" do
    socket =
      socket
      |> assign(:active_seq_tab, "community")
      |> expand_sequence(sequence_id)
      |> assign(:deep_linked_sequence_id, sequence_id)
      |> push_event("scroll-to-element", %{id: "sequence-card-#{sequence_id}", block: "center"})

    {:noreply, socket}
  end

  def handle_params(_params, _uri, socket) do
    previous_deep_link = socket.assigns[:deep_linked_sequence_id]

    socket =
      if previous_deep_link && socket.assigns.expanded_seq == previous_deep_link do
        clear_expanded_sequence(socket)
      else
        socket
      end

    {:noreply, assign(socket, :deep_linked_sequence_id, nil)}
  end

  @impl true
  def handle_event("search_sequences", params, socket) do
    term = params["value"] || params["term"] || ""

    community_sequences =
      filter_sequences(
        socket.assigns.community_sequences_all,
        term,
        socket.assigns.selected_discovery_section_id
      )

    {:noreply, assign(socket, seq_search: term, community_sequences: community_sequences)}
  end

  def handle_event("sort_sequences", %{"sort" => sort}, socket) do
    current_user = socket.assigns.current_user

    community_sequences_all =
      current_user.id |> list_community_sequences() |> sort_sequences(sort)

    community_sequences =
      filter_sequences(
        community_sequences_all,
        socket.assigns.seq_search,
        socket.assigns.selected_discovery_section_id
      )

    {:noreply,
     socket
     |> assign(
       seq_sort: sort,
       community_sequences_all: community_sequences_all,
       community_sequences: community_sequences,
       discovery_sections: build_discovery_sections(community_sequences_all)
     )
     |> assign_sequence_social_metadata(
       current_user.id,
       community_sequences_all,
       socket.assigns.my_sequences
     )}
  end

  def handle_event("switch_seq_tab", %{"tab" => tab}, socket) do
    current_user = socket.assigns.current_user

    socket =
      case tab do
        "mine" ->
          my_sequences = list_my_sequences(current_user)

          socket
          |> assign(active_seq_tab: "mine", my_sequences: my_sequences, create_menu_open: false)
          |> assign_sequence_social_metadata(
            current_user.id,
            socket.assigns.community_sequences_all,
            my_sequences
          )

        _ ->
          socket
          |> assign(active_seq_tab: "community", create_menu_open: false)
          |> assign_sequence_social_metadata(
            current_user.id,
            socket.assigns.community_sequences_all,
            socket.assigns.my_sequences
          )
      end

    {:noreply, socket}
  end

  def handle_event("toggle_create_menu", _params, socket) do
    {:noreply, update(socket, :create_menu_open, &(!&1))}
  end

  def handle_event("close_create_menu", _params, socket) do
    {:noreply, assign(socket, :create_menu_open, false)}
  end

  def handle_event("select_discovery_section", %{"section-id" => section_id}, socket) do
    apply_discovery_filter(section_id, socket)
  end

  def handle_event("select_discovery_section", %{"section_id" => section_id}, socket) do
    apply_discovery_filter(section_id, socket)
  end

  def handle_event("toggle_like", %{"type" => "sequence", "id" => id}, socket) do
    current_user = socket.assigns.current_user

    case Engagement.toggle_like(current_user.id, "sequence", id) do
      {:ok, _action} ->
        community_sequences_all =
          current_user.id
          |> list_community_sequences()
          |> sort_sequences(socket.assigns.seq_sort)

        community_sequences =
          filter_sequences(
            community_sequences_all,
            socket.assigns.seq_search,
            socket.assigns.selected_discovery_section_id
          )

        my_sequences = maybe_refresh_my_sequences(socket)

        {:noreply,
         socket
         |> assign(
           community_sequences_all: community_sequences_all,
           community_sequences: community_sequences,
           discovery_sections: build_discovery_sections(community_sequences_all),
           my_sequences: my_sequences
         )
         |> assign_sequence_social_metadata(
           current_user.id,
           community_sequences_all,
           my_sequences
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Não foi possível registrar o like.")}
    end
  end

  def handle_event("toggle_seq_favorite", %{"id" => seq_id}, socket) do
    user = socket.assigns.current_user

    case Engagement.toggle_favorite(user.id, "sequence", seq_id) do
      {:ok, _} ->
        {:noreply,
         assign_sequence_social_metadata(
           socket,
           user.id,
           socket.assigns.community_sequences_all,
           socket.assigns.my_sequences
         )}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_event("toggle_follow", %{"user-id" => target_id}, socket) do
    user = socket.assigns.current_user
    result = Engagement.toggle_follow(user.id, target_id)
    socket = RateLimit.maybe_flash_rate_limit(socket, result)

    {:noreply,
     assign(socket,
       following_user_ids: Engagement.following_ids(user.id)
     )}
  end

  # ── Inline expansion: sequence comments ────────────────────────────────

  def handle_event("toggle_seq_expand", %{"seq-id" => seq_id}, socket) do
    current_deep_link = socket.assigns.deep_linked_sequence_id

    if socket.assigns.expanded_seq == seq_id do
      if current_deep_link == seq_id do
        {:noreply,
         socket
         |> assign(:deep_linked_sequence_id, nil)
         |> push_patch(to: ~p"/sequence", replace: true)}
      else
        {:noreply, clear_expanded_sequence(socket)}
      end
    else
      socket =
        socket
        |> assign(:deep_linked_sequence_id, nil)
        |> expand_sequence(seq_id)

      socket =
        if current_deep_link do
          push_patch(socket, to: ~p"/sequence", replace: true)
        else
          socket
        end

      {:noreply, socket}
    end
  end

  def handle_event("copy_sequence_link", %{"seq-id" => seq_id}, socket) do
    {:noreply,
     socket
     |> push_event("clipboard:copy", %{text: url(~p"/sequence?sequence=#{seq_id}")})
     |> put_flash(:info, "Link copiado")}
  end

  def handle_event("create_comment", %{"body" => body}, socket) do
    user = socket.assigns.current_user
    seq_id = socket.assigns.expanded_seq

    case Engagement.create_sequence_comment(user, seq_id, %{body: body}) do
      {:ok, _} ->
        {:noreply, reload_seq_expanded(socket)}

      {:error, :rate_limited} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Calma! Muitos comentários seguidos. Espere alguns segundinhos."
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao postar comentário.")}
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
      {:ok, _} -> {:noreply, reload_seq_expanded_likes(socket)}
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

  def handle_event("delete_comment", %{"id" => id, "type" => "sequence_comment"}, socket) do
    user = socket.assigns.current_user
    alias OGrupoDeEstudos.Engagement.Comments.SequenceComment
    comment = OGrupoDeEstudos.Repo.get!(SequenceComment, id)

    case Engagement.delete_sequence_comment(user, comment) do
      {:ok, _} -> {:noreply, reload_seq_expanded(socket)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Sem permissão.")}
    end
  end

  defp apply_discovery_filter(section_id, socket) do
    selected_discovery_section_id =
      if section_id in [nil, ""] do
        nil
      else
        section_id
      end

    selected_discovery_section_id =
      if socket.assigns.selected_discovery_section_id == selected_discovery_section_id do
        nil
      else
        selected_discovery_section_id
      end

    community_sequences =
      filter_sequences(
        socket.assigns.community_sequences_all,
        socket.assigns.seq_search,
        selected_discovery_section_id
      )

    {:noreply,
     assign(socket,
       selected_discovery_section_id: selected_discovery_section_id,
       community_sequences: community_sequences
     )}
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

    socket
    |> assign(
      expanded_seq_comments: comments,
      expanded_seq_comment_likes: comment_likes,
      expanded_seq_replies_map: replies_map
    )
    |> assign_seq_comment_count(seq_id)
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

  defp clear_expanded_sequence(socket) do
    assign(socket,
      expanded_seq: nil,
      expanded_seq_comments: [],
      expanded_seq_comment_likes: %{liked_ids: MapSet.new(), counts: %{}},
      expanded_seq_replies_map: %{},
      expanded_seq_replying_to: nil
    )
  end

  defp expand_sequence(socket, seq_id) do
    user = socket.assigns.current_user
    comments = Engagement.list_sequence_comments(seq_id, limit: 5)
    comment_ids = Enum.map(comments, & &1.id)
    comment_likes = Engagement.likes_map(user.id, "sequence_comment", comment_ids)

    assign(socket,
      expanded_seq: seq_id,
      expanded_seq_comments: comments,
      expanded_seq_comment_likes: comment_likes,
      expanded_seq_replies_map: %{},
      expanded_seq_replying_to: nil
    )
  end

  defp list_community_sequences(_user_id), do: Sequences.list_all_public_sequences()

  defp list_my_sequences(current_user) do
    current_user.id
    |> Sequences.list_public_user_sequences()
    |> Enum.map(&ensure_sequence_author(&1, current_user))
    |> sort_sequences("recent")
  end

  defp sort_sequences(sequences, "recent") do
    Enum.sort_by(sequences, & &1.inserted_at, {:desc, NaiveDateTime})
  end

  defp sort_sequences(sequences, _sort) do
    Enum.sort_by(sequences, fn seq ->
      {-seq.like_count, seq.inserted_at}
    end)
  end

  defp filter_sequences(sequences, term, selected_discovery_section_id) do
    lower = String.downcase(term)

    Enum.filter(sequences, fn seq ->
      matches_term? = term == "" || sequence_matches_term?(seq, lower)

      matches_discovery_section? =
        is_nil(selected_discovery_section_id) ||
          sequence_has_category?(seq, selected_discovery_section_id)

      matches_term? && matches_discovery_section?
    end)
  end

  defp sequence_matches_term?(seq, lower) do
    String.contains?(String.downcase(seq.name), lower) ||
      Enum.any?(seq.sequence_steps, fn sequence_step ->
        String.contains?(String.downcase(sequence_step.step.name), lower) ||
          String.contains?(String.downcase(sequence_step.step.code), lower)
      end)
  end

  defp build_discovery_sections(sequences) do
    sequences
    |> Enum.flat_map(&sequence_categories/1)
    |> Enum.frequencies()
    |> Enum.map(fn {{id, title}, sequence_count} ->
      %{id: id, title: title, sequence_count: sequence_count}
    end)
    |> Enum.sort_by(fn section -> {-section.sequence_count, section.title} end)
  end

  defp sequence_categories(seq) do
    seq.sequence_steps
    |> Enum.map(&category_tuple/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp category_tuple(%{step: %{category: nil}}), do: nil
  defp category_tuple(%{step: %{category: category}}), do: {category.id, category.label}

  defp sequence_has_category?(seq, category_id) do
    Enum.any?(seq.sequence_steps, fn sequence_step ->
      sequence_step.step.category && sequence_step.step.category.id == category_id
    end)
  end

  defp assign_sequence_social_metadata(socket, user_id, community_sequences_all, my_sequences) do
    sequence_ids =
      community_sequences_all
      |> Kernel.++(my_sequences)
      |> Enum.map(& &1.id)
      |> Enum.uniq()

    assign(socket,
      sequence_likes: Engagement.likes_map(user_id, "sequence", sequence_ids),
      seq_favorites: Engagement.favorites_map(user_id, "sequence", sequence_ids),
      seq_comment_counts: Engagement.comment_counts_for("sequence", sequence_ids)
    )
  end

  defp assign_seq_comment_count(socket, seq_id) do
    updated_count =
      seq_id
      |> then(&Engagement.comment_counts_for("sequence", [&1]))
      |> Map.get(seq_id, 0)

    assign(
      socket,
      :seq_comment_counts,
      Map.put(socket.assigns.seq_comment_counts, seq_id, updated_count)
    )
  end

  defp maybe_refresh_my_sequences(socket) do
    if socket.assigns.active_seq_tab == "mine" do
      list_my_sequences(socket.assigns.current_user)
    else
      socket.assigns.my_sequences
    end
  end

  defp ensure_sequence_author(
         %{user: %Ecto.Association.NotLoaded{}, user_id: user_id} = seq,
         current_user
       )
       when current_user.id == user_id do
    %{seq | user: current_user}
  end

  defp ensure_sequence_author(%{user: nil, user_id: user_id} = seq, current_user)
       when current_user.id == user_id do
    %{seq | user: current_user}
  end

  defp ensure_sequence_author(seq, _current_user), do: seq

  defp sequence_author(seq, current_user) do
    seq
    |> ensure_sequence_author(current_user)
    |> Map.get(:user)
    |> case do
      %Ecto.Association.NotLoaded{} -> nil
      user -> user
    end
  end

  defp sequence_author_username(seq, current_user) do
    case sequence_author(seq, current_user) do
      %{username: username} -> username
      _ -> "perfil"
    end
  end

  # ── Apresentação do card (cálculos puros) ───────────────────────────────

  # Paleta de marca usada para completar o glyph de 4 pontos quando a
  # sequência tem menos de 4 categorias distintas.
  @glyph_palette ["#e67e22", "#2980b9", "#27ae60", "#8e44ad"]
  @map_node_cap 12

  defp sequence_step_codes(seq), do: Enum.map(seq.sequence_steps, & &1.step.code)

  defp step_category_color(%{step: %{category: %{color: color}}}) when is_binary(color), do: color
  defp step_category_color(_), do: "#9a7a5a"

  defp sequence_categories_with_color(seq) do
    seq.sequence_steps
    |> Enum.map(& &1.step.category)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(& &1.id)
    |> Enum.map(&%{label: &1.label, color: &1.color})
  end

  defp sequence_accent_color(seq) do
    case sequence_categories_with_color(seq) do
      [%{color: color} | _] -> color
      _ -> "#e67e22"
    end
  end

  defp sequence_glyph_colors(seq) do
    category_colors = seq.sequence_steps |> Enum.map(&step_category_color/1) |> Enum.uniq()
    (category_colors ++ @glyph_palette) |> Enum.uniq() |> Enum.take(4)
  end

  # Monta uma prévia em SVG no estilo do mapa real (/graph/visual): nós
  # agrupados por categoria em clusters com zonas translúcidas, passo inicial
  # como hub central, e o caminho da sequência ligando os nós com setas
  # direcionais coloridas pela categoria de origem. Nós são deduplicados por
  # código, então revisitas reaproveitam o mesmo nó (como no grafo real).
  defp sequence_map_nodes(seq) do
    steps = Enum.take(seq.sequence_steps, @map_node_cap)
    codes = Enum.map(steps, & &1.step.code)
    start_code = List.first(codes)

    unique = Enum.uniq_by(steps, & &1.step.code)
    cats = unique |> Enum.map(&step_category_key/1) |> Enum.uniq()
    centers = cluster_centers(cats)

    nodes =
      unique
      |> Enum.group_by(&step_category_key/1)
      |> Enum.flat_map(fn {cat, members} ->
        scatter_cluster(members, Map.get(centers, cat, {100.0, 64.0}))
      end)
      |> Enum.map(&Map.put(&1, :hub, &1.code == start_code))

    positions = Map.new(nodes, &{&1.code, &1})
    edges = sequence_path_edges(codes, positions)
    markers = edge_markers(edges)
    suffix_by_color = Map.new(markers, &{&1.color, &1.suffix})
    edges = Enum.map(edges, &Map.put(&1, :marker, Map.fetch!(suffix_by_color, &1.color)))

    %{nodes: nodes, edges: edges, zones: cluster_zones(nodes), markers: markers}
  end

  defp step_category_key(%{step: %{category: %{id: id}}}), do: id
  defp step_category_key(_), do: :uncategorized

  defp cluster_centers([]), do: %{}

  # Hub (primeira categoria, normalmente bases/BF) no centro; demais categorias
  # em setores angulares ao redor, como no layout do mapa real.
  defp cluster_centers([hub | others]) do
    count = max(length(others), 1)

    outer =
      others
      |> Enum.with_index()
      |> Enum.map(fn {cat, index} ->
        theta = (-90 + index * 360 / count) * :math.pi() / 180
        {cat, {100.0 + 58 * :math.cos(theta), 64.0 + 36 * :math.sin(theta)}}
      end)

    Map.new([{hub, {100.0, 64.0}} | outer])
  end

  defp scatter_cluster(members, {cx, cy}) do
    members
    |> Enum.with_index()
    |> Enum.map(fn {sequence_step, k} ->
      {dx, dy} = phyllotaxis_offset(k)

      %{
        code: sequence_step.step.code,
        x: Float.round(cx + dx, 1),
        y: Float.round(cy + dy, 1),
        color: step_category_color(sequence_step),
        cat: step_category_key(sequence_step)
      }
    end)
  end

  # Dispersão por filotaxia (ângulo áureo): determinística, espalha os nós de
  # uma mesma categoria num cluster compacto sem aleatoriedade.
  defp phyllotaxis_offset(0), do: {0.0, 0.0}

  defp phyllotaxis_offset(k) do
    angle = k * 2.399963
    radius = 8.5 * :math.sqrt(k)
    {radius * :math.cos(angle), radius * :math.sin(angle)}
  end

  defp sequence_path_edges(codes, positions) do
    codes
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.flat_map(fn [from_code, to_code] ->
      from = Map.get(positions, from_code)
      to = Map.get(positions, to_code)

      if from && to && from_code != to_code do
        [%{x1: from.x, y1: from.y, x2: to.x, y2: to.y, color: from.color}]
      else
        []
      end
    end)
    |> Enum.uniq()
  end

  defp cluster_zones(nodes) do
    nodes
    |> Enum.group_by(& &1.cat)
    |> Enum.reject(fn {_cat, members} -> length(members) < 2 end)
    |> Enum.map(fn {_cat, members} ->
      xs = Enum.map(members, & &1.x)
      ys = Enum.map(members, & &1.y)

      %{
        cx: Float.round((Enum.min(xs) + Enum.max(xs)) / 2, 1),
        cy: Float.round((Enum.min(ys) + Enum.max(ys)) / 2, 1),
        rx: Float.round((Enum.max(xs) - Enum.min(xs)) / 2 + 12, 1),
        ry: Float.round((Enum.max(ys) - Enum.min(ys)) / 2 + 12, 1),
        color: hd(members).color
      }
    end)
  end

  defp edge_markers(edges) do
    edges
    |> Enum.map(& &1.color)
    |> Enum.uniq()
    |> Enum.with_index()
    |> Enum.map(fn {color, index} -> %{color: color, suffix: "c#{index}"} end)
  end

  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :cta, :string, required: true

  defp sequence_empty(assigns) do
    ~H"""
    <div class="rounded-2xl border border-dashed border-gold-500/30 bg-gold-500/[0.04] px-5 py-10 text-center">
      <.icon name="hero-map" class="mx-auto mb-3 size-7 text-ink-300" />
      <p class="m-0 font-serif text-base font-bold text-ink-800">{@title}</p>
      <p class="mx-auto mt-1.5 max-w-md text-sm leading-relaxed text-ink-500">{@description}</p>
      <.link
        navigate={~p"/graph/visual?mode=generator"}
        class="mt-4 inline-flex items-center gap-1.5 rounded-full bg-accent-orange px-5 py-2 text-sm font-semibold text-white no-underline transition hover:bg-accent-orange/90"
      >
        <.icon name="hero-sparkles" class="size-4" /> {@cta}
      </.link>
    </div>
    """
  end

  attr :seq, :map, required: true
  attr :current_user, :map, required: true
  attr :following_user_ids, :any, required: true
  attr :sequence_likes, :map, required: true
  attr :seq_favorites, :any, required: true
  attr :seq_comment_counts, :map, required: true
  attr :expanded_seq, :any, required: true
  attr :expanded_seq_comments, :list, required: true
  attr :expanded_seq_comment_likes, :map, required: true
  attr :expanded_seq_replies_map, :map, required: true
  attr :expanded_seq_replying_to, :any, required: true
  attr :following_enabled, :boolean, default: true
  attr :is_admin, :boolean, required: true
  attr :deep_linked_sequence_id, :any, default: nil

  defp sequence_card(assigns) do
    seq = assigns.seq
    current_user = assigns.current_user
    is_expanded = assigns.expanded_seq == seq.id

    assigns =
      assign(assigns,
        author: sequence_author(seq, current_user),
        author_username: sequence_author_username(seq, current_user),
        step_codes: sequence_step_codes(seq),
        glyph_colors: sequence_glyph_colors(seq),
        accent_color: sequence_accent_color(seq),
        categories: sequence_categories_with_color(seq),
        map: if(is_expanded, do: sequence_map_nodes(seq), else: nil),
        step_count: length(seq.sequence_steps),
        like_count: Map.get(assigns.sequence_likes.counts, seq.id, 0),
        comment_count: Map.get(assigns.seq_comment_counts, seq.id, 0),
        liked: MapSet.member?(assigns.sequence_likes.liked_ids, seq.id),
        is_favorited: MapSet.member?(assigns.seq_favorites, seq.id),
        is_expanded: is_expanded,
        is_deep_linked: assigns.deep_linked_sequence_id == seq.id,
        editable: assigns.is_admin or seq.user_id == current_user.id
      )

    ~H"""
    <article
      id={"sequence-card-#{@seq.id}"}
      data-deep-linked={to_string(@is_deep_linked)}
      style={"border-left-color: #{@accent_color}"}
      class={[
        "group overflow-hidden rounded-2xl border border-l-[3px] border-ink-200 bg-ink-50 shadow-sm transition duration-200",
        @is_deep_linked && "ring-2 ring-accent-orange/40 ring-offset-2 ring-offset-ink-100",
        @is_expanded && "shadow-md",
        !@is_expanded && "hover:-translate-y-0.5 hover:shadow-md"
      ]}
    >
      <%!-- Linha recolhida: glyph + nome + cadeia de códigos + meta --%>
      <div class="flex flex-wrap items-center gap-x-3 gap-y-2 px-4 py-3.5 sm:flex-nowrap">
        <button
          id={"sequence-details-toggle-#{@seq.id}"}
          type="button"
          phx-click="toggle_seq_expand"
          phx-value-seq-id={@seq.id}
          aria-expanded={to_string(@is_expanded)}
          class="flex min-w-0 flex-1 items-center gap-3 text-left cursor-pointer"
        >
          <span class="grid shrink-0 grid-cols-2 gap-0.5" aria-hidden="true">
            <span
              :for={color <- @glyph_colors}
              class="size-[7px] rounded-full"
              style={"background-color: #{color}"}
            />
          </span>
          <span class="flex min-w-0 flex-col gap-0.5 sm:flex-row sm:items-baseline sm:gap-2.5">
            <span class="truncate font-serif text-base font-bold leading-tight text-ink-900">
              {@seq.name}
            </span>
            <span
              :if={@step_codes != []}
              class="flex flex-wrap items-center gap-x-1 font-mono text-[11px] leading-tight text-ink-400"
            >
              <%= for {code, index} <- Enum.with_index(Enum.take(@step_codes, 12)) do %>
                <span :if={index > 0} class="text-ink-300">→</span>
                <span class={index == 0 && "text-ink-500"}>{code}</span>
              <% end %>
              <span :if={length(@step_codes) > 12} class="text-ink-300">…</span>
            </span>
          </span>
        </button>

        <div class="flex shrink-0 items-center gap-2">
          <span
            :if={@seq.video_url}
            class="inline-flex items-center gap-1 rounded-full bg-gold-500/12 px-2 py-1 text-[10px] font-semibold text-gold-600"
            title="Sequência com vídeo"
          >
            <.icon name="hero-play-circle" class="size-3" /> vídeo
          </span>

          <span class="inline-flex items-center gap-1 rounded-full bg-ink-100 px-2.5 py-1 text-[11px] font-semibold text-ink-500">
            {@step_count} {if @step_count == 1, do: "passo", else: "passos"}
          </span>

          <button
            phx-click="toggle_like"
            phx-value-type="sequence"
            phx-value-id={@seq.id}
            aria-pressed={to_string(@liked)}
            aria-label={if @liked, do: "Remover curtida", else: "Curtir sequência"}
            class={[
              "inline-flex items-center gap-1 rounded-full px-2 py-1 text-[12px] transition cursor-pointer",
              @liked && "text-accent-red",
              !@liked && "text-ink-400 hover:text-accent-red"
            ]}
            title={if @liked, do: "Remover curtida", else: "Curtir"}
          >
            <.icon name={if @liked, do: "hero-heart-solid", else: "hero-heart"} class="size-4" />
            <span class="tabular-nums">{@like_count}</span>
          </button>

          <.link
            id={"sequence-author-#{@seq.id}"}
            navigate={~p"/users/#{@author_username}"}
            class="shrink-0 no-underline"
            title={"@#{@author_username}"}
          >
            <.user_avatar user={@author} size={:sm} />
          </.link>

          <button
            type="button"
            phx-click="toggle_seq_expand"
            phx-value-seq-id={@seq.id}
            aria-label={if @is_expanded, do: "Recolher sequência", else: "Expandir sequência"}
            class="inline-flex size-7 items-center justify-center rounded-full text-ink-400 transition hover:bg-ink-100 hover:text-ink-700 cursor-pointer"
          >
            <.icon
              name="hero-chevron-down-mini"
              class={["size-4 transition-transform", @is_expanded && "rotate-180"]}
            />
          </button>
        </div>
      </div>

      <%!-- Estado expandido: prévia no mapa | passos + ações --%>
      <section
        :if={@is_expanded}
        id={"sequence-expanded-#{@seq.id}"}
        class="border-t border-ink-200 bg-ink-100/50 px-4 py-4 sm:px-5"
      >
        <div class="grid gap-5 lg:grid-cols-[minmax(0,18rem)_1fr]">
          <%!-- Coluna do mapa --%>
          <div class="flex flex-col gap-2">
            <p class="text-[11px] font-bold uppercase tracking-[0.18em] text-ink-400">
              Prévia no mapa
            </p>
            <div class="relative overflow-hidden rounded-xl border border-ink-200 bg-ink-50 p-3">
              <svg
                viewBox="0 0 200 128"
                class="h-auto w-full"
                role="img"
                aria-label="Prévia da trilha no mapa"
              >
                <defs>
                  <marker
                    :for={marker <- @map.markers}
                    id={"seq-arrow-#{@seq.id}-#{marker.suffix}"}
                    markerWidth="7"
                    markerHeight="7"
                    refX="5.5"
                    refY="3"
                    orient="auto"
                  >
                    <path d="M0,0 L6,3 L0,6 Z" fill={marker.color} opacity="0.75" />
                  </marker>
                </defs>
                <ellipse
                  :for={zone <- @map.zones}
                  cx={zone.cx}
                  cy={zone.cy}
                  rx={zone.rx}
                  ry={zone.ry}
                  fill={zone.color}
                  opacity="0.1"
                />
                <line
                  :for={edge <- @map.edges}
                  x1={edge.x1}
                  y1={edge.y1}
                  x2={edge.x2}
                  y2={edge.y2}
                  stroke={edge.color}
                  stroke-width="1.4"
                  opacity="0.55"
                  marker-end={"url(#seq-arrow-#{@seq.id}-#{edge.marker})"}
                />
                <circle
                  :for={node <- @map.nodes}
                  cx={node.x}
                  cy={node.y}
                  r={if node.hub, do: "7.5", else: "6"}
                  fill={if node.hub, do: "#fff7ea", else: "#fffef9"}
                  stroke={node.color}
                  stroke-width={if node.hub, do: "2.6", else: "2"}
                />
              </svg>
              <.link
                id={"sequence-map-link-#{@seq.id}"}
                navigate={~p"/graph/visual?seq=#{@seq.id}"}
                class="absolute bottom-3 right-3 inline-flex items-center gap-1.5 rounded-full bg-ink-900 px-3 py-1.5 text-xs font-semibold text-ink-50 no-underline shadow-md transition hover:bg-ink-800"
              >
                <.icon name="hero-map" class="size-3.5" /> Ver no mapa
              </.link>
            </div>
          </div>

          <%!-- Coluna dos passos --%>
          <div class="flex flex-col gap-3">
            <div class="flex items-center justify-between gap-2">
              <p class="text-[11px] font-bold uppercase tracking-[0.18em] text-ink-400">
                Passos · {@step_count} {if @step_count == 1, do: "passo", else: "passos"}
              </p>
              <div class="flex items-center gap-2">
                <.link
                  navigate={~p"/users/#{@author_username}"}
                  class="inline-flex items-center gap-1.5 text-[11px] font-semibold text-ink-500 no-underline transition hover:text-accent-orange"
                >
                  <.user_avatar user={@author} size={:sm} /> @{@author_username}
                </.link>
                <button
                  :if={@following_enabled && @seq.user_id && @seq.user_id != @current_user.id}
                  phx-click="toggle_follow"
                  phx-value-user-id={@seq.user_id}
                  class={[
                    "inline-flex items-center rounded-full border px-2.5 py-1 text-[11px] font-semibold transition cursor-pointer",
                    MapSet.member?(@following_user_ids, @seq.user_id) &&
                      "border-accent-orange/40 bg-accent-orange/10 text-accent-orange",
                    !MapSet.member?(@following_user_ids, @seq.user_id) &&
                      "border-ink-300 text-ink-500 hover:border-accent-orange hover:text-accent-orange"
                  ]}
                >
                  {if MapSet.member?(@following_user_ids, @seq.user_id),
                    do: "Seguindo",
                    else: "Seguir"}
                </button>
              </div>
            </div>

            <%= if @seq.sequence_steps == [] do %>
              <p class="text-sm italic text-ink-400">Nenhum passo cadastrado ainda.</p>
            <% else %>
              <ol class="grid grid-cols-1 gap-1.5 sm:grid-cols-2">
                <li
                  :for={
                    {sequence_step, index} <-
                      Enum.with_index(Enum.take(@seq.sequence_steps, 12), 1)
                  }
                  class="flex items-center gap-2 rounded-lg border border-ink-200 bg-ink-50 px-2.5 py-1.5"
                >
                  <span
                    class="flex size-5 shrink-0 items-center justify-center rounded-full text-[10px] font-bold text-white"
                    style={"background-color: #{step_category_color(sequence_step)}"}
                  >
                    {index}
                  </span>
                  <span class="min-w-0 flex-1 truncate text-[13px] text-ink-800">
                    {sequence_step.step.name}
                  </span>
                  <code class="shrink-0 rounded bg-ink-100 px-1.5 py-0.5 font-mono text-[10px] font-semibold text-ink-500">
                    {sequence_step.step.code}
                  </code>
                </li>
              </ol>
              <.link
                :if={@step_count > 12}
                navigate={~p"/graph/visual?seq=#{@seq.id}"}
                class="inline-flex items-center gap-1 text-xs font-semibold text-accent-orange no-underline hover:underline"
              >
                Ver todos os {@step_count} passos <.icon name="hero-arrow-right" class="size-3" />
              </.link>
            <% end %>

            <%!-- Ações --%>
            <div class="flex flex-wrap items-center gap-2 border-t border-ink-200 pt-3">
              <button
                phx-click="toggle_seq_favorite"
                phx-value-id={@seq.id}
                aria-pressed={to_string(@is_favorited)}
                class={[
                  "inline-flex items-center gap-1.5 rounded-full border px-3 py-1.5 text-[13px] font-semibold transition cursor-pointer",
                  @is_favorited && "border-gold-500/40 bg-gold-500/10 text-gold-600",
                  !@is_favorited &&
                    "border-ink-300 bg-ink-50 text-ink-600 hover:border-gold-500/40 hover:text-gold-600"
                ]}
              >
                <.icon
                  name={if @is_favorited, do: "hero-star-solid", else: "hero-star"}
                  class="size-4"
                />
                {if @is_favorited, do: "Favorita", else: "Favoritar"}
              </button>

              <.link
                :if={@editable}
                navigate={~p"/graph/visual?seq=#{@seq.id}"}
                class="inline-flex items-center gap-1.5 rounded-full border border-ink-300 bg-ink-50 px-3 py-1.5 text-[13px] font-semibold text-ink-600 no-underline transition hover:border-accent-orange hover:text-accent-orange"
              >
                <.icon name="hero-pencil-square" class="size-4" /> Editar
              </.link>

              <button
                id={"sequence-share-#{@seq.id}"}
                phx-click="copy_sequence_link"
                phx-value-seq-id={@seq.id}
                class="inline-flex items-center gap-1.5 rounded-full border border-ink-300 bg-ink-50 px-3 py-1.5 text-[13px] font-semibold text-ink-600 transition hover:border-accent-orange hover:text-accent-orange cursor-pointer"
              >
                <.icon name="hero-link" class="size-4" /> Copiar link
              </button>

              <span class="ml-auto inline-flex items-center gap-1.5 text-[13px] text-ink-500">
                <.icon name="hero-chat-bubble-oval-left" class="size-4 text-ink-400" />
                {@comment_count} {if @comment_count == 1, do: "comentário", else: "comentários"}
              </span>
            </div>

            <%!-- Tags de categoria --%>
            <div :if={@categories != []} class="flex flex-wrap gap-1.5">
              <span
                :for={category <- @categories}
                class="inline-flex items-center rounded-full border px-2.5 py-1 text-[11px] font-semibold"
                style={"color: #{category.color}; border-color: #{category.color}33; background-color: #{category.color}0f"}
              >
                {category.label}
              </span>
            </div>
          </div>
        </div>

        <%!-- Vídeo --%>
        <div
          :if={@seq.video_url}
          id={"sequence-embed-#{@seq.id}"}
          class="mt-4 rounded-xl border border-ink-200 bg-ink-50 p-3"
        >
          <% embed = youtube_embed_url(@seq.video_url) %>
          <%= if embed != :external do %>
            <% {:embed, embed_url} = embed %>
            <details>
              <summary class="cursor-pointer select-none text-sm font-semibold text-accent-orange">
                Ver vídeo da sequência
              </summary>
              <div class="relative mt-3 h-0 overflow-hidden rounded-lg pb-[56.25%]">
                <iframe
                  src={embed_url}
                  style="position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: none; border-radius: 8px;"
                  allowfullscreen
                  loading="lazy"
                >
                </iframe>
              </div>
            </details>
          <% else %>
            <a
              href={@seq.video_url}
              target="_blank"
              rel="noreferrer"
              class="inline-flex items-center gap-1.5 text-sm font-semibold text-accent-orange no-underline"
            >
              <.icon name="hero-play-circle" class="size-4" /> Ver vídeo externo
            </a>
          <% end %>
        </div>

        <%!-- Comentários --%>
        <div id={"sequence-comments-#{@seq.id}"} class="mt-4 border-t border-ink-200 pt-4">
          <h4 class="mb-3 text-[11px] font-bold uppercase tracking-[0.18em] text-ink-400">
            Conversa
          </h4>
          <.comment_thread
            comments={@expanded_seq_comments}
            current_user={@current_user}
            likes_map={@expanded_seq_comment_likes}
            comment_type="sequence_comment"
            parent_id={@seq.id}
            replying_to={@expanded_seq_replying_to}
            replies_map={@expanded_seq_replies_map}
            is_admin={@is_admin}
          />
        </div>
      </section>
    </article>
    """
  end
end
