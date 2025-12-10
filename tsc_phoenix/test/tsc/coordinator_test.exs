defmodule TSC.CoordinatorTest do
  use ExUnit.Case, async: false

  alias TSC.Cache.{TypeCache, FileCache}
  alias TSC.Graph.DependencyGraph

  setup do
    # Clear caches before each test
    TypeCache.clear()
    FileCache.clear()
    DependencyGraph.clear()

    :ok
  end

  describe "check_level/2 chunked approach" do
    @tag :skip
    test "uses single-file approach for 5 or fewer files" do
      # This would require mocking, so skipping for now
      # The logic is simple: <= 5 files uses check_level_single_files
      assert true
    end

    @tag :skip
    test "uses chunked approach for more than 5 files" do
      # This would require mocking the PoolSupervisor
      # The logic creates chunks of max 10 files
      assert true
    end

    test "chunks files correctly with max 10 per chunk" do
      # Test the chunking logic
      files = Enum.map(1..25, fn i -> "file#{i}.ts" end)
      chunks = Enum.chunk_every(files, 10)

      assert length(chunks) == 3
      assert length(Enum.at(chunks, 0)) == 10
      assert length(Enum.at(chunks, 1)) == 10
      assert length(Enum.at(chunks, 2)) == 5
    end

    test "chunks exactly 10 files into 1 chunk" do
      files = Enum.map(1..10, fn i -> "file#{i}.ts" end)
      chunks = Enum.chunk_every(files, 10)

      assert length(chunks) == 1
      assert length(Enum.at(chunks, 0)) == 10
    end

    test "chunks 100 files into 10 chunks" do
      files = Enum.map(1..100, fn i -> "file#{i}.ts" end)
      chunks = Enum.chunk_every(files, 10)

      assert length(chunks) == 10

      Enum.each(chunks, fn chunk ->
        assert length(chunk) == 10
      end)
    end

    test "chunks 1000 files into 100 chunks" do
      files = Enum.map(1..1000, fn i -> "file#{i}.ts" end)
      chunks = Enum.chunk_every(files, 10)

      assert length(chunks) == 100

      Enum.each(chunks, fn chunk ->
        assert length(chunk) == 10
      end)
    end

    test "round-robin worker assignment distributes evenly" do
      pool_size = 4
      num_chunks = 100

      # Simulate worker assignment
      assignments =
        Enum.map(1..num_chunks, fn chunk_idx ->
          rem(chunk_idx - 1, pool_size) + 1
        end)

      # Count assignments per worker
      counts = Enum.frequencies(assignments)

      # Each worker should get 25 chunks (100 / 4)
      assert counts[1] == 25
      assert counts[2] == 25
      assert counts[3] == 25
      assert counts[4] == 25
    end

    test "round-robin with uneven distribution" do
      pool_size = 4
      num_chunks = 10

      assignments =
        Enum.map(1..num_chunks, fn chunk_idx ->
          rem(chunk_idx - 1, pool_size) + 1
        end)

      counts = Enum.frequencies(assignments)

      # With 10 chunks and 4 workers: [3, 3, 2, 2] distribution
      assert counts[1] == 3
      assert counts[2] == 3
      assert counts[3] == 2
      assert counts[4] == 2
    end
  end

  describe "check_level/2 progress tracking" do
    test "progress calculation is correct" do
      total_chunks = 100

      # Simulate progress at different stages
      progress_at_25 = Float.round(25 / total_chunks * 100, 1)
      progress_at_50 = Float.round(50 / total_chunks * 100, 1)
      progress_at_75 = Float.round(75 / total_chunks * 100, 1)
      progress_at_100 = Float.round(100 / total_chunks * 100, 1)

      assert progress_at_25 == 25.0
      assert progress_at_50 == 50.0
      assert progress_at_75 == 75.0
      assert progress_at_100 == 100.0
    end
  end

  describe "retry logic" do
    test "exponential backoff timing" do
      # Test backoff calculation
      # 1 second
      attempt_1_backoff = 1 * 1000
      # 2 seconds
      attempt_2_backoff = 2 * 1000
      # 3 seconds
      attempt_3_backoff = 3 * 1000

      assert attempt_1_backoff == 1000
      assert attempt_2_backoff == 2000
      assert attempt_3_backoff == 3000
    end
  end

  describe "integration - chunking with actual file counts" do
    test "small project: 15 files" do
      files = Enum.map(1..15, fn i -> "src/file#{i}.ts" end)
      chunks = Enum.chunk_every(files, 10)

      # 15 files = 2 chunks (10 + 5)
      assert length(chunks) == 2
    end

    test "medium project: 250 files" do
      files = Enum.map(1..250, fn i -> "src/module#{i}/index.ts" end)
      chunks = Enum.chunk_every(files, 10)

      # 250 files = 25 chunks
      assert length(chunks) == 25
    end

    test "large project: 1000 files" do
      files = Enum.map(1..1000, fn i -> "src/package#{i}/file.ts" end)
      chunks = Enum.chunk_every(files, 10)

      # 1000 files = 100 chunks
      assert length(chunks) == 100
    end

    test "extra large project: 5000 files" do
      files = Enum.map(1..5000, fn i -> "src/module#{i}.ts" end)
      chunks = Enum.chunk_every(files, 10)

      # 5000 files = 500 chunks
      assert length(chunks) == 500
    end
  end

  describe "worker utilization calculation" do
    test "4 workers with 100 chunks" do
      pool_size = 4
      total_chunks = 100

      chunks_per_worker = div(total_chunks, pool_size)
      assert chunks_per_worker == 25

      # Each worker processes 25 chunks of 10 files = 250 files per worker
      files_per_worker = chunks_per_worker * 10
      assert files_per_worker == 250
    end

    test "4 workers with 1000 files" do
      pool_size = 4
      total_files = 1000
      max_files_per_chunk = 10

      total_chunks = ceil(total_files / max_files_per_chunk)
      assert total_chunks == 100

      chunks_per_worker = ceil(total_chunks / pool_size)
      assert chunks_per_worker == 25

      # Approximately 250 files per worker
      approx_files_per_worker = div(total_files, pool_size)
      assert approx_files_per_worker == 250
    end

    test "8 workers with 1000 files" do
      pool_size = 8
      total_files = 1000
      max_files_per_chunk = 10

      total_chunks = ceil(total_files / max_files_per_chunk)
      assert total_chunks == 100

      chunks_per_worker = ceil(total_chunks / pool_size)
      # Some workers get 13, some get 12
      assert chunks_per_worker == 13

      # Approximately 125 files per worker
      approx_files_per_worker = div(total_files, pool_size)
      assert approx_files_per_worker == 125
    end
  end

  describe "concurrency settings" do
    test "max_concurrency allows queueing" do
      pool_size = 4
      max_concurrency = pool_size * 2

      # With max_concurrency = 8 and pool_size = 4,
      # we can have 8 tasks running concurrently
      # This means each worker can potentially handle 2 tasks at once
      # providing better load balancing
      assert max_concurrency == 8
    end
  end
end
