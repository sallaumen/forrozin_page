defmodule OGrupoDeEstudosWeb.CollectionLive do
  @moduledoc """
  Encyclopedia of dance steps.

  Requires authentication. Step wip/draft visibility is controlled
  in the `Encyclopedia` context, never here.
  """

  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.{Accounts, Admin, Encyclopedia, Engagement, Study, Workshops}
  alias OGrupoDeEstudos.Authorization.Policy
  alias OGrupoDeEstudos.Encyclopedia.CollectionBrowser
  alias OGrupoDeEstudosWeb.{ChangesetErrors, InlineEditParams, StepDrawer}

  on_mount {OGrupoDeEstudosWeb.Navigation, :primary}
  on_mount {OGrupoDeEstudosWeb.Hooks.NotificationSubscriber, :default}
  on_mount {OGrupoDeEstudosWeb.Hooks.SocialBubble, :default}

  import OGrupoDeEstudosWeb.UI.TopNav
  import OGrupoDeEstudosWeb.UI.BottomNav
  import OGrupoDeEstudosWeb.CollectionComponents
  import OGrupoDeEstudosWeb.CoreComponents, only: [flash: 1, icon: 1]
  import OGrupoDeEstudosWeb.StepDetail, only: [step_detail: 1]
  import OGrupoDeEstudosWeb.UI.InlineEdit, only: [editable: 1]
  import OGrupoDeEstudosWeb.UI.PWAInstallBanner
  import OGrupoDeEstudosWeb.UI.SocialBubble

  use OGrupoDeEstudosWeb.NotificationHandlers
  use OGrupoDeEstudosWeb.Handlers.FollowHandlers
  use OGrupoDeEstudosWeb.Handlers.StepLearning
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

  # Iron Law: the heavy collection queries run only on the connected render. The
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
        steps_with_links: Encyclopedia.step_ids_with_links(),
        steps_seen_in_class: steps_seen_in_class(socket.assigns.current_user.id),
        learned_step_ids: Engagement.learned_step_ids(socket.assigns.current_user.id),
        following_user_ids: Engagement.following_ids(socket.assigns.current_user.id)
      )
    else
      socket
    end
  end

  defp steps_seen_in_class(user_id) do
    MapSet.union(Workshops.step_ids_seen_by(user_id), Study.step_ids_seen_by(user_id))
  end

  defp initial_assigns(admin) do
    [
      is_admin: admin,
      loaded?: false,
      sections: [],
      collection_cards: [],
      categories: [],
      steps_with_links: MapSet.new(),
      steps_seen_in_class: MapSet.new(),
      learned_step_ids: MapSet.new(),
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
      active_tab: "collection",
      my_steps: [],
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
      suggest_section_id: nil,
      editing_field: nil,
      edit_error: nil
    ]
  end

  @doc """
  Where the person is in the acervo, written as an address.

  Only what answers "where are you?" goes in: the family, the step whose detail
  is open, the tab, and the category being filtered. The search term and the
  edit mode stay in the socket, because they say how the page is being used and
  not which page it is, and because a history entry per keystroke would make
  going back useless.

  A default is not worth writing down, so the acervo tab and the unfiltered
  category leave no trace in the address.
  """
  @spec collection_path(keyword()) :: String.t()
  def collection_path(place) do
    query =
      [
        section: place[:section],
        step: place[:step],
        detail: place[:detail],
        tab: tab_param(place[:tab]),
        category: place[:category]
      ]
      |> Enum.reject(&default_place?/1)

    case query do
      [] -> ~p"/collection"
      query -> ~p"/collection?#{query}"
    end
  end

  defp tab_param("my_steps"), do: "my-steps"
  defp tab_param(_acervo), do: nil

  defp default_place?({_key, value}) when value in [nil, ""], do: true
  defp default_place?({:category, "all"}), do: true
  defp default_place?(_written_down), do: false

  # The address is the single source of truth for where the person is. Every
  # state below used to be an assign changed by a click, which handed the
  # browser no history entry: the back gesture skipped the whole acervo and left
  # the site.
  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:category_filter, params["category"] || "all")
     |> apply_tab(params["tab"])
     |> apply_family(params)
     |> apply_detail(params["detail"])}
  end

  defp apply_tab(socket, "my-steps") do
    socket
    |> assign(:active_tab, "my_steps")
    |> load_my_steps()
  end

  defp apply_tab(socket, _acervo), do: assign(socket, :active_tab, "collection")

  defp load_my_steps(%{assigns: %{loaded?: false}} = socket), do: socket

  defp load_my_steps(socket) do
    assign(socket, :my_steps, Encyclopedia.list_user_steps(socket.assigns.current_user.id))
  end

  # `?step=CODE` is the link people copy: it opens the family the step lives in
  # and marks the row. `?section=ID` is the family opened from the mosaic.
  defp apply_family(socket, %{"step" => code}) when is_binary(code) and code != "" do
    case find_step_context(socket.assigns.sections, code) do
      {:ok, section_id} ->
        socket
        |> enter_family(section_id)
        |> assign(search: "", search_results: [], deep_linked_step_code: code)
        |> push_event("scroll-to-element", %{id: "collection-step-#{code}", block: "center"})

      :error ->
        assign(socket, :deep_linked_step_code, nil)
    end
  end

  defp apply_family(socket, %{"section" => id}) when is_binary(id) and id != "" do
    socket
    |> assign(:deep_linked_step_code, nil)
    |> enter_family(id)
  end

  defp apply_family(socket, _mosaic) do
    assign(socket,
      active_section_id: nil,
      active_section_card: nil,
      suggest_section_id: nil,
      deep_linked_step_code: nil
    )
  end

  defp enter_family(socket, section_id) do
    assign(socket,
      active_section_id: section_id,
      active_section_card: CollectionBrowser.section_details(socket.assigns.sections, section_id),
      suggest_section_id: section_id
    )
  end

  # The drawer is a full screen on the phone, so it is a place like any other.
  defp apply_detail(socket, code) when is_binary(code) and code != "" do
    if drawer_showing?(socket, code), do: socket, else: open_step_drawer(socket, code)
  end

  defp apply_detail(socket, _closed) do
    assign(socket, drawer_open: false, drawer_type: nil, drawer_item: nil)
  end

  defp drawer_showing?(socket, code) do
    match?(%{drawer_open: true, drawer_type: :step, drawer_item: %{code: ^code}}, socket.assigns)
  end

  defp open_step_drawer(socket, code) do
    case Encyclopedia.fetch_step_with_details(code, admin: socket.assigns.is_admin) do
      {:ok, _step} ->
        socket
        |> assign(drawer_open: true, drawer_type: :step)
        |> load_drawer_step(code)

      {:error, :not_found} ->
        assign(socket, drawer_open: false, drawer_type: nil, drawer_item: nil)
    end
  end

  @impl true
  def handle_event("search", %{"term" => term}, socket) do
    admin = Accounts.admin?(socket.assigns.current_user)
    results = if term == "", do: [], else: Encyclopedia.search_steps(term, admin: admin)
    {:noreply, assign(socket, search: term, search_results: results)}
  end

  def handle_event("toggle_filters", _params, socket) do
    {:noreply, assign(socket, :filters_open?, !socket.assigns.filters_open?)}
  end

  def handle_event("toggle_edit_mode", _params, socket) do
    if Policy.authorized?(:manage_section, socket.assigns.current_user, nil) do
      {:noreply, assign(socket, edit_mode: not socket.assigns.edit_mode)}
    else
      {:noreply, socket}
    end
  end

  # Opening a step is an event and not a link because the drawer needs a round
  # trip to the server anyway (connections, links, comments). The mosaic, the
  # tabs and the filter need nothing, so those are real links.
  def handle_event("open_step", %{"code" => code}, socket) do
    {:noreply, push_patch(socket, to: detail_path(socket, code))}
  end

  def handle_event("copy_step_link", %{"code" => code}, socket) do
    {:noreply,
     socket
     |> push_event("clipboard:copy", %{text: url(~p"/collection?step=#{code}")})
     |> put_flash(:info, "Link copiado")}
  end

  # The pencil writes one field of the open family at a time. Which fields exist
  # is a whitelist in InlineEditParams, never the name that arrived in the event.
  def handle_event("edit_field", %{"field" => field}, socket) do
    {:noreply, open_field(socket, InlineEditParams.section_field(field))}
  end

  def handle_event("cancel_edit", _params, socket), do: {:noreply, close_field(socket)}

  def handle_event("save_field", _params, %{assigns: %{editing_field: nil}} = socket),
    do: {:noreply, socket}

  def handle_event("save_field", params, socket) do
    {:noreply, save_family_field(socket, socket.assigns.editing_field, params)}
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

  def handle_event("search_connection", %{"target_code" => term}, socket) do
    if Policy.authorized?(:edit_step, socket.assigns.current_user, socket.assigns.drawer_item) and
         String.length(term) >= 1 do
      suggestions =
        Encyclopedia.list_steps_by(
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
      connection =
        Encyclopedia.get_connection_by(source_code: source_code, target_code: target_code)

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
      step = Encyclopedia.get_step_by(code: code)

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
      {:ok, _} ->
        {:noreply, reload_expanded(socket)}

      {:error, reason} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           OGrupoDeEstudosWeb.Helpers.EngagementMessages.like_error(reason)
         )}
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
      replies = Engagement.list_step_comment_replies(comment_id)
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
      {:ok, _} ->
        {:noreply, sync_drawer_engagement(socket, step_id)}

      {:error, reason} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           OGrupoDeEstudosWeb.Helpers.EngagementMessages.favorite_error(reason)
         )}
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
    target = Encyclopedia.get_step_by(code: target_code)

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

    assign(socket,
      sections: sections,
      collection_cards: CollectionBrowser.build_sections(sections),
      active_section_card: active_section_card
    )
  end

  defp reopen_step_drawer(socket, code) do
    case Encyclopedia.fetch_step_with_details(code, admin: socket.assigns.is_admin) do
      {:ok, _} -> load_drawer_step(socket, code)
      _ -> assign(socket, drawer_open: false)
    end
  end

  # Loads the step detail for the drawer (step plus connections, links, likes and
  # comments). Single source in StepDrawer, shared with GraphVisualLive.
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

  defp detail_path(socket, code) do
    collection_path(
      section: socket.assigns.active_section_id,
      detail: code,
      tab: socket.assigns.active_tab,
      category: socket.assigns.category_filter
    )
  end

  def total_steps(sections) do
    Enum.reduce(sections, 0, fn s, acc ->
      sub_total = Enum.reduce(s.subsections, 0, fn sub, n -> n + length(sub.steps) end)
      acc + length(s.steps) + sub_total
    end)
  end

  @doc """
  Whether the category is worth saying out loud above the family.

  A family called Caminhadas inside a category called Caminhadas says it twice,
  so the line stays quiet unless the two names differ. Quiet is not the same as
  absent: with the pencil out the category always reads, because that is the
  value being changed.
  """
  def family_category_shown?(%{category_label: label, title: title}),
    do: is_binary(label) and label != "" and label != title

  @doc "The category the family belongs to, said plainly."
  def family_category_text(%{category_label: label}) when is_binary(label) and label != "",
    do: label

  def family_category_text(_uncategorized), do: "sem categoria"

  def family_description_text(%{description: text}) when is_binary(text) and text != "", do: text
  def family_description_text(_blank), do: "Escreva a descrição desta família."

  def family_note_text(%{note: text}) when is_binary(text) and text != "", do: text
  def family_note_text(_blank), do: "Escreva a nota desta família."

  @doc "The categories that exist, plus the option of belonging to none."
  def category_options(categories) do
    [{"Sem categoria", ""} | Enum.map(categories, &{&1.label, &1.id})]
  end

  defp open_field(socket, nil), do: socket

  defp open_field(socket, field) do
    if Policy.authorized?(:manage_section, socket.assigns.current_user, nil) do
      socket |> assign(:editing_field, field) |> assign(:edit_error, nil)
    else
      socket
    end
  end

  defp close_field(socket), do: socket |> assign(:editing_field, nil) |> assign(:edit_error, nil)

  defp save_family_field(socket, field, params) do
    card = socket.assigns.active_section_card
    section = Encyclopedia.get_section_by(id: card.id)

    case authorized_update(socket.assigns.current_user, section, field, params) do
      {:ok, _updated} -> socket |> close_field() |> reload_sections()
      {:error, %Ecto.Changeset{} = changeset} -> assign_edit_error(socket, changeset)
      {:error, _unauthorized} -> close_field(socket)
    end
  end

  defp authorized_update(user, section, field, params) do
    case Policy.authorize(:manage_section, user, section) do
      :ok -> Admin.update_section(section, InlineEditParams.attrs(section, field, params))
      {:error, reason} -> {:error, reason}
    end
  end

  defp assign_edit_error(socket, changeset) do
    assign(socket, :edit_error, ChangesetErrors.first_message(changeset))
  end
end
