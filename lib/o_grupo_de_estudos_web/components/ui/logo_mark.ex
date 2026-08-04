defmodule OGrupoDeEstudosWeb.UI.LogoMark do
  @moduledoc """
  The brand mark: two dancers whose arms close into an open circle.

  Inline SVG on purpose. As an `<img>` it would cost one more request, and the
  mark has to be on screen at the very first paint, both in the top nav and in
  the loading splash. Fills and strokes use `currentColor`, so the surrounding
  text color drives the mark and dark mode needs no extra rule.

  `label` is what assistive technology reads. The nav passes `"O"` so the mark
  plus the adjacent "Grupo de Estudos" reads as the whole name. With no label
  the mark is decorative and screen readers skip it.

  The default viewbox is the tight bounding box. The splash passes the full
  512 square instead, so the mark spins around its own center.
  """

  use Phoenix.Component

  attr :class, :any, default: nil
  attr :viewbox, :string, default: "96 76 320 384"
  attr :label, :string, default: nil
  attr :rest, :global

  def logo_mark(assigns) do
    ~H"""
    <svg
      data-ui="logo-mark"
      class={@class}
      viewBox={@viewbox}
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      role={@label && "img"}
      aria-label={@label}
      aria-hidden={is_nil(@label) && "true"}
      {@rest}
    >
      <g fill="currentColor">
        <circle cx="200" cy="110" r="34" />
        <circle cx="312" cy="110" r="34" />
      </g>
      <g fill="none" stroke="currentColor" stroke-width="40" stroke-linecap="round">
        <path d="M212.8 166.9 A140 140 0 0 0 212.8 433.1" />
        <path d="M299.2 166.9 A140 140 0 0 1 299.2 433.1" />
      </g>
    </svg>
    """
  end
end
