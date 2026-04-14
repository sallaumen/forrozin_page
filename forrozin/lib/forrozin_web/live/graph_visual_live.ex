defmodule ForrozinWeb.GraphVisualLive do
  use ForrozinWeb, :live_view

  alias Forrozin.{Accounts, Encyclopedia}

  on_mount {ForrozinWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    graph = Encyclopedia.build_graph()
    graph_json = build_json(graph)

    connected_count =
      graph.edges
      |> Enum.flat_map(&[&1.source_step_id, &1.target_step_id])
      |> MapSet.new()
      |> MapSet.size()

    {:ok,
     socket
     |> assign(:page_title, "Mapa de Passos")
     |> assign(:graph_json, graph_json)
     |> assign(:node_count, connected_count)
     |> assign(:edge_count, length(graph.edges))
     |> assign(:is_admin, Accounts.admin?(socket.assigns.current_user))}
  end

  defp build_json(%{nodes: nodes, edges: edges}) do
    connected_codes =
      edges
      |> Enum.flat_map(fn c -> [c.source_step.code, c.target_step.code] end)
      |> MapSet.new()

    connected_nodes = Enum.filter(nodes, &MapSet.member?(connected_codes, &1.code))

    Jason.encode!(%{
      nodes:
        Enum.map(connected_nodes, fn p ->
          %{
            id: p.code,
            nome: p.name,
            categoria: p.category.label,
            cor: p.category.color
          }
        end),
      edges:
        Enum.map(edges, fn c ->
          %{from: c.source_step.code, to: c.target_step.code, label: c.label}
        end)
    })
  end
end
