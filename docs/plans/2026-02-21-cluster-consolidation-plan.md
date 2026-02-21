# Consolidated Cluster Dashboard Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Merge Ring, AAE Exchange, and Handoff pages into a single consolidated cluster dashboard with sparkline node performance, ring donut chart, and compact node chips.

**Architecture:** Extend ClusterLive to subscribe to five WebSocket topics (cluster, node_stats, ring, aae, handoff). Build four new function components: sparkline SVG, node chips, node performance panel, ring panel. Remove three LiveView modules and their routes. Add redirects.

**Tech Stack:** Phoenix LiveView 1.0, HEEx templates, pure SVG sparklines (no chart library), existing RingChart canvas JS hook, Tailwind CSS with OpenRiak design tokens.

---

### Task 1: Sparkline SVG Component

The lowest-level building block. A pure function component that renders an SVG polyline from a list of numbers.

**Files:**
- Create: `lib/riak_dashboard_web/components/dashboard/sparkline.ex`

**Step 1: Create the sparkline component**

```elixir
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
```

**Step 2: Verify it compiles**

Run: `mix compile --warnings-as-errors`
Expected: Compilation successful, 0 warnings

**Step 3: Commit**

```bash
git add lib/riak_dashboard_web/components/dashboard/sparkline.ex
git commit -m "Add pure SVG sparkline component"
```

---

### Task 2: Node Chips Component

Compact horizontal node list with click-to-select behavior.

**Files:**
- Create: `lib/riak_dashboard_web/components/dashboard/node_chips.ex`

**Step 1: Create the node chips component**

```elixir
defmodule RiakDashboardWeb.Components.Dashboard.NodeChips do
  @moduledoc "Compact horizontal node list with status dots and click-to-select."

  use Phoenix.Component

  import RiakDashboardWeb.CoreComponents, only: [badge: 1]

  attr :nodes, :list, required: true, doc: "List of node maps from cluster data"
  attr :selected_node, :string, default: nil, doc: "Currently selected node name"

  def node_chips(assigns) do
    ~H"""
    <div class="flex flex-wrap gap-2">
      <button
        :for={node <- @nodes}
        type="button"
        phx-click="select_node"
        phx-value-node={node["name"]}
        class={[
          "flex items-center gap-2 px-3 py-1.5 rounded-lg border text-xs font-mono transition-all duration-150",
          "hover:border-[#e77117]/40 focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]",
          if(node["name"] == @selected_node,
            do:
              "border-[#e77117] bg-[#e77117]/5 ring-1 ring-[#e77117]/30 dark:bg-[#e77117]/10",
            else:
              "border-[#EEEDEA] bg-white dark:border-[#334155] dark:bg-[var(--or-bg-surface)]"
          )
        ]}
      >
        <span class={[
          "w-2 h-2 rounded-full shrink-0",
          if(node["reachable"], do: "bg-green-500", else: "bg-red-500")
        ]} />
        <span class="text-[#1A1A1A] dark:text-[#E2E8F0]">
          {node["name"]}
        </span>
        <.badge variant={node_status_variant(node["status"])}>
          {String.upcase(node["status"] || "unknown")}
        </.badge>
      </button>
    </div>
    """
  end

  defp node_status_variant("valid"), do: :success
  defp node_status_variant("leaving"), do: :warning
  defp node_status_variant("exiting"), do: :warning
  defp node_status_variant("joining"), do: :info
  defp node_status_variant("down"), do: :error
  defp node_status_variant(_), do: :info
end
```

**Step 2: Verify it compiles**

Run: `mix compile --warnings-as-errors`
Expected: Compilation successful

**Step 3: Commit**

```bash
git add lib/riak_dashboard_web/components/dashboard/node_chips.ex
git commit -m "Add compact node chips component with click-to-select"
```

---

### Task 3: Node Performance Panel Component

Left panel with node selector dropdown and sparkline rows.

**Files:**
- Create: `lib/riak_dashboard_web/components/dashboard/node_performance.ex`

**Step 1: Create the node performance panel**

