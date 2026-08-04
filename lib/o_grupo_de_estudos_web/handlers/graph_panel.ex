defmodule OGrupoDeEstudosWeb.Handlers.GraphPanel do
  @moduledoc """
  Macro with the sequence panel toggle handlers of GraphVisualLive.

  Usage: `use OGrupoDeEstudosWeb.Handlers.GraphPanel`
  """

  defmacro __using__(_opts) do
    quote do
      def handle_event("toggle_seq_panel", _params, socket) do
        new_open = not socket.assigns.seq_panel

        socket =
          socket
          |> assign(:seq_panel, new_open)
          |> assign(:seq_view, :library)
          |> assign(:seq_manual_steps, [])
          |> assign(:seq_manual_error, nil)
          |> assign(:seq_manual_search, "")
          |> assign(:seq_manual_suggestions, [])
          |> assign(:seq_editing_id, nil)
          |> maybe_refresh_sequence_library(new_open)

        socket =
          if new_open,
            do: socket,
            else: push_event(socket, "set_manual_mode", %{active: false})

        {:noreply, socket}
      end

      def handle_event("show_seq_mobile", _params, socket) do
        {:noreply, assign(socket, seq_mobile_visible: true)}
      end

      def handle_event("hide_seq_mobile", _params, socket) do
        {:noreply, assign(socket, seq_mobile_visible: false)}
      end

      defp maybe_refresh_sequence_library(socket, true), do: assign_sequence_library(socket)
      defp maybe_refresh_sequence_library(socket, false), do: socket
    end
  end
end
