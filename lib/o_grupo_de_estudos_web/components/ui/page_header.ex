defmodule OGrupoDeEstudosWeb.UI.PageHeader do
  @moduledoc """
  Cabeçalho padrão de página.

  Attr obrigatório: `:title`.
  Slots opcionais:
    - `:breadcrumb` — aparece acima do título
    - `:actions` — aparece ao lado do título (ex: botão Editar)

  Tamanho responsivo: `text-3xl` em mobile, `text-4xl` em desktop.
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
