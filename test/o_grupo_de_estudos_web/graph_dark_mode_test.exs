defmodule OGrupoDeEstudosWeb.GraphDarkModeTest do
  use ExUnit.Case, async: true

  test "tokens dark sepia quente presentes em app.css" do
    css = File.read!("assets/css/app.css")
    assert css =~ ~r/--color-ink-50:\s*#1a120d/
    assert css =~ ~r/--color-ink-100:\s*#221511/
    assert css =~ ~r/--color-ink-900:\s*#f5ede4/
  end

  # FOR-39 fix 1: accent-warning text precisa de override no bloco .dark {}
  test "dark mode define --color-accent-warning com contraste WCAG AA" do
    css = File.read!("assets/css/app.css")
    # Verifica que o token existe dentro do bloco .dark {}
    assert css =~ ~r/\.dark\s*\{[^}]*--color-accent-warning:\s*#f0c050/s,
           "falta --color-accent-warning: #f0c050 no bloco .dark {} (contraste 7.3:1 exigido)"
  end

  # FOR-39 fix 2: aba ativa do segmented control visível em dark
  test "segmented control aba ativa usa dark:bg-ink-300 para visibilidade" do
    heex = File.read!("lib/o_grupo_de_estudos_web/live/graph_visual_live.html.heex")

    assert heex =~ "dark:bg-ink-300",
           "aba ativa do segmented control precisa de dark:bg-ink-300"
  end

  # Os icones de curtir/favoritar do drawer agora sao server-side (StepDetail
  # mode :drawer, compartilhado com a Collection): o dark mode vem dos tokens
  # ink-* no bloco .dark {}, sem logica de cor em JS para regredir.

  # FOR-39 fix 4: separadores de linha visíveis em dark mode
  test "cards de sequencia usam dark:border-ink-400/20 nos separadores" do
    heex = File.read!("lib/o_grupo_de_estudos_web/live/graph_visual_live.html.heex")

    assert heex =~ "dark:border-ink-400/20",
           "separadores de linha nos cards precisam de dark:border-ink-400/20"
  end
end
