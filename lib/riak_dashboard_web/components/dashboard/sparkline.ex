defmodule RiakDashboardWeb.Components.Dashboard.Sparkline do
  @moduledoc "Pure SVG sparkline renderer for metric trend visualization."

  use Phoenix.Component

  attr :data, :list, required: true, doc: "List of numeric values"
  attr :width, :integer, default: 120
  attr :height, :integer, default: 24
  attr :color, :string, default: "#e77117"
  attr :class, :string, default: ""

  def sparkline(assigns) do
    points = build_points(assigns.data, assigns.width, assigns.height)
    assigns = assign(assigns, :points, points)

    ~H"""
    <svg
      viewBox={"0 0 #{@width} #{@height}"}
      class={["inline-block", @class]}
      preserveAspectRatio="none"
      role="img"
      aria-label="Sparkline trend"
    >
      <polyline
        :if={length(@data) > 1}
        fill="none"
        stroke={@color}
        stroke-width="1.5"
        stroke-linecap="round"
        stroke-linejoin="round"
        points={@points}
      />
      <line
        :if={length(@data) <= 1}
        x1="0"
        y1={@height / 2}
        x2={@width}
        y2={@height / 2}
        stroke={@color}
        stroke-width="1"
        stroke-dasharray="4 3"
        opacity="0.4"
      />
    </svg>
    """
  end

  defp build_points([], _w, _h), do: ""
  defp build_points([_], w, h), do: "0,#{h / 2} #{w},#{h / 2}"

  defp build_points(data, w, h) do
    min_val = Enum.min(data)
    max_val = Enum.max(data)
    range = if max_val == min_val, do: 1, else: max_val - min_val
    padding = 2
    usable_h = h - padding * 2
    step = w / max(length(data) - 1, 1)

    data
    |> Enum.with_index()
    |> Enum.map(fn {val, i} ->
      x = Float.round(i * step, 1)
      y = Float.round(padding + usable_h - (val - min_val) / range * usable_h, 1)
      "#{x},#{y}"
    end)
    |> Enum.join(" ")
  end
end
