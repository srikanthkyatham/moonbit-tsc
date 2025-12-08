# Elixir Coordinator Implementation Plan

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ELIXIR APPLICATION                                 │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                         SUPERVISOR TREE                               │  │
│  │                                                                       │  │
│  │                        TSC.Supervisor                                 │  │
│  │                             │                                         │  │
│  │     ┌───────────┬───────────┼───────────┬───────────┐                │  │
│  │     │           │           │           │           │                │  │
│  │     ▼           ▼           ▼           ▼           ▼                │  │
│  │  ┌──────┐  ┌─────────┐  ┌────────┐  ┌─────────┐  ┌──────────┐       │  │
│  │  │ Type │  │ Worker  │  │  Dep   │  │  File   │  │   CLI    │       │  │
│  │  │ Cache│  │  Pool   │  │ Graph  │  │ Watcher │  │ Handler  │       │  │
│  │  │ (ETS)│  │Supervisor│  │        │  │         │  │          │       │  │
│  │  └──────┘  └────┬────┘  └────────┘  └─────────┘  └──────────┘       │  │
│  │                 │                                                    │  │
│  │     ┌───────────┼───────────┬───────────┐                           │  │
│  │     │           │           │           │                           │  │
│  │     ▼           ▼           ▼           ▼                           │  │
│  │  ┌──────┐   ┌──────┐   ┌──────┐   ┌──────┐                         │  │
│  │  │ Port │   │ Port │   │ Port │   │ Port │  (MoonBit Workers)      │  │
│  │  │  1   │   │  2   │   │  3   │   │  N   │                         │  │
│  │  └──┬───┘   └──┬───┘   └──┬───┘   └──┬───┘                         │  │
│  │     │          │          │          │                              │  │
│  └─────┼──────────┼──────────┼──────────┼──────────────────────────────┘  │
│        │          │          │          │                                 │
└────────┼──────────┼──────────┼──────────┼─────────────────────────────────┘
         │ stdin    │          │          │
         │ stdout   │          │          │
         ▼          ▼          ▼          ▼
   ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
   │ MoonBit  │ │ MoonBit  │ │ MoonBit  │ │ MoonBit  │
   │ Worker   │ │ Worker   │ │ Worker   │ │ Worker   │
   │ Binary   │ │ Binary   │ │ Binary   │ │ Binary   │
   └──────────┘ └──────────┘ └──────────┘ └──────────┘
```

---

## Project Structure

```
tsc_ex/
├── mix.exs                          # Project config
├── config/
│   ├── config.exs                   # General config
│   ├── dev.exs                      # Dev config
│   └── prod.exs                     # Production config
│
├── lib/
│   ├── tsc.ex                       # Main module
│   │
│   ├── tsc/
│   │   ├── application.ex           # OTP Application
│   │   ├── supervisor.ex            # Root supervisor
│   │   │
│   │   ├── cache/
│   │   │   ├── type_cache.ex        # ETS-based type cache
│   │   │   └── file_cache.ex        # ETS-based file content cache
│   │   │
│   │   ├── worker/
│   │   │   ├── pool_supervisor.ex   # Worker pool supervisor
│   │   │   ├── moonbit_port.ex      # Port to MoonBit binary
│   │   │   └── protocol.ex          # JSON protocol encoding/decoding
│   │   │
│   │   ├── graph/
│   │   │   ├── dependency_graph.ex  # DAG for file dependencies
│   │   │   └── topological_sort.ex  # Kahn's algorithm
│   │   │
│   │   ├── watcher/
│   │   │   └── file_watcher.ex      # FileSystem-based watcher
│   │   │
│   │   ├── coordinator/
│   │   │   ├── coordinator.ex       # Main orchestration logic
│   │   │   └── level_checker.ex     # Check files by dependency level
│   │   │
│   │   └── cli/
│   │       ├── cli.ex               # escript entry point
│   │       ├── parser.ex            # Argument parsing
│   │       └── formatter.ex         # Diagnostic output formatting
│   │
│   └── mix/
│       └── tasks/
│           └── tsc.ex               # Mix task: mix tsc
│
├── priv/
│   └── moonbit_worker               # MoonBit worker binary (copied at build)
│
├── test/
│   ├── tsc_test.exs
│   ├── cache/
│   │   └── type_cache_test.exs
│   ├── worker/
│   │   └── moonbit_port_test.exs
│   └── coordinator/
│       └── coordinator_test.exs
│
└── rel/
    └── config.exs                   # Release config (Burrito for single binary)
```

---

## Implementation Phases

### Phase 1: Project Setup & ETS Cache (Days 1-2)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 1: FOUNDATION                                                         │
│                                                                              │
│  Goals:                                                                      │
│  - Set up Elixir project with proper supervision                            │
│  - Implement ETS-based type cache                                           │
│  - Implement ETS-based file content cache                                   │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 1.1 Project Setup

```elixir
# mix.exs
defmodule TSC.MixProject do
  use Mix.Project

  def project do
    [
      app: :tsc,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript(),
      releases: releases()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {TSC.Application, []}
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},           # JSON encoding/decoding
      {:file_system, "~> 1.0"},     # File watching
      {:optimus, "~> 0.3"},         # CLI parsing
      {:burrito, "~> 1.0"}          # Single binary packaging
    ]
  end

  defp escript do
    [main_module: TSC.CLI]
  end

  defp releases do
    [
      tsc: [
        steps: [:assemble, &Burrito.wrap/1],
        burrito: [
          targets: [
            macos_arm: [os: :darwin, cpu: :aarch64],
            macos_x86: [os: :darwin, cpu: :x86_64],
            linux: [os: :linux, cpu: :x86_64],
            windows: [os: :windows, cpu: :x86_64]
          ]
        ]
      ]
    ]
  end
