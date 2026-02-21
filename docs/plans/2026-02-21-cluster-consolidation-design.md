# Consolidated Cluster Dashboard Design

## Goal

Merge the Ring, AAE Exchange, and Handoff pages into the main cluster dashboard. Remove three separate routes. Deliver maximum cluster visibility from one page load.

## Decisions

- **Node performance**: Accumulate rolling sparklines (last 30 snapshots) in LiveView assigns. Pure SVG, no chart library.
- **AAE**: Count-only stat card. Raw Erlang tuple details dropped.
- **Handoff**: Count-only stat card. Consolidated into cluster dashboard.
- **Old routes**: 301 redirect to `/`.

## Layout (Approach A: Two-Row Density)

```
┌─────────────────────────────────────────────────────────────────────────┐
│ SUMMARY CARDS (6 cards, grid-cols-2 sm:3 lg:6)                          │
│ Cluster | Ring Size | Nodes | Status | AAE Exchanges | Handoffs        │
├─────────────────────────────────────────────────────────────────────────┤
│ NODE CHIPS (flex-wrap, horizontal)                                       │
│ [● dev1 VALID] [● dev2 VALID] [● dev3 VALID] [● dev4 VALID] ...       │
├──────────────────────────────────┬──────────────────────────────────────┤
│ NODE PERFORMANCE (~55%)          │ RING DISTRIBUTION (~45%)             │
│ Dropdown selector + sparklines   │ Donut chart + node distribution     │
│ for gets/puts/memory/latency     │ table (partitions, ring %)          │
└──────────────────────────────────┴──────────────────────────────────────┘
│ REMOTE DCs (conditional, same as current)                               │
└─────────────────────────────────────────────────────────────────────────┘
```

## Section Details

### 1. Summary Cards Row

Six `stat_card` components in a responsive grid.

| # | Title | Value Source | Subtitle | Icon | Badge |
|---|-------|-------------|----------|------|-------|
| 1 | Cluster | `cluster["cluster_name"]` | Claimant: `cluster["claimant"]` | `dashboard` | -- |
| 2 | Ring | `cluster["ring_size"]` | `N partitions` (from ring data) | `ring` | -- |
| 3 | Nodes | `length(cluster["nodes"])` | `N reachable` | `server` | -- |
| 4 | Status | Ready / Changes Pending | -- | `shield` | `:ok` / `:warning` |
| 5 | AAE Exchanges | `aae["count"]` | -- | `shield` | `:ok` (0) / `:info` (>0) |
| 6 | Handoffs | `handoff["count"]` | -- | `transfer` | `:ok` (0) / `:warning` (>0) |

### 2. Node Chips

Compact horizontal row. Each chip:
- Green/red status dot (reachable/unreachable)
- Node name (mono font)
- Status badge (VALID/LEAVING/JOINING/DOWN)
- Click to select in sparkline panel
- Selected chip: orange border ring (`ring-[#e77117]`)

### 3a. Node Performance Panel (left, ~55%)

Header bar with "Node Performance" title + node selector dropdown (`<select phx-change="select_node">`).

Seven sparkline rows:

| Metric | Source | Unit |
|--------|--------|------|
| VNode Gets | `kv.vnode_gets` | count |
| VNode Puts | `kv.vnode_puts` | count |
| Memory | `erlang.memory_total` | MB |
| Processes | `erlang.process_count` | count |
| Get Latency | `kv.node_get_fsm_time_mean` | us |
| Put Latency | `kv.node_put_fsm_time_mean` | us |
| Read Repairs | `kv.read_repairs` | count |

Each row: label (left) + SVG sparkline (center) + current value (right).

Sparkline implementation: Pure SVG `<polyline>` in a small viewbox (e.g., 120x24). Rolling buffer of 30 data points per metric per node, stored in `@sparkline_history` assign.

### 3b. Ring Distribution Panel (right, ~45%)

