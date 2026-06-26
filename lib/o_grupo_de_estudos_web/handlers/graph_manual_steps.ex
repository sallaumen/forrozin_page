defmodule OGrupoDeEstudosWeb.Handlers.GraphManualSteps do
  @moduledoc """
  Macro com os handlers de manipulação de passos do rascunho do construtor
  manual da GraphVisualLive: adicionar (por clique, busca ou seleção), buscar,
  limpar busca, remover e reordenar.

  Uso: `use OGrupoDeEstudosWeb.Handlers.GraphManualSteps`

  Par do `OGrupoDeEstudosWeb.Handlers.GraphManualDraft`. Requer os assigns
  `:seq_manual_steps`, `:seq_manual_search`, `:seq_manual_suggestions`,
  `:seq_manual_error`, `:graph_search_nodes` e os helpers privados do host
  `append_manual_step/2`, `manual_step_suggestions/2`, `find_manual_step/2`,
  `parse_index/1`, `valid_index?/2` e `recompute_manual_missing_edges/2`.
  Empurra "highlight_sequence".
  """

  defmacro __using__(_opts) do
    quote do
      def handle_event("add_manual_step", %{"code" => code, "name" => name}, socket) do
        {:noreply, append_manual_step(socket, %{code: code, name: name})}
      end

      def handle_event("search_manual_step", params, socket) do
        term = String.trim(params["value"] || params["manual_step_search"] || "")
        suggestions = manual_step_suggestions(socket, term)

        {:noreply,
         socket
         |> assign(:seq_manual_search, term)
         |> assign(:seq_manual_suggestions, suggestions)}
      end

      def handle_event("add_manual_step_by_search", params, socket) do
        term = String.trim(params["manual_step_search"] || socket.assigns.seq_manual_search || "")

        case find_manual_step(socket, term) do
          nil ->
            {:noreply,
             socket
             |> assign(:seq_manual_search, term)
             |> assign(:seq_manual_suggestions, manual_step_suggestions(socket, term))
             |> assign(:seq_manual_error, "Escolha um passo da lista para adicionar.")}

          step ->
            {:noreply,
             socket
             |> append_manual_step(step)
             |> assign(:seq_manual_search, "")
             |> assign(:seq_manual_suggestions, [])}
        end
      end

      def handle_event("select_manual_step", %{"code" => code} = params, socket) do
        step =
          case Enum.find(socket.assigns.graph_search_nodes, &(&1.code == code)) do
            nil -> %{code: code, name: params["name"] || code}
            found -> %{code: found.code, name: found.name}
          end

        {:noreply,
         socket
         |> append_manual_step(step)
         |> assign(:seq_manual_search, "")
         |> assign(:seq_manual_suggestions, [])}
      end

      def handle_event("clear_manual_step_search", _params, socket) do
        {:noreply, assign(socket, seq_manual_search: "", seq_manual_suggestions: [])}
      end

      def handle_event("remove_manual_step", %{"index" => index_str}, socket) do
        index = parse_index(index_str)

        if valid_index?(socket.assigns.seq_manual_steps, index) do
          new_steps = List.delete_at(socket.assigns.seq_manual_steps, index)

          {:noreply,
           socket
           |> assign(:seq_manual_steps, new_steps)
           |> assign(:seq_manual_error, nil)
           |> recompute_manual_missing_edges(new_steps)
           |> push_event("highlight_sequence", %{steps: Enum.map(new_steps, & &1.code)})}
        else
          {:noreply, socket}
        end
      end

      def handle_event("move_manual_step", %{"index" => index_str, "direction" => dir}, socket) do
        index = parse_index(index_str)
        steps = socket.assigns.seq_manual_steps
        new_index = if dir == "up", do: index - 1, else: index + 1

        if index >= 0 and new_index >= 0 and new_index < length(steps) do
          item = Enum.at(steps, index)
          new_steps = steps |> List.delete_at(index) |> List.insert_at(new_index, item)

          {:noreply,
           socket
           |> assign(:seq_manual_steps, new_steps)
           |> recompute_manual_missing_edges(new_steps)
           |> push_event("highlight_sequence", %{steps: Enum.map(new_steps, & &1.code)})}
        else
          {:noreply, socket}
        end
      end
    end
  end
end
