defmodule RiakDashboardWeb.Components.Dashboard.Sparkline do
  @moduledoc "Pure SVG sparkline with area fill and endpoint dot."

  use Phoenix.Component

  attr :data, :list, required: true, doc: "List of numeric values"
  attr :width, :integer, default: 120
  attr :height, :integer, default: 24
  attr :color, :string, default: "#e77117"
  attr :class, :string, default: ""

  def sparkline(assigns) do
    points = build_points(assigns.data, assigns.width, assigns.height)
    area = build_area(assigns.data, assigns.width, assigns.height)
    endpoint = last_point(assigns.data, assigns.width, assigns.height)
    uid = "spark-#{System.unique_integer([:positive])}"
    assigns = assign(assigns, points: points, area: area, endpoint: endpoint, uid: uid)

    ~H"""
    <svg
      viewBox={"0 0 #{@width} #{@height}"}
      class={["inline-block", @class]}
      preserveAspectRatio="none"
      role="img"
      aria-label="Sparkline trend"
    >
      <defs :if={length(@data) > 1}>
        <linearGradient id={@uid} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color={@color} stop-opacity="0.2" />
          <stop offset="100%" stop-color={@color} stop-opacity="0.02" />
        </linearGradient>
      </defs>

      <polygon
        :if={length(@data) > 1}
        fill={"url(##{@uid})"}
        points={@area}
      />

      <polyline
        :if={length(@data) > 1}
        fill="none"
        stroke={@color}
        stroke-width="1.5"
        stroke-linecap="round"
        stroke-linejoin="round"
        points={@points}
      />

      <circle
        :if={@endpoint}
        cx={elem(@endpoint, 0)}
        cy={elem(@endpoint, 1)}
        r="2"
        fill={@color}
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
        opacity="0.3"
      />
    </svg>
    """
  end

  defp build_points([], _w, _h), do: ""
  defp build_points([_], w, h), do: "0,#{h / 2} #{w},#{h / 2}"

  defp build_points(data, w, h) do
    coords(data, w, h)
    |> Enum.map(fn {x, y} -> "#{x},#{y}" end)
    |> Enum.join(" ")
  end

  defp build_area(data, w, h) when length(data) > 1 do
    pts = coords(data, w, h)
    line = Enum.map(pts, fn {x, y} -> "#{x},#{y}" end) |> Enum.join(" ")
    {last_x, _} = List.last(pts)
    "#{line} #{last_x},#{h} 0,#{h}"
  end

  defp build_area(_, _, _), do: ""

  defp last_point(data, w, h) when length(data) > 1 do
    coords(data, w, h) |> List.last()
  end

  defp last_point(_, _, _), do: nil

  defp coords(data, w, h) do
    min_val = Enum.min(data)
    max_val = Enum.max(data)
    range = if max_val == min_val, do: 1, else: max_val - min_val
    padding = 3
    usable_h = h - padding * 2
    step = w / max(length(data) - 1, 1)

    data
    |> Enum.with_index()
    |> Enum.map(fn {val, i} ->
      x = Float.round(i * step, 1)
      y = Float.round(padding + usable_h - (val - min_val) / range * usable_h, 1)
      {x, y}
    end)
  end
end
