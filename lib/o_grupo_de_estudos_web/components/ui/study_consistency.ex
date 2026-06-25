defmodule OGrupoDeEstudosWeb.UI.StudyConsistency do
  @moduledoc false
  use Phoenix.Component

  attr :weekly_note_count, :integer, required: true
  attr :monthly_note_count, :integer, required: true
  attr :today_status, :map, required: true
  attr :month_name, :string, required: true

  def study_consistency(assigns) do
    ~H"""
    <div id="study-weekly-summary" class="max-w-[1500px] mx-auto px-4 py-2 flex items-center gap-2">
      <%= if @monthly_note_count > 0 do %>
        <span class="text-xs font-semibold text-ink-700">
          {@monthly_note_count} {if @monthly_note_count == 1, do: "registro", else: "registros"} em {@month_name}
        </span>
        <div class="flex gap-1 ml-auto" aria-label="Progresso semanal">
          <%= for i <- 1..7 do %>
            <div class={[
              "w-2 h-2 rounded-full",
              i <= @weekly_note_count && "bg-gold-500",
              i > @weekly_note_count && "bg-ink-200"
            ]}>
            </div>
          <% end %>
        </div>
        <span class={[
          "rounded-full border px-2 py-0.5 text-[10px] font-semibold shrink-0",
          @today_status.tone == :success &&
            "border-accent-green/25 bg-accent-green/10 text-accent-green",
          @today_status.tone == :warning &&
            "border-accent-orange/25 bg-accent-orange/10 text-accent-orange"
        ]}>
          {@today_status.label}
        </span>
      <% else %>
        <span class="text-xs text-ink-500">
          Nenhum registro em {@month_name} ainda. Comece hoje!
        </span>
        <span class="ml-auto rounded-full border border-accent-orange/25 bg-accent-orange/10 text-accent-orange px-2 py-0.5 text-[10px] font-semibold shrink-0">
          {@today_status.label}
        </span>
      <% end %>
    </div>
    """
  end
end
