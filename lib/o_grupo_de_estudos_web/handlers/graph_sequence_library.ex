defmodule OGrupoDeEstudosWeb.Handlers.GraphSequenceLibrary do
  @moduledoc """
  Macro com os handlers da biblioteca de sequências da GraphVisualLive: salvar
  resultado, deletar, alternar views (config/library/saved/favorites), busca,
  filtros e favoritar sequência.

  Uso: `use OGrupoDeEstudosWeb.Handlers.GraphSequenceLibrary`

  Requer os assigns `:seq_view`, `:seq_results`, `:seq_warnings`, `:seq_saving`,
  `:seq_library_search`, `:seq_library_origin_filter`, `:seq_library_category_filter`
  e os helpers privados do host `parse_int/2`, `can_manage_sequence?/2`,
  `assign_sequence_library/1`, `assign_filtered_sequence_library/1`,
  `deactivate_manual_mode/1` e `maybe_clear_deleted_sequence/2`.
  """

  defmacro __using__(_opts) do
    quote do
      alias OGrupoDeEstudos.Sequences
      alias OGrupoDeEstudos.Engagement

      def handle_event("save_sequence", %{"index" => index_str, "name" => name}, socket) do
        index = parse_int(index_str, 0)
        sequence = Enum.at(socket.assigns.seq_results, index)
        name = String.trim(name)

        if sequence && name != "" do
          step_ids = Enum.map(sequence, & &1.id)
          user_id = socket.assigns.current_user.id

          case Sequences.create_sequence(user_id, name, step_ids) do
            {:ok, _saved} ->
              {:noreply,
               socket
               |> assign(:seq_saving, nil)
               |> assign_sequence_library()}

            {:error, _changeset} ->
              {:noreply, socket}
          end
        else
          {:noreply, socket}
        end
      end

      def handle_event("delete_sequence", %{"id" => id}, socket) do
        sequence = Sequences.get_sequence(id)

        if can_manage_sequence?(socket, sequence) do
          {:ok, _} = Sequences.delete_sequence(sequence)

          socket =
            socket
            |> assign_sequence_library()
            |> maybe_clear_deleted_sequence(id)

          {:noreply, socket}
        else
          {:noreply, socket}
        end
      end

      def handle_event("show_seq_config", _params, socket) do
        {:noreply,
         socket
         |> assign(:seq_view, :config)
         |> assign(:seq_results, [])
         |> assign(:seq_warnings, [])
         |> assign(:seq_saving, nil)
         |> deactivate_manual_mode()}
      end

      def handle_event("show_seq_library", _params, socket) do
        {:noreply,
         socket
         |> assign(:seq_view, :library)
         |> assign_sequence_library()
         |> deactivate_manual_mode()}
      end

      def handle_event("show_seq_saved", _params, socket) do
        {:noreply,
         socket
         |> assign(:seq_view, :library)
         |> assign_sequence_library()
         |> deactivate_manual_mode()}
      end

      def handle_event("show_seq_favorites", _params, socket) do
        {:noreply,
         socket
         |> assign(:seq_view, :library)
         |> assign_sequence_library()
         |> deactivate_manual_mode()}
      end

      def handle_event("search_sequence_library", params, socket) do
        term = params["value"] || params["term"] || ""

        {:noreply,
         socket
         |> assign(:seq_library_search, term)
         |> assign_filtered_sequence_library()}
      end

      def handle_event("filter_sequence_library_origin", %{"origin" => origin}, socket) do
        {:noreply,
         socket
         |> assign(:seq_library_origin_filter, origin)
         |> assign_filtered_sequence_library()}
      end

      def handle_event("filter_sequence_library_category", %{"category" => category}, socket) do
        {:noreply,
         socket
         |> assign(:seq_library_category_filter, category)
         |> assign_filtered_sequence_library()}
      end

      def handle_event("toggle_sequence_favorite_graph", %{"id" => seq_id}, socket) do
        user_id = socket.assigns.current_user.id

        # Só permite favoritar uma sequência visível (pública, própria ou admin);
        # senão favoritar um id arbitrário vazaria sequência privada na biblioteca.
        if Sequences.get_sequence_for_viewer(seq_id, user_id, socket.assigns.is_admin) do
          case Engagement.toggle_favorite(user_id, "sequence", seq_id) do
            {:ok, _} ->
              {:noreply, assign_sequence_library(socket)}

            {:error, reason} ->
              {:noreply,
               put_flash(
                 socket,
                 :error,
                 OGrupoDeEstudosWeb.Helpers.EngagementMessages.favorite_error(reason)
               )}
          end
        else
          {:noreply, socket}
        end
      end
    end
  end
end
