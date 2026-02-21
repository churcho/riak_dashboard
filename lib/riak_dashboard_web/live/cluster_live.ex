defmodule RiakDashboardWeb.ClusterLive do
  use RiakDashboardWeb, :live_view

  import RiakDashboardWeb.Components.Dashboard.Cards
  import RiakDashboardWeb.Components.Dashboard.Connection
  import RiakDashboardWeb.Components.Dashboard.Feedback
  import RiakDashboardWeb.Components.Dashboard.NodeChips
  import RiakDashboardWeb.Components.Dashboard.NodePerformance
  import RiakDashboardWeb.Components.Dashboard.RingPanel

  @sparkline_max_points 30
  @node_color_palette [
    "#e77117",
    "#63819b",
    "#27d7b9",
    "#2d80d1",
    "#d12d2d",
    "#e39e1b",
    "#2cd284"
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
       cluster_name: data["cluster_name"],
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

  # Private helpers

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

        <%!-- Section 4: Remote Datacenters --%>
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
