# Riak Dashboard Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a standalone Phoenix LiveView dashboard that covers every endpoint in the Riak Admin API (Cowboy), with OpenRiak branding and real-time WebSocket updates.

**Architecture:** New Phoenix 1.8 app (`riak_dashboard`) with behaviour-based HTTP client (real + mock), WebSocket JS hooks for live data, and a fixoria-derived UI shell themed with OpenRiak brand tokens. Basic auth protects all routes. No database.

**Tech Stack:** Elixir 1.18+, Phoenix 1.8, LiveView 1.0, Req (HTTP), Tailwind CSS 4, daisyUI, esbuild, Bandit

---

## Task 1: Scaffold Phoenix Project

**Files:**
- Create: `mix.exs`
- Create: `lib/riak_dashboard.ex`
- Create: `lib/riak_dashboard/application.ex`
- Create: `lib/riak_dashboard_web.ex`
- Create: `lib/riak_dashboard_web/endpoint.ex`
- Create: `lib/riak_dashboard_web/router.ex`
- Create: `lib/riak_dashboard_web/telemetry.ex`
- Create: `config/config.exs`, `config/dev.exs`, `config/prod.exs`, `config/test.exs`, `config/runtime.exs`
- Create: `test/test_helper.exs`, `test/support/conn_case.ex`

**Step 1: Generate the Phoenix project**

```bash
cd /Users/abogec/open-riak
mix phx.new riak_dashboard --no-ecto --no-mailer --no-dashboard --no-gettext
```

