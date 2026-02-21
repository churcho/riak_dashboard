# Cluster Selector Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the "Cluster" sidebar nav link with a dropdown selector that shows the current cluster and lets users switch to remote DCs, reconnecting the WebSocket on switch.

**Architecture:** The sidebar is rendered from the app layout (`layouts.ex`) which only sees LiveView assigns. We'll pass cluster data (name + remote_dcs) up through assigns so the sidebar can render the selector. The selector triggers a `phx-click` event that updates `ws_url`, and the JS hook handles disconnect/reconnect.

**Tech Stack:** Phoenix LiveView 1.0, daisyUI dropdown, existing SVG icons, RiakEvents JS hook

---

### Task 1: Remove "Cluster" from nav, add selector attrs to sidebar

**Files:**
- Modify: `lib/riak_dashboard_web/components/dashboard/shell.ex`

**Step 1: Remove "Cluster" from nav_sections**

In `@nav_sections`, remove the Cluster item from the MONITORING section (line 20). The list should start with Ring.

```elixir
@nav_sections [
  %{
    label: "MONITORING",
    items: [
      %{name: "Ring", icon: "ring", path: "/ring"},
      %{name: "Nodes", icon: "server", path: "/nodes"},
      %{name: "Handoff", icon: "transfer", path: "/handoff"},
      %{name: "AAE", icon: "shield", path: "/aae"}
    ]
  },
  # ... rest unchanged
]
```

**Step 2: Add cluster selector attrs to `sidebar/1`**

Add new attrs and pass them through to `sidebar_content`:

```elixir
attr(:active_nav, :string, required: true)
attr(:mobile, :boolean, default: false)
attr(:cluster_name, :string, default: nil)
attr(:remote_dcs, :list, default: [])
attr(:cluster_selector_open, :boolean, default: false)
```

Pass them in the `sidebar_content` call:

```elixir
<.sidebar_content
  nav_sections={@nav_sections}
  active_nav={@active_nav}
  mobile={@mobile}
  cluster_name={@cluster_name}
  remote_dcs={@remote_dcs}
  cluster_selector_open={@cluster_selector_open}
/>
```

And add matching attrs to `sidebar_content/1`.

**Step 3: Add cluster selector component between logo and nav**

After the logo `</div>` and before the `<nav>` tag, add:

```heex
<%!-- Cluster Selector --%>
<div :if={@cluster_name} class="px-2.5 pb-2">
  <button
    type="button"
    phx-click="toggle_cluster_selector"
    class="flex items-center gap-2.5 w-full px-2.5 py-2 rounded-lg border border-[#E0DDD6] bg-[#F0EDE7] hover:bg-[#E8E5DE] transition-colors duration-150 dark:border-[#334155] dark:bg-[#334155] dark:hover:bg-[#3D4F63]"
  >
    <span class="flex flex-shrink-0">
      <.nav_icon name="dashboard" />
    </span>
    <span class="flex-1 text-left min-w-0">
      <span class="block text-[10px] text-[#A8A8A8] dark:text-[#94A3B8] leading-none mb-0.5">Cluster</span>
      <span class="block text-[13px] font-semibold text-[#1A1A1A] dark:text-[#F8FAFC] truncate leading-tight">
        {@cluster_name}
      </span>
    </span>
    <.nav_icon name="chevron-down" class={"flex-shrink-0 text-[#A8A8A8] dark:text-[#94A3B8] transition-transform duration-150 #{if @cluster_selector_open, do: "rotate-180", else: ""}"} />
  </button>

  <div
    :if={@cluster_selector_open and @remote_dcs != []}
    class="mt-1 rounded-lg border border-[#E0DDD6] bg-white overflow-hidden dark:border-[#334155] dark:bg-[#1E293B]"
  >
    <div
      :for={dc <- @remote_dcs}
      phx-click="select_cluster"
      phx-value-name={dc["name"]}
      phx-value-url={dc["admin_url"]}
      class="flex items-center gap-2 px-3 py-2 text-[12px] text-[#5A5A5A] hover:bg-[#F5F3EF] cursor-pointer transition-colors duration-100 dark:text-[#94A3B8] dark:hover:bg-[#243447]"
    >
      <span class="w-1.5 h-1.5 rounded-full bg-[#A8A8A8]" />
      <span class="truncate">{dc["name"]}</span>
    </div>
  </div>
</div>
```

**Step 4: Compile and verify**

Run: `mix compile`
Expected: Clean compilation (no errors, no warnings)

**Step 5: Commit**

```bash
git add lib/riak_dashboard_web/components/dashboard/shell.ex
git commit -m "Add cluster selector component to sidebar, remove Cluster nav link"
```

---

### Task 2: Pass cluster data from LiveView through layout to sidebar

