// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/forrozin"
import topbar from "../vendor/topbar"
import cytoscape from "../vendor/cytoscape.min"
import cytoscapeCola from "../vendor/cytoscape-cola"

// Registra o plugin cola no Cytoscape
cytoscape.use(cytoscapeCola)

// ---------------------------------------------------------------------------
// Canonical category order for radial sectors.
// ---------------------------------------------------------------------------
const CATEGORY_ORDER = [
  "bases", "sacadas", "travas", "pescadas",
  "caminhadas", "giros", "inversao", "outros",
]

// Hub step codes — visually prominent nodes
const HUB_CODES = ["BF", "GS", "GP", "IV", "SC", "CM-F"]

// The ONE central node — Base frontal is the center of everything
const CENTER_CODE = "BF"

// ---------------------------------------------------------------------------
// Hybrid layout: hubs at center + per-category Cola in fixed sectors
// ---------------------------------------------------------------------------
function runHybridLayout(cy) {
  // 1. Classify: BF at center, all others stay in their category
  const byCat = {}
  cy.nodes().forEach(n => {
    const cat = n.data("categoriaName") || "outros"
    ;(byCat[cat] = byCat[cat] || []).push(n)
  })

  // "bases" category includes BF — BF goes to origin, rest of bases around it
  const activeCats = CATEGORY_ORDER.filter(c => byCat[c]?.length > 0)
  Object.keys(byCat).forEach(c => {
    if (!activeCats.includes(c)) activeCats.push(c)
  })

  // 2. Position BF at absolute center
  const bf = cy.getElementById(CENTER_CODE)
  if (bf.length > 0) bf.position({ x: 0, y: 0 })

  // 3. "bases" cluster radiates directly around BF at a shorter radius
  //    Other categories go to outer sectors with proportional angular size
  const outerCats = activeCats.filter(c => c !== "bases")
  const totalNodes = Object.values(byCat).reduce((s, g) => s + g.length, 0)
  // Scale radius with total node count — more nodes need more space
  const R_OUTER = Math.max(700, 500 + totalNodes * 6)
  const R_BASES = 200
  const NODE_GAP = 155
  const ROW_GAP = 130

  const sectorCenters = {}

  // Bases: small ring around center (BF already at 0,0)
  sectorCenters["bases"] = { x: 0, y: 0, theta: -Math.PI / 2 }
  const basesNodes = (byCat["bases"] || []).filter(n => n.id() !== CENTER_CODE)
  basesNodes.forEach((node, i) => {
    const theta = (2 * Math.PI * i / basesNodes.length) - Math.PI / 2
    node.position({
      x: R_BASES * Math.cos(theta),
      y: R_BASES * Math.sin(theta)
    })
  })

  // Proportional angular allocation: bigger categories get more arc
  const totalOuterNodes = outerCats.reduce((sum, c) => sum + (byCat[c]?.length || 1), 0)
  let currentAngle = -Math.PI / 2 // start at 12 o'clock

  outerCats.forEach(cat => {
    const group = byCat[cat] || []
    const n = group.length
    const arcShare = (n / totalOuterNodes) * 2 * Math.PI
    const theta = currentAngle + arcShare / 2 // center of this sector's arc
    currentAngle += arcShare

    sectorCenters[cat] = { x: R_OUTER * Math.cos(theta), y: R_OUTER * Math.sin(theta), theta }

    const center = sectorCenters[cat]
    const rHat = { x: Math.cos(theta), y: Math.sin(theta) }
    const tHat = { x: -Math.sin(theta), y: Math.cos(theta) }
    const perRow = Math.min(4, Math.ceil(Math.sqrt(n)))
    const rows = Math.ceil(n / perRow)

    group.forEach((node, j) => {
      const row = Math.floor(j / perRow)
      const col = j % perRow
      const colsInRow = (row === rows - 1) ? (n - row * perRow) : perRow
      const colOffset = (col - (colsInRow - 1) / 2) * NODE_GAP
      const rowOffset = (row - (rows - 1) / 2) * ROW_GAP

      node.position({
        x: center.x + tHat.x * colOffset + rHat.x * rowOffset,
        y: center.y + tHat.y * colOffset + rHat.y * rowOffset
      })
    })
  })

  // 4. No Cola — preset positions are final. Clean and predictable.
  cy.fit(undefined, 60)
  drawCategoryZones(cy, sectorCenters, byCat)

  return sectorCenters
}

