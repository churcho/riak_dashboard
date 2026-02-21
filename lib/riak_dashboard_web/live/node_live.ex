defmodule RiakDashboardWeb.NodeLive do
  @moduledoc "Per-node detail view showing Erlang VM stats and KV metrics."

  use RiakDashboardWeb, :live_view

  import RiakDashboardWeb.Components.Dashboard.Cards
  import RiakDashboardWeb.Components.Dashboard.Connection
  import RiakDashboardWeb.Components.Dashboard.Feedback
  import RiakDashboardWeb.Formatters

  @impl true
  def mount(%{"node" => node_name}, _session, socket) do
    ws_url = Application.get_env(:riak_dashboard, :riak_ws_url)

    socket =
      assign(socket,
        page_title: node_name,
        active_nav: "Nodes",
        ws_url: ws_url,
        ws_status: :connecting,
        node_name: node_name,
        stats: nil,
        loading: true,
        error: nil,
        topics_json: Jason.encode!(~w(node_stats))
      )

    {:ok, socket}
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

  def handle_event("riak_node_stats", data, socket) when is_map(data) do
    case Map.get(data, socket.assigns.node_name) do
      nil -> {:noreply, socket}
      stats -> {:noreply, assign(socket, stats: stats, loading: false)}
    end
  end

  def handle_event(_event, _data, socket), do: {:noreply, socket}

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

      <.loading_text :if={@loading} label="Loading node stats..." />

      <%= if @stats do %>
        <%!-- Erlang VM Section --%>
        <h2 class="text-lg font-semibold mb-3 text-[#1A1A1A]">Erlang VM</h2>
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
          <.stat_card
            title="OTP Release"
            value={@stats["erlang"]["otp_release"]}
            subtitle={@stats["erlang"]["system_version"] || "Riak node runtime"}
          />
          <.stat_card title="Processes" value={@stats["erlang"]["process_count"]} />
          <.stat_card
            title="Memory (Total)"
            value={"#{memory_total_mb(@stats["erlang"])} MB"}
          />
          <.stat_card
            title="Memory (Processes)"
            value={"#{memory_processes_mb(@stats["erlang"])} MB"}
          />
          <.stat_card
            title="Memory (ETS)"
            value={"#{memory_ets_mb(@stats["erlang"])} MB"}
          />
          <.stat_card
            title="Run Queue"
            value={@stats["erlang"]["run_queue"] || 0}
          />
        </div>

        <%!-- KV Metrics Section --%>
        <h2 class="text-lg font-semibold mb-3 text-[#1A1A1A]">KV Metrics</h2>
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
          <.stat_card title="VNode Gets" value={@stats["kv"]["vnode_gets"]} />
          <.stat_card title="VNode Puts" value={@stats["kv"]["vnode_puts"]} />
          <.stat_card title="Node Gets" value={@stats["kv"]["node_gets"]} />
          <.stat_card title="Node Puts" value={@stats["kv"]["node_puts"]} />
          <.stat_card title="Read Repairs" value={@stats["kv"]["read_repairs"]} />
          <.stat_card
            title="Get Latency (mean)"
            value={"#{@stats["kv"]["node_get_fsm_time_mean"]} \u00B5s"}
          />
          <.stat_card
            title="Put Latency (mean)"
            value={"#{@stats["kv"]["node_put_fsm_time_mean"]} \u00B5s"}
          />
        </div>
      <% end %>
    </div>
    """
  end
end
