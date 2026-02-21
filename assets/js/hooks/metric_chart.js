const MetricChart = {
  mounted() {
    this._svg = this.el.querySelector("svg")
    if (!this._svg) return

    this._tooltip = document.createElement("div")
    this._tooltip.className = "metric-chart-tooltip"
    this._tooltip.style.display = "none"
    this.el.appendChild(this._tooltip)

    this._crosshair = document.createElementNS("http://www.w3.org/2000/svg", "line")
    this._crosshair.setAttribute("stroke", "#e77117")
    this._crosshair.setAttribute("stroke-width", "1")
    this._crosshair.setAttribute("stroke-dasharray", "4 3")
    this._crosshair.setAttribute("opacity", "0.5")
    this._crosshair.style.display = "none"
    this._svg.appendChild(this._crosshair)

    this._dot = document.createElementNS("http://www.w3.org/2000/svg", "circle")
    this._dot.setAttribute("r", "4")
    this._dot.setAttribute("fill", "#e77117")
    this._dot.setAttribute("stroke", "white")
    this._dot.setAttribute("stroke-width", "2")
    this._dot.style.display = "none"
    this._svg.appendChild(this._dot)

    this._bindEvents()
  },

  updated() {
    this._svg = this.el.querySelector("svg")
    if (this._svg && this._crosshair && !this._svg.contains(this._crosshair)) {
      this._svg.appendChild(this._crosshair)
      this._svg.appendChild(this._dot)
    }
  },

  destroyed() {
    if (this._tooltip && this._tooltip.parentNode) {
      this._tooltip.parentNode.removeChild(this._tooltip)
    }
  },

  _bindEvents() {
    const handleMove = (clientX, clientY) => {
      const points = JSON.parse(this.el.dataset.points || "[]")
      if (!points.length || !this._svg) return

      const rect = this._svg.getBoundingClientRect()
      const viewBox = this._svg.viewBox.baseVal
      const scaleX = viewBox.width / rect.width
      const svgX = (clientX - rect.left) * scaleX

      let nearest = points[0]
      let minDist = Math.abs(svgX - nearest.x)
      for (const p of points) {
        const d = Math.abs(svgX - p.x)
        if (d < minDist) { minDist = d; nearest = p }
      }

      this._crosshair.setAttribute("x1", nearest.x)
      this._crosshair.setAttribute("x2", nearest.x)
      this._crosshair.setAttribute("y1", viewBox.y)
      this._crosshair.setAttribute("y2", viewBox.height)
      this._crosshair.style.display = ""

      this._dot.setAttribute("cx", nearest.x)
      this._dot.setAttribute("cy", nearest.y)
      this._dot.style.display = ""

      const unit = this.el.dataset.unit || ""
      this._tooltip.textContent = nearest.val
      this._tooltip.style.display = ""

      const tipRect = this._tooltip.getBoundingClientRect()
      let tipX = clientX - rect.left - tipRect.width / 2
      tipX = Math.max(0, Math.min(tipX, rect.width - tipRect.width))
      const tipY = (nearest.y / viewBox.height) * rect.height - tipRect.height - 10
      this._tooltip.style.left = tipX + "px"
      this._tooltip.style.top = Math.max(0, tipY) + "px"
    }

    this._svg.addEventListener("mousemove", (e) => handleMove(e.clientX, e.clientY))
    this._svg.addEventListener("touchmove", (e) => {
      if (e.touches.length) handleMove(e.touches[0].clientX, e.touches[0].clientY)
    }, { passive: true })

    const hide = () => {
      this._crosshair.style.display = "none"
      this._dot.style.display = "none"
      this._tooltip.style.display = "none"
    }
    this._svg.addEventListener("mouseleave", hide)
    this._svg.addEventListener("touchend", hide)
  }
}

export default MetricChart
