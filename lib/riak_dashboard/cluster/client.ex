defmodule RiakDashboard.Cluster.Client do
  @moduledoc "Behaviour for the Riak Admin API client."

  # === Admin endpoints ===
  @callback ping(base_url :: String.t()) :: {:ok, map()} | {:error, term()}
  @callback cluster_status(base_url :: String.t()) :: {:ok, map()} | {:error, term()}
  @callback ring_ownership(base_url :: String.t()) :: {:ok, map()} | {:error, term()}
  @callback node_stats(base_url :: String.t(), node_name :: String.t()) ::
              {:ok, map()} | {:error, term()}
  @callback handoff_status(base_url :: String.t()) :: {:ok, map()} | {:error, term()}
  @callback aae_status(base_url :: String.t()) :: {:ok, map()} | {:error, term()}
  @callback list_dcs(base_url :: String.t()) :: {:ok, map()} | {:error, term()}

  # === Bucket/Key operations ===
  @callback list_buckets(base_url :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}
  @callback list_keys(base_url :: String.t(), bucket :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}
  @callback get_object(
              base_url :: String.t(),
              bucket :: String.t(),
              key :: String.t(),
              opts :: keyword()
            ) :: {:ok, map()} | {:error, term()}
  @callback put_object(
              base_url :: String.t(),
              bucket :: String.t(),
              key :: String.t(),
              value :: term(),
              opts :: keyword()
            ) :: {:ok, map()} | {:error, term()}
  @callback create_object(
              base_url :: String.t(),
              bucket :: String.t(),
              value :: term(),
              opts :: keyword()
            ) :: {:ok, map()} | {:error, term()}
  @callback delete_object(
              base_url :: String.t(),
              bucket :: String.t(),
              key :: String.t(),
              opts :: keyword()
            ) :: :ok | {:error, term()}

  # === Bucket/Type properties ===
  @callback get_bucket_props(base_url :: String.t(), bucket :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}
  @callback put_bucket_props(
              base_url :: String.t(),
              bucket :: String.t(),
              props :: map(),
              opts :: keyword()
            ) :: {:ok, map()} | {:error, term()}
  @callback delete_bucket_props(
              base_url :: String.t(),
              bucket :: String.t(),
              opts :: keyword()
            ) :: :ok | {:error, term()}
  @callback get_type_props(base_url :: String.t(), type :: String.t()) ::
              {:ok, map()} | {:error, term()}
  @callback put_type_props(base_url :: String.t(), type :: String.t(), props :: map()) ::
              {:ok, map()} | {:error, term()}

  # === Counters ===
  @callback get_counter(
              base_url :: String.t(),
              bucket :: String.t(),
              key :: String.t(),
              opts :: keyword()
            ) :: {:ok, integer()} | {:error, term()}
  @callback update_counter(
              base_url :: String.t(),
              bucket :: String.t(),
              key :: String.t(),
              delta :: integer(),
              opts :: keyword()
            ) :: :ok | {:error, term()}

  # === CRDTs ===
  @callback get_crdt(
              base_url :: String.t(),
              type :: String.t(),
              bucket :: String.t(),
              key :: String.t(),
              opts :: keyword()
            ) :: {:ok, map()} | {:error, term()}
  @callback update_crdt(
              base_url :: String.t(),
              type :: String.t(),
              bucket :: String.t(),
              key :: String.t(),
              update :: map(),
              opts :: keyword()
            ) :: {:ok, map()} | {:error, term()}
  @callback create_crdt(
              base_url :: String.t(),
              type :: String.t(),
              bucket :: String.t(),
              update :: map(),
              opts :: keyword()
            ) :: {:ok, map()} | {:error, term()}

  # === MapReduce ===
  @callback run_mapred(base_url :: String.t(), query :: map(), opts :: keyword()) ::
              {:ok, term()} | {:error, term()}

  # === Secondary Index ===
  @callback index_query(
              base_url :: String.t(),
              bucket :: String.t(),
              field :: String.t(),
              term_or_range :: term(),
              opts :: keyword()
            ) :: {:ok, map()} | {:error, term()}

  # === Complex Query ===
  @callback run_query(
              base_url :: String.t(),
              bucket :: String.t(),
              query :: map(),
              opts :: keyword()
            ) :: {:ok, map()} | {:error, term()}

  @doc "Returns the configured client module."
  def impl do
    Application.get_env(:riak_dashboard, :cluster_client, RiakDashboard.Cluster.HttpClient)
  end

  @doc "Returns the configured Riak Admin API base URL."
  def base_url do
    Application.get_env(:riak_dashboard, :riak_admin_url, "http://localhost:8099")
  end
end
