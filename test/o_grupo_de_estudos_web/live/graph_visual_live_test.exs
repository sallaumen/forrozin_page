defmodule OGrupoDeEstudosWeb.GraphVisualLiveTest do
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
      assert html =~ "graph-legend-desktop"
      assert html =~ "graph-legend-mobile-toggle"
      assert html =~ "graph-legend-mobile-panel"
      assert html =~ ~s(data-graph-legend-filter)
      assert html =~ "Bases"
      refute html =~ ~r/\d+\s+passos\s+·\s+\d+\s+conexões/
    end

    test "legend hides low-value category filters", %{conn: conn} do
      bases = insert(:category, name: "bases", label: "Bases", color: "#d4a054")
      convencoes = insert(:category, name: "convencoes", label: "Convenções", color: "#f1c40f")
      footwork = insert(:category, name: "footwork", label: "Forró Footwork", color: "#e67e22")

      bases_section = insert(:section, category: bases)
      convencoes_section = insert(:section, category: convencoes)
      footwork_section = insert(:section, category: footwork)

      step_a =
        insert(:step, code: "BF", name: "Base frontal", section: bases_section, category: bases)

      step_b =
        insert(:step,
          code: "CV",
          name: "Convenção teste",
          section: convencoes_section,
          category: convencoes
        )

      step_c =
        insert(:step,
          code: "FW",
          name: "Footwork teste",
          section: footwork_section,
          category: footwork
        )

      insert(:connection, source_step: step_a, target_step: step_b)
      insert(:connection, source_step: step_b, target_step: step_c)

      {:ok, _lv, html} = live(logged_in_conn(conn), ~p"/graph/visual")

      assert html =~ ~s(id="legend-desktop-bases")
      assert html =~ ~s(id="legend-mobile-bases")
      refute html =~ ~s(id="legend-desktop-convencoes")
      refute html =~ ~s(id="legend-mobile-convencoes")
      refute html =~ ~s(id="legend-desktop-footwork")
      refute html =~ ~s(id="legend-mobile-footwork")
    end

    test "renders unified graph search and finds visible steps by name or code", %{conn: conn} do
      cat = insert(:category, name: "bases", label: "Bases", color: "#d4a054")
      section = insert(:section, category: cat)
      step_a = insert(:step, code: "BF", name: "Base frontal", section: section, category: cat)
      step_b = insert(:step, code: "SC", name: "Sacada simples", section: section, category: cat)
      insert(:connection, source_step: step_a, target_step: step_b)

      {:ok, lv, html} = live(logged_in_conn(conn), ~p"/graph/visual")

      assert html =~ ~s(id="graph-step-search")

      html = render_keyup(lv, "search_graph_step", %{"value" => "sacada"})

      assert html =~ ~s(id="graph-step-search-results")
      assert html =~ ~s(id="graph-search-result-SC")
      assert html =~ "Sacada simples"
    end

    test "graph search only suggests steps currently visible on the map", %{conn: conn} do
      cat = insert(:category, name: "bases", label: "Bases", color: "#d4a054")
      section = insert(:section, category: cat)
      step_a = insert(:step, code: "BF", name: "Base frontal", section: section, category: cat)
      step_b = insert(:step, code: "SC", name: "Sacada simples", section: section, category: cat)

      insert(:step,
        code: "ORF",
        name: "Passo sem conexão",
        section: section,
        category: cat
      )

      insert(:connection, source_step: step_a, target_step: step_b)

      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/graph/visual")

      html = render_keyup(lv, "search_graph_step", %{"value" => "sem conexão"})

      refute html =~ ~s(id="graph-search-result-ORF")
    end

    test "sequence library shows public examples before the user saves anything", %{conn: conn} do
      cat = insert(:category, name: "bases", label: "Bases", color: "#d4a054")
      section = insert(:section, category: cat)
      step = insert(:step, code: "BA", name: "Balanço", section: section, category: cat)
      sequence = insert(:sequence, name: "Sequência exemplo", user: insert(:user))
      insert(:sequence_step, sequence: sequence, step: step, position: 1)

      {:ok, _lv, html} = live(logged_in_conn(conn), ~p"/graph/visual")

      assert html =~ ~s(id="seq-library-search")
      assert html =~ "Sequência exemplo"
      assert html =~ "exemplo"
      assert html =~ "BA"
    end

    test "sequence query param renders initial sequence steps for the graph hook", %{conn: conn} do
      user = insert(:user)
      cat = insert(:category, name: "bases", label: "Bases", color: "#d4a054")
      section = insert(:section, category: cat)
      step_a = insert(:step, code: "BA", name: "Balanço", section: section, category: cat)
      step_b = insert(:step, code: "SC", name: "Sacada simples", section: section, category: cat)
      insert(:connection, source_step: step_a, target_step: step_b)

      sequence = insert(:sequence, name: "Sequência da comunidade", user: user)
      insert(:sequence_step, sequence: sequence, step: step_a, position: 1)
      insert(:sequence_step, sequence: sequence, step: step_b, position: 2)

      {:ok, _lv, html} = live(log_in_user(conn, user), ~p"/graph/visual?seq=#{sequence.id}")

      assert html =~ ~s(data-initial-sequence-steps=)
      assert html =~ "BA"
      assert html =~ "SC"
      assert html =~ ~s(id="seq-library-card-#{sequence.id}")
      assert html =~ "max-md:hidden"
    end

    test "sequence panel keeps its header outside the scrollable content", %{conn: conn} do
      {:ok, _lv, html} = live(logged_in_conn(conn), ~p"/graph/visual")

      assert html =~ ~s(id="seq-panel-header")
      assert html =~ ~s(id="seq-panel-content")
      assert html =~ "flex flex-col overflow-hidden"
      assert html =~ "min-h-0 flex-1 overflow-y-auto"
    end

    test "admin edit action is available in the top nav instead of floating controls", %{
      conn: conn
    } do
      {:ok, _lv, html} = live(admin_conn(conn), ~p"/graph/visual")

      assert html =~ ~s(id="top-nav-edit-button")
      assert html =~ ~s(phx-click="toggle_edit_mode")
      refute html =~ ~s(id="graph-controls")
    end

    test "viewing a sequence on the map closes the mobile sequence panel", %{conn: conn} do
      user = insert(:user)
      cat = insert(:category, name: "bases", label: "Bases", color: "#d4a054")
      section = insert(:section, category: cat)
      step = insert(:step, code: "BA", name: "Balanço", section: section, category: cat)

      sequence = insert(:sequence, name: "Sequência mobile", user: user)
      insert(:sequence_step, sequence: sequence, step: step, position: 1)

      {:ok, lv, _html} = live(log_in_user(conn, user), ~p"/graph/visual")

      html = render_click(lv, "show_seq_mobile", %{})
      refute html =~ ~r/id="seq-panel"[^>]*max-md:hidden/

      html = render_click(lv, "highlight_saved_sequence", %{"id" => sequence.id})
      assert html =~ ~r/id="seq-panel"[^>]*max-md:hidden/
    end

    test "sequence library combines saved and favorited sequences", %{conn: conn} do
      user = insert(:user)
      cat = insert(:category, name: "bases", label: "Bases", color: "#d4a054")
      section = insert(:section, category: cat)
      step = insert(:step, code: "BA", name: "Balanço", section: section, category: cat)

      saved = insert(:sequence, name: "Minha sequência", user: user)
      insert(:sequence_step, sequence: saved, step: step, position: 1)

      favorite = insert(:sequence, name: "Favorita da roda", user: insert(:user))
      insert(:sequence_step, sequence: favorite, step: step, position: 1)

      {:ok, :favorited} =
        OGrupoDeEstudos.Engagement.toggle_favorite(user.id, "sequence", favorite.id)

      {:ok, _lv, html} = live(log_in_user(conn, user), ~p"/graph/visual")

      assert html =~ "Minha sequência"
      assert html =~ "salva"
      assert html =~ "Favorita da roda"
      assert html =~ "favorita"
    end

    test "sequence library filters by step category", %{conn: conn} do
      bases = insert(:category, name: "bases", label: "Bases", color: "#d4a054")
      giros = insert(:category, name: "giros", label: "Giros", color: "#3498db")
      base_section = insert(:section, category: bases)
      giro_section = insert(:section, category: giros)

      base_step =
        insert(:step, code: "BA", name: "Balanço", section: base_section, category: bases)

      giro_step =
        insert(:step, code: "G1", name: "Giro simples", section: giro_section, category: giros)

      base_seq = insert(:sequence, name: "Sequência de base", user: insert(:user))
      insert(:sequence_step, sequence: base_seq, step: base_step, position: 1)

      giro_seq = insert(:sequence, name: "Sequência de giro", user: insert(:user))
      insert(:sequence_step, sequence: giro_seq, step: giro_step, position: 1)

      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/graph/visual")

      html =
        render_click(lv, "filter_sequence_library_category", %{
          "category" => "bases"
        })

      assert html =~ "Sequência de base"
      refute html =~ "Sequência de giro"
    end

    test "sequence library filters only favorited sequences", %{conn: conn} do
      user = insert(:user)
      cat = insert(:category, name: "bases", label: "Bases", color: "#d4a054")
      section = insert(:section, category: cat)
      step = insert(:step, code: "BA", name: "Balanço", section: section, category: cat)

      saved = insert(:sequence, name: "Minha sequência", user: user)
      insert(:sequence_step, sequence: saved, step: step, position: 1)

      favorite = insert(:sequence, name: "Favorita da comunidade", user: insert(:user))
      insert(:sequence_step, sequence: favorite, step: step, position: 1)

      example = insert(:sequence, name: "Exemplo público", user: insert(:user))
      insert(:sequence_step, sequence: example, step: step, position: 1)

      {:ok, :favorited} =
        OGrupoDeEstudos.Engagement.toggle_favorite(user.id, "sequence", favorite.id)

      {:ok, lv, _html} = live(log_in_user(conn, user), ~p"/graph/visual")

      assert has_element?(lv, "#seq-library-origin-filter")

      lv
      |> element("#seq-library-origin-favorites")
      |> render_click()

      assert has_element?(lv, "#seq-library-card-#{favorite.id}")
      refute has_element?(lv, "#seq-library-card-#{saved.id}")
      refute has_element?(lv, "#seq-library-card-#{example.id}")
    end

    test "sequence library filters community sequences separately from saved ones", %{conn: conn} do
      user = insert(:user)
      cat = insert(:category, name: "bases", label: "Bases", color: "#d4a054")
      section = insert(:section, category: cat)
      step = insert(:step, code: "BA", name: "Balanço", section: section, category: cat)

      saved = insert(:sequence, name: "Minha sequência", user: user)
      insert(:sequence_step, sequence: saved, step: step, position: 1)

      community = insert(:sequence, name: "Sequência da comunidade", user: insert(:user))
      insert(:sequence_step, sequence: community, step: step, position: 1)

      {:ok, lv, _html} = live(log_in_user(conn, user), ~p"/graph/visual")

      lv
      |> element("#seq-library-origin-community")
      |> render_click()

      assert has_element?(lv, "#seq-library-card-#{community.id}")
      refute has_element?(lv, "#seq-library-card-#{saved.id}")
    end

    test "sequence owner can delete from the library card", %{conn: conn} do
      user = insert(:user)
      cat = insert(:category, name: "bases", label: "Bases", color: "#d4a054")
      section = insert(:section, category: cat)
      step = insert(:step, code: "BA", name: "Balanço", section: section, category: cat)

      sequence = insert(:sequence, name: "Sequência para deletar", user: user)
      insert(:sequence_step, sequence: sequence, step: step, position: 1)

      {:ok, lv, _html} = live(log_in_user(conn, user), ~p"/graph/visual")

      lv
      |> element("#seq-library-delete-#{sequence.id}")
      |> render_click()

      refute OGrupoDeEstudos.Sequences.get_sequence(sequence.id)
      refute has_element?(lv, "#seq-library-card-#{sequence.id}")
    end

    test "admin can delete a community sequence from the library card", %{conn: conn} do
      author = insert(:user)
      cat = insert(:category, name: "bases", label: "Bases", color: "#d4a054")
      section = insert(:section, category: cat)
      step = insert(:step, code: "BA", name: "Balanço", section: section, category: cat)

      sequence = insert(:sequence, name: "Sequência moderada", user: author)
      insert(:sequence_step, sequence: sequence, step: step, position: 1)

      {:ok, lv, _html} = live(admin_conn(conn), ~p"/graph/visual")

      lv
      |> element("#seq-library-delete-#{sequence.id}")
      |> render_click()

      refute OGrupoDeEstudos.Sequences.get_sequence(sequence.id)
    end

    test "non-owner cannot delete a public sequence by forging the event", %{conn: conn} do
      author = insert(:user)
      other_user = insert(:user)
      cat = insert(:category, name: "bases", label: "Bases", color: "#d4a054")
      section = insert(:section, category: cat)
      step = insert(:step, code: "BA", name: "Balanço", section: section, category: cat)

      sequence = insert(:sequence, name: "Sequência protegida", user: author)
      insert(:sequence_step, sequence: sequence, step: step, position: 1)

      {:ok, lv, _html} = live(log_in_user(conn, other_user), ~p"/graph/visual")

      refute has_element?(lv, "#seq-library-delete-#{sequence.id}")

      render_click(lv, "delete_sequence", %{"id" => sequence.id})

      assert OGrupoDeEstudos.Sequences.get_sequence(sequence.id)
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

    test "graph taps send the node label as the manual step name" do
      js = File.read!("assets/js/app.js")

      assert js =~ ~S/name: node.data("label") || node.id()/
      refute js =~ ~S/name: node.data("nome") || node.id()/
    end

    test "manual graph taps highlight outgoing options without refocusing the camera" do
      js = File.read!("assets/js/app.js")

      assert js =~ "_applyManualStepGuide(node)"
      assert js =~ ~S/node.outgoers("edge")/
      assert js =~ "if (hook._manualGuideActive) return"
      assert js =~ ~S/if (this._manualMode || this.el.dataset.manualMode === "true") return/
      assert js =~ "_clearManualStepGuide()"
    end

    test "graph hook avoids rebuilding the graph on unrelated LiveView updates" do
      js = File.read!("assets/js/app.js")

      refute js =~ "updated() { this._initGraph() }"
      assert js =~ "this._graphSignatureValue !== this._graphSignature()"
    end

    test "manual step search adds a step by name", %{conn: conn, step_a: step_a} do
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/graph/visual")
      render_click(lv, "toggle_seq_panel", %{})
      render_click(lv, "show_seq_manual", %{})

      html = render_change(lv, "search_manual_step", %{"value" => step_a.name})
      assert html =~ "seq-manual-step-result-#{step_a.code}"

      html =
        render_submit(lv, "add_manual_step_by_search", %{
          "manual_step_search" => step_a.name
        })

      assert html =~ step_a.code
      assert html =~ step_a.name
    end

    test "manual mode exposes favorited steps as quick add buttons", %{
      conn: conn,
      step_a: step_a
    } do
      user = insert(:user)
      {:ok, :favorited} = OGrupoDeEstudos.Engagement.toggle_favorite(user.id, "step", step_a.id)

      {:ok, lv, _html} = live(log_in_user(conn, user), ~p"/graph/visual")
      html = render_click(lv, "show_seq_manual", %{})

      assert html =~ "Favoritos"
      assert has_element?(lv, "#seq-manual-favorite-#{step_a.code}")

      html =
        lv
        |> element("#seq-manual-favorite-#{step_a.code}")
        |> render_click()

      assert html =~ step_a.code
    end

    test "cancel_manual_sequence exits manual mode and clears draft", %{
      conn: conn,
      step_a: step_a
    } do
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/graph/visual")
      render_click(lv, "toggle_seq_panel", %{})
      render_click(lv, "show_seq_manual", %{})
      render_click(lv, "add_manual_step", %{"code" => step_a.code, "name" => step_a.name})

      html =
        lv
        |> element("#seq-manual-cancel")
        |> render_click()

      assert html =~ ~s(id="seq-library-search")
      refute has_element?(lv, "#seq-manual-form")
    end

    test "manual step rows use larger left-side reorder controls", %{
      conn: conn,
      step_a: step_a,
      step_b: step_b
    } do
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/graph/visual")
      render_click(lv, "toggle_seq_panel", %{})
      render_click(lv, "show_seq_manual", %{})
      render_click(lv, "add_manual_step", %{"code" => step_a.code, "name" => step_a.name})
      render_click(lv, "add_manual_step", %{"code" => step_b.code, "name" => step_b.name})

      assert has_element?(lv, "#seq-manual-move-up-1")
      assert has_element?(lv, "#seq-manual-remove-1")
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

    test "editing a saved sequence pre-fills fields and updates the existing record",
         %{conn: conn, step_a: step_a, step_b: step_b} do
      user = insert(:user)

      sequence =
        insert(:sequence,
          name: "Sequência antiga",
          description: "Descrição antiga",
          video_url: "https://example.com/antigo",
          user: user
        )

      insert(:sequence_step, sequence: sequence, step: step_a, position: 1)

      {:ok, lv, _html} = live(log_in_user(conn, user), ~p"/graph/visual")

      html =
        lv
        |> element("#seq-library-edit-#{sequence.id}")
        |> render_click()

      assert html =~ ~s(id="seq-manual-form")
      assert html =~ ~s(value="Sequência antiga")
      assert html =~ "Descrição antiga"
      assert html =~ ~s(value="https://example.com/antigo")

      render_click(lv, "add_manual_step", %{"code" => step_b.code, "name" => step_b.name})

      render_submit(lv, "save_manual_sequence", %{
        "name" => "Sequência atualizada",
        "description" => "Descrição nova",
        "video_url" => "https://example.com/novo"
      })

      updated = OGrupoDeEstudos.Sequences.get_sequence(sequence.id)

      assert updated.name == "Sequência atualizada"
      assert updated.description == "Descrição nova"
      assert updated.video_url == "https://example.com/novo"
      assert Enum.map(updated.sequence_steps, & &1.step.code) == [step_a.code, step_b.code]
    end

    test "editing mode can delete the sequence being edited", %{
      conn: conn,
      step_a: step_a
    } do
      user = insert(:user)
      sequence = insert(:sequence, name: "Sequência em edição", user: user)
      insert(:sequence_step, sequence: sequence, step: step_a, position: 1)

      {:ok, lv, _html} = live(log_in_user(conn, user), ~p"/graph/visual")

      lv
      |> element("#seq-library-edit-#{sequence.id}")
      |> render_click()

      lv
      |> element("#seq-manual-delete")
      |> render_click()

      refute OGrupoDeEstudos.Sequences.get_sequence(sequence.id)
      assert has_element?(lv, "#seq-library-search")
      refute has_element?(lv, "#seq-manual-form")
    end
  end

  describe "automatic sequence generator" do
    setup :setup_graph

    test "generator form uses learner-friendly labels and code with step name", %{
      conn: conn
    } do
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/graph/visual")

      html = render_click(lv, "show_seq_config", %{})

      assert html =~ "Gerador automático"
      assert html =~ "Escolha um ponto de partida"
      assert html =~ ~s(value="BF · Base frontal")
      assert html =~ "Tamanho da sequência"
      assert html =~ "Opções para gerar"
      assert html =~ "Quero incluir estes passos"
      assert html =~ "Fechar a sequência no início"
      assert html =~ "Permitir loops curtos"
      assert html =~ "Limite de Base frontal"

      refute html =~ "Duração"
      refute html =~ "Quantidade"
      refute html =~ "Permitir repetições"
      refute html =~ "Máx. vezes na BF"
    end

    test "generator exposes favorited steps as required-step shortcuts", %{
      conn: conn,
      step_b: step_b
    } do
      user = insert(:user)
      {:ok, :favorited} = OGrupoDeEstudos.Engagement.toggle_favorite(user.id, "step", step_b.id)

      {:ok, lv, _html} = live(log_in_user(conn, user), ~p"/graph/visual")
      html = render_click(lv, "show_seq_config", %{})

      assert html =~ "Favoritos"
      assert has_element?(lv, "#seq-required-favorite-#{step_b.code}")

      html =
        lv
        |> element("#seq-required-favorite-#{step_b.code}")
        |> render_click()

      assert html =~ "#{step_b.code} · #{step_b.name}"
    end

    test "generator mode query opens the automatic generator directly", %{conn: conn} do
      {:ok, _lv, html} = live(logged_in_conn(conn), ~p"/graph/visual?mode=generator")

      assert html =~ "Gerador automático"
      refute html =~ ~r/id="seq-panel"[^>]*max-md:hidden/
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

    test "step detail drawer uses fixed header and stays hidden on mobile", %{conn: conn} do
      {:ok, _view, html} = live(logged_in_conn(conn), ~p"/graph/visual")

      assert html =~ ~s(id="drawer-header")
      assert html =~ ~s(id="drawer-header-content")
      assert html =~ ~s(id="drawer-content" class="min-h-0 flex-1 overflow-y-auto p-6")
      assert html =~ "hidden bg-ink-50"
      assert html =~ "md:flex md:flex-col"
    end

    test "applying a new sequence highlight does not refit before focusing the sequence" do
      js = File.read!("assets/js/app.js")

      assert js =~ "_clearSequenceHighlight({ refit: false })"
      assert js =~ "if (refit) {"
      assert js =~ "cy.animate({ fit: { padding: 60 }, duration: 400 })"
    end
  end
end
