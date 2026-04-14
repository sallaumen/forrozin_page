defmodule ForrozinWeb.GraphLive do
  use ForrozinWeb, :live_view

  alias Forrozin.{Accounts, Admin, Admin.Backup, Encyclopedia}

  on_mount {ForrozinWeb.UserAuth, :ensure_admin}

  @impl true
  def mount(_params, _session, socket) do
    graph = Encyclopedia.build_graph()

    {:ok,
     socket
     |> assign(:is_admin, Accounts.admin?(socket.assigns.current_user))
     |> assign(:edit_mode, false)
     |> assign(:sources, MapSet.new())
     |> assign(:targets, MapSet.new())
     |> assign(:last_backup, nil)
     |> assign(:connection_label, "")
     |> assign(:page_title, "Grafo de Passos")
     |> load_graph(graph)}
  end

  @impl true
  def handle_event("toggle_edit_mode", _params, socket) do
    if socket.assigns.is_admin do
      {:noreply,
       socket
       |> update(:edit_mode, &(!&1))
       |> assign(:sources, MapSet.new())
       |> assign(:targets, MapSet.new())}
    else
      {:noreply, socket}
    end
  end

  def handle_event("select_source", %{"step_id" => id}, socket) do
    if socket.assigns.is_admin do
      {:noreply, update(socket, :sources, &toggle_selection(&1, id))}
    else
      {:noreply, socket}
    end
  end

  def handle_event("select_target", %{"step_id" => id}, socket) do
    if socket.assigns.is_admin do
      {:noreply, update(socket, :targets, &toggle_selection(&1, id))}
    else
      {:noreply, socket}
    end
  end

  def handle_event("update_label", %{"label" => label}, socket) do
    {:noreply, assign(socket, :connection_label, label)}
  end

  def handle_event("create_connections", _params, socket) do
    if socket.assigns.is_admin do
      sources = MapSet.to_list(socket.assigns.sources)
      targets = MapSet.to_list(socket.assigns.targets)
      label = nilify(socket.assigns.connection_label)

      for source_id <- sources, target_id <- targets do
        Admin.create_connection(%{
          source_step_id: source_id,
          target_step_id: target_id,
          type: "exit",
          label: label
        })
      end

      graph = Encyclopedia.build_graph()

      {:noreply,
       socket
       |> assign(:sources, MapSet.new())
       |> assign(:targets, MapSet.new())
       |> assign(:connection_label, "")
       |> load_graph(graph)}
    else
      {:noreply, socket}
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

  def handle_event("create_backup", _params, socket) do
    if socket.assigns.is_admin do
      path = Backup.create_backup!()
      name = Path.basename(path)
      {:noreply, assign(socket, :last_backup, name)}
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

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp load_graph(socket, %{nodes: nodes, edges: edges}) do
    graph_json =
      Jason.encode!(%{
        nodes: Enum.map(nodes, fn p -> %{id: p.code, nome: p.name} end),
        edges:
          Enum.map(edges, fn c ->
            %{from: c.source_step.code, to: c.target_step.code, tipo: c.type}
          end)
      })

    socket
    |> assign(:nodes, nodes)
    |> assign(:edges, edges)
    |> assign(:edges_by_source, Enum.group_by(edges, & &1.source_step_id))
    |> assign(:graph_json, graph_json)
  end

  defp toggle_selection(set, id) do
    if MapSet.member?(set, id), do: MapSet.delete(set, id), else: MapSet.put(set, id)
  end

  defp nilify(""), do: nil
  defp nilify(value), do: value
end