```elixir
defmodule RiakDashboardWeb.Components.Dashboard.NodePerformance do
  @moduledoc "Node performance panel with dropdown selector and sparkline metric rows."

  use Phoenix.Component

  import RiakDashboardWeb.Components.Dashboard.Sparkline
  import RiakDashboardWeb.Formatters

  @metrics [
    %{key: :vnode_gets, label: "VNode Gets", path: ["kv", "vnode_gets"], unit: ""},
    %{key: :vnode_puts, label: "VNode Puts", path: ["kv", "vnode_puts"], unit: ""},
    %{key: :memory, label: "Memory", path: ["erlang", "memory_total"], unit: "MB", format: :memory},
    %{key: :processes, label: "Processes", path: ["erlang", "process_count"], unit: ""},
    %{key: :get_latency, label: "Get Latency", path: ["kv", "node_get_fsm_time_mean"], unit: "\u00B5s"},
    %{key: :put_latency, label: "Put Latency", path: ["kv", "node_put_fsm_time_mean"], unit: "\u00B5s"},
    %{key: :read_repairs, label: "Read Repairs", path: ["kv", "read_repairs"], unit: ""}
  ]

  attr :nodes, :list, required: true, doc: "List of node maps (for dropdown)"
  attr :selected_node, :string, default: nil
  attr :node_stats, :map, default: %{}, doc: "Current node stats keyed by name"
  attr :sparkline_history, :map, default: %{}, doc: "Historical data per node"

  def node_performance(assigns) do
    assigns = assign(assigns, :metrics, @metrics)

    ~H"""
    <div class="bg-white rounded-xl border border-[#EEEDEA] p-4 dark:bg-[var(--or-bg-surface)] dark:border-[var(--or-border-base)]">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-xs font-semibold uppercase tracking-wider text-[#8A8A8A] dark:text-[#94A3B8]">
          Node Performance
        </h3>
        <form phx-change="select_node" class="m-0">
          <select
            name="node"
            class="text-xs border border-[#EEEDEA] rounded-lg px-2 py-1 bg-white text-[#1A1A1A] dark:bg-[var(--or-bg-surface)] dark:border-[var(--or-border-base)] dark:text-[var(--or-fg-base)] focus:ring-1 focus:ring-[#e77117] focus:border-[#e77117]"
          >
            <option
              :for={node <- @nodes}
              value={node["name"]}
              selected={node["name"] == @selected_node}
            >
              {node["name"]}
            </option>
          </select>
        </form>
      </div>

      <div :if={@selected_node == nil} class="py-8 text-center text-sm text-[#A8A8A8] dark:text-[#6B7280]">
        Select a node to view performance metrics
      </div>

      <div :if={@selected_node} class="space-y-1">
        <.metric_row
          :for={metric <- @metrics}
          metric={metric}
          history={get_metric_history(@sparkline_history, @selected_node, metric.key)}
          current={get_current_value(@node_stats, @selected_node, metric)}
        />
      </div>
    </div>
    """
  end

  attr :metric, :map, required: true
  attr :history, :list, required: true
  attr :current, :string, required: true

  defp metric_row(assigns) do
    ~H"""
    <div class="flex items-center gap-3 py-1.5 border-b border-[#F5F3EF] last:border-0 dark:border-[#334155]">
      <span class="w-24 text-xs text-[#8A8A8A] dark:text-[#94A3B8] shrink-0">
        {@metric.label}
      </span>
      <div class="flex-1 h-6">
        <.sparkline data={@history} width={120} height={24} class="w-full h-full" />
      </div>
      <span class="w-20 text-right text-xs font-semibold text-[#1A1A1A] dark:text-[var(--or-fg-base)] tabular-nums shrink-0">
        {@current}
      </span>
    </div>
    """
  end

  defp get_metric_history(sparkline_history, node, metric_key) do
    sparkline_history
    |> Map.get(node, [])
    |> Enum.map(&Map.get(&1, metric_key, 0))
  end

  defp get_current_value(node_stats, node, %{path: [section, key], format: :memory}) do
    case get_in(node_stats, [node, section]) do
      nil -> "-"
      erlang_stats -> "#{memory_total_mb(erlang_stats)} MB"
    end
  end

  defp get_current_value(node_stats, node, %{path: [section, key], unit: unit}) do
    case get_in(node_stats, [node, section, key]) do
      nil -> "-"
      val -> "#{val}#{if unit != "", do: " #{unit}", else: ""}"
    end
  end
end
```

