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
// Ordem canônica das categorias no grafo radial.
// Define a posição angular de cada setor — muda a "leitura" do grafo.
// Categorias vizinhas no array ficam em setores adjacentes no círculo.
// ---------------------------------------------------------------------------
const CATEGORIA_ORDEM = [
  "bases",       // 12h — ponto de partida natural da dança
  "sacadas",     // grupo sacada + SCSP juntos
  "travas",      // travas ao lado de sacadas (fluxo natural)
  "pescadas",    // saída natural de travas/sacadas
  "caminhadas",  // caminhadas ao lado de pescadas
  "giros",       // giros ao lado de caminhadas
  "inversao",    // inversão ao lado de giros
  "outros",      // hub: TRD, PMB, CHQ, arrastes, abraço lateral...
]

// ---------------------------------------------------------------------------
// Calcula posições setoriais: cada categoria = um setor do círculo.
// Dentro de cada setor os nós são dispostos em arco perpendicular ao raio,
// em múltiplas "fileiras" radiais se o setor tiver muitos nós.
// ---------------------------------------------------------------------------
function computeSectorPositions(cy) {
  // Agrupa nós por categoria
  const byCat = {}
  cy.nodes().forEach(n => {
    const cat = n.data("categoria") || "outros"
    ;(byCat[cat] = byCat[cat] || []).push(n)
  })

  // Monta a lista de categorias ativas na ordem canônica,
  // appending categorias desconhecidas ao final
  const activeCats = CATEGORIA_ORDEM.filter(c => byCat[c]?.length > 0)
  Object.keys(byCat).forEach(c => {
    if (!activeCats.includes(c)) activeCats.push(c)
  })

  const numCats  = activeCats.length
  const positions = {}

  // Constantes de geometria
  const R_BASE    = 340   // raio do centro de cada setor
  const NODE_GAP  = 150   // espaço entre nós dentro do setor (tangencial)
  const ROW_GAP   = 140   // espaço entre fileiras radiais

  activeCats.forEach((cat, i) => {
    const group  = byCat[cat]
    const n      = group.length

    // Ângulo central do setor — começa em -90° (12h) e gira horário
    const theta  = (2 * Math.PI * i / numCats) - Math.PI / 2

    // Vetores unitários: radial (para fora) e tangencial (perpendicular)
    const rHat = { x: Math.cos(theta), y: Math.sin(theta) }
    const tHat = { x: -Math.sin(theta), y: Math.cos(theta) }

    // Quantos nós cabem por fileira? Limita a 4 para não alargiar demais.
    const perRow = Math.min(4, Math.ceil(Math.sqrt(n)))
    const rows   = Math.ceil(n / perRow)

    // Centro do setor no espaço cartesiano
    const cx = R_BASE * rHat.x
    const cy_ = R_BASE * rHat.y

    group.forEach((node, j) => {
      const row = Math.floor(j / perRow)
      const col = j % perRow
      // Número de nós na fileira atual (pode ser menor na última)
      const colsInRow = (row === rows - 1) ? (n - row * perRow) : perRow

      // Centraliza a fileira
      const colOffset = (col - (colsInRow - 1) / 2) * NODE_GAP
      // Fileiras mais externas ficam mais longe do centro
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
// Hook: GraphVisual — layout setorial por categoria + cola para overlap
// ---------------------------------------------------------------------------
const GraphVisual = {
  mounted() { this._initGraph() },
  updated() { this._initGraph() },

  _initGraph() {
    const el  = this.el
    const raw = el.dataset.graph
    if (!raw) return

    const {nodes, edges} = JSON.parse(raw)

    if (this._cy) { this._cy.destroy(); this._cy = null }

    const elements = [
      ...nodes.map(n => ({
        data: { id: n.id, label: n.nome, categoria: n.categoria, cor: n.cor || "#9a7a5a" }
      })),
      ...edges.map(e => ({
        data: Object.assign(
          { source: e.from, target: e.to },
          e.label ? { label: e.label } : {}
        )
      }))
    ]

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
            "padding": "10px 16px",
            "background-color": "#fffef9",
            "border-width": 2,
            "border-color": "data(cor)",
            "border-opacity": 0.85,
            "label": function(ele) {
              return ele.data("categoria").toUpperCase() + "\n" + ele.data("label")
            },
            "text-wrap": "wrap",
            "text-halign": "center",
            "text-valign": "center",
            "font-family": "Georgia, serif",
            "font-size": "11px",
            "color": "#1a0e05",
            "text-max-width": "160px",
            "min-width": "90px",
            "shadow-blur": 6,
            "shadow-color": "rgba(60,40,20,0.12)",
            "shadow-offset-x": 0,
            "shadow-offset-y": 2,
            "shadow-opacity": 1
          }
        },
        {
          selector: "node:selected",
          style: {
            "background-color": "data(cor)",
            "background-opacity": 0.15,
            "border-width": 3,
            "border-opacity": 1,
            "shadow-blur": 14,
            "shadow-opacity": 1
          }
        },
        { selector: "node:grabbed", style: { "shadow-blur": 18, "shadow-opacity": 1 } },
        {
          selector: "edge",
          style: {
            "width": 1.5,
            "line-color": "data(cor)",
            "line-opacity": 0.45,
            "target-arrow-color": "data(cor)",
            "target-arrow-shape": "triangle",
            "arrow-scale": 0.9,
            "curve-style": "bezier"
          }
        },
        {
          selector: "edge[label]",
          style: {
            "label": "data(label)",
            "font-size": "10px",
            "font-family": "Georgia, serif",
            "font-style": "italic",
            "text-rotation": "autorotate",
            "text-margin-y": -10,
            "color": "#3a2510",
            "text-background-color": "#fffdf8",
            "text-background-opacity": 0.92,
            "text-background-padding": "3px",
            "text-background-shape": "roundrectangle",
            "text-border-width": 0.8,
            "text-border-color": "data(cor)",
            "text-border-opacity": 0.6
          }
        },
        { selector: "edge:selected", style: { "line-opacity": 1, "width": 2.5 } }
      ],

      wheelSensitivity: 0.3,
      minZoom: 0.08,
      maxZoom: 4
    })

    this._cy = cy

    // Herda cor da categoria de origem para as arestas
    cy.edges().forEach(edge => {
      edge.data("cor", edge.source().data("cor") || "#9a7a5a")
    })

    // ── Fase 1: posicionar nós nos setores calculados ────────────────────
    const positions = computeSectorPositions(cy)
    cy.layout({ name: "preset", positions, animate: false }).run()

    // ── Fase 2: cola brevíssimo para resolver sobreposições residuais ────
    // randomize: false mantém os setores como ponto de partida;
    // maxSimulationTime curto impede que a física desfaça o agrupamento.
    cy.layout({
      name: "cola",
      animate: true,
      animationDuration: 900,
      maxSimulationTime: 1800,
      randomize: false,          // parte das posições setoriais calculadas
      fit: true,
      padding: 56,
      avoidOverlaps: true,
      nodeDimensionsIncludeLabels: true,
      edgeLength: function(e) {
        // Arestas dentro do mesmo setor ficam curtas; entre setores, mais longas
        return e.source().data("categoria") === e.target().data("categoria") ? 130 : 260
      },
      gravity: 0.4,              // gravidade baixa: mantém setores afastados
      convergenceThreshold: 0.05,
      infinite: false
    }).run()

    cy.one("layoutstop", () => { cy.fit(undefined, 56) })

    // ── Fase 3: ao arrastar, cola curto só para anti-sobreposição local ──
    cy.on("dragfreeon", "node", () => {
      cy.layout({
        name: "cola",
        animate: true,
        animationDuration: 400,
        maxSimulationTime: 600,
        randomize: false,
        fit: false,
        padding: 56,
        avoidOverlaps: true,
        nodeDimensionsIncludeLabels: true,
        edgeLength: function(e) {
          return e.source().data("categoria") === e.target().data("categoria") ? 130 : 260
        },
        gravity: 0.4,
        convergenceThreshold: 0.1,
        infinite: false
      }).run()
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

