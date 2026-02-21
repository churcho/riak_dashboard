defmodule RiakDashboardWeb.Paths do
  @moduledoc "Shared path helpers with proper URI encoding for Riak resource navigation."

  def object_path(type, bucket, key),
    do: "#{keys_path(type, bucket)}/#{encode_segment(key)}"

  def keys_path(type, bucket),
    do: "#{buckets_path(type)}/#{encode_segment(bucket)}/keys"

  def buckets_path(nil), do: "/buckets"
  def buckets_path("default"), do: "/buckets"
  def buckets_path(type), do: "/types/#{encode_segment(type)}/buckets"

  def bucket_props_path(type, bucket),
    do: "#{buckets_path(type)}/#{encode_segment(bucket)}/props"

  defp encode_segment(value),
    do: URI.encode(value, &URI.char_unreserved?/1)
end
