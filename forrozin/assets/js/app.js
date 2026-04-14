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

// ---------------------------------------------------------------------------
// Compute sector positions: each category = one sector of a circle.
// ---------------------------------------------------------------------------
function computeSectorPositions(cy) {
  const byCat = {}
  cy.nodes("[^category_zone]").forEach(n => {
    const cat = n.data("categoriaName") || "outros"
    ;(byCat[cat] = byCat[cat] || []).push(n)
  })

  const activeCats = CATEGORY_ORDER.filter(c => byCat[c]?.length > 0)
  Object.keys(byCat).forEach(c => {
    if (!activeCats.includes(c)) activeCats.push(c)
  })

  const numCats = activeCats.length
  const positions = {}
  const R_BASE = 460
  const NODE_GAP = 165
  const ROW_GAP = 155

  activeCats.forEach((cat, i) => {
    const group = byCat[cat]
    const n = group.length
    const theta = (2 * Math.PI * i / numCats) - Math.PI / 2
    const rHat = { x: Math.cos(theta), y: Math.sin(theta) }
    const tHat = { x: -Math.sin(theta), y: Math.cos(theta) }
    const perRow = Math.min(4, Math.ceil(Math.sqrt(n)))
    const rows = Math.ceil(n / perRow)
    const cx = R_BASE * rHat.x
    const cy_ = R_BASE * rHat.y

    group.forEach((node, j) => {
      const row = Math.floor(j / perRow)
      const col = j % perRow
      const colsInRow = (row === rows - 1) ? (n - row * perRow) : perRow
      const colOffset = (col - (colsInRow - 1) / 2) * NODE_GAP
      const rowOffset = (row - (rows - 1) / 2) * ROW_GAP

      positions[node.id()] = {
        x: cx + tHat.x * colOffset + rHat.x * rowOffset,
        y: cy_ + tHat.y * colOffset + rHat.y * rowOffset
      }
    })
  })

  return positions
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

function buildDrawerHTML(d, outEdges, inEdges, degree) {
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
      parts.push(`<div class="drawer-link" data-node-id="${escapeHTML(t.id())}" style="padding: 6px 0; border-bottom: 1px solid rgba(60,40,20,0.06); font-size: 12px; color: #2c1a0e; cursor: pointer;">`)
      parts.push(`<code style="font-size: 10px; color: ${escapeHTML(t.data("cor"))}; margin-right: 6px;">${escapeHTML(t.id())}</code>${escapeHTML(t.data("label"))}${lb}</div>`)
    })
  }

  if (inEdges.length > 0) {
    parts.push(`<div style="font-size: 10px; font-weight: 700; color: #9a7a5a; text-transform: uppercase; letter-spacing: 2px; margin: 16px 0 8px;">← Entradas</div>`)
    inEdges.forEach(e => {
      const s = e.source()
      const lb = e.data("label") ? ` <span style="color: #9a7a5a; font-style: italic;">(${escapeHTML(e.data("label"))})</span>` : ""
      parts.push(`<div class="drawer-link" data-node-id="${escapeHTML(s.id())}" style="padding: 6px 0; border-bottom: 1px solid rgba(60,40,20,0.06); font-size: 12px; color: #2c1a0e; cursor: pointer;">`)
      parts.push(`<code style="font-size: 10px; color: ${escapeHTML(s.data("cor"))}; margin-right: 6px;">${escapeHTML(s.id())}</code>${escapeHTML(s.data("label"))}${lb}</div>`)
    })
  }

  parts.push(`<a href="/steps/${encodeURIComponent(d.id)}" style="display: block; margin-top: 20px; padding: 10px 16px; text-align: center; background: #1a0e05; color: #f2ede4; border-radius: 6px; text-decoration: none; font-size: 12px; letter-spacing: 1px;">Ver passo completo</a>`)

  return parts.join("")
}

function openDrawer(node, cy) {
  const el = document.getElementById("graph-drawer")
  const content = document.getElementById("drawer-content")
  if (!el || !content) return

  const d = node.data()
  content.innerHTML = buildDrawerHTML(d, node.outgoers("edge"), node.incomers("edge"), node.degree())
  el.style.right = "0px"

  content.querySelectorAll(".drawer-link").forEach(link => {
    link.addEventListener("click", () => {
      const targetNode = cy.getElementById(link.dataset.nodeId)
      if (targetNode.length > 0) {
        cy.animate({ center: { eles: targetNode }, duration: 300 })
        targetNode.select()
        openDrawer(targetNode, cy)
        applySpotlight(cy, targetNode)
      }
    })
  })
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
    cy.elements("[^category_zone]").style({ opacity: 0.08 })
    const nh = node.closedNeighborhood()
    nh.style({ opacity: 1 })
    nh.edges().style({ opacity: 0.85, width: 2.5 })
    node.style({ opacity: 1 })
  })
}

function clearSpotlight(cy) {
  cy.batch(() => {
    cy.nodes("[^category_zone]").style({ opacity: 1 })
    cy.edges().style({ opacity: 0.45, width: 1.5 })
  })
}

