# Design: Graph Visual Overhaul

**Date:** 2026-04-14
**Scope:** Subsystem 1 of 3 — visual improvements to `/graph/visual`
**Depends on:** Existing Cytoscape.js + Cola setup, Encyclopedia.build_graph/1, Connection schema

---

## Goal

Reformulate the step connection graph for legibility, category separation, and rich interactivity. High-degree hub nodes (BF, SC, GP) get more visual weight and breathing room. Edges use manual bundling to reduce visual noise. A side drawer provides detail on click.

---

## Section 1 — Layout Engine Changes

Maintain Cytoscape.js + Cola physics. Adjust parameters:

### Node spacing proportional to degree

Nodes with more connections get more space around them. In the Cola layout config:

```javascript
nodeSpacing: function(node) {
  const degree = node.degree()
  const base = 40
  const perConnection = 8
  return base + (degree * perConnection)
}
```

A node with 2 connections → 56px spacing. A hub with 20 connections → 200px spacing. This prevents hub pile-up without affecting leaf nodes.

### Inter-category repulsion

Increase `edgeLength` for cross-category edges:

```javascript
edgeLength: function(edge) {
  const sameCategory = edge.source().data("categoria") === edge.target().data("categoria")
  return sameCategory ? 140 : 420
}
```

Same-category edges stay tight (140px). Cross-category edges push apart (420px, up from 260px).

### Reduced gravity

Lower gravity from 0.4 → 0.15 to allow the graph to expand naturally. Combined with increased edgeLength, this separates clusters without manual positioning.

### Simulation time

Increase `maxSimulationTime` from 1800 → 3000ms to let the physics settle better with more repulsion. Animation duration stays 900ms (the visual part), but the simulation runs longer in background.

---

## Section 2 — Variable Node Sizing

### Size formula

Node dimensions scale with degree:

```javascript
const degree = node.degree()
const baseWidth = 90
const baseHeight = 36
const scaleFactor = Math.min(degree * 3, 40) // cap at +40px

width: baseWidth + scaleFactor
height: baseHeight + (scaleFactor * 0.5)
```

- Leaf node (degree 2): 96 × 39px
- Medium node (degree 8): 114 × 48px
- Hub node (degree 20+): 130 × 56px

### Font scaling

```javascript
"font-size": function(node) {
  const degree = node.degree()
  if (degree >= 15) return 13
  if (degree >= 8) return 11.5
  return 10
}
```

### Label content

- All nodes show only the step name (e.g., "Base frontal", "Sacada simples").
- Category is communicated by border color — no text label for category on the node.
- Code (BF, SC) appears as a small superscript-style secondary label above the name, 8px, muted color.

### Border

- Border width: 2px for normal nodes, 3px for hubs (degree >= 10).
- Border color: category color (from `data(cor)`).
- Shadow scales with degree: hub shadow is larger (10px blur vs 4px for leaves).

---

## Section 3 — Edge Bundling (Manual Waypoints)

### Approach

Use Cytoscape's `curve-style: segments` with computed waypoints. The waypoints are calculated in Elixir and passed in the JSON data.

### Bundling algorithm (Elixir-side)

For edges sharing a source node, compute a "fan-out" point:

1. Group edges by `source_step_id`.
2. For each group with 3+ edges, compute a waypoint that is offset from the source in the direction of the centroid of the targets.
3. Pass waypoints as `segment-distances` and `segment-weights` in the edge data.

```elixir
# In graph_visual_live.ex build_json/1
# For each edge, compute waypoint data based on sibling count
defp compute_edge_waypoints(edges) do
  edges
  |> Enum.group_by(& &1.source_step.code)
  |> Enum.flat_map(fn {_source, group} ->
    count = length(group)
    Enum.with_index(group, fn edge, idx ->
      spread = if count > 2, do: (idx - (count - 1) / 2) * 15, else: 0
      Map.put(edge, :spread, spread)
    end)
  end)
end
```

On the JS side:

```javascript
{
  selector: "edge",
  style: {
    "curve-style": "unbundled-bezier",
    "control-point-distances": "data(spread)",
    "control-point-weights": 0.5
  }
}
```

This fans out edges from the same source at different angles rather than overlapping.

### Opacity spotlight

When a node is selected or hovered:

```javascript
// On node select/hover:
cy.elements().addClass("dimmed")        // opacity 0.08
selectedNode.closedNeighborhood().removeClass("dimmed").addClass("highlighted")

// Styles:
".dimmed": { opacity: 0.08 }
".highlighted": { opacity: 1 }
".highlighted edge": { opacity: 0.85, width: 2.5 }
```

On background click or deselect:

```javascript
cy.elements().removeClass("dimmed").removeClass("highlighted")
```

---

## Section 4 — Category Zones

### Visual treatment

Draw a subtle background zone behind each category cluster. Implementation via a `<canvas>` overlay or Cytoscape's `background-image` on compound nodes.

