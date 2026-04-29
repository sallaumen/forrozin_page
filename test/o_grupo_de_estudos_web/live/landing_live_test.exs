defmodule OGrupoDeEstudosWeb.LandingLiveTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "mount — public" do
    test "renders title and tagline", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")
      assert html =~ "O Grupo de Estudos"
      assert html =~ "wiki de forró"
    end

    test "displays signup and login CTAs for visitors", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")
      assert html =~ "Criar conta"
      assert html =~ "Entrar"
    end

    test "displays about link in footer", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")
      assert html =~ "Quem somos"
    end

    test "shows feature sections", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")
      assert html =~ "Mapa de conexões"
      assert html =~ "Diário de treino"
      assert html =~ "Comunidade"
      assert html =~ "gratuito"
    end
  end

  describe "mount — authenticated" do
    test "redirects to /collection when logged in", %{conn: conn} do
      user = insert(:user)
      conn = log_in_user(conn, user)
      {:error, {:redirect, %{to: "/collection"}}} = live(conn, ~p"/")
    end
  end
end
