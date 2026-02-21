const MetricChart = {
  mounted() {
    this._tooltip = null

    this._crosshair = document.createElementNS("http://www.w3.org/2000/svg", "line")
    this._crosshair.setAttribute("stroke", "#e77117")
    this._crosshair.setAttribute("stroke-width", "1")
    this._crosshair.setAttribute("stroke-dasharray", "4 3")
    this._crosshair.setAttribute("opacity", "0.5")
    this._crosshair.style.display = "none"

    this._dot = document.createElementNS("http://www.w3.org/2000/svg", "circle")
    this._dot.setAttribute("r", "4")
    this._dot.setAttribute("fill", "#e77117")
    this._dot.setAttribute("stroke", "white")
    this._dot.setAttribute("stroke-width", "2")
    this._dot.style.display = "none"
    this._eventsBound = false
    this._syncSvg()
  },

  updated() {
    this._syncSvg()
  },

  destroyed() {
    this._unbindEvents()

    if (this._tooltip && this._tooltip.parentNode) {
      this._tooltip.parentNode.removeChild(this._tooltip)
    }
  },

  _syncSvg() {
    const nextSvg = this.el.querySelector("svg")
    if (!nextSvg) return

    this._ensureTooltip()
    this._points = this._readPoints()

    if (this._svg && this._svg !== nextSvg) {
      this._unbindEvents()
    }

    this._svg = nextSvg

    if (this._crosshair && !this._svg.contains(this._crosshair)) {
      this._svg.appendChild(this._crosshair)
    }

    if (this._dot && !this._svg.contains(this._dot)) {
      this._svg.appendChild(this._dot)
    }

    this._renderAxisLabels(this._points)

    if (!this._eventsBound) {
      this._bindEvents()
    }
  },

  _bindEvents() {
    const handleMove = (clientX, clientY) => {
      const points = this._points || []
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

      if (!this._tooltip) return

      if (Number.isFinite(nearest.ts)) {
        const tsLabel = new Date(nearest.ts * 1000).toLocaleTimeString([], {
          hour: "2-digit",
          minute: "2-digit",
          second: "2-digit",
          timeZoneName: "short"
        })
        this._tooltip.textContent = `${nearest.val} @ ${tsLabel}`
      } else {
        this._tooltip.textContent = nearest.val
      }
      this._tooltip.style.display = ""

      const tipRect = this._tooltip.getBoundingClientRect()
      let tipX = clientX - rect.left - tipRect.width / 2
      tipX = Math.max(0, Math.min(tipX, rect.width - tipRect.width))
      const tipY = (nearest.y / viewBox.height) * rect.height - tipRect.height - 10
      this._tooltip.style.left = tipX + "px"
      this._tooltip.style.top = Math.max(0, tipY) + "px"
    }

    this._onMouseMove = (e) => handleMove(e.clientX, e.clientY)
    this._onTouchMove = (e) => {
      if (e.touches.length) handleMove(e.touches[0].clientX, e.touches[0].clientY)
    }

    this._onHide = () => {
      this._crosshair.style.display = "none"
      this._dot.style.display = "none"
      if (this._tooltip) this._tooltip.style.display = "none"
    }

    this._svg.addEventListener("mousemove", this._onMouseMove)
    this._svg.addEventListener("touchmove", this._onTouchMove, { passive: true })
    this._svg.addEventListener("mouseleave", this._onHide)
    this._svg.addEventListener("touchend", this._onHide)
    this._eventsBound = true
  },

  _unbindEvents() {
    if (!this._svg || !this._eventsBound) return

    this._svg.removeEventListener("mousemove", this._onMouseMove)
    this._svg.removeEventListener("touchmove", this._onTouchMove)
    this._svg.removeEventListener("mouseleave", this._onHide)
    this._svg.removeEventListener("touchend", this._onHide)
    this._eventsBound = false
  },

  _ensureTooltip() {
    if (this._tooltip && this.el.contains(this._tooltip)) return

    this._tooltip = document.createElement("div")
    this._tooltip.className = "metric-chart-tooltip"
    this._tooltip.style.display = "none"
    this.el.appendChild(this._tooltip)
  },

  _readPoints() {
    try {
      const parsed = JSON.parse(this.el.dataset.points || "[]")
      return Array.isArray(parsed) ? parsed : []
    } catch {
      return []
    }
  },

  _renderAxisLabels(points) {
    const startEl = this.el.querySelector("[data-metric-axis-start]")
    const endEl = this.el.querySelector("[data-metric-axis-end]")

    if (!startEl || !endEl || !Array.isArray(points) || points.length < 2) return

    const tsPoints = points.filter((p) => Number.isFinite(p.ts))
    if (tsPoints.length < 2) return

    const sortedTs = tsPoints.map((p) => p.ts).sort((a, b) => a - b)
    const startTs = sortedTs[0]
    const endTs = sortedTs[sortedTs.length - 1]

    const format = (ts) =>
      new Intl.DateTimeFormat(undefined, {
        hour: "2-digit",
        minute: "2-digit"
      }).format(new Date(ts * 1000))

    startEl.textContent = format(startTs)
    endEl.textContent = format(endTs)
  }
}

export default MetricChart
