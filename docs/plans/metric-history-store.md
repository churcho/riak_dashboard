# Metric History Store — Implementation Prompt

## Problem

The cluster dashboard chart holds only ~30 data points per node in LiveView process memory (`sparkline_history` assign). Data only accumulates while the page is open and is lost on navigation or restart. This limits the chart to ~30 seconds — useless for spotting trends.

## Goal

Persist 7 days of per-node metric history to disk via DETS. Expand from 7 to 13 tracked metrics. Provide time range switching (5m, 1h, 24h, 7d) in the chart UI. Reorganize the metric pills into grouped categories to keep the UI clean. Support deleting individual node history and full reset.

---

## Part 1: MetricStore GenServer with DETS

### Data Shape — 13 Metrics Per Point

Each WebSocket push for `node_stats` delivers raw stats per node. Extract these 13 fields:

```elixir
%{
  # Memory (3)
  memory_total: integer(),       # bytes — from erlang.memory.total or erlang.memory_total_mb * 1048576
  memory_processes: integer(),   # bytes — from erlang.memory.processes or erlang.memory_processes_mb * 1048576
  memory_ets: integer(),         # bytes — from erlang.memory.ets or erlang.memory_ets_mb * 1048576

  # Throughput (4)
  vnode_gets: integer(),         # from kv.vnode_gets
  vnode_puts: integer(),         # from kv.vnode_puts
  node_gets: integer(),          # from kv.node_gets
  node_puts: integer(),          # from kv.node_puts

  # Latency (2)
  get_latency: integer(),        # µs — from kv.node_get_fsm_time_mean
  put_latency: integer(),        # µs — from kv.node_put_fsm_time_mean

  # System (4)
  processes: integer(),          # from erlang.process_count
  run_queue: integer(),          # from erlang.run_queue
  read_repairs: integer(),       # from kv.read_repairs
  # Future slot: scheduler_utilization if Riak exposes it
}
```

**Per-point size:** 13 × 8 bytes + 8-byte timestamp = ~112 bytes.

### Downsampling Tiers

| Tier    | Resolution | Max points/node | Duration | Disk/node |
|---------|-----------|-----------------|----------|-----------|
| Recent  | 1s        | 300             | 5 min    | 33 KB     |
| Medium  | 10s avg   | 360             | 1 hour   | 39 KB     |
| Long    | 60s avg   | 1,440           | 24 hours | 157 KB    |
| Weekly  | 5min avg  | 2,016           | 7 days   | 220 KB    |
| **Total** |         | **4,116**       |          | **449 KB** |

5 nodes = **2.2 MB**. 20 nodes = **9 MB**. Well within DETS 2 GB limit.

### Files to Create

**`lib/riak_dashboard/metric_store.ex`** — GenServer with DETS backing.

