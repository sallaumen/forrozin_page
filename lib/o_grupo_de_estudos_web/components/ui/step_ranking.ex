defmodule OGrupoDeEstudosWeb.UI.StepRanking do
  use Phoenix.Component

  attr :ranking, :list, required: true
  attr :total_notes, :integer, default: 0

  def step_ranking(assigns) do
    max_count =
      case assigns.ranking do
        [first | _] -> first.count
        [] -> 1
      end

    assigns = assign(assigns, :max_count, max_count)

    ~H"""
    <div :if={@ranking != []}>
      <div class="space-y-2">
        <%= for {step, idx} <- Enum.with_index(@ranking) do %>
          <div class="flex items-center gap-2">
            <div class={[
              "w-5 h-5 rounded-full flex items-center justify-center text-[10px] font-bold shrink-0",
              idx < 3 && "bg-accent-orange text-white",
              idx >= 3 && "bg-ink-200 text-ink-500"
            ]}>
              {idx + 1}
            </div>
            <div class="flex-1 min-w-0">
              <div class="flex justify-between items-center">
                <span class="text-[11px] font-semibold text-ink-900 truncate">
                  {step.code} · {step.name}
                </span>
                <span class="text-[10px] text-ink-400 font-medium shrink-0 ml-2">{step.count}x</span>
              </div>
              <div class="mt-1 h-1 bg-ink-100 rounded-full overflow-hidden">
                <div
                  class={[
                    "h-full rounded-full",
                    idx == 0 && "bg-accent-orange",
                    idx == 1 && "bg-gold-500",
                    idx == 2 && "bg-gold-500/60",
                    idx >= 3 && "bg-ink-300"
                  ]}
                  style={"width: #{round(step.count / @max_count * 100)}%;"}
                />
              </div>
            </div>
          </div>
        <% end %>
      </div>
      <p :if={@total_notes > 0} class="text-[10px] text-ink-400 text-center mt-3 m-0">
        {length(@ranking)} passos distintos em {@total_notes} {if @total_notes == 1,
          do: "aula",
          else: "aulas"}
      </p>
    </div>
    """
  end
end
