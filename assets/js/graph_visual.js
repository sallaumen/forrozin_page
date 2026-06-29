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
// Theme helpers for Cytoscape (D1: CSS vars = single source of truth)
// ---------------------------------------------------------------------------
function cyTheme() {
  const s = getComputedStyle(document.documentElement)
  const get = v => s.getPropertyValue(v).trim()
  const dark = document.documentElement.classList.contains("dark")
  return {
    nodeFillNormal:      dark ? get("--color-ink-100") : "#fffef9",
    nodeFillSuggested:   get("--color-accent-pink-bg"),
    nodeFillHighlighted: dark ? "#322216" : "#fff8f0",
    nodeFillOutgoing:    dark ? "#0d2016" : "#f3fbf5",
    nodeLabel:           get("--color-ink-900"),
    nodeBorderOpacity:   dark ? 0.95 : 0.85,
    nodeSelectedOpacity: dark ? 0.22 : 0.15,
    likeBorderColor:     dark ? get("--color-accent-red") : "#c0392b",
    journeyLearned:      dark ? get("--color-accent-green") : "#2f8f5b",
    journeyFrontier:     dark ? get("--color-accent-orange") : "#c4621e",
    edgeOpacity:         dark ? 0.75 : 0.70,
    edgeHighlightColor:  dark ? get("--color-accent-orange") : "#c4621e",
    edgeLabelText:       dark ? get("--color-ink-800") : "#3a2510",
    edgeLabelBg:         dark ? get("--color-ink-100") : "#fffdf8",
  }
}

