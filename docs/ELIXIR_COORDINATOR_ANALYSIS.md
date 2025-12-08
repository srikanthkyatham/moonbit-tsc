# Elixir Coordinator + MoonBit Workers Analysis

## Overview

Elixir, built on the Erlang VM (BEAM), offers a unique approach to concurrency through the Actor model. This analysis explores using Elixir as the coordinator layer.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         ELIXIR COORDINATOR                                   │
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                         BEAM VM                                     │   │
│   │                                                                     │   │
│   │   ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐              │   │
│   │   │ Process │  │ Process │  │ Process │  │ Process │              │   │
│   │   │ (file1) │  │ (file2) │  │ (file3) │  │ (cache) │              │   │
│   │   └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘              │   │
│   │        │            │            │            │                    │   │
│   │        └────────────┴─────┬──────┴────────────┘                    │   │
│   │                           │                                        │   │
│   │                    ┌──────▼──────┐                                 │   │
│   │                    │ Supervisor  │                                 │   │
│   │                    │   Tree      │                                 │   │
│   │                    └──────┬──────┘                                 │   │
│   │                           │                                        │   │
│   └───────────────────────────┼────────────────────────────────────────┘   │
│                               │ Port (stdin/stdout)                        │
│                               │                                            │
└───────────────────────────────┼────────────────────────────────────────────┘
                                │
         ┌──────────────────────┼──────────────────────┐
         │                      │                      │
         ▼                      ▼                      ▼
   ┌───────────┐          ┌───────────┐          ┌───────────┐
   │  MoonBit  │          │  MoonBit  │          │  MoonBit  │
   │  Worker 1 │          │  Worker 2 │          │  Worker N │
   └───────────┘          └───────────┘          └───────────┘
```

---

## Elixir's Strengths

### 1. Actor Model / Process Isolation

```elixir
# Each file gets its own lightweight process
defmodule TypeChecker.FileWorker do
  use GenServer

  def start_link(file_path) do
    GenServer.start_link(__MODULE__, file_path)
  end

  def check(pid, source, imported_types) do
    GenServer.call(pid, {:check, source, imported_types}, :infinity)
  end

  @impl true
  def handle_call({:check, source, imported_types}, _from, state) do
    # Send to MoonBit worker via Port
    result = MoonBitPort.check(state.port, source, imported_types)
    {:reply, result, state}
  end
end

