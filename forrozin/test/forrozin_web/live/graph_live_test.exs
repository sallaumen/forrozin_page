defmodule ForrozinWeb.GraphLiveTest do
  use ForrozinWeb.ConnCase, async: false

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
    test "admin sees edit connections button", %{conn: conn} do
      {:ok, _lv, html} = live(admin_conn(conn), ~p"/graph")
      assert html =~ "Editar conexões"
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

  describe "edit mode (admin)" do
    test "clicking edit connections displays the selection panels", %{conn: conn} do
      {:ok, lv, _html} = live(admin_conn(conn), ~p"/graph")
      html = render_click(lv, "toggle_edit_mode", %{})
      assert html =~ "Origens"
      assert html =~ "Destinos"
    end

    test "selecting source and target then creating adds edge to the list", %{conn: conn} do
      step_a = insert(:step, code: "BF", name: "Base frontal")
      step_b = insert(:step, code: "SC", name: "Sacada simples")
      {:ok, lv, _html} = live(admin_conn(conn), ~p"/graph")
      render_click(lv, "toggle_edit_mode", %{})
      render_click(lv, "select_source", %{"step_id" => step_a.id})
      render_click(lv, "select_target", %{"step_id" => step_b.id})
      html = render_click(lv, "create_connections", %{})
      assert html =~ "BF"
      assert html =~ "SC"
    end

    test "creating duplicate connection does not raise error and keeps graph stable", %{conn: conn} do
      step_a = insert(:step, code: "BF")
      step_b = insert(:step, code: "SC")
      insert(:connection, source_step: step_a, target_step: step_b)
      {:ok, lv, _html} = live(admin_conn(conn), ~p"/graph")
      render_click(lv, "toggle_edit_mode", %{})
      render_click(lv, "select_source", %{"step_id" => step_a.id})
      render_click(lv, "select_target", %{"step_id" => step_b.id})
      html = render_click(lv, "create_connections", %{})
      assert html =~ "BF"
    end
  end

  describe "remove connection (admin)" do
    test "admin clicks × and edge count drops to zero", %{conn: conn} do
      step_a = insert(:step, code: "BF")
      step_b = insert(:step, code: "SC")
      connection = insert(:connection, source_step: step_a, target_step: step_b)
      {:ok, lv, html} = live(admin_conn(conn), ~p"/graph")
      assert html =~ "1 arestas"
      html = render_click(lv, "delete_connection", %{"connection_id" => connection.id})
      assert html =~ "0 arestas"
    end
  end
end
