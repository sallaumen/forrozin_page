# Graph Visual Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reformulate the `/graph/visual` page for legibility: variable node sizing, edge bundling, category zones, color legend, and side drawer.

**Architecture:** Elixir enriches the graph JSON with `note`, `category_name`, and edge `spread` data. The JS hook (GraphVisual) is rewritten with new Cytoscape styles, compound nodes for category zones, spotlight interactions, a color legend bar, and a side drawer panel.

**Tech Stack:** Elixir/Phoenix LiveView, Cytoscape.js + Cola plugin, vanilla JS DOM

---

## File Map

| File | Responsibility |
|------|---------------|
| `lib/forrozin_web/live/graph_visual_live.ex` | Modify: enrich `build_json` with note, category_name, edge spread |
| `lib/forrozin_web/live/graph_visual_live.html.heex` | Modify: add legend bar + drawer container |
| `assets/js/app.js` | Modify: rewrite GraphVisual hook — styles, layout, spotlight, legend, drawer |
| `test/forrozin_web/live/graph_visual_live_test.exs` | Create: test that graph JSON includes new fields |

NOTE: The plan involves innerHTML usage for the drawer panel. The content is constructed entirely from trusted server-side data (step names, codes, categories from the DB) — there is no user-generated content or external input. All data originates from Encyclopedia.build_graph/1 which only returns seeder/admin-created data. This is safe in this context.

---

## Tasks

See the design spec at `docs/superpowers/specs/2026-04-14-graph-visual-overhaul-design.md` for full requirements.

### Task 1: Enrich graph JSON (Elixir)

**Files:**
- Modify: `lib/forrozin_web/live/graph_visual_live.ex`
- Create or modify: `test/forrozin_web/live/graph_visual_live_test.exs`

- [ ] **Step 1.1: Write the test**

Add a test file that verifies the JSON includes new fields:

```elixir
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
      insert(:connection, source_step: step_a, target_step: step_b, type: "exit")

      {:ok, _lv, html} = live(logged_in_conn(conn), ~p"/graph/visual")

      assert html =~ "graph-canvas"
      assert html =~ "data-graph"
    end

    test "graph JSON includes note and category_name fields", %{conn: conn} do
      cat = insert(:category, name: "bases", label: "Bases", color: "#d4a054")
      section = insert(:section, category: cat)
      step_a = insert(:step, code: "BF", name: "Base frontal", note: "Mechanical note here", section: section, category: cat)
      step_b = insert(:step, code: "SC", name: "Sacada simples", section: section, category: cat)
      insert(:connection, source_step: step_a, target_step: step_b, type: "exit")

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
  end
end
```

- [ ] **Step 1.2: Run test to verify it fails**

Run: `cd forrozin && mix test test/forrozin_web/live/graph_visual_live_test.exs -v`
Expected: FAIL — `nota` and `categoriaName` not in JSON yet.

- [ ] **Step 1.3: Update build_json/1 and mount/3 in graph_visual_live.ex**

Replace `build_json/1`, add `truncate_note/2` and `compute_edge_spread/1`, update `mount/3` to assign `categories` for the legend.

The new `build_json/1` adds `nota` (truncated to 300 chars), `categoriaName` (internal category name), and computes `spread` for edge bundling. The `compute_edge_spread/1` groups edges by source and calculates a fan-out offset for each edge based on its position in the group.

The full replacement code for graph_visual_live.ex is provided in the spec — implementer should read the current file and apply changes accordingly.

- [ ] **Step 1.4: Run test to verify it passes**

Run: `cd forrozin && mix test test/forrozin_web/live/graph_visual_live_test.exs -v`
Expected: PASS

- [ ] **Step 1.5: Commit**

```bash
git add lib/forrozin_web/live/graph_visual_live.ex test/forrozin_web/live/graph_visual_live_test.exs
git commit -m "feat: enrich graph JSON with note, category_name, and edge spread"
```

---

### Task 2: Update template — legend bar + drawer container

**Files:**
- Modify: `lib/forrozin_web/live/graph_visual_live.html.heex`

- [ ] **Step 2.1: Rewrite the template**

Key changes from original:
- Remove info bar (stats moved to legend)
- Canvas height: `calc(100vh - 56px)` (just header)
- Add `#graph-legend`: absolute positioned bottom bar with category buttons from `@categories` assign
- Add `#graph-drawer`: off-screen right panel (right: -380px, slides in via JS)
- Add `#drawer-close` button and `#drawer-content` container

The legend iterates over `@categories` and renders a button per category with its color dot and label. The drawer starts hidden off-screen.

