defmodule OGrupoDeEstudosWeb.CollectionLive do
  @moduledoc """
  Encyclopedia of dance steps.

  Requires authentication. Step wip/draft visibility is controlled
  in the `Encyclopedia` context, never here.
  """

  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.{Accounts, Admin, Encyclopedia, Engagement}
  alias OGrupoDeEstudos.Encyclopedia.{ConnectionQuery, SectionQuery, StepLinkQuery, StepQuery}
  alias OGrupoDeEstudos.Engagement.Comments.StepCommentQuery

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
    sections = Encyclopedia.list_sections_with_steps(admin: admin)
    categories = Encyclopedia.list_categories()
    open_sections = Map.new(sections, fn s -> {s.id, false} end)

    steps_with_links = StepLinkQuery.step_ids_with_links()

    all_step_ids =
      sections
      |> Enum.flat_map(fn s ->
        Enum.map(s.steps, & &1.id) ++
          Enum.flat_map(s.subsections, fn sub -> Enum.map(sub.steps, & &1.id) end)
      end)

    step_likes = Engagement.likes_map(socket.assigns.current_user.id, "step", all_step_ids)

    socket =
      assign(socket,
        sections: sections,
        categories: categories,
        open_sections: open_sections,
        search: "",
        search_results: [],
        category_filter: "all",
        is_admin: admin,
        edit_mode: false,
        page_title: "Acervo",
        drawer_open: false,
        drawer_type: nil,
        drawer_item: nil,
        drawer_connections_out: [],
        drawer_connections_in: [],
        drawer_link_count: 0,
        connection_search: "",
        connection_suggestions: [],
        suggest_mode: false,
        can_edit_drawer: false,
        active_tab: "acervo",
        my_steps: [],
        steps_with_links: steps_with_links,
        step_likes: step_likes,
        expanded_step: nil,
        expanded_comments: [],
        expanded_links: [],
        expanded_comment_likes: %{liked_ids: MapSet.new(), counts: %{}},
        expanded_replies_map: %{},
        expanded_replying_to: nil,
        expanded_video: nil,
        step_comment_counts: %{},
        drawer_liked: false,
        drawer_favorited: false
      )

    {:ok, socket}
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
    if socket.assigns.is_admin do
      {:noreply, assign(socket, edit_mode: not socket.assigns.edit_mode)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("open_step", %{"code" => code}, socket) do
    case Encyclopedia.fetch_step_with_details(code, admin: socket.assigns.is_admin) do
      {:ok, _} ->
        step =
          StepQuery.get_by(code: code, preload: [:suggested_by, :category, :technical_concepts])

        out = ConnectionQuery.list_by(source_step_id: step.id, preload: [:target_step])
        inn = ConnectionQuery.list_by(target_step_id: step.id, preload: [:source_step])
        link_count = StepLinkQuery.count_by(step_id: step.id, approved: true)

        user_id = socket.assigns.current_user.id
        can_edit = socket.assigns.edit_mode or step.suggested_by_id == user_id
        drawer_liked = Engagement.liked?(user_id, "step", step.id)
        drawer_favorited = Engagement.favorited?(user_id, "step", step.id)

        {:noreply,
         assign(socket,
           drawer_open: true,
           drawer_type: :step,
           drawer_item: step,
           drawer_connections_out: out,
           drawer_connections_in: inn,
           drawer_link_count: link_count,
           can_edit_drawer: can_edit,
           drawer_liked: drawer_liked,
           drawer_favorited: drawer_favorited
         )}

      {:error, :not_found} ->
        {:noreply, socket}
    end
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

  def handle_event("update_step", %{"step" => params}, socket) do
    if not socket.assigns.is_admin do
      {:noreply, socket}
    else
      step = socket.assigns.drawer_item

      case Admin.update_step(step, params) do
        {:ok, updated} ->
          updated =
            StepQuery.get_by(
              code: updated.code,
              preload: [
                :category,
                :technical_concepts,
                connections_as_source: :target_step,
                connections_as_target: :source_step
              ]
            )

          {:noreply,
           socket
           |> assign(drawer_item: updated)
           |> reload_sections()
           |> put_flash(:info, "Passo atualizado")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Erro ao salvar passo")}
      end
    end
  end

  def handle_event("update_section", %{"section" => params}, socket) do
    if not socket.assigns.is_admin do
      {:noreply, socket}
    else
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
    end
  end

  def handle_event("search_connection", %{"target_code" => term}, socket) do
    if not socket.assigns.is_admin or String.length(term) < 1 do
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

  def handle_event("create_step_connection", %{"target_code" => target_code}, socket) do
    if not socket.assigns.is_admin do
      {:noreply, socket}
    else
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
  end

  def handle_event(
        "delete_step_connection",
        %{"source" => source_code, "target" => target_code},
        socket
      ) do
    if not socket.assigns.is_admin do
      {:noreply, socket}
    else
      connection = ConnectionQuery.get_by(source_code: source_code, target_code: target_code)

      if is_nil(connection) do
        {:noreply, put_flash(socket, :error, "Conexão não encontrada")}
      else
        {:ok, _} = Admin.delete_connection(connection.id)

        {:noreply,
         socket |> reopen_step_drawer(socket.assigns.drawer_item.code) |> reload_sections()}
      end
    end
  end

  def handle_event("create_section", %{"section" => params}, socket) do
    if not socket.assigns.is_admin do
      {:noreply, socket}
    else
      max_pos = socket.assigns.sections |> Enum.map(& &1.position) |> Enum.max(fn -> 0 end)

      case Admin.create_section(Map.put(params, "position", max_pos + 1)) do
        {:ok, _} -> {:noreply, socket |> reload_sections() |> put_flash(:info, "Seção criada")}
        {:error, _} -> {:noreply, put_flash(socket, :error, "Erro ao criar seção")}
      end
    end
  end

  def handle_event("create_category", %{"category" => params}, socket) do
    if not socket.assigns.is_admin do
      {:noreply, socket}
    else
      case Admin.create_category(params) do
        {:ok, _} ->
          categories = Encyclopedia.list_categories()

          {:noreply,
           socket |> assign(:categories, categories) |> put_flash(:info, "Categoria criada")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Erro ao criar categoria")}
      end
    end
  end

  def handle_event("toggle_suggest", _params, socket) do
    {:noreply, assign(socket, suggest_mode: not socket.assigns.suggest_mode)}
  end

  def handle_event("create_suggested_step", %{"step" => params}, socket) do
    user = socket.assigns.current_user
    attrs = Map.put(params, "suggested_by_id", user.id)

    case Admin.create_step(attrs) do
      {:ok, _step} ->
        {:noreply,
         socket
         |> reload_sections()
         |> assign(suggest_mode: false)
         |> put_flash(:info, "Passo sugerido com sucesso!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Erro ao criar passo — verifique os campos")}
    end
  end

  def handle_event("approve_step", %{"code" => code}, socket) do
    if not socket.assigns.is_admin do
      {:noreply, socket}
    else
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
    end
  end

  # ── Inline expansion: comments + links per step ─────────────

  def handle_event("toggle_step_expand", %{"step-id" => step_id}, socket) do
    if socket.assigns.expanded_step == step_id do
      # Collapse
      {:noreply,
       assign(socket,
         expanded_step: nil,
         expanded_comments: [],
         expanded_links: [],
         expanded_comment_likes: %{liked_ids: MapSet.new(), counts: %{}},
         expanded_replies_map: %{},
         expanded_replying_to: nil,
         expanded_video: nil
       )}
    else
      # Expand: lazy-load comments + links
      user = socket.assigns.current_user
      comments = Engagement.list_step_comments(step_id, limit: 5)
      comment_ids = Enum.map(comments, & &1.id)
      comment_likes = Engagement.likes_map(user.id, "step_comment", comment_ids)

      links = StepLinkQuery.list_by(step_id: step_id, approved: true, preload: [:submitted_by])

      {:noreply,
       assign(socket,
         expanded_step: step_id,
         expanded_comments: comments,
         expanded_links: links,
         expanded_comment_likes: comment_likes,
         expanded_replies_map: %{},
         expanded_replying_to: nil,
         expanded_video: nil
       )}
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
    user = socket.assigns.current_user
    alias OGrupoDeEstudos.Engagement.Comments.StepComment
    comment = OGrupoDeEstudos.Repo.get!(StepComment, id)

    case Engagement.delete_step_comment(user, comment) do
      {:ok, _} -> {:noreply, reload_expanded(socket)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Sem permissão.")}
    end
  end

  def handle_event("toggle_expanded_video", %{"link-id" => link_id}, socket) do
    current = socket.assigns.expanded_video
    {:noreply, assign(socket, :expanded_video, if(current == link_id, do: nil, else: link_id))}
  end

  def handle_event("toggle_drawer_like", _params, socket) do
    user = socket.assigns.current_user
    step = socket.assigns.drawer_item

    case Engagement.toggle_like(user.id, "step", step.id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:drawer_liked, Engagement.liked?(user.id, "step", step.id))
         |> reload_collection_step_likes()}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_event("toggle_drawer_favorite", _params, socket) do
    user = socket.assigns.current_user
    step = socket.assigns.drawer_item

    case Engagement.toggle_favorite(user.id, "step", step.id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(
           drawer_liked: Engagement.liked?(user.id, "step", step.id),
           drawer_favorited: Engagement.favorited?(user.id, "step", step.id)
         )
         |> reload_collection_step_likes()}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_event("toggle_step_like", %{"id" => step_id}, socket) do
    user = socket.assigns.current_user

    case Engagement.toggle_like(user.id, "step", step_id) do
      {:ok, _} -> {:noreply, reload_collection_step_likes(socket)}
      {:error, _} -> {:noreply, socket}
    end
  end

  defp reload_expanded(socket) do
    step_id = socket.assigns.expanded_step
    user = socket.assigns.current_user

    comments = Engagement.list_step_comments(step_id, limit: 5)
    comment_ids = Enum.map(comments, & &1.id)

    # Refresh expanded replies from DB (so like_count updates)
    replies_map =
      socket.assigns.expanded_replies_map
      |> Map.keys()
      |> Enum.reduce(%{}, fn parent_id, acc ->
        replies = Engagement.list_replies(StepCommentQuery, parent_id)
        Map.put(acc, parent_id, replies)
      end)

    reply_ids =
      replies_map |> Map.values() |> List.flatten() |> Enum.map(& &1.id)

    all_ids = comment_ids ++ reply_ids
    comment_likes = Engagement.likes_map(user.id, "step_comment", all_ids)

    assign(socket,
      expanded_comments: comments,
      expanded_comment_likes: comment_likes,
      expanded_replies_map: replies_map
    )
  end

  defp reload_expanded_likes(socket) do
    user = socket.assigns.current_user
    comment_ids = Enum.map(socket.assigns.expanded_comments, & &1.id)

    reply_ids =
      socket.assigns.expanded_replies_map
      |> Map.values()
      |> List.flatten()
      |> Enum.map(& &1.id)

    all_ids = comment_ids ++ reply_ids
    comment_likes = Engagement.likes_map(user.id, "step_comment", all_ids)
    assign(socket, :expanded_comment_likes, comment_likes)
  end

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

  defp reload_sections(socket) do
    sections = Encyclopedia.list_sections_with_steps(admin: socket.assigns.is_admin)

    open =
      Map.new(sections, fn s -> {s.id, Map.get(socket.assigns.open_sections, s.id, false)} end)

    assign(socket,
      sections: sections,
      open_sections: open
    )
  end

  defp reopen_step_drawer(socket, code) do
    case Encyclopedia.fetch_step_with_details(code, admin: socket.assigns.is_admin) do
      {:ok, _} ->
        step =
          StepQuery.get_by(code: code, preload: [:suggested_by, :category, :technical_concepts])

        out = ConnectionQuery.list_by(source_step_id: step.id, preload: [:target_step])
        inn = ConnectionQuery.list_by(target_step_id: step.id, preload: [:source_step])
        link_count = StepLinkQuery.count_by(step_id: step.id, approved: true)

        assign(socket,
          drawer_item: step,
          drawer_connections_out: out,
          drawer_connections_in: inn,
          drawer_link_count: link_count
        )

      _ ->
        assign(socket, drawer_open: false)
    end
  end

  attr :section, :map, required: true
  attr :open, :boolean, required: true
  attr :edit_mode, :boolean, default: false
  attr :current_user_id, :string, default: nil
  attr :steps_with_links, :any, default: %MapSet{}
  attr :step_likes, :map, default: %{liked_ids: %MapSet{}, counts: %{}}
  attr :expanded_step, :string, default: nil
  attr :expanded_comments, :list, default: []
  attr :expanded_links, :list, default: []
  attr :expanded_comment_likes, :map, default: %{liked_ids: %MapSet{}, counts: %{}}
  attr :expanded_replies_map, :map, default: %{}
  attr :expanded_replying_to, :string, default: nil
  attr :expanded_video, :string, default: nil
  attr :is_admin, :boolean, default: false
  attr :current_user, :map, default: nil

  def section_card(assigns) do
    ~H"""
    <div class={[
      "mb-2 rounded overflow-hidden border",
      @open && "border-ink-300 bg-ink-50",
      !@open && "border-ink-200/70 bg-ink-100/80"
    ]}>
      <div class="flex items-center">
        <button
          phx-click="toggle_section"
          phx-value-section_id={@section.id}
          class="flex-1 text-left flex items-center gap-3 px-5 py-3 bg-transparent border-0 cursor-pointer"
        >
          <span
            style={"color: #{category_color(@section)};"}
            class={[
              "text-[10px] inline-block transition-transform",
              @open && "rotate-90"
            ]}
          >
            ▶
          </span>
          <span class="flex items-center gap-3 flex-wrap flex-1">
            <%= if @section.num do %>
              <span class="text-[11px] text-ink-400 font-serif italic">
                {@section.num}.
              </span>
            <% end %>
            <%= if @section.code do %>
              <code
                style={"color: #{category_color(@section)}; background: #{category_color(@section)}15; border: 1px solid #{category_color(@section)}30;"}
                class="text-[11px] py-0.5 px-2 rounded-sm tracking-wide"
              >
                {@section.code}
              </code>
            <% end %>
            <span class="text-[15px] font-bold text-ink-900 font-serif -tracking-[0.2px]">
              {@section.title}
            </span>
            <span
              style={"color: #{category_color(@section)}; background: #{category_color(@section)}15; border: 1px solid #{category_color(@section)}25;"}
              class="text-[10px] py-px px-2 rounded-full font-serif italic"
            >
              {category_label(@section)}
            </span>
          </span>
        </button>
        <%= if @edit_mode do %>
          <button
            phx-click="open_section"
            phx-value-id={@section.id}
            class="py-1.5 px-3 bg-transparent border-0 cursor-pointer text-ink-500 text-xs"
          >
            ✏
          </button>
        <% end %>
      </div>
      <%= if @open do %>
        <div class="pt-1 pb-5 pl-[54px] pr-6">
          <%= if @section.description do %>
            <p class="text-sm text-ink-600 italic mb-3 leading-relaxed font-serif">
              {@section.description}
            </p>
          <% end %>
          <%= if @section.note do %>
            <div class="text-xs text-ink-700 bg-gold-500/10 border border-gold-500/30 border-l-[3px] border-l-gold-500 rounded-r py-2 px-3.5 mb-3.5 font-serif italic leading-relaxed">
              {@section.note}
            </div>
          <% end %>
          <%= for step <- @section.steps do %>
            <.step_item
              step={step}
              current_user_id={@current_user_id}
              steps_with_links={@steps_with_links}
              step_likes={@step_likes}
              expanded_step={assigns[:expanded_step]}
              expanded_comments={assigns[:expanded_comments] || []}
              expanded_links={assigns[:expanded_links] || []}
              expanded_comment_likes={assigns[:expanded_comment_likes] || %{liked_ids: MapSet.new(), counts: %{}}}
              expanded_replies_map={assigns[:expanded_replies_map] || %{}}
              expanded_replying_to={assigns[:expanded_replying_to]}
              expanded_video={assigns[:expanded_video]}
              is_admin={assigns[:is_admin] || false}
              current_user={assigns[:current_user]}
            />
          <% end %>
          <%= for subsection <- @section.subsections do %>
            <div class="mt-4">
              <div class="text-[10px] font-bold text-ink-500 font-serif uppercase tracking-widest mb-2.5 pb-1.5 border-b border-ink-200">
                {subsection.title}
              </div>
              <%= if subsection.note do %>
                <p class="text-xs text-ink-600 italic mb-2.5 font-serif">
                  {subsection.note}
                </p>
              <% end %>
              <%= for step <- subsection.steps do %>
                <.step_item
                  step={step}
                  current_user_id={@current_user_id}
                  steps_with_links={@steps_with_links}
                  step_likes={@step_likes}
                />
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  attr :step, :map, required: true
  attr :current_user_id, :string, default: nil
  attr :steps_with_links, :any, default: %MapSet{}
  attr :step_likes, :map, default: %{liked_ids: %MapSet{}, counts: %{}}
  attr :expanded_step, :string, default: nil
  attr :expanded_comments, :list, default: []
  attr :expanded_links, :list, default: []
  attr :expanded_comment_likes, :map, default: %{liked_ids: %MapSet{}, counts: %{}}
  attr :expanded_replies_map, :map, default: %{}
  attr :expanded_replying_to, :string, default: nil
  attr :expanded_video, :string, default: nil
  attr :is_admin, :boolean, default: false
  attr :current_user, :map, default: nil

  def step_item(assigns) do
    has_links = MapSet.member?(assigns.steps_with_links, assigns.step.id)
    is_expanded = assigns.expanded_step == assigns.step.id
    assigns = assign(assigns, has_links: has_links, is_expanded: is_expanded)

    ~H"""
    <% is_mine = @step.suggested_by_id != nil and @step.suggested_by_id == @current_user_id %>
    <div class={[
      "border-b border-ink-200/40 rounded-md mb-0.5",
      is_mine && "bg-[#fce4ec]",
      !is_mine && "bg-transparent"
    ]}>
      <div
        phx-click="open_step"
        phx-value-code={@step.code}
        class="flex gap-3.5 p-3 cursor-pointer"
      >
        <%= if @step.image_path do %>
          <img
            src={"/#{@step.image_path}"}
            alt={@step.code}
            loading="lazy"
            class="w-[72px] h-[72px] object-cover rounded flex-shrink-0 border border-ink-300/60"
            style="filter: sepia(20%);"
          />
        <% end %>
        <div class="flex-1 min-w-0">
          <div class="flex items-baseline gap-2.5 flex-wrap">
            <code class="font-mono text-xs font-bold text-ink-700 bg-[#b4782819] py-0.5 px-1.5 rounded-sm tracking-wide border border-[#b4782833]">
              {@step.code}
            </code>
            <span class="text-sm text-ink-800 font-serif leading-normal">
              {@step.name}
            </span>
            <%= if @step.suggested_by_id do %>
              <.link
                navigate={
                  ~p"/users/#{if @step.suggested_by, do: @step.suggested_by.username, else: "#"}"
                }
                class="no-underline"
              >
                <span
                  class={[
                    "text-[9px] py-px px-1.5 rounded-full italic border",
                    @step.approved && "border-accent-green/30 bg-accent-green/10 text-accent-green",
                    !@step.approved && "border-[#8e44ad4d] bg-[#8e44ad1a]"
                  ]}
                  style={if !@step.approved, do: "color: #8e44ad;"}
                >
                  <%= if @step.approved do %>
                    ✓ @{if @step.suggested_by, do: @step.suggested_by.username, else: "?"}
                  <% else %>
                    Sugestão de @{if @step.suggested_by, do: @step.suggested_by.username, else: "?"}
                  <% end %>
                </span>
              </.link>
            <% end %>
          </div>
          <%= if @step.note do %>
            <p class="text-xs text-ink-600 mt-1 font-serif italic leading-relaxed">
              {String.slice(@step.note, 0, 120)}{if String.length(@step.note) > 120, do: "…"}
            </p>
          <% end %>
        </div>
        <div class="flex flex-col items-center gap-1 flex-shrink-0">
          <%= if @step.suggested_by_id do %>
            <span title="Passo da comunidade" class="text-xs opacity-60">👤</span>
          <% end %>
          <%= if @has_links do %>
            <span title="Tem vídeo" class="text-xs opacity-60">🎬</span>
          <% end %>
          <button
            phx-click="toggle_step_like"
            phx-value-id={@step.id}
            class="flex items-center gap-0.5 p-0.5"
            title={if MapSet.member?(@step_likes.liked_ids, @step.id), do: "Remover curtida", else: "Curtir"}
          >
            <.icon
              name={if MapSet.member?(@step_likes.liked_ids, @step.id), do: "hero-heart-solid", else: "hero-heart"}
              class={[
                "w-4 h-4",
                MapSet.member?(@step_likes.liked_ids, @step.id) && "text-accent-red",
                !MapSet.member?(@step_likes.liked_ids, @step.id) && "text-ink-300 hover:text-accent-red/60"
              ]}
            />
            <span class="text-[10px] tabular-nums text-ink-400">
              {Map.get(@step_likes.counts, @step.id, 0)}
            </span>
          </button>
          <%!-- Expand/collapse — compact icon on the right --%>
          <button
            phx-click="toggle_step_expand"
            phx-value-step-id={@step.id}
            class={[
              "p-1 rounded-full transition-colors",
              @is_expanded && "text-accent-orange bg-accent-orange/10",
              !@is_expanded && "text-ink-400 hover:text-ink-600 hover:bg-ink-100"
            ]}
            title={if @is_expanded, do: "Fechar detalhes", else: "Ver detalhes"}
          >
            <.icon
              name={if @is_expanded, do: "hero-chevron-up-mini", else: "hero-chevron-down-mini"}
              class="w-4 h-4"
            />
          </button>
        </div>
      </div>

      <%!-- Expanded content --%>
      <%= if @is_expanded do %>
        <div class="px-4 pb-4 space-y-4 border-t border-ink-100 pt-3">
          <%!-- Links / Videos --%>
          <%= if @expanded_links != [] do %>
            <div>
              <h4 class="text-xs font-bold text-ink-500 uppercase tracking-wider mb-2">Links</h4>
              <div class="space-y-2">
                <%= for link <- @expanded_links do %>
                  <div class="rounded-lg border border-ink-200 overflow-hidden">
                    <div class="flex items-center gap-2 px-3 py-2">
                      <a href={link.url} target="_blank" rel="noopener"
                        class="flex-1 text-sm text-accent-orange hover:underline truncate no-underline">
                        {link.title || link.url}
                      </a>
                      <%= if youtube_id(link.url) do %>
                        <button
                          phx-click="toggle_expanded_video"
                          phx-value-link-id={link.id}
                          class={[
                            "text-xs py-1 px-2.5 rounded-full font-medium transition-colors",
                            @expanded_video == link.id && "bg-ink-200 text-ink-700",
                            @expanded_video != link.id && "bg-ink-100 text-ink-500 hover:bg-ink-200"
                          ]}
                        >
                          <%= if @expanded_video == link.id, do: "▲ Fechar", else: "▶ Assistir" %>
                        </button>
                      <% end %>
                    </div>
                    <%= if @expanded_video == link.id && youtube_id(link.url) do %>
                      <div class="relative pb-[56.25%] h-0 overflow-hidden bg-ink-900">
                        <iframe
                          src={"https://www.youtube.com/embed/#{youtube_id(link.url)}"}
                          class="absolute top-0 left-0 w-full h-full"
                          frameborder="0"
                          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                          allowfullscreen
                        />
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>

          <%!-- Comments --%>
          <div>
            <h4 class="text-xs font-bold text-ink-500 uppercase tracking-wider mb-2">Comentários</h4>
            <.comment_thread
              comments={@expanded_comments}
              current_user={@current_user}
              likes_map={@expanded_comment_likes}
              comment_type="step_comment"
              parent_id={@step.id}
              replying_to={@expanded_replying_to}
              replies_map={@expanded_replies_map}
              is_admin={@is_admin}
            />
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def filtered_sections(sections, "all"), do: sections

  def filtered_sections(sections, category) do
    Enum.filter(sections, fn s ->
      s.category != nil and s.category.name == category
    end)
  end

  def total_steps(sections) do
    Enum.reduce(sections, 0, fn s, acc ->
      sub_total = Enum.reduce(s.subsections, 0, fn sub, n -> n + length(sub.steps) end)
      acc + length(s.steps) + sub_total
    end)
  end

  def category_color(%{category: %{color: color}}), do: color
  def category_color(_), do: "#7f8c8d"

  def category_label(%{category: %{label: label}}), do: label
  def category_label(_), do: ""

  defp youtube_id(url) when is_binary(url) do
    cond do
      String.contains?(url, "youtube.com/watch") ->
        URI.parse(url) |> Map.get(:query, "") |> URI.decode_query() |> Map.get("v")

      String.contains?(url, "youtu.be/") ->
        URI.parse(url) |> Map.get(:path, "") |> String.trim_leading("/")

      true ->
        nil
    end
  end

  defp youtube_id(_), do: nil
end
