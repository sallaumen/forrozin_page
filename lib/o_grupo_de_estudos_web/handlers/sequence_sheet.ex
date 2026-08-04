defmodule OGrupoDeEstudosWeb.Handlers.SequenceSheet do
  @moduledoc """
  The sheet that builds or cites a sequence from inside a study screen.

  A sequence used to be reachable only through the manual builder on the map, so a
  combination that worked in class was written as prose and lost its shape. The
  sheet brings the gesture to where the need shows up.

  Two ways in, both useful: build a new one on the spot, or cite one already in the
  person's collection. The sequence belongs to whoever built it either way.
  """

  import Phoenix.Component, only: [assign: 2, assign: 3]

  alias OGrupoDeEstudos.{Encyclopedia, Sequences}

  @closed %{
    sequence_sheet: nil,
    sequence_draft_steps: [],
    sequence_draft_name: "",
    sequence_search_term: "",
    sequence_step_matches: [],
    sequence_mine: []
  }

  defmacro __using__(_opts) do
    quote do
      on_mount({unquote(__MODULE__), :closed_sheet})

      def handle_event("open_sequence_sheet", %{"tab" => tab}, socket) do
        {:noreply, unquote(__MODULE__).open(socket, tab)}
      end

      def handle_event("close_sequence_sheet", _params, socket) do
        {:noreply, unquote(__MODULE__).close(socket)}
      end

      def handle_event("sequence_sheet_tab", %{"tab" => tab}, socket) do
        {:noreply, unquote(__MODULE__).switch_tab(socket, tab)}
      end

      def handle_event("sequence_draft_name", %{"value" => name}, socket) do
        {:noreply, Phoenix.Component.assign(socket, :sequence_draft_name, name)}
      end

      def handle_event("sequence_search_step", %{"value" => term}, socket) do
        {:noreply, unquote(__MODULE__).search_steps(socket, term)}
      end

      def handle_event("sequence_draft_add", %{"code" => code}, socket) do
        {:noreply, unquote(__MODULE__).add_step(socket, code)}
      end

      def handle_event("sequence_draft_remove", %{"index" => index}, socket) do
        {:noreply, unquote(__MODULE__).remove_step(socket, index)}
      end

      def handle_event("sequence_draft_reorder", %{"order" => order}, socket) do
        {:noreply, unquote(__MODULE__).reorder(socket, order)}
      end
    end
  end

  @doc false
  def on_mount(:closed_sheet, _params, _session, socket) do
    {:cont, assign(socket, @closed)}
  end

  @doc "Opens the sheet fresh on the given tab. A new visit starts with a clean draft."
  def open(socket, tab) do
    socket
    |> assign(@closed)
    |> switch_tab(tab)
  end

  @doc """
  Moves to the other tab keeping the draft intact.

  Peeking at "mine" mid-draft must not cost the steps already picked: the sheet
  resets only when it opens, never on a tab change.
  """
  def switch_tab(socket, "mine") do
    socket
    |> assign(:sequence_sheet, "mine")
    |> assign(:sequence_mine, mine(socket))
  end

  def switch_tab(socket, _new), do: assign(socket, :sequence_sheet, "new")

  @doc "Closes the sheet and drops the draft with it."
  def close(socket), do: assign(socket, @closed)

  @doc "Steps matching the typed term, minus the ones already in the draft."
  def search_steps(socket, term) when byte_size(term) > 0 do
    taken = MapSet.new(socket.assigns.sequence_draft_steps, & &1.code)

    matches =
      Encyclopedia.list_steps_by(
        search: term,
        status: :published,
        wip: false,
        order_by: [asc: :name],
        limit: 8
      )
      |> Enum.reject(&MapSet.member?(taken, &1.code))

    socket
    |> assign(:sequence_search_term, term)
    |> assign(:sequence_step_matches, matches)
  end

  def search_steps(socket, _blank) do
    socket
    |> assign(:sequence_search_term, "")
    |> assign(:sequence_step_matches, [])
  end

  @doc "Appends a step to the draft. The same step may repeat: a sequence can revisit."
  def add_step(socket, code) do
    case Encyclopedia.get_step_by(code: code) do
      nil ->
        socket

      step ->
        socket
        |> assign(:sequence_draft_steps, socket.assigns.sequence_draft_steps ++ [step])
        |> assign(:sequence_search_term, "")
        |> assign(:sequence_step_matches, [])
    end
  end

  @doc "Drops the step at the given position."
  def remove_step(socket, index) do
    case Integer.parse(to_string(index)) do
      {i, _rest} -> assign(socket, :sequence_draft_steps, List.delete_at(draft(socket), i))
      :error -> socket
    end
  end

  @doc """
  Applies the order the drag gesture pushed.

  The client sends positions, not ids: a sequence may repeat the same step, so an
  id would be ambiguous about which copy moved.
  """
  def reorder(socket, order) when is_list(order) do
    steps = draft(socket)

    reordered =
      order
      |> Enum.map(&parse_index/1)
      |> Enum.filter(&(&1 in 0..(length(steps) - 1)//1))
      |> Enum.map(&Enum.at(steps, &1))

    if length(reordered) == length(steps) do
      assign(socket, :sequence_draft_steps, reordered)
    else
      socket
    end
  end

  def reorder(socket, _bad), do: socket

  @doc "Creates the drafted sequence for the current user. Returns `{:ok, sequence}`."
  def save_draft(socket) do
    user = socket.assigns.current_user
    steps = draft(socket)
    name = String.trim(socket.assigns.sequence_draft_name || "")

    with :ok <- ensure_named(name),
         :ok <- ensure_enough_steps(steps) do
      Sequences.create_sequence(user.id, name, Enum.map(steps, & &1.id))
    end
  end

  defp ensure_named(""), do: {:error, :name_required}
  defp ensure_named(_name), do: :ok

  defp ensure_enough_steps(steps) when length(steps) < 2, do: {:error, :too_short}
  defp ensure_enough_steps(_steps), do: :ok

  defp draft(socket), do: socket.assigns.sequence_draft_steps

  defp parse_index(value) do
    case Integer.parse(to_string(value)) do
      {i, _rest} -> i
      :error -> -1
    end
  end

  defp mine(socket) do
    case socket.assigns[:current_user] do
      nil -> []
      user -> Sequences.list_user_sequences(user.id)
    end
  end
end
