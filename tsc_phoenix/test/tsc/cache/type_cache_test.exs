defmodule TSC.Cache.TypeCacheTest do
  use ExUnit.Case, async: false

  alias TSC.Cache.TypeCache

  @test_cache_dir Path.expand("../../../tmp/test_cache", __DIR__)

  setup do
    # Clean up test cache directory
    File.rm_rf!(@test_cache_dir)
    File.mkdir_p!(@test_cache_dir)

    # Clear cache before each test
    TypeCache.clear()

    on_exit(fn ->
      File.rm_rf!(@test_cache_dir)
    end)

    :ok
  end

  describe "basic operations" do
    test "put and get" do
      exports = %{"MyType" => %{"kind" => "interface"}}
      TypeCache.put("/path/to/module.ts", exports)

      assert {:ok, ^exports} = TypeCache.get("/path/to/module.ts")
    end

    test "get returns :not_found for missing module" do
      assert :not_found = TypeCache.get("/nonexistent.ts")
    end

    test "delete removes entry" do
      TypeCache.put("/path/to/module.ts", %{"Test" => %{}})
      TypeCache.delete("/path/to/module.ts")

      assert :not_found = TypeCache.get("/path/to/module.ts")
    end

    test "clear removes all entries" do
      TypeCache.put("/path/one.ts", %{"A" => %{}})
      TypeCache.put("/path/two.ts", %{"B" => %{}})
      TypeCache.clear()

      assert :not_found = TypeCache.get("/path/one.ts")
      assert :not_found = TypeCache.get("/path/two.ts")
    end

    test "has? checks existence" do
      TypeCache.put("/exists.ts", %{})

      assert TypeCache.has?("/exists.ts") == true
      assert TypeCache.has?("/missing.ts") == false
    end

    test "keys returns all cached paths" do
      TypeCache.put("/a.ts", %{})
      TypeCache.put("/b.ts", %{})

      keys = TypeCache.keys()
      assert "/a.ts" in keys
      assert "/b.ts" in keys
    end

    test "get_many returns multiple exports" do
      TypeCache.put("/a.ts", %{"A" => %{}})
      TypeCache.put("/b.ts", %{"B" => %{}})

      result = TypeCache.get_many(["/a.ts", "/b.ts", "/c.ts"])

      assert Map.has_key?(result, "/a.ts")
      assert Map.has_key?(result, "/b.ts")
      refute Map.has_key?(result, "/c.ts")
    end

    test "stats returns cache statistics" do
      TypeCache.put("/test.ts", %{"Test" => %{}})

      stats = TypeCache.stats()

      assert stats.entries >= 1
      assert is_number(stats.memory_bytes)
      assert is_number(stats.memory_mb)
    end
  end

  describe "disk persistence" do
    test "save_to_disk creates cache file" do
      TypeCache.put("/module.ts", %{"Export" => %{"kind" => "type"}})
      TypeCache.save_to_disk(cache_dir: @test_cache_dir)

      cache_file = Path.join(@test_cache_dir, "type_cache.etf")
      assert File.exists?(cache_file)
    end

    test "load_from_disk restores entries" do
      # Put and save
      exports = %{"MyInterface" => %{"kind" => "interface", "members" => []}}
      TypeCache.put("/module.ts", exports)
      TypeCache.save_to_disk(cache_dir: @test_cache_dir)

      # Clear and reload
      TypeCache.clear()
      assert :not_found = TypeCache.get("/module.ts")

      TypeCache.load_from_disk(cache_dir: @test_cache_dir)
      assert {:ok, ^exports} = TypeCache.get("/module.ts")
    end

    test "load_from_disk filters expired entries" do
      # Create a cache file with an old timestamp
      old_timestamp = System.system_time(:millisecond) - (25 * 60 * 60 * 1000) # 25 hours ago
      entries = [{"/old.ts", %{"Old" => %{}}, old_timestamp}]

      cache_file = Path.join(@test_cache_dir, "type_cache.etf")
      File.write!(cache_file, :erlang.term_to_binary(entries, [:compressed]))

      TypeCache.load_from_disk(cache_dir: @test_cache_dir, ttl_hours: 24)

      # Old entry should not be loaded
      assert :not_found = TypeCache.get("/old.ts")
    end

    test "load_from_disk keeps valid entries" do
      # Create a cache file with a recent timestamp
      recent_timestamp = System.system_time(:millisecond) - (1 * 60 * 60 * 1000) # 1 hour ago
      entries = [{"/recent.ts", %{"Recent" => %{}}, recent_timestamp}]

      cache_file = Path.join(@test_cache_dir, "type_cache.etf")
      File.write!(cache_file, :erlang.term_to_binary(entries, [:compressed]))

      TypeCache.load_from_disk(cache_dir: @test_cache_dir, ttl_hours: 24)

      # Recent entry should be loaded
      assert {:ok, %{"Recent" => %{}}} = TypeCache.get("/recent.ts")
    end

    test "save_to_disk respects persist_to_disk: false" do
      TypeCache.put("/module.ts", %{"Test" => %{}})
      TypeCache.save_to_disk(cache_dir: @test_cache_dir, persist_to_disk: false)

      cache_file = Path.join(@test_cache_dir, "type_cache.etf")
      refute File.exists?(cache_file)
    end
  end

  describe "tsconfig invalidation" do
    test "invalidate_on_tsconfig_change clears cache when tsconfig changes" do
      tsconfig_path = Path.join(@test_cache_dir, "tsconfig.json")
      File.write!(tsconfig_path, ~s({"compilerOptions": {"strict": true}}))

      # First call stores the hash
      TypeCache.put("/module.ts", %{"Test" => %{}})
      result1 = TypeCache.invalidate_on_tsconfig_change(tsconfig_path, cache_dir: @test_cache_dir)
      assert result1 == :invalidated

      # Cache should be cleared
      assert :not_found = TypeCache.get("/module.ts")

      # Same tsconfig, should not invalidate
      TypeCache.put("/module2.ts", %{"Test2" => %{}})
      result2 = TypeCache.invalidate_on_tsconfig_change(tsconfig_path, cache_dir: @test_cache_dir)
      assert result2 == :unchanged
      assert {:ok, _} = TypeCache.get("/module2.ts")

      # Change tsconfig
      File.write!(tsconfig_path, ~s({"compilerOptions": {"strict": false}}))
      result3 = TypeCache.invalidate_on_tsconfig_change(tsconfig_path, cache_dir: @test_cache_dir)
      assert result3 == :invalidated
      assert :not_found = TypeCache.get("/module2.ts")
    end

    test "invalidate_on_tsconfig_change handles missing tsconfig" do
      result = TypeCache.invalidate_on_tsconfig_change("/nonexistent/tsconfig.json", cache_dir: @test_cache_dir)
      # First call will be :invalidated since there's no stored hash
      assert result == :invalidated
    end
  end

  describe "cache pruning" do
    test "prune_expired removes old entries" do
      # Insert entries with different timestamps
      :ets.insert(:tsc_type_cache, {"/recent.ts", %{}, System.system_time(:millisecond)})
      old_ts = System.system_time(:millisecond) - (25 * 60 * 60 * 1000)
      :ets.insert(:tsc_type_cache, {"/old.ts", %{}, old_ts})

      pruned = TypeCache.prune_expired(24)

      assert pruned == 1
      assert TypeCache.has?("/recent.ts")
      refute TypeCache.has?("/old.ts")
    end
  end

  describe "cache_dir" do
    test "returns default cache dir" do
      assert TypeCache.cache_dir() == ".tsc_cache"
    end

    test "returns configured cache dir" do
      assert TypeCache.cache_dir(cache_dir: "/custom/path") == "/custom/path"
    end
  end
end
