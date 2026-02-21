defmodule RiakDashboardWeb.Components.Dashboard.Connection do
  @moduledoc "WebSocket connection status indicator component."

  use Phoenix.Component

  attr(:status, :atom, required: true)

  def connection_indicator(assigns) do
    ~H"""
    <div class={[
      "inline-flex items-center gap-2 px-3 py-1 rounded-full text-xs font-semibold",
      @status == :connected &&
        "text-[#4A7C59] bg-[#E8F5E9] border border-[#C4E6C9] dark:text-[#34D399] dark:bg-[#0f3429] dark:border-[#166534]",
      @status in [:disconnected, :connecting] &&
        "text-[#E69500] bg-[#FFF8E1] border border-[#FFE0B2] dark:text-[#f59e0b] dark:bg-[#422006] dark:border-[#92400e]",
      @status == :not_configured &&
        "text-[#C62828] bg-[#FFEBEE] border border-[#FFCDD2] dark:text-[#f87171] dark:bg-[#3a1f22] dark:border-[#7f1d1d]"
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
