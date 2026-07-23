# Benchmark: Elixir coordinator + moonbit-tsc CLI workers over a synthetic workload.
# Run: SECRET_KEY_BASE=... MIX_ENV=prod mix run --no-start bench_elixir.exs <src_dir> <runs>
Logger.configure(level: :warning)

[src_dir, runs_str] = System.argv()
runs = String.to_integer(runs_str)

mbtsc =
  System.get_env("MBTSC_BIN") ||
    "/Users/sriky/Personal/typescript/moonbit-tsc/src/moonbit/_build/native/release/build/cli/cli.exe"

Application.put_env(:tsc_phoenix, :moonbit_binary, mbtsc)
Application.put_env(:tsc_phoenix, :worker_pool_size, System.schedulers_online())
{:ok, _} = Application.ensure_all_started(:tsc_phoenix)

files = Path.wildcard(Path.join(src_dir, "*.ts")) |> Enum.sort()
IO.puts("pool_size=#{TSC.Worker.PoolSupervisor.pool_size()} files=#{length(files)}")

# Warmup
TSC.Coordinator.check_project(Enum.take(files, 20), incremental: false)

times =
  for n <- 1..runs do
    # Cold-run each iteration: cached types change how much checking happens
    TSC.Cache.TypeCache.clear()
    TSC.Cache.FileCache.clear()
    t0 = System.monotonic_time(:millisecond)
    result = TSC.Coordinator.check_project(files, incremental: false)
    dt = System.monotonic_time(:millisecond) - t0

    IO.puts(
      "run #{n}: #{dt}ms wall (coordinator says #{result.stats.elapsed_ms}ms, " <>
        "#{result.stats.files_checked} files, #{result.stats.levels} levels, #{result.stats.errors} errors)"
    )

    dt
  end

sorted = Enum.sort(times)
median = Enum.at(sorted, div(length(sorted), 2))
IO.puts("median: #{median}ms  min: #{List.first(sorted)}ms")