Use `--no-ecto` (no database), `--no-mailer`, `--no-dashboard` (no LiveDashboard — we're building our own), `--no-gettext` (no i18n).

**Step 2: Verify scaffold compiles**

```bash
cd /Users/abogec/open-riak/riak_dashboard
mix deps.get && mix compile
```

Expected: Compiles with zero errors.

**Step 3: Update mix.exs dependencies**

Add `req` for HTTP client. Remove any deps we don't need:

```elixir
defp deps do
  [
    {:phoenix, "~> 1.8"},
    {:phoenix_html, "~> 4.1"},
    {:phoenix_live_reload, "~> 1.2", only: :dev},
    {:phoenix_live_view, "~> 1.0"},
    {:floki, ">= 0.30.0", only: :test},
    {:lazy_html, ">= 0.1.0", only: :test},
    {:esbuild, "~> 0.9", runtime: Mix.env() == :dev},
    {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
    {:heroicons, github: "tailwindlabs/heroicons", tag: "v2.1.1",
     sparse: "optimized", app: false, compile: false, depth: 1},
    {:telemetry_metrics, "~> 1.0"},
    {:telemetry_poller, "~> 1.0"},
    {:req, "~> 0.5"},
    {:jason, "~> 1.2"},
    {:dns_cluster, "~> 0.1.1"},
    {:bandit, "~> 1.5"},
    {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
    {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
    {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
  ]
end
```

**Step 4: Run deps.get and compile**

```bash
mix deps.get && mix compile
```

**Step 5: Verify the server starts**

```bash
mix phx.server
```

Visit http://localhost:4000. Expected: Phoenix welcome page.

**Step 6: Commit**

```bash
git init && git add -A && git commit -m "feat: scaffold riak_dashboard Phoenix project"
```

---

## Task 2: Basic Auth Plug and Config

**Files:**
- Create: `lib/riak_dashboard_web/plugs/basic_auth.ex`
- Modify: `lib/riak_dashboard_web/router.ex`
- Modify: `config/config.exs`
- Modify: `config/runtime.exs`
- Test: `test/riak_dashboard_web/plugs/basic_auth_test.exs`

**Step 1: Write the test**

```elixir
defmodule RiakDashboardWeb.Plugs.BasicAuthTest do
  use RiakDashboardWeb.ConnCase

  test "returns 401 without credentials" do
    conn = get(build_conn(), ~p"/")
    assert conn.status == 401
  end

  test "returns 200 with valid credentials" do
    conn =
      build_conn()
      |> put_req_header("authorization", basic_auth("admin", "password"))
      |> get(~p"/")

    assert conn.status == 200
  end

  test "returns 401 with wrong credentials" do
    conn =
      build_conn()
      |> put_req_header("authorization", basic_auth("admin", "wrong"))
      |> get(~p"/")

    assert conn.status == 401
  end

  defp basic_auth(user, pass) do
    "Basic " <> Base.encode64("#{user}:#{pass}")
  end
end
```

**Step 2: Run test to see it fail**

```bash
mix test test/riak_dashboard_web/plugs/basic_auth_test.exs
```

**Step 3: Implement the basic auth plug**

`lib/riak_dashboard_web/plugs/basic_auth.ex`:

```elixir
defmodule RiakDashboardWeb.Plugs.BasicAuth do
  @moduledoc "HTTP Basic Auth plug with config-driven credentials."

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    config = Application.get_env(:riak_dashboard, :basic_auth, [])
    expected_user = Keyword.get(config, :username, "admin")
    expected_pass = Keyword.get(config, :password, "password")

    with ["Basic " <> encoded] <- get_req_header(conn, "authorization"),
         {:ok, decoded} <- Base.decode64(encoded),
         [^expected_user, ^expected_pass] <- String.split(decoded, ":", parts: 2) do
      conn
    else
      _ ->
        conn
        |> put_resp_header("www-authenticate", ~s(Basic realm="Riak Dashboard"))
        |> send_resp(401, "Unauthorized")
        |> halt()
    end
  end
end
```

**Step 4: Wire into router**

```elixir
pipeline :auth do
  plug RiakDashboardWeb.Plugs.BasicAuth
end

scope "/", RiakDashboardWeb do
  pipe_through [:browser, :auth]
  live "/", ClusterLive, :index
end
```

**Step 5: Add config**

`config/config.exs`:
```elixir
config :riak_dashboard, :basic_auth,
  username: "admin",
  password: "password"
```

`config/runtime.exs`:
```elixir
config :riak_dashboard, :basic_auth,
  username: System.get_env("RIAK_DASHBOARD_USER") || "admin",
  password: System.get_env("RIAK_DASHBOARD_PASS") || "password"
```

**Step 6: Run tests**

```bash
mix test test/riak_dashboard_web/plugs/basic_auth_test.exs
```

**Step 7: Commit**

```bash
git add -A && git commit -m "feat: add basic auth plug with env var config"
```

---

## Task 3: HTTP Client Behaviour and Mock

**Files:**
- Create: `lib/riak_dashboard/cluster/client.ex`
- Create: `lib/riak_dashboard/cluster/http_client.ex`
- Create: `lib/riak_dashboard/cluster/mock_client.ex`
- Modify: `config/config.exs`
- Modify: `config/dev.exs`
- Modify: `config/test.exs`
- Test: `test/riak_dashboard/cluster/http_client_test.exs`
- Test: `test/riak_dashboard/cluster/mock_client_test.exs`

**Step 1: Define the behaviour**

`lib/riak_dashboard/cluster/client.ex`:

```elixir
defmodule RiakDashboard.Cluster.Client do
  @moduledoc "Behaviour for the Riak Admin API client."

  # Admin endpoints
  @callback ping(base_url :: String.t()) :: {:ok, map()} | {:error, term()}
  @callback cluster_status(base_url :: String.t()) :: {:ok, map()} | {:error, term()}
  @callback ring_ownership(base_url :: String.t()) :: {:ok, map()} | {:error, term()}
  @callback node_stats(base_url :: String.t(), node_name :: String.t()) :: {:ok, map()} | {:error, term()}
  @callback handoff_status(base_url :: String.t()) :: {:ok, map()} | {:error, term()}
  @callback aae_status(base_url :: String.t()) :: {:ok, map()} | {:error, term()}
  @callback list_dcs(base_url :: String.t()) :: {:ok, map()} | {:error, term()}

  # Data operations
  @callback list_buckets(base_url :: String.t(), opts :: keyword()) :: {:ok, map()} | {:error, term()}
  @callback list_keys(base_url :: String.t(), bucket :: String.t(), opts :: keyword()) :: {:ok, map()} | {:error, term()}
  @callback get_object(base_url :: String.t(), bucket :: String.t(), key :: String.t(), opts :: keyword()) :: {:ok, map()} | {:error, term()}
  @callback put_object(base_url :: String.t(), bucket :: String.t(), key :: String.t(), value :: term(), opts :: keyword()) :: {:ok, map()} | {:error, term()}
  @callback delete_object(base_url :: String.t(), bucket :: String.t(), key :: String.t(), opts :: keyword()) :: :ok | {:error, term()}
  @callback get_bucket_props(base_url :: String.t(), bucket :: String.t(), opts :: keyword()) :: {:ok, map()} | {:error, term()}
  @callback put_bucket_props(base_url :: String.t(), bucket :: String.t(), props :: map(), opts :: keyword()) :: {:ok, map()} | {:error, term()}

  # Convenience: resolve client module from config
  def impl do
    Application.get_env(:riak_dashboard, :cluster_client, RiakDashboard.Cluster.HttpClient)
  end

  def base_url do
    Application.get_env(:riak_dashboard, :riak_admin_url, "http://localhost:8099")
  end
end
```

**Step 2: Write mock client tests**

```elixir
defmodule RiakDashboard.Cluster.MockClientTest do
  use ExUnit.Case, async: true

  alias RiakDashboard.Cluster.MockClient

  test "ping returns ok with node name" do
    assert {:ok, %{"status" => "ok", "node" => _}} = MockClient.ping("http://unused")
  end

  test "cluster_status returns nodes list" do
    assert {:ok, %{"nodes" => nodes}} = MockClient.cluster_status("http://unused")
    assert length(nodes) == 5
  end

  test "ring_ownership returns partitions" do
    assert {:ok, %{"partitions" => parts}} = MockClient.ring_ownership("http://unused")
    assert length(parts) == 64
  end

  test "list_buckets returns bucket list" do
    assert {:ok, %{"buckets" => buckets}} = MockClient.list_buckets("http://unused")
    assert is_list(buckets)
  end
end
```

**Step 3: Run test, see failure**

```bash
mix test test/riak_dashboard/cluster/mock_client_test.exs
```

**Step 4: Implement HttpClient**

`lib/riak_dashboard/cluster/http_client.ex`:

```elixir
defmodule RiakDashboard.Cluster.HttpClient do
  @moduledoc "Real HTTP client for the Riak Admin API using Req."
  @behaviour RiakDashboard.Cluster.Client

  @timeout 5_000

  @impl true
  def ping(base_url), do: get(base_url, "/api/ping")

  @impl true
  def cluster_status(base_url), do: get(base_url, "/api/cluster/status")

  @impl true
  def ring_ownership(base_url), do: get(base_url, "/api/ring/ownership")

  @impl true
  def node_stats(base_url, node_name),
    do: get(base_url, "/api/nodes/#{URI.encode_www_form(node_name)}/stats")

  @impl true
  def handoff_status(base_url), do: get(base_url, "/api/handoff/status")

  @impl true
  def aae_status(base_url), do: get(base_url, "/api/aae/status")

  @impl true
  def list_dcs(base_url), do: get(base_url, "/api/dcs")

  @impl true
  def list_buckets(base_url, opts \\ []) do
    type = Keyword.get(opts, :type)
    path = if type, do: "/types/#{type}/buckets", else: "/buckets"
    get(base_url, path)
  end

  @impl true
  def list_keys(base_url, bucket, opts \\ []) do
    type = Keyword.get(opts, :type)
    path = if type,
      do: "/types/#{type}/buckets/#{bucket}/keys?keys=true",
      else: "/buckets/#{bucket}/keys?keys=true"
    get(base_url, path)
  end

  @impl true
  def get_object(base_url, bucket, key, opts \\ []) do
    type = Keyword.get(opts, :type)
    path = if type,
      do: "/types/#{type}/buckets/#{bucket}/keys/#{key}",
      else: "/buckets/#{bucket}/keys/#{key}"
    get(base_url, path)
  end

  @impl true
  def put_object(base_url, bucket, key, value, opts \\ []) do
    type = Keyword.get(opts, :type)
    path = if type,
      do: "/types/#{type}/buckets/#{bucket}/keys/#{key}",
      else: "/buckets/#{bucket}/keys/#{key}"
    put(base_url, path, value)
  end

  @impl true
  def delete_object(base_url, bucket, key, opts \\ []) do
    type = Keyword.get(opts, :type)
    path = if type,
      do: "/types/#{type}/buckets/#{bucket}/keys/#{key}",
      else: "/buckets/#{bucket}/keys/#{key}"
    delete(base_url, path)
  end

  @impl true
  def get_bucket_props(base_url, bucket, opts \\ []) do
    type = Keyword.get(opts, :type)
    path = if type,
      do: "/types/#{type}/buckets/#{bucket}/props",
      else: "/buckets/#{bucket}/props"
    get(base_url, path)
  end

  @impl true
  def put_bucket_props(base_url, bucket, props, opts \\ []) do
    type = Keyword.get(opts, :type)
    path = if type,
      do: "/types/#{type}/buckets/#{bucket}/props",
      else: "/buckets/#{bucket}/props"
    put(base_url, path, %{"props" => props})
  end

  defp get(base_url, path) do
    case Req.get("#{base_url}#{path}", receive_timeout: @timeout, retry: false) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}
      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http, status, body}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp put(base_url, path, body) do
    case Req.put("#{base_url}#{path}", json: body, receive_timeout: @timeout, retry: false) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}
      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http, status, body}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp delete(base_url, path) do
    case Req.delete("#{base_url}#{path}", receive_timeout: @timeout, retry: false) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        :ok
      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http, status, body}}
      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

**Step 5: Implement MockClient**

`lib/riak_dashboard/cluster/mock_client.ex` — returns realistic data for a 5-node dev cluster. Every callback returns hardcoded data matching the exact JSON shapes from the LIVEVIEW_INTEGRATION.md doc.

**Step 6: Add config**

`config/config.exs`:
```elixir
config :riak_dashboard, :riak_admin_url, "http://localhost:8099"
```

`config/dev.exs`:
```elixir
config :riak_dashboard, :cluster_client, RiakDashboard.Cluster.MockClient
```

`config/test.exs`:
```elixir
config :riak_dashboard, :cluster_client, RiakDashboard.Cluster.MockClient
```

**Step 7: Run all tests**

```bash
mix test
```

**Step 8: Commit**

```bash
git add -A && git commit -m "feat: add HTTP client behaviour with real and mock implementations"
```

---

## Task 4: OpenRiak Branding and Theming

**Files:**
- Create: `assets/css/app.css` (replace generated)
- Copy: `openriak_tokens.css` → `assets/css/openriak_tokens.css`
- Create: `assets/js/hooks/dark_mode.js`
- Create: `priv/static/images/openriak_dashboard_logo.svg`
- Create: `priv/static/images/openriak_dashboard_logo_dark.svg`
- Create: `priv/static/images/openriak_dashboard_icon.svg`
- Modify: `assets/vendor/` (ensure daisyui.js and daisyui-theme.js are present)

**Step 1: Copy daisyUI vendor files from fixoria**

```bash
cp /Users/abogec/open-riak/fixoria/assets/vendor/daisyui.js assets/vendor/
cp /Users/abogec/open-riak/fixoria/assets/vendor/daisyui-theme.js assets/vendor/
```

**Step 2: Copy OpenRiak tokens CSS**

```bash
cp /Users/abogec/open-riak/branding/openriak-admin-brand/config/openriak_tokens.css assets/css/
```

**Step 3: Create app.css with OpenRiak themes**

Replace the generated `assets/css/app.css` with OpenRiak-themed daisyUI config. Use the OpenRiak orange (#e77117) as primary instead of fixoria's colors. Map daisyUI color tokens to OpenRiak palette values. Import the tokens CSS.

**Step 4: Create modified logo SVGs**

Copy the branding logos but change "ADMIN" text to "DASHBOARD":

```bash
cp /Users/abogec/open-riak/branding/openriak-admin-brand/logos/openriak_admin_icon.svg priv/static/images/openriak_dashboard_icon.svg
```

For the full logos, modify the SVG text elements: change `ADMIN` → `DASHBOARD` and adjust letter-spacing to fit.

**Step 5: Create DarkMode JS hook**

Copy the `openriak_dark_mode.js` hook into `assets/js/hooks/dark_mode.js`.

**Step 6: Verify assets build**

```bash
mix assets.build
```

**Step 7: Commit**

```bash
git add -A && git commit -m "feat: add OpenRiak branding, tokens, and dark mode hook"
```

---

## Task 5: Layout Shell (Sidebar + Header)

**Files:**
- Create: `lib/riak_dashboard_web/components/layouts/root.html.heex`
- Create: `lib/riak_dashboard_web/components/layouts/app.html.heex`
- Modify: `lib/riak_dashboard_web/components/layouts.ex`
- Create: `lib/riak_dashboard_web/components/dashboard/shell.ex`
- Create: `lib/riak_dashboard_web/components/dashboard/icons.ex`

**Step 1: Build root layout**

Adapt from fixoria's root.html.heex. Change:
- Font: DM Sans → Inter (from OpenRiak branding guide)
- Title: Fixoria → OpenRiak Dashboard
- Add `phx-hook="DarkMode"` to `<html>` element
- Add dark mode class toggle support

**Step 2: Build sidebar shell component**

Adapt from fixoria's `ShellComponents`. Replace:
- Logo: Fixoria trademark → OpenRiak Dashboard SVG logo
- Navigation sections: hotel-specific items → Riak monitoring items:
  - **MONITORING**: Cluster, Ring, Nodes, Handoff, AAE
  - **DATA**: Buckets (KV Browser)
- Colors: Replace all `#4A7C59` (fixoria green) with `var(--or-brand)` / `#e77117`
- Replace `#FAFAF8` sidebar bg with `var(--or-bg-base)`
- Replace `#EEEDEA` borders with `var(--or-border-base)`
- Remove merchant dropdown (not applicable)
- Add connection indicator slot at bottom of sidebar

**Step 3: Build header component**

Simplified version of fixoria's header. Include:
- Page title (dynamic per route)
- Dark mode toggle button
- Connection status indicator

**Step 4: Build icons module**

Port needed icons from fixoria + add Riak-specific ones:
- dashboard, ring, server, transfer, shield (for nav)
- check, x, arrow-up, arrow-down (for status)
- sun, moon (for dark mode toggle)
- bucket, key, database (for KV browser)

**Step 5: Wire sidebar into app layout**

The app layout should render sidebar + main content area.

**Step 6: Verify visual result**

```bash
mix phx.server
```

Navigate to http://localhost:4000 with basic auth. Should see the sidebar with OpenRiak branding.

**Step 7: Commit**

```bash
git add -A && git commit -m "feat: add OpenRiak-branded sidebar shell and layout"
```

---

## Task 6: WebSocket JS Hooks

**Files:**
- Create: `assets/js/hooks/riak_events.js`
- Create: `assets/js/hooks/ring_chart.js`
- Modify: `assets/js/app.js`

**Step 1: Create RiakEvents hook**

Copy from LIVEVIEW_INTEGRATION.md (lines 742-785). This hook:
- Reads `data-ws-url` and `data-topics` from the element
- Opens WebSocket to Riak's stream endpoint
- Subscribes to specified topics
- Routes incoming events to LiveView via `pushEvent("riak_" + topic, data)`
- Reconnects with exponential backoff (1s → 30s max)

**Step 2: Create RingChart canvas hook**

Copy from LIVEVIEW_INTEGRATION.md (lines 915-955). This hook:
- Reads `data-ring` JSON from element dataset
- Draws circular ring chart on canvas
- Uses OpenRiak color palette
- Redraws on `updated()` lifecycle

**Step 3: Register hooks in app.js**

```javascript
import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
import {DarkMode} from "./hooks/dark_mode"
import RiakEvents from "./hooks/riak_events"
import RingChart from "./hooks/ring_chart"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {DarkMode, RiakEvents, RingChart}
})

topbar.config({barColors: {0: "#e77117"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

liveSocket.connect()
window.liveSocket = liveSocket
```

**Step 4: Build and verify**

```bash
mix assets.build
```

No JS errors in browser console.

**Step 5: Commit**

```bash
git add -A && git commit -m "feat: add RiakEvents, RingChart, and DarkMode JS hooks"
```

---

## Task 7: Cluster Overview LiveView

**Files:**
- Create: `lib/riak_dashboard_web/live/cluster_live.ex`
- Create: `lib/riak_dashboard_web/components/dashboard/cards.ex`
- Create: `lib/riak_dashboard_web/components/dashboard/node_table.ex`
- Create: `lib/riak_dashboard_web/components/dashboard/connection.ex`
- Modify: `lib/riak_dashboard_web/router.ex`

**Step 1: Create stat cards component**

Adapt fixoria's CardComponents pattern for Riak stats:

```elixir
defmodule RiakDashboardWeb.Components.Dashboard.Cards do
  use Phoenix.Component

  attr :title, :string, required: true
  attr :value, :any, required: true
  attr :subtitle, :string, default: nil
  attr :status, :atom, default: nil  # :ok, :warning, :error

  def stat_card(assigns) do
    ~H"""
    <div class="or-card px-[18px] py-4">
      <div class="text-xs" style="color: var(--or-fg-muted);">{@title}</div>
      <span class="text-[30px] font-bold tracking-tight leading-none"
            style="color: var(--or-fg-base);">
        {@value}
      </span>
      <div :if={@subtitle} class="mt-2.5 text-[11px]" style="color: var(--or-fg-subtle);">
        {@subtitle}
      </div>
    </div>
    """
  end
end
```

**Step 2: Create node table component**

Shows each node with: name, status badge, ring %, reachability indicator, memory, gets, puts.

**Step 3: Create connection indicator component**

Shows WebSocket connection state (Live / Reconnecting / Mock Mode).

**Step 4: Build ClusterLive**

Mount: assigns `ws_connected: false, cluster: nil, node_stats: %{}`.

Handle WebSocket events:
- `handle_event("riak_cluster", data, socket)` → updates cluster assigns
- `handle_event("riak_node_stats", data, socket)` → updates node_stats
- `handle_event("ws_connected", _, socket)` → sets ws_connected: true
- `handle_event("ws_disconnected", _, socket)` → sets ws_connected: false

Render: RiakEvents hook div with data attributes, connection indicator, stat cards (cluster name, ring size, node count, status), node table, DC list.

For mock mode: use `Process.send_after` polling fallback when no WebSocket URL configured.

**Step 5: Add route**

```elixir
live "/", ClusterLive, :index
```

**Step 6: Run and verify**

```bash
mix phx.server
```

Dashboard shows mock cluster data with 5 nodes.

**Step 7: Commit**

```bash
git add -A && git commit -m "feat: add cluster overview dashboard with stat cards and node table"
```

---

## Task 8: Ring Visualization LiveView

**Files:**
- Create: `lib/riak_dashboard_web/live/ring_live.ex`
- Create: `lib/riak_dashboard_web/components/dashboard/ring_chart.ex`
- Modify: `lib/riak_dashboard_web/router.ex`

**Step 1: Create ring chart component**

```elixir
defmodule RiakDashboardWeb.Components.Dashboard.RingChart do
  use Phoenix.Component

  attr :ring, :map, default: nil

  def ring_chart(assigns) do
    ~H"""
    <div id="ring-chart"
         phx-hook="RingChart"
         phx-update="ignore"
         data-ring={@ring && Jason.encode!(@ring)}>
      <canvas width="400" height="400" class="mx-auto"></canvas>
    </div>
    """
  end
end
```

**Step 2: Build RingLive**

Handle `riak_ring` events. Display:
- Canvas ring chart
- Partition count
- Node legend with color swatches
- Node-to-partition count table

**Step 3: Add route**

```elixir
live "/ring", RingLive, :index
```

**Step 4: Verify ring renders with mock data**

**Step 5: Commit**

```bash
git add -A && git commit -m "feat: add ring visualization with canvas chart"
```

---

## Task 9: Node Detail LiveView

**Files:**
- Create: `lib/riak_dashboard_web/live/node_live.ex`
- Modify: `lib/riak_dashboard_web/router.ex`

**Step 1: Build NodeLive**

Receives `:node` param from URL. Subscribes to `node_stats` WebSocket topic.

Displays:
- Node name and status
- Erlang VM section: OTP release, process count, memory breakdown (total, processes, ETS), run queue
- KV metrics section: vnode gets/puts, node gets/puts, read repairs, FSM latencies
- All rendered as stat cards using OpenRiak card styling

**Step 2: Add route**

```elixir
live "/nodes/:node", NodeLive, :show
```

**Step 3: Wire node names in cluster table as links**

```heex
<.link navigate={~p"/nodes/#{node["name"]}"}>
  {node["name"]}
</.link>
```

**Step 4: Verify node detail page renders**

**Step 5: Commit**

```bash
git add -A && git commit -m "feat: add per-node detail view with VM and KV stats"
```

---

## Task 10: Handoff LiveView

**Files:**
- Create: `lib/riak_dashboard_web/live/handoff_live.ex`
- Modify: `lib/riak_dashboard_web/router.ex`

**Step 1: Build HandoffLive**

Subscribes to `handoff` WebSocket topic.

Displays:
- Transfer count badge
- Table of active transfers: raw field (parsed if structured, displayed as-is if not)
- "No active transfers" empty state with green indicator
- Auto-updates via WebSocket events

**Step 2: Add route**

```elixir
live "/handoff", HandoffLive, :index
```

**Step 3: Verify with mock data**

**Step 4: Commit**

```bash
git add -A && git commit -m "feat: add handoff transfer monitoring view"
```

---

## Task 11: AAE LiveView

**Files:**
- Create: `lib/riak_dashboard_web/live/aae_live.ex`
- Modify: `lib/riak_dashboard_web/router.ex`

**Step 1: Build AaeLive**

Subscribes to `aae` WebSocket topic.

Displays:
- Exchange count badge
- Table of active exchanges: raw field
- Empty state when no exchanges active

**Step 2: Add route**

```elixir
live "/aae", AaeLive, :index
```

**Step 3: Verify with mock data**

**Step 4: Commit**

```bash
git add -A && git commit -m "feat: add AAE exchange status view"
```

---

## Task 12: KV Browser — Bucket Listing

**Files:**
- Create: `lib/riak_dashboard_web/live/buckets_live.ex`
- Modify: `lib/riak_dashboard_web/router.ex`

**Step 1: Build BucketsLive**

HTTP polling (not WebSocket — bucket listing is user-initiated, not streaming).

On mount: fetch bucket list via `Client.list_buckets/2`.
Display:
- Table of bucket names with links to key browser
- Type selector dropdown (default type vs named types)
- "List Buckets" button (explicit action — expensive operation warning)
- Loading state

**Step 2: Add route**

```elixir
live "/buckets", BucketsLive, :index
```

**Step 3: Verify with mock data**

**Step 4: Commit**

```bash
git add -A && git commit -m "feat: add bucket listing view"
```

---

## Task 13: KV Browser — Key Listing and Object View

**Files:**
- Create: `lib/riak_dashboard_web/live/keys_live.ex`
- Create: `lib/riak_dashboard_web/live/object_live.ex`
- Modify: `lib/riak_dashboard_web/router.ex`

**Step 1: Build KeysLive**

Receives `:bucket` param. Fetches keys via `Client.list_keys/3`.
Display:
- Key table with links to object detail
- "List Keys" button with warning about full scan
- Pagination support

**Step 2: Build ObjectLive**

Receives `:bucket` and `:key` params. Fetches object via `Client.get_object/4`.
Display:
- Object value (JSON pretty-printed or raw)
- Metadata: content type, vclock, last modified
- Edit button → textarea with save (PUT) capability
- Delete button with confirmation
- Support for typed buckets via query param

**Step 3: Add routes**

```elixir
live "/buckets/:bucket/keys", KeysLive, :index
live "/buckets/:bucket/keys/:key", ObjectLive, :show
live "/types/:type/buckets/:bucket/keys", KeysLive, :index
live "/types/:type/buckets/:bucket/keys/:key", ObjectLive, :show
```

**Step 4: Verify with mock data**

**Step 5: Commit**

```bash
git add -A && git commit -m "feat: add key listing and object CRUD views"
```

---

## Task 14: Bucket Properties View

**Files:**
- Create: `lib/riak_dashboard_web/live/bucket_props_live.ex`
- Modify: `lib/riak_dashboard_web/router.ex`

**Step 1: Build BucketPropsLive**

Receives `:bucket` param. Fetches props via `Client.get_bucket_props/3`.
Display:
- Property table (n_val, allow_mult, last_write_wins, etc.)
- Edit form for common properties
- Reset to defaults button

**Step 2: Add routes**

```elixir
live "/buckets/:bucket/props", BucketPropsLive, :show
live "/types/:type/buckets/:bucket/props", BucketPropsLive, :show
```

**Step 3: Commit**

```bash
git add -A && git commit -m "feat: add bucket properties viewer and editor"
```

---

## Task 15: Polish and Integration

**Files:**
- Modify: all LiveViews for consistent error handling
- Modify: sidebar to highlight active nav item
- Modify: all views for responsive design
- Create: `lib/riak_dashboard_web/live/not_found_live.ex` (404 page)

**Step 1: Active nav highlighting**

Pass current route to sidebar, highlight matching nav item.

**Step 2: Error states**

Every LiveView should handle:
- Loading state (skeleton UI)
- Error state (connection failed banner)
- Empty state (no data yet)

**Step 3: Responsive layout**

Mobile sidebar drawer (from fixoria pattern):
- Hamburger button shows drawer on mobile
- Sidebar overlay on small screens
- Full sidebar on desktop

**Step 4: Dark mode verification**

Test all views in both light and dark mode. Verify:
- OpenRiak tokens switch correctly
- Canvas ring chart colors visible on dark background
- Tables, cards, badges all readable

**Step 5: Quality gates**

```bash
mix compile --warnings-as-errors
mix test
mix format
mix credo --strict
```

**Step 6: Commit**

```bash
git add -A && git commit -m "feat: polish UI, responsive layout, error states, dark mode"
```

---

## Task 16: Production Configuration

**Files:**
- Modify: `config/prod.exs`
- Modify: `config/runtime.exs`
- Create: `rel/overlays/bin/server`
- Create: `rel/overlays/bin/migrate` (noop for us, but expected by phx)

**Step 1: Configure prod settings**

```elixir
# runtime.exs
config :riak_dashboard, :riak_admin_url,
  System.get_env("RIAK_ADMIN_URL") || "http://localhost:8099"

config :riak_dashboard, :riak_ws_url,
  System.get_env("RIAK_WS_URL") || "ws://localhost:8099/api/stream/events"

config :riak_dashboard, :cluster_client, RiakDashboard.Cluster.HttpClient

config :riak_dashboard, :basic_auth,
  username: System.get_env("RIAK_DASHBOARD_USER") || "admin",
  password: System.get_env("RIAK_DASHBOARD_PASS") || "password"
```

**Step 2: Verify release build**

```bash
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix release
```

**Step 3: Commit**

```bash
git add -A && git commit -m "feat: add production configuration and release setup"
```

---

## Summary of Routes (All Cowboy Features Covered)

| Dashboard Route | Cowboy Endpoint(s) | Method |
|---|---|---|
| `/` (Cluster) | `/api/ping`, `/api/cluster/status`, `/api/dcs` | WebSocket + GET |
| `/ring` | `/api/ring/ownership` | WebSocket + GET |
| `/nodes/:node` | `/api/nodes/:node/stats` | WebSocket + GET |
| `/handoff` | `/api/handoff/status` | WebSocket + GET |
| `/aae` | `/api/aae/status` | WebSocket + GET |
| `/buckets` | `/buckets`, `/types/:type/buckets` | GET |
| `/buckets/:b/keys` | `/buckets/:b/keys?keys=true` | GET |
| `/buckets/:b/keys/:k` | `/buckets/:b/keys/:k` | GET/PUT/DELETE |
| `/buckets/:b/props` | `/buckets/:b/props` | GET/PUT |
| `/types/:t/buckets/...` | `/types/:t/buckets/...` | All above typed variants |
| All monitoring views | `/api/stream/events` | WebSocket (ring, cluster, membership, node_stats, handoff, aae, dcs) |

## Task 17: Counter Operations UI

**Files:**
- Create: `lib/riak_dashboard_web/live/counter_live.ex`
- Modify: `lib/riak_dashboard/cluster/client.ex` (add counter callbacks)
- Modify: `lib/riak_dashboard/cluster/http_client.ex`
- Modify: `lib/riak_dashboard/cluster/mock_client.ex`
- Modify: `lib/riak_dashboard_web/router.ex`

**Step 1: Add counter callbacks to client behaviour**

```elixir
@callback get_counter(base_url :: String.t(), bucket :: String.t(), key :: String.t(), opts :: keyword()) :: {:ok, integer()} | {:error, term()}
@callback update_counter(base_url :: String.t(), bucket :: String.t(), key :: String.t(), delta :: integer(), opts :: keyword()) :: :ok | {:error, term()}
```

**Step 2: Implement in HttpClient**

GET `/buckets/:bucket/counters/:key` — response is plain text integer.
POST `/buckets/:bucket/counters/:key` — body is plain text integer delta.

**Step 3: Build CounterLive**

Receives `:bucket` and `:key` params. Displays current value with increment/decrement buttons. Form for custom delta. Shows quorum params.

**Step 4: Add route**

```elixir
live "/buckets/:bucket/counters/:key", CounterLive, :show
```

**Step 5: Commit**

```bash
git add -A && git commit -m "feat: add counter operations view"
```

---

## Task 18: CRDT Operations UI

**Files:**
- Create: `lib/riak_dashboard_web/live/crdt_live.ex`
- Modify: `lib/riak_dashboard/cluster/client.ex` (add CRDT callbacks)
- Modify: `lib/riak_dashboard/cluster/http_client.ex`
- Modify: `lib/riak_dashboard/cluster/mock_client.ex`
- Modify: `lib/riak_dashboard_web/router.ex`

**Step 1: Add CRDT callbacks to client behaviour**

```elixir
@callback get_crdt(base_url :: String.t(), type :: String.t(), bucket :: String.t(), key :: String.t(), opts :: keyword()) :: {:ok, map()} | {:error, term()}
@callback update_crdt(base_url :: String.t(), type :: String.t(), bucket :: String.t(), key :: String.t(), update :: map(), opts :: keyword()) :: {:ok, map()} | {:error, term()}
```

**Step 2: Implement in HttpClient**

GET `/types/:type/buckets/:bucket/datatypes/:key` — returns typed value with context.
POST `/types/:type/buckets/:bucket/datatypes/:key` — sends update operation JSON.

**Step 3: Build CrdtLive**

Receives `:type`, `:bucket`, `:key` params. Displays:
- Type badge (counter/set/map)
- Current value (formatted per type)
- Counter: increment/decrement form
- Set: add/remove elements
- Map: nested key-value editor
- Context passed back on updates

**Step 4: Add route**

```elixir
live "/types/:type/buckets/:bucket/datatypes/:key", CrdtLive, :show
```

**Step 5: Commit**

```bash
git add -A && git commit -m "feat: add CRDT datatype operations view"
```

---

## Task 19: MapReduce Query Builder

**Files:**
- Create: `lib/riak_dashboard_web/live/mapred_live.ex`
- Modify: `lib/riak_dashboard/cluster/client.ex` (add mapred callback)
- Modify: `lib/riak_dashboard/cluster/http_client.ex`
- Modify: `lib/riak_dashboard/cluster/mock_client.ex`
- Modify: `lib/riak_dashboard_web/router.ex`

**Step 1: Add mapred callback to client behaviour**

```elixir
@callback run_mapred(base_url :: String.t(), query :: map(), opts :: keyword()) :: {:ok, term()} | {:error, term()}
```

**Step 2: Implement in HttpClient**

POST `/mapred` — sends query JSON, handles chunked and non-chunked responses.

**Step 3: Build MapredLive**

Displays:
- JSON editor textarea for inputs and query phases
- Run button with loading indicator
- Results panel (pretty-printed JSON)
- Example templates (count keys, map values, etc.)
- Timeout configuration

**Step 4: Add route**

```elixir
live "/mapred", MapredLive, :index
```

**Step 5: Commit**

```bash
git add -A && git commit -m "feat: add MapReduce query builder view"
```

---

## Task 20: Secondary Index Query UI

**Files:**
- Create: `lib/riak_dashboard_web/live/index_query_live.ex`
- Modify: `lib/riak_dashboard/cluster/client.ex` (add 2i callbacks)
- Modify: `lib/riak_dashboard/cluster/http_client.ex`
- Modify: `lib/riak_dashboard/cluster/mock_client.ex`
- Modify: `lib/riak_dashboard_web/router.ex`

**Step 1: Add 2i callbacks to client behaviour**

```elixir
@callback index_query(base_url :: String.t(), bucket :: String.t(), field :: String.t(), term_or_range :: term(), opts :: keyword()) :: {:ok, map()} | {:error, term()}
```

**Step 2: Implement in HttpClient**

GET `/buckets/:bucket/index/:field/:term` (exact match).
GET `/buckets/:bucket/index/:field/:start/:end` (range).
With typed variants.

**Step 3: Build IndexQueryLive**

Displays:
- Bucket and field selectors
- Query type toggle: exact match vs range
- Term/start/end inputs
- max_results and pagination controls
- Results table with continuation support
- Option to return terms alongside keys

**Step 4: Add routes**

```elixir
live "/query/index", IndexQueryLive, :index
```

**Step 5: Commit**

```bash
git add -A && git commit -m "feat: add secondary index query view"
```

---

## Task 21: Bucket Type Properties View

**Files:**
- Create: `lib/riak_dashboard_web/live/type_props_live.ex`
- Modify: `lib/riak_dashboard/cluster/client.ex`
- Modify: `lib/riak_dashboard/cluster/http_client.ex`
- Modify: `lib/riak_dashboard/cluster/mock_client.ex`
- Modify: `lib/riak_dashboard_web/router.ex`

**Step 1: Add type props callbacks**

```elixir
@callback get_type_props(base_url :: String.t(), type :: String.t()) :: {:ok, map()} | {:error, term()}
@callback put_type_props(base_url :: String.t(), type :: String.t(), props :: map()) :: {:ok, map()} | {:error, term()}
```

**Step 2: Build TypePropsLive**

GET `/types/:type/props`, PUT `/types/:type/props`.
Same layout as BucketPropsLive but for types.

**Step 3: Add route**

```elixir
live "/types/:type/props", TypePropsLive, :show
```

**Step 4: Commit**

```bash
git add -A && git commit -m "feat: add bucket type properties view"
```

---

## Summary of Routes (All Cowboy Features Covered)

| Dashboard Route | Cowboy Endpoint(s) | Method |
|---|---|---|
| `/` (Cluster) | `/api/ping`, `/api/cluster/status`, `/api/dcs` | WebSocket + GET |
| `/ring` | `/api/ring/ownership` | WebSocket + GET |
| `/nodes/:node` | `/api/nodes/:node/stats` | WebSocket + GET |
| `/handoff` | `/api/handoff/status` | WebSocket + GET |
| `/aae` | `/api/aae/status` | WebSocket + GET |
| `/buckets` | `/buckets`, `/types/:type/buckets` | GET |
| `/buckets/:b/keys` | `/buckets/:b/keys?keys=true` | GET |
| `/buckets/:b/keys/:k` | `/buckets/:b/keys/:k` | GET/PUT/DELETE |
| `/buckets/:b/props` | `/buckets/:b/props` | GET/PUT/DELETE |
| `/types/:t/buckets/...` | `/types/:t/buckets/...` | All above typed variants |
| `/buckets/:b/counters/:k` | `/buckets/:b/counters/:k` | GET/POST |
| `/types/:t/.../datatypes/:k` | `/types/:t/.../datatypes/:k` | GET/POST |
| `/mapred` | `/mapred` | GET/POST |
| `/query/index` | `/buckets/:b/index/:f/:t`, `.../:f/:s/:e` | GET |
| `/types/:t/props` | `/types/:t/props` | GET/PUT |
| All monitoring views | `/api/stream/events` | WebSocket (ring, cluster, membership, node_stats, handoff, aae, dcs) |

**Reference documents:**
- `doc/API_REFERENCE.md` — All HTTP endpoints, request/response shapes, error codes
- `doc/WEBSOCKET_SPEC.md` — WebSocket topics, frame formats, subscription protocol
- `doc/LIVEVIEW_INTEGRATION.md` — LiveView integration patterns, hooks, component examples
