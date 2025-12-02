defmodule TSC.Telemetry.Reporter do
  @moduledoc """
  Collects telemetry events and stores metrics in ETS.
  Broadcasts updates via PubSub for LiveView.
  """

  use GenServer

  alias TSC.Telemetry.Metrics

  require Logger

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
  @spec get_metrics() :: map()
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
      worker_crashes: get_counter(:worker_crashes),
      phases: get_phase_metrics()
    }
  end

  @doc """
  Get phase timing metrics.
  """
  @spec get_phase_metrics() :: map()
  def get_phase_metrics do
    case :ets.lookup(@metrics_table, :phase_metrics) do
      [{:phase_metrics, metrics}] -> metrics
      [] -> %{}
    end
  end

  @doc """
  Get histogram data for a metric.
  """
  @spec get_histogram(atom()) :: map()
  def get_histogram(name) do
    case :ets.lookup(@metrics_table, :"#{name}_histogram") do
      [{_, histogram}] -> histogram
      [] -> %{buckets: %{}, sum: 0, count: 0}
    end
  end

  @doc """
  Get metrics history for charts.
  """
  @spec get_history(atom(), pos_integer()) :: list()
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
  @spec get_active_checks() :: list()
  def get_active_checks do
    case :ets.lookup(@metrics_table, :active_checks) do
      [{:active_checks, checks}] -> checks
      [] -> []
    end
  end

  @doc """
  Get current build status.
  """
  @spec get_current_build() :: map() | nil
  def get_current_build do
    case :ets.lookup(@metrics_table, :current_build) do
      [{:current_build, build}] -> build
      [] -> nil
    end
  end

  @doc """
  Reset all metrics.
  """
  @spec reset() :: :ok
  def reset do
    init_counters()
    :ok
  end

  # ============================================================================
  # GenServer Callbacks
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
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ============================================================================
  # Telemetry Handlers
  # ============================================================================

  defp attach_handlers do
    events = [
      {Metrics.file_check_start(), &__MODULE__.handle_file_check_start/4},
      {Metrics.file_check_stop(), &__MODULE__.handle_file_check_stop/4},
      {Metrics.cache_hit(), &__MODULE__.handle_cache_hit/4},
      {Metrics.cache_miss(), &__MODULE__.handle_cache_miss/4},
      {Metrics.project_check_start(), &__MODULE__.handle_project_check_start/4},
      {Metrics.project_check_stop(), &__MODULE__.handle_project_check_stop/4},
      {Metrics.worker_crash(), &__MODULE__.handle_worker_crash/4},
      {Metrics.worker_request_start(), &__MODULE__.handle_worker_request_start/4},
      {Metrics.worker_request_stop(), &__MODULE__.handle_worker_request_stop/4},
      {Metrics.phase_stop(), &__MODULE__.handle_phase_stop/4}
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

  def handle_file_check_start(_event, _measurements, metadata, _config) do
    # Add to active checks
    active = get_active_checks()
    :ets.insert(@metrics_table, {:active_checks, [metadata.file | active]})

    # Broadcast to LiveView
    broadcast_update(:file_check_start, metadata)
  end

  def handle_file_check_stop(_event, measurements, metadata, _config) do
    # Remove from active checks
    active = get_active_checks() |> List.delete(metadata.file)
    :ets.insert(@metrics_table, {:active_checks, active})

    # Update counters
    inc_counter(:file_checks)
    add_counter(:total_duration_ms, measurements.duration)

    # Update histogram
    update_histogram(:file_check, measurements.duration)

    # Count errors/warnings from result
    case metadata.result do
      {:ok, %{diagnostics: diags}} when is_list(diags) ->
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

  def handle_cache_hit(_event, _measurements, metadata, _config) do
    inc_counter(:cache_hits)
    broadcast_update(:cache_hit, metadata)
  end

  def handle_cache_miss(_event, _measurements, metadata, _config) do
    inc_counter(:cache_misses)
    broadcast_update(:cache_miss, metadata)
  end

  def handle_project_check_start(_event, measurements, metadata, _config) do
    :ets.insert(@metrics_table, {:current_build, %{
      files_count: measurements.files_count,
      start_time: measurements.system_time,
      status: :in_progress,
      checked: 0
    }})

    broadcast_update(:project_check_start, Map.merge(metadata, measurements))
  end

  def handle_project_check_stop(_event, measurements, metadata, _config) do
    :ets.insert(@metrics_table, {:current_build, %{
      files_count: measurements.files_count,
      duration: measurements.duration,
      status: :complete,
      result: metadata.result
    }})

    # Update histogram
    update_histogram(:project_check, measurements.duration)

    broadcast_update(:project_check_stop, Map.merge(metadata, measurements))
  end

  def handle_worker_crash(_event, _measurements, metadata, _config) do
    inc_counter(:worker_crashes)
    broadcast_update(:worker_crash, metadata)
  end

  def handle_worker_request_start(_event, _measurements, metadata, _config) do
    inc_counter(:worker_requests)
    broadcast_update(:worker_request_start, metadata)
  end

  def handle_worker_request_stop(_event, measurements, metadata, _config) do
    broadcast_update(:worker_request_stop, Map.merge(metadata, measurements))
  end

  def handle_phase_stop(_event, measurements, metadata, _config) do
    phase = metadata.phase
    duration = measurements.duration

    # Update phase metrics
    phase_metrics = get_phase_metrics()
    phase_data = Map.get(phase_metrics, phase, %{count: 0, total_ms: 0, min_ms: nil, max_ms: nil})

    updated_data = %{
      count: phase_data.count + 1,
      total_ms: phase_data.total_ms + duration,
      avg_ms: Float.round((phase_data.total_ms + duration) / (phase_data.count + 1), 2),
      min_ms: min_value(phase_data.min_ms, duration),
      max_ms: max_value(phase_data.max_ms, duration),
      last_ms: duration
    }

    :ets.insert(@metrics_table, {:phase_metrics, Map.put(phase_metrics, phase, updated_data)})

    broadcast_update(:phase_stop, Map.merge(metadata, %{duration: duration}))
  end

  defp min_value(nil, value), do: value
  defp min_value(current, value), do: min(current, value)

  defp max_value(nil, value), do: value
  defp max_value(current, value), do: max(current, value)

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
    try do
      :ets.update_counter(@metrics_table, name, 1)
    rescue
      ArgumentError -> :ets.insert(@metrics_table, {name, 1})
    end
  end

  defp add_counter(name, value) when is_number(value) do
    try do
      :ets.update_counter(@metrics_table, name, round(value))
    rescue
      ArgumentError -> :ets.insert(@metrics_table, {name, round(value)})
    end
  end

  defp add_counter(_name, _value), do: :ok

  @histogram_buckets [10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000]

  defp update_histogram(name, value) when is_number(value) do
    key = :"#{name}_histogram"

    histogram = case :ets.lookup(@metrics_table, key) do
      [{^key, h}] -> h
      [] -> %{buckets: %{}, sum: 0, count: 0}
    end

    # Find appropriate bucket
    bucket = Enum.find(@histogram_buckets, :infinity, fn b -> value <= b end)

    # Update histogram
    updated = %{
      buckets: Map.update(histogram.buckets, bucket, 1, &(&1 + 1)),
      sum: histogram.sum + value,
      count: histogram.count + 1
    }

    :ets.insert(@metrics_table, {key, updated})
  end

  defp update_histogram(_name, _value), do: :ok

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
    [:avg_duration_ms, :cache_hit_rate, :errors_count, :file_checks]
    |> Enum.each(fn metric ->
      history = get_history(metric, 720)  # Keep 1 hour at 5s intervals
      new_point = {timestamp, Map.get(metrics, metric, 0)}
      :ets.insert(@history_table, {metric, history ++ [new_point]})
    end)
  end

  defp broadcast_update(event, data) do
    Phoenix.PubSub.broadcast(
      TscPhoenix.PubSub,
      "compiler:updates",
      {event, data}
    )
  end
end
