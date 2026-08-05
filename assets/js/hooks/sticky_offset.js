// ---------------------------------------------------------------------------
// Hook: StickyOffset — publishes the top bar's real height as a CSS variable
//
// The study tab strip sticks below the top bar, and CSS has no way to ask a
// sibling how tall it is. The offset used to be hardcoded at 48px, but the bar
// measures 56px for a student and 76px for an admin, because the admin menu
// makes the row wrap. Whoever organizes lost 28px of the tab strip behind the
// header.
//
// The bar writes its own height into `--top-nav-h`; whatever sticks below reads
// it. A ResizeObserver keeps it right when the row wraps, when the font scales,
// or when the viewport turns.
// ---------------------------------------------------------------------------
const StickyOffset = {
  mounted() {
    this.publish = () => {
      const height = Math.round(this.el.getBoundingClientRect().height)

      if (height > 0) {
        document.documentElement.style.setProperty("--top-nav-h", `${height}px`)
      }
    }

    this.publish()
    this.observer = new ResizeObserver(this.publish)
    this.observer.observe(this.el)
    window.addEventListener("orientationchange", this.publish)
  },

  updated() {
    this.publish()
  },

  destroyed() {
    if (this.observer) this.observer.disconnect()
    window.removeEventListener("orientationchange", this.publish)
  }
}

export {StickyOffset}
