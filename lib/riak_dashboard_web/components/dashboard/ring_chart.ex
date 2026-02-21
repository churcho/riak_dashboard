defmodule RiakDashboardWeb.Components.Dashboard.RingChart do
  @moduledoc "Ring chart component wrapping the canvas-based partition visualization."

  use Phoenix.Component

  attr(:ring, :map, default: nil)

  @doc "Renders the ring chart canvas element with the RingChart JS hook."
  @spec ring_chart(map()) :: Phoenix.LiveView.Rendered.t()
  def ring_chart(assigns) do
    ~H"""
    <div
      id="ring-chart"
      phx-hook="RingChart"
      data-ring={@ring && Jason.encode!(@ring)}
    >
      <canvas width="400" height="400" class="mx-auto block"></canvas>
    </div>
    """
  end
end
