defmodule RiakDashboardWeb.Components.Dashboard.MetricChart do
  @moduledoc "Full-width interactive area chart with metric pill switching."

  use Phoenix.Component

  @metrics [
    %{key: "memory", label: "Memory", unit: "MB"},
    %{key: "vnode_gets", label: "VNode Gets", unit: ""},
    %{key: "vnode_puts", label: "VNode Puts", unit: ""},
    %{key: "processes", label: "Processes", unit: ""},
    %{key: "get_latency", label: "Get Latency", unit: "\u00B5s"},
    %{key: "put_latency", label: "Put Latency", unit: "\u00B5s"},
    %{key: "read_repairs", label: "Read Repairs", unit: ""}
  ]

  attr :selected_metric, :string, required: true
  attr :data, :list, required: true, doc: "List of numeric values for the selected metric"
  attr :unit, :string, default: ""

  def metric_chart(assigns) do
    assigns = assign(assigns, :metrics, @metrics)

    chart_width = 800
    chart_height = 220
    pad_left = 60
    pad_right = 20
    pad_top = 16
    pad_bottom = 32
    usable_w = chart_width - pad_left - pad_right
    usable_h = chart_height - pad_top - pad_bottom

    {curve_path, area_path, coords, y_labels, data_json, summary} =
      build_chart_data(
        assigns.data,
        usable_w,
        usable_h,
        pad_left,
        pad_top,
        pad_bottom,
        chart_height,
        assigns.unit
      )

    grid_lines = build_grid_lines(y_labels, pad_left, chart_width - pad_right)
    current_label = Enum.find(@metrics, fn m -> m.key == assigns.selected_metric end)

    assigns =
      assign(assigns,
        chart_width: chart_width,
        chart_height: chart_height,
        pad_left: pad_left,
        pad_right: pad_right,
        pad_top: pad_top,
        pad_bottom: pad_bottom,
        curve_path: curve_path,
        area_path: area_path,
        coords: coords,
        y_labels: y_labels,
        grid_lines: grid_lines,
        data_json: data_json,
        summary: summary,
        current_label: current_label
      )

    ~H"""
    <div class="bg-white rounded-xl border border-[#EEEDEA] p-4 dark:bg-[var(--or-bg-surface)] dark:border-[var(--or-border-base)]">
      <%!-- Header: title + current value + pills --%>
      <div class="flex items-start justify-between mb-1 flex-wrap gap-2">
        <div>
          <div class="flex items-baseline gap-3">
            <h3 class="text-xs font-semibold uppercase tracking-wider text-[#8A8A8A] dark:text-[#94A3B8]">
              {(@current_label && @current_label.label) || "Performance"}
            </h3>
            <span
              :if={@summary.current != nil}
              class="text-2xl font-bold font-heading text-[#1A1A1A] dark:text-[#E2E8F0] tracking-tight leading-none"
            >
              {@summary.current}
            </span>
          </div>
          <%!-- Min / Avg / Max summary --%>
          <div
            :if={@summary.current != nil}
            class="flex items-center gap-4 mt-1.5 text-[11px] text-[#8A8A8A] dark:text-[#6B7280]"
          >
            <span>
              Min
              <span class="font-semibold text-[#1A1A1A] dark:text-[#E2E8F0] tabular-nums">
                {@summary.min}
              </span>
            </span>
            <span>
              Avg
              <span class="font-semibold text-[#1A1A1A] dark:text-[#E2E8F0] tabular-nums">
                {@summary.avg}
              </span>
            </span>
            <span>
              Max
              <span class="font-semibold text-[#1A1A1A] dark:text-[#E2E8F0] tabular-nums">
                {@summary.max}
              </span>
            </span>
          </div>
        </div>
        <div class="flex flex-wrap gap-1.5">
          <button
            :for={m <- @metrics}
            type="button"
            phx-click="select_metric"
            phx-value-metric={m.key}
            class={[
              "px-2.5 py-1 rounded text-[11px] font-medium transition-all duration-150",
              "focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]",
              if(m.key == @selected_metric,
                do: "bg-[#e77117] text-white",
                else:
                  "bg-[#F5F3EF] text-[#5A5A5A] hover:bg-[#EEEDEA] dark:bg-[#334155] dark:text-[#94A3B8] dark:hover:bg-[#3E4C5E]"
              )
            ]}
          >
            {m.label}
          </button>
        </div>
      </div>

      <%!-- Chart --%>
      <div
        id="metric-chart"
        phx-hook="MetricChart"
        data-points={@data_json}
        data-unit={@unit}
        class="relative mt-3"
      >
        <svg
          viewBox={"0 0 #{@chart_width} #{@chart_height}"}
          class="w-full h-auto"
          preserveAspectRatio="xMidYMid meet"
        >
          <defs>
            <linearGradient id="metric-area-gradient" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stop-color="#e77117" stop-opacity="0.20" />
              <stop offset="100%" stop-color="#e77117" stop-opacity="0.01" />
            </linearGradient>
          </defs>

          <%!-- Grid lines --%>
          <line
            :for={gl <- @grid_lines}
            x1={gl.x1}
            y1={gl.y}
            x2={gl.x2}
            y2={gl.y}
            stroke="#EEEDEA"
            stroke-width="1"
            class="dark:stroke-[#334155]"
          />

          <%!-- Y-axis labels --%>
          <text
            :for={yl <- @y_labels}
            x={@pad_left - 8}
            y={yl.y}
            text-anchor="end"
            dominant-baseline="middle"
            class="fill-[#8A8A8A] dark:fill-[#6B7280]"
            font-size="11"
            font-family="Inter, sans-serif"
          >
            {yl.label}
          </text>

          <%!-- Time axis labels --%>
          <text
            :if={length(@data) > 1}
            x={@pad_left}
            y={@chart_height - 6}
            text-anchor="start"
            class="fill-[#A8A8A8] dark:fill-[#6B7280]"
            font-size="10"
            font-family="Inter, sans-serif"
          >
            30s ago
          </text>
          <text
            :if={length(@data) > 1}
            x={@chart_width - @pad_right}
            y={@chart_height - 6}
            text-anchor="end"
            class="fill-[#A8A8A8] dark:fill-[#6B7280]"
            font-size="10"
            font-family="Inter, sans-serif"
          >
            now
          </text>

          <%!-- Area fill (smooth) --%>
          <path
            :if={@area_path != ""}
            fill="url(#metric-area-gradient)"
            d={@area_path}
          />

          <%!-- Smooth curve line --%>
          <path
            :if={@curve_path != ""}
            fill="none"
            stroke="#e77117"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            d={@curve_path}
          />

          <%!-- Data point dots --%>
          <circle
            :for={{x, y} <- @coords}
            cx={x}
            cy={y}
            r="2"
            fill="white"
            stroke="#e77117"
            stroke-width="1.5"
            class="dark:fill-[#1F2937]"
          />

          <%!-- Endpoint dot (larger) --%>
          <circle
            :if={@coords != []}
            cx={elem(List.last(@coords), 0)}
            cy={elem(List.last(@coords), 1)}
            r="4"
            fill="#e77117"
            stroke="white"
            stroke-width="2"
            class="dark:stroke-[#1F2937]"
          />

          <%!-- Empty state --%>
          <line
            :if={length(@data) <= 1}
            x1={@pad_left}
            y1={@chart_height / 2}
            x2={@chart_width - 20}
            y2={@chart_height / 2}
            stroke="#e77117"
            stroke-width="1"
            stroke-dasharray="6 4"
            opacity="0.3"
          />
          <text
            :if={length(@data) <= 1}
            x={@chart_width / 2}
            y={@chart_height / 2 - 12}
            text-anchor="middle"
            class="fill-[#A8A8A8] dark:fill-[#6B7280]"
            font-size="12"
            font-family="Inter, sans-serif"
          >
            Collecting data...
          </text>
        </svg>
      </div>
    </div>
    """
  end

  # -- Chart geometry --

  defp build_chart_data(
         data,
         usable_w,
         usable_h,
         pad_left,
         pad_top,
         pad_bottom,
         chart_height,
         unit
       )
       when length(data) > 1 do
    raw_max = Enum.max(data)
    max_val = if raw_max == 0, do: 1, else: raw_max * 1.2
    range = max_val
    step = usable_w / max(length(data) - 1, 1)

    coords =
      data
      |> Enum.with_index()
      |> Enum.map(fn {val, i} ->
        x = Float.round(pad_left + i * step, 1)
        y = Float.round(pad_top + usable_h - val / range * usable_h, 1)
        {x, y}
      end)

    curve_path = build_smooth_path(coords)

    bottom_y = chart_height - pad_bottom
    {first_x, _} = hd(coords)
    {last_x, _} = List.last(coords)
    area_path = "#{curve_path} L #{last_x},#{bottom_y} L #{first_x},#{bottom_y} Z"

    y_labels = build_y_labels(max_val, usable_h, pad_top, unit)

    data_json =
      coords
      |> Enum.zip(data)
      |> Enum.map(fn {{x, y}, val} -> %{x: x, y: y, val: format_value(val, unit)} end)
      |> Jason.encode!()

    summary = build_summary(data, unit)

    {curve_path, area_path, coords, y_labels, data_json, summary}
  end

  defp build_chart_data(
         _data,
         _usable_w,
         _usable_h,
         _pad_left,
         _pad_top,
         _pad_bottom,
         _chart_height,
         _unit
       ) do
    {"", "", [], [], "[]", %{current: nil, min: "-", avg: "-", max: "-"}}
  end

  # -- Smooth cubic bezier path --

  defp build_smooth_path([]), do: ""
  defp build_smooth_path([{x, y}]), do: "M #{x},#{y}"

  defp build_smooth_path(coords) do
    [{x0, y0} | _rest] = coords

    segments =
      coords
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.with_index()
      |> Enum.map(fn {[{x1, y1}, {x2, y2}], i} ->
        # Control point tension
        prev = if i > 0, do: Enum.at(coords, i - 1), else: {x1, y1}
        nxt = if i + 2 < length(coords), do: Enum.at(coords, i + 2), else: {x2, y2}
        {px, py} = prev
        {nx, ny} = nxt

        tension = 0.3
        cp1x = Float.round(x1 + (x2 - px) * tension, 1)
        cp1y = Float.round(y1 + (y2 - py) * tension, 1)
        cp2x = Float.round(x2 - (nx - x1) * tension, 1)
        cp2y = Float.round(y2 - (ny - y1) * tension, 1)

        "C #{cp1x},#{cp1y} #{cp2x},#{cp2y} #{x2},#{y2}"
      end)

    "M #{x0},#{y0} " <> Enum.join(segments, " ")
  end

  # -- Summary stats --

  defp build_summary(data, unit) when length(data) > 0 do
    current = List.last(data)
    min_val = Enum.min(data)
    max_val = Enum.max(data)
    avg_val = Enum.sum(data) / length(data)

    %{
      current: format_value(current, unit),
      min: format_value(min_val, unit),
      max: format_value(max_val, unit),
      avg: format_value(avg_val, unit)
    }
  end

  defp build_summary(_, _), do: %{current: nil, min: "-", avg: "-", max: "-"}

  # -- Y-axis labels --

  defp build_y_labels(max_val, usable_h, pad_top, unit) do
    steps = 4
    top = if max_val == 0, do: 1, else: max_val

    for i <- 0..steps do
      frac = i / steps
      val = top * (1 - frac)
      y = Float.round(pad_top + frac * usable_h, 1)
      %{y: y, label: format_value(val, unit)}
    end
  end

  defp build_grid_lines(y_labels, x_start, x_end) do
    Enum.map(y_labels, fn yl -> %{x1: x_start, x2: x_end, y: yl.y} end)
  end

  # -- Value formatting --

  defp format_value(val, "MB") do
    mb = val / 1_048_576

    cond do
      mb >= 1000 -> "#{Float.round(mb / 1024, 1)} GB"
      mb >= 1 -> "#{Float.round(mb, 1)} MB"
      true -> "#{Float.round(mb * 1024, 0)} KB"
    end
  end

  defp format_value(val, unit) when is_float(val) do
    formatted =
      if val >= 1000, do: "#{Float.round(val / 1000, 1)}k", else: "#{Float.round(val, 1)}"

    if unit != "", do: "#{formatted} #{unit}", else: formatted
  end

  defp format_value(val, unit) when is_integer(val) do
    formatted = if val >= 1000, do: "#{Float.round(val / 1000, 1)}k", else: "#{val}"
    if unit != "", do: "#{formatted} #{unit}", else: formatted
  end

  defp format_value(val, unit) do
    if unit != "", do: "#{val} #{unit}", else: "#{val}"
  end
end
