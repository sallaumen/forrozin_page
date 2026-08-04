defmodule OGrupoDeEstudosWeb.UI.BackButton do
  @moduledoc """
  Back button for the detail navigation context on mobile.

  Behavior through the `BackButton` JS hook:
  - when `window.history.length > 1`, calls `history.back()` (back to the page it
    came from)
  - otherwise navigates to `:fallback` (default `/collection`)

  It accepts several instances on the same page through `:id`.
  """

  use Phoenix.Component

  import OGrupoDeEstudosWeb.CoreComponents, only: [icon: 1]

  attr :id, :string, default: "back-button"
  attr :label, :string, default: "Voltar"
  attr :fallback, :string, default: "/collection"
  attr :class, :any, default: nil

  def back_button(assigns) do
    ~H"""
    <button
      type="button"
      id={@id}
      data-ui="back-button"
      data-fallback={@fallback}
      aria-label={@label}
      phx-hook="BackButton"
      class={[
        "inline-flex h-11 items-center gap-1 rounded-md pl-1.5 pr-3",
        "text-ink-100 hover:bg-ink-700 active:scale-95 transition-colors",
        "cursor-pointer",
        @class
      ]}
    >
      <.icon name="hero-chevron-left" class="size-5 shrink-0" />
      <span class="text-sm font-semibold">{@label}</span>
    </button>
    """
  end
end
