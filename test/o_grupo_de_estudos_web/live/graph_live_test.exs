defmodule OGrupoDeEstudosWeb.GraphLiveTest do
  use OGrupoDeEstudosWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  defp logged_in_conn(conn) do
    user = insert(:user)
    log_in_user(conn, user)
  end

  defp admin_conn(conn) do
    admin = insert(:admin)
    log_in_user(conn, admin)
  end

  describe "access" do
    test "redirects to /login when not authenticated", %{conn: conn} do
      {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/graph")
    end

    test "redirects regular user to /graph/visual", %{conn: conn} do
      {:error, {:redirect, %{to: "/graph/visual"}}} = live(logged_in_conn(conn), ~p"/graph")
    end
  end

  describe "mount — admin" do
    test "renders the Mapa de Passos title", %{conn: conn} do
      {:ok, _lv, html} = live(admin_conn(conn), ~p"/graph")
      assert html =~ "Mapa de Passos"
    end

    test "displays code of a public step", %{conn: conn} do
      insert(:step, code: "BF", name: "Base frontal")
      {:ok, _lv, html} = live(admin_conn(conn), ~p"/graph")
      assert html =~ "BF"
    end

    test "displays edge between two steps", %{conn: conn} do
      step_a = insert(:step, code: "BF", name: "Base frontal")
      step_b = insert(:step, code: "SC", name: "Sacada simples")
      insert(:connection, source_step: step_a, target_step: step_b)
      {:ok, _lv, html} = live(admin_conn(conn), ~p"/graph")
      assert html =~ "BF"
      assert html =~ "SC"
    end

    test "does not display wip step", %{conn: conn} do
      insert(:step, code: "HF-SRS", name: "Sacada Rotativa Suspensa", wip: true)
      {:ok, _lv, html} = live(admin_conn(conn), ~p"/graph")
      refute html =~ "HF-SRS"
    end

    test "contains div#graph-canvas with valid data-graph JSON", %{conn: conn} do
      {:ok, _lv, html} = live(admin_conn(conn), ~p"/graph")
      assert html =~ ~s(id="graph-canvas")
      assert html =~ "data-graph"
      # Extracts JSON from the attribute and validates it
      [_, json] = Regex.run(~r/data-graph="([^"]*)"/, html)
      decoded = json |> String.replace("&quot;", "\"") |> Jason.decode!()
      assert Map.has_key?(decoded, "nodes")
      assert Map.has_key?(decoded, "edges")
    end
  end

  describe "admin controls" do
    test "admin sees Nova Conexão form", %{conn: conn} do
      {:ok, _lv, html} = live(admin_conn(conn), ~p"/graph")
      assert html =~ "Nova Conexão"
    end

    test "admin sees autocomplete search inputs", %{conn: conn} do
      {:ok, _lv, html} = live(admin_conn(conn), ~p"/graph")
      assert html =~ "search_source"
      assert html =~ "search_target"
    end

    test "regular user is redirected before seeing the graph", %{conn: conn} do
      {:error, {:redirect, %{to: "/graph/visual"}}} = live(logged_in_conn(conn), ~p"/graph")
    end

    test "admin sees × button on existing edges", %{conn: conn} do
      step_a = insert(:step, code: "BF")
      step_b = insert(:step, code: "SC")
      insert(:connection, source_step: step_a, target_step: step_b)
      {:ok, _lv, html} = live(admin_conn(conn), ~p"/graph")
      assert html =~ "delete_connection"
    end

    test "regular user cannot access the connection table", %{conn: conn} do
      {:error, {:redirect, %{to: "/graph/visual"}}} = live(logged_in_conn(conn), ~p"/graph")
    end
  end

  describe "autocomplete search" do
    test "search_source returns results for matching term", %{conn: conn} do
      insert(:step, code: "BF", name: "Base frontal")
      {:ok, lv, _html} = live(admin_conn(conn), ~p"/graph")
      html = render_keyup(lv, "search_source", %{"value" => "base"})
      assert html =~ "BF"
    end

    test "selecting source sets the pill", %{conn: conn} do
      step = insert(:step, code: "BF", name: "Base frontal")
      {:ok, lv, _html} = live(admin_conn(conn), ~p"/graph")
      html = render_click(lv, "select_source", %{"id" => step.id, "code" => "BF", "name" => "Base frontal"})
      assert html =~ "BF"
      assert html =~ "clear_source"
    end

    test "clearing source removes the pill", %{conn: conn} do
      step = insert(:step, code: "BF", name: "Base frontal")
      {:ok, lv, _html} = live(admin_conn(conn), ~p"/graph")
      render_click(lv, "select_source", %{"id" => step.id, "code" => "BF", "name" => "Base frontal"})
      html = render_click(lv, "clear_source", %{})
      assert html =~ "search_source"
      refute html =~ "clear_source"
    end

    test "search_target returns results for matching term", %{conn: conn} do
      insert(:step, code: "SC", name: "Sacada simples")
      {:ok, lv, _html} = live(admin_conn(conn), ~p"/graph")
      html = render_keyup(lv, "search_target", %{"value" => "sacada"})
      assert html =~ "SC"
    end

    test "selecting target sets the pill", %{conn: conn} do
      step = insert(:step, code: "SC", name: "Sacada simples")
      {:ok, lv, _html} = live(admin_conn(conn), ~p"/graph")
      html = render_click(lv, "select_target", %{"id" => step.id, "code" => "SC", "name" => "Sacada simples"})
      assert html =~ "SC"
      assert html =~ "clear_target"
    end
  end

  describe "create connection" do
    test "selecting source and target then creating adds edge to the list", %{conn: conn} do
      step_a = insert(:step, code: "BF", name: "Base frontal")
      step_b = insert(:step, code: "SC", name: "Sacada simples")
      {:ok, lv, _html} = live(admin_conn(conn), ~p"/graph")
      render_click(lv, "select_source", %{"id" => step_a.id, "code" => "BF", "name" => "Base frontal"})
      render_click(lv, "select_target", %{"id" => step_b.id, "code" => "SC", "name" => "Sacada simples"})
      html = render_click(lv, "create_connection", %{})
      assert html =~ "BF"
      assert html =~ "SC"
    end

    test "creating without source and target shows error flash", %{conn: conn} do
      {:ok, lv, _html} = live(admin_conn(conn), ~p"/graph")
      html = render_click(lv, "create_connection", %{})
      assert html =~ "Selecione origem e destino"
    end

    test "creating duplicate connection does not raise error and keeps graph stable", %{
      conn: conn
    } do
      step_a = insert(:step, code: "BF")
      step_b = insert(:step, code: "SC")
      insert(:connection, source_step: step_a, target_step: step_b)
      {:ok, lv, _html} = live(admin_conn(conn), ~p"/graph")
      render_click(lv, "select_source", %{"id" => step_a.id, "code" => "BF", "name" => "Base frontal"})
      render_click(lv, "select_target", %{"id" => step_b.id, "code" => "SC", "name" => "Sacada simples"})
      html = render_click(lv, "create_connection", %{})
      assert html =~ "BF"
    end
  end

  describe "remove connection (admin)" do
    test "admin clicks × and edge count drops to zero", %{conn: conn} do
      step_a = insert(:step, code: "BF")
      step_b = insert(:step, code: "SC")
      connection = insert(:connection, source_step: step_a, target_step: step_b)
      {:ok, lv, html} = live(admin_conn(conn), ~p"/graph")
      assert html =~ "1 conexões"
      html = render_click(lv, "delete_connection", %{"connection_id" => connection.id})
      assert html =~ "0 conexões"
    end
  end

  describe "connection filter" do
    test "filter_connections narrows visible connections by code", %{conn: conn} do
      step_a = insert(:step, code: "BF", name: "Base frontal")
      step_b = insert(:step, code: "SC", name: "Sacada simples")
      step_c = insert(:step, code: "GP", name: "Giro paulista")
      insert(:connection, source_step: step_a, target_step: step_b)
      insert(:connection, source_step: step_a, target_step: step_c)
      {:ok, lv, _html} = live(admin_conn(conn), ~p"/graph")
      html = render_keyup(lv, "filter_connections", %{"value" => "sc"})
      assert html =~ "SC"
    end
  end
end