end
```

#### 1.2 Application & Supervisor

```elixir
# lib/tsc/application.ex
defmodule TSC.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # ETS tables must be started first
      TSC.Cache.TypeCache,
      TSC.Cache.FileCache,

      # Then the rest
      TSC.Graph.DependencyGraph,
      {TSC.Worker.PoolSupervisor, pool_size: worker_pool_size()},
      TSC.Watcher.FileWatcher
    ]

    opts = [strategy: :one_for_one, name: TSC.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp worker_pool_size do
    Application.get_env(:tsc, :worker_pool_size, System.schedulers_online())
  end
end
```

#### 1.3 ETS Type Cache

```elixir
# lib/tsc/cache/type_cache.ex
defmodule TSC.Cache.TypeCache do
  @moduledoc """
  ETS-based cache for exported types from modules.

  Uses ETS for:
  - Lock-free concurrent reads (read_concurrency: true)
  - Fast lookups without GenServer bottleneck
  - Automatic cleanup on process termination
  """

  use GenServer

  @table :tsc_type_cache
  @stats_table :tsc_type_cache_stats

  # ============================================================================
  # Public API (direct ETS access for reads)
  # ============================================================================

  @doc """
  Get exported types for a module. Lock-free read.
  """
  @spec get(String.t()) :: {:ok, map()} | :not_found
  def get(module_path) do
    case :ets.lookup(@table, module_path) do
      [{^module_path, exports, _timestamp}] ->
        inc_stat(:hits)
        {:ok, exports}

      [] ->
        inc_stat(:misses)
        :not_found
    end
  end

  @doc """
  Get multiple module exports at once.
  """
  @spec get_many([String.t()]) :: %{String.t() => map()}
  def get_many(module_paths) do
    module_paths
    |> Enum.map(fn path ->
      case get(path) do
        {:ok, exports} -> {path, exports}
        :not_found -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Map.new()
  end

  @doc """
  Resolve imported types for a file based on import specifiers.
  """
  @spec resolve_imports([{String.t(), String.t()}]) :: map()
  def resolve_imports(import_specs) do
    import_specs
    |> Enum.map(fn {specifier, resolved_path} ->
      case get(resolved_path) do
        {:ok, exports} -> {specifier, exports}
        :not_found -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Map.new()
  end

  @doc """
  Store exported types for a module. Goes through GenServer for serialization.
  """
  @spec put(String.t(), map()) :: :ok
  def put(module_path, exports) do
    GenServer.call(__MODULE__, {:put, module_path, exports})
  end

  @doc """
  Invalidate a module's cached exports.
  """
  @spec invalidate(String.t()) :: :ok
  def invalidate(module_path) do
    GenServer.call(__MODULE__, {:invalidate, module_path})
  end

  @doc """
  Invalidate multiple modules.
  """
  @spec invalidate_many([String.t()]) :: :ok
  def invalidate_many(module_paths) do
    GenServer.call(__MODULE__, {:invalidate_many, module_paths})
  end

  @doc """
  Clear entire cache.
  """
  @spec clear() :: :ok
  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  @doc """
  Get cache statistics.
  """
  @spec stats() :: map()
  def stats do
    case :ets.lookup(@stats_table, :stats) do
      [{:stats, hits, misses}] ->
        total = hits + misses
        hit_rate = if total > 0, do: hits / total * 100, else: 0.0

        %{
          hits: hits,
          misses: misses,
          total: total,
          hit_rate: Float.round(hit_rate, 2),
          entries: :ets.info(@table, :size)
        }

      [] ->
        %{hits: 0, misses: 0, total: 0, hit_rate: 0.0, entries: 0}
    end
  end

  # ============================================================================
  # GenServer Implementation
  # ============================================================================

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    # Main cache table - optimized for concurrent reads
    :ets.new(@table, [
      :named_table,
      :public,
      :set,
      read_concurrency: true,
      write_concurrency: false  # Writes go through GenServer anyway
    ])

    # Stats table
    :ets.new(@stats_table, [
      :named_table,
      :public,
      :set,
      write_concurrency: true
    ])
    :ets.insert(@stats_table, {:stats, 0, 0})

    {:ok, %{}}
  end

  @impl true
  def handle_call({:put, module_path, exports}, _from, state) do
    timestamp = System.monotonic_time(:millisecond)
    :ets.insert(@table, {module_path, exports, timestamp})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:invalidate, module_path}, _from, state) do
    :ets.delete(@table, module_path)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:invalidate_many, module_paths}, _from, state) do
    Enum.each(module_paths, &:ets.delete(@table, &1))
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(@table)
    :ets.insert(@stats_table, {:stats, 0, 0})
    {:reply, :ok, state}
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp inc_stat(:hits) do
    :ets.update_counter(@stats_table, :stats, {2, 1})
  rescue
    ArgumentError -> :ok
  end

  defp inc_stat(:misses) do
    :ets.update_counter(@stats_table, :stats, {3, 1})
  rescue
    ArgumentError -> :ok
  end
