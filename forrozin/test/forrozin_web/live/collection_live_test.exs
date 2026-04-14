defmodule ForrozinWeb.CollectionLiveTest do
  use ForrozinWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  defp conn_logado(conn) do
    user = insert(:user)
    log_in_user(conn, user)
  end

  describe "acesso" do
    test "redireciona para /login se não autenticado", %{conn: conn} do
      {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/collection")
    end
  end

  describe "mount — autenticado" do
    test "exibe títulos das seções cadastradas", %{conn: conn} do
      insert(:section, title: "Bases", position: 1)
      {:ok, _lv, html} = live(conn_logado(conn), ~p"/collection")
      assert html =~ "Bases"
    end

    test "não exibe passos wip ao expandir a seção", %{conn: conn} do
      section = insert(:section)
      insert(:step, section: section, name: "Base frontal", wip: false)
      insert(:step, section: section, name: "Sacada Suspensa", wip: true)
      {:ok, lv, _html} = live(conn_logado(conn), ~p"/collection")
      html = render_click(lv, "expand_all", %{})
      assert html =~ "Base frontal"
      refute html =~ "Sacada Suspensa"
    end

    test "não exibe passos com status draft", %{conn: conn} do
      section = insert(:section)
      insert(:step, section: section, name: "Publicado", status: "published")
      insert(:step, section: section, name: "Rascunho", status: "draft")
      {:ok, lv, _html} = live(conn_logado(conn), ~p"/collection")
      html = render_click(lv, "expand_all", %{})
      assert html =~ "Publicado"
      refute html =~ "Rascunho"
    end
  end

  describe "busca" do
    test "exibe passos que correspondem ao termo", %{conn: conn} do
      section = insert(:section)
      insert(:step, section: section, name: "Base frontal")
      insert(:step, section: section, name: "Sacada simples")
      {:ok, lv, _html} = live(conn_logado(conn), ~p"/collection")
      html = render_change(lv, "search", %{"term" => "base"})
      assert html =~ "Base frontal"
      refute html =~ "Sacada simples"
    end

    test "busca é case-insensitive", %{conn: conn} do
      section = insert(:section)
      insert(:step, section: section, name: "Base frontal")
      {:ok, lv, _html} = live(conn_logado(conn), ~p"/collection")
      html = render_change(lv, "search", %{"term" => "BASE"})
      assert html =~ "Base frontal"
    end

    test "busca sem resultado exibe mensagem", %{conn: conn} do
      {:ok, lv, _html} = live(conn_logado(conn), ~p"/collection")
      html = render_change(lv, "search", %{"term" => "xyzxyz"})
      assert html =~ "Nenhum resultado para"
    end

    test "busca vazia restaura a visão de seções", %{conn: conn} do
      insert(:section, title: "Bases", position: 1)
      {:ok, lv, _html} = live(conn_logado(conn), ~p"/collection")
      render_change(lv, "search", %{"term" => "xpto"})
      html = render_change(lv, "search", %{"term" => ""})
      assert html =~ "Bases"
    end

    test "não retorna passos wip na busca", %{conn: conn} do
      section = insert(:section)
      insert(:step, section: section, name: "Base rotativa", wip: true)
      {:ok, lv, _html} = live(conn_logado(conn), ~p"/collection")
      html = render_change(lv, "search", %{"term" => "rotativa"})
      refute html =~ "Base rotativa"
    end
  end

  describe "filtro de categoria" do
    test "exibe apenas seções da categoria selecionada", %{conn: conn} do
      cat_b = insert(:category, name: "bases", label: "Bases")
      cat_s = insert(:category, name: "sacadas", label: "Sacadas")
      insert(:section, title: "Seção Bases", position: 1, category: cat_b)
      insert(:section, title: "Seção Sacadas", position: 2, category: cat_s)
      {:ok, lv, _html} = live(conn_logado(conn), ~p"/collection")
      html = render_click(lv, "filter", %{"category" => "bases"})
      assert html =~ "Seção Bases"
      refute html =~ "Seção Sacadas"
    end

    test "filtro 'all' restaura todas as seções", %{conn: conn} do
      cat_b = insert(:category, name: "bases", label: "Bases")
      cat_s = insert(:category, name: "sacadas", label: "Sacadas")
      insert(:section, title: "Seção Bases", position: 1, category: cat_b)
      insert(:section, title: "Seção Sacadas", position: 2, category: cat_s)
      {:ok, lv, _html} = live(conn_logado(conn), ~p"/collection")
      render_click(lv, "filter", %{"category" => "bases"})
      html = render_click(lv, "filter", %{"category" => "all"})
      assert html =~ "Seção Bases"
      assert html =~ "Seção Sacadas"
    end
  end

  describe "expandir e recolher seções" do
    test "expand_all exibe os passos de todas as seções", %{conn: conn} do
      section = insert(:section, title: "Bases", position: 1)
      insert(:step, section: section, name: "Base frontal")
      {:ok, lv, _html} = live(conn_logado(conn), ~p"/collection")
      html = render_click(lv, "expand_all", %{})
      assert html =~ "Base frontal"
    end

    test "collapse_all oculta os passos das seções", %{conn: conn} do
      section = insert(:section, title: "Bases", position: 1)
      insert(:step, section: section, name: "Base frontal")
      {:ok, lv, _html} = live(conn_logado(conn), ~p"/collection")
      render_click(lv, "expand_all", %{})
      html = render_click(lv, "collapse_all", %{})
      refute html =~ "Base frontal"
      assert html =~ "Bases"
    end

    test "toggle_section abre uma seção específica", %{conn: conn} do
      section = insert(:section, title: "Bases", position: 1)
      insert(:step, section: section, name: "Base frontal")
      {:ok, lv, _html} = live(conn_logado(conn), ~p"/collection")
      html = render_click(lv, "toggle_section", %{"section_id" => section.id})
      assert html =~ "Base frontal"
    end

    test "toggle_section fecha uma seção já aberta", %{conn: conn} do
      section = insert(:section, title: "Bases", position: 1)
      insert(:step, section: section, name: "Base frontal")
      {:ok, lv, _html} = live(conn_logado(conn), ~p"/collection")
      render_click(lv, "toggle_section", %{"section_id" => section.id})
      html = render_click(lv, "toggle_section", %{"section_id" => section.id})
      refute html =~ "Base frontal"
    end
  end
end