// ---------------------------------------------------------------------------
// Category zone overlay: ellipses at fixed sector positions (not bounding box)
// ---------------------------------------------------------------------------
function drawCategoryZones(cy, sectorCenters, byCat) {
  const existingCanvas = cy.container().querySelector(".zone-canvas")
  if (existingCanvas) existingCanvas.remove()

  if (!sectorCenters || !byCat) return

  const container = cy.container()
  const canvas = document.createElement("canvas")
  canvas.className = "zone-canvas"
  canvas.width = container.offsetWidth
  canvas.height = container.offsetHeight
  canvas.style.cssText = "position:absolute;top:0;left:0;pointer-events:none;z-index:0;"
  container.insertBefore(canvas, container.firstChild)

  const ctx = canvas.getContext("2d")
  const pan = cy.pan()
  const zoom = cy.zoom()

  Object.entries(byCat).forEach(([cat, catNodes]) => {
    if (catNodes.length < 2) return
    const cor = catNodes[0].data("cor") || "#9a7a5a"

    // Use actual bounding box of category nodes (which are now properly clustered)
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
    catNodes.forEach(n => {
      const pos = n.renderedPosition()
      const w = n.renderedWidth() / 2
      const h = n.renderedHeight() / 2
      minX = Math.min(minX, pos.x - w)
      minY = Math.min(minY, pos.y - h)
      maxX = Math.max(maxX, pos.x + w)
      maxY = Math.max(maxY, pos.y + h)
    })

    const padding = 30
    const cx = (minX + maxX) / 2
    const cy_ = (minY + maxY) / 2
    const rx = (maxX - minX) / 2 + padding
    const ry = (maxY - minY) / 2 + padding
    const r = Math.max(rx, ry, 40) // circle: use the larger dimension

    ctx.beginPath()
    ctx.arc(cx, cy_, r, 0, 2 * Math.PI)
    ctx.fillStyle = cor + "06"
    ctx.fill()
    ctx.strokeStyle = cor + "18"
    ctx.lineWidth = 1.5
    ctx.stroke()
  })
}

// Redraw zones on pan/zoom
function setupZoneRedraw(cy, sectorCenters, byCat) {
  let rafId = null
  const redraw = () => {
    if (rafId) cancelAnimationFrame(rafId)
    rafId = requestAnimationFrame(() => drawCategoryZones(cy, sectorCenters, byCat))
  }
  cy.on("pan zoom resize", redraw)
}

// ---------------------------------------------------------------------------
// Drawer helpers: build HTML content from trusted server data
// NOTE: All data originates from Encyclopedia.build_graph/1 — admin/seeder
// created only. No user-generated content. escapeHTML used defensively.
// ---------------------------------------------------------------------------
function escapeHTML(str) {
  if (!str) return ""
  const div = document.createElement("div")
  div.textContent = str
  return div.innerHTML
}

