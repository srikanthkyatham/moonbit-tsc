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

  # Phase timing events
  def phase_start, do: @prefix ++ [:phase, :start]
  def phase_stop, do: @prefix ++ [:phase, :stop]

  # ============================================================================
  # Emit Helpers
  # ============================================================================

  @doc """
  Emit file check start event.
  """
  def emit_file_check_start(file, metadata \\ %{}) do
    :telemetry.execute(
      file_check_start(),
      %{system_time: System.system_time()},
      Map.merge(%{file: file}, metadata)
    )
  end

  @doc """
  Emit file check stop event.
  """
  def emit_file_check_stop(file, duration_ms, result, metadata \\ %{}) do
    :telemetry.execute(
      file_check_stop(),
      %{duration: duration_ms},
      Map.merge(%{file: file, result: result}, metadata)
    )
  end

  @doc """
  Emit file check exception event.
  """
  def emit_file_check_exception(file, exception, metadata \\ %{}) do
    :telemetry.execute(
      file_check_exception(),
      %{},
      Map.merge(%{file: file, exception: exception}, metadata)
    )
  end

  @doc """
  Emit level check start event.
  """
  def emit_level_check_start(level, files_count, metadata \\ %{}) do
    :telemetry.execute(
      level_check_start(),
      %{files_count: files_count, system_time: System.system_time()},
      Map.merge(%{level: level}, metadata)
    )
  end

  @doc """
  Emit level check stop event.
  """
  def emit_level_check_stop(level, files_count, duration_ms, metadata \\ %{}) do
    :telemetry.execute(
      level_check_stop(),
      %{files_count: files_count, duration: duration_ms},
      Map.merge(%{level: level}, metadata)
    )
  end

  @doc """
  Emit project check start event.
  """
  def emit_project_check_start(files_count, metadata \\ %{}) do
    :telemetry.execute(
      project_check_start(),
      %{files_count: files_count, system_time: System.system_time()},
      metadata
    )
  end

  @doc """
  Emit project check stop event.
  """
  def emit_project_check_stop(files_count, duration_ms, result, metadata \\ %{}) do
    :telemetry.execute(
      project_check_stop(),
      %{files_count: files_count, duration: duration_ms},
      Map.merge(%{result: result}, metadata)
    )
  end

  @doc """
  Emit cache hit event.
  """
  def emit_cache_hit(cache_type, key) do
    :telemetry.execute(
      cache_hit(),
      %{count: 1},
      %{cache: cache_type, key: key}
    )
  end

  @doc """
  Emit cache miss event.
  """
  def emit_cache_miss(cache_type, key) do
    :telemetry.execute(
      cache_miss(),
      %{count: 1},
      %{cache: cache_type, key: key}
    )
  end

  @doc """
  Emit worker request start event.
  """
  def emit_worker_request_start(worker_id, file) do
    :telemetry.execute(
      worker_request_start(),
      %{system_time: System.system_time()},
      %{worker_id: worker_id, file: file}
    )
  end

  @doc """
  Emit worker request stop event.
  """
  def emit_worker_request_stop(worker_id, file, duration_ms, result) do
    :telemetry.execute(
      worker_request_stop(),
      %{duration: duration_ms},
      %{worker_id: worker_id, file: file, result: result}
    )
  end

  @doc """
  Emit worker crash event.
  """
  def emit_worker_crash(worker_id, reason) do
    :telemetry.execute(
      worker_crash(),
      %{count: 1},
      %{worker_id: worker_id, reason: reason}
    )
  end

  @doc """
  Emit phase start event.

  Phases include:
  - :parse - Parsing TypeScript source
  - :resolve - Resolving imports and dependencies
  - :bind - Symbol binding
  - :check - Type checking
  - :emit - Output generation
  """
  def emit_phase_start(phase, metadata \\ %{}) do
    :telemetry.execute(
      phase_start(),
      %{system_time: System.system_time(:millisecond)},
      Map.merge(%{phase: phase}, metadata)
    )
  end

  @doc """
  Emit phase stop event.
  """
  def emit_phase_stop(phase, duration_ms, metadata \\ %{}) do
    :telemetry.execute(
      phase_stop(),
      %{duration: duration_ms},
      Map.merge(%{phase: phase}, metadata)
    )
  end

  @doc """
  Measure the duration of a function and emit phase events.
  Returns the function result.
  """
  def measure_phase(phase, metadata \\ %{}, fun) when is_function(fun, 0) do
    emit_phase_start(phase, metadata)
    start_time = System.monotonic_time(:millisecond)

    try do
      result = fun.()
      duration = System.monotonic_time(:millisecond) - start_time
      emit_phase_stop(phase, duration, Map.put(metadata, :status, :success))
      result
    rescue
      e ->
        duration = System.monotonic_time(:millisecond) - start_time
        emit_phase_stop(phase, duration, Map.merge(metadata, %{status: :error, error: e}))
        reraise e, __STACKTRACE__
    end
  end
end
