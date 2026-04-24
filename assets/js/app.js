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
import {hooks as colocatedHooks} from "phoenix-colocated/o_grupo_de_estudos"
import topbar from "../vendor/topbar"
import ThreeCanvas from "./three_canvas"

// ---------------------------------------------------------------------------
// Canonical category order for radial sectors.
// ---------------------------------------------------------------------------
const CATEGORY_ORDER = [
  "sacadas", "travas", "pescadas", "caminhadas",
  "giros", "convencoes", "inversao", "outros",
]

// The ONE central node — Base frontal is the center of everything
const CENTER_CODE = "BF"

// ---------------------------------------------------------------------------
// Utility: circled Unicode number for sequence labels
// ---------------------------------------------------------------------------
function circledNumber(n) {
  const circled = ["①","②","③","④","⑤","⑥","⑦","⑧","⑨","⑩",
                   "⑪","⑫","⑬","⑭","⑮","⑯","⑰","⑱","⑲","⑳"]
  return n >= 1 && n <= 20 ? circled[n - 1] : `(${n})`
}

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
  const hasOrphans = cy.nodes().some(n => n.connectedEdges().length === 0)
  // Normal mode: compact. Edit mode with orphans: expand to fit
  const R_OUTER = hasOrphans ? Math.max(900, 600 + totalNodes * 6) : 850
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

  // Proportional angular allocation with minimum arc per category
  const MIN_ARC = Math.PI / 5 // ~36 degrees minimum per category
  const rawArcs = outerCats.map(c => Math.max(byCat[c]?.length || 1, 3))
  const totalWeight = rawArcs.reduce((s, w) => s + w, 0)
  // Scale so total = 2π, but enforce minimum
  let arcs = rawArcs.map(w => Math.max((w / totalWeight) * 2 * Math.PI, MIN_ARC))
  const arcTotal = arcs.reduce((s, a) => s + a, 0)
  arcs = arcs.map(a => (a / arcTotal) * 2 * Math.PI) // normalize to exactly 2π

  let currentAngle = -Math.PI / 2

  outerCats.forEach((cat, catIdx) => {
    const group = byCat[cat] || []
    const n = group.length
    const arcShare = arcs[catIdx]
    const theta = currentAngle + arcShare / 2
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

    const padding = 50
    const cx = (minX + maxX) / 2
    const cy_ = (minY + maxY) / 2
    const rx = (maxX - minX) / 2 + padding
    const ry = (maxY - minY) / 2 + padding
    const r = Math.max(rx, ry, 40) // circle: use the larger dimension

    ctx.beginPath()
    ctx.arc(cx, cy_, r, 0, 2 * Math.PI)
    ctx.fillStyle = cor + "15"
    ctx.fill()
    ctx.strokeStyle = cor + "35"
    ctx.lineWidth = 2
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

function isMobileViewport() {
  return window.matchMedia && window.matchMedia("(max-width: 767px)").matches
}

function buildDrawerActionHTML(d) {
  const isLiked = window._likedStepCodes && window._likedStepCodes.has(d.id)
  const isFavorited = window._favoritedStepCodes && window._favoritedStepCodes.has(d.id)
  const likeCount = d.like_count || 0

  const heartSolidPath = `m11.645 20.91-.007-.003-.022-.012a15.247 15.247 0 0 1-.383-.218 25.18 25.18 0 0 1-4.244-3.17C4.688 15.36 2.25 12.174 2.25 8.25 2.25 5.322 4.714 3 7.688 3A5.5 5.5 0 0 1 12 5.052 5.5 5.5 0 0 1 16.313 3c2.973 0 5.437 2.322 5.437 5.25 0 3.925-2.438 7.111-4.739 9.256a25.175 25.175 0 0 1-4.244 3.17 15.247 15.247 0 0 1-.383.219l-.022.012-.007.004-.003.001a.752.752 0 0 1-.704 0l-.003-.001Z`
  const heartOutlinePath = `M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12Z`
  const starSolidPath = `M10.788 3.21c.448-1.077 1.976-1.077 2.424 0l2.082 5.006 5.404.434c1.164.093 1.636 1.545.749 2.305l-4.117 3.527 1.257 5.273c.271 1.136-.964 2.033-1.96 1.425L12 18.354 7.373 21.18c-.996.608-2.231-.29-1.96-1.425l1.257-5.273-4.117-3.527c-.887-.76-.415-2.212.749-2.305l5.404-.434 2.082-5.005Z`
  const starOutlinePath = `M11.48 3.499a.562.562 0 0 1 1.04 0l2.125 5.111a.563.563 0 0 0 .475.345l5.518.442c.499.04.701.663.321.988l-4.204 3.602a.563.563 0 0 0-.182.557l1.285 5.385a.562.562 0 0 1-.84.61l-4.725-2.885a.562.562 0 0 0-.586 0L6.982 20.54a.562.562 0 0 1-.84-.61l1.285-5.386a.562.562 0 0 0-.182-.557l-4.204-3.602a.562.562 0 0 1 .321-.988l5.518-.442a.563.563 0 0 0 .475-.345L11.48 3.5Z`

  const heartIcon = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" ${isLiked ? 'fill="currentColor"' : 'fill="none" stroke="currentColor" stroke-width="1.5"'} style="width:18px;height:18px;flex-shrink:0;"><path stroke-linecap="round" stroke-linejoin="round" d="${isLiked ? heartSolidPath : heartOutlinePath}"/></svg>`
  const starIcon = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" ${isFavorited ? 'fill="currentColor"' : 'fill="none" stroke="currentColor" stroke-width="1.5"'} style="width:18px;height:18px;flex-shrink:0;"><path stroke-linecap="round" stroke-linejoin="round" d="${isFavorited ? starSolidPath : starOutlinePath}"/></svg>`

  return [
    `<button class="drawer-like-btn" data-code="${escapeHTML(d.id)}" aria-label="Curtir" title="${isLiked ? "Remover curtida" : "Curtir"}" style="display:inline-flex;align-items:center;justify-content:center;gap:4px;min-width:36px;height:36px;background:transparent;border:1px solid ${isLiked ? "#c0392b40" : "rgba(60,40,20,0.12)"};border-radius:8px;cursor:pointer;color:${isLiked ? "#c0392b" : "#9a7a5a"};font-family:Georgia,serif;transition:all 0.15s;">${heartIcon}<span style="font-size:11px;font-weight:700;">${likeCount}</span></button>`,
    `<button class="drawer-fav-btn" data-code="${escapeHTML(d.id)}" aria-label="Favoritar" title="${isFavorited ? "Remover favorito" : "Favoritar"}" style="display:inline-flex;align-items:center;justify-content:center;min-width:36px;height:36px;background:transparent;border:1px solid ${isFavorited ? "#b4782840" : "rgba(60,40,20,0.12)"};border-radius:8px;cursor:pointer;color:${isFavorited ? "#b47828" : "#9a7a5a"};font-family:Georgia,serif;transition:all 0.15s;">${starIcon}</button>`
  ].join("")
}

function buildDrawerHeaderHTML(d) {
  const category = d.categoria
    ? `<span style="display:inline-block;font-size:10px;padding:2px 10px;border-radius:10px;background:${escapeHTML(d.cor)}18;color:${escapeHTML(d.cor)};border:1px solid ${escapeHTML(d.cor)}40;font-style:italic;">${escapeHTML(d.categoria)}</span>`
    : ""

  return [
    `<div style="display:flex;align-items:flex-start;gap:12px;">`,
    `<div style="min-width:0;flex:1;">`,
    `<div style="font-size:11px;color:#9a7a5a;letter-spacing:1px;margin-bottom:4px;">${escapeHTML(d.id)}</div>`,
    `<div style="font-size:20px;font-weight:700;color:#1a0e05;line-height:1.3;margin-bottom:8px;">${escapeHTML(d.label)}</div>`,
    category,
    `</div>`,
    `<div style="display:flex;flex-shrink:0;align-items:center;gap:6px;">${buildDrawerActionHTML(d)}</div>`,
    `</div>`
  ].join("")
}

function buildDrawerBodyHTML(d, outEdges, inEdges, degree, editMode) {
  const parts = []

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

  parts.push(`<a href="/steps/${encodeURIComponent(d.id)}" style="display: block; margin-top: 16px; padding: 12px 16px; text-align: center; background: #1a0e05; color: #f2ede4; border-radius: 6px; text-decoration: none; font-size: 13px; font-weight: 600; letter-spacing: 0.3px;">Ver passo completo</a>`)

  return parts.join("")
}

function openDrawer(node, cy, editMode, hook) {
  const el = document.getElementById("graph-drawer")
  const header = document.getElementById("drawer-header-content")
  const content = document.getElementById("drawer-content")
  if (!el || !header || !content) return

  if (isMobileViewport()) {
    closeDrawer()
    return
  }

  const d = node.data()
  header.innerHTML = buildDrawerHeaderHTML(d)
  content.innerHTML = buildDrawerBodyHTML(d, node.outgoers("edge"), node.incomers("edge"), node.degree(), editMode)
  el.style.transform = "translateX(0)"
  el.dataset.open = "true"
  el.removeAttribute("inert")

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

  // Like + Favorite buttons in drawer
  if (hook) {
    el.querySelectorAll(".drawer-like-btn").forEach(btn => {
      btn.addEventListener("click", () => {
        hook.pushEvent("toggle_step_like_graph", { code: btn.dataset.code })
        // Optimistic UI update
        setTimeout(() => openDrawer(node, cy, editMode, hook), 300)
      })
    })
    el.querySelectorAll(".drawer-fav-btn").forEach(btn => {
      btn.addEventListener("click", () => {
        hook.pushEvent("toggle_step_favorite_graph", { code: btn.dataset.code })
        setTimeout(() => openDrawer(node, cy, editMode, hook), 300)
      })
    })
  }
}

function closeDrawer() {
  const el = document.getElementById("graph-drawer")
  if (el) {
    el.style.transform = "translateX(100%)"
    el.dataset.open = "false"
    el.setAttribute("inert", "")
  }
}

// ---------------------------------------------------------------------------
// Spotlight: dim everything except selected node neighborhood
// ---------------------------------------------------------------------------
function applySpotlight(cy, node) {
  if (window._seqHighlightActive) return
  cy.batch(() => {
    cy.elements().style({ opacity: 0.2 })
    const nh = node.closedNeighborhood()
    nh.style({ opacity: 1 })
    nh.edges().style({ opacity: 0.85, width: 2.5 })
    node.style({ opacity: 1 })
  })
}

function clearSpotlight(cy) {
  if (window._seqHighlightActive) return
  cy.batch(() => {
    cy.nodes().style({ opacity: 1 })
    cy.edges().style({ opacity: 0.45, width: 1.5 })
  })
  applyLikedStepStyling()
}

function applyCategorySpotlight(cy, categoryName) {
  if (window._seqHighlightActive) return
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
// Liked step styling: red border on nodes the current user has liked
// ---------------------------------------------------------------------------
function applyLikedStepStyling() {
  if (!window._cytoscape || !window._likedStepCodes) return
  const cy = window._cyInstance
  if (!cy) return

  cy.nodes().forEach(node => {
    if (window._likedStepCodes.has(node.id())) {
      node.style({
        'border-width': node.data('highlighted') ? 5 : (node.degree() >= 10 ? 3 : 2.5),
        'border-color': '#c0392b'
      })
    } else {
      // Only reset the border-color if the node isn't actively selected/spotlighted
      // and sequence highlight isn't active (sequence takes full precedence)
      if (!window._seqHighlightActive) {
        node.style({
          'border-color': node.data('cor') || '#9a7a5a'
        })
      }
    }
  })
}

// ---------------------------------------------------------------------------
// Hook: GraphVisual — sector layout + cola physics + spotlight + drawer
// ---------------------------------------------------------------------------
const GraphVisual = {
  async mounted() {
    // Lazy-load Cytoscape + cola (only on /graph/visual)
    const [{ default: cytoscape }, { default: cytoscapeCola }] = await Promise.all([
      import("../vendor/cytoscape.min"),
      import("../vendor/cytoscape-cola"),
    ])
    cytoscape.use(cytoscapeCola)
    window._cytoscape = cytoscape

    this._bindGraphLegendInteractions()
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

    // Sequence highlight events — retry if graph not ready yet
    this.handleEvent("highlight_sequence", ({ steps }) => {
      if (this._manualMode || this.el.dataset.manualMode === "true") return

      if (this._cy) {
        this._applySequenceHighlight(steps)
      } else {
        // Graph not initialized yet (happens when navigating from community)
        // Retry after layout completes
        this._pendingHighlight = steps
      }
    })

    this.handleEvent("clear_highlight", () => {
      this._clearSequenceHighlight()
    })

    this.handleEvent("focus_graph_node", ({ code }) => {
      this._focusGraphNode(code)
    })

    this.handleEvent("clear_graph_focus", () => {
      this._clearGraphFocus()
    })

    // Autocomplete helpers: server sets input value via JS push
    this.handleEvent("set_start_step_input", ({ value }) => {
      const input = document.getElementById("seq-start-input")
      if (input) input.value = value
    })

    this.handleEvent("clear_required_input", () => {
      const input = document.getElementById("seq-required-input")
      if (input) input.value = ""
    })

    // Manual mode toggle
    this.handleEvent("set_manual_mode", ({ active }) => {
      this._manualMode = active
      this.el.dataset.manualMode = active ? "true" : "false"
      if (active) {
        this._clearSequenceHighlight({ refit: false })
      } else {
        this._clearManualStepGuide()
      }
    })

    // Liked steps: highlight with red border
    this.handleEvent("set_liked_steps", ({ codes }) => {
      window._likedStepCodes = new Set(codes)
      applyLikedStepStyling()
    })

    // Favorited steps (for drawer buttons)
    this.handleEvent("set_favorited_steps", ({ codes }) => {
      window._favoritedStepCodes = new Set(codes)
    })
  },

  updated() {
    if (this._graphSignatureValue !== this._graphSignature()) {
      this._initGraph()
    }
  },

  destroyed() {
    if (this._graphLegendClickHandler) {
      document.removeEventListener("click", this._graphLegendClickHandler)
      this._graphLegendClickHandler = null
    }
  },

  _graphSignature() {
    return [
      this.el.dataset.graph || "",
      this.el.dataset.editMode || "",
      this.el.dataset.admin || "",
      this.el.dataset.userId || ""
    ].join("|")
  },

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

    const graphSignature = this._graphSignature()
    if (this._cy && this._graphSignatureValue === graphSignature) return

    const { nodes, edges } = JSON.parse(raw)
    if (this._cy) { this._cy.destroy(); this._cy = null }
    this._graphSignatureValue = graphSignature
    this._manualGuideActive = false
    this._manualGuideSourceId = null

    const currentUserId = el.dataset.userId
    this._currentUserId = currentUserId

    // Build elements: step nodes + edges (no compound parents)
    const elements = []
    const nodeColorById = {}

    nodes.forEach(n => {
      nodeColorById[n.id] = n.cor || "#9a7a5a"

      elements.push({
        data: {
          id: n.id, label: n.nome, categoria: n.categoria,
          categoriaName: n.categoriaName, cor: n.cor || "#9a7a5a",
          nota: n.nota,
          highlighted: n.highlighted || false,
          suggested: n.suggested || false,
          suggestedById: n.suggested_by_id
        }
      })
    })

    edges.forEach(e => {
      const d = {
        source: e.from,
        target: e.to,
        spread: e.spread || 0,
        cor: e.to === CENTER_CODE ? "#1a1a1a" : nodeColorById[e.from] || "#9a7a5a"
      }
      if (e.label) d.label = e.label
      elements.push({ data: d, selectable: false })
    })

    const cy = window._cytoscape({
      container: el,
      elements,
      style: [
        {
          selector: "node",
          style: {
            "shape": "roundrectangle",
            "width": function(e) {
              if (e.data("highlighted")) return 132
              return e.degree() >= 10 ? 104 : 88
            },
            "height": function(e) {
              if (e.data("highlighted")) return 76
              return e.degree() >= 10 ? 58 : 48
            },
            "padding": function(e) {
              if (e.data("highlighted")) return "20px 30px"
              return e.degree() >= 10 ? "12px 18px" : "8px 14px"
            },
            "background-color": function(e) {
              return (e.data("suggestedById") && e.data("suggestedById") === currentUserId) ? "#fce4ec" : "#fffef9"
            },
            "border-width": function(e) {
              if (e.data("highlighted")) return 5
              return e.degree() >= 10 ? 3 : 2
            },
            "border-color": "data(cor)", "border-opacity": 0.85,
            "border-style": function(e) { return e.data("suggested") ? "dashed" : "solid" },
            "label": function(e) { return e.id() + "\n" + e.data("label") },
            "text-wrap": "wrap", "text-halign": "center", "text-valign": "center",
            "font-family": "Georgia, serif",
            "font-size": function(e) {
              if (e.data("highlighted")) return 19
              const d = e.degree()
              return d >= 12 ? 15 : d >= 6 ? 14 : 13
            },
            "color": "#1a0e05", "text-max-width": "180px",
            "min-width": "80px"
          }
        },
        {
          selector: "node:selected",
          style: {
            "background-color": "data(cor)", "background-opacity": 0.15,
            "border-width": 3, "border-opacity": 1
          }
        },
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
      minZoom: 0.06, maxZoom: 5,
      autoungrabifyNodes: true
    })

    this._cy = cy
    window._cyInstance = cy
    cy.edges().unselectify()

    // ── Hybrid layout: hubs at center + per-category Cola ──
    const sectorCenters = runHybridLayout(cy)

    // Apply liked step borders after layout (layout is synchronous here)
    applyLikedStepStyling()

    const initialSequenceSteps = this._consumeInitialSequenceSteps()
    if (initialSequenceSteps && initialSequenceSteps.length > 0) {
      this._pendingHighlight = initialSequenceSteps
    }

    // Apply pending sequence highlight (from ?seq= param navigation)
    if (this._pendingHighlight) {
      setTimeout(() => {
        this._applySequenceHighlight(this._pendingHighlight)
        this._pendingHighlight = null
      }, 500)
    }

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
    const hook = this
    this._activeCategory = null
    const isAdmin = el.dataset.admin === "true"
    const isEditMode = el.dataset.editMode === "true"
    this._isAdmin = isAdmin
    this._isEditMode = isEditMode
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

      // Manual sequence mode: clicking a node appends it to the manual list
      if (hook._manualMode || hook.el.dataset.manualMode === "true") {
        if (hook._seqHighlightActive) {
          hook._clearSequenceHighlight({ refit: false })
          hook.pushEvent("clear_highlight", {})
        }
        hook.pushEvent("add_manual_step", { code: node.id(), name: node.data("label") || node.id() })
        hook._applyManualStepGuide(node)
        return
      }

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

      hook._activeCategory = null
      hook._resetLegend()
      applySpotlight(cy, node)
      openDrawer(node, cy, isEditMode && isAdmin, hook)
    })

    cy.on("tap", function(evt) {
      if (evt.target === cy) {
        if (ghostSourceId) { cancelGhost(); return }
        if (hook._manualMode || hook.el.dataset.manualMode === "true") {
          hook._clearManualStepGuide()
          return
        }
        clearSpotlight(cy)
        closeDrawer()
        hook._activeCategory = null
        hook._resetLegend()
      }
    })

    cy.on("mouseover", "node", function(evt) {
      if (document.getElementById("graph-drawer").dataset.open === "true") return
      if (hook._seqHighlightActive) return // Don't interfere with sequence highlight
      if (hook._manualGuideActive) return // Manual mode keeps outgoing options fixed.
      if (hook._activeCategory) return // Category filters stay fixed until the user changes them.
      const node = evt.target
      cy.batch(() => {
        cy.elements().style({ opacity: 0.25 })
        const nh = node.closedNeighborhood()
        nh.style({ opacity: 1 }); nh.edges().style({ opacity: 0.75 })
      })
    })

    cy.on("mouseout", "node", function() {
      if (document.getElementById("graph-drawer").dataset.open === "true") return
      if (hook._seqHighlightActive) return // Don't clear sequence highlight
      if (hook._manualGuideActive) return // Manual mode keeps outgoing options fixed.
      if (!hook._activeCategory) clearSpotlight(cy)
    })

    document.getElementById("drawer-close")?.addEventListener("click", () => {
      closeDrawer(); clearSpotlight(cy); cancelGhost()
    })

    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape") {
        // If sequence is active, clear it first (single-purpose Escape)
        if (hook._seqHighlightActive) {
          hook._clearSequenceHighlight()
          hook.pushEvent("clear_highlight", {})
          return
        }
        if (hook._manualGuideActive) {
          hook._clearManualStepGuide()
          return
        }
        cancelGhost()
        closeDrawer()
        hook._closeMobileLegend()
        clearSpotlight(cy)
        hook._activeCategory = null
        hook._resetLegend()
      }
    })
  },

  _bindGraphLegendInteractions() {
    if (this._graphLegendClickHandler) return

    this._graphLegendClickHandler = event => {
      const toggle = event.target.closest?.("#graph-legend-mobile-toggle")

      if (toggle) {
        const panel = document.getElementById("graph-legend-mobile-panel")
        if (!panel) return

        const willOpen = panel.classList.contains("hidden")
        panel.classList.toggle("hidden", !willOpen)
        toggle.setAttribute("aria-expanded", willOpen ? "true" : "false")
        return
      }

      const btn = event.target.closest?.("[data-graph-legend-filter][data-category]")
      if (!btn) return

      const cy = this._cy
      if (!cy) return

      const catName = btn.dataset.category
      closeDrawer()
      this._closeMobileLegend()

      const sequenceActive = this._seqHighlightActive || window._seqHighlightActive

      if (this._activeCategory === catName && !sequenceActive) {
        this._activeCategory = null
        clearSpotlight(cy)
        this._resetLegend()
        return
      }

      const applyCategory = () => {
        if (!this._cy) return
        this._activeCategory = catName
        applyCategorySpotlight(this._cy, catName)
        this._resetLegend()
        this._activateLegendCategory(catName)
      }

      if (sequenceActive) {
        this._clearSequenceHighlight({ refit: false })
        this.pushEvent("clear_highlight", {})
        setTimeout(applyCategory, 120)
        return
      }

      applyCategory()
    }

    document.addEventListener("click", this._graphLegendClickHandler)
  },

  _resetLegend() {
    document.querySelectorAll("[data-graph-legend-filter][data-category]").forEach(btn => {
      btn.style.background = ""
      btn.style.fontWeight = ""
      btn.setAttribute("aria-pressed", "false")
    })
  },

  _activateLegendCategory(catName) {
    document.querySelectorAll("[data-graph-legend-filter][data-category]").forEach(btn => {
      if (btn.dataset.category !== catName) return
      btn.style.background = "rgba(60,40,20,0.08)"
      btn.style.fontWeight = "700"
      btn.setAttribute("aria-pressed", "true")
    })
  },

  _closeMobileLegend() {
    const panel = document.getElementById("graph-legend-mobile-panel")
    const toggle = document.getElementById("graph-legend-mobile-toggle")
    if (!panel || !toggle) return

    panel.classList.add("hidden")
    toggle.setAttribute("aria-expanded", "false")
  },

  _consumeInitialSequenceSteps() {
    const raw = this.el.dataset.initialSequenceSteps
    if (!raw || raw === "[]") return null

    this.el.dataset.initialSequenceSteps = ""

    try {
      const steps = JSON.parse(raw)
      return Array.isArray(steps) ? steps : null
    } catch (_error) {
      return null
    }
  },

  // ---------------------------------------------------------------------------
  // Sequence highlight: dim all, highlight path nodes + edges with numbers
  // ---------------------------------------------------------------------------
  _applySequenceHighlight(stepCodes) {
    if (!this._cy) return
    const cy = this._cy

    // Clear previous highlight styling without moving the camera. The camera
    // should animate only once, directly to the newly selected sequence.
    this._clearSequenceHighlight({ refit: false })

    // 1. Group positions by step code (handles repeated nodes)
    const positionsByCode = {}
    stepCodes.forEach((code, idx) => {
      positionsByCode[code] = positionsByCode[code] || []
      positionsByCode[code].push(idx + 1)
    })

    cy.batch(() => {
      // 2. Fade everything
      cy.elements().style({ opacity: 0.12 })

      // 3. Highlight nodes (once per unique code, with all positions)
      Object.entries(positionsByCode).forEach(([code, positions]) => {
        const node = cy.getElementById(code)
        if (node.length === 0) return

        // Save original label (only once)
        if (node.data("_origLabel") === undefined) {
          node.data("_origLabel", node.data("label"))
        }
        const originalLabel = node.data("_origLabel")
        const prefix = positions.map(circledNumber).join(" ")
        node.data("label", `${prefix}\n${originalLabel}`)

        node.style({
          opacity: 1,
          "border-color": "#e67e22",
          "border-width": 5,
          "background-color": "#fff8f0",
        })
      })

      // 4. Highlight edges between consecutive pairs
      for (let i = 0; i < stepCodes.length - 1; i++) {
        const src = stepCodes[i]
        const tgt = stepCodes[i + 1]
        const edge = cy.edges(`[source = "${src}"][target = "${tgt}"]`)
        if (edge.length > 0) {
          edge.style({
            opacity: 1,
            "line-color": "#e67e22",
            width: 4,
          })
        }
      }
    })

    // 5. Set active flag + codes (used by guards in hover/spotlight handlers)
    this._seqHighlightActive = true
    window._seqHighlightActive = true
    this._seqHighlightCodes = stepCodes

    // 6. Show exit button
    this._showSeqExitButton()

    // 7. Fit camera to highlighted nodes
    const nodes = cy.nodes().filter(n => positionsByCode[n.id()])
    if (nodes.length > 0) {
      cy.animate({ fit: { eles: nodes, padding: 80 }, duration: 400 })
    }
  },

  _applyManualStepGuide(node) {
    const cy = this._cy
    if (!cy || !node || node.length === 0) return

    this._clearManualStepGuide({ applyLiked: false })

    const outgoingEdges = node.outgoers("edge")
    const outgoingTargets = outgoingEdges.targets()
    const outgoingCount = outgoingTargets.length

    cy.batch(() => {
      cy.elements().style({ opacity: 0.16 })

      node.style({
        opacity: 1,
        "border-color": "#e67e22",
        "border-width": 5,
        "border-style": "solid",
        "background-color": "#fff8f0"
      })

      outgoingEdges.forEach(edge => {
        edge.style({
          opacity: 1,
          "line-color": "#2f8f5b",
          "line-opacity": 1,
          "target-arrow-color": "#2f8f5b",
          width: 3.5
        })
      })

      outgoingTargets.forEach(target => {
        target.style({
          opacity: 1,
          "border-color": "#2f8f5b",
          "border-width": 4,
          "border-style": "solid",
          "background-color": "#f3fbf5"
        })
      })
    })

    this._manualGuideActive = true
    this._manualGuideSourceId = node.id()

    if (outgoingCount > 0) {
      this._showToast(`${node.id()} selecionado · ${outgoingCount} saída(s) possível(is)`)
    } else {
      this._showToast(`${node.id()} selecionado · sem saídas cadastradas`)
    }
  },

  _clearManualStepGuide(options = {}) {
    const { applyLiked = true } = options
    const cy = this._cy
    if (!cy) return

    cy.batch(() => {
      cy.nodes().forEach(node => {
        const suggestedByCurrentUser =
          node.data("suggestedById") && node.data("suggestedById") === this._currentUserId

        node.style({
          opacity: 1,
          "border-color": node.data("cor") || "#9a7a5a",
          "border-width": node.data("highlighted") ? 5 : (node.degree() >= 10 ? 3 : 2),
          "border-style": node.data("suggested") ? "dashed" : "solid",
          "background-color": suggestedByCurrentUser ? "#fce4ec" : "#fffef9"
        })
      })

      cy.edges().forEach(edge => {
        const color = edge.data("cor") || "#9a7a5a"

        edge.style({
          opacity: 0.45,
          "line-color": color,
          "line-opacity": 0.45,
          "target-arrow-color": color,
          width: 1.5
        })
      })
    })

    this._manualGuideActive = false
    this._manualGuideSourceId = null

    if (applyLiked) applyLikedStepStyling()
  },

  _showSeqExitButton() {
    this._removeSeqExitButton()
    if (this._manualMode || this.el.dataset.manualMode === "true") return

    const container = this.el.parentElement
    const btn = document.createElement("button")
    const isMobile = window.matchMedia("(max-width: 767px)").matches

    btn.id = "seq-exit-btn"
    btn.textContent = isMobile ? "Sair da sequência" : "✕ Sair da sequência"
    btn.style.cssText = isMobile
      ? "position:absolute;top:58px;right:12px;z-index:25;min-height:38px;padding:7px 13px;background:#c0392b;color:white;border:none;border-radius:8px;font-family:Georgia,serif;font-size:11px;font-weight:700;cursor:pointer;box-shadow:0 2px 8px rgba(0,0,0,0.12);letter-spacing:0.2px;transition:opacity 0.2s;"
      : "position:absolute;top:60px;right:12px;z-index:25;padding:8px 16px;background:#c0392b;color:white;border:none;border-radius:20px;font-family:Georgia,serif;font-size:12px;font-weight:700;cursor:pointer;box-shadow:0 2px 8px rgba(0,0,0,0.15);letter-spacing:0.5px;transition:opacity 0.2s;"
    btn.addEventListener("click", () => {
      this._clearSequenceHighlight()
      this.pushEvent("clear_highlight", {})
    })
    container.appendChild(btn)
  },

  _removeSeqExitButton() {
    const existing = document.getElementById("seq-exit-btn")
    if (existing) existing.remove()
  },

  _clearSequenceHighlight(options = {}) {
    const { refit = true } = options
    const cy = this._cy
    if (!cy || !this._seqHighlightActive) return

    cy.batch(() => {
      // Restore node labels and styles
      cy.nodes().forEach(node => {
        const orig = node.data("_origLabel")
        if (orig) {
          node.data("label", orig)
          node.removeData("_origLabel")
        }
        node.style({
          opacity: 1,
          "border-color": node.data("cor"),
          "border-width": node.degree() >= 10 ? 3 : 2,
          "background-color": "#fffef9"
        })
      })

      cy.edges().forEach(edge => {
        const color = edge.data("cor") || "#9a7a5a"
        edge.style({
          opacity: 0.45,
          "line-color": color,
          "target-arrow-color": color,
          width: 1.5
        })
      })
    })

    this._seqHighlightActive = false
    window._seqHighlightActive = false
    this._seqHighlightCodes = null
    this._removeSeqExitButton()

    // Re-apply liked step borders now that sequence highlight is gone
    applyLikedStepStyling()

    if (refit) {
      cy.animate({ fit: { padding: 60 }, duration: 400 })
    }
  },

  _focusGraphNode(code) {
    const cy = this._cy
    if (!cy || !code) return

    if (this._seqHighlightActive) {
      this._clearSequenceHighlight()
      this.pushEvent("clear_highlight", {})
    }

    const node = cy.getElementById(code)
    if (node.length === 0) {
      this._showToast("Passo não está visível no mapa")
      return
    }

    clearSpotlight(cy)
    cy.nodes().unselect()
    node.select()
    applySpotlight(cy, node)
    openDrawer(node, cy, this._isEditMode && this._isAdmin, this)

    const neighborhood = node.closedNeighborhood()
    cy.animate({ fit: { eles: neighborhood, padding: 120 }, duration: 350 })
  },

  _clearGraphFocus() {
    const cy = this._cy
    if (!cy) return

    cy.nodes().unselect()
    closeDrawer()
    clearSpotlight(cy)
  }
}