```elixir
defmodule RiakDashboard.MetricStore do
  use GenServer

  # --- Public API ---

  def start_link(opts \\ [])
  # Start the GenServer. Opens/creates DETS file.

  def record(node_stats_map)
  # GenServer.cast — called by ClusterLive on every WS push.
  # node_stats_map is the raw map: %{"dev1@..." => %{"kv" => ..., "erlang" => ...}}
  # The GenServer extracts the 13 metrics internally.

  def query(node_name, range)
  # GenServer.call — returns [{unix_timestamp, %{memory_total: n, ...}}, ...]
  # range: :recent | :hour | :day | :week
  # Results sorted oldest → newest.

  def nodes()
  # Returns list of node names that have history.

  def delete_node(node_name)
  # GenServer.cast — removes from in-memory recent + all DETS tiers.

  def reset()
  # GenServer.cast — clears everything. :dets.delete_all_objects + empty recent map.

  # --- GenServer internals ---

  # State: %{table: dets_ref, recent: %{node => :queue.new()}, compact_counter: 0}
  #
  # Recent tier lives in process memory (hot path, no disk I/O on every 1s push).
  # Medium/long/weekly tiers persist to DETS on compaction schedule.
  #
  # DETS key schema: {node_name, tier_atom} => list of {timestamp, metrics_map}
  # e.g. {"dev1@127.0.0.1", :medium} => [{1708000000, %{memory_total: 123, ...}}, ...]
  #
  # DETS file location: Application.app_dir(:riak_dashboard, "priv/data/metric_store.dets")
  # Create priv/data/ on init if it doesn't exist.
  #
  # Compaction timer: Process.send_after(self(), :compact, 10_000)
  #   Every 10s: average last 10 recent → 1 medium point, write to DETS, trim to 360
  #   Every 60s (counter rem 6 == 0): average last 6 medium → 1 long point, write, trim to 1440
  #   Every 5min (counter rem 30 == 0): average last 5 long → 1 weekly point, write, trim to 2016
  #
  # terminate/2: call :dets.close(table)

  # --- Metric extraction helper ---

  # Extract the 13 metrics from the raw stats map for one node:
  defp extract_metrics(raw_stats) do
    erlang = raw_stats["erlang"] || %{}
    kv = raw_stats["kv"] || %{}

    %{
      memory_total: extract_memory_bytes(erlang),
      memory_processes: extract_memory_field(erlang, "processes", "memory_processes_mb"),
      memory_ets: extract_memory_field(erlang, "ets", "memory_ets_mb"),
      vnode_gets: kv["vnode_gets"] || 0,
      vnode_puts: kv["vnode_puts"] || 0,
      node_gets: kv["node_gets"] || 0,
      node_puts: kv["node_puts"] || 0,
      get_latency: kv["node_get_fsm_time_mean"] || 0,
      put_latency: kv["node_put_fsm_time_mean"] || 0,
      processes: erlang["process_count"] || 0,
      run_queue: erlang["run_queue"] || 0,
      read_repairs: kv["read_repairs"] || 0
    }
  end

  # Handle both formats: erlang.memory.total (bytes) and erlang.memory_total_mb (MB)
  defp extract_memory_bytes(erlang) do
    cond do
      is_number(erlang["memory_total_mb"]) -> round(erlang["memory_total_mb"] * 1_048_576)
      is_number(get_in(erlang, ["memory", "total"])) -> erlang["memory"]["total"]
      is_number(erlang["memory_total"]) -> erlang["memory_total"]
      true -> 0
    end
  end

  defp extract_memory_field(erlang, nested_key, mb_key) do
    cond do
      is_number(erlang[mb_key]) -> round(erlang[mb_key] * 1_048_576)
      is_number(get_in(erlang, ["memory", nested_key])) -> erlang["memory"][nested_key]
      true -> 0
    end
  end
end
```

**`test/riak_dashboard/metric_store_test.exs`** — unit tests:

```elixir
describe "record/1" do
  test "stores points for new nodes in recent tier"
  test "extracts all 13 metrics correctly"
  test "trims recent tier to 300 points"
  test "handles multiple nodes in a single push"
end

describe "query/2" do
  test "returns recent points for :recent range"
  test "returns medium points for :hour range"
  test "returns long points for :day range"
  test "returns weekly points for :week range"
  test "returns empty list for unknown node"
  test "results sorted oldest to newest"
end

describe "compaction" do
  test "averages recent → medium tier every 10s"
  test "averages medium → long tier every 60s"
  test "averages long → weekly tier every 5min"
  test "persists medium/long/weekly to DETS"
  test "trims each tier to its max size"
end

describe "delete_node/1" do
  test "removes node from recent and all DETS tiers"
  test "does not affect other nodes"
end

describe "reset/0" do
  test "clears all in-memory and DETS data"
end

describe "persistence" do
  test "data survives GenServer restart"
  test "recent tier is empty after restart"
  test "medium/long/weekly available immediately after restart"
end
```

**`priv/data/.gitkeep`** — ensure directory exists in repo.

### Files to Modify