Reuses existing `ring_chart` component (canvas donut) + node distribution table extracted from `ring_live.ex`.

Content:
- Donut chart showing partition ownership by node (color-coded)
- Legend/table: node name + color swatch + partition count + ring %

### 4. Remote Datacenters (conditional)

Same as current implementation. Grid of DC cards, shown only when `remote_dcs` is non-empty.

## Data Architecture

### WebSocket Topics

ClusterLive subscribes to all five topics in one connection:

```elixir
topics_json: Jason.encode!(~w(cluster node_stats ring aae handoff))
```

### New Assigns

```elixir
# Existing (kept):
cluster, cluster_name, remote_dcs, node_stats, ws_url, ws_status, loading, error

# New:
ring: nil,                    # Ring data from riak_ring topic
node_dist: [],                # Computed node distribution
aae_count: 0,                 # AAE exchange count
handoff_count: 0,             # Handoff transfer count
selected_node: nil,           # Currently selected node for sparklines
sparkline_history: %{},       # %{node_name => [%{metric => value}, ...]}
```

### New Event Handlers

```elixir
handle_event("riak_ring", data, socket)     -> ring, node_dist
handle_event("riak_aae", data, socket)      -> aae_count
handle_event("riak_handoff", data, socket)  -> handoff_count
```

### Sparkline Accumulation

On each `riak_node_stats` event:
1. Update `node_stats` as before
2. For each node in data, append current metrics to `sparkline_history[node]`
3. Cap each node's history at 30 entries (circular buffer via `Enum.take(-30)`)
4. Auto-select first node if `selected_node` is nil

## New Components

| Component | File | Purpose |
|-----------|------|---------|
| `node_chips/1` | `dashboard/node_chips.ex` | Compact horizontal node list with click-to-select |
| `sparkline/1` | `dashboard/sparkline.ex` | Pure SVG sparkline renderer |
| `node_performance/1` | `dashboard/node_performance.ex` | Left panel: dropdown + sparkline rows |
| `ring_panel/1` | `dashboard/ring_panel.ex` | Right panel: donut chart + distribution table |

## Route Changes

### Remove
- `live("/ring", RingLive, :index)`
- `live("/aae", AaeLive, :index)`
- `live("/handoff", HandoffLive, :index)`

### Add Redirects
```elixir
get("/ring", PageController, :redirect_to_cluster)
get("/aae", PageController, :redirect_to_cluster)
get("/handoff", PageController, :redirect_to_cluster)
```

### Delete Files
- `lib/riak_dashboard_web/live/ring_live.ex`
- `lib/riak_dashboard_web/live/aae_live.ex`
- `lib/riak_dashboard_web/live/handoff_live.ex`

## Navigation Changes

Remove from sidebar MONITORING section:
- Ring link
- AAE link
- Handoff link

Keep: Nodes link (routes to ClusterLive with `/nodes` path).

## Edge Cases

- **Node goes offline**: Status dot turns red, badge changes, sparkline shows last known values
- **Ring in transition**: Ring chart updates in real-time via WebSocket push
- **Empty sparkline history**: Show placeholder (flat line or "Collecting data..." text)
- **No AAE exchanges**: Card shows 0 with `:ok` badge
- **Cluster selector switch**: Resets all data (ring, sparklines, AAE, handoff) and reconnects WebSocket
- **Many nodes (10+)**: Chip list wraps naturally; dropdown handles long lists natively

## Design Tokens

Follows existing OpenRiak design system:
- Card bg: `bg-white dark:bg-[var(--or-bg-surface)]`
- Card border: `border-[#EEEDEA] dark:border-[var(--or-border-base)]`
- Headers: `text-xs font-semibold uppercase tracking-wider text-[#8A8A8A]`
- Values: `text-lg font-bold text-[#1A1A1A] dark:text-[var(--or-fg-base)]`
- Sparkline stroke: `#e77117` (brand orange) for selected metric
- Selected chip: `ring-2 ring-[#e77117]`
