defmodule TSC.Coordinator.ChunkSizeTest do
  use ExUnit.Case, async: true

  alias TSC.Coordinator

  describe "chunk_size/2" do
    test "targets roughly two chunks per worker" do
      # 500 files / (10 workers * 2) = 25 files per chunk
      assert Coordinator.chunk_size(500, 10) == 25
    end

    test "never goes below the minimum chunk size" do
      assert Coordinator.chunk_size(20, 10) == 10
      assert Coordinator.chunk_size(1, 10) == 10
    end

    test "never exceeds the maximum chunk size" do
      assert Coordinator.chunk_size(10_000, 10) == 50
    end

    test "scales with pool size" do
      # Fewer workers -> bigger chunks (capped at max)
      assert Coordinator.chunk_size(500, 4) >= Coordinator.chunk_size(500, 10)
    end
  end
end
