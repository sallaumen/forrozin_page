defmodule OGrupoDeEstudosWeb.Handlers.GraphLikeFavorite do
  @moduledoc """
  Macro com os handlers de curtir/favoritar um passo direto no grafo.

  Uso: `use OGrupoDeEstudosWeb.Handlers.GraphLikeFavorite`

  Requer o assign `:liked_step_codes` e os helpers privados do host:
  `favorited_step_codes/1` e `assign_manual_favorite_steps/1`. Empurra
  "set_liked_steps" / "set_favorited_steps" para o hook Cytoscape.
  """

  defmacro __using__(_opts) do
    quote do
      alias OGrupoDeEstudos.Encyclopedia.StepQuery
      alias OGrupoDeEstudos.Engagement

      def handle_event("toggle_step_like_graph", %{"code" => code}, socket) do
        user = socket.assigns.current_user
        step = StepQuery.get_by(code: code)

        if step do
          Engagement.toggle_like(user.id, "step", step.id)
          liked_codes = Engagement.liked_step_codes(user.id)

          {:noreply,
           socket
           |> assign(:liked_step_codes, liked_codes)
           |> push_event("set_liked_steps", %{codes: liked_codes})}
        else
          {:noreply, socket}
        end
      end

      def handle_event("toggle_step_favorite_graph", %{"code" => code}, socket) do
        user = socket.assigns.current_user
        step = StepQuery.get_by(code: code)

        if step do
          Engagement.toggle_favorite(user.id, "step", step.id)
          liked_codes = Engagement.liked_step_codes(user.id)
          fav_codes = favorited_step_codes(user.id)

          {:noreply,
           socket
           |> assign(:liked_step_codes, liked_codes)
           |> assign_manual_favorite_steps()
           |> push_event("set_liked_steps", %{codes: liked_codes})
           |> push_event("set_favorited_steps", %{codes: fav_codes})}
        else
          {:noreply, socket}
        end
      end
    end
  end
end
