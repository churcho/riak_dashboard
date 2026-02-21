defmodule RiakDashboardWeb.ClusterLive do
  use RiakDashboardWeb, :live_view

  alias RiakDashboard.MetricStore

  import RiakDashboardWeb.Components.Dashboard.Cards
  import RiakDashboardWeb.Components.Dashboard.Feedback
  import RiakDashboardWeb.Components.Dashboard.MetricChart
  import RiakDashboardWeb.Components.Dashboard.NodeChips

  @node_color_palette [
    "#c2185b",
    "#1565c0",
    "#2e7d32",
    "#f9a825",
    "#6a1b9a",
    "#00838f",
    "#d84315",
    "#00897b",
    "#5c6bc0",
    "#f4511e",
    "#8e24aa",
    "#039be5",
    "#7cb342",
    "#ffb300",
    "#e53935",
    "#3949ab",
    "#43a047",
    "#fb8c00",
    "#d81b60",
    "#00acc1"
  ]

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    ws_url = Application.get_env(:riak_dashboard, :riak_ws_url)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(RiakDashboard.PubSub, "metrics:updated")
    end

    socket =
      assign(socket,
        page_title: "Cluster",
        active_nav: "Cluster",
        ws_url: ws_url,
        ws_status: :connecting,
        cluster: nil,
        cluster_name: nil,
        remote_dcs: [],
        node_stats: %{},
        ring: nil,
        node_dist: [],
        aae_count: 0,
        handoff_count: 0,
        selected_node: nil,
        open_node_menu: nil,
        node_clear_modal_node: nil,
        selected_metric: "memory_total",
        selected_metric_group: "memory",
        selected_range: :recent,
        show_reset_modal: false,
        chart_data: [],
        chart_unit: "",
        last_chart_query_at: 0,
        loading: true,
        error: nil,
        topics_json: Jason.encode!(~w(cluster node_stats ring aae handoff))
      )

    {:ok, socket}
  end

  @impl true
  @spec handle_params(map(), String.t(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_params(_params, uri, socket) do
    path = URI.parse(uri).path
    active_nav = if path == "/nodes", do: "Nodes", else: nil
    {:noreply, assign(socket, active_nav: active_nav)}
  end

  # WebSocket lifecycle
  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("ws_connected", _, socket) do
    {:noreply, assign(socket, ws_status: :connected)}
  end

  def handle_event("ws_disconnected", _, socket) do
    {:noreply, assign(socket, ws_status: :disconnected)}
  end

  def handle_event("ws_not_configured", _, socket) do
    {:noreply,
     assign(socket,
       ws_status: :not_configured,
       loading: false,
       error: "Riak WebSocket URL not configured. Set RIAK_WS_URL to enable real-time updates."
     )}
  end

  # Data events
  def handle_event("riak_cluster", data, socket) do
    selected =
      socket.assigns.selected_node ||
        case data["nodes"] do
          [first | _] -> first["name"]
          _ -> nil
        end

    socket =
      assign(socket,
        cluster: data,
        loading: false,
        cluster_name: sanitize_cluster_name(data["cluster_name"]),
        remote_dcs: data["remote_dcs"] || [],
        selected_node: selected
      )

    {:noreply, refresh_chart_data(socket)}
  end

  def handle_event("riak_node_stats", data, socket) do
    MetricStore.record(data)
    Phoenix.PubSub.broadcast(RiakDashboard.PubSub, "metrics:updated", :ok)

    {:noreply, assign(socket, node_stats: data)}
  end

  def handle_event("riak_ring", data, socket) when is_map(data) do
    {:noreply, assign(socket, ring: data, node_dist: node_distribution(data))}
  end

  def handle_event("riak_aae", data, socket) when is_map(data) do
    {:noreply, assign(socket, aae_count: data["count"] || 0)}
  end

  def handle_event("riak_handoff", data, socket) when is_map(data) do
    {:noreply, assign(socket, handoff_count: data["count"] || 0)}
  end

  def handle_event("riak_membership", _data, socket), do: {:noreply, socket}
  def handle_event("riak_dcs", _data, socket), do: {:noreply, socket}
  def handle_event("ws_backpressure", _data, socket), do: {:noreply, socket}
  def handle_event("ws_error", _data, socket), do: {:noreply, socket}

  # UI events
  def handle_event("select_cluster", %{"name" => name}, socket) do
    if name == socket.assigns.cluster_name do
      {:noreply, socket}
    else
      case Enum.find(socket.assigns.remote_dcs, &(&1["name"] == name)) do
        nil ->
          {:noreply, socket}

        dc ->
          ws_url = derive_ws_url(dc["admin_url"])

          {:noreply,
           assign(socket,
             ws_url: ws_url,
             ws_status: :connecting,
             cluster: nil,
             cluster_name: name,
             remote_dcs: [],
             node_stats: %{},
             ring: nil,
             node_dist: [],
             aae_count: 0,
             handoff_count: 0,
             selected_node: nil,
             open_node_menu: nil,
             node_clear_modal_node: nil,
             selected_metric_group: "memory",
             selected_range: :recent,
             show_reset_modal: false,
             chart_data: [],
             chart_unit: "",
             last_chart_query_at: 0,
             loading: true
           )}
      end
    end
  end

  def handle_event("select_node", %{"node" => node_name}, socket) do
    socket = assign(socket, selected_node: node_name, open_node_menu: nil)
    {:noreply, refresh_chart_data(socket)}
  end

  def handle_event("select_metric", %{"metric" => key}, socket) do
    socket =
      assign(socket,
        selected_metric: key,
        selected_metric_group: metric_group_for(key)
      )

    {:noreply, refresh_chart_data(socket)}
  end

  def handle_event("select_metric_group", %{"group" => group_key}, socket) do
    selected_metric =
      if metric_group_for(socket.assigns.selected_metric) == group_key do
        socket.assigns.selected_metric
      else
        default_metric_for_group(group_key)
      end

    {:noreply,
     assign(socket,
       selected_metric_group: group_key,
       selected_metric: selected_metric
     )}
  end

  def handle_event("select_range", %{"range" => range}, socket) do
    socket = assign(socket, selected_range: range_from_param(range))
    {:noreply, refresh_chart_data(socket)}
  end

  def handle_event("open_reset_modal", _params, socket) do
    {:noreply, assign(socket, show_reset_modal: true)}
  end

  def handle_event("close_reset_modal", _params, socket) do
    {:noreply, assign(socket, show_reset_modal: false)}
  end

  def handle_event("confirm_reset_metrics", _params, socket) do
    MetricStore.reset()
    Phoenix.PubSub.broadcast(RiakDashboard.PubSub, "metrics:updated", :ok)
    socket = assign(socket, show_reset_modal: false)
    {:noreply, refresh_chart_data(socket)}
  end

  def handle_event("toggle_node_actions", %{"node" => node_name}, socket) do
    open_node_menu =
      if socket.assigns.open_node_menu == node_name do
        nil
      else
        node_name
      end

    {:noreply, assign(socket, open_node_menu: open_node_menu)}
  end

  def handle_event("close_node_actions", _params, socket) do
    {:noreply, assign(socket, open_node_menu: nil)}
  end

  def handle_event("open_node_clear_modal", %{"node" => node_name}, socket) do
    {:noreply, assign(socket, node_clear_modal_node: node_name, open_node_menu: nil)}
  end

  def handle_event("close_node_clear_modal", _params, socket) do
    {:noreply, assign(socket, node_clear_modal_node: nil)}
  end

  def handle_event("confirm_delete_node_history", %{"node" => node_name}, socket) do
    MetricStore.delete_node(node_name)
    Phoenix.PubSub.broadcast(RiakDashboard.PubSub, "metrics:updated", :ok)
    socket = assign(socket, node_clear_modal_node: nil)
    {:noreply, refresh_chart_data(socket)}
  end

  @impl true
  @spec handle_info(term(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_info(:ok, socket) do
    elapsed = System.monotonic_time(:second) - socket.assigns.last_chart_query_at
    interval = chart_refresh_interval(socket.assigns.selected_range)

    if elapsed >= interval do
      {:noreply, refresh_chart_data(socket)}
    else
      {:noreply, socket}
    end
  end

  # Private helpers

  defp chart_refresh_interval(:recent), do: 0
  defp chart_refresh_interval(:hour), do: 10
  defp chart_refresh_interval(:day), do: 60
  defp chart_refresh_interval(:week), do: 300

  defp refresh_chart_data(socket) do
    assigns = socket.assigns

    data =
      chart_data_for_range(assigns.selected_node, assigns.selected_metric, assigns.selected_range)

    unit = metric_unit(assigns.selected_metric)

    assign(socket,
      chart_data: data,
      chart_unit: unit,
      last_chart_query_at: System.monotonic_time(:second)
    )
  end

  @metric_units %{
    "memory_total" => "MB",
    "memory_processes" => "MB",
    "memory_ets" => "MB",
    "get_latency" => "\u00B5s",
    "put_latency" => "\u00B5s"
  }
  defp metric_unit(key), do: Map.get(@metric_units, key, "")

  defp chart_data_for_range(nil, _metric_key, _range), do: []

  defp chart_data_for_range(node_name, metric_key, range) do
    metric_atom = metric_key_to_atom(metric_key)

    node_name
    |> MetricStore.query(range)
    |> Enum.map(fn {ts, metrics} ->
      %{ts: ts, value: Map.get(metrics, metric_atom, 0)}
    end)
  end

  defp ring_balanced?([]), do: true

  defp ring_balanced?(node_dist) do
    counts = Enum.map(node_dist, & &1.count)
    Enum.max(counts) - Enum.min(counts) <= 1
  end

  defp short_node_name(nil), do: "-"

  defp short_node_name(name) when is_binary(name) do
    name |> String.split("@") |> hd()
  end

  defp sanitize_cluster_name(nil), do: nil

  defp sanitize_cluster_name(name) when is_binary(name) do
    case Regex.run(~r/\{'([^']+)'/, name) do
      [_, node_name] -> node_name
      _ -> name
    end
  end

  defp derive_ws_url(admin_url) do
    admin_url
    |> String.replace_prefix("http://", "ws://")
    |> String.replace_prefix("https://", "wss://")
    |> String.trim_trailing("/")
    |> Kernel.<>("/api/stream/events")
  end

  defp node_distribution(ring) do
    counts = Enum.frequencies_by(ring["partitions"], & &1["node"])
    total = length(ring["partitions"])
    palette_size = length(@node_color_palette)

    counts
    |> Enum.sort_by(fn {node, _count} -> node end)
    |> Enum.with_index()
    |> Enum.map(fn {{node, count}, idx} ->
      color_idx = rem(node_color_hash(node) + idx, palette_size)

      %{
        node: node,
        color: Enum.at(@node_color_palette, color_idx),
        count: count,
        pct: Float.round(count / total * 100, 1)
      }
    end)
    |> dedup_adjacent_colors()
  end

  defp node_color_hash(node_name) do
    :erlang.phash2(node_name, length(@node_color_palette))
  end

  defp dedup_adjacent_colors(dists) do
    palette_size = length(@node_color_palette)

    dists
    |> Enum.reduce([], fn dist, acc ->
      case acc do
        [prev | _] when prev.color == dist.color ->
          new_idx = rem(node_color_hash(dist.node) + 7, palette_size)
          [%{dist | color: Enum.at(@node_color_palette, new_idx)} | acc]

        _ ->
          [dist | acc]
      end
    end)
    |> Enum.reverse()
  end

  @range_atoms %{"recent" => :recent, "hour" => :hour, "day" => :day, "week" => :week}
  defp range_from_param(key), do: Map.get(@range_atoms, key, :recent)

  @metric_atom_keys ~w(
    memory_total memory_processes memory_ets
    vnode_gets vnode_puts node_gets node_puts
    get_latency put_latency
    processes run_queue read_repairs
  )a
  @metric_atoms Map.new(@metric_atom_keys, fn key -> {Atom.to_string(key), key} end)
  defp metric_key_to_atom(key), do: Map.get(@metric_atoms, key, :memory_total)

  @metric_groups_map %{
    "memory_total" => "memory",
    "memory_processes" => "memory",
    "memory_ets" => "memory",
    "vnode_gets" => "throughput",
    "vnode_puts" => "throughput",
    "node_gets" => "throughput",
    "node_puts" => "throughput",
    "get_latency" => "latency",
    "put_latency" => "latency",
    "processes" => "system",
    "run_queue" => "system",
    "read_repairs" => "system"
  }
  defp metric_group_for(key), do: Map.get(@metric_groups_map, key, "memory")

  @default_metrics %{
    "memory" => "memory_total",
    "throughput" => "vnode_gets",
    "latency" => "get_latency",
    "system" => "processes"
  }
  defp default_metric_for_group(group), do: Map.get(@default_metrics, group, "memory_total")

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div
      id="riak-events"
      phx-hook="RiakEvents"
      data-ws-url={@ws_url}
      data-topics={@topics_json}
    >
      <.loading_text :if={@loading} label="Loading cluster data..." />

      <%= if @cluster do %>
        <%!-- Section 1: Summary Cards --%>
        <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3 mb-6">
          <.stat_card
            title="Cluster"
            value={@cluster_name}
            subtitle={"Claimant: #{short_node_name(@cluster["claimant"])}"}
            tooltip={"#{@cluster_name}\nClaimant: #{@cluster["claimant"]}"}
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

        <%!-- Section 2: Ring Distribution --%>
        <div
          :if={@ring}
          class="mb-6 bg-white rounded-xl border border-[#EEEDEA] px-4 py-3 dark:bg-[var(--or-bg-surface)] dark:border-[var(--or-border-base)]"
        >
          <%!-- Header row --%>
          <div class="flex items-center justify-between mb-2.5">
            <div class="flex items-center gap-3">
              <h3 class="text-xs font-semibold uppercase tracking-wider text-[#8A8A8A] dark:text-[#94A3B8]">
                Ring
              </h3>
              <span class="text-xs text-[#1A1A1A] dark:text-[#E2E8F0]">
                <span class="font-bold tabular-nums">{length(@ring["partitions"])}</span>
                <span class="text-[#8A8A8A] dark:text-[#94A3B8]">partitions</span>
              </span>
            </div>
            <div class="flex items-center gap-3 text-xs">
              <%= if ring_balanced?(@node_dist) do %>
                <span class="inline-flex items-center gap-1 text-[#22c55e]">
                  <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
                    <circle
                      cx="6"
                      cy="6"
                      r="5"
                      stroke="currentColor"
                      stroke-width="1.5"
                      opacity="0.3"
                    />
                    <path
                      d="M3.5 6L5.5 8L8.5 4"
                      stroke="currentColor"
                      stroke-width="1.5"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    />
                  </svg>
                  <span class="font-medium">Balanced</span>
                </span>
              <% else %>
                <span class="inline-flex items-center gap-1 text-[#f59e0b]">
                  <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
                    <path d="M6 2L11 10H1L6 2Z" stroke="currentColor" stroke-width="1.2" fill="none" />
                    <line
                      x1="6"
                      y1="5"
                      x2="6"
                      y2="7.5"
                      stroke="currentColor"
                      stroke-width="1.2"
                      stroke-linecap="round"
                    />
                    <circle cx="6" cy="8.8" r="0.6" fill="currentColor" />
                  </svg>
                  <span class="font-medium">Uneven</span>
                </span>
              <% end %>
              <span class="text-[#8A8A8A] dark:text-[#94A3B8]">
                Claimant
                <span class="font-mono font-medium text-[#1A1A1A] dark:text-[#E2E8F0] ml-0.5">
                  {short_node_name(@cluster["claimant"])}
                </span>
              </span>
            </div>
          </div>

          <%!-- Stacked distribution bar --%>
          <div class="flex h-2.5 rounded-full overflow-hidden gap-px bg-[#F5F3EF] dark:bg-[#334155]">
            <div
              :for={dist <- @node_dist}
              class="h-full first:rounded-l-full last:rounded-r-full transition-all duration-300"
              style={"width: #{dist.pct}%; background-color: #{dist.color};"}
            />
          </div>

          <%!-- Legend --%>
          <div class="flex flex-wrap items-center gap-x-4 gap-y-1 mt-2.5">
            <div
              :for={dist <- @node_dist}
              class="flex items-center gap-1.5 text-[11px]"
            >
              <span
                class="w-2.5 h-2.5 rounded-sm shrink-0"
                style={"background-color: #{dist.color};"}
              />
              <span class="font-mono text-[#1A1A1A] dark:text-[#E2E8F0] truncate">
                {short_node_name(dist.node)}
              </span>
              <span class="text-[#8A8A8A] dark:text-[#6B7280] tabular-nums">
                {dist.count}
              </span>
              <span class="text-[#A8A8A8] dark:text-[#6B7280] tabular-nums">
                ({dist.pct}%)
              </span>
            </div>
          </div>
        </div>

        <%!-- Section 3: Node Chips --%>
        <div class="mb-6">
          <h2 class="text-xs font-semibold uppercase tracking-wider text-[#8A8A8A] dark:text-[#94A3B8] mb-3">
            Nodes
          </h2>
          <.node_chips
            nodes={@cluster["nodes"]}
            selected_node={@selected_node}
            open_node_menu={@open_node_menu}
            node_dist={@node_dist}
            node_stats={@node_stats}
          />
        </div>

        <%!-- Section 4: Metric Chart --%>
        <div :if={@selected_node} class="mb-6">
          <.metric_chart
            selected_metric={@selected_metric}
            selected_metric_group={@selected_metric_group}
            selected_range={@selected_range}
            data={@chart_data}
            unit={@chart_unit}
          />
        </div>

        <%!-- Section 5: Remote Datacenters --%>
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
              <div class="font-semibold text-sm text-[#1A1A1A] dark:text-[var(--or-fg-base)]">
                {dc["name"]}
              </div>
              <div class="text-xs mt-1 text-[#8A8A8A] dark:text-[var(--or-fg-muted)]">
                {dc["admin_url"]} &middot; v{dc["riak_version"]}
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <.dialog_modal
        id="clear-metric-history-modal"
        show={@show_reset_modal}
        title="Clear all metric history?"
        message="This will remove persisted and in-memory metric history for every node across all ranges (5m, 1h, 24h, 7d). This action cannot be undone."
        variant={:error}
        on_cancel="close_reset_modal"
      >
        <:actions>
          <button
            type="button"
            phx-click="confirm_reset_metrics"
            class="inline-flex w-full justify-center rounded-md bg-[#DC2626] px-3 py-2 text-sm font-semibold text-white hover:bg-[#B91C1C] sm:w-auto"
          >
            Clear all history
          </button>
          <button
            type="button"
            phx-click="close_reset_modal"
            class="mt-3 inline-flex w-full justify-center rounded-md border border-[#DDD7CF] bg-white px-3 py-2 text-sm font-semibold text-[#3F3F46] hover:bg-[#F8F6F3] sm:mt-0 sm:w-auto dark:border-[#475569] dark:bg-[#0F172A] dark:text-[#CBD5E1] dark:hover:bg-[#1E293B]"
          >
            Cancel
          </button>
        </:actions>
      </.dialog_modal>

      <.dialog_modal
        id="clear-node-history-modal"
        show={not is_nil(@node_clear_modal_node)}
        title={"Clear history for #{short_node_name(@node_clear_modal_node)}?"}
        message="This removes all stored metric history for the selected node across every range (5m, 1h, 24h, 7d). Other nodes are not affected."
        variant={:error}
        on_cancel="close_node_clear_modal"
      >
        <:actions>
          <button
            :if={@node_clear_modal_node}
            type="button"
            phx-click="confirm_delete_node_history"
            phx-value-node={@node_clear_modal_node}
            class="inline-flex w-full justify-center rounded-md bg-[#DC2626] px-3 py-2 text-sm font-semibold text-white hover:bg-[#B91C1C] sm:w-auto"
          >
            Clear node history
          </button>
          <button
            type="button"
            phx-click="close_node_clear_modal"
            class="mt-3 inline-flex w-full justify-center rounded-md border border-[#DDD7CF] bg-white px-3 py-2 text-sm font-semibold text-[#3F3F46] hover:bg-[#F8F6F3] sm:mt-0 sm:w-auto dark:border-[#475569] dark:bg-[#0F172A] dark:text-[#CBD5E1] dark:hover:bg-[#1E293B]"
          >
            Cancel
          </button>
        </:actions>
      </.dialog_modal>
    </div>
    """
  end
end