**`lib/riak_dashboard/application.ex`** — add `RiakDashboard.MetricStore` before `Endpoint`:

```elixir
children = [
  RiakDashboardWeb.Telemetry,
  {DNSCluster, query: ...},
  {Phoenix.PubSub, name: RiakDashboard.PubSub},
  RiakDashboard.MetricStore,           # <-- add here
  RiakDashboardWeb.Endpoint
]
```

**`.gitignore`** — add:

```
priv/data/*.dets
```

---

## Part 2: ClusterLive Integration

**File:** `lib/riak_dashboard_web/live/cluster_live.ex`

### Remove

- `@sparkline_max_points` constant
- `sparkline_history` assign from mount
- `update_sparkline_history/2` private function
- `extract_memory_bytes/1` private function (moves into MetricStore)
- `chart_data_for/3` private function

### Add to mount assigns

```elixir
selected_range: :recent
```

### Modify `handle_event("riak_node_stats", data, socket)`

```elixir
def handle_event("riak_node_stats", data, socket) do
  MetricStore.record(data)
  Phoenix.PubSub.broadcast(RiakDashboard.PubSub, "metrics:updated", :ok)
  {:noreply, assign(socket, node_stats: data)}
end
```

No more `sparkline_history` update. The MetricStore owns all history now.

### Add new event handlers

```elixir
def handle_event("select_range", %{"range" => range}, socket) do
  range_atom = String.to_existing_atom(range)
  {:noreply, assign(socket, selected_range: range_atom)}
end

def handle_event("delete_node_history", %{"node" => name}, socket) do
  MetricStore.delete_node(name)
  {:noreply, socket}
end

def handle_event("reset_metrics", _, socket) do
  MetricStore.reset()
  {:noreply, socket}
end
```

### Subscribe to PubSub

In `mount/3`, when `connected?(socket)`:

```elixir
if connected?(socket) do
  Phoenix.PubSub.subscribe(RiakDashboard.PubSub, "metrics:updated")
end
```

Add handler:

```elixir
def handle_info(:ok, socket) do
  # PubSub broadcast — re-query chart data for current node+range
  {:noreply, socket}
end
```

### Replace chart data helper

```elixir
defp chart_data_for_range(node, metric_key, range) do
  node
  |> MetricStore.query(range)
  |> Enum.map(fn {_ts, metrics} -> Map.get(metrics, String.to_existing_atom(metric_key), 0) end)
end
```

### Update render

Pass `selected_range` to the metric chart component:

```elixir
<.metric_chart
  selected_metric={@selected_metric}
  selected_range={@selected_range}
  data={chart_data_for_range(@selected_node, @selected_metric, @selected_range)}
  unit={metric_unit(@selected_metric)}
/>
```

### Update `metric_unit/1`

Add units for new metrics:

```elixir
defp metric_unit("memory_total"), do: "MB"
defp metric_unit("memory_processes"), do: "MB"
defp metric_unit("memory_ets"), do: "MB"
defp metric_unit("node_gets"), do: ""
defp metric_unit("node_puts"), do: ""
defp metric_unit("run_queue"), do: ""
# existing ones stay the same
```

---

## Part 3: Metric Chart UX Rebuild

**File:** `lib/riak_dashboard_web/components/dashboard/metric_chart.ex`

### New `@metrics` — Grouped by Category

Replace the flat `@metrics` list with grouped categories:

```elixir
@metric_groups [
  %{
    label: "Memory",
    metrics: [
      %{key: "memory_total", label: "Total", unit: "MB"},
      %{key: "memory_processes", label: "Procs", unit: "MB"},
      %{key: "memory_ets", label: "ETS", unit: "MB"}
    ]
  },
  %{
    label: "Throughput",
    metrics: [
      %{key: "vnode_gets", label: "VNode Gets", unit: ""},
      %{key: "vnode_puts", label: "VNode Puts", unit: ""},
      %{key: "node_gets", label: "Node Gets", unit: ""},
      %{key: "node_puts", label: "Node Puts", unit: ""}
    ]
  },
  %{
    label: "Latency",
    metrics: [
      %{key: "get_latency", label: "Get", unit: "µs"},
      %{key: "put_latency", label: "Put", unit: "µs"}
    ]
  },
  %{
    label: "System",
    metrics: [
      %{key: "processes", label: "Processes", unit: ""},
      %{key: "run_queue", label: "Run Queue", unit: ""},
      %{key: "read_repairs", label: "Read Repairs", unit: ""}
    ]
  }
]
```

### New Attrs

```elixir
attr :selected_metric, :string, required: true
attr :selected_range, :atom, required: true   # <-- NEW
attr :data, :list, required: true
attr :unit, :string, default: ""
```

### Chart Header Layout

The chart header area should be reorganized into three rows:

**Row 1 — Title + Value + Time Range Pills (right-aligned) + Reset**

```
MEMORY TOTAL  65.0 MB                          [5m] [1h] [24h] [7d]  [Reset]
Min 62.0 MB   Avg 64.5 MB   Max 65.0 MB
```

Time range pills: "5m", "1h", "24h", "7d". Same pill styling as metric pills but smaller or in a
distinct outline style so they don't compete visually. Active range pill uses a different accent
color (e.g. subtle gray fill instead of brand orange) to distinguish from the metric selection.

Each fires `phx-click="select_range"` with `phx-value-range="recent|hour|day|week"`.

Reset button: small text button, muted color, right of the range pills. Shows `data-confirm="Clear all metric history?"` for safety. Fires `phx-click="reset_metrics"`.

**Row 2 — Grouped Metric Pills**

Render as inline groups with a tiny category label:

```
Memory: [Total] [Procs] [ETS]   Throughput: [VNode Gets] [VNode Puts] [Node Gets] [Node Puts]
Latency: [Get] [Put]   System: [Processes] [Run Queue] [Read Repairs]
```

Each group label is `text-[10px] uppercase tracking-wider text-[#A8A8A8]` (same style as nav
section labels). Pills within each group use the existing orange active / gray inactive styling.

Use `flex flex-wrap` so on small screens the groups stack naturally. Groups are separated by a
slightly larger gap (`gap-x-5`) while pills within a group have the existing tight gap (`gap-1.5`).

**Row 3 — Chart SVG (unchanged)**

### Time Axis Labels

Update left/right time labels dynamically based on `selected_range`:

```elixir
defp range_label(:recent), do: {"5m ago", "now"}
defp range_label(:hour), do: {"1h ago", "now"}
defp range_label(:day), do: {"24h ago", "now"}
defp range_label(:week), do: {"7d ago", "now"}
```

### Empty State

When `data` is empty:
- If `selected_range == :recent` → show "Collecting data..." (existing behavior)
- If `selected_range != :recent` → show "No history for this period" centered in the chart area

---

## Part 4: Node Chip History Management

**File:** `lib/riak_dashboard_web/components/dashboard/node_chips.ex`

Add a small clear-history button on each node card:

- Position: top-right corner of the card, overlapping the border slightly
- Icon: `hero-x-mark-micro` or `hero-trash-micro`, size-3
- Visibility: `opacity-0 group-hover:opacity-40 hover:!opacity-100` — hidden until card hover
- Add `group` class to the card's outer div to enable group-hover
- Fires `phx-click="delete_node_history"` with `phx-value-node={node["name"]}`
- Add `data-confirm={"Clear metric history for #{short_name}?"}` for safety

---

## Part 5: Migration Path

The existing `sparkline_history` and `update_sparkline_history/2` in ClusterLive are **completely replaced** — not kept alongside. The MetricStore's `:recent` tier serves the same purpose (last 5 min of data) and reads from in-memory state, so there's no performance regression.

The old `memory` metric key becomes `memory_total`. Update the default `selected_metric` in mount from `"memory"` to `"memory_total"`.

