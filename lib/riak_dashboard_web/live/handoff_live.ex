defmodule RiakDashboardWeb.HandoffLive do
  @moduledoc "LiveView for monitoring Riak handoff transfers."

  use RiakDashboardWeb, :live_view

  import RiakDashboardWeb.Components.Dashboard.Cards
  import RiakDashboardWeb.Components.Dashboard.Connection
  import RiakDashboardWeb.Components.Dashboard.Feedback

  @impl true
  def mount(_params, _session, socket) do
    ws_url = Application.get_env(:riak_dashboard, :riak_ws_url)

    socket =
      assign(socket,
        page_title: "Handoff",
        active_nav: "Handoff",
        ws_url: ws_url,
        ws_status: :connecting,
        active_transfers: [],
        transfer_count: 0,
        loading: true,
        error: nil,
        topics_json: Jason.encode!(~w(handoff))
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

  def handle_event("riak_handoff", data, socket) do
    {:noreply,
     assign(socket,
       active_transfers: data["active_transfers"] || [],
       transfer_count: data["count"] || 0,
       loading: false
     )}
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
      <div class="flex items-center justify-between flex-wrap gap-3 mb-6">
        <h1 class="text-xl sm:text-2xl font-bold text-[#1A1A1A] dark:text-[#E2E8F0]">
          Handoff Transfers
        </h1>
        <.connection_indicator status={@ws_status} />
      </div>

      <.loading_text :if={@loading} label="Loading handoff data..." />

      <%= unless @loading do %>
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
          <.stat_card
            title="Active Transfers"
            value={@transfer_count}
            status={if @transfer_count == 0, do: :ok, else: :warning}
          />
        </div>

        <%= if @active_transfers != [] do %>
          <div class="mb-4">
            <h2 class="text-lg font-semibold mb-3 text-[#1A1A1A]">
              Transfer Details
            </h2>
            <div class="bg-white rounded-xl border border-[#EEEDEA] overflow-x-auto">
              <table class="w-full text-sm text-[#1A1A1A]">
                <thead>
                  <tr class="border-b border-[#EEECE8]">
                    <th class="px-4 py-3 text-left text-xs font-medium text-[#8A8A8A]">
                      Transfer Payload
                    </th>
                  </tr>
                </thead>
                <tbody>
                  <tr
                    :for={transfer <- @active_transfers}
                    class="border-b border-[#F0EFEB]"
                  >
                    <td class="px-4 py-3 font-mono text-xs whitespace-pre-wrap break-all">
                      {transfer["raw"] || Jason.encode!(transfer)}
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        <% else %>
          <div class="bg-white rounded-xl border border-[#EEEDEA] px-6 py-8 text-center">
            <div class="flex items-center justify-center gap-2 mb-2">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-6 w-6 text-[#4A7C59]"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </svg>
              <span class="text-lg font-semibold text-[#1A1A1A]">
                No active transfers
              </span>
            </div>
            <p class="text-sm text-[#8A8A8A]">
              All partitions are balanced. No handoff activity in progress.
            </p>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end
end
