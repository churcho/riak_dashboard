defmodule RiakDashboardWeb.Components.Dashboard.MetricChart do
  @moduledoc "Full-width interactive area chart with grouped metric and range selectors."

  use Phoenix.Component

  alias Phoenix.LiveView.JS
  import RiakDashboardWeb.CoreComponents, only: [icon: 1]

  @metric_groups [
    %{
      key: "memory",
      label: "Memory",
      metrics: [
        %{key: "memory_total", label: "Total", unit: "MB"},
        %{key: "memory_processes", label: "Procs", unit: "MB"},
        %{key: "memory_ets", label: "ETS", unit: "MB"}
      ]
    },
    %{
      key: "throughput",
      label: "Throughput",
      metrics: [
        %{key: "vnode_gets", label: "VNode Gets", unit: ""},
        %{key: "vnode_puts", label: "VNode Puts", unit: ""},
        %{key: "node_gets", label: "Node Gets", unit: ""},
        %{key: "node_puts", label: "Node Puts", unit: ""}
      ]
    },
    %{
      key: "latency",
      label: "Latency",
      metrics: [
        %{key: "get_latency", label: "Get", unit: "\u00B5s"},
        %{key: "put_latency", label: "Put", unit: "\u00B5s"}
      ]
    },
    %{
      key: "system",
      label: "System",
      metrics: [
        %{key: "processes", label: "Processes", unit: ""},
        %{key: "run_queue", label: "Run Queue", unit: ""},
        %{key: "read_repairs", label: "Read Repairs", unit: ""}
      ]
    }
  ]

  @ranges [
    %{key: "recent", label: "5m", atom: :recent},
    %{key: "hour", label: "1h", atom: :hour},
    %{key: "day", label: "24h", atom: :day},
    %{key: "week", label: "7d", atom: :week}
  ]

  attr :selected_metric, :string, required: true
  attr :selected_metric_group, :string, required: true
  attr :selected_range, :atom, required: true
  attr :data, :list, required: true, doc: "List of numeric values for the selected metric"
  attr :unit, :string, default: ""

  @spec metric_chart(map()) :: Phoenix.LiveView.Rendered.t()
  def metric_chart(assigns) do
    chart_width = 800
    chart_height = 220
    pad_left = 60
    pad_right = 20
    pad_top = 16
    pad_bottom = 32
    usable_w = chart_width - pad_left - pad_right
    usable_h = chart_height - pad_top - pad_bottom

    raw_series = normalize_series(assigns.data)

    plot_data =
      raw_series
      |> reduce_point_density(assigns.selected_range, usable_w)
      |> smooth_series(assigns.selected_range)

    {curve_path, area_path, coords, y_labels, data_json} =
      build_chart_data(
        plot_data,
        usable_w,
        usable_h,
        pad_left,
        pad_top,
        pad_bottom,
        chart_height,
        assigns.unit
      )

    grid_lines = build_grid_lines(y_labels, pad_left, chart_width - pad_right)
    current_metric = find_metric(assigns.selected_metric)

    active_group =
      Enum.find(@metric_groups, &(&1.key == assigns.selected_metric_group)) || hd(@metric_groups)

    {left_range_label, right_range_label} = range_label(assigns.selected_range)

    empty_label =
      if assigns.selected_range == :recent,
        do: "Collecting data...",
        else: "No history for this period"

    assigns =
      assign(assigns,
        metric_groups: @metric_groups,
        ranges: @ranges,
        chart_width: chart_width,
        chart_height: chart_height,
        pad_left: pad_left,
        pad_right: pad_right,
        curve_path: curve_path,
        area_path: area_path,
        coords: coords,
        y_labels: y_labels,
        grid_lines: grid_lines,
        plot_data: plot_data,
        marker_coords: marker_coords(coords, assigns.selected_range),
        data_json: data_json,
        summary: build_summary(values_from_series(raw_series), assigns.unit),
        current_metric: current_metric,
        active_group: active_group,
        left_range_label: left_range_label,
        right_range_label: right_range_label,
        empty_label: empty_label
      )

    ~H"""
    <div class="bg-white rounded-xl border border-[#EEEDEA] p-4 dark:bg-[var(--or-bg-surface)] dark:border-[var(--or-border-base)]">
      <%!-- Row 1: title/value + range pills/clear --%>
      <div class="flex items-start justify-between mb-1 flex-wrap gap-2">
        <div>
          <div class="flex items-baseline gap-3">
            <h3 class="text-xs font-semibold uppercase tracking-wider text-[#8A8A8A] dark:text-[#94A3B8]">
              {metric_title(@current_metric)}
            </h3>
            <span
              :if={@summary.current != nil}
              class="text-2xl font-bold font-heading text-[#1A1A1A] dark:text-[#E2E8F0] tracking-tight leading-none"
            >
              {@summary.current}
            </span>
          </div>

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

        <div class="flex items-center gap-2 flex-wrap justify-end">
          <div class="flex gap-1.5">
            <button
              :for={range <- @ranges}
              type="button"
              phx-click="select_range"
              phx-value-range={range.key}
              class={[
                "px-2 py-1 rounded text-[11px] font-medium transition-all duration-150",
                "focus:outline-none focus-visible:ring-2 focus-visible:ring-[#94A3B8]",
                if(range.atom == @selected_range,
                  do: "bg-[#E9E7E3] text-[#3F3F46] dark:bg-[#334155] dark:text-[#E2E8F0]",
                  else:
                    "border border-[#E5E1DC] text-[#6B6B73] hover:bg-[#F5F3EF] dark:border-[#475569] dark:text-[#94A3B8] dark:hover:bg-[#1F2937]"
                )
              ]}
            >
              {range.label}
            </button>
          </div>

          <button
            type="button"
            phx-click="open_reset_modal"
            class="inline-flex items-center gap-1 px-2 py-1 rounded border border-[#fca5a5]/70 bg-[#fff1f2] text-[11px] font-medium text-[#ef4444] hover:border-[#ef4444] hover:bg-[#fee2e2] transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-[#ef4444]/60 dark:border-[#7f1d1d] dark:bg-[#2a1216] dark:text-[#f87171] dark:hover:bg-[#3f1313]"
          >
            <.icon name="hero-trash-mini" class="size-3.5" /> Clear
          </button>
        </div>
      </div>

      <%!-- Row 2: category tabs + active metrics only --%>
      <div class="mb-3 space-y-2">
        <div class="flex flex-wrap gap-1.5">
          <button
            :for={group <- @metric_groups}
            type="button"
            phx-click="select_metric_group"
            phx-value-group={group.key}
            class={[
              "px-2.5 py-1 rounded text-[10px] uppercase tracking-wider font-medium transition-all duration-200",
              "focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]",
              if(group.key == @selected_metric_group,
                do: "bg-[#1F2937] text-white dark:bg-[#475569]",
                else:
                  "bg-[#F5F3EF] text-[#6B7280] hover:bg-[#EEEDEA] dark:bg-[#334155] dark:text-[#94A3B8] dark:hover:bg-[#3E4C5E]"
              )
            ]}
          >
            {group.label}
          </button>
        </div>

        <div
          id={"metric-group-#{@selected_metric_group}"}
          phx-mounted={JS.remove_class("opacity-0 translate-y-1", time: 220)}
          class="opacity-0 translate-y-1 motion-safe:transition motion-safe:duration-200 motion-safe:ease-out"
        >
          <div class="flex flex-wrap gap-1.5">
            <button
              :for={metric <- @active_group.metrics}
              type="button"
              phx-click="select_metric"
              phx-value-metric={metric.key}
              class={[
                "px-2.5 py-1 rounded text-[11px] font-medium transition-all duration-150",
                "focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]",
                if(metric.key == @selected_metric,
                  do: "bg-[#e77117] text-white",
                  else:
                    "bg-[#F5F3EF] text-[#5A5A5A] hover:bg-[#EEEDEA] dark:bg-[#334155] dark:text-[#94A3B8] dark:hover:bg-[#3E4C5E]"
                )
              ]}
            >
              {metric.label}
            </button>
          </div>
        </div>
      </div>

      <%!-- Row 3: chart --%>
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

          <text
            :if={length(@plot_data) > 1}
            x={@pad_left}
            y={@chart_height - 6}
            text-anchor="start"
            data-metric-axis-start
            class="fill-[#A8A8A8] dark:fill-[#6B7280]"
            font-size="10"
            font-family="Inter, sans-serif"
          >
            {@left_range_label}
          </text>
          <text
            :if={length(@plot_data) > 1}
            x={@chart_width - @pad_right}
            y={@chart_height - 6}
            text-anchor="end"
            data-metric-axis-end
            class="fill-[#A8A8A8] dark:fill-[#6B7280]"
            font-size="10"
            font-family="Inter, sans-serif"
          >
            {@right_range_label}
          </text>

          <path
            :if={@area_path != ""}
            fill="url(#metric-area-gradient)"
            d={@area_path}
          />

          <path
            :if={@curve_path != ""}
            fill="none"
            stroke="#e77117"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            d={@curve_path}
          />

          <circle
            :for={{x, y} <- @marker_coords}
            cx={x}
            cy={y}
            r="2"
            fill="white"
            stroke="#e77117"
            stroke-width="1.5"
            class="dark:fill-[#1F2937]"
          />

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

          <line
            :if={length(@plot_data) <= 1}
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
            :if={length(@plot_data) <= 1}
            x={@chart_width / 2}
            y={@chart_height / 2 - 12}
            text-anchor="middle"
            class="fill-[#A8A8A8] dark:fill-[#6B7280]"
            font-size="12"
            font-family="Inter, sans-serif"
          >
            {@empty_label}
          </text>
        </svg>
      </div>
    </div>
    """
  end

  defp find_metric(metric_key) do
    Enum.find_value(@metric_groups, fn group ->
      case Enum.find(group.metrics, &(&1.key == metric_key)) do
        nil -> nil
        metric -> Map.put(metric, :group, group.label)
      end
    end) || %{label: "Total", group: "Memory"}
  end

  defp metric_title(%{group: group, label: label}), do: String.upcase("#{group} #{label}")

  defp range_label(:recent), do: {"5m ago", "now"}
  defp range_label(:hour), do: {"1h ago", "now"}
  defp range_label(:day), do: {"24h ago", "now"}
  defp range_label(:week), do: {"7d ago", "now"}
  defp range_label(_), do: {"", "now"}

  defp reduce_point_density(data, _range, _usable_w) when length(data) <= 2, do: data

  defp reduce_point_density(data, range, usable_w) do
    target = point_target(range, usable_w)

    if length(data) <= target do
      data
    else
      last_idx = length(data) - 1
      step = (length(data) - 1) / max(target - 1, 1)

      0..(target - 1)
      |> Enum.map(fn i -> min(round(i * step), last_idx) end)
      |> Enum.uniq()
      |> Enum.map(&Enum.at(data, &1))
    end
  end

  defp point_target(:recent, usable_w), do: max(div(trunc(usable_w), 16), 24)
  defp point_target(:hour, usable_w), do: max(div(trunc(usable_w), 13), 28)
  defp point_target(:day, usable_w), do: max(div(trunc(usable_w), 11), 24)
  defp point_target(:week, usable_w), do: max(div(trunc(usable_w), 9), 20)
  defp point_target(_, usable_w), do: max(div(trunc(usable_w), 11), 24)

  defp smooth_series(data, :recent), do: moving_average(data, 2)
  defp smooth_series(data, :hour), do: moving_average(data, 1)
  defp smooth_series(data, _range), do: data

  defp moving_average(data, radius) when radius <= 0 or length(data) <= 2, do: data

  defp moving_average(data, radius) do
    last_idx = length(data) - 1

    data
    |> Enum.with_index()
    |> Enum.map(fn
      {point, 0} ->
        point

      {point, ^last_idx} ->
        point

      {point, idx} ->
        from = max(idx - radius, 0)
        to = min(idx + radius, last_idx)
        window = Enum.slice(data, from..to)
        avg = window |> Enum.map(& &1.value) |> Enum.sum() |> Kernel./(max(length(window), 1))
        %{point | value: avg}
    end)
  end

  defp marker_coords(coords, _range) when length(coords) <= 40, do: coords

  defp marker_coords(coords, range) do
    count = length(coords)
    step = marker_step(range)

    coords
    |> Enum.with_index()
    |> Enum.filter(fn {_coord, idx} ->
      idx == 0 or idx == count - 1 or rem(idx, step) == 0
    end)
    |> Enum.map(&elem(&1, 0))
  end

  defp marker_step(:recent), do: 4
  defp marker_step(:hour), do: 3
  defp marker_step(:day), do: 2
  defp marker_step(_), do: 1

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
    values = values_from_series(data)
    raw_max = Enum.max(values)
    max_val = if raw_max == 0, do: 1, else: raw_max * 1.2
    range = max_val
    idx_step = usable_w / max(length(data) - 1, 1)
    timestamp_bounds = timestamp_bounds(data)

    coords =
      data
      |> Enum.with_index()
      |> Enum.map(fn {point, i} ->
        x =
          case timestamp_bounds do
            {:ok, min_ts, span} when is_integer(point.ts) ->
              Float.round(pad_left + (point.ts - min_ts) / span * usable_w, 1)

            _ ->
              Float.round(pad_left + i * idx_step, 1)
          end

        y = Float.round(pad_top + usable_h - point.value / range * usable_h, 1)
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
      |> Enum.map(fn {{x, y}, point} ->
        %{x: x, y: y, val: format_value(point.value, unit), ts: point.ts}
      end)
      |> Jason.encode!()

    {curve_path, area_path, coords, y_labels, data_json}
  end

  defp build_chart_data(_data, _w, _h, _pl, _pt, _pb, _ch, _unit) do
    {"", "", [], [], "[]"}
  end

  defp build_smooth_path([]), do: ""
  defp build_smooth_path([{x, y}]), do: "M #{x},#{y}"

  defp build_smooth_path(coords) do
    [{x0, y0} | _rest] = coords

    segments =
      coords
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.with_index()
      |> Enum.map(fn {[{x1, y1}, {x2, y2}], i} ->
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

  defp build_summary([], _unit), do: %{current: nil, min: "-", avg: "-", max: "-"}

  defp build_summary(data, unit) do
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

  defp normalize_series(data) do
    data
    |> Enum.map(&normalize_point/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_point(%{value: value} = point) when is_number(value) do
    %{ts: parse_ts(Map.get(point, :ts) || Map.get(point, :timestamp)), value: value}
  end

  defp normalize_point(%{"value" => value} = point) when is_number(value) do
    %{ts: parse_ts(Map.get(point, "ts") || Map.get(point, "timestamp")), value: value}
  end

  defp normalize_point({ts, value}) when is_number(value) do
    %{ts: parse_ts(ts), value: value}
  end

  defp normalize_point(value) when is_number(value) do
    %{ts: nil, value: value}
  end

  defp normalize_point(_), do: nil

  defp parse_ts(ts) when is_integer(ts), do: ts
  defp parse_ts(ts) when is_float(ts), do: trunc(ts)
  defp parse_ts(_), do: nil

  defp values_from_series(series), do: Enum.map(series, & &1.value)

  defp timestamp_bounds(series) do
    timestamps =
      series
      |> Enum.map(& &1.ts)
      |> Enum.reject(&is_nil/1)

    if length(timestamps) == length(series) and length(timestamps) > 1 do
      min_ts = Enum.min(timestamps)
      max_ts = Enum.max(timestamps)
      {:ok, min_ts, max(max_ts - min_ts, 1)}
    else
      :none
    end
  end

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

  defp format_value(val, "MB") do
    mb = val / 1_048_576

    cond do
      mb >= 1000 -> "#{Float.round(mb / 1024, 1)} GB"
      mb >= 1 -> "#{Float.round(mb, 1)} MB"
      true -> "#{Float.round(mb * 1024, 0)} KB"
    end
  end

  defp format_value(val, unit) when is_number(val) do
    formatted =
      cond do
        val >= 1000 -> "#{Float.round(val / 1000, 1)}k"
        is_float(val) -> "#{Float.round(val, 1)}"
        true -> "#{val}"
      end

    append_unit(formatted, unit)
  end

  defp format_value(val, unit), do: append_unit("#{val}", unit)

  defp append_unit(formatted, ""), do: formatted
  defp append_unit(formatted, unit), do: "#{formatted} #{unit}"
end