function buildDrawerHTML(d, outEdges, inEdges, degree, editMode) {
  const parts = []

  parts.push(`<div style="margin-bottom: 20px;">`)
  parts.push(`<div style="font-size: 11px; color: #9a7a5a; letter-spacing: 1px; margin-bottom: 4px;">${escapeHTML(d.id)}</div>`)
  parts.push(`<div style="font-size: 20px; font-weight: 700; color: #1a0e05; line-height: 1.3; margin-bottom: 8px;">${escapeHTML(d.label)}</div>`)
  parts.push(`<span style="display: inline-block; font-size: 10px; padding: 2px 10px; border-radius: 10px; background: ${escapeHTML(d.cor)}18; color: ${escapeHTML(d.cor)}; border: 1px solid ${escapeHTML(d.cor)}40; font-style: italic;">${escapeHTML(d.categoria)}</span>`)
  parts.push(`</div>`)

  if (d.nota) {
    parts.push(`<div style="font-size: 12px; color: #5c3a1a; font-style: italic; line-height: 1.7; margin-bottom: 16px; padding: 10px 14px; background: rgba(212,160,84,0.08); border-left: 3px solid #d4a054; border-radius: 0 4px 4px 0;">${escapeHTML(d.nota)}</div>`)
  }

  parts.push(`<div style="font-size: 11px; color: #7a5c3a; margin-bottom: 16px;">${outEdges.length} saídas · ${inEdges.length} entradas · ${degree} conexões</div>`)

  if (outEdges.length > 0) {
    parts.push(`<div style="font-size: 10px; font-weight: 700; color: #9a7a5a; text-transform: uppercase; letter-spacing: 2px; margin-bottom: 8px;">Saídas →</div>`)
    outEdges.forEach(e => {
      const t = e.target()
      const lb = e.data("label") ? ` <span style="color: #9a7a5a; font-style: italic;">(${escapeHTML(e.data("label"))})</span>` : ""
      const deleteBtn = editMode ? `<button class="delete-connection-btn" data-source="${escapeHTML(d.id)}" data-target="${escapeHTML(t.id())}" style="background:none;border:none;color:#c0392b;cursor:pointer;font-size:14px;padding:0 4px;margin-left:auto;">×</button>` : ""
      parts.push(`<div class="connection-row" style="display:flex;align-items:center;padding: 6px 0; border-bottom: 1px solid rgba(60,40,20,0.06);">`)
      parts.push(`<div class="drawer-link" data-node-id="${escapeHTML(t.id())}" style="font-size: 12px; color: #2c1a0e; cursor: pointer; flex:1;">`)
      parts.push(`<code style="font-size: 10px; color: ${escapeHTML(t.data("cor"))}; margin-right: 6px;">${escapeHTML(t.id())}</code>${escapeHTML(t.data("label"))}${lb}</div>${deleteBtn}</div>`)
    })
  }

  if (inEdges.length > 0) {
    parts.push(`<div style="font-size: 10px; font-weight: 700; color: #9a7a5a; text-transform: uppercase; letter-spacing: 2px; margin: 16px 0 8px;">← Entradas</div>`)
    inEdges.forEach(e => {
      const s = e.source()
      const lb = e.data("label") ? ` <span style="color: #9a7a5a; font-style: italic;">(${escapeHTML(e.data("label"))})</span>` : ""
      const deleteBtn = editMode ? `<button class="delete-connection-btn" data-source="${escapeHTML(s.id())}" data-target="${escapeHTML(d.id)}" style="background:none;border:none;color:#c0392b;cursor:pointer;font-size:14px;padding:0 4px;margin-left:auto;">×</button>` : ""
      parts.push(`<div class="connection-row" style="display:flex;align-items:center;padding: 6px 0; border-bottom: 1px solid rgba(60,40,20,0.06);">`)
      parts.push(`<div class="drawer-link" data-node-id="${escapeHTML(s.id())}" style="font-size: 12px; color: #2c1a0e; cursor: pointer; flex:1;">`)
      parts.push(`<code style="font-size: 10px; color: ${escapeHTML(s.data("cor"))}; margin-right: 6px;">${escapeHTML(s.id())}</code>${escapeHTML(s.data("label"))}${lb}</div>${deleteBtn}</div>`)
    })
  }

  parts.push(`<a href="/steps/${encodeURIComponent(d.id)}" style="display: block; margin-top: 20px; padding: 10px 16px; text-align: center; background: #1a0e05; color: #f2ede4; border-radius: 6px; text-decoration: none; font-size: 12px; letter-spacing: 1px;">Ver passo completo</a>`)

  return parts.join("")
}

function openDrawer(node, cy, editMode, hook) {
  const el = document.getElementById("graph-drawer")
  const content = document.getElementById("drawer-content")
  if (!el || !content) return

  const d = node.data()
  content.innerHTML = buildDrawerHTML(d, node.outgoers("edge"), node.incomers("edge"), node.degree(), editMode)
  el.style.right = "0px"

  // Navigation links
  content.querySelectorAll(".drawer-link").forEach(link => {
    link.addEventListener("click", () => {
      const targetNode = cy.getElementById(link.dataset.nodeId)
      if (targetNode.length > 0) {
        cy.animate({ center: { eles: targetNode }, duration: 300 })
        targetNode.select()
        openDrawer(targetNode, cy, editMode, hook)
        applySpotlight(cy, targetNode)
      }
    })
  })

  // Delete buttons (edit mode only)
  if (editMode && hook) {
    content.querySelectorAll(".delete-connection-btn").forEach(btn => {
      btn.addEventListener("click", function() {
        const source = this.dataset.source
        const target = this.dataset.target
        const row = this.closest(".connection-row")

        // Show confirmation inline
        const confirmDiv = document.createElement("div")
        confirmDiv.style.cssText = "padding:6px 0;font-size:11px;color:#c0392b;"
        const confirmText = document.createTextNode(`Remover ${source} → ${target}? `)
        const confirmBtn = document.createElement("button")
        confirmBtn.textContent = "Confirmar"
        confirmBtn.style.cssText = "background:#c0392b;color:white;border:none;padding:3px 10px;border-radius:3px;cursor:pointer;font-family:Georgia,serif;font-size:11px;margin-right:6px;"
        const cancelBtn = document.createElement("button")
        cancelBtn.textContent = "Cancelar"
        cancelBtn.style.cssText = "background:transparent;color:#9a7a5a;border:1px solid #9a7a5a40;padding:3px 10px;border-radius:3px;cursor:pointer;font-family:Georgia,serif;font-size:11px;"

        confirmDiv.appendChild(confirmText)
        confirmDiv.appendChild(confirmBtn)
        confirmDiv.appendChild(cancelBtn)

        row.textContent = ""
        row.appendChild(confirmDiv)

        confirmBtn.addEventListener("click", () => {
          hook.pushEvent("delete_connection", { source, target })
        })
        cancelBtn.addEventListener("click", () => {
          // Re-open drawer to restore original state
          openDrawer(node, cy, editMode, hook)
        })
      })
    })
  }
}

