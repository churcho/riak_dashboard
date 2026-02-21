defmodule RiakDashboardWeb.ClusterLive do
  use RiakDashboardWeb, :live_view

  import RiakDashboardWeb.Components.Dashboard.Cards
  import RiakDashboardWeb.Components.Dashboard.NodeTable
  import RiakDashboardWeb.Components.Dashboard.Feedback

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
        cluster_selector_open: false,
        node_stats: %{},
        loading: true,
        error: nil,
        topics_json: Jason.encode!(~w(cluster node_stats membership dcs))
      )

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, uri, socket) do
    path = URI.parse(uri).path
    active_nav = if path == "/nodes", do: "Nodes", else: nil
    {:noreply, assign(socket, active_nav: active_nav)}
  end

  # WebSocket event handlers
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

  def handle_event("riak_cluster", data, socket) do
    {:noreply,
     assign(socket,
       cluster: data,
       loading: false,
       cluster_name: data["cluster_name"],
       remote_dcs: data["remote_dcs"] || []
     )}
  end

  def handle_event("toggle_cluster_selector", _, socket) do
    {:noreply,
     assign(socket,
       cluster_selector_open: !socket.assigns.cluster_selector_open
     )}
  end

  def handle_event("select_cluster", %{"name" => name, "url" => admin_url}, socket) do
    ws_url = derive_ws_url(admin_url)

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

  def handle_event("riak_node_stats", data, socket) do
    {:noreply, assign(socket, node_stats: data)}
  end

  def handle_event("riak_membership", _data, socket) do
    {:noreply, socket}
  end

  def handle_event("riak_dcs", _data, socket) do
    {:noreply, socket}
  end

  def handle_event("ws_backpressure", _data, socket) do
    {:noreply, socket}
  end

  def handle_event("ws_error", _data, socket) do
    {:noreply, socket}
  end

  defp derive_ws_url(admin_url) do
    admin_url
    |> String.replace_prefix("http://", "ws://")
    |> String.replace_prefix("https://", "wss://")
    |> String.trim_trailing("/")
    |> Kernel.<>("/api/stream/events")
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
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
          <.stat_card
            title="Cluster"
            value={@cluster["cluster_name"]}
            subtitle={"Claimant: #{@cluster["claimant"]}"}
            tooltip={"#{@cluster["cluster_name"]}\nClaimant: #{@cluster["claimant"]}"}
            icon="dashboard"
          />
          <.stat_card
            title="Ring Size"
            value={@cluster["ring_size"]}
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
        </div>

        <div class="mb-4">
          <h2 class="text-lg font-semibold mb-3 text-[#1A1A1A] dark:text-[#E2E8F0]">Nodes</h2>
          <.node_table nodes={@cluster["nodes"]} node_stats={@node_stats} />
        </div>

        <div
          :if={@cluster["remote_dcs"] != [] and @cluster["remote_dcs"] != nil}
          class="mt-6"
        >
          <h2 class="text-lg font-semibold mb-3 text-[#1A1A1A] dark:text-[#E2E8F0]">
            Remote Datacenters
          </h2>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            <div
              :for={dc <- @cluster["remote_dcs"]}
              class="bg-white rounded-xl border border-[#EEEDEA] px-4 py-3"
            >
              <div class="font-semibold text-[#1A1A1A]">{dc["name"]}</div>
              <div class="text-xs mt-1 text-[#8A8A8A]">
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
