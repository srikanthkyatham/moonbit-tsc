# Phoenix-Based TypeScript Compiler with Dashboard

## Overview

Using Phoenix as the base gives us:
- **Real-time dashboard** via LiveView (no JavaScript needed)
- **Metrics collection** via Telemetry
- **WebSocket-based LSP** potential
- **REST API** for CI/CD integration
- **Built-in PubSub** for live updates

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           PHOENIX APPLICATION                                │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                         WEB LAYER                                    │    │
│  │                                                                      │    │
│  │   ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐  │    │
│  │   │   LiveView   │  │   REST API   │  │   WebSocket (LSP)        │  │    │
│  │   │  Dashboard   │  │  /api/check  │  │   /lsp                   │  │    │
│  │   └──────┬───────┘  └──────┬───────┘  └────────────┬─────────────┘  │    │
│  │          │                 │                       │                │    │
│  │          └─────────────────┴───────────────────────┘                │    │
│  │                            │                                        │    │
│  │                    ┌───────▼───────┐                                │    │
│  │                    │    PubSub     │  (Real-time updates)           │    │
│  │                    └───────────────┘                                │    │
│  └────────────────────────────┼────────────────────────────────────────┘    │
│                               │                                              │
│  ┌────────────────────────────┼────────────────────────────────────────┐    │
│  │                      COMPILER CORE                                   │    │
│  │                            │                                         │    │
│  │   ┌────────────────────────▼────────────────────────────────────┐   │    │
│  │   │                    Telemetry                                 │   │    │
│  │   │  (Metrics: timing, cache hits, errors, worker health)       │   │    │
│  │   └─────────────────────────────────────────────────────────────┘   │    │
│  │                            │                                         │    │
│  │   ┌──────────┐  ┌──────────┴───────┐  ┌──────────────────────────┐  │    │
│  │   │ TypeCache│  │   Coordinator    │  │   DependencyGraph        │  │    │
│  │   │  (ETS)   │  │                  │  │      (ETS)               │  │    │
│  │   └──────────┘  └────────┬─────────┘  └──────────────────────────┘  │    │
│  │                          │                                          │    │
│  │              ┌───────────┼───────────┐                              │    │
│  │              │           │           │                              │    │
│  │              ▼           ▼           ▼                              │    │
│  │         ┌────────┐  ┌────────┐  ┌────────┐                         │    │
│  │         │  Port  │  │  Port  │  │  Port  │  (MoonBit Workers)      │    │
│  │         └────────┘  └────────┘  └────────┘                         │    │
│  │                                                                     │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Dashboard Features

