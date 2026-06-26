defmodule OGrupoDeEstudosWeb.Handlers.GraphThreeD do
  @moduledoc """
  Macro com os handlers de playback 3D de sequências da GraphVisualLive.

  Uso: `use OGrupoDeEstudosWeb.Handlers.GraphThreeD`

  Requer os assigns: `:three_d_mode`, `:three_d_steps`, `:three_d_current_step`,
  `:three_d_playing`, `:three_d_speed` e `:seq_active` (lido para semear a
  animação ao entrar no modo 3D). Empurra o evento "load_animation" para o hook
  3D. Não depende de nenhum helper privado da LiveView host.
  """

  defmacro __using__(_opts) do
    quote do
      alias OGrupoDeEstudos.Encyclopedia.StepQuery
      alias OGrupoDeEstudos.Media

      def handle_event("enter_3d_mode", _params, socket) do
        seq_active = socket.assigns.seq_active

        if seq_active && is_list(seq_active) && seq_active != [] do
          step_codes = Enum.map(seq_active, & &1.code)

          steps =
            step_codes
            |> Enum.map(fn code -> StepQuery.get_by(code: code) end)
            |> Enum.reject(&is_nil/1)
            |> OGrupoDeEstudos.Repo.preload(:category)

          animation_data = Media.build_sequence_animation(steps)

          {:noreply,
           socket
           |> assign(:three_d_mode, true)
           |> assign(:three_d_steps, animation_data)
           |> assign(:three_d_current_step, 0)
           |> assign(:three_d_playing, true)
           |> push_event("load_animation", %{steps: animation_data})}
        else
          {:noreply, socket}
        end
      end

      def handle_event("exit_3d_mode", _params, socket) do
        {:noreply,
         socket
         |> assign(:three_d_mode, false)
         |> assign(:three_d_steps, [])
         |> assign(:three_d_current_step, 0)
         |> assign(:three_d_playing, false)}
      end

      def handle_event("three_d_play", _params, socket),
        do: {:noreply, assign(socket, :three_d_playing, true)}

      def handle_event("three_d_pause", _params, socket),
        do: {:noreply, assign(socket, :three_d_playing, false)}

      def handle_event("three_d_next", _params, socket) do
        max_idx = length(socket.assigns.three_d_steps) - 1
        new_idx = min(socket.assigns.three_d_current_step + 1, max_idx)
        {:noreply, assign(socket, :three_d_current_step, new_idx)}
      end

      def handle_event("three_d_prev", _params, socket) do
        new_idx = max(socket.assigns.three_d_current_step - 1, 0)
        {:noreply, assign(socket, :three_d_current_step, new_idx)}
      end

      def handle_event("three_d_speed", %{"speed" => speed_str}, socket) do
        speed =
          case Float.parse(speed_str) do
            {s, _} -> s
            _ -> 1.0
          end

        {:noreply, assign(socket, :three_d_speed, speed)}
      end

      def handle_event("step_changed", %{"index" => index}, socket) do
        {:noreply, assign(socket, :three_d_current_step, index)}
      end

      def handle_event("playback_ended", _params, socket) do
        {:noreply, assign(socket, :three_d_playing, false)}
      end
    end
  end
end
