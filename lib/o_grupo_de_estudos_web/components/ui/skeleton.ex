defmodule OGrupoDeEstudosWeb.UI.Skeleton do
  @moduledoc """
  Animated loading placeholder: a pulsing rectangle.

  Decorative: `aria-hidden=true` so screen readers skip it. Use :class to set
  height and width.
  """

  use Phoenix.Component

  attr :class, :any, default: "h-6 w-full"
  attr :rest, :global

  def skeleton(assigns) do
    ~H"""
    <div
      data-ui="skeleton"
      aria-hidden="true"
      class={["bg-ink-200 rounded-sm animate-pulse", @class]}
      {@rest}
    >
    </div>
    """
  end
end
