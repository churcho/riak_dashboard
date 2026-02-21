defmodule RiakDashboardWeb.Components.Dashboard.Connection do
  @moduledoc "WebSocket connection status indicator component."

  use Phoenix.Component

  import RiakDashboardWeb.CoreComponents, only: [badge: 1]

  attr(:status, :atom, required: true)

  def connection_indicator(assigns) do
    ~H"""
    <.badge variant={status_variant(@status)} indicator>
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
    </.badge>
    """
  end

  defp status_variant(:connected), do: :success
  defp status_variant(:connecting), do: :warning
  defp status_variant(:disconnected), do: :warning
  defp status_variant(:not_configured), do: :error
end