// ---------------------------------------------------------------------------
// Hook: CityAutocomplete — state select + city input with IBGE data
// ---------------------------------------------------------------------------
const CityAutocomplete = {
  mounted() {
    this._citiesData = null
    this._selectedIndex = -1
    this._currentCities = []
    this._isBrazil = true
    this._loadCities()

    const countrySelect = this.el
    const stateSelect = document.getElementById("state-select")
    const stateWrapper = document.getElementById("state-wrapper")
    const cityInput = document.getElementById("city-input")
    const suggestions = document.getElementById("city-suggestions")
    const form = countrySelect.closest("form")
    if (!cityInput || !suggestions || !stateSelect) return

    const updateCountry = () => {
      this._isBrazil = countrySelect.value === "BR"
      cityInput.value = ""
      suggestions.style.display = "none"
      this._currentCities = []

      if (this._isBrazil) {
        stateWrapper.style.display = "block"
        stateSelect.required = true
        cityInput.placeholder = stateSelect.value ? "Digite o nome da cidade..." : "Selecione o estado primeiro"
      } else {
        stateWrapper.style.display = "none"
        stateSelect.value = ""
        stateSelect.required = false
        cityInput.placeholder = "Digite o nome da sua cidade"
      }
    }

    countrySelect.addEventListener("change", updateCountry)
    updateCountry()

    stateSelect.addEventListener("change", () => {
      cityInput.value = ""
      cityInput.placeholder = stateSelect.value ? "Digite o nome da cidade..." : "Selecione o estado primeiro"
      suggestions.style.display = "none"
      this._currentCities = []
    })

    const showSuggestions = () => {
      if (!this._isBrazil) {
        suggestions.style.display = "none"
        this._currentCities = []
        return
      }

      const state = stateSelect.value
      const term = cityInput.value.toLowerCase()
      if (!state || !this._citiesData || term.length < 1) {
        suggestions.style.display = "none"
        this._currentCities = []
        return
      }

      this._currentCities = (this._citiesData[state] || [])
        .filter(c => c.toLowerCase().includes(term))
        .slice(0, 10)

      if (this._currentCities.length === 0) {
        suggestions.style.display = "none"
        return
      }

      this._selectedIndex = -1
      renderSuggestions()
    }

    const renderSuggestions = () => {
      suggestions.style.display = "block"
      suggestions.textContent = ""
      this._currentCities.forEach((city, idx) => {
        const div = document.createElement("div")
        div.textContent = city
        const isActive = idx === this._selectedIndex
        div.style.cssText = `padding: 10px 16px; cursor: pointer; font-family: Georgia, serif; font-size: 14px; color: #1a0e05; border-bottom: 1px solid rgba(180,120,40,0.1); background: ${isActive ? "rgba(180,120,40,0.1)" : "transparent"};`
        div.addEventListener("mousedown", (e) => {
          e.preventDefault()
          selectCity(city)
        })
        div.addEventListener("mouseover", () => { div.style.background = "rgba(180,120,40,0.06)" })
        div.addEventListener("mouseout", () => { div.style.background = isActive ? "rgba(180,120,40,0.1)" : "transparent" })
        suggestions.appendChild(div)
      })
    }

    const selectCity = (city) => {
      cityInput.value = city
      suggestions.style.display = "none"
      this._currentCities = []
      this._selectedIndex = -1
    }

    cityInput.addEventListener("input", showSuggestions)

    // Keyboard navigation: arrows + enter selects, doesn't submit form
    cityInput.addEventListener("keydown", (e) => {
      if (this._currentCities.length === 0) return

      if (e.key === "ArrowDown") {
        e.preventDefault()
        this._selectedIndex = Math.min(this._selectedIndex + 1, this._currentCities.length - 1)
        renderSuggestions()
      } else if (e.key === "ArrowUp") {
        e.preventDefault()
        this._selectedIndex = Math.max(this._selectedIndex - 1, 0)
        renderSuggestions()
      } else if (e.key === "Enter") {
        e.preventDefault()
        if (this._selectedIndex >= 0) {
          selectCity(this._currentCities[this._selectedIndex])
        } else if (this._currentCities.length === 1) {
          selectCity(this._currentCities[0])
        } else if (this._currentCities.length > 0) {
          // Select first match
          selectCity(this._currentCities[0])
        }
      } else if (e.key === "Escape") {
        suggestions.style.display = "none"
        this._currentCities = []
      }
    })

    cityInput.addEventListener("blur", () => {
      setTimeout(() => { suggestions.style.display = "none" }, 200)
    })

    // Form validation: prevent submit if city is invalid
    if (form) {
      form.addEventListener("submit", (e) => {
        const city = cityInput.value.trim()

        if (!city) {
          e.preventDefault()
          cityInput.style.borderColor = "#c0392b"
          cityInput.placeholder = "Informe sua cidade"
          return
        }

        // Only validate against IBGE list for Brazil
        if (this._isBrazil) {
          const state = stateSelect.value
          if (!state) {
            e.preventDefault()
            stateSelect.style.borderColor = "#c0392b"
            return
          }

          const validCities = (this._citiesData || {})[state] || []
          if (!validCities.includes(city)) {
            e.preventDefault()
            cityInput.style.borderColor = "#c0392b"
            cityInput.value = ""
            cityInput.placeholder = "Selecione uma cidade válida da lista"
            cityInput.focus()
            showSuggestions()
          }
        }
      })
    }
  },

  async _loadCities() {
    try {
      const resp = await fetch("/data/ibge_cities.json")
      this._citiesData = await resp.json()
    } catch (e) {
      console.warn("Could not load IBGE cities:", e)
    }
  }
}

