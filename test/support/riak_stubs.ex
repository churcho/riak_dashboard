defmodule RiakDashboard.Test.RiakStubs do
  @moduledoc false

  @behaviour RiakDashboard.Cluster.Client

  alias RiakDashboard.Cluster.MockBehaviour

  @nodes [
    "dev1@127.0.0.1",
    "dev2@127.0.0.1",
    "dev3@127.0.0.1",
    "dev4@127.0.0.1",
    "dev5@127.0.0.1"
  ]

  def stub_all do
    Mox.stub_with(MockBehaviour, __MODULE__)
  end

  def ping(_base_url) do
    {:ok, %{"status" => "ok", "node" => "dev1@127.0.0.1"}}
  end

  def cluster_status(_base_url) do
    {:ok,
     %{
       "cluster_name" => "default",
       "ring_size" => 64,
       "claimant" => "dev1@127.0.0.1",
       "ready" => true,
       "nodes" =>
         Enum.map(@nodes, fn name ->
           %{"name" => name, "status" => "valid", "ring_pct" => 20.0, "reachable" => true}
         end),
       "pending_changes" => [],
       "remote_dcs" => [
         %{"name" => "us-west-2", "admin_url" => "http://10.0.2.1:8098", "riak_version" => "3.2.0"},
         %{"name" => "eu-central-1", "admin_url" => "http://10.0.3.1:8098", "riak_version" => "3.2.0"}
       ],
       "total_dcs" => 3
     }}
  end

  def ring_ownership(_base_url) do
    partitions =
      for i <- 0..63 do
        node = Enum.at(@nodes, rem(i, 5))
        %{"index" => i, "hash" => i * 1_000_000_000_000_000_000, "node" => node}
      end

    node_colors = %{
      "dev1@127.0.0.1" => 0,
      "dev2@127.0.0.1" => 1,
      "dev3@127.0.0.1" => 2,
      "dev4@127.0.0.1" => 3,
      "dev5@127.0.0.1" => 4
    }

    {:ok, %{"num_partitions" => 64, "partitions" => partitions, "node_colors" => node_colors}}
  end

  def node_stats(_base_url, _node_name) do
    {:ok,
     %{
       "erlang" => %{
         "otp_release" => "26",
         "process_count" => 512,
         "memory_total_mb" => 512,
         "memory_processes_mb" => 256,
         "memory_ets_mb" => 64,
         "run_queue" => 0,
         "system_version" => "Erlang/OTP 26 [erts-14.2.1]"
       },
       "kv" => %{
         "vnode_gets" => 15_234,
         "vnode_puts" => 8_421,
         "read_repairs" => 12,
         "node_gets" => 15_234,
         "node_puts" => 8_421,
         "node_get_fsm_time_mean" => 450,
         "node_put_fsm_time_mean" => 620
       }
     }}
  end

  def handoff_status(_base_url) do
    {:ok, %{"active_transfers" => [], "count" => 0}}
  end

  def aae_status(_base_url) do
    {:ok, %{"exchanges" => [], "count" => 0}}
  end

  def list_dcs(_base_url) do
    {:ok,
     %{
       "dcs" => [
         %{
           "name" => "default",
           "local" => true,
           "admin_url" => "http://127.0.0.1:8099",
           "riak_url" => "http://127.0.0.1:8098",
           "riak_version" => "3.4.0",
           "node" => "dev1@127.0.0.1",
           "reachable" => true,
           "started_at" => 1_700_000_000
         }
       ],
       "count" => 1
     }}
  end

  def list_buckets(_base_url, _opts \\ []) do
    {:ok, %{"buckets" => ["users", "sessions", "events", "config", "logs"]}}
  end

  def list_keys(_base_url, bucket, _opts \\ []) do
    keys =
      case bucket do
        "users" -> ["user_001", "user_002", "user_003"]
        "sessions" -> ["sess_abc", "sess_def"]
        "events" -> ["evt_100", "evt_101", "evt_102", "evt_103"]
        "config" -> ["app_settings", "feature_flags"]
        "logs" -> ["log_2024_01", "log_2024_02"]
        _ -> ["key_1", "key_2"]
      end

    {:ok, %{"keys" => keys}}
  end

  def get_object(_base_url, _bucket, key, _opts \\ []) do
    value = %{
      "id" => key,
      "name" => "Sample Object",
      "created_at" => "2024-01-15T10:30:00Z",
      "updated_at" => "2024-06-20T14:22:00Z"
    }

    {:ok,
     %{
       "status" => 200,
       "value" => value,
       "raw_value" => Jason.encode!(value),
       "vclock" => "a85hYGBgzGDKBVI8ypz/fgaUzZIlMGUy",
       "content_type" => "application/json",
       "etag" => "mock-etag",
       "last_modified" => "Thu, 20 Jun 2024 14:22:00 GMT",
       "link" => "</buckets/users>; rel=\"up\""
     }}
  end

  def put_object(_base_url, _bucket, key, value, _opts \\ []) do
    {:ok, %{"status" => 204, "key" => key, "value" => value}}
  end

  def create_object(_base_url, bucket, value, _opts \\ []) do
    generated = "generated_#{System.unique_integer([:positive])}"

    {:ok,
     %{
       "status" => 201,
       "location" => "/buckets/#{bucket}/keys/#{generated}",
       "value" => value
     }}
  end

  def delete_object(_base_url, _bucket, _key, _opts \\ []) do
    :ok
  end

  def get_bucket_props(_base_url, _bucket, _opts \\ []) do
    {:ok,
     %{
       "props" => %{
         "n_val" => 3,
         "allow_mult" => false,
         "last_write_wins" => false,
         "basic_quorum" => false,
         "notfound_ok" => true,
         "r" => "quorum",
         "w" => "quorum",
         "rw" => "quorum",
         "pr" => 0,
         "pw" => 0,
         "dw" => "quorum",
         "big_vclock" => 50,
         "small_vclock" => 50,
         "old_vclock" => 86_400,
         "young_vclock" => 20
       }
     }}
  end

  def put_bucket_props(_base_url, _bucket, props, _opts \\ []) do
    {:ok, %{"props" => props}}
  end

  def delete_bucket_props(_base_url, _bucket, _opts \\ []) do
    :ok
  end

  def get_type_props(_base_url, type) do
    {:ok,
     %{
       "props" => %{
         "name" => type,
         "n_val" => 3,
         "allow_mult" => true,
         "last_write_wins" => false
       }
     }}
  end

  def put_type_props(_base_url, _type, props) do
    {:ok, %{"props" => props}}
  end

  def get_counter(_base_url, _bucket, _key, _opts \\ []) do
    {:ok, 42}
  end

  def update_counter(_base_url, _bucket, _key, _delta, _opts \\ []) do
    :ok
  end

  def get_crdt(_base_url, type, _bucket, _key, _opts \\ []) do
    {:ok,
     %{
       "type" => type,
       "value" => 42,
       "context" => "g2wAAAABaAJtAAAADCMJoOLmAAAAAWEBag=="
     }}
  end

  def update_crdt(_base_url, _type, _bucket, _key, _update, _opts \\ []) do
    {:ok, %{"status" => "ok"}}
  end

  def create_crdt(_base_url, type, bucket, _update, _opts \\ []) do
    key = "new_#{System.unique_integer([:positive])}"

    {:ok,
     %{
       "status" => 201,
       "location" => "/types/#{type}/buckets/#{bucket}/datatypes/#{key}",
       "body" => %{}
     }}
  end

  def run_mapred(_base_url, _query, _opts \\ []) do
    {:ok,
     [
       %{
         "phase" => 0,
         "data" => [
           %{"key" => "user_001", "value" => 15},
           %{"key" => "user_002", "value" => 23},
           %{"key" => "user_003", "value" => 7}
         ]
       }
     ]}
  end

  def index_query(_base_url, _bucket, _field, _term_or_range, _opts \\ []) do
    {:ok,
     %{
       "keys" => ["user_001", "user_002", "user_003"],
       "continuation" => nil,
       "results" => []
     }}
  end

  def run_query(_base_url, _bucket, _query, _opts \\ []) do
    {:ok, %{"keys" => ["user_001", "user_002"], "count" => 2}}
  end
end