function buildCyStyle(currentUserId) {
  const t = cyTheme()
  return [
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
          const suggested = e.data("suggestedById") && e.data("suggestedById") === currentUserId
          return suggested ? t.nodeFillSuggested : (e.data("highlighted") ? t.nodeFillHighlighted : t.nodeFillNormal)
        },
        "border-width": function(e) {
          if (e.data("highlighted")) return 5
          return e.degree() >= 10 ? 3 : 2
        },
        "border-color": "data(cor)", "border-opacity": t.nodeBorderOpacity,
        "border-style": function(e) { return e.data("suggested") ? "dashed" : "solid" },
        "label": function(e) { return e.id() + "\n" + e.data("label") },
        "text-wrap": "wrap", "text-halign": "center", "text-valign": "center",
        "font-family": "Georgia, serif",
        "font-size": function(e) {
          if (e.data("highlighted")) return 19
          const d = e.degree()
          return d >= 12 ? 15 : d >= 6 ? 14 : 13
        },
        "color": t.nodeLabel, "text-max-width": "180px",
        "min-width": "80px"
      }
    },
    {
      selector: "node:selected",
      style: {
        "background-color": "data(cor)",
        "background-opacity": t.nodeSelectedOpacity,
        "border-width": 3, "border-opacity": 1.0
      }
    },
    {
      selector: "node.like-active",
      style: {
        "border-color": t.likeBorderColor,
        "border-width": 2.5
      }
    },
    {
      selector: "edge",
      style: {
        "width": 2.5,
        "line-color": "data(cor)",
        "line-opacity": function(e) {
          const dense = e.source().degree() >= 10 || e.target().degree() >= 10
          return dense ? t.edgeOpacity * 0.85 : t.edgeOpacity
        },
        "target-arrow-color": "data(cor)",
        "target-arrow-shape": "triangle",
        "source-arrow-shape": "none",
        "arrow-scale": 1.5,
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
        "color": t.edgeLabelText, "text-background-color": t.edgeLabelBg,
        "text-background-opacity": 0.92, "text-background-padding": "3px",
        "text-background-shape": "roundrectangle",
        "text-border-width": 0.8, "text-border-color": "data(cor)", "text-border-opacity": 0.6
      }
    },
    {
      selector: "edge.sequence-highlight",
      style: {
        "width": 4.0,
        "line-color": t.edgeHighlightColor,
        "line-opacity": 1.0,
        "target-arrow-color": t.edgeHighlightColor,
        "arrow-scale": 1.8
      }
    },
    {
      selector: "edge.spotlight-out",
      style: {
        "line-color": "#2f8f5b",
        "line-opacity": 1.0,
        "arrow-scale": 1.8
      }
    }
  ]
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
  applyJourneyStyling()
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
// Journey + like styling: node borders by priority (aprendido > fronteira/meta
// > curtido > categoria), edge colors by learned-state, and progressive reveal
// (display:none on what is neither learned nor frontier nor goal, unless the
// "mapa completo" is on). Single source of truth for node/edge styling, so
// learned (green) never loses to the like border (red).
// ---------------------------------------------------------------------------
function applyJourneyStyling() {
  const cy = window._cyInstance
  if (!cy) return

  // Antes do primeiro push da jornada (set_learned_steps), mostra tudo sem overlay.
  const learned = window._learnedStepCodes
  if (!learned) return

  // Overlays (highlight de sequência, modo manual) são donos temporários da
  // visão e revelam o que precisam; não mexer aqui — o clear deles reaplica a
  // jornada chamando applyJourneyStyling de novo.
  if (window._seqHighlightActive || window._manualMode) return

  const frontier = window._frontierStepCodes || new Set()
  const goal = window._goalStepCode
  // Modo de edição (admin) sempre mostra o grafo inteiro para poder editar
  // conexões, independente da revelação progressiva.
  const editMode = document.getElementById("graph-canvas")?.dataset.editMode === "true"
  const fullMap = window._fullMap === true || editMode
  const liked = window._likedStepCodes || new Set()
  const t = cyTheme()

  cy.batch(() => {
    cy.nodes().forEach(node => {
      const id = node.id()
      const isLearned = learned.has(id)
      const isFrontier = frontier.has(id)
      const isGoal = id === goal
      node.style("display", fullMap || isLearned || isFrontier || isGoal ? "element" : "none")

      if (isLearned) {
        node.removeClass("like-active journey-frontier").addClass("journey-learned")
        node.style({
          "border-color": t.journeyLearned,
          "border-width": node.data("highlighted") ? 5 : 3.5,
          "border-style": "solid"
        })
      } else if (isGoal || isFrontier) {
        node.removeClass("like-active journey-learned").addClass("journey-frontier")
        node.style({
          "border-color": t.journeyFrontier,
          "border-width": isGoal ? 3.5 : 2.5,
          "border-style": "dashed"
        })
      } else if (liked.has(id)) {
        node.removeClass("journey-learned journey-frontier").addClass("like-active")
        node.style({
          "border-color": t.likeBorderColor,
          "border-width": node.degree() >= 10 ? 3 : 2.5,
          "border-style": "solid"
        })
      } else {
        node.removeClass("like-active journey-learned journey-frontier")
        node.style({
          "border-color": node.data("cor") || "#9a7a5a",
          "border-width": node.degree() >= 10 ? 3 : 2,
          "border-style": node.data("suggested") ? "dashed" : "solid"
        })
      }
    })

    cy.edges().forEach(edge => {
      const src = edge.source().id()
      const tgt = edge.target().id()
      const state = learned.has(src) && learned.has(tgt) ? "learned" : learned.has(src) ? "frontier" : "hidden"
      edge.style("display", fullMap || state !== "hidden" ? "element" : "none")

      if (state === "learned") {
        edge.style({ "line-color": t.journeyLearned, "target-arrow-color": t.journeyLearned, "line-style": "solid", "line-opacity": 1 })
      } else if (state === "frontier") {
        edge.style({ "line-color": t.journeyFrontier, "target-arrow-color": t.journeyFrontier, "line-style": "dashed", "line-opacity": 1 })
      } else {
        edge.style({ "line-color": edge.data("cor"), "target-arrow-color": edge.data("cor"), "line-style": "solid" })
      }
    })
  })
}

