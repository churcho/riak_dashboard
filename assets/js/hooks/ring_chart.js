// assets/js/hooks/ring_chart.js
const RingChart = {
  mounted() {
    this.canvas = this.el.querySelector("canvas");
    this.ctx = this.canvas.getContext("2d");
    this.handleThemeChanged = () => this.draw();

    window.addEventListener("riak:theme-changed", this.handleThemeChanged);
    this.draw();
  },

  updated() {
    this.draw();
  },

  destroyed() {
    window.removeEventListener("riak:theme-changed", this.handleThemeChanged);
  },

  draw() {
    const data = JSON.parse(this.el.dataset.ring || "null");
    if (!data) return;

    const {partitions, node_colors} = data;
    const dpr = window.devicePixelRatio || 1;
    const displayWidth = this.canvas.clientWidth || 400;
    const displayHeight = this.canvas.clientHeight || 400;

    this.canvas.width = displayWidth * dpr;
    this.canvas.height = displayHeight * dpr;
    this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

    const cx = displayWidth / 2;
    const cy = displayHeight / 2;
    const r = Math.min(cx, cy) - 20;
    const step = (2 * Math.PI) / partitions.length;

    // OpenRiak color palette for nodes
    const colors = [
      "#e77117", "#222b34", "#27d7b9", "#4a90d9",
      "#e8534e", "#6b8f71", "#9b59b6", "#f39c12"
    ];

    this.ctx.clearRect(0, 0, displayWidth, displayHeight);

    // Draw partition segments
    partitions.forEach((p, i) => {
      const colorIdx = Number.isInteger(node_colors[p.node]) ? node_colors[p.node] : 0;
      const color = colors[colorIdx % colors.length] || colors[i % colors.length];
      const startAngle = i * step - Math.PI / 2;
      const endAngle = (i + 1) * step - Math.PI / 2;

      this.ctx.beginPath();
      this.ctx.moveTo(cx, cy);
      this.ctx.arc(cx, cy, r, startAngle, endAngle);
      this.ctx.closePath();
      this.ctx.fillStyle = color;
      this.ctx.fill();
    });

    const isDark = document.documentElement.classList.contains("dark");
    const innerBg = isDark ? "#1F2937" : "#FAFAF8";
    const centerText = isDark ? "#E2E8F0" : "#1A1A1A";
    const subtitleText = isDark ? "#94A3B8" : "#8A8A8A";

    // Draw inner circle (hole for donut effect)
    const innerR = r * 0.6;
    this.ctx.beginPath();
    this.ctx.arc(cx, cy, innerR, 0, 2 * Math.PI);
    this.ctx.fillStyle = innerBg;
    this.ctx.fill();

    // Draw center text
    this.ctx.fillStyle = centerText;
    this.ctx.font = "bold 24px 'Inter', sans-serif";
    this.ctx.textAlign = "center";
    this.ctx.textBaseline = "middle";
    this.ctx.fillText(partitions.length, cx, cy - 10);
    this.ctx.font = "12px 'Figtree', sans-serif";
    this.ctx.fillStyle = subtitleText;
    this.ctx.fillText("partitions", cx, cy + 12);
  }
};

export default RingChart;
