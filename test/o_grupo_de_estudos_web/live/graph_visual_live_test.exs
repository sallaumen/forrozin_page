defmodule OGrupoDeEstudosWeb.GraphVisualLiveTest do
  use OGrupoDeEstudosWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  defp logged_in_conn(conn) do
    user = insert(:user)
    log_in_user(conn, user)
  end

  defp setup_graph(_ctx) do
    cat = insert(:category, name: "bases", label: "Bases", color: "#d4a054")
    section = insert(:section, category: cat)
    step_a = insert(:step, code: "BF", name: "Base frontal", section: section, category: cat)
    step_b = insert(:step, code: "SC", name: "Sacada simples", section: section, category: cat)
    insert(:connection, source_step: step_a, target_step: step_b)
    %{step_a: step_a, step_b: step_b}
  end

  describe "mount" do
    test "renders the graph page with graph-canvas", %{conn: conn} do
      cat = insert(:category, name: "bases", label: "Bases", color: "#d4a054")
      section = insert(:section, category: cat)

      step_a =
        insert(:step,
          code: "BF",
          name: "Base frontal",
          note: "Test note",
          section: section,
          category: cat
        )

      step_b = insert(:step, code: "SC", name: "Sacada simples", section: section, category: cat)
      insert(:connection, source_step: step_a, target_step: step_b)

      {:ok, _lv, html} = live(logged_in_conn(conn), ~p"/graph/visual")

      assert html =~ "graph-canvas"
      assert html =~ "data-graph"
    end

    test "graph JSON includes note and category_name fields", %{conn: conn} do
      cat = insert(:category, name: "bases", label: "Bases", color: "#d4a054")
      section = insert(:section, category: cat)

      step_a =
        insert(:step,
          code: "BF",
          name: "Base frontal",
          note: "Mechanical note here",
          section: section,
          category: cat
        )

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

  describe "manual sequence mode" do
    setup :setup_graph

    test "show_seq_manual switches to manual view", %{conn: conn} do
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/graph/visual")
      render_click(lv, "toggle_seq_panel", %{})
      html = render_click(lv, "show_seq_manual", %{})
      assert html =~ "Manual"
    end

    test "add_manual_step appends step to manual list", %{conn: conn, step_a: step_a} do
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/graph/visual")
      render_click(lv, "toggle_seq_panel", %{})
      render_click(lv, "show_seq_manual", %{})
      html = render_click(lv, "add_manual_step", %{"code" => step_a.code, "name" => step_a.name})
      assert html =~ step_a.code
    end

    test "remove_manual_step removes step by index", %{conn: conn, step_a: step_a} do
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/graph/visual")
      render_click(lv, "toggle_seq_panel", %{})
      render_click(lv, "show_seq_manual", %{})
      render_click(lv, "add_manual_step", %{"code" => step_a.code, "name" => step_a.name})
      html = render_click(lv, "remove_manual_step", %{"index" => "0"})
      # After removal the numbered list should be empty (no "1." position marker)
      refute html =~ ~r/<span[^>]*>\s*1\.\s*<\/span>/
      assert html =~ "Nenhum passo ainda"
    end

    test "save_manual_sequence without name shows error", %{conn: conn, step_a: step_a} do
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/graph/visual")
      render_click(lv, "toggle_seq_panel", %{})
      render_click(lv, "show_seq_manual", %{})
      render_click(lv, "add_manual_step", %{"code" => step_a.code, "name" => step_a.name})

      html =
        render_submit(lv, "save_manual_sequence", %{
          "name" => "",
          "description" => "",
          "video_url" => ""
        })

      assert html =~ "obrigatório"
    end

    test "save_manual_sequence with no steps shows error", %{conn: conn} do
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/graph/visual")
      render_click(lv, "toggle_seq_panel", %{})
      render_click(lv, "show_seq_manual", %{})

      html =
        render_submit(lv, "save_manual_sequence", %{
          "name" => "Sequência Manual",
          "description" => "",
          "video_url" => ""
        })

      assert html =~ "ao menos um passo"
    end

    test "save_manual_sequence with valid data saves and switches to saved view",
         %{conn: conn, step_a: step_a} do
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/graph/visual")
      render_click(lv, "toggle_seq_panel", %{})
      render_click(lv, "show_seq_manual", %{})
      render_click(lv, "add_manual_step", %{"code" => step_a.code, "name" => step_a.name})

      html =
        render_submit(lv, "save_manual_sequence", %{
          "name" => "Sequência Manual",
          "description" => "",
          "video_url" => ""
        })

      assert html =~ "Sequência Manual"
    end
  end

  describe "drawer overflow prevention" do
    test "step detail drawer does not use right: -Npx — prevents horizontal scroll", %{
      conn: conn
    } do
      {:ok, _view, html} = live(logged_in_conn(conn), ~p"/graph/visual")

      refute html =~ "right: -380px",
             "graph drawer uses `right: -380px` in initial HTML which extends document scroll width"

      refute html =~ "right:-380px",
             "graph drawer uses `right:-380px` in initial HTML which extends document scroll width"

      assert html =~ "translateX(100%)",
             "graph drawer should use transform: translateX(100%) for off-screen positioning"
    end
  end
end