// ---------------------------------------------------------------------------
// Hook: BackButton — history.back() with fallback URL
// ---------------------------------------------------------------------------
const BackButton = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      e.preventDefault();
      if (window.history.length > 1) {
        window.history.back();
      } else {
        const fallback = this.el.dataset.fallback || "/collection";
        window.location.href = fallback;
      }
    });
  }
};

// ---------------------------------------------------------------------------
// Hook: BottomSheet — native <dialog> with swipe-to-close gesture
// ---------------------------------------------------------------------------
const BottomSheet = {
  mounted() {
    const dialog = this.el;

    this._onOpen = () => {
      if (!dialog.open) dialog.showModal();
    };
    this._onClose = () => {
      if (dialog.open) dialog.close();
    };
    dialog.addEventListener("bottom-sheet:open", this._onOpen);
    dialog.addEventListener("bottom-sheet:close", this._onClose);

    this._onBackdropClick = (e) => {
      const content = dialog.querySelector("[data-bottom-sheet-content]");
      if (content && !content.contains(e.target)) {
        dialog.close();
      }
    };
    dialog.addEventListener("click", this._onBackdropClick);

    const content = dialog.querySelector("[data-bottom-sheet-content]");
    const handle = dialog.querySelector("[data-bottom-sheet-handle]");

    if (handle && content) {
      let startY = null;
      let delta = 0;

      this._onTouchStart = (e) => {
        if (e.touches.length !== 1) return;
        startY = e.touches[0].clientY;
        delta = 0;
        content.style.transition = "none";
      };

      this._onTouchMove = (e) => {
        if (startY === null) return;
        delta = e.touches[0].clientY - startY;
        if (delta > 0) {
          content.style.transform = `translateY(${delta}px)`;
        }
      };

      this._onTouchEnd = () => {
        if (startY === null) return;
        content.style.transition = "transform 200ms var(--ease-out-quart, ease-out)";

        if (delta > 80) {
          content.style.transform = "translateY(100%)";
          setTimeout(() => {
            dialog.close();
            content.style.transform = "";
          }, 200);
        } else {
          content.style.transform = "";
        }

        startY = null;
        delta = 0;
      };

      handle.addEventListener("touchstart", this._onTouchStart, { passive: true });
      handle.addEventListener("touchmove", this._onTouchMove, { passive: true });
      handle.addEventListener("touchend", this._onTouchEnd);
    }
  },

  destroyed() {
    const dialog = this.el;
    dialog.removeEventListener("bottom-sheet:open", this._onOpen);
    dialog.removeEventListener("bottom-sheet:close", this._onClose);
    dialog.removeEventListener("click", this._onBackdropClick);
  },
};

