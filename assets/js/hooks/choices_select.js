import Choices from "../../vendor/choices"

const ChoicesSelect = {
  mounted() {
    this._select = this.el.querySelector("select")
    if (!this._select) return

    const compact = this.el.dataset.compact === "true"
    const searchEnabled = this.el.dataset.searchEnabled !== "false"
    const placeholder = this.el.dataset.placeholder || "Select..."
    const options = JSON.parse(this.el.dataset.options || "[]")
    const selected = this.el.dataset.selected

    // Cache initial state to avoid unnecessary re-renders
    this._lastOptions = this.el.dataset.options
    this._lastSelected = selected

    const choices = options.map(o => ({
      value: o.value,
      label: o.label,
      selected: o.value === selected
    }))

    this._choices = new Choices(this._select, {
      searchEnabled,
      searchPlaceholderValue: "Search...",
      itemSelectText: "",
      shouldSort: false,
      allowHTML: false,
      placeholder: true,
      placeholderValue: placeholder,
      choices,
    })

    // Add compact class safely after initialization
    if (compact) {
      const outerEl = this.el.querySelector(".choices")
      if (outerEl) outerEl.classList.add("choices--compact")
    }

    this._select.addEventListener("change", (e) => {
      const eventName = this.el.dataset.event
      const valueKey = this.el.dataset.valueKey || "value"
      if (eventName) {
        this.pushEvent(eventName, { [valueKey]: e.target.value })
      }
    })
  },

  updated() {
    const newOptionsRaw = this.el.dataset.options || "[]"
    const newSelected = this.el.dataset.selected

    // Safety reinitialize if Choices was destroyed unexpectedly
    if (!this._choices) {
      this.mounted()
      return
    }

    // Skip refresh when data hasn't changed
    if (newOptionsRaw === this._lastOptions && newSelected === this._lastSelected) {
      return
    }

    this._lastOptions = newOptionsRaw
    this._lastSelected = newSelected

    const newOptions = JSON.parse(newOptionsRaw)

    this._choices.clearStore()
    this._choices.setChoices(
      newOptions.map(o => ({
        value: o.value,
        label: o.label,
        selected: o.value === newSelected
      }))
    )
  },

  destroyed() {
    if (this._choices) {
      this._choices.destroy()
      this._choices = null
    }
  }
}

export default ChoicesSelect
