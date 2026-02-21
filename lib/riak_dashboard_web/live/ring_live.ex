defmodule RiakDashboardWeb.RingLive do
  @moduledoc "LiveView for visualizing Riak ring ownership and partition distribution."

  use RiakDashboardWeb, :live_view

  import RiakDashboardWeb.Components.Dashboard.Cards
  import RiakDashboardWeb.Components.Dashboard.Connection
  import RiakDashboardWeb.Components.Dashboard.Feedback
  import RiakDashboardWeb.Components.Dashboard.RingChart

  @impl true
  def mount(_params, _session, socket) do
    ws_url = Application.get_env(:riak_dashboard, :riak_ws_url)

    socket =
      assign(socket,
        page_title: "Ring",
        active_nav: "Ring",
        ws_url: ws_url,
        ws_status: :connecting,
        ring: nil,
        node_dist: [],
        loading: true,
        error: nil,
        topics_json: Jason.encode!(~w(ring))
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

  def handle_event("riak_ring", data, socket) when is_map(data) do
    {:noreply, assign(socket, ring: data, node_dist: node_distribution(data), loading: false)}
  end

  def handle_event("ws_backpressure", _data, socket) do
    {:noreply, socket}
  end

  def handle_event("ws_error", _data, socket) do
    {:noreply, socket}
  end

  defp node_distribution(ring) do
    palette = ["#e77117", "#63819b", "#27d7b9", "#2d80d1", "#d12d2d", "#e39e1b", "#2cd284"]

    counts =
      ring["partitions"]
      |> Enum.frequencies_by(& &1["node"])

    total = length(ring["partitions"])
    colors = ring["node_colors"]

    counts
    |> Enum.sort_by(fn {node, _count} -> node end)
    |> Enum.map(fn {node, count} ->
      color_idx = Map.get(colors, node, 0)

      %{
        node: node,
        color: Enum.at(palette, rem(color_idx, length(palette))),
        count: count,
        pct: Float.round(count / total * 100, 1)
      }
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
      <div class="flex items-center justify-between flex-wrap gap-3 mb-6">
        <h1 class="text-xl sm:text-2xl font-bold text-[#1A1A1A] dark:text-[#E2E8F0]">
          Ring Ownership
        </h1>
        <.connection_indicator status={@ws_status} />
      </div>

      <.loading_text :if={@loading} label="Loading ring data..." />

      <%= if @ring do %>
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
          <.stat_card
            title="Partitions"
            value={@ring["num_partitions"] || length(@ring["partitions"])}
          />
          <.stat_card
            title="Nodes"
            value={@ring["partitions"] |> Enum.map(& &1["node"]) |> Enum.uniq() |> length()}
          />
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div class="bg-white rounded-xl border border-[#EEEDEA] p-4">
            <h2 class="text-lg font-semibold mb-3 text-[#1A1A1A]">
              Ring Chart
            </h2>
            <.ring_chart ring={@ring} />
          </div>

          <div class="bg-white rounded-xl border border-[#EEEDEA] p-4">
            <h2 class="text-lg font-semibold mb-3 text-[#1A1A1A]">
              Node Distribution
            </h2>
            <table class="w-full text-sm">
              <thead>
                <tr class="text-[#8A8A8A]">
                  <th class="text-left py-2 font-medium">Node</th>
                  <th class="text-right py-2 font-medium">Partitions</th>
                  <th class="text-right py-2 font-medium">Ring %</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={dist <- @node_dist}
                  class="border-t border-[#EEECE8]"
                >
                  <td class="py-2 flex items-center gap-2 text-[#1A1A1A]">
                    <span
                      class="inline-block w-3 h-3 rounded-sm shrink-0"
                      style={"background-color: #{dist.color};"}
                    >
                    </span>
                    {dist.node}
                  </td>
                  <td class="py-2 text-right text-[#1A1A1A]">
                    {dist.count}
                  </td>
                  <td class="py-2 text-right text-[#8A8A8A]">
                    {dist.pct}%
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
