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

    categories =
      graph.nodes
      |> Enum.map(& &1.category)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq_by(& &1.id)
      |> Enum.sort_by(& &1.label)

    {:ok,
     socket
     |> assign(:page_title, "Mapa de Passos")
     |> assign(:graph_json, graph_json)
     |> assign(:node_count, connected_count)
     |> assign(:edge_count, length(graph.edges))
     |> assign(:categories, categories)
     |> assign(:is_admin, Accounts.admin?(socket.assigns.current_user))}
  end

  # ---------------------------------------------------------------------------
  # JSON building
  # ---------------------------------------------------------------------------

  defp build_json(%{nodes: nodes, edges: edges}) do
    connected_codes =
      edges
      |> Enum.flat_map(fn c -> [c.source_step.code, c.target_step.code] end)
      |> MapSet.new()

    connected_nodes = Enum.filter(nodes, &MapSet.member?(connected_codes, &1.code))

    Jason.encode!(%{
      nodes:
        Enum.map(connected_nodes, fn p ->
          cat = p.category

          %{
            id: p.code,
            nome: p.name,
            categoria: if(cat, do: cat.label, else: "Outros"),
            categoriaName: if(cat, do: cat.name, else: "outros"),
            cor: if(cat, do: cat.color, else: "#9a7a5a"),
            nota: truncate_note(p.note, 300)
          }
        end),
      edges: compute_edge_spread(edges)
    })
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
