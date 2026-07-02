defmodule OGrupoDeEstudosWeb.AdminSuggestionsLiveTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "access control" do
    test "redirects non-admin user to /graph/visual", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/graph/visual"}}} =
               live(log_in_user(conn, insert(:user)), ~p"/admin/suggestions")
    end

    test "redirects unauthenticated user to /login", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/admin/suggestions")
    end

    test "admin can access", %{conn: conn} do
      assert {:ok, _view, _html} =
               live(log_in_user(conn, insert(:admin)), ~p"/admin/suggestions")
    end
  end

  describe "filter tabs" do
    test "switches to the all tab", %{conn: conn} do
      {:ok, lv, _html} = live(log_in_user(conn, insert(:admin)), ~p"/admin/suggestions")

      html = render_click(lv, "filter", %{"tab" => "all"})

      assert html =~ "phx-value-tab=\"all\""
    end

    test "falls back to pending on an unknown tab", %{conn: conn} do
      {:ok, lv, _html} = live(log_in_user(conn, insert(:admin)), ~p"/admin/suggestions")

      html = render_click(lv, "filter", %{"tab" => "drop_table"})

      assert html =~ "phx-value-tab=\"pending\""
    end
  end
end