end
```

#### 1.4 ETS File Cache

```elixir
# lib/tsc/cache/file_cache.ex
defmodule TSC.Cache.FileCache do
  @moduledoc """
  ETS-based cache for file contents and hashes.
  Avoids re-reading unchanged files.
  """

  use GenServer

  @table :tsc_file_cache

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Get file content. Returns cached version if file hasn't changed.
  """
  @spec get_content(String.t()) :: {:ok, String.t(), String.t()} | {:error, term()}
  def get_content(file_path) do
    case :ets.lookup(@table, file_path) do
      [{^file_path, content, hash, mtime}] ->
        # Check if file has been modified
        case File.stat(file_path) do
          {:ok, %{mtime: ^mtime}} ->
            # File unchanged, return cached
            {:ok, content, hash}

          {:ok, %{mtime: new_mtime}} ->
            # File changed, reload
            reload_file(file_path, new_mtime)

          {:error, reason} ->
            {:error, reason}
        end

      [] ->
        # Not cached, load fresh
        load_file(file_path)
    end
  end

  @doc """
  Get content hash only (for change detection).
  """
  @spec get_hash(String.t()) :: {:ok, String.t()} | :not_found
  def get_hash(file_path) do
    case get_content(file_path) do
      {:ok, _content, hash} -> {:ok, hash}
      _ -> :not_found
    end
  end

  @doc """
  Invalidate a file's cache entry.
  """
  @spec invalidate(String.t()) :: :ok
  def invalidate(file_path) do
    :ets.delete(@table, file_path)
    :ok
  end

  # ============================================================================
  # GenServer
  # ============================================================================

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    :ets.new(@table, [
      :named_table,
      :public,
      :set,
      read_concurrency: true
    ])

    {:ok, %{}}
  end

  # ============================================================================
  # Private
  # ============================================================================

  defp load_file(file_path) do
    case File.stat(file_path) do
      {:ok, %{mtime: mtime}} ->
        case File.read(file_path) do
          {:ok, content} ->
            hash = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
            :ets.insert(@table, {file_path, content, hash, mtime})
            {:ok, content, hash}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp reload_file(file_path, mtime) do
    case File.read(file_path) do
      {:ok, content} ->
        hash = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
        :ets.insert(@table, {file_path, content, hash, mtime})
        {:ok, content, hash}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

---

### Phase 2: MoonBit Port Communication (Days 3-5)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 2: PORT COMMUNICATION                                                 │
│                                                                              │
│  Goals:                                                                      │
│  - Implement Port wrapper for MoonBit worker                                │
│  - JSON protocol encoding/decoding                                          │
│  - Worker pool with supervision                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 2.1 JSON Protocol

```elixir
# lib/tsc/worker/protocol.ex
defmodule TSC.Worker.Protocol do
  @moduledoc """
  JSON-RPC-like protocol for MoonBit worker communication.
  """

  # ============================================================================
  # Request Building
  # ============================================================================

  @doc """
  Build a check request.
  """
  def check_request(id, file, source, imported_types, options \\ %{}) do
    %{
      id: id,
      command: "check",
      file: file,
      source: source,
      importedTypes: imported_types,
      options: options
    }
  end

  @doc """
  Build a parse request (for import extraction).
  """
  def parse_request(id, file, source) do
    %{
      id: id,
      command: "parse",
      file: file,
      source: source
    }
  end

  @doc """
  Build a ping request.
  """
  def ping_request(id) do
    %{
      id: id,
      command: "ping"
    }
  end

  @doc """
  Build a shutdown request.
  """
  def shutdown_request(id) do
    %{
      id: id,
      command: "shutdown"
    }
  end

  # ============================================================================
  # Encoding/Decoding
  # ============================================================================

  @doc """
  Encode a request to JSON line.
  """
  def encode(request) do
    Jason.encode!(request) <> "\n"
  end

  @doc """
  Decode a JSON response.
  """
  def decode(json_line) do
    case Jason.decode(json_line) do
      {:ok, response} -> {:ok, parse_response(response)}
      {:error, reason} -> {:error, {:json_decode_error, reason}}
    end
  end

  # ============================================================================
  # Response Parsing
  # ============================================================================

  defp parse_response(%{"id" => id, "success" => success} = response) do
    %{
      id: id,
      success: success,
      diagnostics: parse_diagnostics(response["diagnostics"] || []),
      exported_types: response["exportedTypes"],
      js: response["js"],
      source_map: response["sourceMap"],
      declaration: response["declaration"],
      imports: response["imports"]  # For parse command
    }
  end

  defp parse_response(response) do
    {:error, {:invalid_response, response}}
  end

  defp parse_diagnostics(diagnostics) when is_list(diagnostics) do
    Enum.map(diagnostics, &parse_diagnostic/1)
  end

  defp parse_diagnostic(diag) do
    %{
      file: diag["file"],
      line: diag["line"],
      column: diag["column"],
      end_line: diag["endLine"],
      end_column: diag["endColumn"],
      code: diag["code"],
      category: parse_category(diag["category"]),
      message: diag["message"]
    }
  end

  defp parse_category("error"), do: :error
  defp parse_category("warning"), do: :warning
  defp parse_category("suggestion"), do: :suggestion
  defp parse_category("message"), do: :message
  defp parse_category(_), do: :error
end
```

#### 2.2 MoonBit Port GenServer

```elixir
# lib/tsc/worker/moonbit_port.ex
defmodule TSC.Worker.MoonBitPort do
  @moduledoc """
  GenServer managing a Port to a MoonBit worker process.

  Each MoonBitPort instance:
  - Spawns one MoonBit worker binary via Port
  - Handles JSON request/response communication
  - Tracks pending requests for async responses
  - Restarts worker if it crashes (via supervisor)
  """

  use GenServer
  require Logger

  alias TSC.Worker.Protocol

  @default_timeout 60_000

  # ============================================================================
  # Public API
  # ============================================================================

  def start_link(opts) do
    name = Keyword.get(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Check a file. Blocks until response received.
  """
  @spec check(pid() | atom(), String.t(), String.t(), map(), map()) ::
          {:ok, map()} | {:error, term()}
  def check(server, file, source, imported_types, options \\ %{}) do
    GenServer.call(server, {:check, file, source, imported_types, options}, @default_timeout)
  end

  @doc """
  Parse a file for imports.
  """
  @spec parse(pid() | atom(), String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def parse(server, file, source) do
    GenServer.call(server, {:parse, file, source}, @default_timeout)
  end

  @doc """
  Ping the worker to check if it's alive.
  """
  @spec ping(pid() | atom()) :: :pong | {:error, term()}
  def ping(server) do
    case GenServer.call(server, :ping, 5_000) do
      {:ok, _} -> :pong
      error -> error
    end
  end

  @doc """
  Get worker status.
  """
  @spec status(pid() | atom()) :: map()
  def status(server) do
    GenServer.call(server, :status)
  end

  # ============================================================================
  # GenServer Implementation
  # ============================================================================

  defmodule State do
    defstruct [
      :port,
      :worker_path,
      :pending,
      :next_id,
      :buffer,
      :request_count,
      :start_time
    ]
  end

  @impl true
  def init(opts) do
    worker_path = Keyword.get(opts, :worker_path, default_worker_path())

    case open_port(worker_path) do
      {:ok, port} ->
        state = %State{
          port: port,
          worker_path: worker_path,
          pending: %{},
          next_id: 1,
          buffer: "",
          request_count: 0,
          start_time: System.monotonic_time(:millisecond)
        }

        {:ok, state}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:check, file, source, imported_types, options}, from, state) do
    {id, state} = next_request_id(state)
    request = Protocol.check_request(id, file, source, imported_types, options)
    send_request(state.port, request)

    pending = Map.put(state.pending, id, from)
    {:noreply, %{state | pending: pending, request_count: state.request_count + 1}}
  end

  @impl true
  def handle_call({:parse, file, source}, from, state) do
    {id, state} = next_request_id(state)
    request = Protocol.parse_request(id, file, source)
    send_request(state.port, request)

    pending = Map.put(state.pending, id, from)
    {:noreply, %{state | pending: pending, request_count: state.request_count + 1}}
  end

  @impl true
  def handle_call(:ping, from, state) do
    {id, state} = next_request_id(state)
    request = Protocol.ping_request(id)
    send_request(state.port, request)

    pending = Map.put(state.pending, id, from)
    {:noreply, %{state | pending: pending}}
  end

  @impl true
  def handle_call(:status, _from, state) do
    uptime = System.monotonic_time(:millisecond) - state.start_time

    status = %{
      pending_requests: map_size(state.pending),
      request_count: state.request_count,
      uptime_ms: uptime,
      port_alive: Port.info(state.port) != nil
    }

    {:reply, status, state}
  end

  @impl true
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    # Accumulate data in buffer and process complete lines
    buffer = state.buffer <> data
    {lines, remaining} = extract_lines(buffer)

    state = %{state | buffer: remaining}

    state =
      Enum.reduce(lines, state, fn line, acc ->
        handle_response_line(line, acc)
      end)

    {:noreply, state}
  end

  @impl true
  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    Logger.error("MoonBit worker exited with status #{status}")

    # Reply to all pending requests with error
    Enum.each(state.pending, fn {_id, from} ->
      GenServer.reply(from, {:error, {:worker_exit, status}})
    end)

    # Stop - supervisor will restart us
    {:stop, {:worker_exit, status}, %{state | pending: %{}}}
  end

  @impl true
  def handle_info({:EXIT, port, reason}, %{port: port} = state) do
    Logger.error("MoonBit worker port closed: #{inspect(reason)}")

    Enum.each(state.pending, fn {_id, from} ->
      GenServer.reply(from, {:error, {:port_closed, reason}})
    end)

    {:stop, {:port_closed, reason}, %{state | pending: %{}}}
  end

  @impl true
  def terminate(_reason, state) do
    if state.port && Port.info(state.port) do
      # Try graceful shutdown
      {id, _} = next_request_id(state)
      request = Protocol.shutdown_request(id)
      send_request(state.port, request)
      Process.sleep(100)
      Port.close(state.port)
    end

    :ok
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp open_port(worker_path) do
    if File.exists?(worker_path) do
      port =
        Port.open({:spawn_executable, worker_path}, [
          :binary,
          :exit_status,
          :use_stdio,
          :stderr_to_stdout,
          {:line, 1_000_000}  # Max line length 1MB
        ])

      {:ok, port}
    else
      {:error, {:worker_not_found, worker_path}}
    end
  end

  defp send_request(port, request) do
    data = Protocol.encode(request)
    Port.command(port, data)
  end

  defp next_request_id(state) do
    id = "req-#{state.next_id}"
    {id, %{state | next_id: state.next_id + 1}}
  end

  defp extract_lines(buffer) do
    case String.split(buffer, "\n", parts: 2) do
      [line, rest] ->
        {more_lines, remaining} = extract_lines(rest)
        {[line | more_lines], remaining}

      [incomplete] ->
        {[], incomplete}
    end
  end

  defp handle_response_line(line, state) do
    case Protocol.decode(line) do
      {:ok, response} ->
        handle_response(response, state)

      {:error, reason} ->
        Logger.warning("Failed to decode response: #{inspect(reason)}")
        state
    end
  end

  defp handle_response(%{id: id} = response, state) do
    case Map.pop(state.pending, id) do
      {nil, _pending} ->
        Logger.warning("Received response for unknown request: #{id}")
        state

      {from, pending} ->
        GenServer.reply(from, {:ok, response})
        %{state | pending: pending}
    end
  end

  defp default_worker_path do
    Application.app_dir(:tsc, "priv/moonbit_worker")
  end
