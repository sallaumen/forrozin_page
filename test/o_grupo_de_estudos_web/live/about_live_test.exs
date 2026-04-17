defmodule OGrupoDeEstudosWeb.AboutLiveTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "renders about page", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/about")
    assert html =~ "O Grupo de Estudos" or html =~ "Grupo de Estudos" or html =~ "forró"
  end
end
