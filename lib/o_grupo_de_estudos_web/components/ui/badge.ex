defmodule OGrupoDeEstudosWeb.UI.Badge do
  @moduledoc """
  Pílula pequena pra tags, categorias, status, códigos.

  Variantes:
  - `:neutral` (default) — cinza/ink
  - `:info` — azul
  - `:success` — verde
  - `:warning` — laranja
  - `:danger` — vermelho
  - `:accent` — dourado (gold)
  """

  use Phoenix.Component

  attr :variant, :atom,
    values: [:neutral, :info, :success, :warning, :danger, :accent],
    default: :neutral

  attr :class, :any, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def badge(assigns) do
    ~H"""
    <span
      data-ui="badge"
      data-variant={@variant}
      class={[
        "inline-flex items-center px-2 py-0.5 rounded-sm text-xs font-sans font-medium",
        variant_classes(@variant),
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </span>
    """
  end

  defp variant_classes(:neutral), do: "bg-ink-100 text-ink-700"
  defp variant_classes(:info), do: "bg-ink-100 text-accent-blue"
  defp variant_classes(:success), do: "bg-ink-100 text-accent-green"
  defp variant_classes(:warning), do: "bg-ink-100 text-accent-orange"
  defp variant_classes(:danger), do: "bg-ink-100 text-accent-red"
  defp variant_classes(:accent), do: "bg-gold-400/30 text-ink-900"
end
