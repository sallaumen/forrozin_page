defmodule OGrupoDeEstudosWeb.UI.Skeleton do
  @moduledoc """
  Placeholder animado de loading — retângulo pulsando.

  Decorativo: `aria-hidden=true` pra não ser lido por screen readers.
  Use :class pra definir altura/largura.
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
