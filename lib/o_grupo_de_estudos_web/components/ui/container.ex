defmodule OGrupoDeEstudosWeb.UI.Container do
  @moduledoc """
  Responsive content wrapper.

  Caps content width at `max-w-4xl` and applies responsive horizontal padding
  (`px-4 sm:px-6 lg:px-8`). Designed to be the outermost wrapper of main page
  content so that layout is consistent across the app.
  """

  use Phoenix.Component

  attr :class, :any, default: nil, doc: "extra classes appended to the base set"
  attr :rest, :global

  slot :inner_block, required: true

  def container(assigns) do
    ~H"""
    <div
      data-ui="container"
      class={["w-full max-w-4xl mx-auto px-4 sm:px-6 lg:px-8", @class]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end
end
