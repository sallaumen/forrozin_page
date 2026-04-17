defmodule OGrupoDeEstudosWeb.UserProfileLive do
  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.{Accounts, Encyclopedia, Engagement, Sequences}
  alias OGrupoDeEstudos.Engagement.{Badges, ProfileCommentQuery}

  on_mount {OGrupoDeEstudosWeb.UserAuth, :ensure_authenticated}
  on_mount {OGrupoDeEstudosWeb.Hooks.NotificationSubscriber, :default}

  import OGrupoDeEstudosWeb.UI.TopNav
  import OGrupoDeEstudosWeb.UI.BottomNav
  import OGrupoDeEstudosWeb.CoreComponents, only: [icon: 1]

  use OGrupoDeEstudosWeb.NotificationHandlers

  @impl true
  def mount(%{"username" => username}, _session, socket) do
    case Accounts.get_user_by_username(username) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Usuário não encontrado.")
         |> redirect(to: ~p"/collection")}

      user ->
        current_user = socket.assigns.current_user

        steps = Encyclopedia.list_user_steps(user.id)
        sequences = Sequences.list_public_user_sequences(user.id)

        step_ids = Enum.map(steps, & &1.id)
        sequence_ids = Enum.map(sequences, & &1.id)

        step_likes = Engagement.likes_map(current_user.id, "step", step_ids)
        sequence_likes = Engagement.likes_map(current_user.id, "sequence", sequence_ids)

        comments =
          ProfileCommentQuery.list_by(
            profile_id: user.id,
            preload: [:author]
          )

        comment_ids = Enum.map(comments, & &1.id)
        comment_likes = Engagement.likes_map(current_user.id, "profile_comment", comment_ids)

        is_own_profile = current_user.id == user.id

        # Stats
        total_likes = Engagement.total_likes_received(user.id)
        total_favorites = Engagement.count_user_favorites(user.id)
        total_sequences = length(sequences)

        # Badges
        badges = Badges.compute(user.id)
        primary_badge = Enum.find(badges, & &1.earned)

        {:ok,
         assign(socket,
           page_title: user.name || user.username,
           profile_user: user,
           user_steps: steps,
           user_sequences: sequences,
           step_likes: step_likes,
           sequence_likes: sequence_likes,
           is_own_profile: is_own_profile,
           is_admin: Accounts.admin?(current_user),
           nav_mode: if(is_own_profile, do: :primary, else: :detail),
           comments: comments,
           comment_likes: comment_likes,
           comment_body: "",
           total_likes: total_likes,
           total_favorites: total_favorites,
           total_sequences: total_sequences,
           badges: badges,
           primary_badge: primary_badge,
           profile_tab: "steps",
           favorite_steps: [],
           favorite_sequences: [],
           favorite_sub_tab: "steps"
         )}
    end
  end

  @impl true
  def handle_event("toggle_like", %{"type" => type, "id" => id}, socket) do
    current_user = socket.assigns.current_user

    case Engagement.toggle_like(current_user.id, type, id) do
      {:ok, _action} ->
        socket = reload_all_likes(socket, current_user)
        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Não foi possível registrar o like.")}
    end
  end

  @impl true
  def handle_event("update_comment_body", %{"body" => body}, socket) do
    {:noreply, assign(socket, comment_body: body)}
  end

  @impl true
  def handle_event("post_comment", %{"body" => body}, socket) do
    current_user = socket.assigns.current_user
    profile_user = socket.assigns.profile_user

    attrs = %{
      body: body,
      author_id: current_user.id,
      profile_id: profile_user.id
    }

    case Engagement.create_profile_comment(attrs) do
      {:ok, _comment} ->
        socket = reload_comments(socket, current_user)
        {:noreply, assign(socket, comment_body: "")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Não foi possível postar o comentário.")}
    end
  end

  @impl true
  def handle_event("delete_comment", %{"id" => comment_id}, socket) do
    current_user = socket.assigns.current_user
    comment = Enum.find(socket.assigns.comments, &(&1.id == comment_id))

    can_delete =
      comment &&
        (current_user.id == comment.author_id || Accounts.admin?(current_user))

    if can_delete do
      case Engagement.delete_profile_comment(comment) do
        {:ok, _} ->
          socket = reload_comments(socket, current_user)
          {:noreply, socket}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Não foi possível remover o comentário.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Sem permissão para remover este comentário.")}
    end
  end

  @impl true
  def handle_event("switch_profile_tab", %{"tab" => "favorites"}, socket) do
    profile_user = socket.assigns.profile_user
    fav_steps = Engagement.list_user_favorites(profile_user.id, "step")
    fav_sequences = Engagement.list_user_favorites(profile_user.id, "sequence")

    {:noreply,
     assign(socket,
       profile_tab: "favorites",
       favorite_steps: fav_steps,
       favorite_sequences: fav_sequences
     )}
  end

  @impl true
  def handle_event("switch_profile_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, profile_tab: tab)}
  end

  @impl true
  def handle_event("switch_favorite_sub_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, favorite_sub_tab: tab)}
  end

  # --- helpers ---

  defp reload_comments(socket, current_user) do
    profile_user = socket.assigns.profile_user

    comments =
      ProfileCommentQuery.list_by(
        profile_id: profile_user.id,
        preload: [:author]
      )

    comment_ids = Enum.map(comments, & &1.id)
    comment_likes = Engagement.likes_map(current_user.id, "profile_comment", comment_ids)

    assign(socket, comments: comments, comment_likes: comment_likes)
  end

  defp reload_all_likes(socket, current_user) do
    steps = socket.assigns.user_steps
    sequences = socket.assigns.user_sequences
    comments = socket.assigns.comments

    step_ids = Enum.map(steps, & &1.id)
    sequence_ids = Enum.map(sequences, & &1.id)
    comment_ids = Enum.map(comments, & &1.id)

    assign(socket,
      step_likes: Engagement.likes_map(current_user.id, "step", step_ids),
      sequence_likes: Engagement.likes_map(current_user.id, "sequence", sequence_ids),
      comment_likes: Engagement.likes_map(current_user.id, "profile_comment", comment_ids)
    )
  end
end
