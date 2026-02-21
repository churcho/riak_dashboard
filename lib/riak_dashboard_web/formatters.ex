defmodule RiakDashboardWeb.Formatters do
  @moduledoc "Shared formatting helpers for memory stats and value display."

  def memory_total_mb(%{"memory_total_mb" => value}) when is_number(value),
    do: Float.round(value * 1.0, 1)

  def memory_total_mb(%{"memory" => %{"total" => bytes}}) when is_number(bytes),
    do: Float.round(bytes / 1_048_576, 1)

  def memory_total_mb(_), do: "-"

  def memory_processes_mb(%{"memory_processes_mb" => value}) when is_number(value),
    do: Float.round(value * 1.0, 1)

  def memory_processes_mb(%{"memory" => %{"processes" => bytes}}) when is_number(bytes),
    do: Float.round(bytes / 1_048_576, 1)

  def memory_processes_mb(_), do: "-"

  def memory_ets_mb(%{"memory_ets_mb" => value}) when is_number(value),
    do: Float.round(value * 1.0, 1)

  def memory_ets_mb(%{"memory" => %{"ets" => bytes}}) when is_number(bytes),
    do: Float.round(bytes / 1_048_576, 1)

  def memory_ets_mb(_), do: "-"

  def format_value(value) when is_map(value) or is_list(value),
    do: Jason.encode!(value, pretty: true)

  def format_value(value) when is_binary(value), do: value
  def format_value(value), do: inspect(value)
end
