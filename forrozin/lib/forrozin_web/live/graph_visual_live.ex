defmodule ForrozinWeb.GraphVisualLive do
  use ForrozinWeb, :live_view

  alias Forrozin.{Accounts, Admin, Encyclopedia}
  alias Forrozin.Encyclopedia.{ConnectionQuery, StepQuery}

  on_mount {ForrozinWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    is_admin = Accounts.admin?(socket.assigns.current_user)
    graph = Encyclopedia.build_graph()

    {:ok,
     socket
     |> assign(:page_title, "Mapa de Passos")
     |> assign(:is_admin, is_admin)
     |> assign(:edit_mode, false)
     |> assign_graph_data(graph, false)}
  end

  # ---------------------------------------------------------------------------
  # Events — Admin editing
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("toggle_edit_mode", _params, socket) do
    if not socket.assigns.is_admin do
      {:noreply, socket}
    else
      new_mode = not socket.assigns.edit_mode
      graph = Encyclopedia.build_graph()

      socket =
        socket
        |> assign(:edit_mode, new_mode)
        |> assign_graph_data(graph, new_mode)

      {:noreply,
       push_event(socket, "graph_updated", %{
         graph_json: socket.assigns.graph_json,
         edit_mode: new_mode,
         orphans: if(new_mode, do: build_orphans_json(graph), else: "[]")
       })}
    end
  end

  def handle_event("create_connection", %{"source" => source_code, "target" => target_code}, socket) do
    if not socket.assigns.is_admin do
      {:noreply, socket}
    else
      with source when not is_nil(source) <- StepQuery.get_by(code: source_code),
           target when not is_nil(target) <- StepQuery.get_by(code: target_code),
           {:ok, _conn} <- Admin.create_connection(%{source_step_id: source.id, target_step_id: target.id}) do
        graph = Encyclopedia.build_graph()
        edit_mode = socket.assigns.edit_mode

        socket =
          socket
          |> assign_graph_data(graph, edit_mode)

        {:noreply,
         push_event(socket, "graph_updated", %{
           graph_json: socket.assigns.graph_json,
           edit_mode: edit_mode,
           orphans: if(edit_mode, do: build_orphans_json(graph), else: "[]")
         })}
      else
        {:error, _changeset} ->
          {:noreply, push_event(socket, "graph_error", %{message: "Conexão já existe"})}

        nil ->
          {:noreply, push_event(socket, "graph_error", %{message: "Passo não encontrado"})}
      end
    end
  end

  def handle_event("delete_connection", %{"source" => source_code, "target" => target_code}, socket) do
    if not socket.assigns.is_admin do
      {:noreply, socket}
    else
      connection = ConnectionQuery.get_by(source_code: source_code, target_code: target_code)

      case connection do
        nil ->
          {:noreply, push_event(socket, "graph_error", %{message: "Conexão não encontrada"})}

        conn ->
          {:ok, _} = Admin.delete_connection(conn.id)
          graph = Encyclopedia.build_graph()
          edit_mode = socket.assigns.edit_mode

          socket =
            socket
            |> assign_graph_data(graph, edit_mode)

          {:noreply,
           push_event(socket, "graph_updated", %{
             graph_json: socket.assigns.graph_json,
             edit_mode: edit_mode,
             orphans: if(edit_mode, do: build_orphans_json(graph), else: "[]")
           })}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Graph data helpers
  # ---------------------------------------------------------------------------

  defp assign_graph_data(socket, graph, include_orphans) do
    graph_json = build_json(graph, include_orphans)

    connected_count =
      graph.edges
      |> Enum.flat_map(&[&1.source_step_id, &1.target_step_id])
      |> MapSet.new()
      |> MapSet.size()

    categories =
      graph.nodes
      |> Enum.map(& &1.category)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq_by(& &1.id)
      |> Enum.sort_by(& &1.label)

    socket
    |> assign(:graph_json, graph_json)
    |> assign(:node_count, connected_count)
    |> assign(:edge_count, length(graph.edges))
    |> assign(:categories, categories)
  end

  defp build_json(%{nodes: nodes, edges: edges}, include_orphans) do
    connected_codes =
      edges
      |> Enum.flat_map(fn c -> [c.source_step.code, c.target_step.code] end)
      |> MapSet.new()

    visible_nodes =
      if include_orphans do
        nodes
      else
        Enum.filter(nodes, &MapSet.member?(connected_codes, &1.code))
      end

    Jason.encode!(%{
      nodes:
        Enum.map(visible_nodes, fn p ->
          cat = p.category

          %{
            id: p.code,
            nome: p.name,
            categoria: if(cat, do: cat.label, else: "Outros"),
            categoriaName: if(cat, do: cat.name, else: "outros"),
            cor: if(cat, do: cat.color, else: "#9a7a5a"),
            nota: truncate_note(p.note, 300),
            highlighted: p.highlighted || false,
            suggested: p.suggested_by_id != nil,
            suggested_by_id: p.suggested_by_id,
            orphan: not MapSet.member?(connected_codes, p.code)
          }
        end),
      edges: compute_edge_spread(edges)
    })
  end

  defp build_orphans_json(%{nodes: nodes, edges: edges}) do
    connected_codes =
      edges
      |> Enum.flat_map(fn c -> [c.source_step.code, c.target_step.code] end)
      |> MapSet.new()

    orphans =
      nodes
      |> Enum.reject(&MapSet.member?(connected_codes, &1.code))
      |> Enum.map(fn p ->
        cat = p.category
        %{id: p.code, nome: p.name, categoria: if(cat, do: cat.label, else: "Outros"), cor: if(cat, do: cat.color, else: "#9a7a5a")}
      end)

    Jason.encode!(orphans)
  end

  defp truncate_note(nil, _max), do: nil
  defp truncate_note(text, max) when byte_size(text) <= max, do: text
  defp truncate_note(text, max), do: String.slice(text, 0, max) <> "…"

  defp compute_edge_spread(edges) do
    edges
    |> Enum.group_by(& &1.source_step.code)
    |> Enum.flat_map(fn {_source, group} ->
      count = length(group)

      group
      |> Enum.with_index()
      |> Enum.map(fn {edge, idx} ->
        spread = if count > 2, do: round((idx - (count - 1) / 2) * 20), else: 0

        %{
          from: edge.source_step.code,
          to: edge.target_step.code,
          label: edge.label,
          spread: spread
        }
      end)
    end)
  end
end
