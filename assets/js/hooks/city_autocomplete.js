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
      suggestions.style.display = "none"
      this._currentCities = []

      if (this._isBrazil) {
        stateWrapper.style.display = "block"
        stateSelect.required = true
        cityInput.placeholder = "Digite sua cidade"
      } else {
        stateWrapper.style.display = "none"
        stateSelect.value = ""
        stateSelect.required = false
        cityInput.placeholder = "Digite sua cidade"
      }
    }

    countrySelect.addEventListener("change", updateCountry)
    updateCountry()

    stateSelect.addEventListener("change", () => {
      // Don't clear cityInput.value — user may have typed something valid
      cityInput.placeholder = "Digite sua cidade"
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

    // City is free text — no validation against IBGE list.
    // Autocomplete is a suggestion, not a requirement.
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

export default CityAutocomplete