end
```

#### 2.3 Worker Pool Supervisor

```elixir
# lib/tsc/worker/pool_supervisor.ex
defmodule TSC.Worker.PoolSupervisor do
  @moduledoc """
  Supervises a pool of MoonBit worker Ports.
  """

  use Supervisor

  alias TSC.Worker.MoonBitPort

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    pool_size = Keyword.get(opts, :pool_size, System.schedulers_online())
    worker_path = Keyword.get(opts, :worker_path)

    children =
      for i <- 1..pool_size do
        worker_opts = [
          name: worker_name(i),
          worker_path: worker_path
        ]
        |> Enum.reject(fn {_, v} -> is_nil(v) end)

        Supervisor.child_spec(
          {MoonBitPort, worker_opts},
          id: {MoonBitPort, i}
        )
      end

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Get a worker from the pool (round-robin).
  """
  @spec checkout() :: pid()
  def checkout do
    children = Supervisor.which_children(__MODULE__)
    count = length(children)
    index = rem(:erlang.unique_integer([:positive]), count)
    {_, pid, _, _} = Enum.at(children, index)
    pid
  end

  @doc """
  Get all workers.
  """
  @spec all_workers() :: [pid()]
  def all_workers do
    __MODULE__
    |> Supervisor.which_children()
    |> Enum.map(fn {_, pid, _, _} -> pid end)
  end

  @doc """
  Get pool status.
  """
  @spec status() :: map()
  def status do
    workers = all_workers()

    statuses =
      workers
      |> Enum.map(&MoonBitPort.status/1)

    %{
      pool_size: length(workers),
      total_requests: Enum.sum(Enum.map(statuses, & &1.request_count)),
      total_pending: Enum.sum(Enum.map(statuses, & &1.pending_requests)),
      all_alive: Enum.all?(statuses, & &1.port_alive)
    }
  end

  defp worker_name(index), do: :"tsc_worker_#{index}"
end
```

---

### Phase 3: Dependency Graph (Days 6-7)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 3: DEPENDENCY GRAPH                                                   │
│                                                                              │
│  Goals:                                                                      │
│  - Build dependency graph from imports                                      │
│  - Topological sort for check ordering                                      │
│  - Incremental invalidation                                                 │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 3.1 Dependency Graph

```elixir
# lib/tsc/graph/dependency_graph.ex
defmodule TSC.Graph.DependencyGraph do
  @moduledoc """
  Manages file dependency graph for incremental type checking.

  Stored in ETS for fast concurrent access.
  """

  use GenServer

  @deps_table :tsc_deps        # file -> [dependencies]
  @rdeps_table :tsc_rdeps      # file -> [dependents (reverse)]
  @imports_table :tsc_imports  # file -> [{specifier, resolved_path}]

  # ============================================================================
  # Public API
  # ============================================================================

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Build graph from file -> imports mapping.
  """
  @spec build(%{String.t() => [{String.t(), String.t()}]}) :: :ok
  def build(file_imports) do
    GenServer.call(__MODULE__, {:build, file_imports})
  end

  @doc """
  Update dependencies for a single file.
  """
  @spec update_file(String.t(), [{String.t(), String.t()}]) :: :ok
  def update_file(file, imports) do
    GenServer.call(__MODULE__, {:update_file, file, imports})
  end

  @doc """
  Get direct dependencies of a file.
  """
  @spec get_dependencies(String.t()) :: [String.t()]
  def get_dependencies(file) do
    case :ets.lookup(@deps_table, file) do
      [{^file, deps}] -> deps
      [] -> []
    end
  end

  @doc """
  Get direct dependents of a file (who imports this file).
  """
  @spec get_dependents(String.t()) :: [String.t()]
  def get_dependents(file) do
    case :ets.lookup(@rdeps_table, file) do
      [{^file, rdeps}] -> rdeps
      [] -> []
    end
  end

  @doc """
  Get all transitive dependents of a file.
  """
  @spec get_all_dependents(String.t()) :: [String.t()]
  def get_all_dependents(file) do
    get_all_dependents_recursive(file, MapSet.new())
    |> MapSet.delete(file)
    |> MapSet.to_list()
  end

  @doc """
  Get import specifiers for a file.
  """
  @spec get_imports(String.t()) :: [{String.t(), String.t()}]
  def get_imports(file) do
    case :ets.lookup(@imports_table, file) do
      [{^file, imports}] -> imports
      [] -> []
    end
  end

  @doc """
  Get topological levels for all files.
  Returns list of lists, where each inner list can be processed in parallel.
  """
  @spec topological_levels() :: [[String.t()]]
  def topological_levels do
    files = get_all_files()
    TSC.Graph.TopologicalSort.levels(files, &get_dependencies/1)
  end

  @doc """
  Get topological levels for specific files (and their dependencies).
  """
  @spec topological_levels([String.t()]) :: [[String.t()]]
  def topological_levels(files) do
    # Include all dependencies
    all_files = expand_with_dependencies(files)
    TSC.Graph.TopologicalSort.levels(all_files, &get_dependencies/1)
  end

  @doc """
  Clear the graph.
  """
  @spec clear() :: :ok
  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  # ============================================================================
  # GenServer
  # ============================================================================

  @impl true
  def init(_) do
    :ets.new(@deps_table, [:named_table, :public, :set, read_concurrency: true])
    :ets.new(@rdeps_table, [:named_table, :public, :set, read_concurrency: true])
    :ets.new(@imports_table, [:named_table, :public, :set, read_concurrency: true])

    {:ok, %{}}
  end

  @impl true
  def handle_call({:build, file_imports}, _from, state) do
    :ets.delete_all_objects(@deps_table)
    :ets.delete_all_objects(@rdeps_table)
    :ets.delete_all_objects(@imports_table)

    # Build forward deps and store imports
    Enum.each(file_imports, fn {file, imports} ->
      deps = imports |> Enum.map(fn {_, resolved} -> resolved end) |> Enum.uniq()
      :ets.insert(@deps_table, {file, deps})
      :ets.insert(@imports_table, {file, imports})
    end)

    # Build reverse deps
    build_reverse_deps(file_imports)

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:update_file, file, imports}, _from, state) do
    # Remove old reverse deps
    old_deps = get_dependencies(file)

    Enum.each(old_deps, fn dep ->
      old_rdeps = get_dependents(dep)
      new_rdeps = List.delete(old_rdeps, file)
      :ets.insert(@rdeps_table, {dep, new_rdeps})
    end)

    # Update forward deps
    new_deps = imports |> Enum.map(fn {_, resolved} -> resolved end) |> Enum.uniq()
    :ets.insert(@deps_table, {file, new_deps})
    :ets.insert(@imports_table, {file, imports})

    # Update reverse deps
    Enum.each(new_deps, fn dep ->
      rdeps = get_dependents(dep)
      :ets.insert(@rdeps_table, {dep, [file | rdeps] |> Enum.uniq()})
    end)

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(@deps_table)
    :ets.delete_all_objects(@rdeps_table)
    :ets.delete_all_objects(@imports_table)
    {:reply, :ok, state}
  end

  # ============================================================================
  # Private
  # ============================================================================

  defp build_reverse_deps(file_imports) do
    reverse_map =
      file_imports
      |> Enum.flat_map(fn {file, imports} ->
        imports
        |> Enum.map(fn {_, resolved} -> {resolved, file} end)
      end)
      |> Enum.group_by(fn {dep, _} -> dep end, fn {_, file} -> file end)

    Enum.each(reverse_map, fn {dep, dependents} ->
      :ets.insert(@rdeps_table, {dep, Enum.uniq(dependents)})
    end)
  end

  defp get_all_files do
    :ets.tab2list(@deps_table)
    |> Enum.map(fn {file, _} -> file end)
  end

  defp get_all_dependents_recursive(file, visited) do
    if MapSet.member?(visited, file) do
      visited
    else
      visited = MapSet.put(visited, file)

      get_dependents(file)
      |> Enum.reduce(visited, fn dep, acc ->
        get_all_dependents_recursive(dep, acc)
      end)
    end
  end

  defp expand_with_dependencies(files) do
    files
    |> Enum.reduce(MapSet.new(files), fn file, acc ->
      deps = get_all_dependencies_recursive(file, MapSet.new())
      MapSet.union(acc, deps)
    end)
    |> MapSet.to_list()
  end

  defp get_all_dependencies_recursive(file, visited) do
    if MapSet.member?(visited, file) do
      visited
    else
      visited = MapSet.put(visited, file)

      get_dependencies(file)
      |> Enum.reduce(visited, fn dep, acc ->
        get_all_dependencies_recursive(dep, acc)
      end)
    end
  end