**Files:**
- Modify: `lib/riak_dashboard_web/components/layouts.ex`
- Modify: `lib/riak_dashboard_web/live/cluster_live.ex`

**Step 1: Update layout to pass cluster data to sidebar**

In `layouts.ex`, the `app/1` function renders `<.sidebar>`. Update it to pass the new attrs:

```elixir
<.sidebar
  active_nav={assigns[:active_nav] || "Cluster"}
  cluster_name={assigns[:cluster_name]}
  remote_dcs={assigns[:remote_dcs] || []}
  cluster_selector_open={assigns[:cluster_selector_open] || false}
/>
```

**Step 2: Add cluster state assigns in ClusterLive mount**

In `cluster_live.ex` `mount/3`, add to the assigns:

```elixir
cluster_name: nil,
remote_dcs: [],
cluster_selector_open: false,
```

**Step 3: Extract cluster_name and remote_dcs when cluster data arrives**

In the `handle_event("riak_cluster", data, socket)` handler, update to also extract the cluster info:

```elixir
def handle_event("riak_cluster", data, socket) do
  {:noreply,
   assign(socket,
     cluster: data,
     loading: false,
     cluster_name: data["cluster_name"],
     remote_dcs: data["remote_dcs"] || []
   )}
end
```

**Step 4: Add toggle handler**

Add a new `handle_event` for the dropdown toggle:

```elixir
def handle_event("toggle_cluster_selector", _, socket) do
  {:noreply, assign(socket, cluster_selector_open: !socket.assigns.cluster_selector_open)}
end
```

**Step 5: Compile and verify**

Run: `mix compile`
Expected: Clean compilation

**Step 6: Commit**

```bash
git add lib/riak_dashboard_web/components/layouts.ex lib/riak_dashboard_web/live/cluster_live.ex
git commit -m "Wire cluster data from LiveView through layout to sidebar selector"
```

---

### Task 3: Handle cluster switching with WebSocket reconnection

**Files:**
- Modify: `lib/riak_dashboard_web/live/cluster_live.ex`
- Modify: `assets/js/hooks/riak_events.js`

**Step 1: Add select_cluster event handler in ClusterLive**

```elixir
def handle_event("select_cluster", %{"name" => name, "url" => admin_url}, socket) do
  # Derive WebSocket URL from admin_url (replace http with ws, append stream path)
  ws_url =
    admin_url
    |> String.replace_prefix("http://", "ws://")
    |> String.replace_prefix("https://", "wss://")
    |> String.trim_trailing("/")
    |> Kernel.<>("/api/stream/events")

  {:noreply,
   assign(socket,
     ws_url: ws_url,
     ws_status: :connecting,
     cluster: nil,
     cluster_name: name,
     remote_dcs: [],
     node_stats: %{},
     loading: true,
     cluster_selector_open: false
   )}
end
```

**Step 2: Update RiakEvents JS hook to support URL changes**

The hook needs to watch for `data-ws-url` changes and reconnect. Update `riak_events.js`:

```javascript
const RiakEvents = {
  mounted() {
    this.currentUrl = this.el.dataset.wsUrl;
    const topics = JSON.parse(this.el.dataset.topics || '["cluster"]');
    this.topics = topics;
    this.reconnectAttempts = 0;

    if (this.currentUrl) {
      this.connect(this.currentUrl, topics);
    } else {
      this.pushEvent("ws_not_configured", {});
    }
  },

  updated() {
    const newUrl = this.el.dataset.wsUrl;
    if (newUrl && newUrl !== this.currentUrl) {
      this.currentUrl = newUrl;
      this.disconnect();
      this.reconnectAttempts = 0;
      this.connect(newUrl, this.topics);
    }
  },

  connect(url, topics) {
    this.ws = new WebSocket(url);

    this.ws.onopen = () => {
      this.reconnectAttempts = 0;
      this.ws.send(JSON.stringify({action: "subscribe", topics: topics}));
      this.pushEvent("ws_connected", {});
    };

    this.ws.onmessage = (evt) => {
      const msg = JSON.parse(evt.data);
      if (msg.type === "event" || msg.type === "snapshot") {
        this.pushEvent("riak_" + msg.topic, msg.data);
      } else if (msg.type === "backpressure") {
        this.pushEvent("ws_backpressure", msg);
      } else if (msg.type === "error") {
        this.pushEvent("ws_error", msg);
      }
    };

    this.ws.onclose = () => {
      this.pushEvent("ws_disconnected", {});
      if (!this._intentionalClose) {
        const delay = Math.min(1000 * Math.pow(2, this.reconnectAttempts), 30000);
        this.reconnectAttempts++;
        this._reconnectTimer = setTimeout(() => this.connect(url, topics), delay);
      }
    };

    this.ws.onerror = () => this.ws.close();
  },

  disconnect() {
    this._intentionalClose = true;
    if (this._reconnectTimer) clearTimeout(this._reconnectTimer);
    if (this.ws) this.ws.close();
    this._intentionalClose = false;
  },

  destroyed() {
    this._intentionalClose = true;
    if (this._reconnectTimer) clearTimeout(this._reconnectTimer);
    if (this.ws) this.ws.close();
  }
};

export default RiakEvents;
```

