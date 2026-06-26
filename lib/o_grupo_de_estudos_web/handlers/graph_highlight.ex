defmodule OGrupoDeEstudosWeb.Handlers.GraphHighlight do
  @moduledoc """
  Macro com os handlers de destaque de sequência sobre o grafo da GraphVisualLive.

  Uso: `use OGrupoDeEstudosWeb.Handlers.GraphHighlight`

  Requer os assigns: `:seq_active`, `:seq_active_id`, `:seq_initial_steps_json`,
  `:seq_missing_edges`, `:seq_mobile_visible`, `:seq_results` e o helper privado
  do host `parse_int/2`. Empurra "highlight_sequence" / "clear_highlight" para o
  hook Cytoscape.
  """

  defmacro __using__(_opts) do
    quote do
      alias OGrupoDeEstudos.Sequences

      def handle_event("highlight_sequence", %{"index" => index_str}, socket) do
        index = parse_int(index_str, 0)
        sequence = Enum.at(socket.assigns.seq_results, index)

        if sequence do
          step_codes = Enum.map(sequence, & &1.code)

          {:noreply,
           socket
           |> assign(:seq_active, sequence)
           |> assign(:seq_active_id, nil)
           |> assign(:seq_initial_steps_json, "[]")
           |> assign(:seq_mobile_visible, false)
           |> push_event("highlight_sequence", %{steps: step_codes})}
        else
          {:noreply, socket}
        end
      end

      def handle_event("highlight_saved_sequence", %{"id" => id}, socket) do
        saved = Sequences.get_sequence(id)

        if saved do
          steps = Enum.sort_by(saved.sequence_steps, & &1.position)
          step_codes = Enum.map(steps, & &1.step.code)
          step_list = Enum.map(steps, &%{id: &1.step.id, code: &1.step.code, name: &1.step.name})

          {:noreply,
           socket
           |> assign(:seq_active, step_list)
           |> assign(:seq_active_id, saved.id)
           |> assign(:seq_initial_steps_json, Jason.encode!(step_codes))
           |> assign(:seq_missing_edges, [])
           |> assign(:seq_mobile_visible, false)
           |> push_event("highlight_sequence", %{steps: step_codes})}
        else
          {:noreply, socket}
        end
      end

      def handle_event("clear_highlight", _params, socket) do
        {:noreply,
         socket
         |> assign(:seq_active, nil)
         |> assign(:seq_active_id, nil)
         |> assign(:seq_initial_steps_json, "[]")
         |> assign(:seq_missing_edges, [])
         |> push_event("clear_highlight", %{})}
      end
    end
  end
end
