defmodule OGrupoDeEstudosWeb.CommunityLive do
  @moduledoc """
  Sequences page — shows all public sequences sorted by like count,
  with inline comment expansion (lazy-loaded) and YouTube embeds.

  Accessible to all authenticated users.
  """

  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.{Accounts, Engagement, Sequences}
  alias OGrupoDeEstudos.Engagement.Comments.SequenceCommentQuery
  alias OGrupoDeEstudosWeb.Helpers.RateLimit

  on_mount {OGrupoDeEstudosWeb.UserAuth, :ensure_authenticated}
  on_mount {OGrupoDeEstudosWeb.Navigation, :primary}
  on_mount {OGrupoDeEstudosWeb.Hooks.NotificationSubscriber, :default}

  import OGrupoDeEstudosWeb.UI.TopNav
  import OGrupoDeEstudosWeb.UI.BottomNav
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

    community_sequences = filter_sequences(community_sequences_all, "")
    my_sequences = []

    {:ok,
     socket
     |> assign(
       page_title: "Sequências",
       is_admin: admin,
       community_sequences_all: community_sequences_all,
       community_sequences: community_sequences,
       discovery_sections: build_discovery_sections(community_sequences_all),
       seq_search: "",
       seq_sort: "popular",
       active_seq_tab: "community",
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
  def handle_event("search_sequences", params, socket) do
    term = params["value"] || params["term"] || ""
    community_sequences = filter_sequences(socket.assigns.community_sequences_all, term)

    {:noreply, assign(socket, seq_search: term, community_sequences: community_sequences)}
  end

  def handle_event("sort_sequences", %{"sort" => sort}, socket) do
    current_user = socket.assigns.current_user

    community_sequences_all =
      current_user.id |> list_community_sequences() |> sort_sequences(sort)

    community_sequences = filter_sequences(community_sequences_all, socket.assigns.seq_search)

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
          |> assign(active_seq_tab: "mine", my_sequences: my_sequences)
          |> assign_sequence_social_metadata(
            current_user.id,
            socket.assigns.community_sequences_all,
            my_sequences
          )

        _ ->
          socket
          |> assign(active_seq_tab: "community")
          |> assign_sequence_social_metadata(
            current_user.id,
            socket.assigns.community_sequences_all,
            socket.assigns.my_sequences
          )
      end

    {:noreply, socket}
  end

  def handle_event("toggle_like", %{"type" => "sequence", "id" => id}, socket) do
    current_user = socket.assigns.current_user

    case Engagement.toggle_like(current_user.id, "sequence", id) do
      {:ok, _action} ->
        community_sequences_all =
          current_user.id
          |> list_community_sequences()
          |> sort_sequences(socket.assigns.seq_sort)

        community_sequences = filter_sequences(community_sequences_all, socket.assigns.seq_search)
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

  defp filter_sequences(sequences, ""), do: sequences

  defp filter_sequences(sequences, term) do
    lower = String.downcase(term)

    Enum.filter(sequences, fn seq ->
      String.contains?(String.downcase(seq.name), lower)
    end)
  end

  defp build_discovery_sections(sequences) do
    sequences
    |> Enum.flat_map(fn seq ->
      seq.sequence_steps
      |> Enum.map(fn sequence_step ->
        category = sequence_step.step.category

        if category do
          {category.id, category.label}
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
    end)
    |> Enum.frequencies()
    |> Enum.map(fn {{id, title}, sequence_count} ->
      %{id: id, title: title, sequence_count: sequence_count}
    end)
    |> Enum.sort_by(fn section -> {-section.sequence_count, section.title} end)
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

  defp sequence_author_initial(seq, current_user) do
    seq
    |> sequence_author_username(current_user)
    |> String.slice(0, 1)
    |> String.upcase()
  end

  defp sequence_category_labels(seq) do
    seq.sequence_steps
    |> Enum.map(fn sequence_step ->
      sequence_step.step.category && sequence_step.step.category.label
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp sequence_preview_text(seq) do
    categories = sequence_category_labels(seq)

    cond do
      categories != [] ->
        categories
        |> Enum.take(3)
        |> Enum.join(" · ")

      seq.sequence_steps != [] ->
        seq.sequence_steps
        |> Enum.map(& &1.step.name)
        |> Enum.take(2)
        |> Enum.join(" · ")

      true ->
        "Pronta para explorar no mapa"
    end
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

  defp sequence_card(assigns) do
    seq = assigns.seq
    current_user = assigns.current_user
    author = sequence_author(seq, current_user)
    author_username = sequence_author_username(seq, current_user)

    assigns =
      assign(assigns,
        author: author,
        author_username: author_username,
        author_initial: sequence_author_initial(seq, current_user),
        category_labels: sequence_category_labels(seq),
        preview_text: sequence_preview_text(seq),
        step_count: length(seq.sequence_steps),
        like_count: Map.get(assigns.sequence_likes.counts, seq.id, 0),
        comment_count: Map.get(assigns.seq_comment_counts, seq.id, 0),
        liked: MapSet.member?(assigns.sequence_likes.liked_ids, seq.id),
        is_favorited: MapSet.member?(assigns.seq_favorites, seq.id),
        is_expanded: assigns.expanded_seq == seq.id
      )

    ~H"""
    <article
      id={"sequence-card-#{@seq.id}"}
      class={[
        "group overflow-hidden rounded-lg border bg-white/90 shadow-sm transition duration-200 hover:-translate-y-0.5 hover:shadow-lg",
        @is_expanded && "border-accent-orange/45 shadow-md",
        !@is_expanded && "border-ink-300/50"
      ]}
    >
      <div class="h-1 w-full bg-gradient-to-r from-accent-orange via-gold-500 to-accent-green" />
      <div class="flex flex-col gap-5 px-4 py-4 sm:px-5 sm:py-5">
        <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
          <div class="min-w-0 flex-1">
            <div class="mb-3 flex flex-wrap items-center gap-2">
              <span class="inline-flex items-center rounded-full bg-accent-orange/10 px-2.5 py-1 text-[11px] font-semibold uppercase text-accent-orange">
                Sequência pública
              </span>
              <span
                :if={@seq.video_url}
                class="inline-flex items-center rounded-full bg-gold-500/12 px-2.5 py-1 text-[11px] font-semibold text-gold-700"
              >
                Com vídeo
              </span>
            </div>

            <h3 class="max-w-2xl text-2xl font-semibold leading-tight text-ink-900">
              {@seq.name}
            </h3>
            <p class="mt-2 max-w-2xl text-sm leading-6 text-ink-600">
              {@preview_text}
            </p>

            <div class="mt-4 flex flex-wrap items-center gap-2 text-xs text-ink-500">
              <span class="inline-flex items-center gap-1 rounded-full bg-ink-100 px-2.5 py-1 font-medium">
                <.icon name="hero-queue-list" class="size-3.5 text-ink-500" /> {@step_count} passo(s)
              </span>
              <span
                :if={@like_count > 0}
                class="inline-flex items-center gap-1 rounded-full bg-accent-red/8 px-2.5 py-1 font-medium text-accent-red"
              >
                <.icon name="hero-heart-solid" class="size-3.5" /> {@like_count}
              </span>
              <span class="inline-flex items-center gap-1 rounded-full bg-ink-100 px-2.5 py-1 font-medium">
                <.icon name="hero-chat-bubble-left" class="size-3.5 text-ink-500" /> {@comment_count}
              </span>
            </div>
          </div>

          <div class="flex flex-col gap-2 sm:items-end">
            <.link
              id={"sequence-map-link-#{@seq.id}"}
              navigate={~p"/graph/visual?seq=#{@seq.id}"}
              class="inline-flex min-h-11 items-center justify-center gap-2 rounded-md bg-accent-orange px-4 py-3 text-sm font-semibold text-white no-underline shadow-sm transition hover:bg-accent-orange/90"
            >
              <.icon name="hero-map" class="size-4" /> Ver no mapa
            </.link>

            <div class="flex flex-wrap items-center gap-2 sm:justify-end">
              <button
                phx-click="toggle_like"
                phx-value-type="sequence"
                phx-value-id={@seq.id}
                aria-label={
                  if @liked,
                    do: "Remover curtida desta sequência",
                    else: "Curtir esta sequência"
                }
                aria-pressed={to_string(@liked)}
                class={[
                  "inline-flex min-h-10 items-center gap-2 rounded-md border px-3 py-2 text-sm transition cursor-pointer",
                  @liked && "border-accent-red/30 bg-accent-red/8 text-accent-red",
                  !@liked &&
                    "border-ink-300/60 bg-white text-ink-500 hover:border-accent-red/30 hover:text-accent-red"
                ]}
                title={if @liked, do: "Remover like", else: "Curtir"}
              >
                <.icon name={if @liked, do: "hero-heart-solid", else: "hero-heart"} class="size-4" />
                <span class="tabular-nums">{@like_count}</span>
              </button>

              <button
                phx-click="toggle_seq_favorite"
                phx-value-id={@seq.id}
                aria-label={
                  if @is_favorited,
                    do: "Remover sequência dos salvos",
                    else: "Salvar sequência"
                }
                aria-pressed={to_string(@is_favorited)}
                class={[
                  "inline-flex min-h-10 items-center gap-2 rounded-md border px-3 py-2 text-sm transition cursor-pointer",
                  @is_favorited && "border-gold-500/40 bg-gold-500/8 text-gold-700",
                  !@is_favorited &&
                    "border-ink-300/60 bg-white text-ink-500 hover:border-gold-500/40 hover:text-gold-700"
                ]}
                title={if @is_favorited, do: "Remover favorito", else: "Favoritar"}
              >
                <.icon
                  name={if @is_favorited, do: "hero-star-solid", else: "hero-star"}
                  class="size-4"
                />
                <span>{if @is_favorited, do: "Salva", else: "Salvar"}</span>
              </button>
            </div>
          </div>
        </div>

        <div class="flex flex-wrap gap-2">
          <span
            :for={label <- Enum.take(@category_labels, 3)}
            class="inline-flex items-center rounded-full border border-accent-orange/20 bg-accent-orange/6 px-2.5 py-1 text-[11px] font-semibold text-ink-600"
          >
            {label}
          </span>
          <code
            :for={sequence_step <- Enum.take(@seq.sequence_steps, 5)}
            class="rounded-sm border border-gold-500/20 bg-gold-500/10 px-2 py-1 font-mono text-[11px] font-semibold text-ink-700"
          >
            {sequence_step.step.code}
          </code>
        </div>

        <div class="flex flex-col gap-3 border-t border-ink-200/70 pt-4 sm:flex-row sm:items-center sm:justify-between">
          <div class="flex flex-wrap items-center gap-3">
            <.link
              id={"sequence-author-#{@seq.id}"}
              navigate={~p"/users/#{@author_username}"}
              class="inline-flex items-center gap-2 text-sm font-medium text-ink-700 no-underline transition hover:text-accent-orange"
            >
              <span class="inline-flex size-8 items-center justify-center rounded-full bg-accent-orange text-xs font-semibold text-white">
                {@author_initial}
              </span>
              <span>@{@author_username}</span>
            </.link>

            <button
              :if={@following_enabled && @seq.user_id && @seq.user_id != @current_user.id}
              phx-click="toggle_follow"
              phx-value-user-id={@seq.user_id}
              class={[
                "inline-flex min-h-9 items-center rounded-full border px-3 py-1.5 text-xs font-semibold transition cursor-pointer",
                MapSet.member?(@following_user_ids, @seq.user_id) &&
                  "border-accent-orange bg-accent-orange/10 text-accent-orange",
                !MapSet.member?(@following_user_ids, @seq.user_id) &&
                  "border-ink-300/70 text-ink-500 hover:border-accent-orange hover:text-accent-orange"
              ]}
            >
              {if MapSet.member?(@following_user_ids, @seq.user_id), do: "Seguindo", else: "Seguir"}
            </button>
          </div>

          <button
            id={"sequence-details-toggle-#{@seq.id}"}
            phx-click="toggle_seq_expand"
            phx-value-seq-id={@seq.id}
            class={[
              "inline-flex min-h-10 items-center justify-center gap-2 rounded-md border px-3 py-2 text-sm transition cursor-pointer",
              @is_expanded &&
                "border-accent-orange/30 bg-accent-orange/10 text-accent-orange",
              !@is_expanded &&
                "border-ink-300/60 bg-white text-ink-500 hover:border-ink-500/60 hover:text-ink-700"
            ]}
            title={if @is_expanded, do: "Fechar", else: "Ver comentários e vídeo"}
          >
            <.icon
              name={if @is_expanded, do: "hero-chevron-up-mini", else: "hero-chevron-down-mini"}
              class="size-4"
            />
            <span>
              {if @is_expanded,
                do: "Fechar detalhes",
                else:
                  if(@comment_count > 0,
                    do: "#{@comment_count} comentário(s)",
                    else: "Abrir detalhes"
                  )}
            </span>
          </button>
        </div>
      </div>

      <section
        :if={@is_expanded}
        id={"sequence-expanded-#{@seq.id}"}
        class="border-t border-ink-200/80 bg-ink-50/70 px-4 py-4 sm:px-5"
      >
        <div class="flex flex-col gap-4">
          <div
            :if={@seq.video_url}
            id={"sequence-embed-#{@seq.id}"}
            class="rounded-md border border-ink-200/70 bg-white/80 p-3"
          >
            <% embed = youtube_embed_url(@seq.video_url) %>
            <%= if embed != :external do %>
              <% {:embed, embed_url} = embed %>
              <details>
                <summary class="cursor-pointer text-sm font-medium text-accent-orange select-none">
                  Ver vídeo
                </summary>
                <div class="relative mt-3 h-0 overflow-hidden rounded-md pb-[56.25%]">
                  <iframe
                    src={embed_url}
                    style="position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: none; border-radius: 6px;"
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
                class="text-sm font-medium text-accent-orange no-underline"
              >
                Ver vídeo externo
              </a>
            <% end %>
          </div>

          <div id={"sequence-comments-#{@seq.id}"}>
            <h4 class="mb-3 text-xs font-semibold uppercase tracking-wide text-ink-500">
              Comentários
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
        </div>
      </section>
    </article>
    """
  end
end
