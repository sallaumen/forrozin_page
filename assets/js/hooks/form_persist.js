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

export default FormPersist