function closeDrawer() {
  const el = document.getElementById("graph-drawer")
  if (el) el.style.right = "-380px"
}

// ---------------------------------------------------------------------------
// Spotlight: dim everything except selected node neighborhood
// ---------------------------------------------------------------------------
function applySpotlight(cy, node) {
  cy.batch(() => {
    cy.elements().style({ opacity: 0.2 })
    const nh = node.closedNeighborhood()
    nh.style({ opacity: 1 })
    nh.edges().style({ opacity: 0.85, width: 2.5 })
    node.style({ opacity: 1 })
  })
}

function clearSpotlight(cy) {
  cy.batch(() => {
    cy.nodes().style({ opacity: 1 })
    cy.edges().style({ opacity: 0.45, width: 1.5 })
  })
}

function applyCategorySpotlight(cy, categoryName) {
  cy.batch(() => {
    cy.elements().style({ opacity: 0.15 })
    const catNodes = cy.nodes(`[categoriaName = "${categoryName}"]`)
    catNodes.style({ opacity: 1 })
    catNodes.connectedEdges().style({ opacity: 0.7, width: 2 })
    catNodes.connectedEdges().connectedNodes().style({ opacity: 0.6 })
    catNodes.style({ opacity: 1 })
  })
}

// ---------------------------------------------------------------------------
// Hook: GraphVisual — sector layout + cola physics + spotlight + drawer
// ---------------------------------------------------------------------------
const GraphVisual = {
  mounted() {
    this._initGraph()

    // Listen for server push events
    this.handleEvent("graph_updated", ({ graph_json, edit_mode, orphans }) => {
      this.el.dataset.graph = graph_json
      this.el.dataset.editMode = edit_mode
      this._initGraph()
      if (orphans) this._renderOrphans(JSON.parse(orphans))
    })

    this.handleEvent("graph_error", ({ message }) => {
      this._showToast(message)
    })
  },

  updated() { this._initGraph() },

  _showToast(message) {
    const toast = document.createElement("div")
    toast.textContent = message
    toast.style.cssText = "position:fixed;top:70px;left:50%;transform:translateX(-50%);background:#c0392b;color:white;padding:8px 20px;border-radius:6px;font-family:Georgia,serif;font-size:12px;z-index:200;opacity:0;transition:opacity 0.3s;"
    document.body.appendChild(toast)
    requestAnimationFrame(() => { toast.style.opacity = "1" })
    setTimeout(() => { toast.style.opacity = "0"; setTimeout(() => toast.remove(), 300) }, 2500)
  },

  _renderOrphans(orphans) {
    const list = document.getElementById("orphan-list")
    if (!list) return
    if (!orphans || orphans.length === 0) {
      list.textContent = "Nenhum passo órfão"
      list.style.cssText = "font-size:11px;color:#9a7a5a;font-style:italic;padding:8px 0;"
      return
    }

    list.textContent = ""
    const hook = this

    orphans.forEach(o => {
      const btn = document.createElement("button")
      btn.style.cssText = `display:flex;align-items:center;gap:6px;width:100%;padding:6px 8px;margin-bottom:4px;border:1px solid ${o.cor}40;border-radius:4px;background:white;cursor:pointer;font-family:Georgia,serif;font-size:11px;color:#2c1a0e;text-align:left;`
      const dot = document.createElement("span")
      dot.style.cssText = `width:6px;height:6px;border-radius:50%;background:${o.cor};flex-shrink:0;`
      const label = document.createElement("span")
      label.textContent = `${o.id} — ${o.nome}`
      btn.appendChild(dot)
      btn.appendChild(label)

      btn.addEventListener("click", () => {
        // Start connection creation from this orphan
        // The orphan may not be on the graph yet, so we store the code
        // and handle it in the next tap on a graph node
        hook._pendingOrphanSource = o.id
        hook._showToast(`Clique num passo no grafo para conectar ${o.id} →`)
        // Highlight the button
        list.querySelectorAll("button").forEach(b => b.style.background = "white")
        btn.style.background = "#c0392b15"
      })

      list.appendChild(btn)
    })
  },

  _initGraph() {
    const el = this.el
    const raw = el.dataset.graph
    if (!raw) return

    const { nodes, edges } = JSON.parse(raw)
    if (this._cy) { this._cy.destroy(); this._cy = null }

    // Build elements: step nodes + edges (no compound parents)
    const elements = []

    nodes.forEach(n => {
      elements.push({
        data: {
          id: n.id, label: n.nome, categoria: n.categoria,
          categoriaName: n.categoriaName, cor: n.cor || "#9a7a5a",
          nota: n.nota
        }
      })
    })

    edges.forEach(e => {
      const d = { source: e.from, target: e.to, spread: e.spread || 0 }
      if (e.label) d.label = e.label
      elements.push({ data: d })
    })

    const cy = cytoscape({
      container: el,
      elements,
      style: [
        {
          selector: "node",
          style: {
            "shape": "roundrectangle",
            "width": "label",
            "height": "label",
            "padding": function(e) {
              const HUB_CODES = ["BF", "GS", "GP", "IV", "SC", "CM-F"]
              if (HUB_CODES.includes(e.id())) return "20px 30px"
              return e.degree() >= 10 ? "12px 18px" : "8px 14px"
            },
            "background-color": "#fffef9",
            "border-width": function(e) {
              const HUB_CODES = ["BF", "GS", "GP", "IV", "SC", "CM-F"]
              if (HUB_CODES.includes(e.id())) return 5
              return e.degree() >= 10 ? 3 : 2
            },
            "border-color": "data(cor)", "border-opacity": 0.85,
            "label": function(e) { return e.id() + "\n" + e.data("label") },
            "text-wrap": "wrap", "text-halign": "center", "text-valign": "center",
            "font-family": "Georgia, serif",
            "font-size": function(e) {
              const HUB_CODES = ["BF", "GS", "GP", "IV", "SC", "CM-F"]
              if (HUB_CODES.includes(e.id())) return 19
              const d = e.degree()
              return d >= 12 ? 15 : d >= 6 ? 14 : 13
            },
            "color": "#1a0e05", "text-max-width": "180px",
            "min-width": "80px",
            "shadow-blur": function(e) {
              const HUB_CODES = ["BF", "GS", "GP", "IV", "SC", "CM-F"]
              if (HUB_CODES.includes(e.id())) return 20
              return e.degree() >= 10 ? 10 : 4
            },
            "shadow-color": "rgba(60,40,20,0.12)",
            "shadow-offset-x": 0, "shadow-offset-y": 2, "shadow-opacity": 1
          }
        },
        {
          selector: "node:selected",
          style: {
            "background-color": "data(cor)", "background-opacity": 0.15,
            "border-width": 3, "border-opacity": 1, "shadow-blur": 16, "shadow-opacity": 1
          }
        },
        { selector: "node:grabbed", style: { "shadow-blur": 20, "shadow-opacity": 1 } },
        {
          selector: "edge",
          style: {
            "width": 1.5, "line-color": "data(cor)", "line-opacity": 0.45,
            "target-arrow-color": "data(cor)", "target-arrow-shape": "triangle", "arrow-scale": 0.9,
            "curve-style": "unbundled-bezier",
            "control-point-distances": function(e) { return e.data("spread") || 0 },
            "control-point-weights": 0.5
          }
        },
        {
          selector: "edge[label]",
          style: {
            "label": "data(label)", "font-size": "10px", "font-family": "Georgia, serif",
            "font-style": "italic", "text-rotation": "autorotate", "text-margin-y": -10,
            "color": "#3a2510", "text-background-color": "#fffdf8",
            "text-background-opacity": 0.92, "text-background-padding": "3px",
            "text-background-shape": "roundrectangle",
            "text-border-width": 0.8, "text-border-color": "data(cor)", "text-border-opacity": 0.6
          }
        }
      ],
      wheelSensitivity: 0.3, minZoom: 0.06, maxZoom: 5
    })

    this._cy = cy

    // Inherit source category color to edges — except edges pointing to BF get black
    cy.edges().forEach(edge => {
      if (edge.target().id() === CENTER_CODE) {
        edge.data("cor", "#1a1a1a")
      } else {
        edge.data("cor", edge.source().data("cor") || "#9a7a5a")
      }
    })

    // ── Hybrid layout: hubs at center + per-category Cola ──
    const sectorCenters = runHybridLayout(cy)

    // Collect byCat for zone redraw
    const byCat = {}
    cy.nodes().forEach(n => {
      const cat = n.data("categoriaName") || "outros"
      ;(byCat[cat] = byCat[cat] || []).push(n)
    })
    setupZoneRedraw(cy, sectorCenters, byCat)

    // ── Drag-release: just redraw zones, no re-layout ──
    cy.on("dragfreeon", "node", () => {
      drawCategoryZones(cy, sectorCenters, byCat)
    })

    // ── Interactions ──
    let activeCategory = null
    const hook = this
    const isAdmin = el.dataset.admin === "true"
    const isEditMode = el.dataset.editMode === "true"
    let ghostSourceId = this._pendingOrphanSource || null
    this._pendingOrphanSource = null

    // Ghost edge line (canvas overlay for connection creation)
    let ghostLine = null
    if (isEditMode && ghostSourceId) {
      // Highlight that we're waiting for target
      hook._showToast(`Clique num passo para conectar ${ghostSourceId} →`)
    }

    function cancelGhost() {
      ghostSourceId = null
      if (ghostLine) { ghostLine.remove(); ghostLine = null }
      cy.nodes().style({ "border-style": "solid" })
    }

    cy.on("tap", "node", function(evt) {
      const node = evt.target

      // Edit mode: connection creation flow
      if (isEditMode && isAdmin) {
        // Check for pending orphan source (from left panel)
        if (hook._pendingOrphanSource) {
          const orphanCode = hook._pendingOrphanSource
          hook._pendingOrphanSource = null
          hook.pushEvent("create_connection", { source: orphanCode, target: node.id() })
          return
        }

        if (ghostSourceId) {
          // Second click — create connection
          const targetId = node.id()
          if (targetId !== ghostSourceId) {
            hook.pushEvent("create_connection", { source: ghostSourceId, target: targetId })
          }
          cancelGhost()
          return
        } else {
          // First click — start ghost edge
          ghostSourceId = node.id()
          node.style({ "border-style": "dashed", "border-width": 4 })
          hook._showToast(`${node.id()} selecionado — clique no destino`)
        }
      }

      activeCategory = null
      applySpotlight(cy, node)
      openDrawer(node, cy, isEditMode && isAdmin, hook)
    })

    cy.on("tap", function(evt) {
      if (evt.target === cy) {
        if (ghostSourceId) { cancelGhost(); return }
        clearSpotlight(cy); closeDrawer(); activeCategory = null; resetLegend()
      }
    })

    cy.on("mouseover", "node", function(evt) {
      if (document.getElementById("graph-drawer").style.right === "0px") return
      const node = evt.target
      cy.batch(() => {
        cy.elements().style({ opacity: 0.25 })
        const nh = node.closedNeighborhood()
        nh.style({ opacity: 1 }); nh.edges().style({ opacity: 0.75 })
      })
    })

    cy.on("mouseout", "node", function() {
      if (document.getElementById("graph-drawer").style.right === "0px") return
      if (!activeCategory) clearSpotlight(cy)
    })

    document.getElementById("drawer-close")?.addEventListener("click", () => {
      closeDrawer(); clearSpotlight(cy); cancelGhost()
    })

    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape") {
        cancelGhost()
        closeDrawer(); clearSpotlight(cy); activeCategory = null; resetLegend()
      }
    })

    // Legend buttons
    const legendBtns = document.querySelectorAll("#graph-legend button[data-category]")
    function resetLegend() {
      legendBtns.forEach(b => { b.style.background = "transparent"; b.style.fontWeight = "normal" })
    }

    legendBtns.forEach(btn => {
      btn.addEventListener("click", () => {
        const catName = btn.dataset.category
        closeDrawer()
        if (activeCategory === catName) {
          activeCategory = null; clearSpotlight(cy); resetLegend(); return
        }
        activeCategory = catName
        applyCategorySpotlight(cy, catName)
        resetLegend()
        btn.style.background = "rgba(60,40,20,0.08)"; btn.style.fontWeight = "700"
      })
    })
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, GraphVisual},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

