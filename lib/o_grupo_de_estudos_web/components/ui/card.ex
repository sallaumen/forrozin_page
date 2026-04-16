defmodule OGrupoDeEstudosWeb.UI.Card do
  @moduledoc """
  Padrão visual de card — container de conteúdo com fundo, borda e sombra
  suave. Usado pra passos, sequências, links etc.
  """

  use Phoenix.Component

  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(id)

  slot :inner_block, required: true

  def card(assigns) do
    ~H"""
    <div
      data-ui="card"
      class={[
        "bg-ink-50 border border-ink-200 rounded-md shadow-xs p-4",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end
end