end
```

#### 3.2 Topological Sort

```elixir
# lib/tsc/graph/topological_sort.ex
defmodule TSC.Graph.TopologicalSort do
  @moduledoc """
  Kahn's algorithm for topological sorting with levels.
  Returns files grouped by dependency level for parallel processing.
  """

  @doc """
  Returns list of levels, where each level contains files that can be
  processed in parallel (no dependencies on each other).
  """
  @spec levels([String.t()], (String.t() -> [String.t()])) :: [[String.t()]]
  def levels(files, get_deps_fn) do
    # Build in-degree map
    file_set = MapSet.new(files)

    in_degrees =
      files
      |> Enum.map(fn file ->
        deps = get_deps_fn.(file)
        # Only count deps that are in our file set
        in_degree = Enum.count(deps, &MapSet.member?(file_set, &1))
        {file, in_degree}
      end)
      |> Map.new()

    # Process levels
    process_levels(in_degrees, get_deps_fn, file_set, [])
    |> Enum.reverse()
  end

  defp process_levels(in_degrees, get_deps_fn, file_set, acc) do
    # Find all nodes with in-degree 0
    level =
      in_degrees
      |> Enum.filter(fn {_, degree} -> degree == 0 end)
      |> Enum.map(fn {file, _} -> file end)

    if level == [] do
      # Check for cycles
      if map_size(in_degrees) > 0 do
        remaining = Map.keys(in_degrees)
        raise "Circular dependency detected involving: #{inspect(remaining)}"
      end

      acc
    else
      # Remove processed nodes and update in-degrees
      new_in_degrees =
        in_degrees
        |> Map.drop(level)
        |> update_in_degrees(level, get_deps_fn, file_set)

      process_levels(new_in_degrees, get_deps_fn, file_set, [level | acc])
    end
  end

  defp update_in_degrees(in_degrees, processed, _get_deps_fn, file_set) do
    # For each file that was just processed, find files that depend on it
    # and decrement their in-degree

    # This is slightly inefficient but correct - we iterate through remaining
    # files and check if any of their deps were just processed
    processed_set = MapSet.new(processed)

    in_degrees
    |> Enum.map(fn {file, degree} ->
      # Count how many of file's dependencies were just processed
      # We need to get fresh deps since they might include processed files
      decrement =
        in_degrees
        |> Map.keys()
        |> Enum.count(fn _ ->
          # This isn't right - we need the original deps
          false
        end)

      {file, degree - decrement}
    end)
    |> Map.new()
  end
