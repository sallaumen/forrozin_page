defmodule OGrupoDeEstudosWeb.Handlers.StepLearning do
  @moduledoc """
  The "I already know this step" gesture outside the map.

  The map has its own handler (`Handlers.GraphJourney`), which besides marking has
  to recompute the frontier and push it to Cytoscape. Here the screens only need
  the mark and the color of the chip.
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
  Codes of the steps the person already knows.

  It becomes chip color on the study and workshop screens. Reloaded on every mark:
  without that the person would mark a step, close the sheet and see the old chip.
  """
  @spec codigos_sabidos(map()) :: MapSet.t()
  def codigos_sabidos(%{assigns: %{current_user: %{id: id}}}),
    do: MapSet.new(OGrupoDeEstudos.Engagement.learned_step_codes(id))

  def codigos_sabidos(_sem_usuario), do: MapSet.new()

  @doc """
  Toggles the learning and returns the socket with the screen up to date.

  Marking as learned also favorites (an `Ecto.Multi` in the context), so the
  screens that show the star have to be refreshed together.
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
  Opens the quick sheet of the step.

  A code that does not exist simply opens nothing: the sheet stays closed by
  coming back nil, and the page keeps standing.
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
