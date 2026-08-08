defmodule OGrupoDeEstudosWeb.UI.UserSearch do
  @moduledoc """
  Typeahead over registered people, the same shape as `UI.StepSearch`:
  a form-wrapped input firing `search_event` per keystroke, one button
  per match firing `pick_event` with the username. Submitting the form
  fires `submit_event` with whatever was typed, for whoever already
  knows the exact username.
  """

  use Phoenix.Component

  import OGrupoDeEstudosWeb.UI.UserAvatar

  attr :id, :string, required: true
  attr :suggestions, :list, default: []
  attr :placeholder, :string, required: true
  attr :field_name, :string, default: "username"
  attr :search_event, :string, required: true
  attr :pick_event, :string, required: true
  attr :submit_event, :string, default: nil
  attr :submit_label, :string, default: nil

  def user_search(assigns) do
    ~H"""
    <div id={@id} class="relative">
      <form
        id={"#{@id}-form"}
        phx-change={@search_event}
        phx-submit={@submit_event}
        autocomplete="off"
        class="flex flex-wrap items-center gap-2"
      >
        <input
          id={"#{@id}-input"}
          type="text"
          name={@field_name}
          placeholder={@placeholder}
          autocomplete="off"
          required
          phx-debounce="200"
          class="min-w-0 flex-1 rounded-full border border-ink-300 bg-ink-50 px-4 py-2 font-serif text-[13px] text-ink-800 placeholder:text-ink-400"
        />
        <button
          :if={@submit_event && @submit_label}
          type="submit"
          phx-disable-with="Adicionando..."
          class="cursor-pointer rounded-full border-0 bg-ink-900 px-4 py-2 font-serif text-[13px] font-semibold text-ink-50"
        >
          {@submit_label}
        </button>
      </form>
      <div
        :if={@suggestions != []}
        class="absolute left-0 right-0 top-[42px] z-20 overflow-hidden rounded-xl border border-ink-200 bg-ink-50 shadow-lg"
      >
        <button
          :for={user <- @suggestions}
          type="button"
          phx-click={@pick_event}
          phx-value-username={user.username}
          class="flex w-full items-center gap-2.5 border-b border-ink-200/60 px-3 py-2 text-left last:border-b-0 hover:bg-ink-100"
        >
          <.user_avatar user={user} size={:xs} />
          <span class="min-w-0 truncate text-[13px] text-ink-800">
            {user.name}
            <span class="text-ink-500">@{user.username}</span>
          </span>
        </button>
      </div>
    </div>
    """
  end
end
