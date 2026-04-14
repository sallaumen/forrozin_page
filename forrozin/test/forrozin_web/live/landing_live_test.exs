defmodule ForrozinWeb.LandingLiveTest do
  use ForrozinWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "mount — public" do
    test "renders title and tagline", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")
      assert html =~ "O grupo de estudos"
      assert html =~ "Forró roots"
    end

    test "displays signup and login CTAs for visitors", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")
      assert html =~ "Quero estudar"
      assert html =~ "Já tenho conta"
    end

    test "displays author section", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")
      assert html =~ "L. Tavano"
    end
  end

  describe "mount — authenticated" do
    test "displays link to collection instead of signup CTAs", %{conn: conn} do
      user = insert(:user)
      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/")
      assert html =~ "Ir para o acervo"
      refute html =~ "Quero estudar"
    end
  end
end