// Register PWA service worker (Phase 0b)
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/sw.js").catch((err) => {
      console.warn("Service worker registration failed:", err);
    });
  });
}

// ---------------------------------------------------------------------------
// FormPersist hook — saves form fields to sessionStorage, restores on mount
// Protects against data loss on LiveView reconnect, deploy, or page refresh.
// Usage: add phx-hook="FormPersist" id="unique-form-id" to any <form>
// ---------------------------------------------------------------------------
const FormPersist = {
  mounted() {
    this._key = `form_persist:${this.el.id}`
    // Delay restore to next frame — ensures DOM inputs are fully rendered
    requestAnimationFrame(() => this._restoreFields())
    this._startAutoSave()
  },

  updated() {
    // LiveView re-rendered the form (e.g. user clicked a step, drawer opened).
    // DOM inputs may be replaced with empty values — restore + re-bind listeners.
    this._stopAutoSave()
    this._startAutoSave()
    requestAnimationFrame(() => this._restoreFields())
  },

  reconnected() {
    // LiveView reconnected after deploy — restore form data
    requestAnimationFrame(() => this._restoreFields())
  },

  destroyed() {
    this._stopAutoSave()
    // Do NOT clear sessionStorage — destroyed fires on conditional hide,
    // LiveView reconnect, and deploy. Data cleared explicitly after submit.
  },

  _restoreFields() {
    const saved = sessionStorage.getItem(this._key)
    if (!saved) return

    try {
      const data = JSON.parse(saved)
      let hasData = false

      Object.entries(data).forEach(([name, value]) => {
        if (!value && value !== false) return

        // Find input by name — try CSS-escaped brackets first, then plain
        let input = null
        try {
          input = this.el.querySelector(`[name="${CSS.escape(name)}"]`)
        } catch (_) {}
        if (!input) {
          try { input = this.el.querySelector(`[name="${name}"]`) } catch (_) {}
        }

        if (input && input.type !== "hidden" && input.type !== "password"
            && input.name !== "_csrf_token") {
          if (input.type === "checkbox") {
            if (input.checked !== !!value) {
              input.checked = !!value
              hasData = true
            }
          } else if (input.value !== value) {
            input.value = value
            hasData = true
          }
        }
      })

      // Mark inputs so LiveView doesn't overwrite them on next patch
      // We do NOT dispatch input/change events — that would trigger
      // server-side validation which could reset the form.
      // The values are in the DOM; they'll be sent on submit.
    } catch (_) {
      sessionStorage.removeItem(this._key)
    }
  },

  _startAutoSave() {
    this._saveHandler = () => this._saveFields()
    this.el.addEventListener("input", this._saveHandler)
    this.el.addEventListener("change", this._saveHandler)
  },

  _stopAutoSave() {
    if (this._saveHandler) {
      this.el.removeEventListener("input", this._saveHandler)
      this.el.removeEventListener("change", this._saveHandler)
    }
  },

  _saveFields() {
    const data = {}
    const inputs = this.el.querySelectorAll("input, textarea, select")
    inputs.forEach(input => {
      if (input.name && input.type !== "hidden" && input.type !== "password"
          && input.name !== "_csrf_token" && input.type !== "file") {
        if (input.type === "checkbox") {
          data[input.name] = input.checked
        } else if (input.type === "radio") {
          if (input.checked) data[input.name] = input.value
        } else if (input.value) {
          data[input.name] = input.value
        }
      }
    })
    sessionStorage.setItem(this._key, JSON.stringify(data))
  }
}