function applyCategorySpotlight(cy, categoryName) {
  cy.batch(() => {
    cy.elements("[^category_zone]").style({ opacity: 0.08 })
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
  mounted() { this._initGraph() },
  updated() { this._initGraph() },

  _initGraph() {
    const el = this.el
    const raw = el.dataset.graph
    if (!raw) return

    const { nodes, edges } = JSON.parse(raw)
    if (this._cy) { this._cy.destroy(); this._cy = null }

    // Build elements: category zone parents + step nodes + edges
    const categorySet = new Set(nodes.map(n => n.categoriaName))
    const elements = []

    categorySet.forEach(catName => {
      const sample = nodes.find(n => n.categoriaName === catName)
      elements.push({
        data: { id: `zone-${catName}`, cor: sample?.cor || "#9a7a5a", category_zone: true },
        classes: "category-zone"
      })
    })

    nodes.forEach(n => {
      elements.push({
        data: {
          id: n.id, label: n.nome, categoria: n.categoria,
          categoriaName: n.categoriaName, cor: n.cor || "#9a7a5a",
          nota: n.nota, parent: `zone-${n.categoriaName}`
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
          selector: "node.category-zone",
          style: {
            "background-color": "data(cor)", "background-opacity": 0.04,
            "border-width": 0, "shape": "roundrectangle", "padding": "45px",
            "label": "", "events": "no"
          }
        },
        {
          selector: "node[^category_zone]",
          style: {
            "shape": "roundrectangle",
            "width": "label",
            "height": "label",
            "padding": function(e) {
              const HUB_CODES = ["BF", "GS", "GP", "IV", "SC", "CM-F"]
              if (HUB_CODES.includes(e.id())) return "16px 24px"
              return e.degree() >= 10 ? "12px 18px" : "8px 14px"
            },
            "background-color": "#fffef9",
            "border-width": function(e) {
              const HUB_CODES = ["BF", "GS", "GP", "IV", "SC", "CM-F"]
              if (HUB_CODES.includes(e.id())) return 4
              return e.degree() >= 10 ? 3 : 2
            },
            "border-color": "data(cor)", "border-opacity": 0.85,
            "label": function(e) { return e.id() + "\n" + e.data("label") },
            "text-wrap": "wrap", "text-halign": "center", "text-valign": "center",
            "font-family": "Georgia, serif",
            "font-size": function(e) {
              const HUB_CODES = ["BF", "GS", "GP", "IV", "SC", "CM-F"]
              if (HUB_CODES.includes(e.id())) return 17
              const d = e.degree()
              return d >= 12 ? 15 : d >= 6 ? 14 : 13
            },
            "color": "#1a0e05", "text-max-width": "180px",
            "min-width": "80px",
            "shadow-blur": function(e) {
              const HUB_CODES = ["BF", "GS", "GP", "IV", "SC", "CM-F"]
              if (HUB_CODES.includes(e.id())) return 16
              return e.degree() >= 10 ? 10 : 4
            },
            "shadow-color": "rgba(60,40,20,0.12)",
            "shadow-offset-x": 0, "shadow-offset-y": 2, "shadow-opacity": 1
          }
        },
        {
          selector: "node[^category_zone]:selected",
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

    // Inherit source category color to edges
    cy.edges().forEach(edge => { edge.data("cor", edge.source().data("cor") || "#9a7a5a") })

    // ── Phase 1: preset sector positions ──
    const positions = computeSectorPositions(cy)
    cy.layout({ name: "preset", positions, animate: false }).run()

    // ── Phase 2: cola with degree-based spacing ──
    const colaOpts = {
      name: "cola", animate: true, animationDuration: 900, maxSimulationTime: 2500,
      randomize: false, fit: true, padding: 60, avoidOverlaps: true,
      nodeDimensionsIncludeLabels: true,
      nodeSpacing: function(node) {
        if (node.hasClass("category-zone")) return 0
        return 45 + (node.degree() * 6)
      },
      edgeLength: function(e) {
        const same = e.source().data("categoriaName") === e.target().data("categoriaName")
        return same ? 140 : 340
      },
      gravity: 0.12, convergenceThreshold: 0.05, infinite: false
    }
    cy.layout(colaOpts).run()
    cy.one("layoutstop", () => { cy.fit(undefined, 60) })

    // ── Phase 3: drag-release local cola ──
    cy.on("dragfreeon", "node[^category_zone]", () => {
      cy.layout(Object.assign({}, colaOpts, {
        animationDuration: 400, maxSimulationTime: 600,
        fit: false, convergenceThreshold: 0.1
      })).run()
    })

    // ── Interactions ──
    let activeCategory = null

    cy.on("tap", "node[^category_zone]", function(evt) {
      activeCategory = null
      applySpotlight(cy, evt.target)
      openDrawer(evt.target, cy)
    })

    cy.on("tap", function(evt) {
      if (evt.target === cy) {
        clearSpotlight(cy); closeDrawer(); activeCategory = null; resetLegend()
      }
    })

    cy.on("mouseover", "node[^category_zone]", function(evt) {
      if (document.getElementById("graph-drawer").style.right === "0px") return
      const node = evt.target
      cy.batch(() => {
        cy.elements("[^category_zone]").style({ opacity: 0.15 })
        const nh = node.closedNeighborhood()
        nh.style({ opacity: 1 }); nh.edges().style({ opacity: 0.7 })
      })
    })

    cy.on("mouseout", "node[^category_zone]", function() {
      if (document.getElementById("graph-drawer").style.right === "0px") return
      if (!activeCategory) clearSpotlight(cy)
    })

    document.getElementById("drawer-close")?.addEventListener("click", () => {
      closeDrawer(); clearSpotlight(cy)
    })

    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape") { closeDrawer(); clearSpotlight(cy); activeCategory = null; resetLegend() }
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

