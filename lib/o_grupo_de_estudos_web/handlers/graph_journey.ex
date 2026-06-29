defmodule OGrupoDeEstudosWeb.Handlers.GraphJourney do
  @moduledoc """
  Macro com os handlers da jornada de estudos no grafo: marcar um passo como
  aprendido e alternar entre "Meu progresso" e "Explorar tudo" (mapa completo).

  Uso: `use OGrupoDeEstudosWeb.Handlers.GraphJourney`

  Requer os assigns `:learned_codes`, `:frontier_codes`, `:next_goal`,
  `:full_map?` e `:edges`, e os helpers privados do host: `compute_frontier/2`,
  `learned_payload/4`, `favorited_step_codes/1` e `assign_manual_favorite_steps/1`.
  Empurra "set_learned_steps" (com learned/frontier/goal/full_map) para o hook
  Cytoscape recolorir e revelar/esconder; o disclosure é client-side.
  """

  defmacro __using__(_opts) do
    quote do
      alias OGrupoDeEstudos.Encyclopedia.StepQuery
      alias OGrupoDeEstudos.Engagement
      alias OGrupoDeEstudosWeb.GraphVisual.JourneyPlan
      alias OGrupoDeEstudosWeb.StepDrawer

      def handle_event("toggle_step_learned", %{"code" => code}, socket) do
        user = socket.assigns.current_user
        step = StepQuery.get_by(code: code)

        if step do
          Engagement.toggle_learned(user.id, step.id)
          {:noreply, refresh_journey(socket, user.id, step.id)}
        else
          {:noreply, socket}
        end
      end

      def handle_event("toggle_full_map", _params, socket) do
        full_map = not socket.assigns.full_map?

        payload =
          learned_payload(
            socket.assigns.learned_codes,
            socket.assigns.frontier_codes,
            socket.assigns.next_goal,
            full_map
          )

        {:noreply,
         socket
         |> assign(:full_map?, full_map)
         |> push_event("set_learned_steps", payload)}
      end

      def handle_event("reset_progress", _params, socket) do
        Engagement.reset_learned(socket.assigns.current_user.id)
        next_goal = JourneyPlan.next_goal([])

        {:noreply,
         socket
         |> assign(:learned_codes, [])
         |> assign(:frontier_codes, [])
         |> assign(:next_goal, next_goal)
         |> push_event(
           "set_learned_steps",
           learned_payload([], [], next_goal, socket.assigns.full_map?)
         )}
      end

      # Centra/revela um passo no mapa (clique num item de "pode aprender agora").
      def handle_event("focus_step", %{"code" => code}, socket) do
        {:noreply, push_event(socket, "focus_graph_node", %{code: code})}
      end

      def handle_event("toggle_journey", _params, socket) do
        {:noreply, assign(socket, :journey_open, not socket.assigns.journey_open)}
      end

      # Recarrega aprendidos/fronteira/meta e o engajamento implicado (favorito +
      # like), recolorindo o grafo e o painel sem reconstruir a instância.
      defp refresh_journey(socket, user_id, step_id) do
        learned_codes = Engagement.learned_step_codes(user_id)
        frontier_codes = compute_frontier(socket.assigns.edges, learned_codes)
        next_goal = JourneyPlan.next_goal(learned_codes)
        liked_codes = Engagement.liked_step_codes(user_id)

        socket
        |> assign(:learned_codes, learned_codes)
        |> assign(:frontier_codes, frontier_codes)
        |> assign(:next_goal, next_goal)
        |> assign(:liked_step_codes, liked_codes)
        |> assign_manual_favorite_steps()
        |> StepDrawer.sync_engagement(step_id)
        |> push_event(
          "set_learned_steps",
          learned_payload(learned_codes, frontier_codes, next_goal, socket.assigns.full_map?)
        )
        |> push_event("set_liked_steps", %{codes: liked_codes})
        |> push_event("set_favorited_steps", %{codes: favorited_step_codes(user_id)})
      end
    end
  end
end
