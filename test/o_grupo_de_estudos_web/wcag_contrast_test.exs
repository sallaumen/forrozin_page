defmodule OGrupoDeEstudosWeb.WcagContrastTest do
  use ExUnit.Case, async: true
  alias OGrupoDeEstudosWeb.WcagContrast, as: W

  test "texto dark mode passa WCAG AA" do
    # ink-900 / ink-100
    assert W.ratio("#f5ede4", "#221511") >= 4.5
    # ink-600 / ink-100 (drawer nota, stats)
    assert W.ratio("#c0a080", "#221511") >= 4.5
    # ink-500 / ink-100 (texto secundario)
    assert W.ratio("#a08060", "#221511") >= 4.5
    # gold-500 / ink-100
    assert W.ratio("#e6b347", "#221511") >= 4.5
  end

  test "elementos graficos passam WCAG 3:1 em ambos os modos" do
    canvas_light = "#fffef9"
    canvas_dark = "#1a120d"
    # edge highlight (D8)
    # light
    assert W.ratio("#c4621e", canvas_light) >= 3.0
    # dark accent-orange
    assert W.ratio("#f39c12", canvas_dark) >= 3.0
    # spotlight
    assert W.ratio("#2f8f5b", canvas_light) >= 3.0
    assert W.ratio("#2f8f5b", canvas_dark) >= 3.0
    # like border (D7)
    node_dark = "#221511"
    # light
    assert W.ratio("#c0392b", "#fffef9") >= 3.0
    # dark accent-red
    assert W.ratio("#e74c3c", node_dark) >= 3.0
  end

  test "text-accent em fundo dark passa WCAG AA" do
    # text-accent-orange
    assert W.ratio("#f39c12", "#221511") >= 4.5
    # text-accent-green
    assert W.ratio("#2ecc71", "#221511") >= 4.5
  end
end
