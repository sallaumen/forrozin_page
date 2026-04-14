defmodule ForrozinWeb.CollectionLive do
  @moduledoc """
  Encyclopedia of dance steps.

  Requires authentication. Step wip/draft visibility is controlled
  in the `Encyclopedia` context, never here.
  """

  use ForrozinWeb, :live_view

  import Ecto.Query

  alias Forrozin.{Accounts, Admin, Encyclopedia}
  alias Forrozin.Encyclopedia.{Connection, Section, Step}
  alias Forrozin.Repo

  on_mount {ForrozinWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    admin = Accounts.admin?(socket.assigns.current_user)
    sections = Encyclopedia.list_sections_with_steps(admin: admin)
    categories = Encyclopedia.list_categories()
    open_sections = Map.new(sections, fn s -> {s.id, false} end)

    socket =
      assign(socket,
        sections: sections,
        categories: categories,
        open_sections: open_sections,
        search: "",
        search_results: [],
        category_filter: "all",
        email_confirmed: Accounts.email_confirmed?(socket.assigns.current_user),
        is_admin: admin,
        edit_mode: false,
        page_title: "Acervo",
        drawer_open: false,
        drawer_type: nil,
        drawer_item: nil,
        drawer_connections_out: [],
        drawer_connections_in: [],
        connection_search: "",
        connection_suggestions: []
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

  # ---------------------------------------------------------------------------
  # Edit mode + drawer
  # ---------------------------------------------------------------------------

  def handle_event("toggle_edit_mode", _params, socket) do
    if socket.assigns.is_admin do
      {:noreply, assign(socket, edit_mode: not socket.assigns.edit_mode)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("open_step", %{"code" => code}, socket) do
    case Encyclopedia.get_step_with_details(code, admin: socket.assigns.is_admin) do
      {:ok, step} ->
        out = Repo.all(from c in Connection, where: c.source_step_id == ^step.id, preload: [:target_step])
        inn = Repo.all(from c in Connection, where: c.target_step_id == ^step.id, preload: [:source_step])

        {:noreply,
         assign(socket,
           drawer_open: true,
           drawer_type: :step,
           drawer_item: step,
           drawer_connections_out: out,
           drawer_connections_in: inn
         )}

      {:error, :not_found} ->
        {:noreply, socket}
    end
  end

  def handle_event("open_section", %{"id" => id}, socket) do
    case Repo.get(Section, id) do
      nil ->
        {:noreply, socket}

      section ->
        section = Repo.preload(section, :category)

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
          updated = Repo.preload(updated, [:category, :technical_concepts, connections_as_source: :target_step, connections_as_target: :source_step])

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
          updated = Repo.preload(updated, :category)

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
      term_lower = String.downcase(term)

      suggestions =
        Repo.all(
          from s in Step,
            where: s.status == "published",
            where: fragment("lower(?) LIKE ? OR lower(?) LIKE ?", s.code, ^"%#{term_lower}%", s.name, ^"%#{term_lower}%"),
            order_by: [asc: s.name],
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
      target = Repo.one(from s in Step, where: s.code == ^target_code)

      if is_nil(target) do
        {:noreply, put_flash(socket, :error, "Passo não encontrado")}
      else
        case Admin.create_connection(%{source_step_id: step.id, target_step_id: target.id}) do
          {:ok, _} ->
            {:noreply, socket |> reopen_step_drawer(step.code) |> put_flash(:info, "Conexão criada")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Conexão já existe")}
        end
      end
    end
  end

  def handle_event("delete_step_connection", %{"source" => source_code, "target" => target_code}, socket) do
    if not socket.assigns.is_admin do
      {:noreply, socket}
    else
      connection =
        Repo.one(
          from c in Connection,
            join: s in Step, on: c.source_step_id == s.id,
            join: t in Step, on: c.target_step_id == t.id,
            where: s.code == ^source_code and t.code == ^target_code
        )

      if is_nil(connection) do
        {:noreply, put_flash(socket, :error, "Conexão não encontrada")}
      else
        {:ok, _} = Admin.delete_connection(connection.id)
        {:noreply, socket |> reopen_step_drawer(socket.assigns.drawer_item.code) |> reload_sections()}
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
          {:noreply, socket |> assign(:categories, categories) |> put_flash(:info, "Categoria criada")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Erro ao criar categoria")}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp reload_sections(socket) do
    sections = Encyclopedia.list_sections_with_steps(admin: socket.assigns.is_admin)
    open = Map.new(sections, fn s -> {s.id, Map.get(socket.assigns.open_sections, s.id, false)} end)
    assign(socket, sections: sections, open_sections: open)
  end

  defp reopen_step_drawer(socket, code) do
    case Encyclopedia.get_step_with_details(code, admin: socket.assigns.is_admin) do
      {:ok, step} ->
        out = Repo.all(from c in Connection, where: c.source_step_id == ^step.id, preload: [:target_step])
        inn = Repo.all(from c in Connection, where: c.target_step_id == ^step.id, preload: [:source_step])
        assign(socket, drawer_item: step, drawer_connections_out: out, drawer_connections_in: inn)

      _ ->
        assign(socket, drawer_open: false)
    end
  end

  # ---------------------------------------------------------------------------
  # Components
  # ---------------------------------------------------------------------------

  attr :section, :map, required: true
  attr :open, :boolean, required: true
  attr :edit_mode, :boolean, default: false

  def section_card(assigns) do
    ~H"""
    <div
      class="mb-2 rounded overflow-hidden"
      style={"border: 1px solid #{if @open, do: "rgba(60,40,20,0.2)", else: "rgba(60,40,20,0.1)"}; background: #{if @open, do: "#fffef9", else: "#fdfcf7"}"}
    >
      <div class="flex items-center">
        <button
          phx-click="toggle_section"
          phx-value-section_id={@section.id}
          class="flex-1 text-left flex items-center gap-3 px-5 py-3"
          style="background: transparent; border: none; cursor: pointer;"
        >
          <span style={"color: #{category_color(@section)}; font-size: 10px; display: inline-block; transform: #{if @open, do: "rotate(90deg)", else: "rotate(0deg)"}; transition: transform 0.15s;"}>
            ▶
          </span>
        <span class="flex items-center gap-3 flex-wrap flex-1">
          <%= if @section.num do %>
            <span style="font-size: 11px; color: #aaa; font-family: Georgia, serif; font-style: italic;">
              {@section.num}.
            </span>
          <% end %>
          <%= if @section.code do %>
            <code style={"font-size: 11px; color: #{category_color(@section)}; background: #{category_color(@section)}15; padding: 2px 8px; border-radius: 3px; border: 1px solid #{category_color(@section)}30; letter-spacing: 0.5px;"}>
              {@section.code}
            </code>
          <% end %>
          <span style="font-size: 15px; font-weight: 700; color: #1a0e05; font-family: Georgia, serif; letter-spacing: -0.2px;">
            {@section.title}
          </span>
          <span style={"font-size: 10px; color: #{category_color(@section)}; background: #{category_color(@section)}15; padding: 1px 8px; border-radius: 10px; font-family: Georgia, serif; font-style: italic; border: 1px solid #{category_color(@section)}25;"}>
            {category_label(@section)}
          </span>
        </span>
        </button>
        <%= if @edit_mode do %>
          <button phx-click="open_section" phx-value-id={@section.id} style="padding: 6px 12px; background: none; border: none; cursor: pointer; color: #9a7a5a; font-size: 12px;">✏</button>
        <% end %>
      </div>
      <%= if @open do %>
        <div style="padding: 4px 24px 20px 54px;">
          <%= if @section.description do %>
            <p style="font-size: 13px; color: #7a5c3a; font-style: italic; margin-bottom: 12px; line-height: 1.7; font-family: Georgia, serif;">
              {@section.description}
            </p>
          <% end %>
          <%= if @section.note do %>
            <div style="font-size: 12px; color: #5c3a1a; background: rgba(212,160,84,0.1); border: 1px solid rgba(212,160,84,0.3); border-left: 3px solid #d4a054; border-radius: 0 4px 4px 0; padding: 8px 14px; margin: 0 0 14px; font-family: Georgia, serif; font-style: italic; line-height: 1.7;">
              {@section.note}
            </div>
          <% end %>
          <%= for step <- @section.steps do %>
            <.step_item step={step} />
          <% end %>
          <%= for subsection <- @section.subsections do %>
            <div style="margin-top: 16px;">
              <div style="font-size: 10px; font-weight: 700; color: #9a7a5a; font-family: Georgia, serif; text-transform: uppercase; letter-spacing: 2px; margin-bottom: 10px; padding-bottom: 6px; border-bottom: 1px solid rgba(60,40,20,0.1);">
                {subsection.title}
              </div>
              <%= if subsection.note do %>
                <p style="font-size: 12px; color: #7a5c3a; font-style: italic; margin-bottom: 10px; font-family: Georgia, serif;">
                  {subsection.note}
                </p>
              <% end %>
              <%= for step <- subsection.steps do %>
                <.step_item step={step} />
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  attr :step, :map, required: true

  def step_item(assigns) do
    ~H"""
    <div
      phx-click="open_step"
      phx-value-code={@step.code}
      style="display: flex; gap: 14px; padding: 12px 0; border-bottom: 1px solid rgba(60,40,20,0.12); cursor: pointer;"
    >
      <%= if @step.image_path do %>
        <img
          src={"/#{@step.image_path}"}
          alt={@step.code}
          loading="lazy"
          style="width: 72px; height: 72px; object-fit: cover; border-radius: 4px; flex-shrink: 0; border: 1px solid rgba(60,40,20,0.15); filter: sepia(20%);"
        />
      <% end %>
      <div style="flex: 1;">
        <div style="display: flex; align-items: baseline; gap: 10px; flex-wrap: wrap;">
          <code style="font-family: 'Courier New', monospace; font-size: 12px; font-weight: 700; color: #5c3a1a; background: rgba(180,120,40,0.1); padding: 2px 7px; border-radius: 3px; letter-spacing: 0.5px; border: 1px solid rgba(180,120,40,0.2);">
            {@step.code}
          </code>
          <span style="font-size: 14px; color: #2c1a0e; font-family: Georgia, serif; line-height: 1.5;">
            {@step.name}
          </span>
        </div>
        <%= if @step.note do %>
          <p style="font-size: 12px; color: #7a5c3a; margin: 5px 0 0; font-family: Georgia, serif; font-style: italic; line-height: 1.6;">
            {String.slice(@step.note, 0, 120)}{if String.length(@step.note) > 120, do: "…"}
          </p>
        <% end %>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Public helpers (used in template)
  # ---------------------------------------------------------------------------

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
