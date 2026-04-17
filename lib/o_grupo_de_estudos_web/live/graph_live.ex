defmodule OGrupoDeEstudosWeb.GraphLive do
  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.{Accounts, Admin, Admin.Backup, Encyclopedia}
  alias OGrupoDeEstudos.Encyclopedia.StepQuery

  on_mount {OGrupoDeEstudosWeb.UserAuth, :ensure_admin}
  on_mount {OGrupoDeEstudosWeb.Navigation, :detail}

  import OGrupoDeEstudosWeb.UI.TopNav

  @impl true
  def mount(_params, _session, socket) do
    graph = Encyclopedia.build_graph()

    {:ok,
     socket
     |> assign(:is_admin, Accounts.admin?(socket.assigns.current_user))
     |> assign(:source_search, "")
     |> assign(:source_results, [])
     |> assign(:source_selected, nil)
     |> assign(:target_search, "")
     |> assign(:target_results, [])
     |> assign(:target_selected, nil)
     |> assign(:connection_label, "")
     |> assign(:connection_filter, "")
     |> assign(:last_backup, nil)
     |> assign(:page_title, "Mapa de Passos")
     |> load_graph(graph)}
  end

  @impl true
  def handle_event("search_source", params, socket) do
    term = params["value"] || params["term"] || ""

    results =
      if String.length(term) >= 1 do
        StepQuery.list_by(search: term, order_by: [asc: :code], limit: 8, preload: [:category])
      else
        []
      end

    {:noreply, assign(socket, source_search: term, source_results: results)}
  end

  def handle_event("select_source", %{"id" => id, "code" => code, "name" => name}, socket) do
    {:noreply,
     assign(socket, source_selected: %{id: id, code: code, name: name}, source_search: "", source_results: [])}
  end

  def handle_event("clear_source", _params, socket) do
    {:noreply, assign(socket, source_selected: nil, source_search: "", source_results: [])}
  end

  def handle_event("search_target", params, socket) do
    term = params["value"] || params["term"] || ""

    results =
      if String.length(term) >= 1 do
        StepQuery.list_by(search: term, order_by: [asc: :code], limit: 8, preload: [:category])
      else
        []
      end

    {:noreply, assign(socket, target_search: term, target_results: results)}
  end

  def handle_event("select_target", %{"id" => id, "code" => code, "name" => name}, socket) do
    {:noreply,
     assign(socket, target_selected: %{id: id, code: code, name: name}, target_search: "", target_results: [])}
  end

  def handle_event("clear_target", _params, socket) do
    {:noreply, assign(socket, target_selected: nil, target_search: "", target_results: [])}
  end

  def handle_event("update_connection_label", %{"label" => label}, socket) do
    {:noreply, assign(socket, :connection_label, label)}
  end

  def handle_event("create_connection", _params, socket) do
    source = socket.assigns.source_selected
    target = socket.assigns.target_selected
    label = nilify(socket.assigns.connection_label)

    if source && target do
      Admin.create_connection(%{
        source_step_id: source.id,
        target_step_id: target.id,
        label: label
      })

      graph = Encyclopedia.build_graph()

      {:noreply,
       socket
       |> assign(source_selected: nil, target_selected: nil, connection_label: "")
       |> load_graph(graph)
       |> put_flash(:info, "Conexão #{source.code} → #{target.code} criada!")}
    else
      {:noreply, put_flash(socket, :error, "Selecione origem e destino")}
    end
  end

  def handle_event("edit_connection_label", %{"connection_id" => id, "label" => label}, socket) do
    if socket.assigns.is_admin do
      Admin.update_connection(id, %{label: nilify(label)})
      graph = Encyclopedia.build_graph()
      {:noreply, load_graph(socket, graph)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("delete_connection", %{"connection_id" => id}, socket) do
    if socket.assigns.is_admin do
      Admin.delete_connection(id)
      graph = Encyclopedia.build_graph()
      {:noreply, load_graph(socket, graph)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("create_backup", _params, socket) do
    if socket.assigns.is_admin do
      path = Backup.create_backup!()
      name = Path.basename(path)
      {:noreply, assign(socket, :last_backup, name)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("filter_connections", params, socket) do
    term = params["value"] || params["term"] || ""
    {:noreply, assign(socket, :connection_filter, term)}
  end

  defp load_graph(socket, %{nodes: nodes, edges: edges}) do
    graph_json =
      Jason.encode!(%{
        nodes: Enum.map(nodes, fn p -> %{id: p.code, nome: p.name} end),
        edges:
          Enum.map(edges, fn c ->
            %{from: c.source_step.code, to: c.target_step.code}
          end)
      })

    sorted_nodes = Enum.sort_by(nodes, & &1.code)
    sorted_edges = Enum.sort_by(edges, fn e -> {e.source_step.code, e.target_step.code} end)

    socket
    |> assign(:nodes, sorted_nodes)
    |> assign(:edges, sorted_edges)
    |> assign(:edges_by_source, Enum.group_by(sorted_edges, & &1.source_step_id))
    |> assign(:graph_json, graph_json)
  end

  defp nilify(""), do: nil
  defp nilify(value), do: value
end