end
```

---

### Phase 4: Coordinator (Days 8-10)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 4: COORDINATOR                                                        │
│                                                                              │
│  Goals:                                                                      │
│  - Main orchestration logic                                                 │
│  - Level-by-level parallel checking                                         │
│  - Incremental checking                                                     │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 4.1 Main Coordinator

```elixir
# lib/tsc/coordinator/coordinator.ex
defmodule TSC.Coordinator do
  @moduledoc """
  Main orchestration logic for type checking.
  """

  require Logger

  alias TSC.Cache.{TypeCache, FileCache}
  alias TSC.Graph.DependencyGraph
  alias TSC.Worker.{PoolSupervisor, MoonBitPort}

  @doc """
  Check an entire project.
  """
  @spec check_project([String.t()], map()) :: %{success: boolean(), diagnostics: [map()]}
  def check_project(files, options \\ %{}) do
    Logger.info("Checking #{length(files)} files...")
    start_time = System.monotonic_time(:millisecond)

    # 1. Parse imports in parallel
    Logger.debug("Parsing imports...")
    file_imports = parse_imports_parallel(files)

    # 2. Build dependency graph
    Logger.debug("Building dependency graph...")
    DependencyGraph.build(file_imports)

    # 3. Get topological levels
    levels = DependencyGraph.topological_levels()
    Logger.debug("Found #{length(levels)} dependency levels")

    # 4. Check each level
    diagnostics =
      levels
      |> Enum.with_index()
      |> Enum.flat_map(fn {level_files, level_index} ->
        Logger.debug("Checking level #{level_index}: #{length(level_files)} files")
        check_level(level_files, options)
      end)

    elapsed = System.monotonic_time(:millisecond) - start_time
    Logger.info("Check completed in #{elapsed}ms")

    # 5. Return results
    %{
      success: Enum.all?(diagnostics, &(&1.category != :error)),
      diagnostics: diagnostics,
      stats: %{
        files_checked: length(files),
        elapsed_ms: elapsed,
        cache_stats: TypeCache.stats()
      }
    }
  end

  @doc """
  Incrementally check files that changed.
  """
  @spec check_incremental([String.t()], map()) :: %{success: boolean(), diagnostics: [map()]}
  def check_incremental(changed_files, options \\ %{}) do
    Logger.info("Incremental check for #{length(changed_files)} changed files")

    # 1. Find all affected files (changed + dependents)
    affected_files =
      changed_files
      |> Enum.flat_map(fn file ->
        [file | DependencyGraph.get_all_dependents(file)]
      end)
      |> Enum.uniq()

    Logger.debug("#{length(affected_files)} files affected")

    # 2. Invalidate caches for affected files
    TypeCache.invalidate_many(affected_files)

    # 3. Re-parse imports for changed files
    changed_imports =
      changed_files
      |> parse_imports_parallel()

    # 4. Update dependency graph
    Enum.each(changed_imports, fn {file, imports} ->
      DependencyGraph.update_file(file, imports)
    end)

    # 5. Get topological levels for affected files only
    levels = DependencyGraph.topological_levels(affected_files)

    # 6. Check each level
    diagnostics =
      levels
      |> Enum.flat_map(&check_level(&1, options))

    %{
      success: Enum.all?(diagnostics, &(&1.category != :error)),
      diagnostics: diagnostics
    }
  end

  # ============================================================================
  # Private
  # ============================================================================

  defp parse_imports_parallel(files) do
    files
    |> Task.async_stream(
      fn file -> {file, parse_file_imports(file)} end,
      max_concurrency: System.schedulers_online(),
      timeout: 30_000
    )
    |> Enum.map(fn {:ok, result} -> result end)
    |> Map.new()
  end

  defp parse_file_imports(file) do
    case FileCache.get_content(file) do
      {:ok, source, _hash} ->
        worker = PoolSupervisor.checkout()

        case MoonBitPort.parse(worker, file, source) do
          {:ok, %{imports: imports}} when is_list(imports) ->
            Enum.map(imports, fn imp ->
              {imp["specifier"], resolve_import(file, imp["specifier"])}
            end)

          _ ->
            []
        end

      _ ->
        []
    end
  end

  defp check_level(files, options) do
    files
    |> Task.async_stream(
      fn file -> check_file(file, options) end,
      max_concurrency: System.schedulers_online(),
      timeout: :infinity
    )
    |> Enum.flat_map(fn
      {:ok, diagnostics} -> diagnostics
      {:exit, reason} -> [%{message: inspect(reason), category: :error}]
    end)
  end

  defp check_file(file, options) do
    case FileCache.get_content(file) do
      {:ok, source, _hash} ->
        # Get imports for this file
        imports = DependencyGraph.get_imports(file)

        # Resolve imported types from cache
        imported_types = TypeCache.resolve_imports(imports)

        # Get a worker
        worker = PoolSupervisor.checkout()

        # Check the file
        case MoonBitPort.check(worker, file, source, imported_types, options) do
          {:ok, result} ->
            # Store exported types
            if result.exported_types do
              TypeCache.put(file, result.exported_types)
            end

            result.diagnostics

          {:error, reason} ->
            [%{file: file, message: inspect(reason), category: :error}]
        end

      {:error, reason} ->
        [%{file: file, message: "Failed to read: #{inspect(reason)}", category: :error}]
    end
  end

  defp resolve_import(from_file, specifier) do
    # Simple resolution - in real implementation this would handle:
    # - Relative paths (./foo, ../bar)
    # - Node modules
    # - Path aliases from tsconfig
    # - .ts/.tsx/.d.ts extension resolution

    dir = Path.dirname(from_file)

    cond do
      String.starts_with?(specifier, "./") or String.starts_with?(specifier, "../") ->
        specifier
        |> String.replace_prefix("./", "")
        |> String.replace_prefix("../", "../")
        |> then(&Path.join(dir, &1))
        |> resolve_extension()

      true ->
        # Node module - would look in node_modules
        specifier
    end
  end

  defp resolve_extension(path) do
    cond do
      File.exists?(path <> ".ts") -> path <> ".ts"
      File.exists?(path <> ".tsx") -> path <> ".tsx"
      File.exists?(path <> "/index.ts") -> path <> "/index.ts"
      File.exists?(path <> "/index.tsx") -> path <> "/index.tsx"
      File.exists?(path) -> path
      true -> path <> ".ts"
    end
  end
