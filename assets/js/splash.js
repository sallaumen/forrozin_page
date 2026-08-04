// Takes the loading splash (#app-splash, in root.html.heex) off the screen.
//
// The splash starts at opacity 0 and takes 400ms to show up. If the app was
// ready before that, nobody ever saw it, so it leaves at once. If it was
// already visible, freeze the opacity it has right now and transition to zero:
// fading out "from 1" while the screen was still at "0.3" would flash.
const FADE_MS = 240

export default function dismissSplash() {
  const splash = document.getElementById("app-splash")
  if (!splash) { return }

  const shown = parseFloat(getComputedStyle(splash).opacity)
  if (shown === 0) { return splash.remove() }

  splash.style.opacity = shown
  splash.dataset.leaving = ""
  splash.getBoundingClientRect()
  splash.style.opacity = "0"
  setTimeout(() => splash.remove(), FADE_MS + 60)
}