// Clear form persistence after successful submit
window.addEventListener("phx:form_persisted_clear", (e) => {
  const key = `form_persist:${e.detail.id}`
  sessionStorage.removeItem(key)
})

// ---------------------------------------------------------------------------
// PWA: Capture beforeinstallprompt GLOBALLY (must run before any hook)
// ---------------------------------------------------------------------------
window._deferredPWAPrompt = null
window.addEventListener('beforeinstallprompt', (e) => {
  e.preventDefault()
  window._deferredPWAPrompt = e
})

// ---------------------------------------------------------------------------
// Hook: PWAInstall — elegant install banner
// ---------------------------------------------------------------------------
const PWAInstall = {
  mounted() {
    const isStandalone = window.matchMedia('(display-mode: standalone)').matches
      || window.navigator.standalone === true

    // Hide completely in PWA mode
    if (isStandalone) {
      this.el.remove()
      return
    }

    // Show at most once per week (localStorage persists across sessions)
    const lastDismissed = localStorage.getItem('pwa_banner_dismissed_at')
    if (lastDismissed) {
      const weekMs = 7 * 24 * 60 * 60 * 1000
      if (Date.now() - parseInt(lastDismissed) < weekMs) return
    }

    const banner = this.el
    const installBtn = document.getElementById('pwa-install-btn')
    const dismissBtn = document.getElementById('pwa-dismiss-btn')

    // Show after 3s delay
    setTimeout(() => banner.classList.remove('hidden'), 3000)

    if (installBtn) {
      installBtn.addEventListener('click', async () => {
        if (window._deferredPWAPrompt) {
          // Chrome/Android: native install prompt
          window._deferredPWAPrompt.prompt()
          const { outcome } = await window._deferredPWAPrompt.userChoice
          if (outcome === 'accepted') {
            banner.classList.add('hidden')
            localStorage.setItem('pwa_banner_dismissed_at', Date.now().toString())
          }
          window._deferredPWAPrompt = null
        } else {
          // iOS/other: show a helpful modal instead of ugly alert
          showInstallInstructions()
        }
      })
    }

    if (dismissBtn) {
      dismissBtn.addEventListener('click', () => {
        banner.classList.add('hidden')
        localStorage.setItem('pwa_banner_dismissed_at', Date.now().toString())
      })
    }
  }
}