end
```

---

### Phase 5: File Watcher & CLI (Days 11-13)

```elixir
# lib/tsc/watcher/file_watcher.ex
defmodule TSC.Watcher.FileWatcher do
  use GenServer
  require Logger

  @debounce_ms 100

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def watch(paths) do
    GenServer.call(__MODULE__, {:watch, paths})
  end

  def stop_watching do
    GenServer.call(__MODULE__, :stop)
  end

  @impl true
  def init(_opts) do
    {:ok, %{watcher: nil, pending: %{}, paths: []}}
  end

  @impl true
  def handle_call({:watch, paths}, _from, state) do
    # Stop existing watcher if any
    if state.watcher, do: FileSystem.stop(state.watcher)

    # Start new watcher
    {:ok, watcher} = FileSystem.start_link(dirs: paths)
    FileSystem.subscribe(watcher)

    {:reply, :ok, %{state | watcher: watcher, paths: paths}}
  end

  @impl true
  def handle_call(:stop, _from, state) do
    if state.watcher, do: FileSystem.stop(state.watcher)
    {:reply, :ok, %{state | watcher: nil}}
  end

  @impl true
  def handle_info({:file_event, _watcher, {path, events}}, state) do
    if should_handle?(path, events) do
      # Cancel existing timer for this file
      state = cancel_pending(state, path)

      # Schedule debounced check
      ref = Process.send_after(self(), {:check, path}, @debounce_ms)
      pending = Map.put(state.pending, path, ref)

      {:noreply, %{state | pending: pending}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:check, path}, state) do
    Logger.info("File changed: #{path}")

    # Invalidate file cache
    TSC.Cache.FileCache.invalidate(path)

    # Trigger incremental check
    Task.start(fn ->
      result = TSC.Coordinator.check_incremental([path])
      TSC.CLI.Formatter.print_diagnostics(result.diagnostics)
    end)

    pending = Map.delete(state.pending, path)
    {:noreply, %{state | pending: pending}}
  end

  defp should_handle?(path, events) do
    is_ts_file?(path) and has_relevant_event?(events)
  end

  defp is_ts_file?(path) do
    String.ends_with?(path, [".ts", ".tsx", ".mts", ".cts"])
  end

  defp has_relevant_event?(events) do
    Enum.any?(events, &(&1 in [:modified, :created, :renamed]))
  end

  defp cancel_pending(state, path) do
    case Map.get(state.pending, path) do
      nil -> state
      ref ->
        Process.cancel_timer(ref)
        %{state | pending: Map.delete(state.pending, path)}
    end
  end
