defmodule RiakDashboardWeb.FormattersTest do
  use ExUnit.Case, async: true

  alias RiakDashboardWeb.Formatters

  describe "memory_total_mb/1" do
    test "returns pre-computed MB value" do
      assert Formatters.memory_total_mb(%{"memory_total_mb" => 512.3}) == 512.3
    end

    test "converts raw bytes to MB" do
      # 100 MB = 104_857_600 bytes
      assert Formatters.memory_total_mb(%{"memory" => %{"total" => 104_857_600}}) == 100.0
    end

    test "returns dash for missing data" do
      assert Formatters.memory_total_mb(%{}) == "-"
      assert Formatters.memory_total_mb(nil) == "-"
    end
  end

  describe "memory_processes_mb/1" do
    test "returns pre-computed MB value" do
      assert Formatters.memory_processes_mb(%{"memory_processes_mb" => 64.0}) == 64.0
    end

    test "converts raw bytes to MB" do
      assert Formatters.memory_processes_mb(%{"memory" => %{"processes" => 52_428_800}}) == 50.0
    end

    test "returns dash for missing data" do
      assert Formatters.memory_processes_mb(%{}) == "-"
    end
  end

  describe "memory_ets_mb/1" do
    test "returns pre-computed MB value" do
      assert Formatters.memory_ets_mb(%{"memory_ets_mb" => 32.5}) == 32.5
    end

    test "converts raw bytes to MB" do
      assert Formatters.memory_ets_mb(%{"memory" => %{"ets" => 10_485_760}}) == 10.0
    end

    test "returns dash for missing data" do
      assert Formatters.memory_ets_mb(%{}) == "-"
    end
  end

  describe "format_value/1" do
    test "formats map as pretty JSON" do
      result = Formatters.format_value(%{"key" => "val"})
      assert result =~ "\"key\""
      assert result =~ "\"val\""
    end

    test "formats list as pretty JSON" do
      result = Formatters.format_value([1, 2, 3])
      assert result == "[\n  1,\n  2,\n  3\n]"
    end

    test "returns binary as-is" do
      assert Formatters.format_value("hello") == "hello"
    end

    test "inspects atoms" do
      assert Formatters.format_value(:foo) == ":foo"
    end

    test "inspects integers" do
      assert Formatters.format_value(42) == "42"
    end
  end
end
