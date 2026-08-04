defmodule OGrupoDeEstudosWeb.Handlers.GraphManualSteps do
  @moduledoc """
  Macro with the step manipulation handlers of the manual builder draft in
  GraphVisualLive: add (by click, search or selection), search, remove and reorder.
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

      # The client sends positions, not codes: a sequence may repeat the same step,
      # so a code would be ambiguous about which copy moved.
      def handle_event("reorder_manual_steps", %{"order" => order}, socket) when is_list(order) do
        steps = socket.assigns.seq_manual_steps
        reordered = reorder_manual(steps, order)

        if length(reordered) == length(steps) do
          {:noreply,
           socket
           |> assign(:seq_manual_steps, reordered)
           |> recompute_manual_missing_edges(reordered)
           |> push_event("highlight_sequence", %{steps: Enum.map(reordered, & &1.code)})}
        else
          {:noreply, socket}
        end
      end

      def handle_event("reorder_manual_steps", _bad, socket), do: {:noreply, socket}

      defp reorder_manual(steps, order) do
        order
        |> Enum.map(&parse_index/1)
        |> Enum.filter(&valid_index?(steps, &1))
        |> Enum.map(&Enum.at(steps, &1))
      end
    end
  end
end
