defmodule OGrupoDeEstudosWeb.AgendaRailTest do
  @moduledoc """
  The left rail of the agenda, and why it stopped being a box.

  The date used to sit in a 54px bordered square. The row aligns on the
  baseline, and a column flex container's baseline is the one of the text inside
  it — so the number lined up with the title while the border did not: it rose
  13px above the title and stopped 25px short of the block, leaving the two
  centres 19px apart. A bordered box is read by its edges, so the whole row
  looked crooked even though the type was aligned.

  Without the border there is no edge to misalign, and the date now matches the
  hour rail of `agenda_row/1`, which is the same idea in the sibling list.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias OGrupoDeEstudosWeb.WorkshopComponents

  defp date_rail do
    render_component(&WorkshopComponents.date_block/1, datetime: ~U[2026-08-21 22:00:00Z])
  end

  test "the date is type on the page, not a box drawn around it" do
    html = date_rail()

    assert html =~ "21"
    assert html =~ "ago", "o mês vem em caixa baixa e sobe por CSS, não no conteúdo"
    assert html =~ "uppercase"

    refute html =~ "border-ink-200", "borda é a aresta que desalinhava com o título"
    refute html =~ "h-[54px]"
  end

  test "the date rail is as wide as the hour rail of the sibling list" do
    componentes = File.read!("lib/o_grupo_de_estudos_web/components/workshop_components.ex")

    trilhos =
      ~r/w-\[3\.1rem\][^"]*sm:w-\[3\.4rem\]/
      |> Regex.scan(componentes)
      |> length()

    assert trilhos >= 3,
           "data, hora e programação usam a mesma coluna; larguras diferentes desalinham as listas"
  end

  test "the day is the one being read in Brazil, not in UTC" do
    # 21/08 às 22h UTC é ainda dia 21 às 19h em Curitiba.
    assert date_rail() =~ "21"

    # 22/08 às 02h UTC já é dia 21 às 23h em Curitiba: a data do fuso local manda.
    html = render_component(&WorkshopComponents.date_block/1, datetime: ~U[2026-08-22 02:00:00Z])

    assert html =~ "21"
  end
end