end
```

```elixir
# lib/tsc/cli/cli.ex
defmodule TSC.CLI do
  @moduledoc """
  Command-line interface for TSC.
  """

  alias TSC.CLI.{Parser, Formatter}

  def main(args) do
    # Ensure application is started
    {:ok, _} = Application.ensure_all_started(:tsc)

    args
    |> Parser.parse()
    |> run()
  end

  defp run({:ok, %{command: :check} = opts}) do
    files = discover_files(opts)

    result = TSC.Coordinator.check_project(files, opts.compiler_options)

    Formatter.print_diagnostics(result.diagnostics)
    Formatter.print_summary(result)

    exit_code = if result.success, do: 0, else: 1
    System.halt(exit_code)
  end

  defp run({:ok, %{command: :watch} = opts}) do
    files = discover_files(opts)

    # Initial check
    result = TSC.Coordinator.check_project(files, opts.compiler_options)
    Formatter.print_diagnostics(result.diagnostics)
    Formatter.print_summary(result)

    # Start watching
    IO.puts("\nWatching for file changes. Press Ctrl+C to stop.\n")
    TSC.Watcher.FileWatcher.watch(opts.paths)

    # Keep running
    Process.sleep(:infinity)
  end

  defp run({:error, message}) do
    IO.puts(:stderr, "Error: #{message}")
    System.halt(1)
  end

  defp discover_files(opts) do
    opts.paths
    |> Enum.flat_map(&find_ts_files/1)
    |> Enum.uniq()
  end

  defp find_ts_files(path) do
    cond do
      File.dir?(path) ->
        Path.wildcard(Path.join(path, "**/*.{ts,tsx}"))

      String.ends_with?(path, [".ts", ".tsx"]) ->
        [path]

      true ->
        []
    end
  end
end
```

---

## Timeline Summary

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          IMPLEMENTATION TIMELINE                             │
└─────────────────────────────────────────────────────────────────────────────┘

Week 1:
├── Days 1-2:  Phase 1 - Project Setup & ETS Cache
│              ├── mix.exs, supervision tree
│              ├── TypeCache (ETS)
│              └── FileCache (ETS)
│
├── Days 3-5:  Phase 2 - Port Communication
│              ├── JSON Protocol
│              ├── MoonBitPort GenServer
│              └── WorkerPool Supervisor

Week 2:
├── Days 6-7:  Phase 3 - Dependency Graph
│              ├── DependencyGraph (ETS)
│              └── Topological Sort
│
├── Days 8-10: Phase 4 - Coordinator
│              ├── Main orchestration
│              ├── Level-by-level checking
│              └── Incremental checking

Week 3:
├── Days 11-13: Phase 5 - Watcher & CLI
│               ├── FileSystem watcher
│               ├── CLI with Optimus
│               └── Diagnostic formatting
│
└── Days 14-15: Phase 6 - Testing & Polish
                ├── Integration tests
                ├── Burrito packaging
                └── Documentation
```

---

## Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Type Cache** | ETS with `read_concurrency` | Lock-free reads, writes serialized through GenServer |
| **Worker Comm** | Ports (not NIFs) | Isolation, crash safety, simpler debugging |
| **Worker Pool** | Simple round-robin | Good enough for file-level parallelism |
| **Dep Graph** | ETS tables | Fast lookups, concurrent reads |
| **File Watcher** | FileSystem library | Wraps inotify/FSEvents, battle-tested |
| **Packaging** | Burrito | Single binary with embedded BEAM |
