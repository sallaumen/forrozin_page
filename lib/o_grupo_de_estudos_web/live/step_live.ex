defmodule OGrupoDeEstudosWeb.StepLive do
  @moduledoc "Detail page for a single encyclopedia step."

  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.{Accounts, Admin, Encyclopedia, Engagement}
  alias OGrupoDeEstudos.Encyclopedia.{ConnectionQuery, StepLinkQuery, StepQuery}

  on_mount {OGrupoDeEstudosWeb.UserAuth, :ensure_authenticated}
  on_mount {OGrupoDeEstudosWeb.Navigation, :detail}
  on_mount {OGrupoDeEstudosWeb.Hooks.NotificationSubscriber, :default}

  import OGrupoDeEstudosWeb.UI.TopNav
  import OGrupoDeEstudosWeb.UI.CommentThread

  use OGrupoDeEstudosWeb.NotificationHandlers

  @impl true
  def mount(%{"code" => code}, _session, socket) do
    admin = Accounts.admin?(socket.assigns.current_user)
    user_id = socket.assigns.current_user.id

    case Encyclopedia.fetch_step_with_details(code, admin: admin) do
      {:ok, _} ->
        step =
          StepQuery.get_by(code: code, preload: [:suggested_by, :category, :technical_concepts])

        can_edit = admin or step.suggested_by_id == user_id

        connections_out =
          ConnectionQuery.list_by(source_step_id: step.id, preload: [:target_step])

        connections_in = ConnectionQuery.list_by(target_step_id: step.id, preload: [:source_step])

        approved_links =
          StepLinkQuery.list_by(
            step_id: step.id,
            approved: true,
            preload: [:submitted_by]
          )

        link_ids = Enum.map(approved_links, & &1.id)
        link_likes = Engagement.likes_map(user_id, "step_link", link_ids)

        sorted_links =
          Enum.sort_by(approved_links, fn link ->
            -Map.get(link_likes.counts, link.id, 0)
          end)

        # Load step comments
        step_comments = Engagement.list_step_comments(step.id)
        step_comment_ids = Enum.map(step_comments, & &1.id)
        step_comment_likes = Engagement.likes_map(user_id, "step_comment", step_comment_ids)

        {:ok,
         assign(socket,
           step: step,
           page_title: step.name,
           is_admin: admin,
           can_edit: can_edit,
           edit_mode: false,
           connections_out: connections_out,
           connections_in: connections_in,
           connection_search: "",
           connection_suggestions: [],
           incoming_search: "",
           incoming_suggestions: [],
           categories: Encyclopedia.list_categories(),
           approved_links: sorted_links,
           link_likes: link_likes,
           link_url: "",
           link_title: "",
           link_submitted: false,
           expanded_link: nil,
           editing_link_id: nil,
           editing_link_url: "",
           editing_link_title: "",
           step_comments: step_comments,
           step_comment_likes: step_comment_likes,
           replying_to: nil,
           replies_map: %{}
         )}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Passo não encontrado.")
         |> redirect(to: ~p"/collection")}
    end
  end

  @impl true
  def handle_event("toggle_edit", _params, socket) do
    {:noreply, assign(socket, edit_mode: not socket.assigns.edit_mode)}
  end

  def handle_event("update_step", %{"step" => params}, socket) do
    if not socket.assigns.can_edit, do: {:noreply, socket}

    case Admin.update_step(socket.assigns.step, params) do
      {:ok, updated} ->
        updated =
          StepQuery.get_by(
            code: updated.code,
            preload: [
              :category,
              :technical_concepts,
              :suggested_by,
              connections_as_source: :target_step,
              connections_as_target: :source_step
            ]
          )

        {:noreply,
         assign(socket, step: updated, page_title: updated.name)
         |> put_flash(:info, "Passo atualizado")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao salvar")}
    end
  end

  def handle_event("delete_step", _params, socket) do
    if not socket.assigns.is_admin do
      {:noreply, socket}
    else
      step = socket.assigns.step

      # Soft-delete all connections first (cascade)
      ConnectionQuery.soft_delete_by(either_step_id: step.id)

      case Admin.delete_step(step) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Passo \"#{step.name}\" deletado.")
           |> redirect(to: ~p"/collection")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Erro ao deletar passo")}
      end
    end
  end

  def handle_event("search_connection", %{"target_code" => term}, socket) do
    if not socket.assigns.can_edit or String.length(term) < 1 do
      {:noreply, assign(socket, connection_search: term, connection_suggestions: [])}
    else
      suggestions =
        StepQuery.list_by(
          status: "published",
          search: term,
          order_by: [asc: :name],
          limit: 8,
          preload: [:category]
        )

      {:noreply, assign(socket, connection_search: term, connection_suggestions: suggestions)}
    end
  end

  def handle_event("select_connection_target", %{"code" => code}, socket) do
    {:noreply, assign(socket, connection_search: code, connection_suggestions: [])}
  end

  def handle_event("create_connection", %{"target_code" => target_code}, socket) do
    if not socket.assigns.can_edit, do: {:noreply, socket}

    target = StepQuery.get_by(code: target_code)

    if is_nil(target) do
      {:noreply, put_flash(socket, :error, "Passo não encontrado")}
    else
      step = socket.assigns.step

      case Admin.create_connection(%{source_step_id: step.id, target_step_id: target.id}) do
        {:ok, _} -> {:noreply, reload_step(socket, step.code)}
        {:error, _} -> {:noreply, put_flash(socket, :error, "Conexão já existe")}
      end
    end
  end

  def handle_event(
        "delete_connection",
        %{"source" => source_code, "target" => target_code},
        socket
      ) do
    if not socket.assigns.can_edit, do: {:noreply, socket}

    connection = ConnectionQuery.get_by(source_code: source_code, target_code: target_code)

    if connection do
      {:ok, _} = Admin.delete_connection(connection.id)
      {:noreply, reload_step(socket, socket.assigns.step.code)}
    else
      {:noreply, put_flash(socket, :error, "Conexão não encontrada")}
    end
  end

  # --- Incoming connections ---

  def handle_event("search_incoming_connection", %{"source_code" => term}, socket) do
    if not socket.assigns.can_edit or String.length(term) < 1 do
      {:noreply, assign(socket, incoming_search: term, incoming_suggestions: [])}
    else
      suggestions =
        StepQuery.list_by(
          search: term,
          order_by: [asc: :name],
          limit: 8,
          preload: [:category]
        )

      {:noreply, assign(socket, incoming_search: term, incoming_suggestions: suggestions)}
    end
  end

  def handle_event("select_incoming_target", %{"code" => code}, socket) do
    {:noreply, assign(socket, incoming_search: code, incoming_suggestions: [])}
  end

  def handle_event("create_incoming_connection", %{"source_code" => source_code}, socket) do
    if not socket.assigns.can_edit, do: {:noreply, socket}

    source = StepQuery.get_by(code: source_code)

    if is_nil(source) do
      {:noreply, put_flash(socket, :error, "Passo não encontrado")}
    else
      step = socket.assigns.step

      case Admin.create_connection(%{source_step_id: source.id, target_step_id: step.id}) do
        {:ok, _} -> {:noreply, reload_step(socket, step.code)}
        {:error, _} -> {:noreply, put_flash(socket, :error, "Conexão já existe")}
      end
    end
  end

  # --- Link editing ---

  def handle_event("start_edit_link", %{"link-id" => link_id}, socket) do
    link = Enum.find(socket.assigns.approved_links, &(&1.id == link_id))

    if link do
      {:noreply,
       assign(socket,
         editing_link_id: link_id,
         editing_link_url: link.url,
         editing_link_title: link.title || ""
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_event("cancel_edit_link", _params, socket) do
    {:noreply, assign(socket, editing_link_id: nil, editing_link_url: "", editing_link_title: "")}
  end

  def handle_event("update_link", %{"url" => url, "title" => title}, socket) do
    link = Enum.find(socket.assigns.approved_links, &(&1.id == socket.assigns.editing_link_id))
    user_id = socket.assigns.current_user.id
    can_edit_link = socket.assigns.is_admin or (link && link.submitted_by_id == user_id)

    if link && can_edit_link do
      case Admin.update_step_link(link, %{url: String.trim(url), title: String.trim(title)}) do
        {:ok, _} ->
          socket =
            socket
            |> assign(editing_link_id: nil, editing_link_url: "", editing_link_title: "")
            |> reload_step(socket.assigns.step.code)
            |> put_flash(:info, "Link atualizado")

          {:noreply, socket}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "URL inválida")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("delete_link", %{"link-id" => link_id}, socket) do
    link = Enum.find(socket.assigns.approved_links, &(&1.id == link_id))
    user_id = socket.assigns.current_user.id
    can_delete = socket.assigns.is_admin or (link && link.submitted_by_id == user_id)

    if link && can_delete do
      case Admin.delete_step_link(link) do
        {:ok, _} ->
          {:noreply,
           socket
           |> reload_step(socket.assigns.step.code)
           |> put_flash(:info, "Link removido")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Erro ao remover link")}
      end
    else
      {:noreply, socket}
    end
  end

  # --- Unapprove step ---

  def handle_event("unapprove_step", _params, socket) do
    if not socket.assigns.is_admin, do: {:noreply, socket}

    case Admin.unapprove_step(socket.assigns.step) do
      {:ok, _} ->
        {:noreply,
         socket
         |> reload_step(socket.assigns.step.code)
         |> put_flash(:info, "Passo desaprovado — removido do acervo público")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao desaprovar")}
    end
  end

  def handle_event("submit_link", %{"url" => url, "title" => title}, socket) do
    user_id = socket.assigns.current_user.id
    step_id = socket.assigns.step.id

    attrs = %{
      url: String.trim(url),
      title: String.trim(title),
      step_id: step_id,
      submitted_by_id: user_id,
      approved: false
    }

    case Admin.create_step_link(attrs) do
      {:ok, _link} ->
        {:noreply,
         socket
         |> assign(link_url: "", link_title: "", link_submitted: true)
         |> put_flash(:info, "Link enviado para aprovação!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "URL inválida. Use http:// ou https://")}
    end
  end

  def handle_event("toggle_link_like", %{"link-id" => link_id}, socket) do
    user_id = socket.assigns.current_user.id

    case Engagement.toggle_like(user_id, "step_link", link_id) do
      {:ok, _} ->
        # Reload link likes and re-sort
        link_ids = Enum.map(socket.assigns.approved_links, & &1.id)
        link_likes = Engagement.likes_map(user_id, "step_link", link_ids)

        sorted_links =
          Enum.sort_by(socket.assigns.approved_links, fn link ->
            -Map.get(link_likes.counts, link.id, 0)
          end)

        {:noreply, assign(socket, link_likes: link_likes, approved_links: sorted_links)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao registrar like")}
    end
  end

  def handle_event("toggle_link_video", %{"link-id" => link_id}, socket) do
    expanded =
      if socket.assigns.expanded_link == link_id, do: nil, else: link_id

    {:noreply, assign(socket, expanded_link: expanded)}
  end

  # --- Comments ---

  def handle_event("create_comment", %{"body" => body}, socket) do
    user = socket.assigns.current_user
    step = socket.assigns.step

    case Engagement.create_step_comment(user, step.id, %{body: body}) do
      {:ok, _comment} ->
        {:noreply, reload_step_comments(socket)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Não foi possível postar o comentário.")}
    end
  end

  def handle_event("create_reply", %{"body" => body, "parent-id" => parent_id}, socket) do
    user = socket.assigns.current_user
    step = socket.assigns.step

    case Engagement.create_step_comment(user, step.id, %{
           body: body,
           parent_step_comment_id: parent_id
         }) do
      {:ok, _reply} ->
        {:noreply, socket |> reload_step_comments() |> assign(:replying_to, nil)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Não foi possível postar a resposta.")}
    end
  end

  def handle_event("toggle_comment_like", %{"type" => type, "id" => id}, socket) do
    user = socket.assigns.current_user

    case Engagement.toggle_like(user.id, type, id) do
      {:ok, _} -> {:noreply, reload_step_comments(socket)}
      {:error, _} -> {:noreply, socket}
    end
  end

  def handle_event("start_reply", %{"id" => comment_id}, socket) do
    {:noreply, assign(socket, :replying_to, comment_id)}
  end

  def handle_event("toggle_replies", %{"id" => comment_id}, socket) do
    alias OGrupoDeEstudos.Engagement.Comments.StepCommentQuery
    replies_map = socket.assigns.replies_map

    if Map.has_key?(replies_map, comment_id) do
      socket = assign(socket, :replies_map, Map.delete(replies_map, comment_id))
      {:noreply, reload_step_comments(socket)}
    else
      replies = Engagement.list_replies(StepCommentQuery, comment_id)
      new_map = Map.put(replies_map, comment_id, replies)
      socket = assign(socket, :replies_map, new_map)
      # Reload likes to include reply IDs
      {:noreply, reload_step_comments(socket)}
    end
  end

  def handle_event("delete_comment", %{"id" => id, "type" => "step_comment"}, socket) do
    user = socket.assigns.current_user
    alias OGrupoDeEstudos.Engagement.Comments.StepComment
    comment = OGrupoDeEstudos.Repo.get!(StepComment, id)

    case Engagement.delete_step_comment(user, comment) do
      {:ok, _} -> {:noreply, reload_step_comments(socket)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Sem permissão.")}
    end
  end

  defp reload_step_comments(socket) do
    alias OGrupoDeEstudos.Engagement.Comments.StepCommentQuery

    step = socket.assigns.step
    user = socket.assigns.current_user

    comments = Engagement.list_step_comments(step.id)
    comment_ids = Enum.map(comments, & &1.id)

    # Refresh expanded replies from DB (so like_count updates)
    replies_map =
      socket.assigns.replies_map
      |> Map.keys()
      |> Enum.reduce(%{}, fn parent_id, acc ->
        replies = Engagement.list_replies(StepCommentQuery, parent_id)
        Map.put(acc, parent_id, replies)
      end)

    reply_ids =
      replies_map
      |> Map.values()
      |> List.flatten()
      |> Enum.map(& &1.id)

    all_comment_ids = comment_ids ++ reply_ids
    comment_likes = Engagement.likes_map(user.id, "step_comment", all_comment_ids)

    assign(socket,
      step_comments: comments,
      step_comment_likes: comment_likes,
      replies_map: replies_map
    )
  end

  defp reload_step(socket, code) do
    case Encyclopedia.fetch_step_with_details(code, admin: socket.assigns.is_admin) do
      {:ok, _} ->
        step =
          StepQuery.get_by(code: code, preload: [:suggested_by, :category, :technical_concepts])

        out = ConnectionQuery.list_by(source_step_id: step.id, preload: [:target_step])
        inn = ConnectionQuery.list_by(target_step_id: step.id, preload: [:source_step])

        approved_links =
          StepLinkQuery.list_by(step_id: step.id, approved: true, preload: [:submitted_by])

        link_ids = Enum.map(approved_links, & &1.id)
        user_id = socket.assigns.current_user.id
        link_likes = Engagement.likes_map(user_id, "step_link", link_ids)

        sorted_links =
          Enum.sort_by(approved_links, fn link ->
            -Map.get(link_likes.counts, link.id, 0)
          end)

        assign(socket,
          step: step,
          connections_out: out,
          connections_in: inn,
          connection_search: "",
          connection_suggestions: [],
          incoming_search: "",
          incoming_suggestions: [],
          approved_links: sorted_links,
          link_likes: link_likes
        )

      _ ->
        socket
    end
  end

  def category_color(%{category: %{color: color}}), do: color
  def category_color(_), do: "#7f8c8d"

  def category_label(%{category: %{label: label}}), do: label
  def category_label(_), do: "—"

  @doc """
  Parses a URL and returns `{:youtube, embed_url}` for YouTube links,
  or `:external` for all other URLs.

  Supports:
  - `https://www.youtube.com/watch?v=VIDEO_ID`
  - `https://youtu.be/VIDEO_ID`
  - URLs with additional query parameters (only `v` is used)
  """
  def youtube_embed_url(url) when is_binary(url) do
    uri = URI.parse(url)

    cond do
      uri.host in ["www.youtube.com", "youtube.com"] and uri.path == "/watch" ->
        case URI.decode_query(uri.query || "") do
          %{"v" => video_id} when video_id != "" ->
            {:youtube, "https://www.youtube.com/embed/#{video_id}"}

          _ ->
            :external
        end

      uri.host == "youtu.be" and is_binary(uri.path) ->
        video_id = String.trim_leading(uri.path, "/")

        if video_id != "" do
          {:youtube, "https://www.youtube.com/embed/#{video_id}"}
        else
          :external
        end

      true ->
        :external
    end
  end

  def youtube_embed_url(_), do: :external
end
