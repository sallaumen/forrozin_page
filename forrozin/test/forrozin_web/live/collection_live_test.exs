defmodule ForrozinWeb.CollectionLiveTest do
  use ForrozinWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  defp logged_in_conn(conn) do
    user = insert(:user)
    log_in_user(conn, user)
  end

  describe "access" do
    test "redirects to /login when not authenticated", %{conn: conn} do
      {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/collection")
    end
  end

  describe "mount — authenticated" do
    test "displays titles of registered sections", %{conn: conn} do
      insert(:section, title: "Bases", position: 1)
      {:ok, _lv, html} = live(logged_in_conn(conn), ~p"/collection")
      assert html =~ "Bases"
    end

    test "does not display wip steps when expanding the section", %{conn: conn} do
      section = insert(:section)
      insert(:step, section: section, name: "Base frontal", wip: false)
      insert(:step, section: section, name: "Sacada Suspensa", wip: true)
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
      html = render_click(lv, "expand_all", %{})
      assert html =~ "Base frontal"
      refute html =~ "Sacada Suspensa"
    end

    test "does not display draft steps", %{conn: conn} do
      section = insert(:section)
      insert(:step, section: section, name: "Publicado", status: "published")
      insert(:step, section: section, name: "Rascunho", status: "draft")
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
      html = render_click(lv, "expand_all", %{})
      assert html =~ "Publicado"
      refute html =~ "Rascunho"
    end
  end

  describe "search" do
    test "displays steps matching the search term", %{conn: conn} do
      section = insert(:section)
      insert(:step, section: section, name: "Base frontal")
      insert(:step, section: section, name: "Sacada simples")
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
      html = render_change(lv, "search", %{"term" => "base"})
      assert html =~ "Base frontal"
      refute html =~ "Sacada simples"
    end

    test "search is case-insensitive", %{conn: conn} do
      section = insert(:section)
      insert(:step, section: section, name: "Base frontal")
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
      html = render_change(lv, "search", %{"term" => "BASE"})
      assert html =~ "Base frontal"
    end

    test "search with no results displays message", %{conn: conn} do
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
      html = render_change(lv, "search", %{"term" => "xyzxyz"})
      assert html =~ "Nenhum resultado para"
    end

    test "empty search restores section view", %{conn: conn} do
      insert(:section, title: "Bases", position: 1)
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
      render_change(lv, "search", %{"term" => "xpto"})
      html = render_change(lv, "search", %{"term" => ""})
      assert html =~ "Bases"
    end

    test "does not return wip steps in search", %{conn: conn} do
      section = insert(:section)
      insert(:step, section: section, name: "Base rotativa", wip: true)
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
      html = render_change(lv, "search", %{"term" => "rotativa"})
      refute html =~ "Base rotativa"
    end
  end

  describe "category filter" do
    test "displays only sections from the selected category", %{conn: conn} do
      cat_b = insert(:category, name: "bases", label: "Bases")
      cat_s = insert(:category, name: "sacadas", label: "Sacadas")
      insert(:section, title: "Seção Bases", position: 1, category: cat_b)
      insert(:section, title: "Seção Sacadas", position: 2, category: cat_s)
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
      html = render_click(lv, "filter", %{"category" => "bases"})
      assert html =~ "Seção Bases"
      refute html =~ "Seção Sacadas"
    end

    test "'all' filter restores all sections", %{conn: conn} do
      cat_b = insert(:category, name: "bases", label: "Bases")
      cat_s = insert(:category, name: "sacadas", label: "Sacadas")
      insert(:section, title: "Seção Bases", position: 1, category: cat_b)
      insert(:section, title: "Seção Sacadas", position: 2, category: cat_s)
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
      render_click(lv, "filter", %{"category" => "bases"})
      html = render_click(lv, "filter", %{"category" => "all"})
      assert html =~ "Seção Bases"
      assert html =~ "Seção Sacadas"
    end
  end

  describe "expand and collapse sections" do
    test "expand_all displays steps from all sections", %{conn: conn} do
      section = insert(:section, title: "Bases", position: 1)
      insert(:step, section: section, name: "Base frontal")
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
      html = render_click(lv, "expand_all", %{})
      assert html =~ "Base frontal"
    end

    test "collapse_all hides steps from sections", %{conn: conn} do
      section = insert(:section, title: "Bases", position: 1)
      insert(:step, section: section, name: "Base frontal")
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
      render_click(lv, "expand_all", %{})
      html = render_click(lv, "collapse_all", %{})
      refute html =~ "Base frontal"
      assert html =~ "Bases"
    end

    test "toggle_section opens a specific section", %{conn: conn} do
      section = insert(:section, title: "Bases", position: 1)
      insert(:step, section: section, name: "Base frontal")
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
      html = render_click(lv, "toggle_section", %{"section_id" => section.id})
      assert html =~ "Base frontal"
    end

    test "toggle_section closes an already open section", %{conn: conn} do
      section = insert(:section, title: "Bases", position: 1)
      insert(:step, section: section, name: "Base frontal")
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
      render_click(lv, "toggle_section", %{"section_id" => section.id})
      html = render_click(lv, "toggle_section", %{"section_id" => section.id})
      refute html =~ "Base frontal"
    end
  end
end
