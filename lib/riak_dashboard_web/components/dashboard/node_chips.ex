defmodule RiakDashboardWeb.Components.Dashboard.NodeChips do
  @moduledoc "Compact horizontal node list with status dots and click-to-select."

  use Phoenix.Component

  import RiakDashboardWeb.CoreComponents, only: [badge: 1]

  attr :nodes, :list, required: true, doc: "List of node maps from cluster data"
  attr :selected_node, :string, default: nil, doc: "Currently selected node name"

  def node_chips(assigns) do
    ~H"""
    <div class="flex flex-wrap gap-2">
      <button
        :for={node <- @nodes}
        type="button"
        phx-click="select_node"
        phx-value-node={node["name"]}
        class={[
          "flex items-center gap-2 px-3 py-1.5 rounded-lg border text-xs font-mono transition-all duration-150",
          "hover:border-[#e77117]/40 focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]",
          if(node["name"] == @selected_node,
            do: "border-[#e77117] bg-[#e77117]/5 ring-1 ring-[#e77117]/30 dark:bg-[#e77117]/10",
            else: "border-[#EEEDEA] bg-white dark:border-[#334155] dark:bg-[var(--or-bg-surface)]"
          )
        ]}
      >
        <span class={[
          "w-2 h-2 rounded-full shrink-0",
          if(node["reachable"], do: "bg-green-500", else: "bg-red-500")
        ]} />
        <span class="text-[#1A1A1A] dark:text-[#E2E8F0]">
          {node["name"]}
        </span>
        <.badge variant={node_status_variant(node["status"])}>
          {String.upcase(node["status"] || "unknown")}
        </.badge>
      </button>
    </div>
    """
  end

  defp node_status_variant("valid"), do: :success
  defp node_status_variant("leaving"), do: :warning
  defp node_status_variant("exiting"), do: :warning
  defp node_status_variant("joining"), do: :info
  defp node_status_variant("down"), do: :error
  defp node_status_variant(_), do: :info
end
