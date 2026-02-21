defmodule RiakDashboard.MetricStore do
  @moduledoc "Persists per-node metric history across multiple downsampled tiers."

  use GenServer

  @recent_limit 300
  @medium_limit 360
  @long_limit 1_440
  @weekly_limit 2_016

  @compact_medium_every 1
  @compact_long_every 6
  @compact_weekly_every 30

  @metric_keys [
    :memory_total,
    :memory_processes,
    :memory_ets,
    :vnode_gets,
    :vnode_puts,
    :node_gets,
    :node_puts,
    :get_latency,
    :put_latency,
    :processes,
    :run_queue,
    :read_repairs,
    :scheduler_utilization
  ]

  @type metric_point :: {non_neg_integer(), %{atom() => integer()}}
  @type range :: :recent | :hour | :day | :week

  # Public API
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)

    if name do
      GenServer.start_link(__MODULE__, opts, name: name)
    else
      GenServer.start_link(__MODULE__, opts)
    end
  end

  @spec record(map()) :: :ok
  def record(node_stats_map), do: record(__MODULE__, node_stats_map)

  @spec record(GenServer.server(), map()) :: :ok
  def record(server, node_stats_map) do
    safe_cast(server, {:record, node_stats_map})
  end

  @spec query(String.t(), range()) :: [metric_point()]
  def query(node_name, range), do: query(__MODULE__, node_name, range)

  @spec query(GenServer.server(), String.t(), range()) :: [metric_point()]
  def query(server, node_name, range) do
    safe_call(server, {:query, node_name, range}, [])
  end

  @spec nodes() :: [String.t()]
  def nodes, do: nodes(__MODULE__)

  @spec nodes(GenServer.server()) :: [String.t()]
  def nodes(server) do
    safe_call(server, :nodes, [])
  end

  @spec delete_node(String.t()) :: :ok
  def delete_node(node_name), do: delete_node(__MODULE__, node_name)

  @spec delete_node(GenServer.server(), String.t()) :: :ok
  def delete_node(server, node_name) do
    safe_cast(server, {:delete_node, node_name})
  end

  @spec reset() :: :ok
  def reset, do: reset(__MODULE__)

  @spec reset(GenServer.server()) :: :ok
  def reset(server) do
    safe_cast(server, :reset)
  end

  # GenServer
  @impl true
  def init(opts) do
    table = Keyword.get(opts, :table, :riak_dashboard_metric_store)
    path = Keyword.get(opts, :path, default_dets_path())
    compact_interval = Keyword.get(opts, :compact_interval, 10_000)

    path
    |> Path.dirname()
    |> File.mkdir_p!()

    {:ok, _} = :dets.open_file(table, type: :set, file: String.to_charlist(path))

    schedule_compact(compact_interval)

    {:ok,
     %{
       table: table,
       recent: %{},
       compact_counter: 0,
       compact_interval: compact_interval
     }}
  end

  @impl true
  def terminate(_reason, state) do
    :ok = :dets.close(state.table)
  end

  @impl true
  def handle_cast({:record, node_stats_map}, state) when is_map(node_stats_map) do
    timestamp = System.system_time(:second)

    recent =
      Enum.reduce(node_stats_map, state.recent, fn {node_name, raw_stats}, acc ->
        point = {timestamp, extract_metrics(raw_stats)}
        updated = trim_to_limit(Map.get(acc, node_name, []) ++ [point], @recent_limit)
        Map.put(acc, node_name, updated)
      end)

    {:noreply, %{state | recent: recent}}
  end

  def handle_cast({:record, _invalid_payload}, state), do: {:noreply, state}

  def handle_cast({:delete_node, node_name}, state) do
    Enum.each([:medium, :long, :weekly], fn tier ->
      :ok = :dets.delete(state.table, {node_name, tier})
    end)

    {:noreply, %{state | recent: Map.delete(state.recent, node_name)}}
  end

  def handle_cast(:reset, state) do
    :ok = :dets.delete_all_objects(state.table)
    {:noreply, %{state | recent: %{}, compact_counter: 0}}
  end

  @impl true
  def handle_call({:query, node_name, :recent}, _from, state) do
    points = state.recent |> Map.get(node_name, []) |> sort_points()
    {:reply, points, state}
  end

  def handle_call({:query, node_name, range}, _from, state) do
    points =
      case range_to_tier(range) do
        nil -> []
        tier -> state |> read_tier(node_name, tier) |> sort_points()
      end

    {:reply, points, state}
  end

  def handle_call(:nodes, _from, state) do
    dets_nodes =
      :dets.foldl(
        fn {{node_name, _tier}, _points}, acc ->
          MapSet.put(acc, node_name)
        end,
        MapSet.new(),
        state.table
      )

    nodes =
      state.recent
      |> Map.keys()
      |> Enum.reduce(dets_nodes, &MapSet.put(&2, &1))
      |> MapSet.to_list()
      |> Enum.sort()

    {:reply, nodes, state}
  end

  @impl true
  def handle_info(:compact, state) do
    state =
      state
      |> compact_recent_to_medium()
      |> compact_medium_to_long()
      |> compact_long_to_weekly()
      |> bump_compact_counter()

    schedule_compact(state.compact_interval)
    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  # Metric extraction
  defp extract_metrics(raw_stats) when is_map(raw_stats) do
    erlang = map_get(raw_stats, "erlang", %{})
    kv = map_get(raw_stats, "kv", %{})

    %{
      memory_total: extract_memory_bytes(erlang),
      memory_processes:
        extract_memory_field(erlang, "processes", "memory_processes_mb", "memory_processes"),
      memory_ets: extract_memory_field(erlang, "ets", "memory_ets_mb", "memory_ets"),
      vnode_gets: normalize_int(map_get(kv, "vnode_gets", 0)),
      vnode_puts: normalize_int(map_get(kv, "vnode_puts", 0)),
      node_gets: normalize_int(map_get(kv, "node_gets", 0)),
      node_puts: normalize_int(map_get(kv, "node_puts", 0)),
      get_latency: normalize_int(map_get(kv, "node_get_fsm_time_mean", 0)),
      put_latency: normalize_int(map_get(kv, "node_put_fsm_time_mean", 0)),
      processes: normalize_int(map_get(erlang, "process_count", 0)),
      run_queue: normalize_int(map_get(erlang, "run_queue", 0)),
      read_repairs: normalize_int(map_get(kv, "read_repairs", 0)),
      scheduler_utilization: normalize_int(map_get(erlang, "scheduler_utilization", 0))
    }
  end

  defp extract_metrics(_), do: zero_metrics()

  defp extract_memory_bytes(erlang) do
    cond do
      is_number(map_get(erlang, "memory_total_mb")) ->
        round(map_get(erlang, "memory_total_mb") * 1_048_576)

      is_number(get_in(erlang, ["memory", "total"])) ->
        normalize_int(get_in(erlang, ["memory", "total"]))

      is_number(map_get(erlang, "memory_total")) ->
        normalize_int(map_get(erlang, "memory_total"))

      true ->
        0
    end
  end

  defp extract_memory_field(erlang, nested_key, mb_key, fallback_bytes_key) do
    cond do
      is_number(map_get(erlang, mb_key)) ->
        round(map_get(erlang, mb_key) * 1_048_576)

      is_number(get_in(erlang, ["memory", nested_key])) ->
        normalize_int(get_in(erlang, ["memory", nested_key]))

      is_number(map_get(erlang, fallback_bytes_key)) ->
        normalize_int(map_get(erlang, fallback_bytes_key))

      true ->
        0
    end
  end

  # Compaction
  defp compact_recent_to_medium(state) do
    if rem(state.compact_counter, @compact_medium_every) != 0 do
      state
    else
      Enum.reduce(state.recent, state, fn {node_name, points}, acc ->
        maybe_append_averaged(acc, node_name, :medium, points, 10, @medium_limit)
      end)
    end
  end

  defp compact_medium_to_long(state) do
    next_counter = state.compact_counter + 1

    if rem(next_counter, @compact_long_every) != 0,
      do: state,
      else: compact_tier(state, :medium, :long, 6, @long_limit)
  end

  defp compact_long_to_weekly(state) do
    next_counter = state.compact_counter + 1

    if rem(next_counter, @compact_weekly_every) != 0,
      do: state,
      else: compact_tier(state, :long, :weekly, 5, @weekly_limit)
  end

  defp compact_tier(state, source_tier, target_tier, sample_size, limit) do
    Enum.reduce(tier_nodes(state, source_tier), state, fn node_name, acc ->
      points = read_tier(acc, node_name, source_tier)
      maybe_append_averaged(acc, node_name, target_tier, points, sample_size, limit)
    end)
  end

  defp maybe_append_averaged(state, node_name, tier, points, sample_size, limit) do
    case average_recent(points, sample_size) do
      nil -> state
      point -> append_point(state, node_name, tier, point, limit)
    end
  end

  defp bump_compact_counter(state), do: %{state | compact_counter: state.compact_counter + 1}

  defp append_point(state, node_name, tier, point, limit) do
    updated =
      state
      |> read_tier(node_name, tier)
      |> Kernel.++([point])
      |> trim_to_limit(limit)

    :ok = :dets.insert(state.table, {{node_name, tier}, updated})
    state
  end

  defp average_recent([], _sample_size), do: nil

  defp average_recent(points, sample_size) do
    sampled = Enum.take(points, -sample_size)
    {timestamp, _metrics} = List.last(sampled)
    count = length(sampled)

    averaged =
      Enum.into(@metric_keys, %{}, fn key ->
        value =
          sampled
          |> Enum.reduce(0, fn {_ts, metrics}, acc -> acc + Map.get(metrics, key, 0) end)
          |> Kernel./(count)
          |> round()

        {key, value}
      end)

    {timestamp, averaged}
  end

  # DETS helpers
  defp read_tier(state, node_name, tier) do
    case :dets.lookup(state.table, {node_name, tier}) do
      [{{^node_name, ^tier}, points}] -> points
      _ -> []
    end
  end

  defp tier_nodes(state, tier) do
    :dets.foldl(
      fn
        {{node_name, ^tier}, _points}, acc -> [node_name | acc]
        _, acc -> acc
      end,
      [],
      state.table
    )
    |> Enum.uniq()
  end

  # Shared helpers
  defp range_to_tier(:hour), do: :medium
  defp range_to_tier(:day), do: :long
  defp range_to_tier(:week), do: :weekly
  defp range_to_tier(_), do: nil

  defp sort_points(points) do
    Enum.sort_by(points, fn {timestamp, _metrics} -> timestamp end)
  end

  defp trim_to_limit(points, limit) do
    Enum.take(points, -limit)
  end

  defp normalize_int(value) when is_integer(value), do: value
  defp normalize_int(value) when is_float(value), do: round(value)
  defp normalize_int(_), do: 0

  defp map_get(map, key, default \\ nil)

  defp map_get(map, key, default) when is_map(map) and is_binary(key) do
    case Map.fetch(map, key) do
      {:ok, value} ->
        value

      :error ->
        case safe_existing_atom(key) do
          nil -> default
          atom_key -> Map.get(map, atom_key, default)
        end
    end
  end

  defp map_get(map, key, default) when is_map(map), do: Map.get(map, key, default)
  defp map_get(_not_map, _key, default), do: default

  defp safe_existing_atom(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end

  defp zero_metrics do
    Enum.into(@metric_keys, %{}, &{&1, 0})
  end

  defp schedule_compact(interval_ms) do
    Process.send_after(self(), :compact, interval_ms)
  end

  defp default_dets_path do
    Application.app_dir(:riak_dashboard, "priv/data/metric_store.dets")
  end

  defp safe_call(server, message, fallback) do
    GenServer.call(server, message)
  catch
    :exit, _reason -> fallback
  end

  defp safe_cast(server, message) do
    GenServer.cast(server, message)
  rescue
    ArgumentError -> :ok
  catch
    :exit, _reason -> :ok
  end
end