Recommended approach: **Cytoscape compound nodes**. Create a parent node for each category. Set child nodes' `parent` to their category node.

```javascript
// Category parent node style:
{
  selector: "node.category-zone",
  style: {
    "background-color": "data(cor)",
    "background-opacity": 0.05,
    "border-width": 0,
    "shape": "roundrectangle",
    "padding": "30px",
    "label": "",          // no label on zone
    "events": "no"        // not interactive
  }
}
```

The compound node approach means Cola will naturally keep children within their parent's bounds, providing soft clustering without hard walls.

### Behavior

- Category zones resize dynamically as children are dragged.
- No hard constraints — a node dragged out of its zone can float, but Cola pulls it back on release.

---

## Section 5 — Color Legend

### Position

Fixed bar at the bottom of the canvas, inside the viewport but above the graph (z-index above Cytoscape).

### Content

Horizontal row of category chips:

```
[● Bases] [● Sacadas] [● Travas] [● Giros] [● Caminhadas] [● Pescadas] [● Inversão] [● Outros]
```

Each chip: colored circle (12px) + category label (11px, Georgia serif). Background: semi-transparent cream.

### Interaction

Click a category → spotlight filter:
- Nodes of that category + their immediate connections → full opacity.
- Everything else → dimmed (0.08).
- Click again or click background → reset.

---

## Section 6 — Side Drawer

### Trigger

Click on any node opens a drawer panel from the right side of the screen.

### Layout

- Width: 360px (fixed).
- Height: full viewport minus header.
- Background: cream (#fffef9) with left border (1px, rgba(60,40,20,0.15)).
- Slides in from right with 200ms ease transition.
- Overlay: no dark backdrop — graph stays visible and interactive behind the drawer.

### Content

1. **Header**: Step code (small, muted) + Step name (18px, bold, Georgia) + Category badge (colored pill).
2. **Note** (if exists): Mechanical description, 13px italic. Truncated to 3 lines with "ver mais" toggle.
3. **Stats**: Degree count — "12 saídas · 4 entradas" with small icons.
4. **Connections — Outgoing**: List of `→ Target Name (label)` for each outgoing edge. Each row clickable → centers graph on that target + opens its drawer.
5. **Connections — Incoming**: List of `← Source Name (label)` for each incoming edge. Same click behavior.
6. **Actions**: "Ver passo completo" button → navigates to `/steps/:code`.

### Close behavior

- Click × button in drawer header.
- Click on canvas background.
- Click on a different node → drawer transitions to new node content.
- Press Escape key.

### LiveView integration

The drawer is pure client-side (JS in the GraphVisual hook). No server round-trips for open/close. The data is already present in the Cytoscape graph — the hook reads `node.data()` and `node.connectedEdges()` to populate.

---

## Section 7 — Data Contract (JSON Changes)

Current JSON structure:

```json
{
  "nodes": [{"id": "BF", "nome": "Base frontal", "categoria": "Bases", "cor": "#d4a054"}],
  "edges": [{"from": "BF", "to": "SC", "label": null}]
}
```

New JSON structure adds `note` to nodes and `spread` to edges:

```json
{
  "nodes": [
    {
      "id": "BF",
      "nome": "Base frontal",
      "categoria": "Bases",
      "cor": "#d4a054",
      "nota": "O condutor...",
      "categoriaName": "bases"
    }
  ],
  "edges": [
    {
      "from": "BF",
      "to": "SC",
      "label": null,
      "spread": 15
    }
  ]
}
```

- `nota`: step note for the drawer (truncated to 300 chars server-side to keep JSON lightweight).
- `categoriaName`: internal category name (for grouping/compound node assignment).
- `spread`: computed waypoint offset for edge bundling.

---

## Section 8 — Performance Considerations

- **131 edges, ~76 nodes** — well within Cytoscape's comfort zone (it handles 10K+ elements).
- Compound nodes add ~8 parent nodes — negligible overhead.
- Edge spread calculation is O(E) in Elixir — instant.
- Spotlight toggling uses Cytoscape batch operations (`cy.batch()`) for smooth DOM updates.
- Drawer is pure DOM manipulation, no virtual DOM framework needed.

---

## What Does NOT Change

- GraphLive (`/graph`) admin editor — stays as-is with its table-based UI.
- Encyclopedia.build_graph/1 — query logic unchanged, only the JSON transformation in GraphVisualLive changes.
- Connection schema — no new fields needed.
- Routing — no new routes.
- Auth — same access control.

---

## What IS Deferred (Subsystems 2 and 3)

- **Inline graph editing** (admin clicks to create/delete edges on the visual graph) — Subsystem 2, separate spec.
- **Sequence generator** (algorithm to traverse graph and generate step sequences) — Subsystem 3, separate spec. Requires new DB schema for user sequences.
