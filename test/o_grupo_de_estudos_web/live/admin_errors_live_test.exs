defmodule OGrupoDeEstudosWeb.AdminErrorsLiveTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "access control" do
    test "redirects non-admin user to /graph/visual", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/graph/visual"}}} =
               live(log_in_user(conn, insert(:user)), ~p"/admin/errors")
    end

    test "redirects unauthenticated user to /login", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/admin/errors")
    end

    test "admin can access", %{conn: conn} do
      assert {:ok, _view, _html} =
               live(log_in_user(conn, insert(:admin)), ~p"/admin/errors")
    end
  end
end
