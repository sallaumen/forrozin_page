defmodule OGrupoDeEstudosWeb.AdminErrorsLiveTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.Admin.ErrorLog
  alias OGrupoDeEstudos.Repo

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

  describe "error list (streams)" do
    setup %{conn: conn}, do: %{conn: log_in_user(conn, insert(:admin))}

    defp log_error(msg), do: Repo.insert!(%ErrorLog{level: :error, message: msg})

    test "renders logged errors and the loaded count", %{conn: conn} do
      log_error("boom-alpha")
      log_error("boom-beta")

      {:ok, _lv, html} = live(conn, ~p"/admin/errors")

      assert html =~ "boom-alpha"
      assert html =~ "boom-beta"
      assert html =~ "2 erro(s) carregados"
    end

    test "clear_all resets the stream and shows the empty state", %{conn: conn} do
      log_error("to-be-cleared")
      {:ok, lv, _html} = live(conn, ~p"/admin/errors")

      html = render_click(lv, "clear_all", %{})

      assert html =~ "Nenhum erro registrado"
      assert html =~ "0 erro(s) carregados"
      assert Repo.aggregate(ErrorLog, :count) == 0
    end

    test "load_more streams the next page", %{conn: conn} do
      for i <- 1..51, do: log_error("err-#{i}")

      {:ok, lv, html} = live(conn, ~p"/admin/errors")
      assert html =~ "50 erro(s) carregados"
      assert html =~ "Carregar mais"

      html = render_click(lv, "load_more", %{})
      assert html =~ "51 erro(s) carregados"
      refute html =~ "Carregar mais"
    end
  end
end
