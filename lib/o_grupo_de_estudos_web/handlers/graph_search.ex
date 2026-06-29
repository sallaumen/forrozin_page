defmodule OGrupoDeEstudosWeb.Handlers.GraphSearch do
  @moduledoc """
  Macro com os handlers de busca de passos no grafo da GraphVisualLive.

  Uso: `use OGrupoDeEstudosWeb.Handlers.GraphSearch`

  Requer os assigns: `:graph_search_query`, `:graph_search_results` e
  `:graph_search_nodes` (lista de nós visíveis, lida na busca). Empurra
  "focus_graph_node" / "clear_graph_focus" para o hook Cytoscape.
  """

  defmacro __using__(_opts) do
    quote do
      alias OGrupoDeEstudosWeb.GraphVisual.GraphData
      alias OGrupoDeEstudosWeb.StepDrawer

      def handle_event("search_graph_step", %{"value" => term}, socket) do
        term = String.trim(term)

        results =
          if String.length(term) >= 1 do
            GraphData.search_graph_nodes(socket.assigns.graph_search_nodes, term)
          else
            []
          end

        {:noreply,
         socket
         |> assign(:graph_search_query, term)
         |> assign(:graph_search_results, results)}
      end

      def handle_event("select_graph_step", %{"code" => code}, socket) do
        label =
          case Enum.find(socket.assigns.graph_search_nodes, &(&1.code == code)) do
            nil -> code
            step -> "#{step.code} · #{step.name}"
          end

        {:noreply,
         socket
         |> assign(:graph_search_query, label)
         |> assign(:graph_search_results, [])
         |> assign(:drawer_open, true)
         |> StepDrawer.load_step(code)
         |> push_event("focus_graph_node", %{code: code, close_journey: false})}
      end

      def handle_event("clear_graph_search", _params, socket) do
        {:noreply,
         socket
         |> assign(:graph_search_query, "")
         |> assign(:graph_search_results, [])
         |> assign(drawer_open: false, drawer_item: nil)
         |> push_event("clear_graph_focus", %{})}
      end
    end
  end
end
