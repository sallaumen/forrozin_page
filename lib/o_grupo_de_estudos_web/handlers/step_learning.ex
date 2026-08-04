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
      on_mount({unquote(__MODULE__), :closed_sheet})

      alias OGrupoDeEstudos.Encyclopedia.StepQuery
      alias OGrupoDeEstudos.Engagement

      @impl true
      def handle_event("toggle_step_learned", %{"code" => code}, socket) do
        case StepQuery.get_by(code: code) do
          nil -> {:noreply, socket}
          step -> {:noreply, unquote(__MODULE__).toggle(socket, step)}
        end
      end

      def handle_event("open_step_sheet", %{"code" => code}, socket) do
        {:noreply, unquote(__MODULE__).open_sheet(socket, StepQuery.get_by(code: code))}
      end

      def handle_event("close_step_sheet", _params, socket) do
        {:noreply, Phoenix.Component.assign(socket, step_sheet: nil, step_sheet_learned: false)}
      end
    end
  end

  @doc false
  def on_mount(:closed_sheet, _params, _session, socket) do
    {:cont,
     socket
     |> Phoenix.Component.assign_new(:step_sheet, fn -> nil end)
     |> Phoenix.Component.assign_new(:step_sheet_learned, fn -> false end)
     |> Phoenix.Component.assign_new(:learned_codes, fn -> learned_codes_of(socket) end)}
  end

  @doc """
  Codes of the steps the person already knows.

  It becomes chip color on the study and workshop screens. Reloaded on every mark:
  without that the person would mark a step, close the sheet and see the old chip.
  """
  @spec learned_codes_of(map()) :: MapSet.t()
  def learned_codes_of(%{assigns: %{current_user: %{id: id}}}),
    do: MapSet.new(OGrupoDeEstudos.Engagement.learned_step_codes(id))

  def learned_codes_of(_no_user), do: MapSet.new()

  @doc """
  Toggles the learning and returns the socket with the screen up to date.

  Marking as learned also favorites (an `Ecto.Multi` in the context), so the
  screens that show the star have to be refreshed together.
  """
  def toggle(socket, step) do
    user_id = socket.assigns.current_user.id
    OGrupoDeEstudos.Engagement.toggle_learned(user_id, step.id)

    socket
    |> refresh_page(step, user_id)
    |> refresh_drawer(step, user_id)
    |> refresh_sheet(step, user_id)
    |> Phoenix.Component.assign(
      :learned_codes,
      MapSet.new(OGrupoDeEstudos.Engagement.learned_step_codes(user_id))
    )
  end

  defp refresh_page(%{assigns: %{step_learned: _}} = socket, step, user_id) do
    Phoenix.Component.assign(socket,
      step_learned: OGrupoDeEstudos.Engagement.learned?(user_id, step.id),
      step_favorited: OGrupoDeEstudos.Engagement.favorited?(user_id, "step", step.id)
    )
  end

  defp refresh_page(socket, _step, _user_id), do: socket

  defp refresh_drawer(%{assigns: %{drawer_item: %{id: id}}} = socket, %{id: id} = step, user_id) do
    Phoenix.Component.assign(socket,
      drawer_learned: OGrupoDeEstudos.Engagement.learned?(user_id, step.id),
      drawer_favorited: OGrupoDeEstudos.Engagement.favorited?(user_id, "step", step.id)
    )
  end

  defp refresh_drawer(socket, _step, _user_id), do: socket

  defp refresh_sheet(%{assigns: %{step_sheet: %{id: id}}} = socket, %{id: id} = step, user_id) do
    Phoenix.Component.assign(
      socket,
      :step_sheet_learned,
      OGrupoDeEstudos.Engagement.learned?(user_id, step.id)
    )
  end

  defp refresh_sheet(socket, _step, _user_id), do: socket

  @doc """
  Opens the quick sheet of the step.

  A code that does not exist simply opens nothing: the sheet stays closed by
  coming back nil, and the page keeps standing.
  """
  def open_sheet(socket, nil), do: socket

  def open_sheet(socket, step) do
    Phoenix.Component.assign(socket,
      step_sheet: step,
      step_sheet_learned:
        OGrupoDeEstudos.Engagement.learned?(socket.assigns.current_user.id, step.id)
    )
  end
end
