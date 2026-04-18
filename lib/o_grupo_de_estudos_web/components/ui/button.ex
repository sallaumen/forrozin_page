defmodule OGrupoDeEstudosWeb.UI.Button do
  @moduledoc """
  Botão primário da UI.

  Variantes: `:primary` (padrão), `:ghost`, `:danger`.
  Tamanhos: `:sm`, `:md` (padrão), `:lg`.

  Todos os tamanhos forçam `min-h-[44px]` pra touch target compliance.
  Loading desabilita e mostra spinner.
  """

  use Phoenix.Component

  import OGrupoDeEstudosWeb.CoreComponents, only: [icon: 1]

  attr :variant, :atom, values: [:primary, :ghost, :danger], default: :primary
  attr :size, :atom, values: [:sm, :md, :lg], default: :md
  attr :type, :string, values: ~w(button submit reset), default: "button"
  attr :loading, :boolean, default: false
  attr :class, :any, default: nil

  attr :rest, :global, include: ~w(disabled phx-click phx-value-id data-confirm name value form)

  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      data-ui="button"
      data-variant={@variant}
      data-size={@size}
      disabled={@loading}
      class={[
        base_classes(),
        size_classes(@size),
        variant_classes(@variant),
        @class
      ]}
      {@rest}
    >
      <span :if={@loading} class="inline-flex items-center mr-2">
        <.icon name="hero-arrow-path" class="size-4 animate-spin" />
      </span>
      {render_slot(@inner_block)}
    </button>
    """
  end

  defp base_classes do
    "inline-flex items-center justify-center font-sans font-medium rounded-md " <>
      "transition-colors focus-visible:outline-none focus-visible:ring-2 " <>
      "focus-visible:ring-ink-900 focus-visible:ring-offset-2 " <>
      "disabled:opacity-60 disabled:cursor-not-allowed cursor-pointer " <>
      "active:scale-[0.97]"
  end

  defp size_classes(:sm), do: "h-8 min-h-[44px] px-3 text-sm"
  defp size_classes(:md), do: "h-10 min-h-[44px] px-4 text-sm"
  defp size_classes(:lg), do: "h-12 min-h-[44px] px-5 text-base"

  defp variant_classes(:primary), do: "bg-ink-900 text-ink-100 hover:bg-ink-800"

  defp variant_classes(:ghost),
    do: "bg-transparent text-ink-700 border border-ink-300 hover:bg-ink-100"

  defp variant_classes(:danger), do: "bg-accent-red text-ink-100 hover:opacity-90"
end
