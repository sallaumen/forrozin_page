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
import GraphVisual from "./graph_visual"
import CityAutocomplete from "./hooks/city_autocomplete"
import BackButton from "./hooks/back_button"
import BottomSheet from "./hooks/bottom_sheet"
import FormPersist from "./hooks/form_persist"
import OnboardingTour from "./hooks/onboarding_tour"
import AutoDismiss from "./hooks/auto_dismiss"
import DragReorder from "./hooks/drag_reorder"
import {PWAInstall, PWAInstallSettings, PWANavIcon} from "./hooks/pwa"
import {StickyOffset} from "./hooks/sticky_offset"
import dismissSplash from "./splash"

// Register PWA service worker (Phase 0b)
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/sw.js").catch((err) => {
      console.warn("Service worker registration failed:", err);
    });
  });
}

// ---------------------------------------------------------------------------
// PWA: Capture beforeinstallprompt GLOBALLY (must run before any hook)
// ---------------------------------------------------------------------------
window._deferredPWAPrompt = null
window.addEventListener('beforeinstallprompt', (e) => {
  e.preventDefault()
  window._deferredPWAPrompt = e
})

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, GraphVisual, CityAutocomplete, BackButton, BottomSheet, FormPersist, PWAInstall, PWAInstallSettings, PWANavIcon, OnboardingTour, AutoDismiss, DragReorder, StickyOffset},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
// On the first load the splash is what says "loading". The blue bar on top of
// it would be noise, so it is left to the navigations that follow.
window.addEventListener("phx:page-loading-start", info => {
  if (info.detail.kind !== "initial") { topbar.show(300) }
})
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// Clears a form after the server confirmed the submit. On purpose it does not
// clear on submit: if the server refuses (rate limit, validation), the typed
// text stays there.
window.addEventListener("phx:form:clear", (event) => {
  const form = document.getElementById(event.detail.id)
  if (form) { form.reset() }
})

// Clipboard copy handler (used by push_event from LiveView)
window.addEventListener("phx:clipboard:copy", (event) => {
  const text = event.detail.text
  if (navigator.clipboard) {
    navigator.clipboard.writeText(text)
  } else {
    // Fallback for older browsers
    const ta = document.createElement("textarea")
    ta.value = text
    ta.style.position = "fixed"
    ta.style.left = "-9999px"
    document.body.appendChild(ta)
    ta.select()
    document.execCommand("copy")
    document.body.removeChild(ta)
  }
})

window.addEventListener("phx:scroll-to-element", (event) => {
  const { id, behavior = "smooth", block = "center" } = event.detail

  window.requestAnimationFrame(() => {
    const el = document.getElementById(id)

    if (el) {
      el.scrollIntoView({ behavior, block, inline: "nearest" })
    }
  })
})

// ---------------------------------------------------------------------------
// Dark mode — server is the source of truth; localStorage is a FOUC cache
// ---------------------------------------------------------------------------
// On every server push, apply the class and keep localStorage in sync so
// that root.html.heex's inline script can prevent flash on next page load.
window.addEventListener("phx:set-dark-mode", (e) => {
  const isDark = e.detail.dark
  localStorage.setItem("dark_mode", isDark.toString())

  if (isDark) {
    document.documentElement.classList.add("dark")
  } else {
    document.documentElement.classList.remove("dark")
  }
})

// Copy-to-clipboard: triggered by a server push (e.g. the admin error copy
// button). Lives here, not as an inline <script>, so the CSP can forbid inline.
window.addEventListener("phx:copy_to_clipboard", (e) => {
  navigator.clipboard.writeText(e.detail.text).then(() => {
    const btn = document.activeElement
    if (btn) {
      btn.style.color = "#27ae60"
      setTimeout(() => { btn.style.color = "" }, 1000)
    }
  })
})

// The splash only leaves once the page is actually ready. On a LiveView that
// is the end of the initial join (kind: "initial"), when the data has arrived;
// on a page served by a controller there is nothing to wait for beyond this
// file. The listener goes in before connect() so the event cannot be missed.
if (document.querySelector("[data-phx-main]")) {
  window.addEventListener("phx:page-loading-stop", dismissSplash, {once: true})
} else {
  dismissSplash()
}

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// iOS Safari only fires :active (used for the tactile button flash, see
// app.css) when the page has a touch listener. One empty global listener solves
// it, with no inline handler (CSP-safe).
document.addEventListener("touchstart", () => {}, {passive: true})

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