function showInstallInstructions() {
  // Remove existing modal if any
  document.getElementById('pwa-instructions-modal')?.remove()

  const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent)
  const steps = isIOS
    ? `<li>Toque em <strong>Compartilhar</strong> <span style="font-size:18px;">⬆</span></li>
       <li>Role até <strong>"Adicionar à Tela de Início"</strong></li>
       <li>Toque em <strong>Adicionar</strong></li>`
    : `<li>Toque no menu <strong>⋮</strong> do navegador</li>
       <li>Selecione <strong>"Instalar aplicativo"</strong></li>
       <li>Confirme a instalação</li>`

  const modal = document.createElement('div')
  modal.id = 'pwa-instructions-modal'
  modal.style.cssText = 'position:fixed;inset:0;z-index:9999;display:flex;align-items:center;justify-content:center;background:rgba(26,14,5,0.85);padding:20px;'
  modal.innerHTML = `
    <div style="background:#f7f3ec;border-radius:16px;padding:28px 24px;max-width:320px;width:100%;text-align:center;font-family:Georgia,serif;">
      <img src="/icons/icon-192.png" alt="OGE" style="width:56px;height:56px;border-radius:12px;margin:0 auto 16px;display:block;box-shadow:0 4px 12px rgba(0,0,0,0.15);" />
      <h3 style="font-size:18px;color:#1a0e05;margin:0 0 8px;font-weight:700;">Instale o Grupo de Estudos</h3>
      <p style="font-size:13px;color:#7a5c3a;margin:0 0 16px;line-height:1.5;">Acesse como um app direto da tela inicial</p>
      <ol style="text-align:left;font-size:13px;color:#3a2510;line-height:1.8;padding-left:20px;margin:0 0 20px;">${steps}</ol>
      <button onclick="this.closest('#pwa-instructions-modal').remove()" style="background:#b47828;color:white;border:none;padding:10px 28px;border-radius:20px;font-family:Georgia,serif;font-size:14px;font-weight:700;cursor:pointer;letter-spacing:0.5px;">Entendi</button>
    </div>`
  document.body.appendChild(modal)
  modal.addEventListener('click', (e) => {
    if (e.target === modal) modal.remove()
  })
}

