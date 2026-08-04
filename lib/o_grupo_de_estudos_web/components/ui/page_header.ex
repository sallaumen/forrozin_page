defmodule OGrupoDeEstudosWeb.UI.PageHeader do
  @moduledoc """
  Standard page header.

  Required attr: `:title`.
  Optional slots:
    - `:breadcrumb` shows above the title
    - `:actions` shows next to the title (an edit button, for instance)

  Responsive size: `text-3xl` on mobile, `text-4xl` on desktop.
  """

  use Phoenix.Component

  attr :title, :string, required: true
  attr :class, :any, default: nil

  slot :breadcrumb
  slot :actions

  def page_header(assigns) do
    ~H"""
    <header data-ui="page-header" class={["mb-6", @class]}>
      <div :if={@breadcrumb != []} class="text-xs text-ink-500 font-sans mb-2">
        {render_slot(@breadcrumb)}
      </div>
      <div class="flex items-start justify-between gap-4 flex-wrap">
        <h1 class="font-serif text-3xl md:text-4xl font-bold text-ink-900 leading-tight">
          {@title}
        </h1>
        <div :if={@actions != []} class="flex items-center gap-2 flex-shrink-0">
          {render_slot(@actions)}
        </div>
      </div>
    </header>
    """
  end
end