- [ ] **Step 2.2: Commit**

```bash
git add lib/forrozin_web/live/graph_visual_live.html.heex
git commit -m "feat: add legend bar and drawer container to graph template"
```

---

### Task 3: Rewrite GraphVisual JS hook

**Files:**
- Modify: `assets/js/app.js`

This is the largest task. Replace everything from `const CATEGORIA_ORDEM` through the end of `const GraphVisual = {...}` block.

Key changes:

**Layout:**
- `CATEGORIA_ORDEM` renamed to `CATEGORY_ORDER`
- `R_BASE` increased from 340 to 420
- `NODE_GAP` increased from 150 to 160
- `ROW_GAP` increased from 140 to 160
- `computeSectorPositions` now filters out `category_zone` nodes
- Cola `gravity` reduced from 0.4 to 0.15
- Cola `maxSimulationTime` increased from 1800 to 3000
- Cola `edgeLength`: same-category 140, cross-category 420 (was 130/260)
- Cola `nodeSpacing`: `40 + (degree * 8)` (proportional to connections)

**Node styles:**
- Width/height are functions of `ele.degree()`
- Font-size scales: 13px for degree >= 15, 11.5 for >= 8, 10 otherwise
- Border-width: 3px for degree >= 10, 2px otherwise
- Shadow-blur: 10px for hubs, 4px for leaves
- Label: `code + "\n" + name` (no more CATEGORIA uppercase prefix)

**Category zones:**
- Compound parent nodes (`category-zone` class) with 4% opacity background
- Each step node has `parent: "zone-{categoryName}"` in its data

**Edges:**
- `curve-style: "unbundled-bezier"` with `control-point-distances` from `data(spread)`
- Spread computed in Elixir and passed in JSON

**Interactions:**
- `openDrawer(node, cy)`: builds drawer HTML from node data, slides panel in
- `closeDrawer()`: slides panel out
- `applySpotlight(cy, node)`: dims all to 0.08 opacity, highlights neighborhood to 1.0
- `clearSpotlight(cy)`: resets all opacities
- `applyCategorySpotlight(cy, catName)`: highlights category cluster
- Node tap → spotlight + drawer
- Background tap → clear + close
- Hover → light spotlight (only when drawer is closed)
- Legend button click → toggle category spotlight
- Escape key → close all
- Drawer connection links → navigate to that node in graph

NOTE on innerHTML: The drawer content is built from trusted server-side data only (step names, codes, categories from the seeder/admin). No user-generated content flows into it. Sanitization is not needed in this context.

- [ ] **Step 3.1: Replace the hook code in app.js**

- [ ] **Step 3.2: Verify compilation**

Run: `cd forrozin && mix compile 2>&1 | grep "error"`
Expected: no errors.

- [ ] **Step 3.3: Run all tests**

Run: `cd forrozin && mix test`
Expected: all tests pass.

- [ ] **Step 3.4: Commit**

```bash
git add assets/js/app.js
git commit -m "feat: rewrite GraphVisual hook — variable sizing, bundling, spotlight, drawer"
```

---

### Task 4: Verification

- [ ] **Step 4.1: Run full test suite**

Run: `cd forrozin && mix test`
Expected: all tests pass.

- [ ] **Step 4.2: Visual verification**

Start server: `cd forrozin && mix phx.server`

Navigate to `/graph/visual` and verify:
1. Nodes are sized differently (BF, SC, GP are visibly larger)
2. Category zones have subtle colored backgrounds
3. Clusters are more separated than before
4. Clicking a node opens the drawer from the right
5. Drawer shows step details, connections, and "Ver passo completo" link
6. Clicking a connection in the drawer navigates to that node
7. Legend bar at bottom shows category chips
8. Clicking a category in legend spotlights that cluster
9. Pressing Escape or clicking background closes drawer and resets spotlight

- [ ] **Step 4.3: Push**

```bash
git push
```

---

### Task 5: Xaves — Engineering Quality Gate

- [ ] **Step 5.1 — Pass 1: Tavano RFC Compliance**

Review changed `.ex` files for pipe violations, suppressions.

- [ ] **Step 5.2 — Pass 2: Production Code Review**

Verify `build_json/1` handles nil notes, edge spread edge cases, no Portuguese identifiers in new code.

- [ ] **Step 5.3 — Pass 3: Test Quality Review**

Verify test names follow RFC pattern, tests cover new JSON fields.

- [ ] **Step 5.4 — Apply fixes if needed**

- [ ] **Step 5.5 — Merge Readiness Report**
