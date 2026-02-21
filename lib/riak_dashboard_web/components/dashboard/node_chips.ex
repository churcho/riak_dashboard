defmodule RiakDashboardWeb.Components.Dashboard.NodeChips do
  @moduledoc "Node cards with status, ring share, and key stats."

  use Phoenix.Component

  attr :nodes, :list, required: true, doc: "List of node maps from cluster data"
  attr :selected_node, :string, default: nil, doc: "Currently selected node name"
  attr :node_dist, :list, default: [], doc: "Node distribution list with partition counts"
  attr :node_stats, :map, default: %{}, doc: "Current node stats keyed by name"

  def node_chips(assigns) do
    dist_map = Map.new(assigns.node_dist, fn d -> {d.node, d} end)
    assigns = assign(assigns, :dist_map, dist_map)

    ~H"""
    <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-2.5">
      <button
        :for={node <- @nodes}
        type="button"
        phx-click="select_node"
        phx-value-node={node["name"]}
        class={[
          "text-left rounded-lg p-3 transition-all duration-150",
          "focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117]",
          if(node["name"] == @selected_node,
            do: "border-2 border-[#e77117] bg-[#e77117]/[0.03] dark:bg-[#e77117]/[0.06]",
            else:
              "border border-[#EEEDEA] bg-white hover:border-[#e77117]/30 dark:border-[#334155] dark:bg-[var(--or-bg-surface)] dark:hover:border-[#e77117]/30"
          )
        ]}
      >
        <%!-- Row 1: status + name + ring % --%>
        <div class="flex items-center gap-2 mb-2">
          <span class={[
            "w-2 h-2 rounded-full shrink-0",
            if(node["reachable"], do: "bg-[#22c55e]", else: "bg-[#ef4444]")
          ]} />
          <span class="text-[12px] font-semibold font-mono text-[#1A1A1A] dark:text-[#E2E8F0] truncate flex-1">
            {short_name(node["name"])}
          </span>
          <span
            :if={Map.has_key?(@dist_map, node["name"])}
            class="text-[11px] font-semibold tabular-nums text-[#e77117]"
          >
            {@dist_map[node["name"]].pct}%
          </span>
        </div>

        <%!-- Row 2: ring share bar --%>
        <div
          :if={Map.has_key?(@dist_map, node["name"])}
          class="h-1 rounded-full bg-[#F5F3EF] dark:bg-[#334155] mb-2.5 overflow-hidden"
        >
          <div
            class="h-full rounded-full bg-[#e77117]/60"
            style={"width: #{(@dist_map[node["name"]]).pct}%"}
          />
        </div>

        <%!-- Row 3: mini stats --%>
        <div class="flex items-center gap-3 text-[10px] text-[#8A8A8A] dark:text-[#6B7280]">
          <.mini_stat label="Mem" value={format_memory(@node_stats, node["name"])} />
          <.mini_stat
            label="Procs"
            value={format_stat(@node_stats, node["name"], ["erlang", "process_count"])}
          />
          <.mini_stat
            label="Gets"
            value={format_stat(@node_stats, node["name"], ["kv", "vnode_gets"])}
          />
          <.mini_stat
            label="Puts"
            value={format_stat(@node_stats, node["name"], ["kv", "vnode_puts"])}
          />
        </div>
      </button>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true

  defp mini_stat(assigns) do
    ~H"""
    <span>
      <span class="text-[#A8A8A8] dark:text-[#6B7280]">{@label}</span>
      <span class="font-semibold text-[#1A1A1A] dark:text-[#E2E8F0] tabular-nums ml-0.5">
        {@value}
      </span>
    </span>
    """
  end

  defp short_name(name) when is_binary(name) do
    name |> String.split("@") |> List.last()
  end

  defp short_name(name), do: name

  defp format_memory(node_stats, node_name) do
    case get_in(node_stats, [node_name, "erlang"]) do
      %{"memory_total_mb" => mb} when is_number(mb) ->
        format_mb(mb)

      %{"memory" => %{"total" => bytes}} when is_number(bytes) ->
        format_mb(bytes / 1_048_576)

      %{"memory_total" => bytes} when is_number(bytes) ->
        format_mb(bytes / 1_048_576)

      _ ->
        "-"
    end
  end

  defp format_mb(mb) when mb >= 1024, do: "#{Float.round(mb / 1024, 1)}G"
  defp format_mb(mb), do: "#{Float.round(mb * 1.0, 0)}M"

  defp format_stat(node_stats, node_name, path) do
    case get_in(node_stats, [node_name | path]) do
      nil -> "-"
      val when val >= 1_000_000 -> "#{Float.round(val / 1_000_000, 1)}M"
      val when val >= 1000 -> "#{Float.round(val / 1000, 1)}k"
      val -> "#{val}"
    end
  end
end
