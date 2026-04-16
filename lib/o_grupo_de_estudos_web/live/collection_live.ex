defmodule OGrupoDeEstudosWeb.CollectionLive do
  @moduledoc """
  Encyclopedia of dance steps.

  Requires authentication. Step wip/draft visibility is controlled
  in the `Encyclopedia` context, never here.
  """

  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.{Accounts, Admin, Encyclopedia}
  alias OGrupoDeEstudos.Encyclopedia.{ConnectionQuery, SectionQuery, StepLinkQuery, StepQuery}

  on_mount {OGrupoDeEstudosWeb.UserAuth, :ensure_authenticated}
  on_mount {OGrupoDeEstudosWeb.Navigation, :primary}

  import OGrupoDeEstudosWeb.UI.TopNav
  import OGrupoDeEstudosWeb.UI.BottomNav

  @impl true
  def mount(_params, _session, socket) do
    admin = Accounts.admin?(socket.assigns.current_user)
    sections = Encyclopedia.list_sections_with_steps(admin: admin)
    categories = Encyclopedia.list_categories()
    open_sections = Map.new(sections, fn s -> {s.id, false} end)

    steps_with_links = StepLinkQuery.step_ids_with_links()

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
        steps_with_links: steps_with_links
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

        {:noreply,
         assign(socket,
           drawer_open: true,
           drawer_type: :step,
           drawer_item: step,
           drawer_connections_out: out,
           drawer_connections_in: inn,
           drawer_link_count: link_count,
           can_edit_drawer: can_edit
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

  def step_item(assigns) do
    ~H"""
    <% is_mine = @step.suggested_by_id != nil and @step.suggested_by_id == @current_user_id %>
    <div
      phx-click="open_step"
      phx-value-code={@step.code}
      class={[
        "flex gap-3.5 p-3 border-b border-ink-200/40 cursor-pointer rounded-md mb-0.5",
        is_mine && "bg-[#fce4ec]",
        !is_mine && "bg-transparent"
      ]}
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
      <div class="flex items-center gap-1 flex-shrink-0">
        <%= if @step.suggested_by_id do %>
          <span title="Passo da comunidade" class="text-xs opacity-60">👤</span>
        <% end %>
        <%= if MapSet.member?(@steps_with_links, @step.id) do %>
          <span title="Tem vídeo" class="text-xs opacity-60">🎬</span>
        <% end %>
      </div>
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
end
