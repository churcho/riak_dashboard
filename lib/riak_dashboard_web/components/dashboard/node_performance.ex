defmodule RiakDashboardWeb.Components.Dashboard.NodePerformance do
  @moduledoc "Node performance panel with dropdown selector and sparkline metric rows."

  use Phoenix.Component

  import RiakDashboardWeb.Components.Dashboard.ChoicesSelect
  import RiakDashboardWeb.Components.Dashboard.Sparkline

  @metrics [
    %{key: :vnode_gets, label: "VNode Gets", path: ["kv", "vnode_gets"], unit: "", format: :raw},
    %{key: :vnode_puts, label: "VNode Puts", path: ["kv", "vnode_puts"], unit: "", format: :raw},
    %{
      key: :memory,
      label: "Memory",
      path: ["erlang", "memory_total"],
      unit: "MB",
      format: :memory
    },
    %{
      key: :processes,
      label: "Processes",
      path: ["erlang", "process_count"],
      unit: "",
      format: :raw
    },
    %{
      key: :get_latency,
      label: "Get Latency",
      path: ["kv", "node_get_fsm_time_mean"],
      unit: "\u00B5s",
      format: :raw
    },
    %{
      key: :put_latency,
      label: "Put Latency",
      path: ["kv", "node_put_fsm_time_mean"],
      unit: "\u00B5s",
      format: :raw
    },
    %{
      key: :read_repairs,
      label: "Read Repairs",
      path: ["kv", "read_repairs"],
      unit: "",
      format: :raw
    }
  ]

  attr :nodes, :list, required: true, doc: "List of node maps (for dropdown)"
  attr :selected_node, :string, default: nil
  attr :node_stats, :map, default: %{}, doc: "Current node stats keyed by name"
  attr :sparkline_history, :map, default: %{}, doc: "Historical data per node"

  def node_performance(assigns) do
    assigns = assign(assigns, :metrics, @metrics)

    ~H"""
    <div class="bg-white rounded-xl border border-[#EEEDEA] p-4 dark:bg-[var(--or-bg-surface)] dark:border-[var(--or-border-base)]">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-xs font-semibold uppercase tracking-wider text-[#8A8A8A] dark:text-[#94A3B8]">
          Node Performance
        </h3>
        <.choices_select
          id="node-performance-selector"
          options={Enum.map(@nodes, &{&1["name"], &1["name"]})}
          selected={@selected_node}
          event="select_node"
          value_key="node"
          placeholder="Select a node..."
          compact
          search_enabled={length(@nodes) > 5}
        />
      </div>

      <div
        :if={@selected_node == nil}
        class="py-8 text-center text-sm text-[#A8A8A8] dark:text-[#6B7280]"
      >
        Select a node to view performance metrics
      </div>

      <div :if={@selected_node} class="space-y-0">
        <.metric_row
          :for={metric <- @metrics}
          metric={metric}
          history={get_metric_history(@sparkline_history, @selected_node, metric.key)}
          current={get_current_value(@node_stats, @selected_node, metric)}
        />
      </div>
    </div>
    """
  end

  attr :metric, :map, required: true
  attr :history, :list, required: true
  attr :current, :string, required: true

  defp metric_row(assigns) do
    ~H"""
    <div class="flex items-center gap-3 py-1.5 border-b border-[#F5F3EF] last:border-0 dark:border-[#334155]">
      <span class="w-24 text-xs text-[#8A8A8A] dark:text-[#94A3B8] shrink-0">
        {@metric.label}
      </span>
      <div class="flex-1 h-6">
        <.sparkline data={@history} width={120} height={24} class="w-full h-full" />
      </div>
      <span class="w-20 text-right text-xs font-semibold text-[#1A1A1A] dark:text-[var(--or-fg-base)] tabular-nums shrink-0">
        {@current}
      </span>
    </div>
    """
  end

  defp get_metric_history(sparkline_history, node, metric_key) do
    sparkline_history
    |> Map.get(node, [])
    |> Enum.map(&Map.get(&1, metric_key, 0))
  end

  defp get_current_value(node_stats, node, %{format: :memory, path: [section | _]}) do
    case get_in(node_stats, [node, section]) do
      nil ->
        "-"

      %{"memory_total_mb" => value} when is_number(value) ->
        "#{Float.round(value * 1.0, 1)} MB"

      %{"memory" => %{"total" => bytes}} when is_number(bytes) ->
        "#{Float.round(bytes / 1_048_576, 1)} MB"

      %{"memory_total" => bytes} when is_number(bytes) ->
        "#{Float.round(bytes / 1_048_576, 1)} MB"

      _ ->
        "-"
    end
  end

  defp get_current_value(node_stats, node, %{path: [section, key], unit: unit}) do
    case get_in(node_stats, [node, section, key]) do
      nil -> "-"
      val when unit != "" -> "#{val} #{unit}"
      val -> "#{val}"
    end
  end
end