---

## File Changes Summary

| Action | File | What |
|--------|------|------|
| **Create** | `lib/riak_dashboard/metric_store.ex` | GenServer + DETS, record/query/compact/delete/reset |
| **Create** | `test/riak_dashboard/metric_store_test.exs` | Unit tests |
| **Create** | `priv/data/.gitkeep` | Ensure data directory exists |
| **Modify** | `lib/riak_dashboard/application.ex` | Add MetricStore to supervision tree |
| **Modify** | `lib/riak_dashboard_web/live/cluster_live.ex` | Remove sparkline_history, integrate MetricStore, add range/delete/reset events, PubSub |
| **Modify** | `lib/riak_dashboard_web/components/dashboard/metric_chart.ex` | Grouped metric pills, range pills, reset button, dynamic time labels, empty states |
| **Modify** | `lib/riak_dashboard_web/components/dashboard/node_chips.ex` | Add per-node clear history button |
| **Modify** | `.gitignore` | Add `priv/data/*.dets` |

---

## Verification

1. `mix compile` — no warnings
2. `mix test test/riak_dashboard/metric_store_test.exs` — all pass
3. Visual check with `agent-browser` on port 4000:
   - Grouped metric pills render in categories with labels
   - Range pills (5m, 1h, 24h, 7d) appear and switch the chart view
   - "5m" is active by default and chart updates live
   - Clicking "1h" shows "No history for this period" initially
   - After accumulating data, switching ranges shows different resolutions
   - Reset button shows confirmation dialog, clears chart
   - Node chip trash icons appear on card hover
   - Dark mode renders correctly for all new elements
4. `agent-browser errors` — no JS console errors
5. Restart the server (`mix phx.server`), reopen dashboard — verify 1h/24h/7d data persists while 5m view starts fresh

---

## Sequence Diagram

```
Server starts
  MetricStore.init()
    → File.mkdir_p!(priv/data/)
    → :dets.open_file(metric_store.dets)
    → schedule_compact() (10s timer)
    → Recent tier empty, medium/long/weekly loaded from DETS

User opens dashboard
  ClusterLive.mount()
    → MetricStore.query(node, :recent)     # may return [] on cold start
    → PubSub.subscribe("metrics:updated")
    → Assign chart data + selected_range: :recent

Every ~1s (WebSocket push):
  ClusterLive.handle_event("riak_node_stats", data)
    → MetricStore.record(data)             # cast — 13 metrics extracted, appended to recent queue
    → PubSub.broadcast("metrics:updated")
    → LiveView re-queries MetricStore for current range
    → Chart re-renders

Every 10s (GenServer :compact):
  Average last 10 recent → 1 medium point → write DETS

Every 60s (compact_counter rem 6 == 0):
  Average last 6 medium → 1 long point → write DETS

Every 5min (compact_counter rem 30 == 0):
  Average last 5 long → 1 weekly point → write DETS

User clicks "7d" range pill:
  handle_event("select_range", %{"range" => "week"})
    → MetricStore.query(node, :week)       # reads from DETS
    → Chart re-renders with 2,016 points over 7 days

User clicks "Memory > ETS" metric pill:
  handle_event("select_metric", %{"metric" => "memory_ets"})
    → Re-query MetricStore, extract memory_ets from each point
    → Chart switches to ETS memory view

User clicks trash icon on node chip:
  handle_event("delete_node_history", %{"node" => "dev3@..."})
    → MetricStore.delete_node("dev3@...")
    → Node's history cleared from memory + DETS

User clicks Reset button:
  handle_event("reset_metrics", _)
    → MetricStore.reset()
    → All history cleared, chart shows "Collecting data..."

Server crashes / restarts:
  MetricStore.init() re-opens existing DETS file
    → medium/long/weekly data intact on disk
    → recent tier empty (refills in ~5 minutes)
    → User sees no gap in 1h/24h/7d views
```
