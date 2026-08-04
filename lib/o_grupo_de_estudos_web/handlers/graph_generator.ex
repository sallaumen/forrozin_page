defmodule OGrupoDeEstudosWeb.Handlers.GraphGenerator do
  @moduledoc """
  Macro with the automatic sequence generator handlers of GraphVisualLive.

  Usage: `use OGrupoDeEstudosWeb.Handlers.GraphGenerator`
  """

  defmacro __using__(_opts) do
    quote do
      alias OGrupoDeEstudos.Sequences
      alias OGrupoDeEstudosWeb.GraphVisual.SequenceGenerator

      def handle_event("generate_sequences", params, socket) do
        start_code =
          params
          |> Map.get("start_query", Map.get(params, "start_code", ""))
          |> SequenceGenerator.resolve_step_code(
            socket.assigns.graph_search_nodes,
            Map.get(params, "start_code", "")
          )

        gen_params =
          OGrupoDeEstudos.Sequences.GenerationParams.from_raw(
            start_code,
            socket.assigns.seq_required_codes,
            params
          )

        case Sequences.generate(gen_params) do
          {:ok, sequences, warnings} ->
            {:noreply,
             socket
             |> assign(:seq_results, sequences)
             |> assign(:seq_warnings, warnings)
             |> assign(:seq_view, :results)
             |> assign(:seq_saving, nil)
             |> assign(:seq_missing_edges, [])}

          {:error, %Sequences.GeneratorError{message: message}} ->
            # The results panel is the only visible place on this page (flash does not
            # render from handle_event here), so the typed domain error becomes its only message.
            {:noreply,
             socket
             |> assign(:seq_results, [])
             |> assign(:seq_warnings, [message])
             |> assign(:seq_view, :results)
             |> assign(:seq_saving, nil)
             |> assign(:seq_missing_edges, [])}
        end
      end

      def handle_event("start_save_sequence", %{"index" => index_str}, socket) do
        index = parse_int(index_str, 0)
        {:noreply, assign(socket, :seq_saving, index)}
      end

      def handle_event("cancel_save_sequence", _params, socket) do
        {:noreply, assign(socket, :seq_saving, nil)}
      end

      def handle_event("search_start_step", %{"value" => term}, socket) do
        suggestions =
          if String.length(term) >= 1 do
            OGrupoDeEstudos.Encyclopedia.list_steps_by(
              search: term,
              public_only: true,
              limit: 6,
              order_by: [asc: :code]
            )
            |> Enum.map(&%{code: &1.code, name: &1.name})
          else
            []
          end

        {:noreply,
         socket
         |> assign(:seq_start_query, term)
         |> assign(:seq_start_suggestions, suggestions)}
      end

      def handle_event("select_start_step", %{"code" => code, "name" => name}, socket) do
        label = step_display_label(%{code: code, name: name})

        {:noreply,
         socket
         |> assign(:seq_start_code, code)
         |> assign(:seq_start_query, label)
         |> assign(:seq_start_suggestions, [])
         |> push_event("set_start_step_input", %{value: label, name: name})}
      end

      def handle_event("search_required_step", %{"value" => term}, socket) do
        suggestions =
          if String.length(term) >= 1 do
            already = socket.assigns.seq_required_codes

            OGrupoDeEstudos.Encyclopedia.list_steps_by(
              search: term,
              public_only: true,
              limit: 6,
              order_by: [asc: :code]
            )
            |> Enum.reject(&(&1.code in already))
            |> Enum.map(&%{code: &1.code, name: &1.name})
          else
            []
          end

        {:noreply,
         socket
         |> assign(:seq_required_search, term)
         |> assign(:seq_required_suggestions, suggestions)}
      end

      def handle_event("select_required_step", %{"code" => code}, socket) do
        already = socket.assigns.seq_required_codes

        new_required =
          if code in already do
            already
          else
            already ++ [code]
          end

        {:noreply,
         socket
         |> assign(:seq_required_codes, new_required)
         |> assign(:seq_required_search, "")
         |> assign(:seq_required_suggestions, [])
         |> push_event("clear_required_input", %{})}
      end

      def handle_event("hide_seq_suggestions", _params, socket) do
        {:noreply,
         assign(socket,
           seq_start_suggestions: [],
           seq_required_suggestions: []
         )}
      end

      def handle_event("remove_required_step", %{"code" => code}, socket) do
        new_required = Enum.reject(socket.assigns.seq_required_codes, &(&1 == code))
        {:noreply, assign(socket, :seq_required_codes, new_required)}
      end
    end
  end
end
