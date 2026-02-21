# Configuration reference

This document covers every configuration option for the Riak Dashboard. It is written for someone deploying the dashboard for the first time.

## Environment variables

All environment variables are read at boot time in `config/runtime.exs`. In development, the defaults work out of the box. In production, you need to set at least `SECRET_KEY_BASE` and `PHX_SERVER`.

| Variable | What it does | Default | Required? |
|----------|-------------|---------|-----------|
| `RIAK_ADMIN_URL` | Base URL for the Riak Admin HTTP API. The dashboard calls this for cluster status, bucket operations, ring data, and everything else that hits Riak over HTTP. | `http://localhost:8099` | No |
| `RIAK_WS_URL` | WebSocket URL for real-time event streaming from Riak. The browser-side JS hook connects here to get live updates on the cluster, ring, handoff, and AAE pages. If unset, those pages show "Not Connected". | `ws://localhost:8099/api/stream/events` | No |
| `RIAK_DASHBOARD_USER` | Username for HTTP Basic Auth. Every request to the dashboard must pass this. | `admin` | No |
| `RIAK_DASHBOARD_PASS` | Password for HTTP Basic Auth. | `password` | No |
| `SECRET_KEY_BASE` | Signs and encrypts cookies. Generate one with `mix phx.gen.secret`. There is no default in production. The app will crash on startup if this is missing. | None in prod | Yes (prod) |
| `PHX_SERVER` | Set to `true` to start the HTTP server. Required when running a release. Not needed when you start with `mix phx.server` because Mix handles it. | Not set | Yes (releases) |
| `PHX_HOST` | Hostname used for URL generation (links, WebSocket endpoints). In production, the endpoint assumes HTTPS on port 443. | `localhost` | No |
| `PORT` | HTTP port the server listens on. | `4000` | No |
| `DNS_CLUSTER_QUERY` | DNS query for automatic Erlang node clustering via the `dns_cluster` library. Leave blank if you are running a single node. | Not set | No |

## Config files

All config files live in `config/`. Here is what each one does.

### config.exs

Compile-time defaults shared across all environments. This is where the base values for `riak_admin_url`, `riak_ws_url`, and Basic Auth credentials are set. It also configures esbuild, Tailwind, the JSON library, the Phoenix endpoint adapter (Bandit), and the logger format.

Everything in this file can be overridden by the environment-specific files below.

### dev.exs

Development settings. Binds to `127.0.0.1:4000`, turns on code reloading, debug errors, and live reload for JS/CSS/templates. Sets a hardcoded `secret_key_base` so you do not need an env var. Runs esbuild and Tailwind in watch mode.

Also enables HEEx debug annotations and expensive LiveView runtime checks, both of which you would not want in production.

### test.exs

Test settings. Swaps the HTTP client for `RiakDashboard.Cluster.MockBehaviour` so tests never hit a real Riak node. Runs on port 4002 with the HTTP server disabled. Logs only warnings and errors to keep test output clean.

### prod.exs

Production compile-time settings. Turns on static asset caching via `cache_static_manifest`, sets the server to `true`, and drops the log level to `:info`. Does not contain secrets or env-var reads. Those go in `runtime.exs`.

### runtime.exs

Loaded at boot, after compilation, before the app starts. This is where environment variables are read. It runs in every environment, but the production block (guarded by `if config_env() == :prod`) is where the important stuff happens:

- Reads `SECRET_KEY_BASE` (crashes if missing)
- Reads `PHX_HOST` and `PORT`
- Configures the endpoint to bind on all interfaces (`{0, 0, 0, 0, 0, 0, 0, 0}`)
- Sets the cluster client to `RiakDashboard.Cluster.HttpClient`
- Reads `DNS_CLUSTER_QUERY`

The `RIAK_ADMIN_URL`, `RIAK_WS_URL`, `RIAK_DASHBOARD_USER`, and `RIAK_DASHBOARD_PASS` variables are read outside the prod block, so they work in all environments.

## Common deployment scenarios

### Local development without Riak

```bash
mix setup
mix phx.server
```

The dashboard starts on `http://localhost:4000`. Pages that depend on the WebSocket (cluster, ring, handoff, AAE) will show "Not Connected". Bucket and key operations will fail with connection errors. This is fine for working on the UI without a running cluster.

Default credentials: `admin` / `password`.

### Local development with Riak

Point the dashboard at your local Riak node:

```bash
export RIAK_ADMIN_URL=http://localhost:8099
export RIAK_WS_URL=ws://localhost:8099/api/stream/events
mix phx.server
```

The default port for Riak's admin API is 8099. The regular HTTP API is on 8098. The dashboard uses the admin API.

There is an `example.local.env` file in the project root you can copy to `.env` and source before starting:

```bash
cp example.local.env .env
# edit .env with your values
source .env && mix phx.server
```

### Docker / container

Pass environment variables with `docker run -e` or through your `docker-compose.yml`:

```bash
docker run \
  -e PHX_SERVER=true \
  -e SECRET_KEY_BASE=$(mix phx.gen.secret) \
  -e PORT=4000 \
  -e RIAK_ADMIN_URL=http://riak-node:8099 \
  -e RIAK_WS_URL=ws://riak-node:8099/api/stream/events \
  -p 4000:4000 \
  riak-dashboard
```

`PHX_SERVER=true` is required. Without it, the release boots but does not listen for HTTP connections.

If your Riak node is on the same Docker network, use the container name as the hostname (e.g., `http://riak-node:8099`).

### Production release

Build the release:

```bash
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix release
```

Run it:

```bash
SECRET_KEY_BASE=<your-64-byte-secret> \
PHX_SERVER=true \
PHX_HOST=dashboard.example.com \
PORT=4000 \
RIAK_ADMIN_URL=http://riak-admin:8099 \
RIAK_WS_URL=ws://riak-admin:8099/api/stream/events \
_build/prod/rel/riak_dashboard/bin/riak_dashboard start
```

All config comes from environment variables via `runtime.exs`. There are no config files to edit on the production host.

Two variables are mandatory:
- `SECRET_KEY_BASE` -- the app raises on startup without it
- `PHX_SERVER=true` -- otherwise the release does not start the HTTP server

Generate a secret with:

```bash
mix phx.gen.secret
```

In production, the endpoint assumes HTTPS on port 443 for URL generation (`url: [host: host, port: 443, scheme: "https"]`). The actual HTTP listener still binds to whatever `PORT` you set. Put a reverse proxy (nginx, Caddy, a load balancer) in front to terminate TLS.