### 1. Real-Time Compilation View

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  TSC Dashboard                                              [Watch: ON] 🟢  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─ Current Build ──────────────────────────────────────────────────────┐   │
│  │                                                                       │   │
│  │  Status: Checking...  ████████████░░░░░░░░  60% (45/75 files)        │   │
│  │                                                                       │   │
│  │  Level 0: ✓ Complete (12 files, 234ms)                               │   │
│  │  Level 1: ✓ Complete (28 files, 567ms)                               │   │
│  │  Level 2: ● In Progress (5/35 files)                                 │   │
│  │           ├── src/api/users.ts ●                                     │   │
│  │           ├── src/api/posts.ts ●                                     │   │
│  │           ├── src/api/auth.ts ●                                      │   │
│  │           └── ... 32 more                                            │   │
│  │                                                                       │   │
│  └───────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─ Errors & Warnings ──────────────────────────────────────────────────┐   │
│  │                                                                       │   │
│  │  🔴 2 Errors  🟡 5 Warnings                                          │   │
│  │                                                                       │   │
│  │  src/components/Button.tsx:45:12                                     │   │
│  │  TS2322: Type 'string' is not assignable to type 'number'           │   │
│  │  │                                                                    │   │
│  │  │  43 │ const Button = ({ size }: Props) => {                       │   │
│  │  │  44 │   return (                                                  │   │
│  │  │► 45 │     <button style={{ width: size }}>                       │   │
│  │  │     │                        ~~~~                                 │   │
│  │  │  46 │       Click me                                              │   │
│  │                                                                       │   │
│  └───────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2. Metrics Dashboard

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Metrics                                                    Last 5 minutes  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─ Performance ────────────────────┐  ┌─ Cache ────────────────────────┐   │
│  │                                  │  │                                │   │
│  │  Avg Check Time     │████│ 45ms  │  │  Type Cache                   │   │
│  │  Parse Time         │██  │ 12ms  │  │  ├── Hit Rate: 87.3%          │   │
│  │  Bind Time          │███ │ 18ms  │  │  ├── Entries: 1,234           │   │
│  │  Type Check Time    │████│ 38ms  │  │  └── Size: 45.2 MB            │   │
│  │  Emit Time          │█   │  5ms  │  │                                │   │
│  │                                  │  │  File Cache                    │   │
│  │  ──────────────────────────────  │  │  ├── Hit Rate: 94.1%          │   │
│  │  Total Files: 1,234              │  │  └── Entries: 1,234           │   │
│  │  Total Lines: 89,432             │  │                                │   │
│  │                                  │  │                                │   │
│  └──────────────────────────────────┘  └────────────────────────────────┘   │
│                                                                              │
│  ┌─ Workers ────────────────────────────────────────────────────────────┐   │
│  │                                                                       │   │
│  │  Worker 1  🟢  │████████░░│ 80%   Processed: 234   Uptime: 5m 23s   │   │
│  │  Worker 2  🟢  │██████░░░░│ 60%   Processed: 198   Uptime: 5m 23s   │   │
│  │  Worker 3  🟢  │███████░░░│ 70%   Processed: 212   Uptime: 5m 23s   │   │
│  │  Worker 4  🟡  │██████████│ 100%  Processed: 256   Uptime: 5m 23s   │   │
│  │                                                                       │   │
│  └───────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─ Check Time Over Last Hour ──────────────────────────────────────────┐   │
│  │                                                                       │   │
│  │  ms                                                                   │   │
│  │  100│                                                                 │   │
│  │   80│    ╭─╮                         ╭──╮                            │   │
│  │   60│╭───╯ ╰──╮    ╭─╮    ╭──────╮ ╭─╯  ╰──╮                        │   │
│  │   40│         ╰────╯ ╰────╯      ╰─╯       ╰────────                 │   │
│  │   20│                                                                 │   │
│  │    0└─────────────────────────────────────────────────────────────   │   │
│  │      12:00    12:15    12:30    12:45    13:00                       │   │
│  │                                                                       │   │
│  └───────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3. Dependency Graph Visualization

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Dependency Graph                                    [Filter: src/api/*]    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│                            ┌─────────────┐                                  │
│                            │  types.ts   │                                  │
│                            │  Level 0    │                                  │
│                            └──────┬──────┘                                  │
│                    ┌──────────────┼──────────────┐                          │
│                    │              │              │                          │
│                    ▼              ▼              ▼                          │
│              ┌──────────┐  ┌──────────┐  ┌──────────┐                       │
│              │ utils.ts │  │ api.ts   │  │config.ts │                       │
│              │ Level 1  │  │ Level 1  │  │ Level 1  │                       │
│              └────┬─────┘  └────┬─────┘  └──────────┘                       │
│                   │             │                                           │
│                   └──────┬──────┘                                           │
│                          │                                                  │
│                          ▼                                                  │
│                    ┌──────────┐                                             │
│                    │  app.ts  │ ◄── Currently checking                      │
│                    │ Level 2  │                                             │
│                    └──────────┘                                             │
│                                                                              │
│  Legend: ○ Pending  ● Checking  ✓ Complete  ✗ Error                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Project Structure

```
tsc_phoenix/
├── mix.exs
├── config/
│   ├── config.exs
│   ├── dev.exs
│   ├── prod.exs
│   └── runtime.exs
│
├── lib/
│   ├── tsc/                          # Core compiler logic
│   │   ├── application.ex
│   │   ├── cache/
│   │   │   ├── type_cache.ex         # ETS type cache
│   │   │   └── file_cache.ex         # ETS file cache
│   │   ├── worker/
│   │   │   ├── pool_supervisor.ex
│   │   │   ├── moonbit_port.ex       # Port to MoonBit
│   │   │   └── protocol.ex           # JSON protocol
│   │   ├── graph/
│   │   │   ├── dependency_graph.ex
│   │   │   └── topological_sort.ex
│   │   ├── coordinator/
│   │   │   └── coordinator.ex        # Main orchestration
│   │   ├── watcher/
│   │   │   └── file_watcher.ex
│   │   └── telemetry/
│   │       ├── metrics.ex            # Telemetry events
│   │       └── reporter.ex           # Metrics reporter
│   │
│   ├── tsc_web/                      # Phoenix web layer
│   │   ├── endpoint.ex
│   │   ├── router.ex
│   │   ├── telemetry.ex              # Phoenix telemetry
│   │   │
│   │   ├── controllers/
│   │   │   ├── api/
│   │   │   │   ├── check_controller.ex    # POST /api/check
│   │   │   │   ├── project_controller.ex  # GET /api/project
│   │   │   │   └── metrics_controller.ex  # GET /api/metrics
│   │   │   └── page_controller.ex
│   │   │
│   │   ├── live/
│   │   │   ├── dashboard_live.ex          # Main dashboard
│   │   │   ├── metrics_live.ex            # Metrics page
│   │   │   ├── graph_live.ex              # Dependency graph
│   │   │   ├── errors_live.ex             # Error browser
│   │   │   └── components/
│   │   │       ├── build_progress.ex      # Build progress component
│   │   │       ├── error_list.ex          # Error list component
│   │   │       ├── worker_status.ex       # Worker status component
│   │   │       ├── cache_stats.ex         # Cache stats component
│   │   │       └── time_chart.ex          # Time series chart
│   │   │
│   │   ├── channels/
│   │   │   ├── user_socket.ex
│   │   │   └── lsp_channel.ex             # WebSocket LSP
│   │   │
│   │   └── templates/
│   │       └── layout/
│   │           └── root.html.heex
│   │
│   └── tsc_cli/                      # CLI (optional, can also use Phoenix)
│       └── cli.ex
│
├── priv/
│   ├── moonbit_worker                # MoonBit binary
│   └── static/
│       └── assets/                   # CSS, JS
│
└── test/
```

---

## Implementation

### 1. Telemetry Setup

```elixir
# lib/tsc/telemetry/metrics.ex
defmodule TSC.Telemetry.Metrics do
  @moduledoc """
  Telemetry events for compiler metrics.
  """

  # ============================================================================
  # Event Names
  # ============================================================================

  @prefix [:tsc]

  def file_check_start, do: @prefix ++ [:file, :check, :start]
  def file_check_stop, do: @prefix ++ [:file, :check, :stop]
  def file_check_exception, do: @prefix ++ [:file, :check, :exception]

  def level_check_start, do: @prefix ++ [:level, :check, :start]
  def level_check_stop, do: @prefix ++ [:level, :check, :stop]

  def project_check_start, do: @prefix ++ [:project, :check, :start]
  def project_check_stop, do: @prefix ++ [:project, :check, :stop]

  def cache_hit, do: @prefix ++ [:cache, :hit]
  def cache_miss, do: @prefix ++ [:cache, :miss]

  def worker_request_start, do: @prefix ++ [:worker, :request, :start]
  def worker_request_stop, do: @prefix ++ [:worker, :request, :stop]

  def worker_crash, do: @prefix ++ [:worker, :crash]

  # ============================================================================
  # Emit Helpers
  # ============================================================================

  def emit_file_check_start(file, metadata \\ %{}) do
    :telemetry.execute(
      file_check_start(),
      %{system_time: System.system_time()},
      Map.merge(%{file: file}, metadata)
    )
  end

  def emit_file_check_stop(file, duration_ms, result, metadata \\ %{}) do
    :telemetry.execute(
      file_check_stop(),
      %{duration: duration_ms},
      Map.merge(%{file: file, result: result}, metadata)
    )
  end

  def emit_cache_hit(cache_type, key) do
    :telemetry.execute(
      cache_hit(),
      %{count: 1},
      %{cache: cache_type, key: key}
    )
  end

  def emit_cache_miss(cache_type, key) do
    :telemetry.execute(
      cache_miss(),
      %{count: 1},
      %{cache: cache_type, key: key}
    )
  end

  def emit_project_check_start(files_count, metadata \\ %{}) do
    :telemetry.execute(
      project_check_start(),
      %{files_count: files_count, system_time: System.system_time()},
      metadata
    )
  end

  def emit_project_check_stop(files_count, duration_ms, result, metadata \\ %{}) do
    :telemetry.execute(
      project_check_stop(),
      %{files_count: files_count, duration: duration_ms},
      Map.merge(%{result: result}, metadata)
    )
  end
end
```

```elixir
# lib/tsc/telemetry/reporter.ex
defmodule TSC.Telemetry.Reporter do
  @moduledoc """
  Collects telemetry events and stores metrics in ETS.
  Broadcasts updates via PubSub for LiveView.
  """

  use GenServer

  alias TSC.Telemetry.Metrics

  @metrics_table :tsc_metrics
  @history_table :tsc_metrics_history

  # ============================================================================
  # Public API
  # ============================================================================

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Get current metrics snapshot.
  """
  def get_metrics do
    %{
      file_checks: get_counter(:file_checks),
      total_duration_ms: get_counter(:total_duration_ms),
      avg_duration_ms: get_avg_duration(),
      cache_hits: get_counter(:cache_hits),
      cache_misses: get_counter(:cache_misses),
      cache_hit_rate: get_cache_hit_rate(),
      errors_count: get_counter(:errors_count),
      warnings_count: get_counter(:warnings_count),
      worker_requests: get_counter(:worker_requests),
      worker_crashes: get_counter(:worker_crashes)
    }
  end

  @doc """
  Get metrics history for charts.
  """
  def get_history(metric_name, limit \\ 60) do
    case :ets.lookup(@history_table, metric_name) do
      [{^metric_name, history}] ->
        history |> Enum.take(-limit)
      [] ->
        []
    end
  end

  @doc """
  Get currently active checks.
  """
  def get_active_checks do
    case :ets.lookup(@metrics_table, :active_checks) do
      [{:active_checks, checks}] -> checks
      [] -> []
    end
  end

  # ============================================================================
  # GenServer
  # ============================================================================

  @impl true
  def init(_) do
    # Create ETS tables
    :ets.new(@metrics_table, [:named_table, :public, :set])
    :ets.new(@history_table, [:named_table, :public, :set])

    # Initialize counters
    init_counters()

    # Attach telemetry handlers
    attach_handlers()

    # Start periodic history recording
    schedule_history_snapshot()

    {:ok, %{}}
  end

  @impl true
  def handle_info(:snapshot_history, state) do
    record_history_snapshot()
    schedule_history_snapshot()
    {:noreply, state}
  end

  @impl true
  def handle_info({:telemetry_event, event, measurements, metadata}, state) do
    handle_telemetry(event, measurements, metadata)
    {:noreply, state}
  end

  # ============================================================================
  # Telemetry Handlers
  # ============================================================================

  defp attach_handlers do
    events = [
      {Metrics.file_check_start(), &handle_file_check_start/4},
      {Metrics.file_check_stop(), &handle_file_check_stop/4},
      {Metrics.cache_hit(), &handle_cache_hit/4},
      {Metrics.cache_miss(), &handle_cache_miss/4},
      {Metrics.project_check_start(), &handle_project_check_start/4},
      {Metrics.project_check_stop(), &handle_project_check_stop/4},
      {Metrics.worker_crash(), &handle_worker_crash/4}
    ]

    Enum.each(events, fn {event, handler} ->
      :telemetry.attach(
        "tsc-reporter-#{inspect(event)}",
        event,
        handler,
        nil
      )
    end)
  end

  defp handle_file_check_start(_event, _measurements, metadata, _config) do
    # Add to active checks
    active = get_active_checks()
    :ets.insert(@metrics_table, {:active_checks, [metadata.file | active]})

    # Broadcast to LiveView
    broadcast_update(:file_check_start, metadata)
  end

  defp handle_file_check_stop(_event, measurements, metadata, _config) do
    # Remove from active checks
    active = get_active_checks() |> List.delete(metadata.file)
    :ets.insert(@metrics_table, {:active_checks, active})

    # Update counters
    inc_counter(:file_checks)
    add_counter(:total_duration_ms, measurements.duration)

    # Count errors/warnings
    case metadata.result do
      {:ok, %{diagnostics: diags}} ->
        errors = Enum.count(diags, &(&1.category == :error))
        warnings = Enum.count(diags, &(&1.category == :warning))
        add_counter(:errors_count, errors)
        add_counter(:warnings_count, warnings)
      _ ->
        :ok
    end

    # Broadcast
    broadcast_update(:file_check_stop, Map.merge(metadata, %{duration: measurements.duration}))
  end

  defp handle_cache_hit(_event, _measurements, metadata, _config) do
    inc_counter(:cache_hits)
    broadcast_update(:cache_hit, metadata)
  end

  defp handle_cache_miss(_event, _measurements, metadata, _config) do
    inc_counter(:cache_misses)
    broadcast_update(:cache_miss, metadata)
  end

  defp handle_project_check_start(_event, measurements, metadata, _config) do
    :ets.insert(@metrics_table, {:current_build, %{
      files_count: measurements.files_count,
      start_time: measurements.system_time,
      status: :in_progress
    }})

    broadcast_update(:project_check_start, metadata)
  end

  defp handle_project_check_stop(_event, measurements, metadata, _config) do
    :ets.insert(@metrics_table, {:current_build, %{
      files_count: measurements.files_count,
      duration: measurements.duration,
      status: :complete,
      result: metadata.result
    }})

    broadcast_update(:project_check_stop, Map.merge(metadata, measurements))
  end

  defp handle_worker_crash(_event, _measurements, metadata, _config) do
    inc_counter(:worker_crashes)
    broadcast_update(:worker_crash, metadata)
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp init_counters do
    counters = [
      :file_checks, :total_duration_ms, :cache_hits, :cache_misses,
      :errors_count, :warnings_count, :worker_requests, :worker_crashes
    ]

    Enum.each(counters, fn name ->
      :ets.insert(@metrics_table, {name, 0})
    end)

    :ets.insert(@metrics_table, {:active_checks, []})
  end

  defp get_counter(name) do
    case :ets.lookup(@metrics_table, name) do
      [{^name, value}] -> value
      [] -> 0
    end
  end

  defp inc_counter(name) do
    :ets.update_counter(@metrics_table, name, 1)
  rescue
    ArgumentError -> :ets.insert(@metrics_table, {name, 1})
  end

  defp add_counter(name, value) do
    :ets.update_counter(@metrics_table, name, value)
  rescue
    ArgumentError -> :ets.insert(@metrics_table, {name, value})
  end

  defp get_avg_duration do
    checks = get_counter(:file_checks)
    total = get_counter(:total_duration_ms)
    if checks > 0, do: Float.round(total / checks, 2), else: 0.0
  end

  defp get_cache_hit_rate do
    hits = get_counter(:cache_hits)
    misses = get_counter(:cache_misses)
    total = hits + misses
    if total > 0, do: Float.round(hits / total * 100, 2), else: 0.0
  end

  defp schedule_history_snapshot do
    Process.send_after(self(), :snapshot_history, 5_000)  # Every 5 seconds
  end

  defp record_history_snapshot do
    timestamp = System.system_time(:second)
    metrics = get_metrics()

    # Record each metric with timestamp
    [:avg_duration_ms, :cache_hit_rate, :errors_count]
    |> Enum.each(fn metric ->
      history = get_history(metric, 720)  # Keep 1 hour at 5s intervals
      new_point = {timestamp, Map.get(metrics, metric, 0)}
      :ets.insert(@history_table, {metric, history ++ [new_point]})
    end)
  end

  defp broadcast_update(event, data) do
    Phoenix.PubSub.broadcast(
      TSC.PubSub,
      "compiler:updates",
      {event, data}
    )
  end
end
```

### 2. LiveView Dashboard

```elixir
# lib/tsc_web/live/dashboard_live.ex
defmodule TSCWeb.DashboardLive do
  use TSCWeb, :live_view

  alias TSC.Telemetry.Reporter
  alias TSC.Cache.TypeCache
  alias TSC.Worker.PoolSupervisor

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to compiler updates
      Phoenix.PubSub.subscribe(TSC.PubSub, "compiler:updates")

      # Periodic refresh
      :timer.send_interval(1000, self(), :refresh)
    end

    socket =
      socket
      |> assign(:metrics, Reporter.get_metrics())
      |> assign(:active_checks, Reporter.get_active_checks())
      |> assign(:cache_stats, TypeCache.stats())
      |> assign(:worker_status, PoolSupervisor.status())
      |> assign(:current_build, nil)
      |> assign(:recent_errors, [])
      |> assign(:watch_mode, false)

    {:ok, socket}
  end

  @impl true
  def handle_info(:refresh, socket) do
    socket =
      socket
      |> assign(:metrics, Reporter.get_metrics())
      |> assign(:cache_stats, TypeCache.stats())
      |> assign(:worker_status, PoolSupervisor.status())

    {:noreply, socket}
  end

  @impl true
  def handle_info({:file_check_start, data}, socket) do
    active = [data.file | socket.assigns.active_checks] |> Enum.take(20)
    {:noreply, assign(socket, :active_checks, active)}
  end

  @impl true
  def handle_info({:file_check_stop, data}, socket) do
    active = List.delete(socket.assigns.active_checks, data.file)

    # Add errors to recent list
    recent_errors =
      case data do
        %{result: {:ok, %{diagnostics: diags}}} ->
          errors = Enum.filter(diags, &(&1.category == :error))
          (errors ++ socket.assigns.recent_errors) |> Enum.take(50)
        _ ->
          socket.assigns.recent_errors
      end

    socket =
      socket
      |> assign(:active_checks, active)
      |> assign(:recent_errors, recent_errors)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:project_check_start, data}, socket) do
    {:noreply, assign(socket, :current_build, %{status: :in_progress, files: data.files_count})}
  end

  @impl true
  def handle_info({:project_check_stop, data}, socket) do
    {:noreply, assign(socket, :current_build, %{status: :complete, duration: data.duration})}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def handle_event("toggle_watch", _, socket) do
    watch_mode = !socket.assigns.watch_mode

    if watch_mode do
      TSC.Watcher.FileWatcher.watch(["./src"])
    else
      TSC.Watcher.FileWatcher.stop_watching()
    end

    {:noreply, assign(socket, :watch_mode, watch_mode)}
  end

  @impl true
  def handle_event("run_check", _, socket) do
    Task.start(fn ->
      TSC.Coordinator.check_project(discover_files())
    end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_cache", _, socket) do
    TypeCache.clear()
    {:noreply, assign(socket, :cache_stats, TypeCache.stats())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="dashboard">
      <header class="dashboard-header">
        <h1>TSC Dashboard</h1>
        <div class="controls">
          <button phx-click="run_check" class="btn btn-primary">
            Run Check
          </button>
          <button phx-click="toggle_watch" class={"btn #{if @watch_mode, do: "btn-success", else: "btn-secondary"}"}>
            Watch: <%= if @watch_mode, do: "ON 🟢", else: "OFF" %>
          </button>
        </div>
      </header>

      <div class="grid">
        <!-- Build Progress -->
        <.live_component
          module={TSCWeb.Components.BuildProgress}
          id="build-progress"
          current_build={@current_build}
          active_checks={@active_checks}
        />

        <!-- Metrics Cards -->
        <div class="metrics-grid">
          <.metric_card
            title="Files Checked"
            value={@metrics.file_checks}
            icon="📁"
          />
          <.metric_card
            title="Avg Check Time"
            value={"#{@metrics.avg_duration_ms}ms"}
            icon="⏱️"
          />
          <.metric_card
            title="Cache Hit Rate"
            value={"#{@metrics.cache_hit_rate}%"}
            icon="💾"
          />
          <.metric_card
            title="Errors"
            value={@metrics.errors_count}
            icon="🔴"
            class={if @metrics.errors_count > 0, do: "error"}
          />
        </div>

        <!-- Worker Status -->
        <.live_component
          module={TSCWeb.Components.WorkerStatus}
          id="worker-status"
          status={@worker_status}
        />

        <!-- Cache Stats -->
        <.live_component
          module={TSCWeb.Components.CacheStats}
          id="cache-stats"
          stats={@cache_stats}
        />

        <!-- Recent Errors -->
        <.live_component
          module={TSCWeb.Components.ErrorList}
          id="error-list"
          errors={@recent_errors}
        />

        <!-- Time Chart -->
        <.live_component
          module={TSCWeb.Components.TimeChart}
          id="time-chart"
          metric={:avg_duration_ms}
          title="Check Time (ms)"
        />
      </div>
    </div>
    """
  end

  defp metric_card(assigns) do
    ~H"""
    <div class={"metric-card #{assigns[:class]}"}>
      <span class="icon"><%= @icon %></span>
      <div class="content">
        <span class="value"><%= @value %></span>
        <span class="title"><%= @title %></span>
      </div>
    </div>
    """
  end

  defp discover_files do
    Path.wildcard("src/**/*.{ts,tsx}")
  end
end
```

### 3. Build Progress Component

```elixir
# lib/tsc_web/live/components/build_progress.ex
defmodule TSCWeb.Components.BuildProgress do
  use TSCWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class="build-progress card">
      <h2>Current Build</h2>

      <%= if @current_build do %>
        <div class="progress-bar">
          <div
            class={"progress-fill #{@current_build.status}"}
            style={"width: #{progress_percent(@current_build)}%"}
          >
          </div>
        </div>

        <div class="status">
          <%= case @current_build.status do %>
            <% :in_progress -> %>
              <span class="spinner">●</span> Checking...
            <% :complete -> %>
              ✓ Complete in <%= @current_build.duration %>ms
          <% end %>
        </div>
      <% else %>
        <div class="idle">No active build</div>
      <% end %>

      <%= if length(@active_checks) > 0 do %>
        <div class="active-files">
          <h3>Currently Checking:</h3>
          <ul>
            <%= for file <- Enum.take(@active_checks, 5) do %>
              <li class="checking">
                <span class="spinner">●</span>
                <%= Path.basename(file) %>
              </li>
            <% end %>
            <%= if length(@active_checks) > 5 do %>
              <li class="more">... and <%= length(@active_checks) - 5 %> more</li>
            <% end %>
          </ul>
        </div>
      <% end %>
    </div>
    """
  end

  defp progress_percent(%{status: :complete}), do: 100
  defp progress_percent(%{files_count: total, checked: checked}) when total > 0 do
    checked / total * 100
  end
  defp progress_percent(_), do: 0
end
```

### 4. REST API for CI/CD

```elixir
# lib/tsc_web/controllers/api/check_controller.ex
defmodule TSCWeb.API.CheckController do
  use TSCWeb, :controller

  alias TSC.Coordinator

  @doc """
  POST /api/check
  Body: { "files": ["src/foo.ts"], "options": {} }

  Response: {
    "success": true,
    "diagnostics": [...],
    "stats": { "files_checked": 10, "elapsed_ms": 234 }
  }
  """
  def create(conn, params) do
    files = params["files"] || discover_project_files(params["project"])
    options = params["options"] || %{}

    result = Coordinator.check_project(files, options)

    conn
    |> put_status(if result.success, do: 200, else: 400)
    |> json(%{
      success: result.success,
      diagnostics: format_diagnostics(result.diagnostics),
      stats: result.stats
    })
  end

  @doc """
  GET /api/check/status
  Returns current build status and metrics.
  """
  def status(conn, _params) do
    metrics = TSC.Telemetry.Reporter.get_metrics()
    active = TSC.Telemetry.Reporter.get_active_checks()

    json(conn, %{
      building: length(active) > 0,
      active_files: active,
      metrics: metrics
    })
  end

  defp discover_project_files(project_path) when is_binary(project_path) do
    Path.wildcard(Path.join(project_path, "**/*.{ts,tsx}"))
  end

  defp discover_project_files(_), do: Path.wildcard("src/**/*.{ts,tsx}")

  defp format_diagnostics(diagnostics) do
    Enum.map(diagnostics, fn d ->
      %{
        file: d.file,
        line: d.line,
        column: d.column,
        code: d.code,
        category: d.category,
        message: d.message
      }
    end)
  end
end
```

### 5. Router

```elixir
# lib/tsc_web/router.ex
defmodule TSCWeb.Router do
  use TSCWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TSCWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", TSCWeb do
    pipe_through :browser

    live "/", DashboardLive, :index
    live "/metrics", MetricsLive, :index
    live "/graph", GraphLive, :index
    live "/errors", ErrorsLive, :index
  end

  scope "/api", TSCWeb.API do
    pipe_through :api

    post "/check", CheckController, :create
    get "/check/status", CheckController, :status
    get "/metrics", MetricsController, :index
    get "/project", ProjectController, :show
  end

  # WebSocket for LSP (future)
  # socket "/lsp", TSCWeb.LSPSocket,
  #   websocket: true
end
```

---

## Deployment Options

### Option 1: Development Server

```bash
# Start Phoenix server with dashboard
mix phx.server

# Access dashboard at http://localhost:4000
```

### Option 2: CLI with Embedded Server

```elixir
# lib/tsc_cli/cli.ex
defmodule TSC.CLI do
  def main(args) do
    {opts, files, _} = OptionParser.parse(args,
      strict: [
        dashboard: :boolean,
        port: :integer,
        watch: :boolean
      ]
    )

    # Start the application
    {:ok, _} = Application.ensure_all_started(:tsc)

    if opts[:dashboard] do
      # Start Phoenix endpoint
      port = opts[:port] || 4000
      IO.puts("Dashboard available at http://localhost:#{port}")
    end

    if opts[:watch] do
      TSC.Watcher.FileWatcher.watch(["./src"])
      IO.puts("Watching for changes...")
      Process.sleep(:infinity)
    else
      result = TSC.Coordinator.check_project(files)
      print_result(result)
      System.halt(if result.success, do: 0, else: 1)
    end
  end
end
```

```bash
# CLI with dashboard
./tsc --dashboard --port 4000 ./src

# CLI without dashboard
./tsc ./src
```

### Option 3: Single Binary with Burrito

```elixir
# mix.exs
defp releases do
  [
    tsc: [
      steps: [:assemble, &Burrito.wrap/1],
      burrito: [
        targets: [
          macos: [os: :darwin, cpu: :aarch64],
          linux: [os: :linux, cpu: :x86_64]
        ]
      ]
    ]
  ]
end
```

---

## Timeline

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          IMPLEMENTATION TIMELINE                             │
└─────────────────────────────────────────────────────────────────────────────┘

Week 1: Core + Basic Dashboard
├── Days 1-2:  Phoenix project setup, ETS caches
├── Days 3-4:  Port communication with MoonBit
└── Days 5:    Basic LiveView dashboard (build progress)

Week 2: Full Dashboard
├── Days 6-7:  Telemetry integration, metrics collection
├── Days 8-9:  LiveView components (workers, cache, errors)
└── Day 10:    Time series charts

Week 3: Polish
├── Days 11-12: Dependency graph visualization
├── Days 13:    REST API for CI/CD
├── Days 14:    File watcher integration
└── Day 15:     Testing, Burrito packaging
```

---

## Benefits of Phoenix Approach

| Feature | Benefit |
|---------|---------|
| **LiveView Dashboard** | Real-time updates without JavaScript |
| **PubSub** | Easy broadcast of compiler events |
| **Telemetry** | Built-in metrics infrastructure |
| **REST API** | CI/CD integration, remote triggering |
| **WebSocket** | Future LSP server capability |
| **Supervision** | Fault-tolerant worker management |
| **ETS** | Fast, concurrent caching |
| **Hot Reload** | Update dashboard without restart |
