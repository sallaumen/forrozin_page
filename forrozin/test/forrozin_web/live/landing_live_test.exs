defmodule ForrozinWeb.LandingLiveTest do
  use ForrozinWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "mount — público" do
    test "renderiza o título e tagline", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")
      assert html =~ "O grupo de estudos"
      assert html =~ "Forró roots"
    end

    test "exibe CTAs de cadastro e login para visitante", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")
      assert html =~ "Quero estudar"
      assert html =~ "Já tenho conta"
    end

    test "exibe seção do autor", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")
      assert html =~ "L. Tavano"
    end
  end

  describe "mount — autenticado" do
    test "exibe link para o acervo em vez dos CTAs de cadastro", %{conn: conn} do
      user = insert(:user)
      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/")
      assert html =~ "Ir para o acervo"
      refute html =~ "Quero estudar"
    end
  end
end
