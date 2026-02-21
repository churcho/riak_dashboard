defmodule RiakDashboard.Cluster.HttpClient do
  @moduledoc "Real HTTP client for the Riak Admin API using Req."

  @behaviour RiakDashboard.Cluster.Client

  @timeout 5_000

  # ---------------------------------------------------------------------------
  # Admin endpoints
  # ---------------------------------------------------------------------------

  @impl true
  def ping(base_url) do
    get_json(base_url, "/api/ping")
  end

  @impl true
  def cluster_status(base_url) do
    get_json(base_url, "/api/cluster/status")
  end

  @impl true
  def ring_ownership(base_url) do
    get_json(base_url, "/api/ring/ownership")
  end

  @impl true
  def node_stats(base_url, node_name) do
    get_json(base_url, "/api/nodes/#{URI.encode(node_name)}/stats")
  end

  @impl true
  def handoff_status(base_url) do
    get_json(base_url, "/api/handoff/status")
  end

  @impl true
  def aae_status(base_url) do
    get_json(base_url, "/api/aae/status")
  end

  @impl true
  def list_dcs(base_url) do
    get_json(base_url, "/api/dcs")
  end

  # ---------------------------------------------------------------------------
  # Bucket/Key operations
  # ---------------------------------------------------------------------------

  @impl true
  def list_buckets(base_url, opts \\ []) do
    path = bucket_base_path(opts) <> "?buckets=true"
    get_json(base_url, path)
  end

  @impl true
  def list_keys(base_url, bucket, opts \\ []) do
    path = bucket_path(bucket, opts) <> "/keys?keys=true"
    get_json(base_url, path)
  end

  @impl true
  def get_object(base_url, bucket, key, opts \\ []) do
    path = bucket_path(bucket, opts) <> "/keys/#{URI.encode(key)}"

    case Req.get(base_url <> path,
           receive_timeout: @timeout,
           retry: false,
           decode_body: false
         ) do
      {:ok, %Req.Response{status: status, body: body, headers: headers}}
      when status in 200..399 ->
        {:ok,
         %{
           "status" => status,
           "value" => decode_object_body(body, header_value(headers, "content-type")),
           "raw_value" => body,
           "content_type" => header_value(headers, "content-type"),
           "vclock" => header_value(headers, "x-riak-vclock"),
           "etag" => header_value(headers, "etag"),
           "last_modified" => header_value(headers, "last-modified"),
           "link" => header_value(headers, "link"),
           "location" => header_value(headers, "location")
         }}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def put_object(base_url, bucket, key, value, opts \\ []) do
    path = bucket_path(bucket, opts) <> "/keys/#{URI.encode(key)}"
    {body, content_type} = encode_object_body(value)
    query_opts = Keyword.drop(opts, [:type, :content_type, :vclock])

    path =
      maybe_append_query(path, query_opts)

    headers =
      [{"content-type", Keyword.get(opts, :content_type, content_type)}]
      |> maybe_add_header("x-riak-vclock", Keyword.get(opts, :vclock))

    case Req.put(base_url <> path,
           body: body,
           headers: headers,
           receive_timeout: @timeout,
           decode_body: false,
           retry: false
         ) do
      {:ok, %Req.Response{status: status, body: body, headers: headers}}
      when status in 200..299 ->
        {:ok,
         %{
           "status" => status,
           "value" => decode_object_body(body, header_value(headers, "content-type")),
           "raw_value" => body,
           "vclock" => header_value(headers, "x-riak-vclock"),
           "etag" => header_value(headers, "etag"),
           "last_modified" => header_value(headers, "last-modified")
         }}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def create_object(base_url, bucket, value, opts \\ []) do
    path = bucket_path(bucket, opts) <> "/keys"
    {body, content_type} = encode_object_body(value)
    query_opts = Keyword.drop(opts, [:type, :content_type, :vclock])

    path =
      maybe_append_query(path, query_opts)

    headers =
      [{"content-type", Keyword.get(opts, :content_type, content_type)}]
      |> maybe_add_header("x-riak-vclock", Keyword.get(opts, :vclock))

    case Req.post(base_url <> path,
           body: body,
           headers: headers,
           receive_timeout: @timeout,
           decode_body: false,
           retry: false
         ) do
      {:ok, %Req.Response{status: status, body: resp_body, headers: resp_headers}}
      when status in 200..299 ->
        {:ok,
         %{
           "status" => status,
           "location" => header_value(resp_headers, "location"),
           "value" => decode_object_body(resp_body, header_value(resp_headers, "content-type")),
           "raw_value" => resp_body
         }}

      {:ok, %Req.Response{status: status, body: resp_body}} ->
        {:error, {status, resp_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def delete_object(base_url, bucket, key, opts \\ []) do
    path = bucket_path(bucket, opts) <> "/keys/#{URI.encode(key)}"
    query_opts = Keyword.drop(opts, [:type, :vclock])
    path = maybe_append_query(path, query_opts)

    headers =
      []
      |> maybe_add_header("x-riak-vclock", Keyword.get(opts, :vclock))

    case Req.delete(base_url <> path,
           headers: headers,
           receive_timeout: @timeout,
           retry: false
         ) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        :ok

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Bucket/Type properties
  # ---------------------------------------------------------------------------

  @impl true
  def get_bucket_props(base_url, bucket, opts \\ []) do
    path =
      bucket_path(bucket, opts)
      |> Kernel.<>("/props")
      |> maybe_append_query(Keyword.drop(opts, [:type]))

    get_json(base_url, path)
  end

  @impl true
  def put_bucket_props(base_url, bucket, props, opts \\ []) do
    path =
      bucket_path(bucket, opts)
      |> Kernel.<>("/props")
      |> maybe_append_query(Keyword.drop(opts, [:type]))

    case Req.put(base_url <> path,
           json: %{"props" => props},
           receive_timeout: @timeout,
           retry: false
         ) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        {:ok, props}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def delete_bucket_props(base_url, bucket, opts \\ []) do
    path =
      bucket_path(bucket, opts)
      |> Kernel.<>("/props")
      |> maybe_append_query(Keyword.drop(opts, [:type]))

    case Req.delete(base_url <> path,
           receive_timeout: @timeout,
           retry: false
         ) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        :ok

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def get_type_props(base_url, type) do
    get_json(base_url, "/types/#{URI.encode(type)}/props")
  end

  @impl true
  def put_type_props(base_url, type, props) do
    path = "/types/#{URI.encode(type)}/props"

    case Req.put(base_url <> path,
           json: %{"props" => props},
           receive_timeout: @timeout,
           retry: false
         ) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        {:ok, props}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Counters
  # ---------------------------------------------------------------------------

  @impl true
  def get_counter(base_url, bucket, key, opts \\ []) do
    path = bucket_path(bucket, opts) <> "/counters/#{URI.encode(key)}"
    path = maybe_append_query(path, Keyword.drop(opts, [:type]))

    case Req.get(base_url <> path,
           receive_timeout: @timeout,
           retry: false,
           decode_body: false
         ) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, String.to_integer(String.trim(body))}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def update_counter(base_url, bucket, key, delta, opts \\ []) do
    path = bucket_path(bucket, opts) <> "/counters/#{URI.encode(key)}"
    path = maybe_append_query(path, Keyword.drop(opts, [:type]))

    case Req.post(base_url <> path,
           body: Integer.to_string(delta),
           headers: [{"content-type", "text/plain"}],
           receive_timeout: @timeout,
           retry: false
         ) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        :ok

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # CRDTs
  # ---------------------------------------------------------------------------

  @impl true
  def get_crdt(base_url, type, bucket, key, opts \\ []) do
    path = "/types/#{URI.encode(type)}/buckets/#{URI.encode(bucket)}/datatypes/#{URI.encode(key)}"
    path = maybe_append_query(path, opts)
    get_json(base_url, path)
  end

  @impl true
  def update_crdt(base_url, type, bucket, key, update, opts \\ []) do
    path = "/types/#{URI.encode(type)}/buckets/#{URI.encode(bucket)}/datatypes/#{URI.encode(key)}"
    path = maybe_append_query(path, opts)

    case Req.post(base_url <> path,
           json: update,
           receive_timeout: @timeout,
           retry: false
         ) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def create_crdt(base_url, type, bucket, update, opts \\ []) do
    path = "/types/#{URI.encode(type)}/buckets/#{URI.encode(bucket)}/datatypes"
    path = maybe_append_query(path, opts)

    case Req.post(base_url <> path,
           json: update,
           receive_timeout: @timeout,
           retry: false
         ) do
      {:ok, %Req.Response{status: status, body: body, headers: headers}}
      when status in 200..399 ->
        {:ok,
         %{
           "status" => status,
           "location" => header_value(headers, "location"),
           "body" => body
         }}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # MapReduce
  # ---------------------------------------------------------------------------

  @impl true
  def run_mapred(base_url, query, opts \\ []) do
    path = maybe_append_query("/mapred", opts)

    case Req.post(base_url <> path,
           json: query,
           receive_timeout: @timeout,
           retry: false
         ) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Secondary Index
  # ---------------------------------------------------------------------------

  @impl true
  def index_query(base_url, bucket, field, term_or_range, opts \\ []) do
    base_path = bucket_path(bucket, opts) <> "/index/#{URI.encode(field)}"
    query_opts = Keyword.drop(opts, [:type])

    path =
      case term_or_range do
        {start_val, end_val} ->
          "#{base_path}/#{URI.encode(to_string(start_val))}/#{URI.encode(to_string(end_val))}"

        exact ->
          "#{base_path}/#{URI.encode(to_string(exact))}"
      end
      |> maybe_append_query(query_opts)

    get_json(base_url, path)
  end

  # ---------------------------------------------------------------------------
  # Query
  # ---------------------------------------------------------------------------

  @impl true
  def run_query(base_url, bucket, query, opts \\ []) do
    path = bucket_path(bucket, opts) <> "/query"
    path = maybe_append_query(path, Keyword.drop(opts, [:type]))

    case Req.post(base_url <> path,
           json: query,
           receive_timeout: @timeout,
           retry: false
         ) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp get_json(base_url, path) do
    case Req.get(base_url <> path,
           receive_timeout: @timeout,
           retry: false
         ) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp bucket_base_path(opts) do
    case Keyword.get(opts, :type) do
      nil -> "/buckets"
      type -> "/types/#{URI.encode(type)}/buckets"
    end
  end

  defp bucket_path(bucket, opts) do
    bucket_base_path(opts) <> "/#{URI.encode(bucket)}"
  end

  defp encode_object_body(value) when is_binary(value), do: {value, "application/json"}

  defp encode_object_body(value) do
    {Jason.encode!(value), "application/json"}
  end

  defp decode_object_body(body, content_type) when is_binary(body) do
    if json_content_type?(content_type) do
      case Jason.decode(body) do
        {:ok, decoded} -> decoded
        _ -> body
      end
    else
      body
    end
  end

  defp decode_object_body(body, _content_type), do: body

  defp json_content_type?(nil), do: false

  defp json_content_type?(content_type) do
    String.contains?(String.downcase(content_type), "application/json")
  end

  defp header_value(headers, name) do
    headers
    |> List.wrap()
    |> Enum.find_value(fn
      {key, value} when is_binary(key) and is_binary(value) ->
        if String.downcase(key) == name, do: value, else: nil

      _ ->
        nil
    end)
  end

  defp maybe_add_header(headers, _key, nil), do: headers
  defp maybe_add_header(headers, _key, ""), do: headers
  defp maybe_add_header(headers, key, value), do: [{key, value} | headers]

  defp maybe_append_query(path, opts) do
    query_params =
      opts
      |> Keyword.drop([:type])
      |> Enum.map_join("&", fn {k, v} -> "#{k}=#{URI.encode(to_string(v))}" end)

    if query_params == "" do
      path
    else
      path <> "?" <> query_params
    end
  end
end
