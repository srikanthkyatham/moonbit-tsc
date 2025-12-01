defmodule TSC.Telemetry.Profiler do
  @moduledoc """
  Performance profiler for TSC operations.

  Provides detailed profiling with:
  - Call stack tracing
  - Memory usage tracking
  - Hot path analysis
  - Bottleneck detection
  """

  use GenServer

  require Logger

  @profiler_table :tsc_profiler
  @samples_table :tsc_profiler_samples
  @traces_table :tsc_profiler_traces

  # ============================================================================
  # Public API
  # ============================================================================

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Start profiling a named session.
  """
  @spec start_session(String.t(), keyword()) :: {:ok, String.t()}
  def start_session(name, opts \\ []) do
    session_id = generate_session_id()

    session = %{
      id: session_id,
      name: name,
      started_at: System.system_time(:millisecond),
      ended_at: nil,
      status: :running,
      opts: opts,
      initial_memory: get_memory_info(),
      samples: [],
      traces: [],
      summary: nil
    }

    :ets.insert(@profiler_table, {session_id, session})

    # Start sampling if enabled
    if Keyword.get(opts, :sample_interval, 100) > 0 do
      GenServer.cast(__MODULE__, {:start_sampling, session_id, opts})
    end

    {:ok, session_id}
  end

  @doc """
  Stop profiling session and generate report.
  """
  @spec stop_session(String.t()) :: {:ok, map()} | {:error, atom()}
  def stop_session(session_id) do
    case get_session(session_id) do
      nil ->
        {:error, :not_found}

      session ->
        GenServer.cast(__MODULE__, {:stop_sampling, session_id})

        ended_at = System.system_time(:millisecond)
        duration = ended_at - session.started_at

        # Collect samples
        samples = get_samples(session_id)

        # Generate summary
        summary = generate_summary(session, samples, duration)

        updated_session = %{session |
          ended_at: ended_at,
          status: :completed,
          samples: samples,
          summary: summary
        }

        :ets.insert(@profiler_table, {session_id, updated_session})

        {:ok, updated_session}
    end
  end

  @doc """
  Profile a function execution.
  """
  @spec profile(String.t(), atom(), function()) :: any()
  def profile(session_id, operation, fun) when is_function(fun, 0) do
    start_time = System.monotonic_time(:microsecond)
    memory_before = :erlang.memory(:total)

    trace_id = generate_trace_id()
    trace_start(session_id, trace_id, operation)

    try do
      result = fun.()

      end_time = System.monotonic_time(:microsecond)
      memory_after = :erlang.memory(:total)

      trace_end(session_id, trace_id, %{
        duration_us: end_time - start_time,
        memory_delta: memory_after - memory_before,
        status: :success
      })

      result
    rescue
      e ->
        end_time = System.monotonic_time(:microsecond)
        memory_after = :erlang.memory(:total)

        trace_end(session_id, trace_id, %{
          duration_us: end_time - start_time,
          memory_delta: memory_after - memory_before,
          status: :error,
          error: Exception.message(e)
        })

        reraise e, __STACKTRACE__
    end
  end

  @doc """
  Add a trace point to a session.
  """
  @spec trace(String.t(), atom(), map()) :: :ok
  def trace(session_id, event, metadata \\ %{}) do
    trace_entry = %{
      timestamp: System.monotonic_time(:microsecond),
      event: event,
      metadata: metadata
    }

    :ets.insert(@traces_table, {{session_id, :erlang.unique_integer()}, trace_entry})
    :ok
  end

  @doc """
  Get all profiling sessions.
  """
  @spec list_sessions() :: [map()]
  def list_sessions do
    :ets.tab2list(@profiler_table)
    |> Enum.map(fn {_id, session} -> session end)
    |> Enum.sort_by(& &1.started_at, :desc)
  end

  @doc """
  Get a specific session.
  """
  @spec get_session(String.t()) :: map() | nil
  def get_session(session_id) do
    case :ets.lookup(@profiler_table, session_id) do
      [{^session_id, session}] -> session
      [] -> nil
    end
  end

  @doc """
  Get system-wide memory info.
  """
  @spec get_memory_info() :: map()
  def get_memory_info do
    memory = :erlang.memory()

    %{
      total: memory[:total],
      processes: memory[:processes],
      ets: memory[:ets],
      binary: memory[:binary],
      atom: memory[:atom],
      system: memory[:system]
    }
  end

  @doc """
  Get process info for all TSC-related processes.
  """
  @spec get_process_info() :: [map()]
  def get_process_info do
    Process.list()
    |> Enum.filter(&tsc_process?/1)
    |> Enum.map(&process_details/1)
    |> Enum.sort_by(& &1.memory, :desc)
    |> Enum.take(20)
  end

  @doc """
  Get ETS table statistics.
  """
  @spec get_ets_stats() :: [map()]
  def get_ets_stats do
    :ets.all()
    |> Enum.map(fn table ->
      info = :ets.info(table)
      %{
        name: info[:name] || table,
        size: info[:size] || 0,
        memory: (info[:memory] || 0) * :erlang.system_info(:wordsize),
        type: info[:type] || :unknown
      }
    end)
    |> Enum.sort_by(& &1.memory, :desc)
    |> Enum.take(20)
  end

  @doc """
  Get hot path analysis from traces.
  """
  @spec analyze_hot_paths(String.t()) :: [map()]
  def analyze_hot_paths(session_id) do
    get_traces(session_id)
    |> Enum.group_by(& &1.event)
    |> Enum.map(fn {event, traces} ->
      durations = traces
        |> Enum.filter(&Map.has_key?(&1, :duration_us))
        |> Enum.map(& &1.duration_us)

      %{
        operation: event,
        count: length(traces),
        total_time_us: Enum.sum(durations),
        avg_time_us: safe_avg(durations),
        max_time_us: Enum.max(durations, fn -> 0 end),
        min_time_us: Enum.min(durations, fn -> 0 end)
      }
    end)
    |> Enum.sort_by(& &1.total_time_us, :desc)
  end

  @doc """
  Detect performance bottlenecks.
  """
  @spec detect_bottlenecks(String.t()) :: [map()]
  def detect_bottlenecks(session_id) do
    hot_paths = analyze_hot_paths(session_id)

    bottlenecks = []

    # Find operations taking >80% of time
    total_time = Enum.sum(Enum.map(hot_paths, & &1.total_time_us))

    bottlenecks = hot_paths
      |> Enum.filter(fn path ->
        path.total_time_us > total_time * 0.2
      end)
      |> Enum.map(fn path ->
        %{
          type: :time_dominance,
          operation: path.operation,
          percentage: Float.round(path.total_time_us / max(total_time, 1) * 100, 2),
          suggestion: "Operation '#{path.operation}' takes #{path.percentage}% of total time"
        }
      end)
      |> Kernel.++(bottlenecks)

    # Find operations with high variance (potential inconsistency)
    bottlenecks = hot_paths
      |> Enum.filter(fn path ->
        path.max_time_us > path.avg_time_us * 5 and path.count > 5
      end)
      |> Enum.map(fn path ->
        %{
          type: :high_variance,
          operation: path.operation,
          ratio: Float.round(path.max_time_us / max(path.avg_time_us, 1), 2),
          suggestion: "Operation '#{path.operation}' has high variance (max #{path.ratio}x avg)"
        }
      end)
      |> Kernel.++(bottlenecks)

    bottlenecks
  end

  @doc """
  Get real-time performance metrics.
  """
  @spec get_realtime_metrics() :: map()
  def get_realtime_metrics do
    scheduler_usage = :scheduler.utilization(1000)
    |> Enum.map(fn {scheduler_id, usage, _} -> {scheduler_id, usage} end)
    |> Map.new()

    %{
      memory: get_memory_info(),
      scheduler_usage: scheduler_usage,
      process_count: length(Process.list()),
      ets_memory: :erlang.memory(:ets),
      run_queue: :erlang.statistics(:run_queue),
      reductions: elem(:erlang.statistics(:reductions), 0),
      io: get_io_stats()
    }
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(_) do
    :ets.new(@profiler_table, [:named_table, :public, :set])
    :ets.new(@samples_table, [:named_table, :public, :ordered_set])
    :ets.new(@traces_table, [:named_table, :public, :ordered_set])

    {:ok, %{sampling_sessions: %{}}}
  end

  @impl true
  def handle_cast({:start_sampling, session_id, opts}, state) do
    interval = Keyword.get(opts, :sample_interval, 100)
    timer_ref = Process.send_after(self(), {:sample, session_id}, interval)

    new_state = put_in(state, [:sampling_sessions, session_id], %{
      timer_ref: timer_ref,
      interval: interval
    })

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:stop_sampling, session_id}, state) do
    case get_in(state, [:sampling_sessions, session_id]) do
      nil ->
        {:noreply, state}

      %{timer_ref: timer_ref} ->
        Process.cancel_timer(timer_ref)
        new_state = update_in(state, [:sampling_sessions], &Map.delete(&1, session_id))
        {:noreply, new_state}
    end
  end

  @impl true
  def handle_info({:sample, session_id}, state) do
    case get_in(state, [:sampling_sessions, session_id]) do
      nil ->
        {:noreply, state}

      %{interval: interval} ->
        # Record sample
        sample = %{
          timestamp: System.monotonic_time(:microsecond),
          memory: get_memory_info(),
          scheduler_usage: :scheduler.utilization(50),
          run_queue: :erlang.statistics(:run_queue)
        }

        :ets.insert(@samples_table, {{session_id, System.monotonic_time()}, sample})

        # Schedule next sample
        timer_ref = Process.send_after(self(), {:sample, session_id}, interval)
        new_state = put_in(state, [:sampling_sessions, session_id, :timer_ref], timer_ref)

        {:noreply, new_state}
    end
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp generate_session_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp generate_trace_id do
    :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
  end

  defp trace_start(session_id, trace_id, operation) do
    trace_entry = %{
      trace_id: trace_id,
      operation: operation,
      started_at: System.monotonic_time(:microsecond),
      event: operation
    }

    :ets.insert(@traces_table, {{session_id, trace_id, :start}, trace_entry})
  end

  defp trace_end(session_id, trace_id, result) do
    # Get start trace
    case :ets.lookup(@traces_table, {session_id, trace_id, :start}) do
      [{_, start_trace}] ->
        ended_at = System.monotonic_time(:microsecond)

        complete_trace = Map.merge(start_trace, %{
          ended_at: ended_at,
          duration_us: result.duration_us,
          memory_delta: result.memory_delta,
          status: result.status
        })

        :ets.insert(@traces_table, {{session_id, trace_id, :complete}, complete_trace})

      [] ->
        :ok
    end
  end

  defp get_samples(session_id) do
    :ets.select(@samples_table, [
      {{{session_id, :_}, :"$1"}, [], [:"$1"]}
    ])
  end

  defp get_traces(session_id) do
    :ets.select(@traces_table, [
      {{{session_id, :_, :complete}, :"$1"}, [], [:"$1"]}
    ])
  end

  defp generate_summary(session, samples, duration) do
    memory_samples = Enum.map(samples, & &1.memory.total)

    %{
      duration_ms: duration,
      sample_count: length(samples),
      memory: %{
        initial: session.initial_memory.total,
        final: get_memory_info().total,
        peak: Enum.max(memory_samples, fn -> 0 end),
        min: Enum.min(memory_samples, fn -> 0 end),
        avg: safe_avg(memory_samples)
      },
      operations: length(get_traces(session.id))
    }
  end

  defp safe_avg([]), do: 0.0
  defp safe_avg(list), do: Float.round(Enum.sum(list) / length(list), 2)

  defp tsc_process?(pid) do
    case Process.info(pid, [:dictionary, :registered_name]) do
      nil ->
        false

      info ->
        name = info[:registered_name]
        dict = info[:dictionary] || []

        cond do
          is_atom(name) and String.contains?(to_string(name), "TSC") -> true
          is_atom(name) and String.contains?(to_string(name), "Tsc") -> true
          Keyword.get(dict, :"$initial_call", nil) in tsc_modules() -> true
          true -> false
        end
    end
  end

  defp tsc_modules do
    [
      {TSC.Coordinator, :init, 1},
      {TSC.Worker.PoolSupervisor, :init, 1},
      {TSC.Worker.CLIWorker, :init, 1},
      {TSC.Cache.TypeCache, :init, 1},
      {TSC.Cache.FileCache, :init, 1},
      {TSC.Telemetry.Reporter, :init, 1}
    ]
  end

  defp process_details(pid) do
    case Process.info(pid, [:memory, :message_queue_len, :reductions, :registered_name, :current_function]) do
      nil ->
        %{pid: pid, memory: 0, message_queue: 0, reductions: 0, name: nil, current_function: nil}

      info ->
        %{
          pid: pid,
          memory: info[:memory] || 0,
          message_queue: info[:message_queue_len] || 0,
          reductions: info[:reductions] || 0,
          name: info[:registered_name],
          current_function: info[:current_function]
        }
    end
  end

  defp get_io_stats do
    {{:input, input}, {:output, output}} = :erlang.statistics(:io)
    %{input: input, output: output}
  end
end