**Step 2: Verify it compiles**

Run: `mix compile --warnings-as-errors`
Expected: Compilation successful

**Step 3: Commit**

```bash
git add lib/riak_dashboard_web/components/dashboard/node_performance.ex
git commit -m "Add node performance panel with sparkline metrics"
```

---

### Task 4: Ring Panel Component

Right panel extracted from ring_live.ex — donut chart + node distribution table.

**Files:**
- Create: `lib/riak_dashboard_web/components/dashboard/ring_panel.ex`

**Step 1: Create the ring panel component**

This extracts the ring chart and distribution table from `ring_live.ex` into a reusable component.

```elixir
defmodule RiakDashboardWeb.Components.Dashboard.RingPanel do
  @moduledoc "Ring distribution panel with donut chart and node partition table."

  use Phoenix.Component

  import RiakDashboardWeb.Components.Dashboard.RingChart

  attr :ring, :map, default: nil, doc: "Ring data from WebSocket"
  attr :node_dist, :list, default: [], doc: "Computed node distribution list"

  def ring_panel(assigns) do
    ~H"""
    <div class="bg-white rounded-xl border border-[#EEEDEA] p-4 dark:bg-[var(--or-bg-surface)] dark:border-[var(--or-border-base)]">
      <h3 class="text-xs font-semibold uppercase tracking-wider text-[#8A8A8A] dark:text-[#94A3B8] mb-4">
        Ring Distribution
      </h3>

      <div :if={@ring == nil} class="py-8 text-center text-sm text-[#A8A8A8] dark:text-[#6B7280]">
        Waiting for ring data...
      </div>

      <div :if={@ring}>
        <div class="flex justify-center mb-4">
          <.ring_chart ring={@ring} />
        </div>

        <table class="w-full text-xs">
          <thead>
            <tr class="text-[#8A8A8A] dark:text-[#94A3B8]">
              <th class="text-left py-1.5 font-medium">Node</th>
              <th class="text-right py-1.5 font-medium">Parts</th>
              <th class="text-right py-1.5 font-medium">Ring %</th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={dist <- @node_dist}
              class="border-t border-[#F5F3EF] dark:border-[#334155]"
            >
              <td class="py-1.5 flex items-center gap-1.5 text-[#1A1A1A] dark:text-[#E2E8F0]">
                <span
                  class="inline-block w-2.5 h-2.5 rounded-sm shrink-0"
                  style={"background-color: #{dist.color};"}
                />
                <span class="font-mono truncate">{dist.node}</span>
              </td>
              <td class="py-1.5 text-right text-[#1A1A1A] dark:text-[#E2E8F0] tabular-nums">
                {dist.count}
              </td>
              <td class="py-1.5 text-right text-[#8A8A8A] dark:text-[#94A3B8] tabular-nums">
                {dist.pct}%
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end
end
```

**Step 2: Verify it compiles**

Run: `mix compile --warnings-as-errors`
Expected: Compilation successful

**Step 3: Commit**

```bash
git add lib/riak_dashboard_web/components/dashboard/ring_panel.ex
git commit -m "Add ring distribution panel component"
```

---

### Task 5: Update ClusterLive — Data Layer

Add new WebSocket topic subscriptions, sparkline accumulation, and event handlers to ClusterLive.

**Files:**
- Modify: `lib/riak_dashboard_web/live/cluster_live.ex`

**Step 1: Update imports and mount assigns**

Add to the top of `cluster_live.ex` (after existing imports):

```elixir
import RiakDashboardWeb.Components.Dashboard.NodeChips
import RiakDashboardWeb.Components.Dashboard.NodePerformance
import RiakDashboardWeb.Components.Dashboard.RingPanel
import RiakDashboardWeb.Components.Dashboard.Connection
```

Update `mount/3` to add new assigns:

Replace the `topics_json` line to subscribe to all five topics:
```elixir
topics_json: Jason.encode!(~w(cluster node_stats ring aae handoff))
```

