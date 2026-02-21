defmodule RiakDashboardWeb.AaeLive do
  @moduledoc "LiveView for monitoring Riak Active Anti-Entropy (AAE) exchange status."

  use RiakDashboardWeb, :live_view

  import RiakDashboardWeb.Components.Dashboard.Cards
  import RiakDashboardWeb.Components.Dashboard.Connection
  import RiakDashboardWeb.Components.Dashboard.Feedback

  @impl true
  def mount(_params, _session, socket) do
    ws_url = Application.get_env(:riak_dashboard, :riak_ws_url)

    socket =
      assign(socket,
        page_title: "AAE",
        active_nav: "AAE",
        ws_url: ws_url,
        ws_status: :connecting,
        aae: nil,
        loading: true,
        error: nil,
        topics_json: Jason.encode!(~w(aae))
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

  def handle_event("riak_aae", data, socket) do
    {:noreply, assign(socket, aae: data, loading: false)}
  end

  def handle_event("ws_backpressure", _data, socket) do
    {:noreply, socket}
  end

  def handle_event("ws_error", _data, socket) do
    {:noreply, socket}
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
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold text-[#1A1A1A]">AAE Exchanges</h1>
        <.connection_indicator status={@ws_status} />
      </div>

      <.loading_text :if={@loading} label="Loading AAE data..." />

      <%= if @aae do %>
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
          <.stat_card title="Active Exchanges" value={@aae["count"]} />
        </div>

        <%= if @aae["exchanges"] != [] do %>
          <div class="bg-white rounded-xl border border-[#EEEDEA] p-4">
            <h2 class="text-lg font-semibold mb-3 text-[#1A1A1A]">
              Exchange Details
            </h2>
            <table class="w-full text-sm">
              <thead>
                <tr class="text-[#8A8A8A]">
                  <th class="text-left py-2 font-medium">Exchange Payload</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={exchange <- @aae["exchanges"]}
                  class="border-t border-[#EEECE8]"
                >
                  <td class="py-2 text-[#1A1A1A] font-mono text-xs whitespace-pre-wrap break-all">
                    {exchange["raw"] || Jason.encode!(exchange)}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        <% else %>
          <div class="bg-white rounded-xl border border-[#EEEDEA] px-5 py-8 text-center">
            <p class="text-sm text-[#8A8A8A]">No active exchanges</p>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end
end
