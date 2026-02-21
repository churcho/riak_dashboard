defmodule RiakDashboardWeb.PathsTest do
  use ExUnit.Case, async: true

  alias RiakDashboardWeb.Paths

  describe "buckets_path/1" do
    test "nil type returns untyped path" do
      assert Paths.buckets_path(nil) == "/buckets"
    end

    test "\"default\" type returns untyped path" do
      assert Paths.buckets_path("default") == "/buckets"
    end

    test "custom type returns typed path" do
      assert Paths.buckets_path("maps") == "/types/maps/buckets"
    end
  end

  describe "keys_path/2" do
    test "nil type returns untyped path" do
      assert Paths.keys_path(nil, "users") == "/buckets/users/keys"
    end

    test "\"default\" type returns untyped path" do
      assert Paths.keys_path("default", "users") == "/buckets/users/keys"
    end

    test "custom type returns typed path" do
      assert Paths.keys_path("maps", "users") == "/types/maps/buckets/users/keys"
    end
  end

  describe "object_path/3" do
    test "nil type returns untyped path" do
      assert Paths.object_path(nil, "users", "key1") == "/buckets/users/keys/key1"
    end

    test "custom type returns typed path" do
      assert Paths.object_path("maps", "users", "key1") ==
               "/types/maps/buckets/users/keys/key1"
    end
  end

  describe "bucket_props_path/2" do
    test "nil type returns untyped path" do
      assert Paths.bucket_props_path(nil, "users") == "/buckets/users/props"
    end

    test "\"default\" type returns untyped path" do
      assert Paths.bucket_props_path("default", "users") == "/buckets/users/props"
    end

    test "custom type returns typed path" do
      assert Paths.bucket_props_path("maps", "users") == "/types/maps/buckets/users/props"
    end
  end

  describe "URI encoding" do
    test "encodes slashes in segment" do
      assert Paths.buckets_path("a/b") == "/types/a%2Fb/buckets"
    end

    test "encodes question marks in segment" do
      assert Paths.keys_path(nil, "b?x") == "/buckets/b%3Fx/keys"
    end

    test "encodes hash in segment" do
      assert Paths.object_path(nil, "b", "k#1") == "/buckets/b/keys/k%231"
    end

    test "encodes spaces as %20" do
      assert Paths.keys_path(nil, "my bucket") == "/buckets/my%20bucket/keys"
    end

    test "encodes literal plus as %2B" do
      assert Paths.keys_path(nil, "a+b") == "/buckets/a%2Bb/keys"
    end
  end
end
