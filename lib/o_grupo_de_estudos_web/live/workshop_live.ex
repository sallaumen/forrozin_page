defmodule OGrupoDeEstudosWeb.WorkshopLive do
  @moduledoc """
  Public workshop page: the link that circulates on WhatsApp.

  It opens for whoever has no account yet (title, date, place, price, description
  and who teaches). What is private lives inside: conversation, names of enrolled
  people and the gallery.
  """

  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.{Accounts, Engagement, Workshops}
  alias OGrupoDeEstudos.Authorization.Policy
  alias OGrupoDeEstudos.Engagement.Badges
  alias OGrupoDeEstudos.Engagement.Comments.WorkshopCommentQuery
  alias OGrupoDeEstudos.Workshops.Workshop

  use OGrupoDeEstudosWeb.Handlers.StepLearning

  import OGrupoDeEstudosWeb.StudyComponents, only: [step_sheet: 1]
  import OGrupoDeEstudosWeb.UI.CommentThread
  import OGrupoDeEstudosWeb.UI.TopNav
  import OGrupoDeEstudosWeb.UI.UserAvatar, only: [user_avatar: 1]
  import OGrupoDeEstudosWeb.WorkshopComponents

  @comment_type "workshop_comment"
  # 4s: transcoding a 45s clip takes well over that, so the page can ask again a
  # few times without weighing anything down.
  @recarga_galeria_ms 4_000

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    workshop = Workshops.get_by_slug(slug)

    case Policy.authorize(:view_workshop, socket.assigns[:current_user], acesso(workshop, socket)) do
      :ok -> {:ok, socket |> permitir_media() |> assign_page(workshop)}
      {:error, _} -> {:ok, not_found(socket)}
    end
  end

  # The Policy is pure and does not query: the boundary resolves the facts first.
  defp acesso(nil, _socket), do: nil
  defp acesso(workshop, socket), do: Workshops.access_for(workshop, socket.assigns[:current_user])

  defp permitir_media(socket) do
    allow_upload(socket, :media,
      accept: ~w(.jpg .jpeg .png .webp .mp4 .mov),
      max_entries: 1,
      max_file_size: 200_000_000
    )
  end

  defp assign_page(socket, workshop) do
    socket
    |> assign(:page_title, workshop.title)
    |> assign(:replying_to, nil)
    |> assign(:replies_map, %{})
    |> assign_workshop(workshop)
    |> reload_comments()
  end

  # Same answer as an unknown slug: a "no permission" would confirm the workshop
  # exists at that address.
  defp not_found(socket) do
    socket
    |> put_flash(:error, "Workshop não encontrado.")
    |> redirect(to: ~p"/study/workshops")
  end

  @impl true
  def handle_event("search_workshop_step", %{"term" => termo}, socket) do
    {:noreply, assign(socket, :busca_passo, OGrupoDeEstudos.Study.search_related_steps(termo))}
  end

  def handle_event("add_workshop_step", %{"id" => step_id}, socket) do
    Workshops.add_step(socket.assigns.workshop, socket.assigns.current_user, step_id)

    {:noreply, socket |> assign(:busca_passo, []) |> reload_workshop()}
  end

  def handle_event("remove_workshop_step", %{"id" => step_id}, socket) do
    Workshops.remove_step(socket.assigns.workshop, socket.assigns.current_user, step_id)

    {:noreply, reload_workshop(socket)}
  end

  def handle_event("request_join", _params, %{assigns: %{current_user: nil}} = socket) do
    {:noreply, redirect(socket, to: ~p"/signup?#{[workshop: socket.assigns.workshop.slug]}")}
  end

  def handle_event("request_join", _params, socket) do
    case Workshops.request_join(socket.assigns.workshop, socket.assigns.current_user) do
      {:ok, _pedido} ->
        {:noreply,
         socket
         |> reload_workshop()
         |> put_flash(:info, "Pedido enviado. Quem organiza vai avaliar.")}

      {:error, _motivo} ->
        {:noreply, put_flash(socket, :error, "Não foi possível enviar o pedido.")}
    end
  end

  def handle_event("join_waitlist", _params, %{assigns: %{current_user: nil}} = socket) do
    {:noreply, redirect(socket, to: ~p"/signup?#{[workshop: socket.assigns.workshop.slug]}")}
  end

  def handle_event("join_waitlist", _params, socket) do
    case Workshops.join_waitlist(socket.assigns.workshop, socket.assigns.current_user) do
      {:ok, _entrada} ->
        {:noreply,
         socket
         |> reload_workshop()
         |> put_flash(:info, "Você entrou na lista de espera. Se abrir vaga, ela é sua.")}

      {:error, _motivo} ->
        {:noreply, put_flash(socket, :error, "Não foi possível entrar na lista.")}
    end
  end

  def handle_event("leave_waitlist", _params, socket) do
    Workshops.leave_waitlist(socket.assigns.workshop, socket.assigns[:current_user])

    {:noreply, socket |> reload_workshop() |> put_flash(:info, "Você saiu da lista de espera.")}
  end

  def handle_event("enroll", _params, %{assigns: %{current_user: nil}} = socket) do
    # No account: remembers where to come back to and sends to signup.
    {:noreply, redirect(socket, to: ~p"/signup?#{[workshop: socket.assigns.workshop.slug]}")}
  end

  def handle_event("enroll", _params, socket) do
    user = socket.assigns.current_user

    case Workshops.enroll(socket.assigns.workshop, user) do
      {:ok, _enrollment} ->
        {:noreply,
         socket
         |> reload_workshop()
         |> put_flash(:info, "Inscrição confirmada! Te vejo lá.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, enroll_error(reason))}
    end
  end

  def handle_event("cancel_enrollment", _params, %{assigns: %{current_user: nil}} = socket),
    do: {:noreply, socket}

  def handle_event("cancel_enrollment", _params, socket) do
    case Workshops.cancel_enrollment(socket.assigns.workshop, socket.assigns.current_user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> reload_workshop()
         |> put_flash(:info, "Inscrição cancelada.")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Você não estava inscrito.")}
    end
  end

  def handle_event("create_comment", %{"body" => body}, socket) do
    comment(socket, %{body: String.trim(body)}, "new-comment-form")
  end

  def handle_event("create_reply", %{"body" => body, "parent-id" => parent_id}, socket) do
    case comment_of_this_workshop(socket, parent_id) do
      {:ok, id} -> reply(socket, String.trim(body), id)
      :error -> {:noreply, socket}
    end
  end

  def handle_event("start_reply", %{"id" => comment_id}, socket) do
    with {:ok, id} <- comment_of_this_workshop(socket, comment_id),
         %{} <- socket.assigns.current_user do
      {:noreply, assign(socket, :replying_to, id)}
    else
      # Without an account the form does not even open, which beats letting someone
      # write and throwing the text away on submit.
      nil -> {:noreply, to_signup(socket)}
      :error -> {:noreply, socket}
    end
  end

  def handle_event("toggle_replies", %{"id" => comment_id}, socket) do
    case comment_of_this_workshop(socket, comment_id) do
      {:ok, id} -> {:noreply, socket |> toggle_replies(id) |> reload_comments()}
      :error -> {:noreply, socket}
    end
  end

  def handle_event("toggle_comment_like", %{"id" => comment_id}, socket) do
    with %{} = user <- socket.assigns.current_user,
         :ok <- Policy.authorize(:like, user, nil),
         {:ok, id} <- comment_of_this_workshop(socket, comment_id) do
      toggle_like(socket, user, @comment_type, id, &reload_comments/1)
    else
      :error -> {:noreply, socket}
      _ -> {:noreply, to_signup(socket)}
    end
  end

  def handle_event("delete_comment", %{"id" => comment_id}, socket) do
    with %{} = user <- socket.assigns.current_user,
         {:ok, id} <- comment_of_this_workshop(socket, comment_id),
         %{} = comment <- Engagement.get_workshop_comment(id),
         {:ok, _} <- Engagement.delete_workshop_comment(user, comment) do
      {:noreply, socket |> reload_comments() |> put_flash(:info, "Comentário apagado.")}
    else
      :error -> {:noreply, socket}
      _ -> {:noreply, put_flash(socket, :error, "Não foi possível apagar o comentário.")}
    end
  end

  def handle_event("validate_media", _params, socket), do: {:noreply, socket}

  def handle_event("upload_media", _params, socket) do
    workshop = socket.assigns.workshop
    user = socket.assigns.current_user

    socket
    |> consume_uploaded_entries(:media, fn %{path: tmp_path}, entry ->
      {:ok, Workshops.add_media(workshop, user, atributos_da_media(tmp_path, entry))}
    end)
    |> resultado_do_envio(socket)
  end

  def handle_event("remove_media", %{"id" => id}, socket) do
    workshop = socket.assigns.workshop
    user = socket.assigns.current_user

    case Workshops.remove_media(workshop, user, id) do
      {:ok, _} ->
        {:noreply, socket |> assign_page(workshop) |> put_flash(:info, "Mídia removida.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Não foi possível remover.")}
    end
  end

  def handle_event("toggle_workshop_like", _params, socket) do
    with %{} = user <- socket.assigns.current_user,
         :ok <- Policy.authorize(:like, user, nil) do
      toggle_like(socket, user, "workshop", socket.assigns.workshop.id, &assign_workshop_likes/1)
    else
      _ -> {:noreply, to_signup(socket)}
    end
  end

  @impl true
  def handle_info(:recarregar_galeria, socket) do
    # The timer fired, so nothing is pending anymore: releasing the lock before
    # reloading lets `assign_workshop/2` schedule the next one, if there is still
    # video converting.
    socket = assign(socket, :recarga_agendada?, false)

    {:noreply, assign_workshop(socket, socket.assigns.workshop)}
  end

  defp atributos_da_media(tmp_path, entry) do
    %{tmp_path: tmp_path, content_type: entry.client_type, byte_size: entry.client_size}
  end

  defp resultado_do_envio([{:ok, %{status: :processing}}], socket) do
    {:noreply,
     socket
     |> assign_page(socket.assigns.workshop)
     |> put_flash(:info, "Enviado! O vídeo aparece na galeria assim que terminar de preparar.")}
  end

  defp resultado_do_envio([{:ok, _media}], socket) do
    {:noreply,
     socket
     |> assign_page(socket.assigns.workshop)
     |> put_flash(:info, "Enviado! Já está na galeria.")}
  end

  defp resultado_do_envio([{:error, motivo}], socket) do
    {:noreply, put_flash(socket, :error, erro_de_media(motivo))}
  end

  defp resultado_do_envio(_nada, socket), do: {:noreply, socket}

  @doc false
  def erro_de_upload_media(:too_large), do: "Arquivo grande demais. O limite é 200 MB."
  def erro_de_upload_media(:not_accepted), do: "Só foto (JPG, PNG, WEBP) ou vídeo (MP4, MOV)."
  def erro_de_upload_media(:too_many_files), do: "Um arquivo por vez."
  def erro_de_upload_media(_outro), do: "Não deu para carregar esse arquivo."

  defp erro_de_media(:storage_full),
    do: "O armazenamento está no limite. Avise quem organiza antes de tentar de novo."

  defp erro_de_media(:media_quota),
    do: "Este workshop chegou ao limite de 2 GB em fotos e vídeos."

  defp erro_de_media(:unsupported_type), do: "Só entra foto ou vídeo."
  defp erro_de_media(:unauthorized), do: "Só quem está no workshop manda mídia."
  defp erro_de_media(_outro), do: "Não foi possível enviar."

  # The rate limit cuts at 20 likes per 10s: without this the click gives no
  # answer at all and the page looks frozen.
  defp toggle_like(socket, user, type, id, reload) do
    case Engagement.toggle_like(user.id, type, id) do
      {:ok, _} -> {:noreply, reload.(socket)}
      {:error, reason} -> {:noreply, put_flash(socket, :error, like_error(reason))}
    end
  end

  defp like_error(:rate_limited), do: "Calma lá! Espere alguns segundos antes de curtir de novo."
  defp like_error(_reason), do: "Não foi possível registrar sua curtida."

  # The id comes from params on a public page: it can be garbage, or the id of a
  # comment from another workshop. Only what belongs to this conversation is accepted.
  defp comment_of_this_workshop(socket, comment_id) do
    known =
      socket.assigns.comments
      |> Enum.map(& &1.id)
      |> Enum.concat(reply_ids(socket.assigns.replies_map))

    if comment_id in known, do: {:ok, comment_id}, else: :error
  end

  # Opens the replies of the parent: whoever just replied needs to see what they
  # wrote, without having to click "see replies".
  defp reply(socket, body, parent_id) do
    socket
    |> assign(:replies_map, Map.put_new(socket.assigns.replies_map, parent_id, []))
    |> comment(
      %{body: body, parent_workshop_comment_id: parent_id},
      "reply-form-#{parent_id}"
    )
  end

  defp comment(socket, %{body: ""}, _form_id), do: {:noreply, socket}

  defp comment(socket, attrs, form_id) do
    user = socket.assigns.current_user
    workshop = socket.assigns.workshop

    with :ok <- Policy.authorize(:comment_workshop, user, workshop),
         {:ok, _comment} <- Engagement.create_workshop_comment(user, workshop.id, attrs) do
      # Clears the field only now: a server refusal preserves the typed text.
      {:noreply,
       socket
       |> assign(:replying_to, nil)
       |> reload_comments()
       |> push_event("form:clear", %{id: form_id})}
    else
      {:error, :unauthenticated} -> {:noreply, to_signup(socket)}
      {:error, reason} -> {:noreply, put_flash(socket, :error, comment_error(reason))}
    end
  end

  defp comment_error(:unauthorized), do: "Este workshop não está aberto para comentários."
  defp comment_error(:rate_limited), do: "Calma lá! Espere alguns segundos para comentar de novo."
  defp comment_error(_reason), do: "Não foi possível publicar seu comentário."

  defp to_signup(socket) do
    redirect(socket, to: ~p"/signup?#{[workshop: socket.assigns.workshop.slug]}")
  end

  defp toggle_replies(socket, comment_id) do
    replies_map = socket.assigns.replies_map

    case Map.has_key?(replies_map, comment_id) do
      true -> assign(socket, :replies_map, Map.delete(replies_map, comment_id))
      false -> assign(socket, :replies_map, Map.put(replies_map, comment_id, []))
    end
  end

  # Reloads comments and open replies. On purpose does NOT reload the workshop:
  # the participant list can have 100 rows.
  defp reload_comments(socket) do
    comments = Engagement.list_workshop_comments(socket.assigns.workshop.id)
    replies_map = refresh_replies(socket.assigns.replies_map)

    socket
    |> assign(:comments, comments)
    |> assign(:replies_map, replies_map)
    |> assign(:comment_likes, comment_likes(socket.assigns.current_user, comments, replies_map))
    |> assign(:comment_badges, badges(comments, replies_map))
  end

  # Batched: the thread is public and the per-comment calculation would be an N+1
  # open to any visitor with the link.
  defp badges(comments, replies_map) do
    comments
    |> Enum.concat(replies_map |> Map.values() |> List.flatten())
    |> Enum.map(& &1.user_id)
    |> Enum.uniq()
    |> Badges.primary_batch()
  end

  defp refresh_replies(replies_map) do
    Map.new(replies_map, fn {parent_id, _} ->
      {parent_id, Engagement.list_replies(WorkshopCommentQuery, parent_id)}
    end)
  end

  defp comment_likes(nil, _comments, _replies_map), do: %{liked_ids: MapSet.new(), counts: %{}}

  defp comment_likes(user, comments, replies_map) do
    ids = Enum.map(comments, & &1.id) ++ reply_ids(replies_map)
    Engagement.likes_map(user.id, @comment_type, ids)
  end

  defp reply_ids(replies_map) do
    replies_map |> Map.values() |> List.flatten() |> Enum.map(& &1.id)
  end

  defp assign_workshop(socket, workshop) do
    user = socket.assigns[:current_user]
    participants = Workshops.list_participants(workshop.id)

    socket
    |> assign(:workshop, workshop)
    |> assign(:is_admin, user && Accounts.admin?(user))
    |> assign(:participants, participants)
    |> assign(:enrolled_count, length(participants))
    |> assign(:enrolled?, user && Enum.any?(participants, &(&1.user_id == user.id)))
    |> assign(:organizer?, Workshops.admin?(workshop, user))
    |> assign(:full?, Workshop.full?(workshop, length(participants)))
    |> assign(:can_comment?, Policy.authorized?(:comment_workshop, user, workshop))
    |> assign(:pode_ver_media?, Workshops.can_see_media?(workshop, user))
    |> assign(:media, media_visivel(workshop, user))
    |> assign(:professores, professores(workshop))
    |> assign(:passos, Workshops.list_steps(workshop.id))
    |> assign(:busca_passo, [])
    |> assign(:liberado?, Workshops.liberado?(workshop, user))
    |> assign(:vitrine?, vitrine?(workshop, user))
    |> assign(:join_status, Workshops.join_status(workshop, user))
    |> assign(:na_fila, Workshops.waitlist_position(workshop, user))
    |> assign(:fila_total, Workshops.waitlist_count(workshop.id))
    |> agendar_recarga_da_galeria()
    |> assign_workshop_likes()
  end

  # The storefront is the state of whoever stands outside a private workshop. A
  # public workshop is never in that state: its rules did not change.
  defp vitrine?(%Workshop{visibility: :private} = workshop, user),
    do: not Workshops.liberado?(workshop, user)

  defp vitrine?(%Workshop{}, _user), do: false

  # Who teaches is now an explicit choice of whoever organizes. With nobody chosen
  # it falls back to the organizer: the right guess in most cases, and it goes away
  # as soon as the list is filled in.
  defp professores(workshop) do
    case Workshops.list_teachers(workshop.id) do
      [] -> [do_organizador(workshop)]
      escolhidos -> escolhidos
    end
  end

  defp do_organizador(workshop) do
    %{
      user_id: workshop.organizer.id,
      name: workshop.organizer.name,
      username: workshop.organizer.username,
      avatar_path: workshop.organizer.avatar_path
    }
  end

  # The transcode runs in another queue and cannot notify this page. While there
  # is video converting, the gallery reloads itself: without this the uploader
  # stares at "Processando" until they remember to hit F5.
  #
  # No PubSub: the queue has concurrency 1 and the wait is seconds, so a timer
  # that only exists while there is something to wait for is cheaper than a
  # topic, a subscribe and a broadcast.
  defp agendar_recarga_da_galeria(socket) do
    esperando? = connected?(socket) and Enum.any?(socket.assigns.media, &processando?/1)

    agendar_recarga(socket, esperando?, socket.assigns[:recarga_agendada?] || false)
  end

  # A timer is already flying: do not schedule another. `assign_workshop/2` runs
  # on every enrollment and every like, and without this lock each click would
  # stack one more poll over the same video.
  defp agendar_recarga(socket, true, true), do: socket

  defp agendar_recarga(socket, true, false) do
    Process.send_after(self(), :recarregar_galeria, intervalo_recarga())
    assign(socket, :recarga_agendada?, true)
  end

  defp agendar_recarga(socket, false, _agendada?), do: assign(socket, :recarga_agendada?, false)

  # Configurable only so the test can wait for the timer without holding the suite.
  defp intervalo_recarga do
    Application.get_env(:o_grupo_de_estudos, :recarga_galeria_ms, @recarga_galeria_ms)
  end

  defp processando?(%{status: :processing}), do: true
  defp processando?(_outra), do: false

  defp assign_workshop_likes(socket) do
    workshop = socket.assigns.workshop
    user = socket.assigns[:current_user]

    socket
    |> assign(:like_count, Engagement.count_likes("workshop", workshop.id))
    |> assign(:liked?, liked_workshop?(user, workshop))
  end

  defp liked_workshop?(nil, _workshop), do: false

  defp liked_workshop?(user, workshop) do
    %{liked_ids: liked} = Engagement.likes_map(user.id, "workshop", [workshop.id])
    MapSet.member?(liked, workshop.id)
  end

  defp reload_workshop(socket) do
    assign_workshop(socket, Workshops.get_by_slug(socket.assigns.workshop.slug))
  end

  # The gallery is paid content: only who is in the workshop sees it.
  defp media_visivel(workshop, user) do
    if Workshops.can_see_media?(workshop, user), do: Workshops.list_media(workshop.id), else: []
  end

  defp enroll_error(:organizer), do: "Você organiza este workshop, já está dentro."
  defp enroll_error(:full), do: "As vagas acabaram."
  defp enroll_error(:not_open), do: "Este workshop não está aberto para inscrição."
  defp enroll_error(:already_enrolled), do: "Você já está inscrito."
end
