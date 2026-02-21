defmodule RiakDashboardWeb.Components.Dashboard.RingPanel do
  @moduledoc "Ring distribution panel with donut chart and node partition table."

  use Phoenix.Component

  import RiakDashboardWeb.Components.Dashboard.RingChart

  attr :ring, :map, default: nil, doc: "Ring data from WebSocket"
  attr :node_dist, :list, default: [], doc: "Computed node distribution list"

  def ring_panel(assigns) do
    ~H"""
    <div class="bg-white rounded-xl border border-[#EEEDEA] p-4 dark:bg-[var(--or-bg-surface)] dark:border-[var(--or-border-base)]">
      <h3 class="text-xs font-semibold uppercase tracking-wider text-[#8A8A8A] dark:text-[#94A3B8] mb-4">
        Ring Distribution
      </h3>

      <div :if={@ring == nil} class="py-8 text-center text-sm text-[#A8A8A8] dark:text-[#6B7280]">
        Waiting for ring data...
      </div>

      <div :if={@ring}>
        <div class="flex justify-center mb-4">
          <.ring_chart ring={@ring} />
        </div>

        <table class="w-full text-xs">
          <thead>
            <tr class="text-[#8A8A8A] dark:text-[#94A3B8]">
              <th class="text-left py-1.5 font-medium">Node</th>
              <th class="text-right py-1.5 font-medium">Parts</th>
              <th class="text-right py-1.5 font-medium">Ring %</th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={dist <- @node_dist}
              class="border-t border-[#F5F3EF] dark:border-[#334155]"
            >
              <td class="py-1.5 flex items-center gap-1.5 text-[#1A1A1A] dark:text-[#E2E8F0]">
                <span
                  class="inline-block w-2.5 h-2.5 rounded-sm shrink-0"
                  style={"background-color: #{dist.color};"}
                />
                <span class="font-mono truncate">{dist.node}</span>
              </td>
              <td class="py-1.5 text-right text-[#1A1A1A] dark:text-[#E2E8F0] tabular-nums">
                {dist.count}
              </td>
              <td class="py-1.5 text-right text-[#8A8A8A] dark:text-[#94A3B8] tabular-nums">
                {dist.pct}%
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end
end
