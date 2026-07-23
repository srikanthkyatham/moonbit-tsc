# Attribute Elixir coordinator overhead by phase.
Logger.configure(level: :warning)
[src_dir] = System.argv()

mbtsc =
  "/Users/sriky/Personal/typescript/moonbit-tsc/src/moonbit/_build/native/release/build/cli/cli.exe"

Application.put_env(:tsc_phoenix, :moonbit_binary, mbtsc)
Application.put_env(:tsc_phoenix, :worker_pool_size, System.schedulers_online())
{:ok, _} = Application.ensure_all_started(:tsc_phoenix)

files = Path.wildcard(Path.join(src_dir, "*.ts")) |> Enum.sort()

time = fn label, fun ->
  t0 = System.monotonic_time(:millisecond)
  res = fun.()
  IO.puts("#{label}: #{System.monotonic_time(:millisecond) - t0}ms")
  res
end

# Phase A: import extraction (dep graph input) as coordinator does it
time.("import extraction (#{length(files)} files, concurrency 10)", fn ->
  files
  |> Task.async_stream(fn f -> TSC.Parser.ImportExtractor.extract(f) end,
    max_concurrency: 10,
    timeout: 60_000
  )
  |> Enum.count()
end)

# Phase B: chunked pool checking alone (what check_levels does), cold cache
TSC.Cache.TypeCache.clear()

time.("chunked pool check (50 chunks x 10 files, 10 workers)", fn ->
  files
  |> Enum.chunk_every(10)
  |> Task.async_stream(
    fn chunk -> TSC.Worker.PoolSupervisor.check_files(chunk, %{use_cached_types: true}) end,
    max_concurrency: 20,
    timeout: 120_000
  )
  |> Enum.count()
end)

# Phase C: same but without external-types JSON building
TSC.Cache.TypeCache.clear()

time.("chunked pool check (no cached types)", fn ->
  files
  |> Enum.chunk_every(10)
  |> Task.async_stream(
    fn chunk -> TSC.Worker.PoolSupervisor.check_files(chunk, %{}) end,
    max_concurrency: 20,
    timeout: 120_000
  )
  |> Enum.count()
end)