// ---------------------------------------------------------------------------
// Hook: GraphVisual — sector layout + cola physics + spotlight + drawer
// ---------------------------------------------------------------------------
const GraphVisual = {
  async mounted() {
    // Registra os handlers de push ANTES do import async: os push_events do
    // mount conectado (set_liked_steps/set_favorited_steps/set_learned_steps)
    // chegam cedo e seriam perdidos se o registro esperasse o import.
    this._registerServerEvents()

    // Lazy-load Cytoscape + cola (only on /graph/visual)
    const [{ default: cytoscape }, { default: cytoscapeCola }] = await Promise.all([
      import("../vendor/cytoscape.min"),
      import("../vendor/cytoscape-cola"),
    ])
    cytoscape.use(cytoscapeCola)
    window._cytoscape = cytoscape

    this._bindGraphLegendInteractions()
    this._initGraph()
  },

  _registerServerEvents() {
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

    // Manual mode toggle. O builder manual constrói a sequência clicando nós, e
    // nó display:none não recebe clique — então o modo manual revela o grafo
    // inteiro (e applyJourneyStyling sai cedo enquanto _manualMode está ativo).
    this.handleEvent("set_manual_mode", ({ active }) => {
      this._manualMode = active
      window._manualMode = active
      this.el.dataset.manualMode = active ? "true" : "false"
      if (active) {
        this._clearSequenceHighlight({ refit: false })
        if (this._cy) this._cy.elements().style("display", "element")
      } else {
        this._clearManualStepGuide()
        applyJourneyStyling()
      }
    })

    // Liked steps: highlight with red border
    this.handleEvent("set_liked_steps", ({ codes }) => {
      window._likedStepCodes = new Set(codes)
      applyJourneyStyling()
    })

    // Favorited steps (for drawer buttons)
    this.handleEvent("set_favorited_steps", ({ codes }) => {
      window._favoritedStepCodes = new Set(codes)
    })

    // Jornada de estudos: aprendidos (verde), fronteira/meta (laranja) e
    // revelação progressiva. Recolore + mostra/esconde sem reconstruir o grafo.
    this.handleEvent("set_learned_steps", ({ learned, frontier, goal, full_map }) => {
      window._learnedStepCodes = new Set(learned)
      window._frontierStepCodes = new Set(frontier)
      window._goalStepCode = goal
      window._fullMap = full_map === true
      applyJourneyStyling()
    })

    // Drawer do StepDetail (server-side): centrar/destacar o nó ao abrir (clique
    // no nó ou num chip de conexão) e limpar o destaque ao fechar.
    this.handleEvent("center_node", ({ code }) => {
      const cy = this._cy
      if (!cy) return
      const node = cy.getElementById(code)
      if (node.length > 0) {
        // Revela o nó (um chip do drawer pode apontar para um passo escondido
        // no modo progressivo); o fechar do drawer reaplica a jornada.
        node.closedNeighborhood().style("display", "element")
        cy.animate({ center: { eles: node }, duration: 300 })
        node.select()
        applySpotlight(cy, node)
      }
    })

    this.handleEvent("clear_spotlight", () => {
      if (this._cy) clearSpotlight(this._cy)
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
    this._themeObserver?.disconnect()
    this._themeObserver = null
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
      style: buildCyStyle(currentUserId),
      minZoom: 0.06, maxZoom: 5,
      autoungrabifyNodes: true
    })

    this._cy = cy
    window._cyInstance = cy
    cy.edges().unselectify()

    // ── Hybrid layout: hubs at center + per-category Cola ──
    const sectorCenters = runHybridLayout(cy)

    // Apply liked step borders after layout (layout is synchronous here)
    applyJourneyStyling()

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
      hook.pushEvent("open_step", { code: node.id() })
    })

    cy.on("tap", function(evt) {
      if (evt.target === cy) {
        if (ghostSourceId) { cancelGhost(); return }
        if (hook._manualMode || hook.el.dataset.manualMode === "true") {
          hook._clearManualStepGuide()
          return
        }
        clearSpotlight(cy)
        hook.pushEvent("close_drawer", {})
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
        hook.pushEvent("close_drawer", {})
        hook._closeMobileLegend()
        clearSpotlight(cy)
        hook._activeCategory = null
        hook._resetLegend()
      }
    })

    // Theme toggle observer — re-apply Cytoscape colors when .dark changes
    if (this._themeObserver) this._themeObserver.disconnect()
    const themeObserver = new MutationObserver(mutations => {
      for (const m of mutations) {
        if (m.attributeName !== "class") continue
        const t = cyTheme()
        cy.batch(() => {
          cy.nodes().forEach(n => {
            const suggested = n.data("suggestedById") === currentUserId
            const highlighted = n.data("highlighted")
            n.style({
              "background-color": suggested ? t.nodeFillSuggested : (highlighted ? t.nodeFillHighlighted : t.nodeFillNormal),
              "color": t.nodeLabel,
              "border-opacity": t.nodeBorderOpacity,
            })
          })
          cy.edges().forEach(e => {
            const dense = e.source().degree() >= 10 || e.target().degree() >= 10
            e.style({ "line-opacity": dense ? t.edgeOpacity * 0.85 : t.edgeOpacity })
          })
          cy.edges("[label]").forEach(e => {
            e.style({ "color": t.edgeLabelText, "text-background-color": t.edgeLabelBg })
          })
          cy.edges(".sequence-highlight").forEach(e => {
            e.style({ "line-color": t.edgeHighlightColor, "target-arrow-color": t.edgeHighlightColor })
          })
          cy.nodes(".like-active").forEach(n => {
            n.style({ "border-color": t.likeBorderColor })
          })
        })
        break
      }
    })
    themeObserver.observe(document.documentElement, { attributes: true, attributeFilter: ["class"] })
    this._themeObserver = themeObserver
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

      // No "Meu progresso" a maioria dos nós está escondida; o filtro de
      // categoria só faz sentido no mapa completo (ou em edição). A legenda
      // segue como chave de cores, mas o clique não filtra aqui.
      const legendEditMode = this.el.dataset.editMode === "true"
      if (!window._fullMap && !legendEditMode) return

      const catName = btn.dataset.category
      this.pushEvent("close_drawer", {})
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
    const t = cyTheme()

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
      // Sequência sobrepõe a revelação progressiva: mostra tudo para o caminho
      // aparecer mesmo fora do "meu progresso". O clear reaplica a jornada.
      cy.elements().style("display", "element")

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
          "background-color": t.nodeFillHighlighted,
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
    const t = cyTheme()

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
        "background-color": t.nodeFillHighlighted
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
          "background-color": t.nodeFillOutgoing
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
    const t = cyTheme()

    cy.batch(() => {
      cy.nodes().forEach(node => {
        const suggestedByCurrentUser =
          node.data("suggestedById") && node.data("suggestedById") === this._currentUserId

        node.style({
          opacity: 1,
          "border-color": node.data("cor") || "#9a7a5a",
          "border-width": node.data("highlighted") ? 5 : (node.degree() >= 10 ? 3 : 2),
          "border-style": node.data("suggested") ? "dashed" : "solid",
          "background-color": suggestedByCurrentUser ? t.nodeFillSuggested : t.nodeFillNormal
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

    if (applyLiked) applyJourneyStyling()
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
    const t = cyTheme()

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
          "background-color": t.nodeFillNormal
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
    applyJourneyStyling()

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
    // Revela o nó buscado e a vizinhança mesmo em "Meu progresso" (a busca é uma
    // ação deliberada de "me mostre este passo"); o clear reaplica a jornada.
    node.closedNeighborhood().style("display", "element")
    node.select()
    applySpotlight(cy, node)

    const neighborhood = node.closedNeighborhood()
    cy.animate({ fit: { eles: neighborhood, padding: 120 }, duration: 350 })
  },

  _clearGraphFocus() {
    const cy = this._cy
    if (!cy) return

    cy.nodes().unselect()
    clearSpotlight(cy)
  }
}

export default GraphVisual
