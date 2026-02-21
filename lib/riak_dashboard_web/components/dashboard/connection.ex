defmodule RiakDashboardWeb.Components.Dashboard.Connection do
  @moduledoc "WebSocket connection status indicator component."

  use Phoenix.Component

  attr(:status, :atom, required: true)

  def connection_indicator(assigns) do
    ~H"""
    <div class={[
      "inline-flex items-center gap-2 px-3 py-1 rounded-full text-xs font-semibold",
      @status == :connected && "text-[#4A7C59] bg-[#E8F5E9] border border-[#C4E6C9]",
      @status in [:disconnected, :connecting] &&
        "text-[#E69500] bg-[#FFF8E1] border border-[#FFE0B2]",
      @status == :not_configured && "text-[#C62828] bg-[#FFEBEE] border border-[#FFCDD2]"
    ]}>
      <span class={[
        "w-2 h-2 rounded-full",
        @status == :connected && "bg-green-500 animate-pulse",
        @status in [:disconnected, :connecting] && "bg-amber-500",
        @status == :not_configured && "bg-red-500"
      ]} />
      <%= case @status do %>
        <% :connected -> %>
          Live
        <% :connecting -> %>
          Connecting...
        <% :disconnected -> %>
          Reconnecting...
        <% :not_configured -> %>
          Not Connected
      <% end %>
    </div>
    """
  end
end
