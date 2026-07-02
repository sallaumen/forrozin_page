defmodule OGrupoDeEstudosWeb.AdminDashboardTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  describe "GET /admin/dashboard" do
    test "redirects unauthenticated user to /login", %{conn: conn} do
      conn = get(conn, "/admin/dashboard")

      assert redirected_to(conn) == "/login"
    end

    test "redirects non-admin user away", %{conn: conn} do
      conn =
        conn
        |> log_in_user(insert(:user))
        |> get("/admin/dashboard")

      assert redirected_to(conn) == "/graph/visual"
    end

    test "admin reaches the live dashboard home", %{conn: conn} do
      conn = log_in_user(conn, insert(:admin))

      redirect = conn |> get("/admin/dashboard") |> redirected_to()
      assert redirect =~ "/admin/dashboard/home"

      home = conn |> get(redirect) |> html_response(200)
      assert home =~ "Dashboard"
    end
  end
end