Add new assigns after existing ones:
```elixir
ring: nil,
node_dist: [],
aae_count: 0,
handoff_count: 0,
selected_node: nil,
sparkline_history: %{}
```

**Step 2: Add new event handlers**

Add these handler functions in `cluster_live.ex` after the existing `handle_event("riak_dcs", ...)`:

```elixir
def handle_event("riak_ring", data, socket) when is_map(data) do
  {:noreply, assign(socket, ring: data, node_dist: node_distribution(data))}
end

def handle_event("riak_aae", data, socket) when is_map(data) do
  {:noreply, assign(socket, aae_count: data["count"] || 0)}
end

def handle_event("riak_handoff", data, socket) when is_map(data) do
  {:noreply, assign(socket, handoff_count: data["count"] || 0)}
end
```

**Step 3: Update the node_stats handler to accumulate sparkline history**

Replace the existing `handle_event("riak_node_stats", ...)`:

```elixir
def handle_event("riak_node_stats", data, socket) do
  history = update_sparkline_history(socket.assigns.sparkline_history, data)

  selected =
    socket.assigns.selected_node ||
      (socket.assigns.cluster && socket.assigns.cluster["nodes"] |> List.first() |> Access.get("name"))

  {:noreply, assign(socket, node_stats: data, sparkline_history: history, selected_node: selected)}
end
```

**Step 4: Add select_node event handler**

```elixir
def handle_event("select_node", %{"node" => node_name}, socket) do
  {:noreply, assign(socket, selected_node: node_name)}
end
```

**Step 5: Add private helper functions**

Add the `node_distribution/1` function (extracted from `ring_live.ex`):

```elixir
@sparkline_max_points 30
@node_color_palette ["#e77117", "#63819b", "#27d7b9", "#2d80d1", "#d12d2d", "#e39e1b", "#2cd284"]

defp node_distribution(ring) do
  counts = Enum.frequencies_by(ring["partitions"], & &1["node"])
  total = length(ring["partitions"])
  colors = ring["node_colors"]

  counts
  |> Enum.sort_by(fn {node, _count} -> node end)
  |> Enum.map(fn {node, count} ->
    color_idx = Map.get(colors, node, 0)

    %{
      node: node,
      color: Enum.at(@node_color_palette, rem(color_idx, length(@node_color_palette))),
      count: count,
      pct: Float.round(count / total * 100, 1)
    }
  end)
end

defp update_sparkline_history(history, node_stats_data) do
  Enum.reduce(node_stats_data, history, fn {node_name, stats}, acc ->
    point = %{
      vnode_gets: get_in(stats, ["kv", "vnode_gets"]) || 0,
      vnode_puts: get_in(stats, ["kv", "vnode_puts"]) || 0,
      memory: get_in(stats, ["erlang", "memory_total"]) || 0,
      processes: get_in(stats, ["erlang", "process_count"]) || 0,
      get_latency: get_in(stats, ["kv", "node_get_fsm_time_mean"]) || 0,
      put_latency: get_in(stats, ["kv", "node_put_fsm_time_mean"]) || 0,
      read_repairs: get_in(stats, ["kv", "read_repairs"]) || 0
    }

    existing = Map.get(acc, node_name, [])
    updated = Enum.take(existing ++ [point], -@sparkline_max_points)
    Map.put(acc, node_name, updated)
  end)
end
```

**Step 6: Update `select_cluster` handler to reset new assigns**

In the existing `handle_event("select_cluster", ...)`, add the new assigns to the reset:

```elixir
ring: nil,
node_dist: [],
aae_count: 0,
handoff_count: 0,
selected_node: nil,
sparkline_history: %{}
```

**Step 7: Verify it compiles**

Run: `mix compile --warnings-as-errors`
Expected: Compilation successful

**Step 8: Commit**

```bash
git add lib/riak_dashboard_web/live/cluster_live.ex
git commit -m "Add ring, AAE, handoff topics and sparkline accumulation to ClusterLive"
```

---

### Task 6: Update ClusterLive — Render Template

Replace the render function with the new consolidated layout.

**Files:**
- Modify: `lib/riak_dashboard_web/live/cluster_live.ex` (render function)

