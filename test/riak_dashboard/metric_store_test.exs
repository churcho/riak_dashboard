defmodule RiakDashboard.MetricStoreTest do
  use ExUnit.Case, async: false

  alias RiakDashboard.MetricStore

  setup do
    unique = System.unique_integer([:positive, :monotonic])
    dir = Path.join(System.tmp_dir!(), "riak_dashboard_metric_store_#{unique}")
    File.mkdir_p!(dir)

    path = Path.join(dir, "metric_store.dets")
    table = String.to_atom("metric_store_test_#{unique}")

    pid =
      start_supervised!(
        {MetricStore, name: nil, table: table, path: path, compact_interval: 60_000}
      )

    on_exit(fn ->
      if Process.alive?(pid) do
        GenServer.stop(pid)
      end

      File.rm_rf(dir)
    end)

    {:ok, store: pid, path: path, table: table}
  end

  describe "record/2" do
    test "stores points for new nodes in recent tier and extracts 13 metrics", %{store: store} do
      MetricStore.record(store, %{"dev1@127.0.0.1" => sample_node_stats(100)})

      [{_ts, point}] = MetricStore.query(store, "dev1@127.0.0.1", :recent)

      assert Map.keys(point) |> Enum.sort() ==
               [
                 :get_latency,
                 :memory_ets,
                 :memory_processes,
                 :memory_total,
                 :node_gets,
                 :node_puts,
                 :processes,
                 :put_latency,
                 :read_repairs,
                 :scheduler_utilization,
                 :run_queue,
                 :vnode_gets,
                 :vnode_puts
               ]
               |> Enum.sort()

      assert point.memory_total == 100 * 1_048_576
      assert point.memory_processes == 40 * 1_048_576
      assert point.memory_ets == 30 * 1_048_576
      assert point.vnode_gets == 1
      assert point.vnode_puts == 2
      assert point.node_gets == 3
      assert point.node_puts == 4
      assert point.get_latency == 10
      assert point.put_latency == 20
      assert point.processes == 222
      assert point.run_queue == 7
      assert point.read_repairs == 5
      assert point.scheduler_utilization == 0
    end

    test "trims recent tier to 300 points", %{store: store} do
      for i <- 1..305 do
        MetricStore.record(store, %{"dev1@127.0.0.1" => sample_node_stats(i)})
      end

      points = MetricStore.query(store, "dev1@127.0.0.1", :recent)
      assert length(points) == 300

      [{_oldest_ts, oldest_point} | _] = points
      assert oldest_point.memory_total == 6 * 1_048_576
    end

    test "handles multiple nodes in a single push", %{store: store} do
      MetricStore.record(store, %{
        "dev1@127.0.0.1" => sample_node_stats(10),
        "dev2@127.0.0.1" => sample_node_stats(20)
      })

      assert length(MetricStore.query(store, "dev1@127.0.0.1", :recent)) == 1
      assert length(MetricStore.query(store, "dev2@127.0.0.1", :recent)) == 1
    end
  end

  describe "query/3" do
    test "returns empty list for unknown node", %{store: store} do
      assert MetricStore.query(store, "unknown@127.0.0.1", :recent) == []
      assert MetricStore.query(store, "unknown@127.0.0.1", :hour) == []
    end

    test "returns results sorted oldest to newest", %{store: store} do
      MetricStore.record(store, %{"dev1@127.0.0.1" => sample_node_stats(10)})
      MetricStore.record(store, %{"dev1@127.0.0.1" => sample_node_stats(20)})
      MetricStore.record(store, %{"dev1@127.0.0.1" => sample_node_stats(30)})

      values =
        store
        |> MetricStore.query("dev1@127.0.0.1", :recent)
        |> Enum.map(fn {_ts, metrics} -> metrics.memory_total end)

      assert values == Enum.sort(values)
    end

    test "returns medium/long/weekly points for hour/day/week ranges", %{store: store} do
      for i <- 1..10 do
        MetricStore.record(store, %{"dev1@127.0.0.1" => sample_node_stats(i)})
      end

      # one compact -> medium
      send(store, :compact)
      assert length(MetricStore.query(store, "dev1@127.0.0.1", :hour)) == 1

      # six compacts total -> long
      for _ <- 1..5, do: send(store, :compact)
      assert length(MetricStore.query(store, "dev1@127.0.0.1", :day)) == 1

      # thirty compacts total -> weekly
      for _ <- 1..24, do: send(store, :compact)
      assert length(MetricStore.query(store, "dev1@127.0.0.1", :week)) == 1
    end
  end

  describe "compaction" do
    test "averages recent tier into medium tier every compact", %{store: store} do
      for i <- 1..10 do
        MetricStore.record(store, %{"dev1@127.0.0.1" => sample_node_stats(i)})
      end

      send(store, :compact)

      [{_ts, point}] = MetricStore.query(store, "dev1@127.0.0.1", :hour)
      assert point.vnode_gets == 1
      assert point.vnode_puts == 2
      assert point.memory_total == round(5.5 * 1_048_576)
    end

    test "trims medium tier to 360 points", %{store: store} do
      for i <- 1..10 do
        MetricStore.record(store, %{"dev1@127.0.0.1" => sample_node_stats(i)})
      end

      for _ <- 1..370 do
        send(store, :compact)
      end

      assert length(MetricStore.query(store, "dev1@127.0.0.1", :hour)) == 360
    end
  end

  describe "compaction equivalence" do
    test "produces consistent averaged values across all tiers", %{store: store} do
      for i <- 1..20 do
        MetricStore.record(store, %{"dev1@127.0.0.1" => sample_node_stats(i)})
      end

      # 30 compaction cycles populate medium (every 1), long (every 6), weekly (every 30)
      for _ <- 1..30, do: send(store, :compact)

      # Last 10 of 20 points → memory_total_mb 11..20 → avg 15.5
      expected_memory = round(15.5 * 1_048_576)

      hour_points = MetricStore.query(store, "dev1@127.0.0.1", :hour)
      day_points = MetricStore.query(store, "dev1@127.0.0.1", :day)
      week_points = MetricStore.query(store, "dev1@127.0.0.1", :week)

      assert length(hour_points) == 30
      assert length(day_points) == 5
      assert length(week_points) == 1

      # All tiers carry the same averaged values (source data is static)
      for {_ts, point} <- hour_points do
        assert point.memory_total == expected_memory
        assert point.vnode_gets == 1
        assert point.vnode_puts == 2
      end

      [{_ts, day_point} | _] = day_points
      assert day_point.memory_total == expected_memory

      [{_ts, week_point}] = week_points
      assert week_point.memory_total == expected_memory
    end
  end

  describe "delete_node/2" do
    test "removes node from recent and all dets tiers", %{store: store} do
      for i <- 1..10 do
        MetricStore.record(store, %{"dev1@127.0.0.1" => sample_node_stats(i)})
      end

      send(store, :compact)

      MetricStore.delete_node(store, "dev1@127.0.0.1")

      assert MetricStore.query(store, "dev1@127.0.0.1", :recent) == []
      assert MetricStore.query(store, "dev1@127.0.0.1", :hour) == []
      assert MetricStore.query(store, "dev1@127.0.0.1", :day) == []
      assert MetricStore.query(store, "dev1@127.0.0.1", :week) == []
    end

    test "does not affect other nodes", %{store: store} do
      MetricStore.record(store, %{
        "dev1@127.0.0.1" => sample_node_stats(10),
        "dev2@127.0.0.1" => sample_node_stats(20)
      })

      MetricStore.delete_node(store, "dev1@127.0.0.1")

      assert MetricStore.query(store, "dev1@127.0.0.1", :recent) == []
      assert length(MetricStore.query(store, "dev2@127.0.0.1", :recent)) == 1
    end
  end

  describe "reset/1" do
    test "clears all in-memory and dets data", %{store: store} do
      for i <- 1..10 do
        MetricStore.record(store, %{"dev1@127.0.0.1" => sample_node_stats(i)})
      end

      send(store, :compact)
      MetricStore.reset(store)

      assert MetricStore.query(store, "dev1@127.0.0.1", :recent) == []
      assert MetricStore.query(store, "dev1@127.0.0.1", :hour) == []
      assert MetricStore.nodes(store) == []
    end
  end

  describe "persistence" do
    test "medium data survives restart while recent starts empty", %{
      store: store,
      path: path,
      table: table
    } do
      for i <- 1..10 do
        MetricStore.record(store, %{"dev1@127.0.0.1" => sample_node_stats(i)})
      end

      send(store, :compact)
      assert length(MetricStore.query(store, "dev1@127.0.0.1", :hour)) == 1

      GenServer.stop(store)

      {:ok, pid2} =
        MetricStore.start_link(name: nil, table: table, path: path, compact_interval: 60_000)

      assert MetricStore.query(pid2, "dev1@127.0.0.1", :recent) == []
      assert length(MetricStore.query(pid2, "dev1@127.0.0.1", :hour)) == 1

      GenServer.stop(pid2)
    end
  end

  describe "availability" do
    test "public api is safe when store process is unavailable" do
      assert MetricStore.query(:missing_metric_store, "dev1@127.0.0.1", :recent) == []
      assert MetricStore.nodes(:missing_metric_store) == []

      assert MetricStore.record(:missing_metric_store, %{}) == :ok
      assert MetricStore.delete_node(:missing_metric_store, "dev1@127.0.0.1") == :ok
      assert MetricStore.reset(:missing_metric_store) == :ok
    end
  end

  defp sample_node_stats(memory_total_mb) do
    %{
      "erlang" => %{
        "memory_total_mb" => memory_total_mb,
        "memory_processes_mb" => 40,
        "memory_ets_mb" => 30,
        "process_count" => 222,
        "run_queue" => 7
      },
      "kv" => %{
        "vnode_gets" => 1,
        "vnode_puts" => 2,
        "node_gets" => 3,
        "node_puts" => 4,
        "node_get_fsm_time_mean" => 10,
        "node_put_fsm_time_mean" => 20,
        "read_repairs" => 5
      }
    }
  end
end
