defmodule OGrupoDeEstudosWeb.Handlers.GraphManualDraft do
  @moduledoc """
  Macro com os handlers do ciclo de vida do rascunho do construtor manual de
  sequências da GraphVisualLive: abrir, editar uma sequência salva, cancelar e
  salvar.

  Uso: `use OGrupoDeEstudosWeb.Handlers.GraphManualDraft`

  Os handlers de manipulação de passos do rascunho ficam em
  `OGrupoDeEstudosWeb.Handlers.GraphManualSteps`. Requer o grupo de assigns
  `:seq_manual_*`, `:seq_view`, `:seq_editing_id`, `:seq_missing_edges` e os
  helpers privados do host `can_manage_sequence?/2`,
  `recompute_manual_missing_edges/2`, `assign_manual_favorite_steps/1`,
  `reset_manual_draft/1`, `assign_sequence_library/1` e
  `do_save_manual_sequence/6`. Empurra "set_manual_mode" / "highlight_sequence"
  / "clear_highlight".
  """

  defmacro __using__(_opts) do
    quote do
      alias OGrupoDeEstudos.Sequences

      @impl true
      def handle_event("edit_saved_sequence", %{"id" => id}, socket) do
        saved = Sequences.get_sequence(id)

        if can_manage_sequence?(socket, saved) do
          steps = Enum.sort_by(saved.sequence_steps, & &1.position)
          manual_steps = Enum.map(steps, &%{code: &1.step.code, name: &1.step.name})

          {:noreply,
           socket
           |> assign(:seq_view, :manual)
           |> assign(:seq_manual_steps, manual_steps)
           |> assign(:seq_manual_error, nil)
           |> assign(:seq_manual_search, "")
           |> assign(:seq_manual_suggestions, [])
           |> assign(:seq_editing_id, saved.id)
           |> assign(:seq_manual_name, saved.name || "")
           |> assign(:seq_manual_description, saved.description || "")
           |> assign(:seq_manual_video_url, saved.video_url || "")
           |> recompute_manual_missing_edges(manual_steps)
           |> push_event("set_manual_mode", %{active: true})
           |> push_event("highlight_sequence", %{steps: Enum.map(manual_steps, & &1.code)})}
        else
          {:noreply, socket}
        end
      end

      def handle_event("show_seq_manual", _params, socket) do
        {:noreply,
         socket
         |> assign(:seq_view, :manual)
         |> assign(:seq_manual_steps, [])
         |> assign(:seq_manual_error, nil)
         |> assign(:seq_manual_search, "")
         |> assign(:seq_manual_suggestions, [])
         |> assign(:seq_editing_id, nil)
         |> assign(:seq_manual_name, "")
         |> assign(:seq_manual_description, "")
         |> assign(:seq_manual_video_url, "")
         |> assign(:seq_missing_edges, [])
         |> assign_manual_favorite_steps()
         |> push_event("set_manual_mode", %{active: true})}
      end

      def handle_event("cancel_manual_sequence", _params, socket) do
        {:noreply,
         socket
         |> reset_manual_draft()
         |> assign(:seq_view, :library)
         |> assign_sequence_library()
         |> push_event("set_manual_mode", %{active: false})
         |> push_event("clear_highlight", %{})}
      end

      def handle_event("save_manual_sequence", params, socket) do
        name = Map.get(params, "name", "") |> String.trim()
        description = Map.get(params, "description", "") |> String.trim()
        video_url = Map.get(params, "video_url", "") |> String.trim()
        manual_steps = socket.assigns.seq_manual_steps
        user_id = socket.assigns.current_user.id

        socket =
          socket
          |> assign(:seq_manual_name, name)
          |> assign(:seq_manual_description, description)
          |> assign(:seq_manual_video_url, video_url)

        cond do
          name == "" ->
            {:noreply, assign(socket, :seq_manual_error, "Nome é obrigatório.")}

          manual_steps == [] ->
            {:noreply, assign(socket, :seq_manual_error, "Adicione ao menos um passo.")}

          true ->
            do_save_manual_sequence(socket, name, description, video_url, manual_steps, user_id)
        end
      end
    end
  end
end
