# Riak Dashboard — Design Document

## Overview

Standalone Phoenix 1.8 + LiveView application for monitoring Riak clusters. Provides real-time visibility into cluster health, ring ownership, per-node stats, handoff transfers, and AAE exchanges. Connects to the Riak Admin API (Cowboy, port 8099) via HTTP and WebSocket.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Project type | Standalone mix project | Clean separation from riak_tui, independent deployment |
| App name | `riak_dashboard` | Distinct from admin API; lives at `/Users/abogec/open-riak/riak_dashboard` |
| Auth | HTTP Basic Auth via Plug | Simple, no database needed; credentials from env vars |
| Data source | Behaviour-based client (real + mock) | Dev works without a running cluster |
| Real-time | WebSocket from day one | RiakEvents JS hook → Riak stream endpoint; polling fallback for mock mode |
| Database | None (no Ecto) | Read-only monitoring dashboard |
| Theming | Fixoria shell + OpenRiak branding tokens | Proven layout with correct brand colors |
| MVP scope | Full monitoring suite | Cluster, ring, node detail, handoff, AAE |

## Project Structure

```
riak_dashboard/
├── lib/
│   ├── riak_dashboard/
│   │   ├── application.ex
│   │   └── cluster/
│   │       ├── client.ex           # Behaviour definition
│   │       ├── http_client.ex      # Real Req-based implementation
│   │       ├── mock_client.ex      # Mock for dev/test
│   │       └── data.ex             # Structs
│   ├── riak_dashboard_web/
│   │   ├── endpoint.ex
│   │   ├── router.ex
│   │   ├── plugs/basic_auth.ex
│   │   ├── components/
│   │   │   ├── core_components.ex
│   │   │   ├── layouts.ex
│   │   │   ├── layouts/
│   │   │   ├── icons.ex
│   │   │   └── dashboard/
│   │   │       ├── shell.ex
│   │   │       ├── cards.ex
│   │   │       ├── ring_chart.ex
│   │   │       ├── node_table.ex
│   │   │       └── connection.ex
│   │   └── live/
│   │       ├── cluster_live.ex
│   │       ├── ring_live.ex
│   │       ├── node_live.ex
│   │       ├── handoff_live.ex
│   │       └── aae_live.ex
├── assets/
│   ├── css/app.css
│   ├── js/
│   │   ├── app.js
│   │   └── hooks/
│   │       ├── riak_events.js
│   │       └── ring_chart.js
│   └── vendor/topbar.js
├── config/
│   ├── config.exs
│   ├── dev.exs
│   ├── prod.exs
│   ├── runtime.exs
│   └── test.exs
├── priv/static/
└── test/
```

## Authentication

HTTP Basic Auth with config-driven credentials:

```elixir
# runtime.exs
config :riak_dashboard, :basic_auth,
  username: System.get_env("RIAK_DASHBOARD_USER") || "admin",
  password: System.get_env("RIAK_DASHBOARD_PASS") || "password"
```

Applied via a plug pipeline in the router. No sessions or database.

## Routes

| Path | LiveView | Purpose |
|------|----------|---------|
| `/` | ClusterLive | Cluster overview, health, node list |
| `/ring` | RingLive | Ring partition visualization |
| `/nodes/:node` | NodeLive | Per-node VM and KV stats |
| `/handoff` | HandoffLive | Active transfer monitoring |
| `/aae` | AaeLive | Anti-entropy exchange status |

## Data Layer

Behaviour `RiakDashboard.Cluster.Client` with callbacks:
- `ping/1`, `cluster_status/1`, `ring_ownership/1`
- `node_stats/2`, `handoff_status/1`, `aae_status/1`, `list_dcs/1`

Two implementations selected via config:
- `HttpClient` — Req-based, hits Riak Admin API
- `MockClient` — returns realistic 5-node cluster data

## Real-Time Updates

WebSocket connection from browser to Riak's `ws://host:8099/api/stream/events`:
- `RiakEvents` JS hook manages connection, subscription, reconnection with backoff
- Events pushed to LiveView via `pushEvent`
- LiveView handlers update assigns on each event
- Connection indicator shows WebSocket health
- Fallback: `Process.send_after` polling when WebSocket unavailable (mock mode)

## Theming

- OpenRiak brand colors via CSS custom properties (`--or-brand`, `--or-bg-surface`, etc.)
- Inter font family (branding guide)
- Dark mode via class toggle + `openriak_dark_mode.js` hook
- Sidebar navigation adapted from fixoria shell: Cluster, Ring, Nodes, Handoff, AAE
- Logo: modified SVG showing "OpenRiak Dashboard" instead of "OpenRiak Admin"
- Stat cards, tables, and badges follow fixoria patterns with OpenRiak semantic colors

## Views

**Cluster Overview** — Health indicator, node count, ring size, pending changes. Node table with status badges. DC list for multi-DC setups.

**Ring Visualization** — Canvas-based circular ring chart. Partition-to-node mapping with consistent colors. Hover tooltips for hash ranges.

**Node Detail** — VM stats (OTP version, processes, memory). KV metrics (gets/puts, latencies, read repairs). Stat card layout.

**Handoff** — Active transfers table: type, source, target, progress.

**AAE** — Exchange table: partition, last exchange, status.
