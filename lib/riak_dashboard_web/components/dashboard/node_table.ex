defmodule RiakDashboardWeb.Components.Dashboard.NodeTable do
  @moduledoc "Table component for displaying cluster node information and per-node stats."

  use Phoenix.Component

  import RiakDashboardWeb.CoreComponents, only: [badge: 1]
  import RiakDashboardWeb.Formatters, only: [memory_total_mb: 1]

  attr(:nodes, :list, required: true)
  attr(:node_stats, :map, default: %{})

  def node_table(assigns) do
    ~H"""
    <div class="bg-white rounded-xl border border-[#EEEDEA] overflow-hidden dark:bg-[var(--or-bg-surface)] dark:border-[var(--or-border-base)]">
      <div class="overflow-x-auto">
        <table class="w-full min-w-[640px]">
          <thead>
            <tr class="bg-[#F5F3EF] dark:bg-[#243447]">
              <th class="px-4 py-3 text-left text-xs font-semibold text-[#8A8A8A] dark:text-[#94A3B8]">
                Node
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold text-[#8A8A8A] dark:text-[#94A3B8]">
                Status
              </th>
              <th class="px-4 py-3 text-right text-xs font-semibold text-[#8A8A8A] dark:text-[#94A3B8]">
                Ring %
              </th>
              <th class="px-4 py-3 text-right text-xs font-semibold text-[#8A8A8A] dark:text-[#94A3B8]">
                Memory
              </th>
              <th class="px-4 py-3 text-right text-xs font-semibold text-[#8A8A8A] dark:text-[#94A3B8]">
                Processes
              </th>
              <th class="px-4 py-3 text-right text-xs font-semibold text-[#8A8A8A] dark:text-[#94A3B8]">
                Gets
              </th>
              <th class="px-4 py-3 text-right text-xs font-semibold text-[#8A8A8A] dark:text-[#94A3B8]">
                Puts
              </th>
            </tr>
          </thead>
          <tbody>
            <tr :for={node <- @nodes} class="border-t border-[#F0EFEB] dark:border-[#334155]">
              <td class="px-4 py-3 font-mono text-sm">
                <.link
                  navigate={"/nodes/#{URI.encode(node["name"])}"}
                  class="text-primary hover:underline"
                >
                  <span class={[
                    "inline-block w-2 h-2 rounded-full mr-2",
                    node["reachable"] && "bg-green-500",
                    !node["reachable"] && "bg-red-500"
                  ]} />
                  {node["name"]}
                </.link>
              </td>
              <td class="px-4 py-3 text-sm">
                <.badge
                  variant={node_status_variant(node["status"])}
                  class="uppercase tracking-wide text-[10px] py-0.5 px-1.5"
                >
                  {node["status"]}
                </.badge>
              </td>
              <td class="px-4 py-3 text-sm text-right text-[#1A1A1A] dark:text-[#E2E8F0]">
                {node["ring_pct"]}%
              </td>
              <% stats = Map.get(@node_stats, node["name"]) %>
              <%= if stats do %>
                <td class="px-4 py-3 text-sm text-right text-[#1A1A1A] dark:text-[#E2E8F0]">
                  {memory_total_mb(stats["erlang"])} MB
                </td>
                <td class="px-4 py-3 text-sm text-right text-[#1A1A1A] dark:text-[#E2E8F0]">
                  {stats["erlang"]["process_count"]}
                </td>
                <td class="px-4 py-3 text-sm text-right text-[#1A1A1A] dark:text-[#E2E8F0]">
                  {stats["kv"]["node_gets"]}
                </td>
                <td class="px-4 py-3 text-sm text-right text-[#1A1A1A] dark:text-[#E2E8F0]">
                  {stats["kv"]["node_puts"]}
                </td>
              <% else %>
                <td
                  colspan="4"
                  class="px-4 py-3 text-sm text-center text-[#A8A8A8] dark:text-[#6B7280]"
                >
                  -
                </td>
              <% end %>
            </tr>
          </tbody>
        </table>
      </div>
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