# Supervisor automatically restarts crashed workers
defmodule TypeChecker.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      {TypeChecker.TypeCache, []},
      {TypeChecker.WorkerPool, pool_size: System.schedulers_online()},
      {TypeChecker.FileWatcher, []},
      {TypeChecker.DependencyGraph, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

### 2. Fault Tolerance ("Let It Crash")

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    FAULT TOLERANCE COMPARISON                                │
└─────────────────────────────────────────────────────────────────────────────┘

Go:
┌─────────────────────────────────────────────────────────────────────────────┐
│  Worker crashes → Must handle manually:                                     │
│                                                                              │
│    if err != nil {                                                          │
│        // Restart worker                                                    │
│        // Retry request                                                     │
│        // Handle timeout                                                    │
│        // Log error                                                         │
│    }                                                                        │
│                                                                              │
│  Every error path must be explicitly coded                                  │
└─────────────────────────────────────────────────────────────────────────────┘

Elixir:
┌─────────────────────────────────────────────────────────────────────────────┐
│  Worker crashes → Supervisor automatically restarts:                        │
│                                                                              │
│    # Supervisor strategy handles it                                         │
│    children = [                                                             │
│      {Worker, restart: :permanent}  # Auto-restart on crash                 │
│    ]                                                                        │
│                                                                              │
│  "Let it crash" - errors are isolated, recovery is automatic                │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3. Message Passing (Native IPC)

```elixir
# Elixir processes communicate via message passing - same model as IPC!
defmodule TypeChecker.Coordinator do
  use GenServer

  def check_project(files) do
    # Spawn a process for each file
    tasks = Enum.map(files, fn file ->
      Task.async(fn -> check_file(file) end)
    end)

    # Collect results (message passing under the hood)
    Task.await_many(tasks, :infinity)
  end

  defp check_file(file) do
    imported_types = TypeCache.get_imports(file)

    # This naturally maps to IPC with MoonBit!
    MoonBitPort.call(:check, %{
      file: file,
      source: File.read!(file),
      imported_types: imported_types
    })
  end
end
```

### 4. Hot Code Reloading

```elixir
# Update coordinator logic without stopping the system
# MoonBit workers keep running!

# Before: v1.0
defmodule TypeChecker.Strategy do
  def check_order(files), do: files  # Simple order
end

# Hot reload to v1.1
defmodule TypeChecker.Strategy do
  def check_order(files) do
    # New: topological sort
    DependencyGraph.sort(files)
  end
end

# Zero downtime upgrade!
```

### 5. Built-in Distribution

```elixir
# Scale across machines trivially
defmodule TypeChecker.Distributed do
  def check_on_node(file, node) do
    # Run on remote node
    :rpc.call(node, TypeChecker, :check_file, [file])
  end

  def distributed_check(files) do
    nodes = [node() | Node.list()]

    files
    |> Enum.with_index()
    |> Enum.map(fn {file, i} ->
      node = Enum.at(nodes, rem(i, length(nodes)))
      Task.async(fn -> check_on_node(file, node) end)
    end)
    |> Task.await_many()
  end
end
```

---

## Elixir vs Go Comparison

### Concurrency Model

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CONCURRENCY MODELS                                   │
└─────────────────────────────────────────────────────────────────────────────┘

Go (CSP - Communicating Sequential Processes):
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│   Goroutine ──────► Channel ──────► Goroutine                               │
│                                                                              │
│   - Shared memory possible (mutex needed)                                   │
│   - Channels for communication                                              │
│   - Manual error handling                                                   │
│   - ~2KB per goroutine                                                      │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘

Elixir (Actor Model):
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│   Process ──────► Mailbox ──────► Process                                   │
│      │                               │                                       │
│      └───── Isolated Heap ───────────┘                                       │
│                                                                              │
│   - No shared memory (immutable)                                            │
│   - Message passing only                                                    │
│   - Automatic fault isolation                                               │
│   - ~0.5KB per process                                                      │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Detailed Comparison

| Aspect | Go | Elixir |
|--------|-----|--------|
| **Concurrency** | Goroutines + Channels | Processes + Mailboxes |
| **Memory Model** | Shared (needs mutex) | Isolated (no locks needed) |
| **Fault Tolerance** | Manual try/catch | Automatic supervision |
| **Hot Reload** | No (restart required) | Yes (zero downtime) |
| **Distribution** | Manual (gRPC, etc.) | Built-in (OTP) |
| **Startup Time** | ~5-10ms | ~500ms-1s (BEAM startup) |
| **Binary Size** | ~10-15MB | ~50MB+ (includes BEAM) |
| **Memory Baseline** | ~10-20MB | ~30-50MB |
| **Learning Curve** | Moderate | Steeper (FP paradigm) |
| **Ecosystem** | Mature (CLI tools) | Strong (web/distributed) |
| **Hiring Pool** | Large | Smaller |

### Performance Characteristics

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PERFORMANCE COMPARISON                               │
└─────────────────────────────────────────────────────────────────────────────┘

Startup Time:
┌────────────────────────────────────────────────────────────────────────────┐
│  Go:     ████  ~10ms                                                       │
│  Elixir: ████████████████████████████████████████████  ~500ms-1s           │
│                                                                            │
│  Winner: Go (50-100x faster cold start)                                    │
└────────────────────────────────────────────────────────────────────────────┘

Process/Goroutine Creation:
┌────────────────────────────────────────────────────────────────────────────┐
│  Go:     ████  ~1μs                                                        │
│  Elixir: ██  ~0.5μs                                                        │
│                                                                            │
│  Winner: Elixir (slightly faster, more lightweight)                        │
└────────────────────────────────────────────────────────────────────────────┘

Memory Per Unit:
┌────────────────────────────────────────────────────────────────────────────┐
│  Go Goroutine:     ████  ~2KB                                              │
│  Elixir Process:   ██  ~0.5KB                                              │
│                                                                            │
│  Winner: Elixir (4x less memory per concurrent unit)                       │
└────────────────────────────────────────────────────────────────────────────┘

Raw CPU Performance:
┌────────────────────────────────────────────────────────────────────────────┐
│  Go:     ████████████████████  ~1x (baseline)                              │
│  Elixir: ████████████  ~0.5-0.7x                                           │
│                                                                            │
│  Winner: Go (compiled to native code vs BEAM bytecode)                     │
└────────────────────────────────────────────────────────────────────────────┘

File I/O:
┌────────────────────────────────────────────────────────────────────────────┐
│  Go:     ████████████████████  Fast (native syscalls)                      │
│  Elixir: ████████████████  Good (BEAM scheduler + NIFs)                    │
│                                                                            │
│  Winner: Go (slightly faster)                                              │
└────────────────────────────────────────────────────────────────────────────┘
```

---

## Elixir Architecture for TypeScript Compiler

```elixir
# lib/tsc/application.ex
defmodule TSC.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Type cache (ETS-backed for fast concurrent reads)
      {TSC.TypeCache, []},

      # Dependency graph (GenServer)
      {TSC.DependencyGraph, []},

      # MoonBit worker pool (Poolboy or custom)
      {TSC.WorkerPool, size: System.schedulers_online()},

      # File watcher (FileSystem library)
      {TSC.FileWatcher, paths: ["./src"]},

      # CLI handler
      {TSC.CLI, []}
    ]

    opts = [strategy: :one_for_one, name: TSC.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

### Type Cache with ETS

```elixir
# lib/tsc/type_cache.ex
defmodule TSC.TypeCache do
  use GenServer

  @table :type_cache

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    # ETS table for concurrent reads without GenServer bottleneck
    :ets.new(@table, [:named_table, :public, read_concurrency: true])
    {:ok, %{}}
  end

  # Fast concurrent read (no GenServer call)
  def get(module_path) do
    case :ets.lookup(@table, module_path) do
      [{^module_path, exports}] -> {:ok, exports}
      [] -> :error
    end
  end

  # Write through GenServer (serialized)
  def put(module_path, exports) do
    GenServer.call(__MODULE__, {:put, module_path, exports})
  end

  @impl true
  def handle_call({:put, module_path, exports}, _from, state) do
    :ets.insert(@table, {module_path, exports})
    {:reply, :ok, state}
  end

  # Resolve imports for a file
  def resolve_imports(import_specs) do
    import_specs
    |> Enum.map(fn {specifier, resolved_path} ->
      case get(resolved_path) do
        {:ok, exports} -> {specifier, exports}
        :error -> {specifier, %{}}
      end
    end)
    |> Map.new()
  end
end
```

### MoonBit Port Communication

```elixir
# lib/tsc/moonbit_port.ex
defmodule TSC.MoonBitPort do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(_opts) do
    # Open port to MoonBit worker binary
    port = Port.open(
      {:spawn_executable, moonbit_worker_path()},
      [:binary, :exit_status, {:line, 1_000_000}]
    )
    {:ok, %{port: port, pending: %{}, next_id: 1}}
  end

  def check(pid, file, source, imported_types) do
    GenServer.call(pid, {:check, file, source, imported_types}, :infinity)
  end

  @impl true
  def handle_call({:check, file, source, imported_types}, from, state) do
    request = %{
      id: "req-#{state.next_id}",
      command: "check",
      file: file,
      source: source,
      importedTypes: imported_types
    }

    # Send JSON to MoonBit worker
    json = Jason.encode!(request) <> "\n"
    Port.command(state.port, json)

    # Store pending request
    pending = Map.put(state.pending, request.id, from)
    {:noreply, %{state | pending: pending, next_id: state.next_id + 1}}
  end

  @impl true
  def handle_info({port, {:data, {:eol, line}}}, %{port: port} = state) do
    # Parse response from MoonBit worker
    case Jason.decode(line) do
      {:ok, %{"id" => id} = response} ->
        case Map.pop(state.pending, id) do
          {nil, _} ->
            {:noreply, state}

          {from, pending} ->
            GenServer.reply(from, {:ok, response})
            {:noreply, %{state | pending: pending}}
        end

      {:error, _} ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    # Worker crashed - supervisor will restart this GenServer
    {:stop, {:worker_exit, status}, state}
  end

  defp moonbit_worker_path do
    Application.app_dir(:tsc, "priv/tsc-worker")
  end
end
```

### Worker Pool

```elixir
# lib/tsc/worker_pool.ex
defmodule TSC.WorkerPool do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    size = Keyword.get(opts, :size, System.schedulers_online())

    children =
      for i <- 1..size do
        Supervisor.child_spec(
          {TSC.MoonBitPort, []},
          id: {TSC.MoonBitPort, i}
        )
      end

    Supervisor.init(children, strategy: :one_for_one)
  end

  # Get a worker (round-robin or least-busy)
  def checkout do
    workers = Supervisor.which_children(__MODULE__)
    {_, pid, _, _} = Enum.random(workers)
    pid
  end
end
```

### Coordinator (Main Flow)

```elixir
# lib/tsc/coordinator.ex
defmodule TSC.Coordinator do
  alias TSC.{TypeCache, DependencyGraph, WorkerPool, MoonBitPort}

  def check_project(files) do
    # 1. Parse imports (parallel)
    imports = parse_imports_parallel(files)

    # 2. Build dependency graph
    DependencyGraph.build(files, imports)

    # 3. Get topological levels
    levels = DependencyGraph.topological_levels()

    # 4. Check each level
    diagnostics =
      levels
      |> Enum.flat_map(&check_level/1)

    # 5. Return results
    %{
      success: Enum.all?(diagnostics, &(&1.category != :error)),
      diagnostics: diagnostics
    }
  end

  defp check_level(files) do
    # Check all files in level concurrently
    files
    |> Task.async_stream(
      fn file -> check_file(file) end,
      max_concurrency: System.schedulers_online(),
      timeout: :infinity
    )
    |> Enum.flat_map(fn
      {:ok, {:ok, result}} -> result.diagnostics
      {:ok, {:error, reason}} -> [%{message: reason, category: :error}]
      {:exit, reason} -> [%{message: inspect(reason), category: :error}]
    end)
  end

  defp check_file(file) do
    # Get imports for this file
    imports = DependencyGraph.get_imports(file)
    imported_types = TypeCache.resolve_imports(imports)

    # Get a worker from pool
    worker = WorkerPool.checkout()

    # Send to MoonBit
    source = File.read!(file)
    result = MoonBitPort.check(worker, file, source, imported_types)

    # Store exports in cache
    case result do
      {:ok, %{"exportedTypes" => exports}} ->
        TypeCache.put(file, exports)
      _ ->
        :ok
    end

    result
  end

  defp parse_imports_parallel(files) do
    files
    |> Task.async_stream(fn file ->
      source = File.read!(file)
      # Quick regex or send to MoonBit for parsing
      {file, extract_imports(source)}
    end)
    |> Enum.map(fn {:ok, result} -> result end)
    |> Map.new()
  end
end
```

### File Watcher

```elixir
# lib/tsc/file_watcher.ex
defmodule TSC.FileWatcher do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    paths = Keyword.get(opts, :paths, ["."])

    # Use FileSystem library (wraps inotify/FSEvents)
    {:ok, watcher_pid} = FileSystem.start_link(dirs: paths)
    FileSystem.subscribe(watcher_pid)

    {:ok, %{watcher: watcher_pid, debounce: %{}}}
  end

  @impl true
  def handle_info({:file_event, _watcher, {path, events}}, state) do
    if should_process?(path, events) do
      # Debounce rapid changes
      state = schedule_check(state, path)
      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:check_file, path}, state) do
    # Trigger incremental check
    TSC.Coordinator.check_file_incremental(path)

    debounce = Map.delete(state.debounce, path)
    {:noreply, %{state | debounce: debounce}}
  end

  defp should_process?(path, events) do
    String.ends_with?(path, [".ts", ".tsx"]) and
      Enum.any?(events, &(&1 in [:modified, :created]))
  end

  defp schedule_check(state, path) do
    # Cancel existing timer
    case Map.get(state.debounce, path) do
      nil -> :ok
      ref -> Process.cancel_timer(ref)
    end

    # Schedule new check in 100ms
    ref = Process.send_after(self(), {:check_file, path}, 100)
    %{state | debounce: Map.put(state.debounce, path, ref)}
  end
end
```

---

## CLI with Elixir (escript)

```elixir
# lib/tsc/cli.ex
defmodule TSC.CLI do
  def main(args) do
    {opts, files, _} = OptionParser.parse(args,
      strict: [
        project: :string,
        watch: :boolean,
        out_dir: :string,
        parallel: :integer
      ],
      aliases: [p: :project, w: :watch, o: :out_dir]
    )

    # Start the application
    Application.ensure_all_started(:tsc)

    case opts do
      %{watch: true} ->
        run_watch_mode(opts, files)

      _ ->
        run_single_check(opts, files)
    end
  end

  defp run_single_check(opts, files) do
    files = resolve_files(opts, files)
    result = TSC.Coordinator.check_project(files)

    print_diagnostics(result.diagnostics)

    if result.success do
      System.halt(0)
    else
      System.halt(1)
    end
  end

  defp run_watch_mode(opts, files) do
    files = resolve_files(opts, files)

    # Initial check
    result = TSC.Coordinator.check_project(files)
    print_diagnostics(result.diagnostics)

    IO.puts("\nWatching for file changes...")

    # Keep running (FileWatcher handles changes)
    Process.sleep(:infinity)
  end
end
```

---

## Comparison: Go vs Elixir for This Project

### Pros of Elixir

| Aspect | Benefit |
|--------|---------|
| **Supervision Trees** | Automatic restart of crashed MoonBit workers |
| **Process Isolation** | One bad file can't crash the whole system |
| **Message Passing** | Natural fit for IPC with MoonBit |
| **Hot Reload** | Update coordinator without restarting workers |
| **ETS** | Lock-free concurrent reads for type cache |
| **Pattern Matching** | Clean handling of JSON responses |
| **Distribution** | Scale to multiple machines trivially |
| **Functional** | Immutable data = fewer bugs |

### Cons of Elixir

| Aspect | Challenge |
|--------|-----------|
| **Startup Time** | ~500ms-1s (BEAM boot) vs Go's ~10ms |
| **Binary Size** | ~50MB+ (includes BEAM) vs Go's ~10MB |
| **Memory** | ~30-50MB baseline vs Go's ~10-20MB |
| **Raw CPU** | Slower than Go for compute |
| **CLI Tooling** | Less mature than Go (cobra/viper) |
| **Hiring** | Smaller pool than Go |
| **Learning Curve** | FP paradigm shift |
| **Single Binary** | Needs BEAM or Burrito for packaging |

### When Elixir Shines

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Elixir is EXCELLENT for:                                                   │
│                                                                              │
│  ✅ Long-running processes (LSP server, watch mode)                         │
│  ✅ High concurrency (thousands of files)                                   │
│  ✅ Fault tolerance (workers can crash safely)                              │
│  ✅ Distributed builds (multiple machines)                                  │
│  ✅ Hot code updates (zero-downtime deploys)                                │
│                                                                              │
│  Elixir is LESS ideal for:                                                  │
│                                                                              │
│  ❌ Single-file compilation (startup overhead)                              │
│  ❌ Minimal binary distribution                                             │
│  ❌ Raw CPU performance                                                     │
│  ❌ Teams without FP experience                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Head-to-Head: Go vs Elixir vs Pure MoonBit

| Aspect | Pure MoonBit | Go | Elixir |
|--------|-------------|-----|--------|
| **Startup** | ⭐⭐⭐⭐ ~20ms | ⭐⭐⭐⭐⭐ ~10ms | ⭐⭐ ~500ms |
| **Binary Size** | ⭐⭐⭐⭐ ~5MB | ⭐⭐⭐ ~12MB | ⭐ ~50MB+ |
| **Memory** | ⭐⭐⭐⭐ ~10MB | ⭐⭐⭐ ~20MB | ⭐⭐ ~40MB |
| **Concurrency** | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Fault Tolerance** | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Hot Reload** | ⭐ | ⭐ | ⭐⭐⭐⭐⭐ |
| **Distribution** | ⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| **CLI Ecosystem** | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Hiring Pool** | ⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Dev Speed** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |

---

## Recommendation Matrix

| Use Case | Recommended |
|----------|-------------|
| **CLI tool (fast startup)** | Go |
| **Watch mode (long-running)** | Elixir or Go |
| **LSP server** | Elixir (fault tolerance) |
| **Distributed builds** | Elixir |
| **Single binary** | Go |
| **Maximum performance** | Go + WASM |
| **Team has FP experience** | Elixir |
| **Team has Go experience** | Go |
| **Learning project** | Pure MoonBit |

---

## Final Recommendation

### For This TypeScript Compiler Project:

**Primary: Go** - Better for CLI tools
```
┌─────────────────────────────────────────────────────────────────────────────┐
│  - Fast startup (critical for CLI)                                          │
│  - Small binary                                                              │
│  - Large hiring pool                                                         │
│  - typescript-go code can be reused                                         │
│  - Mature CLI ecosystem                                                      │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Consider Elixir if:**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│  - Building LSP server (long-running, fault tolerance critical)             │
│  - Distributed compilation across machines                                  │
│  - Team has Elixir experience                                               │
│  - Watch mode is primary use case                                           │
│  - Zero-downtime updates matter                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Hybrid Possibility

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    HYBRID: GO CLI + ELIXIR LSP                              │
│                                                                              │
│   CLI (Go):                          LSP Server (Elixir):                   │
│   ┌──────────────────────┐           ┌──────────────────────┐               │
│   │  $ tsc ./src         │           │  Long-running        │               │
│   │                      │           │  Fault-tolerant      │               │
│   │  Fast startup        │           │  Hot-reloadable      │               │
│   │  Single check        │           │  Handles crashes     │               │
│   │  Exit when done      │           │  gracefully          │               │
│   └──────────┬───────────┘           └──────────┬───────────┘               │
│              │                                  │                            │
│              └──────────────┬───────────────────┘                            │
│                             │                                                │
│                             ▼                                                │
│                    ┌────────────────────┐                                   │
│                    │   MoonBit Workers  │                                   │
│                    │   (shared)         │                                   │
│                    └────────────────────┘                                   │
│                                                                              │
│   Same MoonBit compiler code, different coordinators for different needs    │
└─────────────────────────────────────────────────────────────────────────────┘
```

This hybrid approach gives you:
- **Go CLI** for fast, single-shot compilation
- **Elixir LSP** for robust, long-running IDE support
- **Same MoonBit workers** for both (IPC protocol unchanged)
