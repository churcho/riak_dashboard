defmodule RiakDashboardWeb.Components.Dashboard.NodeTable do
  @moduledoc "Table component for displaying cluster node information and per-node stats."

  use Phoenix.Component

  import RiakDashboardWeb.Formatters, only: [memory_total_mb: 1]

  attr(:nodes, :list, required: true)
  attr(:node_stats, :map, default: %{})

  def node_table(assigns) do
    ~H"""
    <div class="bg-white rounded-xl border border-[#EEEDEA] overflow-hidden">
      <table class="w-full">
        <thead>
          <tr class="bg-[#F5F3EF]">
            <th class="px-4 py-3 text-left text-xs font-semibold text-[#8A8A8A]">
              Node
            </th>
            <th class="px-4 py-3 text-left text-xs font-semibold text-[#8A8A8A]">
              Status
            </th>
            <th class="px-4 py-3 text-right text-xs font-semibold text-[#8A8A8A]">
              Ring %
            </th>
            <th class="px-4 py-3 text-right text-xs font-semibold text-[#8A8A8A]">
              Memory
            </th>
            <th class="px-4 py-3 text-right text-xs font-semibold text-[#8A8A8A]">
              Processes
            </th>
            <th class="px-4 py-3 text-right text-xs font-semibold text-[#8A8A8A]">
              Gets
            </th>
            <th class="px-4 py-3 text-right text-xs font-semibold text-[#8A8A8A]">
              Puts
            </th>
          </tr>
        </thead>
        <tbody>
          <tr :for={node <- @nodes} class="border-t border-[#F0EFEB]">
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
              <span class={status_badge_class(node["status"])}>{node["status"]}</span>
            </td>
            <td class="px-4 py-3 text-sm text-right text-[#1A1A1A]">
              {node["ring_pct"]}%
            </td>
            <% stats = Map.get(@node_stats, node["name"]) %>
            <%= if stats do %>
              <td class="px-4 py-3 text-sm text-right text-[#1A1A1A]">
                {memory_total_mb(stats["erlang"])} MB
              </td>
              <td class="px-4 py-3 text-sm text-right text-[#1A1A1A]">
                {stats["erlang"]["process_count"]}
              </td>
              <td class="px-4 py-3 text-sm text-right text-[#1A1A1A]">
                {stats["kv"]["node_gets"]}
              </td>
              <td class="px-4 py-3 text-sm text-right text-[#1A1A1A]">
                {stats["kv"]["node_puts"]}
              </td>
            <% else %>
              <td
                colspan="4"
                class="px-4 py-3 text-sm text-center text-[#A8A8A8]"
              >
                -
              </td>
            <% end %>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @badge_styles %{
    "valid" => "text-[#4A7C59] bg-[#E8F5E9]",
    "leaving" => "text-[#E69500] bg-[#FFF8E1]",
    "exiting" => "text-[#E69500] bg-[#FFF8E1]",
    "joining" => "text-[#2D80D1] bg-[#E3F2FD]",
    "down" => "text-[#C75050] bg-[#FFEBEE]"
  }

  defp status_badge_class(status) do
    colors = Map.get(@badge_styles, status, "text-[#2D80D1] bg-[#E3F2FD]")
    "text-xs font-semibold #{colors} px-2 py-0.5 rounded-full"
  end
end
