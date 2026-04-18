defmodule OGrupoDeEstudosWeb.UI.BottomSheet do
  @moduledoc """
  Bottom sheet / modal dialog responsivo.

  Mobile: desliza de baixo, ocupa até 85% da altura, handle visual pra
  drag-down close.
  Desktop (≥md): vira modal centralizado com overlay.

  Base: elemento `<dialog>` nativo — traz foco trap, Escape close,
  aria semantics prontos.

  Estado de abertura controlado via JS (`.showModal()` / `.close()`).
  Use `Phoenix.LiveView.JS` pra disparar:

      <button phx-click={JS.dispatch("bottom-sheet:open", to: "#my-sheet")}>
        Abrir
      </button>

  O hook `BottomSheet` em `assets/js/app.js` cuida de:
  - Listener `bottom-sheet:open` → `showModal()`
  - Listener `bottom-sheet:close` → `close()`
  - Swipe-down em mobile → close
  - Click no overlay → close
  """

  use Phoenix.Component

  import OGrupoDeEstudosWeb.CoreComponents, only: [icon: 1]

  attr :id, :string, required: true
  attr :title, :string, default: nil
  attr :class, :any, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def bottom_sheet(assigns) do
    ~H"""
    <dialog
      id={@id}
      data-ui="bottom-sheet"
      phx-hook="BottomSheet"
      phx-update="ignore"
      class={[
        "bg-transparent p-0 m-0",
        "backdrop:bg-ink-900/40",
        @class
      ]}
      {@rest}
    >
      <div
        data-bottom-sheet-content
        class={[
          "bg-ink-50 font-sans text-ink-900",
          "w-full md:w-[480px] md:max-w-[90vw]",
          "md:rounded-lg rounded-t-lg",
          "fixed bottom-0 left-0 right-0 mx-auto",
          "md:relative md:bottom-auto md:mx-auto md:my-8",
          "max-h-[85vh] md:max-h-[80vh] overflow-y-auto",
          "shadow-lg"
        ]}
      >
        <div data-bottom-sheet-handle class="md:hidden flex justify-center py-2">
          <div class="w-10 h-1 bg-ink-300 rounded-full"></div>
        </div>
        <div class={[
          "flex items-center px-4 pt-2 pb-3",
          @title && "justify-between border-b border-ink-200",
          !@title && "justify-end"
        ]}>
          <h2 :if={@title} class="text-lg font-serif font-bold text-ink-900">{@title}</h2>
          <button
            type="button"
            aria-label="Fechar"
            class="w-11 h-11 inline-flex items-center justify-center text-ink-500 hover:text-ink-900 rounded-md"
            phx-click={Phoenix.LiveView.JS.dispatch("bottom-sheet:close", to: "##{@id}")}
          >
            <.icon name="hero-x-mark" class="size-5" />
          </button>
        </div>
        <div class="px-4 py-4">
          {render_slot(@inner_block)}
        </div>
      </div>
    </dialog>
    """
  end
end
