defmodule ForrozinWeb.AcervoLiveTest do
  use ForrozinWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  defp conn_logado(conn) do
    user = insert(:user)
    log_in_user(conn, user)
  end

  describe "acesso" do
    test "redireciona para /entrar se não autenticado", %{conn: conn} do
      {:error, {:redirect, %{to: "/entrar"}}} = live(conn, ~p"/acervo")
    end
  end

  describe "mount — autenticado" do
    test "exibe títulos das seções cadastradas", %{conn: conn} do
      insert(:secao, titulo: "Bases", posicao: 1)
      {:ok, _lv, html} = live(conn_logado(conn), ~p"/acervo")
      assert html =~ "Bases"
    end

    test "não exibe passos wip ao expandir a seção", %{conn: conn} do
      secao = insert(:secao)
      insert(:passo, secao: secao, nome: "Base frontal", wip: false)
      insert(:passo, secao: secao, nome: "Sacada Suspensa", wip: true)
      {:ok, lv, _html} = live(conn_logado(conn), ~p"/acervo")
      html = render_click(lv, "expandir_tudo", %{})
      assert html =~ "Base frontal"
      refute html =~ "Sacada Suspensa"
    end

    test "não exibe passos com status rascunho", %{conn: conn} do
      secao = insert(:secao)
      insert(:passo, secao: secao, nome: "Publicado", status: "publicado")
      insert(:passo, secao: secao, nome: "Rascunho", status: "rascunho")
      {:ok, lv, _html} = live(conn_logado(conn), ~p"/acervo")
      html = render_click(lv, "expandir_tudo", %{})
      assert html =~ "Publicado"
      refute html =~ "Rascunho"
    end
  end

  describe "busca" do
    test "exibe passos que correspondem ao termo", %{conn: conn} do
      secao = insert(:secao)
      insert(:passo, secao: secao, nome: "Base frontal")
      insert(:passo, secao: secao, nome: "Sacada simples")
      {:ok, lv, _html} = live(conn_logado(conn), ~p"/acervo")
      html = render_change(lv, "buscar", %{"termo" => "base"})
      assert html =~ "Base frontal"
      refute html =~ "Sacada simples"
    end

    test "busca é case-insensitive", %{conn: conn} do
      secao = insert(:secao)
      insert(:passo, secao: secao, nome: "Base frontal")
      {:ok, lv, _html} = live(conn_logado(conn), ~p"/acervo")
      html = render_change(lv, "buscar", %{"termo" => "BASE"})
      assert html =~ "Base frontal"
    end

    test "busca sem resultado exibe mensagem", %{conn: conn} do
      {:ok, lv, _html} = live(conn_logado(conn), ~p"/acervo")
      html = render_change(lv, "buscar", %{"termo" => "xyzxyz"})
      assert html =~ "Nenhum resultado para"
    end

    test "busca vazia restaura a visão de seções", %{conn: conn} do
      insert(:secao, titulo: "Bases", posicao: 1)
      {:ok, lv, _html} = live(conn_logado(conn), ~p"/acervo")
      render_change(lv, "buscar", %{"termo" => "xpto"})
      html = render_change(lv, "buscar", %{"termo" => ""})
      assert html =~ "Bases"
    end

    test "não retorna passos wip na busca", %{conn: conn} do
      secao = insert(:secao)
      insert(:passo, secao: secao, nome: "Base rotativa", wip: true)
      {:ok, lv, _html} = live(conn_logado(conn), ~p"/acervo")
      html = render_change(lv, "buscar", %{"termo" => "rotativa"})
      refute html =~ "Base rotativa"
    end
  end

  describe "filtro de categoria" do
    test "exibe apenas seções da categoria selecionada", %{conn: conn} do
      cat_b = insert(:categoria, nome: "bases", rotulo: "Bases")
      cat_s = insert(:categoria, nome: "sacadas", rotulo: "Sacadas")
      insert(:secao, titulo: "Seção Bases", posicao: 1, categoria: cat_b)
      insert(:secao, titulo: "Seção Sacadas", posicao: 2, categoria: cat_s)
      {:ok, lv, _html} = live(conn_logado(conn), ~p"/acervo")
      html = render_click(lv, "filtrar", %{"categoria" => "bases"})
      assert html =~ "Seção Bases"
      refute html =~ "Seção Sacadas"
    end

    test "filtro 'all' restaura todas as seções", %{conn: conn} do
      cat_b = insert(:categoria, nome: "bases", rotulo: "Bases")
      cat_s = insert(:categoria, nome: "sacadas", rotulo: "Sacadas")
      insert(:secao, titulo: "Seção Bases", posicao: 1, categoria: cat_b)
      insert(:secao, titulo: "Seção Sacadas", posicao: 2, categoria: cat_s)
      {:ok, lv, _html} = live(conn_logado(conn), ~p"/acervo")
      render_click(lv, "filtrar", %{"categoria" => "bases"})
      html = render_click(lv, "filtrar", %{"categoria" => "all"})
      assert html =~ "Seção Bases"
      assert html =~ "Seção Sacadas"
    end
  end

  describe "expandir e recolher seções" do
    test "expandir_tudo exibe os passos de todas as seções", %{conn: conn} do
      secao = insert(:secao, titulo: "Bases", posicao: 1)
      insert(:passo, secao: secao, nome: "Base frontal")
      {:ok, lv, _html} = live(conn_logado(conn), ~p"/acervo")
      html = render_click(lv, "expandir_tudo", %{})
      assert html =~ "Base frontal"
    end

    test "recolher_tudo oculta os passos das seções", %{conn: conn} do
      secao = insert(:secao, titulo: "Bases", posicao: 1)
      insert(:passo, secao: secao, nome: "Base frontal")
      {:ok, lv, _html} = live(conn_logado(conn), ~p"/acervo")
      render_click(lv, "expandir_tudo", %{})
      html = render_click(lv, "recolher_tudo", %{})
      refute html =~ "Base frontal"
      assert html =~ "Bases"
    end

    test "toggle_secao abre uma seção específica", %{conn: conn} do
      secao = insert(:secao, titulo: "Bases", posicao: 1)
      insert(:passo, secao: secao, nome: "Base frontal")
      {:ok, lv, _html} = live(conn_logado(conn), ~p"/acervo")
      html = render_click(lv, "toggle_secao", %{"secao_id" => secao.id})
      assert html =~ "Base frontal"
    end

    test "toggle_secao fecha uma seção já aberta", %{conn: conn} do
      secao = insert(:secao, titulo: "Bases", posicao: 1)
      insert(:passo, secao: secao, nome: "Base frontal")
      {:ok, lv, _html} = live(conn_logado(conn), ~p"/acervo")
      render_click(lv, "toggle_secao", %{"secao_id" => secao.id})
      html = render_click(lv, "toggle_secao", %{"secao_id" => secao.id})
      refute html =~ "Base frontal"
    end
  end
end
