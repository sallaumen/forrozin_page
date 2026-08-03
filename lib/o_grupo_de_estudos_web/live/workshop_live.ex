defmodule OGrupoDeEstudosWeb.WorkshopLive do
  @moduledoc """
  Página pública do workshop: o link que circula no WhatsApp.

  Abre para quem ainda não tem conta (título, data, local, preço, descrição
  e quantas pessoas vão). Nomes dos inscritos e a inscrição em si exigem
  login. Nada de pagamento entra nesta LiveView — nem no socket.
  """

  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.{Accounts, Engagement, Workshops}
  alias OGrupoDeEstudos.Authorization.Policy
  alias OGrupoDeEstudos.Engagement.Badges
  alias OGrupoDeEstudos.Engagement.Comments.WorkshopCommentQuery
  alias OGrupoDeEstudos.Workshops.Workshop

  import OGrupoDeEstudosWeb.UI.CommentThread
  import OGrupoDeEstudosWeb.UI.TopNav
  import OGrupoDeEstudosWeb.WorkshopComponents

  @comment_type "workshop_comment"

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    workshop = Workshops.get_by_slug(slug)

    case Policy.authorize(:view_workshop, socket.assigns[:current_user], workshop) do
      :ok -> {:ok, assign_page(socket, workshop)}
      {:error, _} -> {:ok, not_found(socket)}
    end
  end

  defp assign_page(socket, workshop) do
    socket
    |> assign(:page_title, workshop.title)
    |> assign(:replying_to, nil)
    |> assign(:replies_map, %{})
    |> assign_workshop(workshop)
    |> reload_comments()
  end

  # Mesma resposta de slug inexistente: um "sem permissao" confirmaria que o
  # workshop existe naquele endereco.
  defp not_found(socket) do
    socket
    |> put_flash(:error, "Workshop não encontrado.")
    |> redirect(to: ~p"/study/workshops")
  end

  @impl true
  def handle_event("enroll", _params, %{assigns: %{current_user: nil}} = socket) do
    # Sem conta: guarda para onde voltar e manda para o cadastro.
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

  # ── Conversa ────────────────────────────────────────────────────────

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
      # Sem conta o formulario nem abre: melhor do que deixar escrever e
      # jogar o texto fora no envio.
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

  def handle_event("toggle_workshop_like", _params, socket) do
    with %{} = user <- socket.assigns.current_user,
         :ok <- Policy.authorize(:like, user, nil) do
      toggle_like(socket, user, "workshop", socket.assigns.workshop.id, &assign_workshop_likes/1)
    else
      _ -> {:noreply, to_signup(socket)}
    end
  end

  # O rate limit corta em 20 likes por 10s: sem isso o clique nao dá resposta
  # nenhuma e a pessoa acha que a pagina travou.
  defp toggle_like(socket, user, type, id, reload) do
    case Engagement.toggle_like(user.id, type, id) do
      {:ok, _} -> {:noreply, reload.(socket)}
      {:error, reason} -> {:noreply, put_flash(socket, :error, like_error(reason))}
    end
  end

  defp like_error(:rate_limited), do: "Calma lá! Espere alguns segundos antes de curtir de novo."
  defp like_error(_reason), do: "Não foi possível registrar sua curtida."

  # Id vem de params numa pagina publica: pode ser lixo, ou o id de um
  # comentario de outro workshop. So aceita o que esta nesta conversa.
  defp comment_of_this_workshop(socket, comment_id) do
    known =
      socket.assigns.comments
      |> Enum.map(& &1.id)
      |> Enum.concat(reply_ids(socket.assigns.replies_map))

    if comment_id in known, do: {:ok, comment_id}, else: :error
  end

  # Abre as respostas do pai: quem acabou de responder precisa ver o que
  # escreveu, sem ter que clicar em "ver respostas".
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
      # Limpa o campo so agora: recusa do servidor preserva o texto digitado.
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

  # Recarrega comentarios e respostas abertas. De proposito NAO recarrega o
  # workshop: a lista de participantes pode ter 100 linhas.
  defp reload_comments(socket) do
    comments = Engagement.list_workshop_comments(socket.assigns.workshop.id)
    replies_map = refresh_replies(socket.assigns.replies_map)

    socket
    |> assign(:comments, comments)
    |> assign(:replies_map, replies_map)
    |> assign(:comment_likes, comment_likes(socket.assigns.current_user, comments, replies_map))
    |> assign(:comment_badges, badges(comments, replies_map))
  end

  # Em lote: a thread e publica e o calculo por comentario seria um N+1 aberto
  # a qualquer visitante com o link.
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

  # ── Workshop ────────────────────────────────────────────────────────

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
    |> assign_workshop_likes()
  end

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

  defp enroll_error(:organizer), do: "Você organiza este workshop, já está dentro."
  defp enroll_error(:full), do: "As vagas acabaram."
  defp enroll_error(:not_open), do: "Este workshop não está aberto para inscrição."
  defp enroll_error(:already_enrolled), do: "Você já está inscrito."
end
