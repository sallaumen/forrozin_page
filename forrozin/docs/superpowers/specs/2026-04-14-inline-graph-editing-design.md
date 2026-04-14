# Design: Inline Graph Editing (Admin)

**Date:** 2026-04-14
**Scope:** Subsystem 2 of 3 — admin editing of connections directly on `/graph/visual`
**Depends on:** Graph Visual Overhaul (subsystem 1, completed), Admin context CRUD

---

## Goal

Allow admins to add and remove step connections directly on the visual graph page (`/graph/visual`) without leaving the graph or using the separate `/graph` table editor. The `type` field ("exit"/"entry") is removed from connections — direction is the only semantics.

---

## Section 1 — Schema Change: Remove `type`

### Migration

New migration removes `type` column and updates the unique constraint:

```sql
ALTER TABLE step_connections DROP COLUMN type;
DROP INDEX IF EXISTS step_connections_source_step_id_target_step_id_type_index;
CREATE UNIQUE INDEX step_connections_source_target_index
  ON step_connections (source_step_id, target_step_id);
```

### Connection schema

Remove from `connection.ex`:
- `field :type, :string`
- `@valid_types`
- `validate_inclusion(:type, @valid_types)`
- `type` from `@required_fields`

Update unique constraint name to `step_connections_source_target_index`.

### Cascading changes

- `Admin.create_connection/1`: no longer requires `type` in attrs
- `Encyclopedia.build_graph/1`: edges no longer have `type`
- `GraphVisualLive.build_json/1`: remove `type` from edge JSON (was unused in JS anyway)
- `GraphLive`: remove `type` references in event handlers and template
- Factory: `connection_factory` removes `type: "exit"`
- Seeder: connection creation removes `type`
- Mix task `ExtractConnections`: removes `type` from connection attrs
- All tests: remove `type` from `insert(:connection, ...)`

---

## Section 2 — LiveView Server Events

`GraphVisualLive` gains two new `handle_event` clauses, guarded by admin check:

### `"create_connection"`

Params: `%{"source" => source_code, "target" => target_code}`

1. Look up source and target steps by code via `Encyclopedia.get_step_by_code/1` (or direct Repo query since admin may need wip steps).
2. Call `Admin.create_connection(%{source_step_id: source.id, target_step_id: target.id})`.
3. On `{:ok, _}`: rebuild graph JSON, assign new `graph_json`, push event `"graph_updated"` with the new JSON to JS.
4. On `{:error, changeset}`: push event `"graph_error"` with message (e.g., "Connection already exists").

### `"delete_connection"`

Params: `%{"source" => source_code, "target" => target_code}`

1. Find the connection by source and target step codes.
2. Call `Admin.delete_connection(connection.id)`.
3. Rebuild and push updated graph JSON.

### Admin guard

Both events check `Accounts.admin?(socket.assigns.current_user)` before processing. Non-admin calls are silently ignored.

### Graph rebuild helper

Extract a `rebuild_and_push_graph/1` private function that:
1. Calls `Encyclopedia.build_graph()`
2. Calls `build_json/1`
3. Recalculates `node_count`, `edge_count`, `categories`
4. Assigns all and returns socket

---

## Section 3 — JS Client Interactions

### Admin detection

The template passes `data-admin={to_string(@is_admin)}` on the graph canvas div. JS reads this to conditionally show edit controls.

### Edit mode toggle

A button in the drawer header area (or the legend bar) toggles `editMode` boolean in the hook state.

When edit mode is ON:
- Drawer shows × buttons next to each connection
- Clicking a node starts "connection creation" flow instead of just opening drawer
- Visual indicator: subtle toolbar or border glow indicating edit mode

When edit mode is OFF:
- Normal behavior (spotlight + drawer, no editing)

### Creating a connection (edge ghost)

1. Admin clicks node A → node A gets a pulsing border animation (CSS class).
2. A ghost edge (dashed line, 50% opacity) follows the mouse cursor from A's position.
3. Admin clicks node B → `pushEvent("create_connection", {source: A.id, target: B.id})`.
4. Admin clicks background → cancels, removes ghost edge and pulsing border.
5. On server response (`"graph_updated"`): hook rebuilds the entire Cytoscape graph with new data.

### Deleting a connection

1. In the drawer, each connection row has a × button (only in edit mode).
2. Click × → inline confirmation: the row changes to "Remover A → B? [Confirmar] [Cancelar]".
3. Click Confirmar → `pushEvent("delete_connection", {source: sourceCode, target: targetCode})`.
4. On server response: graph rebuilt, drawer refreshed for the selected node.

### Server push handling

Hook listens for `"graph_updated"` push event:
```javascript
this.handleEvent("graph_updated", ({graph_json}) => {
  this.el.dataset.graph = graph_json
  this._initGraph() // full rebuild
})
```

And `"graph_error"` for toast/flash:
```javascript
this.handleEvent("graph_error", ({message}) => {
  // Show temporary toast notification
})
```

---

## Section 4 — What Does NOT Change

- Non-admin users see no difference — drawer is read-only, no edit toggle.
- The graph layout algorithm (preset sectors, no Cola) is unchanged.
- The `/graph` admin table editor continues to exist as an alternative.
- Category zones, spotlight, legend — all unchanged.
- The `label` and `description` fields on connections remain (editable via `/graph` table view, not inline for now).

---

## Section 5 — What IS Deferred

- Editing connection `label` inline on the graph — can be done via `/graph` table view for now.
- Drag-to-reorder nodes within sectors — pure visual, no DB impact.
- Sequence generator (subsystem 3) — separate spec.