Key changes:
- Track `currentUrl` and `topics` as instance properties
- Add `updated()` lifecycle hook that detects URL changes and reconnects
- Extract `disconnect()` method with `_intentionalClose` flag to prevent auto-reconnect during intentional switches

**Step 3: Compile and verify**

Run: `mix compile`
Expected: Clean compilation

**Step 4: Commit**

```bash
git add lib/riak_dashboard_web/live/cluster_live.ex assets/js/hooks/riak_events.js
git commit -m "Handle cluster switching with WebSocket disconnect/reconnect"
```

---

### Task 4: Clean up router and handle_params

**Files:**
- Modify: `lib/riak_dashboard_web/router.ex`
- Modify: `lib/riak_dashboard_web/live/cluster_live.ex`

**Step 1: Remove duplicate route**

In `router.ex`, the `/nodes` route is redundant now (Nodes is a separate nav link pointing to the same view). Keep it but update the Cluster path handling:

The `/` route stays as the cluster overview. The `/nodes` route stays for direct node access. No changes needed to the router.

**Step 2: Simplify handle_params**

In `cluster_live.ex`, update `handle_params` since "Cluster" is no longer a nav item — the `/` path should not highlight anything in the nav (the cluster selector handles it):

```elixir
def handle_params(_params, uri, socket) do
  path = URI.parse(uri).path
  active_nav = if path == "/nodes", do: "Nodes", else: nil
  {:noreply, assign(socket, active_nav: active_nav)}
end
```

Actually, since "/" still renders the cluster overview and "Nodes" is still a nav link, keep the current behavior but just handle the nil case for "/" since "Cluster" is gone from the nav:

```elixir
def handle_params(_params, uri, socket) do
  path = URI.parse(uri).path
  active_nav = if path == "/nodes", do: "Nodes", else: ""
  {:noreply, assign(socket, active_nav: active_nav)}
end
```

**Step 3: Compile and verify**

Run: `mix compile`
Expected: Clean compilation

**Step 4: Commit**

```bash
git add lib/riak_dashboard_web/live/cluster_live.ex
git commit -m "Simplify handle_params now that Cluster is a selector, not a nav link"
```

---

### Task 5: Update mock data with sample remote DCs for testing

**Files:**
- Modify: `test/support/riak_stubs.ex`

**Step 1: Add remote DC entries to mock cluster data**

In `riak_stubs.ex`, update the `cluster_status` function to include sample remote DCs so the selector dropdown has entries to display in dev mode:

```elixir
"remote_dcs" => [
  %{
    "name" => "us-west-2",
    "admin_url" => "http://10.0.2.1:8098",
    "riak_version" => "3.2.0"
  },
  %{
    "name" => "eu-central-1",
    "admin_url" => "http://10.0.3.1:8098",
    "riak_version" => "3.2.0"
  }
],
"total_dcs" => 3
```

**Step 2: Compile and verify**

Run: `mix compile`
Expected: Clean compilation

**Step 3: Commit**

```bash
git add test/support/riak_stubs.ex
git commit -m "Add sample remote DCs to mock data for cluster selector testing"
```

---

### Task 6: Visual testing and polish

**Step 1: Start dev server and open browser**

```bash
source local.env && mix phx.server
agent-browser --headed open http://admin:password@localhost:4000
```

**Step 2: Verify cluster selector renders**

- Cluster selector should appear below logo, above MONITORING section
- Shows "Cluster" label + cluster name
- "Cluster" should NOT appear in nav items

**Step 3: Test dropdown behavior**

- Click the selector button — dropdown should open showing remote DCs
- Click again — dropdown should close
- Verify chevron rotates on open/close

**Step 4: Test cluster switching**

- Click a remote DC — should show loading state, attempt WebSocket reconnection
- Cluster name in selector should update to the selected DC name

**Step 5: Test dark mode**

- Toggle to dark mode
- Verify selector styling adapts (dark backgrounds, light text)

**Step 6: Screenshot evidence**

```bash
agent-browser screenshot evidence-cluster-selector.png
```

**Step 7: Commit any polish fixes**

```bash
git add -A
git commit -m "Polish cluster selector styling and dark mode support"
```
