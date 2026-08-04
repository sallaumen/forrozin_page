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
      # The sheet starts closed. It sits in the `use` so the screens that use it do
      # not have to remember to initialize the assign.
      on_mount({unquote(__MODULE__), :folha_fechada})

      alias OGrupoDeEstudos.Encyclopedia.StepQuery
      alias OGrupoDeEstudos.Engagement

      @impl true
      def handle_event("toggle_step_learned", %{"code" => code}, socket) do
        case StepQuery.get_by(code: code) do
          nil -> {:noreply, socket}
          step -> {:noreply, unquote(__MODULE__).alternar(socket, step)}
        end
      end

      def handle_event("open_step_sheet", %{"code" => code}, socket) do
        {:noreply, unquote(__MODULE__).abrir_folha(socket, StepQuery.get_by(code: code))}
      end

      def handle_event("close_step_sheet", _params, socket) do
        {:noreply, Phoenix.Component.assign(socket, step_sheet: nil, step_sheet_learned: false)}
      end
    end
  end

  @doc false
  def on_mount(:folha_fechada, _params, _session, socket) do
    {:cont,
     socket
     |> Phoenix.Component.assign_new(:step_sheet, fn -> nil end)
     |> Phoenix.Component.assign_new(:step_sheet_learned, fn -> false end)
     |> Phoenix.Component.assign_new(:learned_codes, fn -> codigos_sabidos(socket) end)}
  end

  @doc """
  Códigos dos passos que a pessoa já sabe.

  Vira cor de chip nas telas de estudo e de workshop. Recarregado a cada
  marcação: sem isso a pessoa marcaria pela folha, fecharia, e veria o chip
  antigo sem saber se funcionou.
  """
  @spec codigos_sabidos(map()) :: MapSet.t()
  def codigos_sabidos(%{assigns: %{current_user: %{id: id}}}),
    do: MapSet.new(OGrupoDeEstudos.Engagement.learned_step_codes(id))

  def codigos_sabidos(_sem_usuario), do: MapSet.new()

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
    |> atualizar_folha(step, user_id)
    |> Phoenix.Component.assign(
      :learned_codes,
      MapSet.new(OGrupoDeEstudos.Engagement.learned_step_codes(user_id))
    )
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

  defp atualizar_folha(%{assigns: %{step_sheet: %{id: id}}} = socket, %{id: id} = step, user_id) do
    Phoenix.Component.assign(
      socket,
      :step_sheet_learned,
      OGrupoDeEstudos.Engagement.learned?(user_id, step.id)
    )
  end

  defp atualizar_folha(socket, _step, _user_id), do: socket

  @doc """
  Abre a folha rápida do passo.

  Código que não existe simplesmente não abre nada: a folha some por vir nula,
  e a página segue de pé.
  """
  def abrir_folha(socket, nil), do: socket

  def abrir_folha(socket, step) do
    Phoenix.Component.assign(socket,
      step_sheet: step,
      step_sheet_learned:
        OGrupoDeEstudos.Engagement.learned?(socket.assigns.current_user.id, step.id)
    )
  end
end
