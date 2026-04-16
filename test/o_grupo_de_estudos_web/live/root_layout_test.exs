defmodule OGrupoDeEstudosWeb.RootLayoutTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "root layout" do
    test "viewport meta includes viewport-fit=cover for safe-area support", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ ~s(<meta name="viewport")
      assert html =~ "viewport-fit=cover",
             "viewport meta should include viewport-fit=cover to enable safe-area-inset"
    end

    test "viewport meta includes width=device-width and initial-scale=1", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "width=device-width"
      assert html =~ "initial-scale=1"
    end
  end
end
