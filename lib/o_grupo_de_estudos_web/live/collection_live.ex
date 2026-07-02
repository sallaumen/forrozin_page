defmodule OGrupoDeEstudosWeb.CollectionLive do
  @moduledoc """
  Encyclopedia of dance steps.

  Requires authentication. Step wip/draft visibility is controlled
  in the `Encyclopedia` context, never here.
  """

  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.{Accounts, Admin, Encyclopedia, Engagement}
  alias OGrupoDeEstudos.Authorization.Policy
  alias OGrupoDeEstudos.Encyclopedia.CollectionBrowser
  alias OGrupoDeEstudos.Encyclopedia.{ConnectionQuery, SectionQuery, StepLinkQuery, StepQuery}
  alias OGrupoDeEstudos.Engagement.Comments.StepCommentQuery
  alias OGrupoDeEstudosWeb.StepDrawer

  on_mount {OGrupoDeEstudosWeb.Navigation, :primary}
  on_mount {OGrupoDeEstudosWeb.Hooks.NotificationSubscriber, :default}

  import OGrupoDeEstudosWeb.UI.TopNav
  import OGrupoDeEstudosWeb.UI.BottomNav
  import OGrupoDeEstudosWeb.CollectionComponents
  import OGrupoDeEstudosWeb.CoreComponents, only: [flash: 1, icon: 1]
  import OGrupoDeEstudosWeb.StepDetail, only: [step_detail: 1]
  import OGrupoDeEstudosWeb.UI.PWAInstallBanner
  import OGrupoDeEstudosWeb.UI.SocialBubble

  use OGrupoDeEstudosWeb.NotificationHandlers
  use OGrupoDeEstudosWeb.Handlers.FollowHandlers
  use OGrupoDeEstudosWeb.Handlers.SocialBubbleHandlers
  use OGrupoDeEstudosWeb.Handlers.ActivityToastHandlers

  import OGrupoDeEstudosWeb.UI.ActivityToast

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(initial_assigns(Accounts.admin?(socket.assigns.current_user)))
      |> load_collection_data()

    {:ok, socket}
  end

  # Iron Law: the heavy acervo queries run only on the connected render. The
  # dead/HTTP render returns instantly with placeholders + a loading skeleton,
  # then the WebSocket mount fills the data in.
  defp load_collection_data(socket) do
    if connected?(socket) do
      sections = Encyclopedia.list_sections_with_steps(admin: socket.assigns.is_admin)

      assign(socket,
        loaded?: true,
        sections: sections,
        collection_cards: CollectionBrowser.build_sections(sections),
        categories: Encyclopedia.list_categories(),
        open_sections: Map.new(sections, fn s -> {s.id, false} end),
        steps_with_links: StepLinkQuery.step_ids_with_links(),
        following_user_ids: Engagement.following_ids(socket.assigns.current_user.id)
      )
    else
      socket
    end
  end

  defp initial_assigns(admin) do
    [
      is_admin: admin,
      loaded?: false,
      sections: [],
      collection_cards: [],
      categories: [],
      open_sections: %{},
      steps_with_links: MapSet.new(),
      step_likes: %{liked_ids: MapSet.new(), counts: %{}},
      following_user_ids: [],
      search: "",
      search_results: [],
      category_filter: "all",
      edit_mode: false,
      page_title: "Acervo",
      drawer_open: false,
      drawer_type: nil,
      drawer_item: nil,
      drawer_connections_out: [],
      drawer_connections_in: [],
      connections_expanded: false,
      drawer_step_image: nil,
      drawer_links: [],
      drawer_link_likes: %{liked_ids: MapSet.new(), counts: %{}},
      drawer_like_count: 0,
      connection_search: "",
      connection_suggestions: [],
      suggest_mode: false,
      suggest_form: %{},
      suggest_error: nil,
      can_edit_drawer: false,
      active_tab: "acervo",
      my_steps: [],
      bubble_open: false,
      bubble_tab: "following",
      suggested_users: [],
      bubble_following_list: [],
      bubble_followers_list: [],
      bubble_search: "",
      bubble_search_results: [],
      expanded_step: nil,
      expanded_comments: [],
      expanded_comment_likes: %{liked_ids: MapSet.new(), counts: %{}},
      expanded_replies_map: %{},
      expanded_replying_to: nil,
      expanded_video: nil,
      step_comment_counts: %{},
      drawer_liked: false,
      drawer_favorited: false,
      deep_linked_step_code: nil,
      active_section_id: nil,
      active_section_card: nil,
      filters_open?: false,
      suggest_section_id: nil
    ]
  end

  @impl true
  def handle_params(%{"step" => step_code}, _uri, socket)
      when is_binary(step_code) and step_code != "" do
    case find_step_context(socket.assigns.sections, step_code) do
      {:ok, section_id} ->
        details = CollectionBrowser.section_details(socket.assigns.sections, section_id)

        {:noreply,
         socket
         |> assign(
           active_tab: "acervo",
           search: "",
           search_results: [],
           active_section_id: section_id,
           active_section_card: details,
           deep_linked_step_code: step_code,
           drawer_open: false,
           drawer_type: nil,
           drawer_item: nil
         )
         |> push_event("scroll-to-element", %{id: "collection-step-#{step_code}", block: "center"})}

      :error ->
        {:noreply, assign(socket, :deep_linked_step_code, nil)}
    end
  end

  def handle_params(_params, _uri, socket) do
    previous_deep_link = socket.assigns[:deep_linked_step_code]

    socket =
      if previous_deep_link do
        assign(socket,
          deep_linked_step_code: nil,
          active_section_id: nil,
          active_section_card: nil
        )
      else
        assign(socket, :deep_linked_step_code, nil)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"term" => term}, socket) do
    admin = Accounts.admin?(socket.assigns.current_user)
    results = if term == "", do: [], else: Encyclopedia.search_steps(term, admin: admin)
    {:noreply, assign(socket, search: term, search_results: results)}
  end

  def handle_event("filter", %{"category" => category}, socket) do
    {:noreply, assign(socket, category_filter: category)}
  end

  def handle_event("toggle_filters", _params, socket) do
    {:noreply, assign(socket, :filters_open?, !socket.assigns.filters_open?)}
  end

  def handle_event("enter_section", %{"section_id" => section_id}, socket) do
    details = CollectionBrowser.section_details(socket.assigns.sections, section_id)

    {:noreply,
     assign(socket,
       active_section_id: section_id,
       active_section_card: details,
       suggest_section_id: section_id
     )}
  end

  def handle_event("back_to_overview", _params, socket) do
    socket =
      assign(socket,
        active_section_id: nil,
        active_section_card: nil
      )

    socket =
      if socket.assigns.deep_linked_step_code do
        socket
        |> assign(:deep_linked_step_code, nil)
        |> push_patch(to: ~p"/collection", replace: true)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("toggle_section", %{"section_id" => id}, socket) do
    open_sections = Map.update(socket.assigns.open_sections, id, true, fn a -> !a end)
    {:noreply, assign(socket, open_sections: open_sections)}
  end

  def handle_event("expand_all", _params, socket) do
    open_sections = Map.new(socket.assigns.sections, fn s -> {s.id, true} end)
    {:noreply, assign(socket, open_sections: open_sections)}
  end

  def handle_event("collapse_all", _params, socket) do
    open_sections = Map.new(socket.assigns.sections, fn s -> {s.id, false} end)
    {:noreply, assign(socket, open_sections: open_sections)}
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    socket =
      if tab == "meus_passos" do
        my_steps = Encyclopedia.list_user_steps(socket.assigns.current_user.id)
        assign(socket, active_tab: tab, my_steps: my_steps)
      else
        assign(socket, active_tab: tab)
      end

    {:noreply, socket}
  end

  def handle_event("toggle_edit_mode", _params, socket) do
    if Policy.authorized?(:manage_section, socket.assigns.current_user, nil) do
      {:noreply, assign(socket, edit_mode: not socket.assigns.edit_mode)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("open_step", %{"code" => code}, socket) do
    socket =
      if socket.assigns.deep_linked_step_code && socket.assigns.deep_linked_step_code != code do
        socket
        |> assign(:deep_linked_step_code, nil)
        |> push_patch(to: ~p"/collection", replace: true)
      else
        socket
      end

    case Encyclopedia.fetch_step_with_details(code, admin: socket.assigns.is_admin) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(drawer_open: true, drawer_type: :step)
         |> load_drawer_step(code)}

      {:error, :not_found} ->
        {:noreply, socket}
    end
  end

  def handle_event("copy_step_link", %{"code" => code}, socket) do
    {:noreply,
     socket
     |> push_event("clipboard:copy", %{text: url(~p"/collection?step=#{code}")})
     |> put_flash(:info, "Link copiado")}
  end

  def handle_event("open_section", %{"id" => id}, socket) do
    case SectionQuery.get_by(id: id, preload: [:category]) do
      nil ->
        {:noreply, socket}

      section ->
        {:noreply,
         assign(socket,
           drawer_open: true,
           drawer_type: :section,
           drawer_item: section,
           drawer_connections_out: [],
           drawer_connections_in: []
         )}
    end
  end

  def handle_event("close_drawer", _params, socket) do
    {:noreply, assign(socket, drawer_open: false, drawer_type: nil, drawer_item: nil)}
  end

  def handle_event("toggle_connections", _params, socket) do
    {:noreply, assign(socket, connections_expanded: not socket.assigns.connections_expanded)}
  end

  def handle_event("update_step", %{"step" => params}, socket) do
    if Policy.authorized?(:edit_step, socket.assigns.current_user, socket.assigns.drawer_item) do
      step = socket.assigns.drawer_item

      case Admin.update_step(step, params) do
        {:ok, updated} ->
          {:noreply,
           socket
           |> load_drawer_step(updated.code)
           |> reload_sections()
           |> put_flash(:info, "Passo atualizado")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Erro ao salvar passo")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("update_section", %{"section" => params}, socket) do
    if Policy.authorized?(
         :manage_section,
         socket.assigns.current_user,
         socket.assigns.drawer_item
       ) do
      section = socket.assigns.drawer_item

      case Admin.update_section(section, params) do
        {:ok, updated} ->
          updated = SectionQuery.get_by(id: updated.id, preload: [:category])

          {:noreply,
           socket
           |> assign(drawer_item: updated)
           |> reload_sections()
           |> put_flash(:info, "Seção atualizada")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Erro ao salvar seção")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("search_connection", %{"target_code" => term}, socket) do
    if Policy.authorized?(:edit_step, socket.assigns.current_user, socket.assigns.drawer_item) and
         String.length(term) >= 1 do
      suggestions =
        StepQuery.list_by(
          status: :published,
          search: term,
          order_by: [asc: :name],
          limit: 8,
          preload: [:category]
        )

      {:noreply, assign(socket, connection_search: term, connection_suggestions: suggestions)}
    else
      {:noreply, assign(socket, connection_search: term, connection_suggestions: [])}
    end
  end

  def handle_event("select_connection_target", %{"code" => code}, socket) do
    {:noreply, assign(socket, connection_search: code, connection_suggestions: [])}
  end

  def handle_event("create_step_connection", %{"target_code" => target_code}, socket) do
    if Policy.authorized?(:edit_step, socket.assigns.current_user, socket.assigns.drawer_item) do
      do_create_step_connection(socket, target_code)
    else
      {:noreply, socket}
    end
  end

  def handle_event(
        "delete_step_connection",
        %{"source" => source_code, "target" => target_code},
        socket
      ) do
    if Policy.authorized?(:edit_step, socket.assigns.current_user, socket.assigns.drawer_item) do
      connection = ConnectionQuery.get_by(source_code: source_code, target_code: target_code)

      if is_nil(connection) do
        {:noreply, put_flash(socket, :error, "Conexão não encontrada")}
      else
        {:ok, _} = Admin.delete_connection(connection.id)

        {:noreply,
         socket |> reopen_step_drawer(socket.assigns.drawer_item.code) |> reload_sections()}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("create_section", %{"section" => params}, socket) do
    if Policy.authorized?(:manage_section, socket.assigns.current_user, nil) do
      max_pos = socket.assigns.sections |> Enum.map(& &1.position) |> Enum.max(fn -> 0 end)

      case Admin.create_section(Map.put(params, "position", max_pos + 1)) do
        {:ok, _} -> {:noreply, socket |> reload_sections() |> put_flash(:info, "Seção criada")}
        {:error, _} -> {:noreply, put_flash(socket, :error, "Erro ao criar seção")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("create_category", %{"category" => params}, socket) do
    if Policy.authorized?(:manage_section, socket.assigns.current_user, nil) do
      case Admin.create_category(params) do
        {:ok, _} ->
          categories = Encyclopedia.list_categories()

          {:noreply,
           socket
           |> assign(categories: categories, filters_open?: true)
           |> put_flash(:info, "Categoria criada")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Erro ao criar categoria")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("toggle_suggest", _params, socket) do
    {:noreply,
     assign(socket,
       suggest_mode: not socket.assigns.suggest_mode,
       suggest_section_id: socket.assigns.suggest_section_id || socket.assigns.active_section_id
     )}
  end

  def handle_event("create_suggested_step", %{"step" => step_params}, socket) do
    user = socket.assigns.current_user

    # Auto-fill category from selected section
    attrs =
      step_params
      |> Map.put("suggested_by_id", user.id)
      |> maybe_fill_category_from_section(socket.assigns.sections)

    case Admin.create_step(attrs) do
      {:ok, step} ->
        {:noreply,
         socket
         |> reload_sections()
         |> assign(
           suggest_mode: false,
           suggest_form: %{},
           suggest_error: nil,
           drawer_open: false,
           drawer_type: nil,
           drawer_item: nil
         )
         |> put_flash(:info, "Passo '#{step.name}' sugerido com sucesso!")}

      {:error, changeset} ->
        error_msg = format_changeset_errors(changeset)
        {:noreply, assign(socket, suggest_error: error_msg)}
    end
  end

  def handle_event("approve_step", %{"code" => code}, socket) do
    if Policy.authorized?(:approve_step, socket.assigns.current_user, socket.assigns.drawer_item) do
      step = StepQuery.get_by(code: code)

      if step do
        Admin.update_step(step, %{approved: true})

        socket =
          socket
          |> reload_sections()
          |> reopen_step_drawer(code)
          |> put_flash(:info, "Passo aprovado!")

        {:noreply, socket}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  # ── Comentários do passo em foco no drawer (assigns expanded_*) ──

  def handle_event("create_comment", %{"body" => body}, socket) do
    user = socket.assigns.current_user
    step_id = socket.assigns.expanded_step

    case Engagement.create_step_comment(user, step_id, %{body: body}) do
      {:ok, _} -> {:noreply, reload_expanded(socket)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Erro ao postar comentário.")}
    end
  end

  def handle_event("create_reply", %{"body" => body, "parent-id" => parent_id}, socket) do
    user = socket.assigns.current_user
    step_id = socket.assigns.expanded_step

    case Engagement.create_step_comment(user, step_id, %{
           body: body,
           parent_step_comment_id: parent_id
         }) do
      {:ok, _} ->
        {:noreply, socket |> reload_expanded() |> assign(:expanded_replying_to, nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao postar resposta.")}
    end
  end

  def handle_event("toggle_comment_like", %{"type" => type, "id" => id}, socket) do
    user = socket.assigns.current_user

    case Engagement.toggle_like(user.id, type, id) do
      {:ok, _} -> {:noreply, reload_expanded(socket)}
      {:error, _} -> {:noreply, socket}
    end
  end

  def handle_event("start_reply", %{"id" => comment_id}, socket) do
    {:noreply, assign(socket, :expanded_replying_to, comment_id)}
  end

  def handle_event("toggle_replies", %{"id" => comment_id}, socket) do
    replies_map = socket.assigns.expanded_replies_map

    if Map.has_key?(replies_map, comment_id) do
      {:noreply, assign(socket, :expanded_replies_map, Map.delete(replies_map, comment_id))}
    else
      replies = Engagement.list_replies(StepCommentQuery, comment_id)
      new_map = Map.put(replies_map, comment_id, replies)
      socket = assign(socket, :expanded_replies_map, new_map)
      {:noreply, reload_expanded_likes(socket)}
    end
  end

  def handle_event("delete_comment", %{"id" => id, "type" => "step_comment"}, socket) do
    with %{} = comment <- Engagement.get_step_comment(id),
         {:ok, _} <- Engagement.delete_step_comment(socket.assigns.current_user, comment) do
      {:noreply, reload_expanded(socket)}
    else
      _ -> {:noreply, put_flash(socket, :error, "Sem permissão.")}
    end
  end

  def handle_event("toggle_link_video", %{"link-id" => link_id}, socket) do
    current = socket.assigns.expanded_video
    {:noreply, assign(socket, :expanded_video, if(current == link_id, do: nil, else: link_id))}
  end

  def handle_event("toggle_link_like", %{"link-id" => link_id}, socket) do
    user_id = socket.assigns.current_user.id

    case Engagement.toggle_like(user_id, "step_link", link_id) do
      {:ok, _} ->
        link_ids = Enum.map(socket.assigns.drawer_links, & &1.id)
        link_likes = Engagement.likes_map(user_id, "step_link", link_ids)

        sorted =
          Enum.sort_by(socket.assigns.drawer_links, fn link ->
            -Map.get(link_likes.counts, link.id, 0)
          end)

        {:noreply, assign(socket, drawer_link_likes: link_likes, drawer_links: sorted)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao registrar like")}
    end
  end

  def handle_event("toggle_step_like", %{"id" => step_id}, socket) do
    user = socket.assigns.current_user

    case Engagement.toggle_like(user.id, "step", step_id) do
      {:ok, _} ->
        {:noreply, socket |> reload_collection_step_likes() |> sync_drawer_engagement(step_id)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_event("toggle_step_favorite", %{"id" => step_id}, socket) do
    user = socket.assigns.current_user

    case Engagement.toggle_favorite(user.id, "step", step_id) do
      {:ok, _} -> {:noreply, sync_drawer_engagement(socket, step_id)}
      {:error, _} -> {:noreply, socket}
    end
  end

  defp reload_expanded(socket), do: StepDrawer.reload_comments(socket)

  defp reload_expanded_likes(socket), do: StepDrawer.reload_comment_likes(socket)

  defp reload_collection_step_likes(socket) do
    sections = socket.assigns.sections

    all_step_ids =
      sections
      |> Enum.flat_map(fn s ->
        Enum.map(s.steps, & &1.id) ++
          Enum.flat_map(s.subsections, fn sub -> Enum.map(sub.steps, & &1.id) end)
      end)

    step_likes = Engagement.likes_map(socket.assigns.current_user.id, "step", all_step_ids)
    assign(socket, :step_likes, step_likes)
  end

  defp maybe_fill_category_from_section(attrs, sections) do
    section_id = attrs["section_id"]

    if section_id && section_id != "" do
      section = Enum.find(sections, &(&1.id == section_id))

      if section && section.category_id do
        Map.put(attrs, "category_id", section.category_id)
      else
        attrs
      end
    else
      attrs
    end
  end

  defp do_create_step_connection(socket, target_code) do
    step = socket.assigns.drawer_item
    target = StepQuery.get_by(code: target_code)

    if is_nil(target) do
      {:noreply, put_flash(socket, :error, "Passo não encontrado")}
    else
      case Admin.create_connection(%{source_step_id: step.id, target_step_id: target.id}) do
        {:ok, _} ->
          {:noreply,
           socket |> reopen_step_drawer(step.code) |> put_flash(:info, "Conexão criada")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Conexão já existe")}
      end
    end
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map_join(" · ", fn
      {:code, ["has already been taken"]} -> "Esse código já existe. Escolha outro."
      {:code, msgs} -> "Código: #{Enum.join(msgs, ", ")}"
      {:name, msgs} -> "Nome: #{Enum.join(msgs, ", ")}"
      {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}"
    end)
  end

  defp reload_sections(socket) do
    sections = Encyclopedia.list_sections_with_steps(admin: socket.assigns.is_admin)

    active_section_card =
      if socket.assigns.active_section_id do
        CollectionBrowser.section_details(sections, socket.assigns.active_section_id)
      end

    open =
      Map.new(sections, fn s -> {s.id, Map.get(socket.assigns.open_sections, s.id, false)} end)

    assign(socket,
      sections: sections,
      collection_cards: CollectionBrowser.build_sections(sections),
      open_sections: open,
      active_section_card: active_section_card
    )
  end

  defp reopen_step_drawer(socket, code) do
    case Encyclopedia.fetch_step_with_details(code, admin: socket.assigns.is_admin) do
      {:ok, _} -> load_drawer_step(socket, code)
      _ -> assign(socket, drawer_open: false)
    end
  end

  # Carrega o detalhe do passo no drawer (passo + conexões, links/likes e
  # comentários). Fonte única em StepDrawer, compartilhada com a GraphVisualLive.
  defp load_drawer_step(socket, code), do: StepDrawer.load_step(socket, code)

  defp sync_drawer_engagement(socket, step_id), do: StepDrawer.sync_engagement(socket, step_id)

  defp find_step_context(sections, step_code) do
    Enum.find_value(sections, :error, fn section ->
      visible_steps = section.steps ++ Enum.flat_map(section.subsections, & &1.steps)

      if Enum.any?(visible_steps, &(&1.code == step_code)) do
        {:ok, section.id}
      end
    end)
  end

  def filtered_sections(sections, "all") do
    sections
    |> Enum.reject(&conventions_section?/1)
    |> Kernel.++(Enum.filter(sections, &conventions_section?/1))
  end

  def filtered_sections(sections, category) do
    Enum.filter(sections, fn s ->
      s.category != nil and s.category.name == category
    end)
  end

  def filtered_collection_cards(cards, "all") do
    cards
    |> Enum.reject(&conventions_card?/1)
  end

  def filtered_collection_cards(cards, category) do
    Enum.filter(cards, fn card -> card.category_name == category end)
  end

  defp conventions_section?(%{title: "Convenções da Notação"}), do: true
  defp conventions_section?(_), do: false

  defp conventions_card?(%{title: "Convenções da Notação"}), do: true
  defp conventions_card?(_), do: false

  def total_steps(sections) do
    Enum.reduce(sections, 0, fn s, acc ->
      sub_total = Enum.reduce(s.subsections, 0, fn sub, n -> n + length(sub.steps) end)
      acc + length(s.steps) + sub_total
    end)
  end
end
