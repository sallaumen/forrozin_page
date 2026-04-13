defmodule ForrozinWeb.PassoLiveTest do
  use ForrozinWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defp conn_logado(conn) do
    user = insert(:user)
    log_in_user(conn, user)
  end

  describe "acesso" do
    test "redireciona para /entrar se não autenticado", %{conn: conn} do
      {:error, {:redirect, %{to: "/entrar"}}} = live(conn, ~p"/passos/BF")
    end

    test "redireciona para /acervo se o passo não existe", %{conn: conn} do
      {:error, {:redirect, %{to: "/acervo"}}} = live(conn_logado(conn), ~p"/passos/INEXISTENTE")
    end
  end

  describe "detalhe do passo" do
    test "exibe nome e código do passo", %{conn: conn} do
      secao = insert(:secao)
      insert(:passo, secao: secao, codigo: "BF", nome: "Base Frontal")
      {:ok, _lv, html} = live(conn_logado(conn), ~p"/passos/BF")
      assert html =~ "Base Frontal"
      assert html =~ "BF"
    end

    test "exibe nota técnica quando presente", %{conn: conn} do
      secao = insert(:secao)

      insert(:passo,
        secao: secao,
        codigo: "BF2",
        nome: "Base Frontal",
        nota: "Descrição mecânica do passo."
      )

      {:ok, _lv, html} = live(conn_logado(conn), ~p"/passos/BF2")
      assert html =~ "Descrição mecânica do passo."
    end

    test "não exibe passo wip para usuário comum", %{conn: conn} do
      secao = insert(:secao)
      insert(:passo, secao: secao, codigo: "WIP1", nome: "Passo WIP", wip: true)
      {:error, {:redirect, %{to: "/acervo"}}} = live(conn_logado(conn), ~p"/passos/WIP1")
    end
  end
end
