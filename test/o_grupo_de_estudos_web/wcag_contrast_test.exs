defmodule OGrupoDeEstudosWeb.WcagContrastTest do
  use ExUnit.Case, async: true
  alias OGrupoDeEstudosWeb.WcagContrast, as: W

  @ink_100_dark "#221511"
  @ink_500 "#a08060"
  @ink_600 "#c0a080"
  @ink_900_light "#f5ede4"
  @gold_500 "#e6b347"

  @canvas_light "#fffef9"
  @canvas_dark "#1a120d"
  @edge_highlight_light "#c4621e"
  @accent_orange_dark "#f39c12"
  @spotlight "#2f8f5b"
  @like_border_light "#c0392b"
  @accent_red_dark "#e74c3c"
  @accent_green_dark "#2ecc71"

  test "dark mode text passes WCAG AA" do
    assert W.ratio(@ink_900_light, @ink_100_dark) >= 4.5
    assert W.ratio(@ink_600, @ink_100_dark) >= 4.5
    assert W.ratio(@ink_500, @ink_100_dark) >= 4.5
    assert W.ratio(@gold_500, @ink_100_dark) >= 4.5
  end

  test "graphic elements pass WCAG 3:1 in both modes" do
    assert W.ratio(@edge_highlight_light, @canvas_light) >= 3.0
    assert W.ratio(@accent_orange_dark, @canvas_dark) >= 3.0
    assert W.ratio(@spotlight, @canvas_light) >= 3.0
    assert W.ratio(@spotlight, @canvas_dark) >= 3.0
    assert W.ratio(@like_border_light, @canvas_light) >= 3.0
    assert W.ratio(@accent_red_dark, @ink_100_dark) >= 3.0
  end

  test "accent text on a dark background passes WCAG AA" do
    assert W.ratio(@accent_orange_dark, @ink_100_dark) >= 4.5
    assert W.ratio(@accent_green_dark, @ink_100_dark) >= 4.5
  end
end
