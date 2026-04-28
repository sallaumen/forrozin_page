defmodule OGrupoDeEstudosWeb.UI.GoalsBoard do
  use Phoenix.Component
  import OGrupoDeEstudosWeb.CoreComponents, only: [icon: 1]

  attr :goals, :list, required: true
  attr :goal_input, :string, default: ""
  attr :create_event, :string, default: "create_goal"
  attr :toggle_event, :string, default: "toggle_goal"
  attr :delete_event, :string, default: "delete_goal"

  def goals_board(assigns) do
    pending = Enum.reject(assigns.goals, & &1.completed)
    completed = Enum.filter(assigns.goals, & &1.completed)
    assigns = assign(assigns, pending: pending, completed: completed)

    ~H"""
    <div>
      <%!-- Add goal form --%>
      <form phx-submit={@create_event} class="flex gap-2 mb-3">
        <input
          type="text"
          name="body"
          value={@goal_input}
          placeholder="Nova meta..."
          autocomplete="off"
          required
          class="flex-1 rounded-lg border border-ink-200 bg-ink-50/80 px-2.5 py-1.5 font-serif text-xs text-ink-700 box-border outline-none transition-colors focus:border-accent-orange/40"
        />
        <button
          type="submit"
          class="text-xs font-bold text-white bg-accent-orange rounded-lg px-3 py-1.5 cursor-pointer border-0 hover:bg-accent-orange/90 transition-colors shrink-0"
        >
          +
        </button>
      </form>

      <%!-- Pending goals --%>
      <%= if @pending != [] do %>
        <div class="space-y-1">
          <%= for goal <- @pending do %>
            <div class="flex items-start gap-2 group rounded-lg px-1.5 py-1 hover:bg-ink-50 transition-colors">
              <button
                type="button"
                phx-click={@toggle_event}
                phx-value-id={goal.id}
                class="mt-0.5 w-4 h-4 rounded border border-ink-300 bg-white cursor-pointer shrink-0 flex items-center justify-center hover:border-accent-orange transition-colors"
              />
              <p class="text-xs text-ink-800 m-0 flex-1 leading-relaxed">{goal.body}</p>
              <button
                type="button"
                phx-click={@delete_event}
                phx-value-id={goal.id}
                class="opacity-0 group-hover:opacity-100 transition-opacity text-ink-400 hover:text-accent-red cursor-pointer bg-transparent border-0 p-0 shrink-0"
              >
                <.icon name="hero-x-mark" class="w-3.5 h-3.5" />
              </button>
            </div>
          <% end %>
        </div>
      <% end %>

      <%!-- Empty state --%>
      <p
        :if={@pending == [] && @completed == []}
        class="text-xs text-ink-400 italic m-0 py-2 text-center"
      >
        Sem metas ainda. Adicione acima!
      </p>

      <%!-- Completed goals (collapsible) --%>
      <%= if @completed != [] do %>
        <details class="mt-2">
          <summary class="text-[10px] text-ink-400 cursor-pointer font-semibold select-none">
            {length(@completed)} {if length(@completed) == 1, do: "concluida", else: "concluidas"}
          </summary>
          <div class="mt-1 space-y-1">
            <%= for goal <- @completed do %>
              <div class="flex items-start gap-2 group rounded-lg px-1.5 py-1 hover:bg-ink-50 transition-colors">
                <button
                  type="button"
                  phx-click={@toggle_event}
                  phx-value-id={goal.id}
                  class="mt-0.5 w-4 h-4 rounded border border-accent-green bg-accent-green cursor-pointer shrink-0 flex items-center justify-center"
                >
                  <.icon name="hero-check" class="w-3 h-3 text-white" />
                </button>
                <p class="text-xs text-ink-400 m-0 flex-1 leading-relaxed line-through">
                  {goal.body}
                </p>
                <button
                  type="button"
                  phx-click={@delete_event}
                  phx-value-id={goal.id}
                  class="opacity-0 group-hover:opacity-100 transition-opacity text-ink-400 hover:text-accent-red cursor-pointer bg-transparent border-0 p-0 shrink-0"
                >
                  <.icon name="hero-x-mark" class="w-3.5 h-3.5" />
                </button>
              </div>
            <% end %>
          </div>
        </details>
      <% end %>
    </div>
    """
  end
end