// Hook: PWAInstallSettings — permanent install button in Settings page
const PWAInstallSettings = {
  mounted() {
    const isStandalone = window.matchMedia('(display-mode: standalone)').matches
      || window.navigator.standalone === true

    if (isStandalone) {
      // Already in PWA — change button to show status
      this.el.textContent = 'Instalado ✓'
      this.el.classList.remove('bg-gold-500', 'hover:bg-gold-600', 'cursor-pointer')
      this.el.classList.add('bg-accent-green/20', 'text-accent-green', 'cursor-default')
      this.el.disabled = true
      return
    }

    this.el.addEventListener('click', async () => {
      if (window._deferredPWAPrompt) {
        window._deferredPWAPrompt.prompt()
        const { outcome } = await window._deferredPWAPrompt.userChoice
        if (outcome === 'accepted') {
          this.el.textContent = 'Instalado ✓'
          this.el.disabled = true
        }
        window._deferredPWAPrompt = null
      } else {
        showInstallInstructions()
      }
    })
  }
}

// Hook: OnboardingTour — guided spotlight tour for first-time users
// All text content is hardcoded (no user input), so innerHTML usage here is safe.
const OnboardingTour = {
  mounted() {
    if (localStorage.getItem('tour_completed')) return
    this._timer = setTimeout(() => this.startTour(), 800)
  },
  destroyed() {
    if (this._timer) clearTimeout(this._timer)
    this.cleanup()
  },
  startTour() {
    const isMobile = window.innerWidth < 768
    this.steps = [
      {
        selector: isMobile
          ? '[data-ui="bottom-nav"] li:nth-child(1)'
          : '#top-nav-desktop-primary-nav a:nth-child(1)',
        title: 'Aqui fica todo o acervo.',
        text: 'Uma wiki de forró roots que a gente constrói junto. Tem muita coisa aberta ainda, então se achar algo pra melhorar, manda ver!',
      },
      {
        selector: isMobile
          ? '[data-ui="bottom-nav"] li:nth-child(2)'
          : '#top-nav-desktop-primary-nav a:nth-child(2)',
        title: 'O mapa mostra como os passos se conectam.',
        text: 'Ele tá em construção, então pode ter conexão faltando ou errada. Você pode sugerir novas ou pedir remoção das incorretas.',
      },
      {
        selector: isMobile
          ? '[data-ui="bottom-nav"] li:nth-child(3)'
          : '#top-nav-desktop-primary-nav a:nth-child(3)',
        title: 'Seu cantinho de treino.',
        text: 'Anota o que praticou, vincula os passos e vai acompanhando sua evolução.',
      },
      {
        selector: isMobile
          ? '[data-ui="bottom-nav"] li:nth-child(5)'
          : '#top-nav-desktop-primary-nav a:nth-child(4)',
        title: 'Aqui a galera se encontra.',
        text: 'Segue outros dançarinos, vê o que tão criando e compartilha suas sequências.',
      },
      {
        selector: '#collection-shell',
        title: 'Tudo aqui pode ser editado por você.',
        text: 'Toca no lápis pra sugerir melhorias nos textos, links ou conexões. Eu reviso e aprovo o mais rápido que der.',
      },
      {
        selector: null,
        title: 'Esse projeto é de todo mundo.',
        text: 'Quanto mais gente contribui, melhor fica. Bom treino! 🎶',
      },
    ]
    this.currentStep = 0
    this.render()
  },
  render() {
    this.cleanup()
    if (this.currentStep >= this.steps.length) { this.finish(); return }
    const step = this.steps[this.currentStep]
    const total = this.steps.length
    const target = step.selector ? document.querySelector(step.selector) : null
    const isLast = this.currentStep === total - 1

    // Overlay with spotlight cutout
    const overlay = document.createElement('div')
    overlay.id = 'tour-overlay'
    overlay.style.cssText = 'position:fixed;inset:0;z-index:9998;'

    if (target) {
      const r = target.getBoundingClientRect()
      const p = 6, rd = 8, vw = window.innerWidth, vh = window.innerHeight
      const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg')
      svg.setAttribute('width', vw)
      svg.setAttribute('height', vh)
      svg.style.cssText = 'position:fixed;inset:0;'

      const mask = document.createElementNS('http://www.w3.org/2000/svg', 'mask')
      mask.id = 'tour-mask'
      const bg = document.createElementNS('http://www.w3.org/2000/svg', 'rect')
      bg.setAttribute('width', '100%'); bg.setAttribute('height', '100%'); bg.setAttribute('fill', 'white')
      const cut = document.createElementNS('http://www.w3.org/2000/svg', 'rect')
      cut.setAttribute('x', r.left - p); cut.setAttribute('y', r.top - p)
      cut.setAttribute('width', r.width + p*2); cut.setAttribute('height', r.height + p*2)
      cut.setAttribute('rx', rd); cut.setAttribute('fill', 'black')
      mask.append(bg, cut)

      const fill = document.createElementNS('http://www.w3.org/2000/svg', 'rect')
      fill.setAttribute('width', '100%'); fill.setAttribute('height', '100%')
      fill.setAttribute('fill', 'rgba(0,0,0,0.6)'); fill.setAttribute('mask', 'url(#tour-mask)')

      const defs = document.createElementNS('http://www.w3.org/2000/svg', 'defs')
      defs.appendChild(mask)
      svg.append(defs, fill)
      overlay.appendChild(svg)
    } else {
      const dim = document.createElement('div')
      dim.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,0.6);'
      overlay.appendChild(dim)
    }
    document.body.appendChild(overlay)

    // Tooltip (safe: all content is hardcoded strings, no user input)
    const tt = document.createElement('div')
    tt.id = 'tour-tooltip'
    Object.assign(tt.style, {
      position:'fixed', zIndex:'9999',
      background:'#faf8f4', border:'1px solid rgba(0,0,0,0.1)',
      borderRadius:'12px', padding:'20px 22px 16px',
      boxShadow:'0 20px 50px rgba(30,22,16,0.25)',
      maxWidth:'320px', width:'calc(100vw - 2rem)',
      fontFamily:"'Source Serif 4',Georgia,serif",
      animation:'slide-in-right 0.25s ease-out',
    })

    const counter = document.createElement('div')
    Object.assign(counter.style, {fontSize:'10px',color:'#9a8a78',fontWeight:'600',textTransform:'uppercase',letterSpacing:'0.15em',marginBottom:'8px'})
    counter.textContent = `${this.currentStep + 1} de ${total}`

    const title = document.createElement('div')
    Object.assign(title.style, {fontSize:'15px',fontWeight:'700',color:'#1a0e05',marginBottom:'6px',lineHeight:'1.3'})
    title.textContent = step.title

    const text = document.createElement('div')
    Object.assign(text.style, {fontSize:'13px',color:'#5c4a3a',lineHeight:'1.6',marginBottom:'16px'})
    text.textContent = step.text

    const btns = document.createElement('div')
    Object.assign(btns.style, {display:'flex',gap:'8px',justifyContent:'flex-end'})

    if (!isLast) {
      const skip = document.createElement('button')
      Object.assign(skip.style, {background:'transparent',border:'1px solid rgba(0,0,0,0.1)',borderRadius:'8px',padding:'8px 16px',fontSize:'12px',color:'#9a8a78',cursor:'pointer',fontFamily:'inherit'})
      skip.textContent = 'Pular'
      skip.addEventListener('click', () => this.finish())
      btns.appendChild(skip)
    }

    const next = document.createElement('button')
    Object.assign(next.style, {background:'#1a0e05',color:'#faf8f4',border:'none',borderRadius:'8px',padding:'8px 20px',fontSize:'12px',fontWeight:'600',cursor:'pointer',fontFamily:'inherit'})
    next.textContent = isLast ? 'Começar!' : 'Próximo'
    next.addEventListener('click', () => { this.currentStep++; this.render() })
    btns.appendChild(next)

    tt.append(counter, title, text, btns)
    document.body.appendChild(tt)

    // Position tooltip
    if (target) {
      const r = target.getBoundingClientRect()
      const ttRect = tt.getBoundingClientRect()
      if (window.innerWidth < 768 && r.top > window.innerHeight / 2) {
        tt.style.bottom = (window.innerHeight - r.top + 16) + 'px'
        tt.style.left = Math.max(16, Math.min(r.left, window.innerWidth - ttRect.width - 16)) + 'px'
      } else {
        tt.style.top = (r.bottom + 16) + 'px'
        tt.style.left = Math.max(16, Math.min(r.left, window.innerWidth - ttRect.width - 16)) + 'px'
      }
    } else {
      tt.style.top = '50%'; tt.style.left = '50%'; tt.style.transform = 'translate(-50%, -50%)'
    }

    overlay.addEventListener('click', (e) => {
      if (e.target.closest('#tour-tooltip')) return
      this.currentStep++; this.render()
    })
  },
  cleanup() {
    const o = document.getElementById('tour-overlay')
    const t = document.getElementById('tour-tooltip')
    if (o) o.remove()
    if (t) t.remove()
  },
  finish() {
    this.cleanup()
    localStorage.setItem('tour_completed', '1')
    localStorage.setItem('onboarding_seen', '1')
  }
}

// Hook: AutoDismiss — auto-hides flash messages after a configurable delay
const AutoDismiss = {
  mounted() {
    const delay = parseInt(this.el.dataset.dismissAfter || "6000", 10)
    this._timer = setTimeout(() => {
      this.el.style.transition = "opacity 0.4s ease, transform 0.4s ease"
      this.el.style.opacity = "0"
      this.el.style.transform = "translateX(100%)"
      setTimeout(() => this.el.remove(), 400)
    }, delay)
  },
  destroyed() {
    if (this._timer) clearTimeout(this._timer)
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, GraphVisual, ThreeCanvas, CityAutocomplete, BackButton, BottomSheet, FormPersist, PWAInstall, PWAInstallSettings, OnboardingTour, AutoDismiss},
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
