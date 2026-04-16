defmodule OGrupoDeEstudosWeb.UI.IconButton do
  @moduledoc """
  Botão que contém apenas um ícone.

  Requer `:label` (vira `aria-label` — screen readers dependem disso).
  Tamanho fixo 44×44 (w-11 h-11) pra touch target compliance.
  """

  use Phoenix.Component

  import OGrupoDeEstudosWeb.CoreComponents, only: [icon: 1]

  attr :label, :string, required: true, doc: "aria-label (required for a11y)"
  attr :icon, :string, required: true, doc: "heroicon name (e.g. hero-x-mark)"

  attr :variant, :atom, values: [:default, :ghost, :danger], default: :default

  attr :type, :string, values: ~w(button submit), default: "button"
  attr :class, :any, default: nil

  attr :rest, :global, include: ~w(disabled phx-click phx-value-id data-confirm)

  def icon_button(assigns) do
    ~H"""
    <button
      type={@type}
      data-ui="icon-button"
      data-variant={@variant}
      aria-label={@label}
      class={[
        "inline-flex items-center justify-center w-11 h-11 rounded-md",
        "transition-colors cursor-pointer",
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ink-900",
        "disabled:opacity-60 disabled:cursor-not-allowed",
        "active:scale-[0.94]",
        variant_classes(@variant),
        @class
      ]}
      {@rest}
    >
      <.icon name={@icon} class="size-5" />
    </button>
    """
  end

  defp variant_classes(:default), do: "text-ink-700 hover:bg-ink-100"
  defp variant_classes(:ghost), do: "text-ink-500 hover:text-ink-900 hover:bg-ink-100"
  defp variant_classes(:danger), do: "text-accent-red hover:bg-accent-red/10"
end
