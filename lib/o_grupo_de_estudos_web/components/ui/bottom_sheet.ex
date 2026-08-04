defmodule OGrupoDeEstudosWeb.UI.BottomSheet do
  @moduledoc """
  Responsive bottom sheet / modal dialog.

  Mobile: slides up from the bottom, takes up to 85% of the height, with a visual
  handle for drag-down close.
  Desktop (>=md): becomes a centered modal with an overlay.

  Base: the native `<dialog>` element, which brings focus trap, Escape close and
  aria semantics ready.

  The open state is controlled through JS (`.showModal()` / `.close()`).
  Use `Phoenix.LiveView.JS` to trigger it:

      <button phx-click={JS.dispatch("bottom-sheet:open", to: "#my-sheet")}>
        Abrir
      </button>

  The `BottomSheet` hook in `assets/js/app.js` takes care of:
  - the `bottom-sheet:open` listener, calling `showModal()`
  - the `bottom-sheet:close` listener, calling `close()`
  - swipe-down on mobile, which closes
  - a click on the overlay, which closes
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
