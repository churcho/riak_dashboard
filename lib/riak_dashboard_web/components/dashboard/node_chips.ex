defmodule RiakDashboardWeb.Components.Dashboard.NodeChips do
  @moduledoc "Compact pill-style node list with status icons and click-to-select."

  use Phoenix.Component

  attr :nodes, :list, required: true, doc: "List of node maps from cluster data"
  attr :selected_node, :string, default: nil, doc: "Currently selected node name"

  def node_chips(assigns) do
    ~H"""
    <div class="flex flex-wrap gap-1.5">
      <button
        :for={node <- @nodes}
        type="button"
        phx-click="select_node"
        phx-value-node={node["name"]}
        class={[
          "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-mono transition-all duration-150",
          "hover:border-[#e77117]/40 focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]",
          if(node["name"] == @selected_node,
            do:
              "border border-[#e77117] bg-[#e77117]/5 ring-1 ring-[#e77117]/30 dark:bg-[#e77117]/10",
            else:
              "border border-[#EEEDEA] bg-white dark:border-[#334155] dark:bg-[var(--or-bg-surface)]"
          )
        ]}
      >
        <.status_icon reachable={node["reachable"]} status={node["status"]} />
        <span class="text-[#1A1A1A] dark:text-[#E2E8F0] truncate">
          {node["name"]}
        </span>
      </button>
    </div>
    """
  end

  attr :reachable, :boolean, required: true
  attr :status, :string, required: true

  defp status_icon(assigns) do
    ~H"""
    <svg
      width="12"
      height="12"
      viewBox="0 0 12 12"
      fill="none"
      class="shrink-0"
      aria-label={if @reachable, do: "Reachable", else: "Unreachable"}
    >
      <circle cx="6" cy="6" r="5" stroke={status_color(@reachable)} stroke-width="1.5" opacity="0.2" />
      <circle :if={@reachable} cx="6" cy="6" r="2.5" fill={status_color(@reachable)} />
      <line
        :if={!@reachable}
        x1="4"
        y1="4"
        x2="8"
        y2="8"
        stroke={status_color(@reachable)}
        stroke-width="1.5"
        stroke-linecap="round"
      />
      <line
        :if={!@reachable}
        x1="8"
        y1="4"
        x2="4"
        y2="8"
        stroke={status_color(@reachable)}
        stroke-width="1.5"
        stroke-linecap="round"
      />
    </svg>
    """
  end

  defp status_color(true), do: "#22c55e"
  defp status_color(false), do: "#ef4444"
end
