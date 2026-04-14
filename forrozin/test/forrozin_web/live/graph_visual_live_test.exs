defmodule ForrozinWeb.GraphVisualLiveTest do
  use ForrozinWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  defp logged_in_conn(conn) do
    user = insert(:user)
    log_in_user(conn, user)
  end

  describe "mount" do
    test "renders the graph page with graph-canvas", %{conn: conn} do
      cat = insert(:category, name: "bases", label: "Bases", color: "#d4a054")
      section = insert(:section, category: cat)
      step_a = insert(:step, code: "BF", name: "Base frontal", note: "Test note", section: section, category: cat)
      step_b = insert(:step, code: "SC", name: "Sacada simples", section: section, category: cat)
      insert(:connection, source_step: step_a, target_step: step_b)

      {:ok, _lv, html} = live(logged_in_conn(conn), ~p"/graph/visual")

      assert html =~ "graph-canvas"
      assert html =~ "data-graph"
    end

    test "graph JSON includes note and category_name fields", %{conn: conn} do
      cat = insert(:category, name: "bases", label: "Bases", color: "#d4a054")
      section = insert(:section, category: cat)
      step_a = insert(:step, code: "BF", name: "Base frontal", note: "Mechanical note here", section: section, category: cat)
      step_b = insert(:step, code: "SC", name: "Sacada simples", section: section, category: cat)
      insert(:connection, source_step: step_a, target_step: step_b)

      {:ok, _lv, html} = live(logged_in_conn(conn), ~p"/graph/visual")

      [_, json] = Regex.run(~r/data-graph="([^"]*)"/, html)
      decoded = json |> String.replace("&quot;", "\"") |> Jason.decode!()

      bf_node = Enum.find(decoded["nodes"], &(&1["id"] == "BF"))
      assert bf_node["nota"] == "Mechanical note here"
      assert bf_node["categoriaName"] == "bases"
      assert bf_node["cor"] == "#d4a054"

      [edge] = decoded["edges"]
      assert Map.has_key?(edge, "spread")
    end

    test "legend displays category chips", %{conn: conn} do
      cat = insert(:category, name: "bases", label: "Bases", color: "#d4a054")
      section = insert(:section, category: cat)
      step_a = insert(:step, code: "BF", name: "Base frontal", section: section, category: cat)
      step_b = insert(:step, code: "SC", name: "Sacada simples", section: section, category: cat)
      insert(:connection, source_step: step_a, target_step: step_b)

      {:ok, _lv, html} = live(logged_in_conn(conn), ~p"/graph/visual")

      assert html =~ "graph-legend"
      assert html =~ "Bases"
    end

    test "redirects to /login when not authenticated", %{conn: conn} do
      {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/graph/visual")
    end
  end
end
