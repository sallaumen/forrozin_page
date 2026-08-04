defmodule OGrupoDeEstudosWeb.Handlers.StepLearning do
  @moduledoc """
  O gesto de "já sei este passo" fora do mapa.

  O mapa tem o seu próprio handler (`Handlers.GraphJourney`), que além de
  marcar precisa recalcular a fronteira da jornada e repintar o grafo. Aqui o
  trabalho é menor: marcar e refletir na tela.

  As duas telas que usam este handler mostram o mesmo componente
  (`StepDetail`), então a atualização é a mesma nos dois casos, só muda o nome
  do assign: a página do passo guarda em `step_*`, o drawer em `drawer_*`.
  """

  defmacro __using__(_opts) do
    quote do
      alias OGrupoDeEstudos.Encyclopedia.StepQuery
      alias OGrupoDeEstudos.Engagement

      @impl true
      def handle_event("toggle_step_learned", %{"code" => code}, socket) do
        case StepQuery.get_by(code: code) do
          nil -> {:noreply, socket}
          step -> {:noreply, unquote(__MODULE__).alternar(socket, step)}
        end
      end
    end
  end

  @doc """
  Alterna o aprendizado e devolve o socket com a tela em dia.

  Marcar como aprendido também favorita (é um `Ecto.Multi` no contexto), então
  o favorito é relido junto: sem isso a estrela só acenderia no próximo
  reload, e ninguém entenderia de onde veio.
  """
  def alternar(socket, step) do
    user_id = socket.assigns.current_user.id
    OGrupoDeEstudos.Engagement.toggle_learned(user_id, step.id)

    socket
    |> atualizar_pagina(step, user_id)
    |> atualizar_drawer(step, user_id)
  end

  defp atualizar_pagina(%{assigns: %{step_learned: _}} = socket, step, user_id) do
    Phoenix.Component.assign(socket,
      step_learned: OGrupoDeEstudos.Engagement.learned?(user_id, step.id),
      step_favorited: OGrupoDeEstudos.Engagement.favorited?(user_id, "step", step.id)
    )
  end

  defp atualizar_pagina(socket, _step, _user_id), do: socket

  defp atualizar_drawer(%{assigns: %{drawer_item: %{id: id}}} = socket, %{id: id} = step, user_id) do
    Phoenix.Component.assign(socket,
      drawer_learned: OGrupoDeEstudos.Engagement.learned?(user_id, step.id),
      drawer_favorited: OGrupoDeEstudos.Engagement.favorited?(user_id, "step", step.id)
    )
  end

  defp atualizar_drawer(socket, _step, _user_id), do: socket
end
