defmodule OGrupoDeEstudosWeb.UserProfileLive do
  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.{Accounts, Encyclopedia, Engagement, Sequences, Study, Suggestions}
  alias OGrupoDeEstudos.Engagement.{Badges, ProfileCommentQuery}

  on_mount {OGrupoDeEstudosWeb.UserAuth, :ensure_authenticated}
  on_mount {OGrupoDeEstudosWeb.Hooks.NotificationSubscriber, :default}

  import OGrupoDeEstudosWeb.UI.TopNav
  import OGrupoDeEstudosWeb.UI.BottomNav
  import OGrupoDeEstudosWeb.CoreComponents, only: [icon: 1]

  use OGrupoDeEstudosWeb.NotificationHandlers
  use OGrupoDeEstudosWeb.Handlers.ActivityToastHandlers

  import OGrupoDeEstudosWeb.UI.ActivityToast

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

        following_count = Engagement.count_following(user.id)
        followers_count = Engagement.count_followers(user.id)

        is_following =
          if is_own_profile, do: false, else: Engagement.following?(current_user.id, user.id)

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
           following_count: following_count,
           followers_count: followers_count,
           is_following: is_following,
           badges: badges,
           primary_badge: primary_badge,
           is_profile_teacher: user.is_teacher,
           study_link_status: study_link_status(current_user, user),
           student_count:
             if(user.is_teacher,
               do: length(Study.list_student_links_for_teacher(user.id)),
               else: 0
             ),
           profile_tab: "steps",
           favorite_steps: [],
           favorite_sequences: [],
           favorite_sub_tab: "steps",
           contributions: [],
           bubble_open: false,
           bubble_tab: "following",
           suggested_users: [],
           bubble_following_list: [],
           bubble_followers_list: [],
           bubble_search: "",
           bubble_search_results: [],
           following_user_ids: Engagement.following_ids(current_user.id)
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

      {:error, :rate_limited} ->
        {:noreply,
         put_flash(socket, :error, "Calma! Muitas ações seguidas. Espere alguns segundinhos.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Não foi possível registrar o like.")}
    end
  end

  @impl true
  def handle_event("toggle_follow", _params, socket) do
    current = socket.assigns.current_user
    profile = socket.assigns.profile_user

    case Engagement.toggle_follow(current.id, profile.id) do
      {:ok, _} ->
        {:noreply,
         assign(socket,
           is_following: Engagement.following?(current.id, profile.id),
           following_count: Engagement.count_following(profile.id),
           followers_count: Engagement.count_followers(profile.id)
         )}

      {:error, :rate_limited} ->
        {:noreply,
         put_flash(socket, :error, "Calma! Muitas ações seguidas. Espere alguns segundinhos.")}

      {:error, _} ->
        {:noreply, socket}
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
  def handle_event("switch_profile_tab", %{"tab" => "contributions"}, socket) do
    profile_user = socket.assigns.profile_user
    contributions = Suggestions.list_by_user(profile_user.id)
    {:noreply, assign(socket, profile_tab: "contributions", contributions: contributions)}
  end

  @impl true
  def handle_event("switch_profile_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, profile_tab: tab)}
  end

  @impl true
  def handle_event("switch_favorite_sub_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, favorite_sub_tab: tab)}
  end

  # Student requests teacher OR teacher invites student
  def handle_event("request_study", params, socket) do
    current = socket.assigns.current_user
    profile = socket.assigns.profile_user

    result = resolve_study_request(current, profile, params["role"])
    handle_study_result(result, socket, profile)
  end

  # Accept pending request directly from profile
  def handle_event("accept_study", _params, socket) do
    current = socket.assigns.current_user
    profile = socket.assigns.profile_user

    import Ecto.Query
    alias OGrupoDeEstudos.Study.TeacherStudentLink

    # Find the pending link between these two users (either direction)
    link =
      OGrupoDeEstudos.Repo.one(
        from(l in TeacherStudentLink,
          where:
            l.pending == true and
              ((l.teacher_id == ^profile.id and l.student_id == ^current.id) or
                 (l.teacher_id == ^current.id and l.student_id == ^profile.id))
        )
      )

    if link do
      case Study.accept_link_request(link, current) do
        {:ok, _} ->
          {:noreply,
           socket
           |> assign(:study_link_status, :connected)
           |> put_flash(:info, "Conexão aceita!")}

        {:error, :invalid} ->
          {:noreply,
           put_flash(
             socket,
             :error,
             "Não foi possível aceitar: você não pode aceitar um pedido que você mesmo iniciou."
           )}

        _ ->
          {:noreply, put_flash(socket, :error, "Não foi possível aceitar o pedido.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Pedido não encontrado.")}
    end
  end

  def handle_event("end_study_link", _params, socket) do
    current = socket.assigns.current_user
    profile = socket.assigns.profile_user

    import Ecto.Query
    alias OGrupoDeEstudos.Study.TeacherStudentLink

    link =
      OGrupoDeEstudos.Repo.one(
        from(l in TeacherStudentLink,
          where:
            l.active == true and
              ((l.teacher_id == ^profile.id and l.student_id == ^current.id) or
                 (l.teacher_id == ^current.id and l.student_id == ^profile.id))
        )
      )

    if link do
      Study.end_link(link, current)

      {:noreply,
       socket
       |> assign(:study_link_status, study_link_status(current, profile))
       |> put_flash(:info, "Vínculo de estudo encerrado.")}
    else
      {:noreply, socket}
    end
  end

  # --- helpers ---

  defp resolve_study_request(current, %{is_teacher: true} = profile, "student"),
    do: Study.request_teacher_link(current, profile.id)

  defp resolve_study_request(%{is_teacher: true} = current, profile, "teacher"),
    do: Study.invite_student_link(current, profile.id)

  defp resolve_study_request(current, profile, _role) do
    cond do
      profile.is_teacher -> Study.request_teacher_link(current, profile.id)
      current.is_teacher -> Study.invite_student_link(current, profile.id)
      true -> {:error, :invalid}
    end
  end

  defp handle_study_result({:ok, _}, socket, profile) do
    {:noreply,
     socket
     |> assign(:study_link_status, :pending_sent)
     |> put_flash(
       :info,
       "Pedido enviado! #{Accounts.first_name(profile)} será notificado(a)."
     )}
  end

  defp handle_study_result({:error, :already_connected}, socket, _profile),
    do: {:noreply, put_flash(socket, :info, "Vocês já estão conectados.")}

  defp handle_study_result({:error, :already_pending}, socket, _profile),
    do: {:noreply, put_flash(socket, :info, "Pedido já enviado. Aguarde a resposta.")}

  defp handle_study_result(_result, socket, _profile),
    do: {:noreply, socket}

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

  defp study_link_status(current_user, profile_user) do
    if current_user.id == profile_user.id do
      nil
    else
      current_user
      |> find_study_link(profile_user)
      |> interpret_study_link(current_user, profile_user)
    end
  end

  defp find_study_link(current_user, profile_user) do
    import Ecto.Query
    alias OGrupoDeEstudos.Study.TeacherStudentLink

    OGrupoDeEstudos.Repo.one(
      from(l in TeacherStudentLink,
        where:
          (l.teacher_id == ^profile_user.id and l.student_id == ^current_user.id) or
            (l.teacher_id == ^current_user.id and l.student_id == ^profile_user.id)
      )
    )
  end

  defp interpret_study_link(nil, current_user, profile_user) do
    cond do
      profile_user.is_teacher and current_user.is_teacher -> :available_both
      profile_user.is_teacher or current_user.is_teacher -> :available
      true -> nil
    end
  end

  defp interpret_study_link(%{active: true}, _current_user, _profile_user), do: :connected

  defp interpret_study_link(
         %{pending: true, initiated_by_id: initiated_id},
         current_user,
         _profile_user
       ) do
    if initiated_id == current_user.id, do: :pending_sent, else: :pending_received
  end

  defp interpret_study_link(_link, _current_user, _profile_user), do: :available
end