**Step 1: Replace the render function**

Replace the entire `render/1` function in `cluster_live.ex`:

```elixir
@impl true
def render(assigns) do
  ~H"""
  <div
    id="riak-events"
    phx-hook="RiakEvents"
    data-ws-url={@ws_url}
    data-topics={@topics_json}
  >
    <div class="flex items-center justify-end flex-wrap gap-3 mb-6">
      <.connection_indicator status={@ws_status} />
    </div>

    <.loading_text :if={@loading} label="Loading cluster data..." />

    <%= if @cluster do %>
      <%!-- Section 1: Summary Cards --%>
      <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3 mb-6">
        <.stat_card
          title="Cluster"
          value={@cluster["cluster_name"]}
          subtitle={"Claimant: #{@cluster["claimant"]}"}
          tooltip={"#{@cluster["cluster_name"]}\nClaimant: #{@cluster["claimant"]}"}
          icon="dashboard"
        />
        <.stat_card
          title="Ring"
          value={@cluster["ring_size"]}
          subtitle={"#{if @ring, do: length(@ring["partitions"]), else: @cluster["ring_size"]} partitions"}
          icon="ring"
        />
        <.stat_card
          title="Nodes"
          value={length(@cluster["nodes"])}
          subtitle={"#{Enum.count(@cluster["nodes"], & &1["reachable"])} reachable"}
          icon="server"
        />
        <.stat_card
          title="Status"
          value={if @cluster["ready"], do: "Ready", else: "Changes Pending"}
          status={if @cluster["ready"], do: :ok, else: :warning}
          icon="shield"
        />
        <.stat_card
          title="AAE Exchanges"
          value={@aae_count}
          status={if @aae_count == 0, do: :ok, else: :info}
          icon="shield"
        />
        <.stat_card
          title="Handoffs"
          value={@handoff_count}
          status={if @handoff_count == 0, do: :ok, else: :warning}
          icon="transfer"
        />
      </div>

      <%!-- Section 2: Node Chips --%>
      <div class="mb-6">
        <h2 class="text-xs font-semibold uppercase tracking-wider text-[#8A8A8A] dark:text-[#94A3B8] mb-3">
          Nodes
        </h2>
        <.node_chips nodes={@cluster["nodes"]} selected_node={@selected_node} />
      </div>

      <%!-- Section 3: Two-Panel Display --%>
      <div class="grid grid-cols-1 lg:grid-cols-12 gap-4 mb-6">
        <div class="lg:col-span-7">
          <.node_performance
            nodes={@cluster["nodes"]}
            selected_node={@selected_node}
            node_stats={@node_stats}
            sparkline_history={@sparkline_history}
          />
        </div>
        <div class="lg:col-span-5">
          <.ring_panel ring={@ring} node_dist={@node_dist} />
        </div>
      </div>

      <%!-- Section 4: Remote Datacenters (conditional) --%>
      <div
        :if={@cluster["remote_dcs"] != [] and @cluster["remote_dcs"] != nil}
        class="mt-2"
      >
        <h2 class="text-xs font-semibold uppercase tracking-wider text-[#8A8A8A] dark:text-[#94A3B8] mb-3">
          Remote Datacenters
        </h2>
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
          <div
            :for={dc <- @cluster["remote_dcs"]}
            class="bg-white rounded-xl border border-[#EEEDEA] px-4 py-3 dark:bg-[var(--or-bg-surface)] dark:border-[var(--or-border-base)]"
          >
            <div class="font-semibold text-sm text-[#1A1A1A] dark:text-[var(--or-fg-base)]">{dc["name"]}</div>
            <div class="text-xs mt-1 text-[#8A8A8A] dark:text-[var(--or-fg-muted)]">
              {dc["admin_url"]} &middot; v{dc["riak_version"]}
            </div>
          </div>
        </div>
      </div>
    <% end %>
  </div>
  """
end
```

**Step 2: Verify it compiles**

Run: `mix compile --warnings-as-errors`
Expected: Compilation successful

**Step 3: Commit**

```bash
git add lib/riak_dashboard_web/live/cluster_live.ex
git commit -m "Replace ClusterLive render with consolidated dashboard layout"
```

