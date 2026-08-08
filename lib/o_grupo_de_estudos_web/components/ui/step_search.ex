defmodule OGrupoDeEstudosWeb.UI.StepSearch do
  @moduledoc """
  Typeahead over the step collection: a form-wrapped input firing
  `search_event` per keystroke (debounced), one button per match firing
  `add_event` with the step id.

  The app-wide standard picker for steps; the study diary, the shared
  lessons and the workshop step list all render this same shape.
  """

  use Phoenix.Component

  attr :id, :string, required: true
  attr :suggestions, :list, default: []
  attr :placeholder, :string, default: "+ Vincular passo..."
  attr :disabled, :boolean, default: false
  attr :search_event, :string, required: true
  attr :add_event, :string, required: true
  attr :rest, :global, include: ~w(phx-value-note-id)

  def step_search(assigns) do
    ~H"""
    <div id={@id} class="relative">
      <form phx-change={@search_event} autocomplete="off" {@rest}>
        <input
          id={"#{@id}-input"}
          type="text"
          name="term"
          value=""
          placeholder={@placeholder}
          disabled={@disabled}
          phx-debounce="200"
          class="w-full rounded-lg border border-ink-200 bg-ink-50/80 px-3 py-2 font-serif text-xs text-ink-700 outline-none transition-colors focus:border-accent-orange/40 disabled:opacity-60"
        />
      </form>
      <div
        :if={@suggestions != []}
        class="absolute left-0 right-0 top-[42px] z-20 overflow-hidden rounded-xl border border-ink-200 bg-ink-50 shadow-lg"
      >
        <button
          :for={step <- @suggestions}
          type="button"
          phx-click={@add_event}
          phx-value-id={step.id}
          phx-value-step-id={step.id}
          {@rest}
          class="flex w-full items-center justify-between gap-2 border-b border-ink-200/60 px-3 py-2.5 text-left last:border-b-0 hover:bg-ink-100"
        >
          <span class="min-w-0 truncate text-xs text-ink-800">
            <code class="font-bold text-accent-orange">{step.code}</code>
            {step.name}
          </span>
          <span class="shrink-0 text-[10px] font-semibold text-accent-orange">Adicionar</span>
        </button>
      </div>
    </div>
    """
  end
end
