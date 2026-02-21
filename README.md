# Riak Dashboard

A web UI for managing and monitoring [OpenRiak](https://github.com/OpenRiak) clusters. Built with Phoenix LiveView.

![Elixir](https://img.shields.io/badge/Elixir-1.18-4B275F) ![Phoenix](https://img.shields.io/badge/Phoenix-1.8-E8590C) ![License](https://img.shields.io/badge/license-MIT-blue)

## What it does

The dashboard connects to a Riak node's Admin API over HTTP and (optionally) its WebSocket event stream. It gives you:

**Cluster monitoring** -- cluster status, ring ownership visualization, per-node Erlang VM and KV metrics, handoff transfers, AAE exchange tracking. Pages that support WebSocket update in real time; without a WebSocket URL configured, they show a "Not Connected" indicator and wait for data.

**Data browser** -- list buckets (with optional bucket type), browse keys, read/write/delete objects, inspect and edit bucket properties and bucket type properties.

**Data types** -- read and increment counters, inspect and update CRDTs (counters, sets, maps).

**Query tools** -- run MapReduce jobs, secondary index (2i) queries (exact match and range), and complex queries against buckets.

## Prerequisites

- **Elixir 1.18+** and **Erlang/OTP 26+** ([install guide](https://elixir-lang.org/install.html))
- **A running Riak node** with the Admin API enabled (port 8099 by default). The dashboard works without one, but most pages will show errors or empty state.

## Quick start

```bash
# Clone and install dependencies
git clone <repo-url> && cd dashboard
mix setup

# Start the dev server
mix phx.server
```

Open [localhost:4000](http://localhost:4000). Log in with `admin` / `password`.

If your Riak node isn't at `localhost:8099`, point the dashboard at it:

```bash
RIAK_ADMIN_URL=http://my-riak-node:8099 \
RIAK_WS_URL=ws://my-riak-node:8099/api/stream/events \
mix phx.server
```

## Configuration

All configuration comes from environment variables, read at startup in `config/runtime.exs`.

| Variable | What it does | Default |
|----------|-------------|---------|
| `RIAK_ADMIN_URL` | Riak Admin HTTP API base URL | `http://localhost:8099` |
| `RIAK_WS_URL` | Riak WebSocket event stream URL | `ws://localhost:8099/api/stream/events` |
| `RIAK_DASHBOARD_USER` | Basic auth username | `admin` |
| `RIAK_DASHBOARD_PASS` | Basic auth password | `password` |
| `SECRET_KEY_BASE` | Cookie signing key (**required in prod**) | set in dev/test configs |
| `PHX_SERVER` | Set to `true` to start the HTTP server | not set (use `mix phx.server` in dev) |
| `PHX_HOST` | Hostname for generated URLs | `localhost` |
| `PORT` | HTTP listen port | `4000` |
| `DNS_CLUSTER_QUERY` | DNS query for Erlang clustering | not set |

For a deeper walkthrough of each variable and deployment scenarios, see [docs/configuration.md](docs/configuration.md).

## Architecture

```
Browser
  |
  |-- HTTP ---------> Phoenix Endpoint (Bandit, port 4000)
  |                      |
  |                    BasicAuth plug
  |                      |
  |                    LiveView (15 pages)
  |                      |
  |                    Client behaviour -- HttpClient (Req) --> Riak Admin API (:8099)
  |
  |-- WebSocket -----> Riak WS stream (:8099/api/stream/events)
       (JS hook)          |
                       pushes events back to LiveView
```

The dashboard is stateless -- it doesn't store anything itself. Every page either calls the Riak Admin API on demand (bucket operations, queries) or receives real-time updates over WebSocket (cluster status, ring, handoff, AAE).

**Client behaviour:** `RiakDashboard.Cluster.Client` defines callbacks for every Riak API endpoint. `HttpClient` is the real implementation using the `Req` HTTP library with a 5-second timeout and no retries. In tests, `Mox` stubs the behaviour so nothing hits the network.

**Real-time updates:** Five pages (cluster, ring, node detail, handoff, AAE) mount a `RiakEvents` JavaScript hook that opens a WebSocket to Riak's event stream. The hook subscribes to topics and pushes incoming events into the LiveView as `handle_event` calls. If no `RIAK_WS_URL` is configured, these pages show a "Not Connected" badge.

A full architecture diagram is at [docs/architecture/system-overview.excalidraw](docs/architecture/system-overview.excalidraw) (open with [excalidraw.com](https://excalidraw.com) or the VS Code extension).

## Pages

| Path | Page | What it shows |
|------|------|---------------|
| `/` | Cluster overview | Cluster name, ring size, node count, node table with stats |
| `/ring` | Ring ownership | Donut chart of partition distribution, per-node breakdown |
| `/nodes/:node` | Node detail | Erlang VM stats (memory, processes, run queue), KV metrics (gets, puts, latency) |
| `/handoff` | Handoff | Active transfer count and details |
| `/aae` | AAE | Active Anti-Entropy exchange status |
| `/buckets` | Bucket browser | List all buckets, link to keys and properties |
| `/buckets/:b/keys` | Key browser | List keys in a bucket, create new objects |
| `/buckets/:b/keys/:k` | Object detail | View/edit/delete an object, see metadata (vclock, etag, content-type) |
| `/buckets/:b/props` | Bucket properties | View and edit n_val, allow_mult, quorum settings, reset to defaults |
| `/counters` | Counter lookup | Open a counter by bucket + key |
| `/buckets/:b/counters/:k` | Counter detail | Current value, increment/decrement with custom delta |
| `/datatypes` | CRDT lookup | Open or create CRDTs by type/bucket/key |
| `/types/:t/buckets/:b/datatypes/:k` | CRDT detail | Current value, context, update operations |
| `/mapred` | MapReduce | JSON query editor, formatted results |
| `/query` | Query | Complex queries with timeout and max_results |
| `/query/index` | 2i query | Secondary index exact match and range queries |
| `/types` | Bucket types | List known types, edit type properties |

All bucket routes also work with typed buckets: `/types/:type/buckets/:bucket/...`

## Testing

Tests use [Mox](https://github.com/dashbitco/mox) to stub the `Client` behaviour. No Riak connection needed.

```bash
mix test                        # run all 62 tests
mix test --cover                # with coverage
mix credo --strict              # code quality
mix sobelow                     # security scan
mix format --check-formatted    # formatting check
```

The `ConnCase` test helper automatically stubs all `Client` callbacks with realistic fixture data via `RiakDashboard.Test.RiakStubs.stub_all/0`, so most tests work without any per-test setup. Override specific stubs with `Mox.expect/4` when you need to test error paths or specific responses.

## Production deployment

```bash
# Build a release
MIX_ENV=prod mix deps.get
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix release

# Run it
SECRET_KEY_BASE=$(mix phx.gen.secret) \
PHX_SERVER=true \
RIAK_ADMIN_URL=http://riak-node:8099 \
RIAK_WS_URL=ws://riak-node:8099/api/stream/events \
RIAK_DASHBOARD_USER=ops \
RIAK_DASHBOARD_PASS=<something-strong> \
PORT=4000 \
_build/prod/rel/riak_dashboard/bin/riak_dashboard start
```

The release is a self-contained binary. No Elixir or Erlang installation needed on the target machine.

## Development

```bash
mix setup              # install deps + build assets
mix phx.server         # start with file watching
iex -S mix phx.server  # start with IEx shell attached
```

The dev server live-reloads Elixir code and rebuilds CSS/JS on file changes. Tailwind CSS 4 with daisyUI handles styling. esbuild bundles JavaScript.

## Project structure

```
lib/
  riak_dashboard/
    application.ex              # supervision tree
    cluster/
      client.ex                 # behaviour (API contract)
      http_client.ex            # Req-based implementation
  riak_dashboard_web/
    router.ex                   # all routes
    endpoint.ex                 # HTTP server config
    plugs/basic_auth.ex         # authentication
    live/                       # 15 LiveView modules
    components/dashboard/       # reusable UI components
    formatters.ex               # value display helpers
assets/
  js/hooks/
    riak_events.js              # WebSocket client hook
    ring_chart.js               # canvas ring visualization
  css/app.css                   # Tailwind 4 + daisyUI
test/
  support/
    mocks.ex                    # Mox.defmock
    riak_stubs.ex               # default stub data
    conn_case.ex                # test setup with auto-stubs
```

## License

MIT