---

### Task 7: Visual Verification — First Pass

Open the app in the browser and verify the consolidated layout renders.

**Step 1: Open the dashboard**

```bash
agent-browser --headed open http://localhost:4000/
```

**Step 2: Wait for LiveView and data**

```bash
agent-browser wait --load networkidle
agent-browser wait 2000
```

**Step 3: Take desktop screenshot**

```bash
agent-browser set viewport 1440 900
agent-browser screenshot /tmp/consolidated-v1.png -f
```

**Step 4: Inspect and verify**

Check that:
- 6 summary cards appear in a row
- Node chips render below cards
- Two-panel layout shows node performance (left) + ring chart (right)
- Sparklines start accumulating after a few seconds of WebSocket data

**Step 5: Check for JS errors**

```bash
agent-browser errors
agent-browser console
```

**Step 6: Close browser**

```bash
agent-browser close
```

**Step 7: Fix any issues found, then commit**

```bash
git add -A
git commit -m "Fix visual issues from first consolidation pass"
```

---

### Task 8: Route Cleanup — Remove Old Pages

Remove the Ring, AAE, and Handoff LiveView modules and add redirects.

**Files:**
- Modify: `lib/riak_dashboard_web/router.ex:26-29` (remove old routes, add redirects)
- Modify: `lib/riak_dashboard_web/controllers/page_controller.ex` (add redirect action)
- Delete: `lib/riak_dashboard_web/live/ring_live.ex`
- Delete: `lib/riak_dashboard_web/live/aae_live.ex`
- Delete: `lib/riak_dashboard_web/live/handoff_live.ex`
- Delete: `test/riak_dashboard_web/live/ring_live_test.exs`
- Delete: `test/riak_dashboard_web/live/aae_live_test.exs`
- Delete: `test/riak_dashboard_web/live/handoff_live_test.exs`

**Step 1: Add redirect action to PageController**

In `lib/riak_dashboard_web/controllers/page_controller.ex`, add:

```elixir
def redirect_to_cluster(conn, _params) do
  conn
  |> put_status(301)
  |> redirect(to: "/")
end
```

**Step 2: Update the router**

In `lib/riak_dashboard_web/router.ex`, remove these three lines:

```elixir
live("/ring", RingLive, :index)
live("/handoff", HandoffLive, :index)
live("/aae", AaeLive, :index)
```

Add redirects inside the existing scope (before or after the live routes):

```elixir
get("/ring", PageController, :redirect_to_cluster)
get("/aae", PageController, :redirect_to_cluster)
get("/handoff", PageController, :redirect_to_cluster)
```

**Step 3: Delete the old LiveView files**

```bash
rm lib/riak_dashboard_web/live/ring_live.ex
rm lib/riak_dashboard_web/live/aae_live.ex
rm lib/riak_dashboard_web/live/handoff_live.ex
```

**Step 4: Delete the old test files**

```bash
rm test/riak_dashboard_web/live/ring_live_test.exs
rm test/riak_dashboard_web/live/aae_live_test.exs
rm test/riak_dashboard_web/live/handoff_live_test.exs
```

**Step 5: Verify it compiles**

Run: `mix compile --warnings-as-errors`
Expected: Compilation successful, no undefined function warnings

**Step 6: Run tests to check nothing is broken**

Run: `mix test`
Expected: All remaining tests pass (the deleted test files are gone)

**Step 7: Commit**

```bash
git add -A
git commit -m "Remove Ring, AAE, Handoff pages; add 301 redirects to cluster dashboard"
```

---

### Task 9: Navigation Cleanup — Update Sidebar

Remove Ring, AAE, and Handoff links from the sidebar navigation.

**Files:**
- Modify: `lib/riak_dashboard_web/components/dashboard/shell.ex:16-25` (nav_sections)

**Step 1: Update the nav_sections module attribute**

In `shell.ex`, replace the `@nav_sections` definition. Remove Ring, Handoff, and AAE from the MONITORING section, keeping only Nodes:

