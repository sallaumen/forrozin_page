defmodule OGrupoDeEstudosWeb.Handlers.GraphGenerator do
  @moduledoc """
  Macro com os handlers do gerador automático de sequências da GraphVisualLive.

  Uso: `use OGrupoDeEstudosWeb.Handlers.GraphGenerator`

  Cobre a geração (generate_sequences), o overlay de salvar resultado
  (start/cancel_save_sequence) e os autocompletes de passo inicial / passos
  obrigatórios. Requer os assigns `:seq_results`, `:seq_warnings`, `:seq_view`,
  `:seq_saving`, `:seq_missing_edges`, `:seq_start_code`, `:seq_start_query`,
  `:seq_start_suggestions`, `:seq_required_codes`, `:seq_required_search`,
  `:seq_required_suggestions` e `:graph_search_nodes`, e os helpers privados do
  host `parse_int/2` e `step_display_label/1`. Empurra
  "set_start_step_input" / "clear_required_input".
  """

  defmacro __using__(_opts) do
    quote do
      alias OGrupoDeEstudos.Sequences
      alias OGrupoDeEstudos.Encyclopedia.StepQuery
      alias OGrupoDeEstudosWeb.GraphVisual.SequenceGenerator

      def handle_event("generate_sequences", params, socket) do
        start_code =
          params
          |> Map.get("start_query", Map.get(params, "start_code", ""))
          |> SequenceGenerator.resolve_step_code(
            socket.assigns.graph_search_nodes,
            Map.get(params, "start_code", "")
          )

        loop_mode = Map.get(params, "loop_mode", "none")

        allow_repeats =
          loop_mode in ["light", "free"] or Map.get(params, "allow_repeats") in ["true", "on"]

        cyclic = Map.get(params, "cyclic") in ["true", "on"]
        min_length = if allow_repeats, do: 8, else: 4
        length_val = parse_int(Map.get(params, "length", "10"), 10) |> max(min_length)
        count_val = parse_int(Map.get(params, "count", "3"), 3)

        required_codes = socket.assigns.seq_required_codes

        max_bf = parse_int(Map.get(params, "max_bf_visits", "3"), 3)

        gen_params = %{
          start_code: start_code,
          length: length_val,
          count: count_val,
          required_codes: required_codes,
          allow_repeats: allow_repeats,
          cyclic: cyclic,
          max_bf_visits: max_bf,
          max_same_pair_loops: SequenceGenerator.max_same_pair_loops(loop_mode)
        }

        {:ok, sequences, warnings} = Sequences.generate(gen_params)

        {:noreply,
         socket
         |> assign(:seq_results, sequences)
         |> assign(:seq_warnings, warnings)
         |> assign(:seq_view, :results)
         |> assign(:seq_saving, nil)
         |> assign(:seq_missing_edges, [])}
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
            StepQuery.list_by(search: term, public_only: true, limit: 6, order_by: [asc: :code])
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

      # Autocomplete — required steps
      def handle_event("search_required_step", %{"value" => term}, socket) do
        suggestions =
          if String.length(term) >= 1 do
            already = socket.assigns.seq_required_codes

            StepQuery.list_by(search: term, public_only: true, limit: 6, order_by: [asc: :code])
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
