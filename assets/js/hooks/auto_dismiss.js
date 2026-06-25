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

export default AutoDismiss