```elixir
@nav_sections [
  %{
    label: "MONITORING",
    items: [
      %{name: "Nodes", icon: "server", path: "/nodes"}
    ]
  },
  %{
    label: "DATA",
    items: [
      %{name: "Buckets", icon: "bucket", path: "/buckets"},
      %{name: "Counters", icon: "counter", path: "/counters"},
      %{name: "CRDTs", icon: "datatype", path: "/datatypes"},
      %{name: "MapReduce", icon: "mapreduce", path: "/mapred"},
      %{name: "Query", icon: "search", path: "/query"},
      %{name: "Index Query", icon: "search", path: "/query/index"}
    ]
  },
  %{
    label: "SETTINGS",
    items: [
      %{name: "Type Properties", icon: "settings", path: "/types"}
    ]
  }
]
```

**Step 2: Verify it compiles**

Run: `mix compile --warnings-as-errors`
Expected: Compilation successful

**Step 3: Commit**

```bash
git add lib/riak_dashboard_web/components/dashboard/shell.ex
git commit -m "Remove Ring, AAE, Handoff links from sidebar navigation"
```

---

### Task 10: Visual Verification — Final Pass

Full visual check of the consolidated dashboard and redirect behavior.

**Step 1: Open dashboard and verify layout**

```bash
agent-browser --headed open http://localhost:4000/
agent-browser wait --load networkidle
agent-browser wait 3000
agent-browser set viewport 1440 900
agent-browser screenshot /tmp/consolidated-final-desktop.png -f
```

**Step 2: Verify redirects work**

```bash
agent-browser open http://localhost:4000/ring
agent-browser wait --load networkidle
agent-browser get url
# Should be http://localhost:4000/ (redirected)

agent-browser open http://localhost:4000/aae
agent-browser wait --load networkidle
agent-browser get url
# Should be http://localhost:4000/ (redirected)

agent-browser open http://localhost:4000/handoff
agent-browser wait --load networkidle
agent-browser get url
# Should be http://localhost:4000/ (redirected)
```

**Step 3: Verify sidebar**

```bash
agent-browser snapshot -i
# Should NOT show Ring, AAE, or Handoff links
```

**Step 4: Test node chip selection**

```bash
agent-browser snapshot -i
# Click a node chip
agent-browser click @e2  # (adjust ref based on snapshot)
agent-browser wait 500
agent-browser screenshot /tmp/consolidated-node-selected.png
```

**Step 5: Test dark mode**

```bash
agent-browser snapshot -i
# Find and click the dark mode toggle
# Take screenshot in dark mode
agent-browser screenshot /tmp/consolidated-dark-mode.png
```

**Step 6: Test tablet/mobile viewports**

```bash
agent-browser set viewport 768 1024
agent-browser screenshot /tmp/consolidated-tablet.png -f

agent-browser set viewport 375 667
agent-browser screenshot /tmp/consolidated-mobile.png -f
```

**Step 7: Check for errors**

```bash
agent-browser errors
agent-browser console
```

**Step 8: Close browser**

```bash
agent-browser close
```

**Step 9: Fix any visual issues, commit**

```bash
git add -A
git commit -m "Fix visual polish from final consolidation review"
```

---

### Task 11: Run Tests and Quality Checks

Run the full test suite and code quality tools.

**Step 1: Run all tests**

Run: `mix test`
Expected: All tests pass

**Step 2: Run formatter**

Run: `mix format`

**Step 3: Run credo**

Run: `mix credo`
Expected: No issues (or only pre-existing ones)

**Step 4: Compile with warnings**

Run: `mix compile --warnings-as-errors`
Expected: Clean compilation

**Step 5: Commit any formatting fixes**

```bash
git add -A
git commit -m "Format and clean up after consolidation"
```

---

### Task 12: Code Quality Review

Run ondiek, fresh-eyes, and code-simplifier agents.

**Step 1: Run ondiek**

Invoke ondiek skill to check code quality and add @spec annotations to new modules.

**Step 2: Run fresh-eyes agent**

Launch fresh-eyes agent to review all newly written code for bugs and issues.

**Step 3: Run code-simplifier agent**

Launch code-simplifier to clean up any complexity in the new components.

**Step 4: Commit fixes**

```bash
git add -A
git commit -m "Apply code quality improvements from review agents"
```
