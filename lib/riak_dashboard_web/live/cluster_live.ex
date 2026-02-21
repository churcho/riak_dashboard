defmodule RiakDashboardWeb.ClusterLive do
  use RiakDashboardWeb, :live_view

  import RiakDashboardWeb.Components.Dashboard.Cards
  import RiakDashboardWeb.Components.Dashboard.Feedback
  import RiakDashboardWeb.Components.Dashboard.MetricChart
  import RiakDashboardWeb.Components.Dashboard.NodeChips

  @sparkline_max_points 30
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
  def mount(_params, _session, socket) do
    ws_url = Application.get_env(:riak_dashboard, :riak_ws_url)

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
        sparkline_history: %{},
        selected_metric: "memory",
        loading: true,
        error: nil,
        topics_json: Jason.encode!(~w(cluster node_stats ring aae handoff))
      )

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, uri, socket) do
    path = URI.parse(uri).path
    active_nav = if path == "/nodes", do: "Nodes", else: nil
    {:noreply, assign(socket, active_nav: active_nav)}
  end

  # WebSocket lifecycle
  @impl true
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

    {:noreply,
     assign(socket,
       cluster: data,
       loading: false,
       cluster_name: sanitize_cluster_name(data["cluster_name"]),
       remote_dcs: data["remote_dcs"] || [],
       selected_node: selected
     )}
  end

  def handle_event("riak_node_stats", data, socket) do
    history = update_sparkline_history(socket.assigns.sparkline_history, data)

    {:noreply, assign(socket, node_stats: data, sparkline_history: history)}
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
             sparkline_history: %{},
             loading: true
           )}
      end
    end
  end

  def handle_event("select_node", %{"node" => node_name}, socket) do
    {:noreply, assign(socket, selected_node: node_name)}
  end

  def handle_event("select_metric", %{"metric" => key}, socket) do
    {:noreply, assign(socket, selected_metric: key)}
  end

  # Private helpers

  defp metric_unit("memory"), do: "MB"
  defp metric_unit("get_latency"), do: "\u00B5s"
  defp metric_unit("put_latency"), do: "\u00B5s"
  defp metric_unit(_), do: ""

  defp chart_data_for(sparkline_history, node, metric_key) do
    sparkline_history
    |> Map.get(node, [])
    |> Enum.map(&Map.get(&1, String.to_existing_atom(metric_key), 0))
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

  defp extract_memory_bytes(%{"erlang" => %{"memory_total_mb" => mb}}) when is_number(mb),
    do: round(mb * 1_048_576)

  defp extract_memory_bytes(%{"erlang" => %{"memory" => %{"total" => bytes}}})
       when is_number(bytes),
       do: bytes

  defp extract_memory_bytes(%{"erlang" => %{"memory_total" => bytes}}) when is_number(bytes),
    do: bytes

  defp extract_memory_bytes(_), do: nil

  defp update_sparkline_history(history, node_stats_data) do
    Enum.reduce(node_stats_data, history, fn {node_name, stats}, acc ->
      point = %{
        vnode_gets: get_in(stats, ["kv", "vnode_gets"]) || 0,
        vnode_puts: get_in(stats, ["kv", "vnode_puts"]) || 0,
        memory: extract_memory_bytes(stats) || 0,
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

  @impl true
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
            node_dist={@node_dist}
            node_stats={@node_stats}
          />
        </div>

        <%!-- Section 4: Metric Chart --%>
        <div :if={@selected_node} class="mb-6">
          <.metric_chart
            selected_metric={@selected_metric}
            data={chart_data_for(@sparkline_history, @selected_node, @selected_metric)}
            unit={metric_unit(@selected_metric)}
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
    </div>
    """
  end
end
