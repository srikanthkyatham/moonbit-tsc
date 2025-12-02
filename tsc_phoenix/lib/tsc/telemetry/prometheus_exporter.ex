defmodule TSC.Telemetry.PrometheusExporter do
  @moduledoc """
  Prometheus metrics exporter for TypeScript compiler telemetry.

  Exposes metrics in Prometheus text format at /metrics endpoint.

  ## Metrics Exported

  ### Counters
  - `tsc_file_checks_total` - Total number of file checks
  - `tsc_cache_hits_total` - Total cache hits
  - `tsc_cache_misses_total` - Total cache misses
  - `tsc_errors_total` - Total errors found
  - `tsc_warnings_total` - Total warnings found
  - `tsc_worker_crashes_total` - Total worker crashes

  ### Gauges
  - `tsc_active_checks` - Number of active file checks
  - `tsc_cache_hit_rate` - Cache hit rate percentage

  ### Histograms
  - `tsc_file_check_duration_ms` - File check duration in milliseconds
  - `tsc_project_check_duration_ms` - Project check duration in milliseconds
  - `tsc_phase_duration_ms` - Phase duration by phase name
  """

  alias TSC.Telemetry.Reporter

  @histogram_buckets [10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000]

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Generate Prometheus metrics text output.
  """
  @spec export() :: String.t()
  def export do
    metrics = Reporter.get_metrics()
    phase_metrics = get_phase_metrics()
    histograms = get_histograms()

    [
      export_info(),
      export_counters(metrics),
      export_gauges(metrics),
      export_histograms(histograms),
      export_phase_metrics(phase_metrics)
    ]
    |> Enum.join("\n")
  end

  @doc """
  Get metrics as a map (for JSON export).
  """
  @spec export_json() :: map()
  def export_json do
    metrics = Reporter.get_metrics()
    phase_metrics = get_phase_metrics()

    %{
      counters: %{
        file_checks_total: metrics.file_checks,
        cache_hits_total: metrics.cache_hits,
        cache_misses_total: metrics.cache_misses,
        errors_total: metrics.errors_count,
        warnings_total: metrics.warnings_count,
        worker_crashes_total: metrics.worker_crashes
      },
      gauges: %{
        active_checks: length(Reporter.get_active_checks()),
        cache_hit_rate: metrics.cache_hit_rate,
        avg_duration_ms: metrics.avg_duration_ms
      },
      phases: phase_metrics,
      histograms: get_histograms()
    }
  end

  # ============================================================================
  # Private - Export Formatters
  # ============================================================================

  defp export_info do
    """
    # HELP tsc_build_info TypeScript compiler build information
    # TYPE tsc_build_info gauge
    tsc_build_info{version="0.1.0"} 1
    """
  end

  defp export_counters(metrics) do
    """
    # HELP tsc_file_checks_total Total number of file checks performed
    # TYPE tsc_file_checks_total counter
    tsc_file_checks_total #{metrics.file_checks}

    # HELP tsc_cache_hits_total Total number of cache hits
    # TYPE tsc_cache_hits_total counter
    tsc_cache_hits_total #{metrics.cache_hits}

    # HELP tsc_cache_misses_total Total number of cache misses
    # TYPE tsc_cache_misses_total counter
    tsc_cache_misses_total #{metrics.cache_misses}

    # HELP tsc_errors_total Total number of TypeScript errors found
    # TYPE tsc_errors_total counter
    tsc_errors_total #{metrics.errors_count}

    # HELP tsc_warnings_total Total number of TypeScript warnings found
    # TYPE tsc_warnings_total counter
    tsc_warnings_total #{metrics.warnings_count}

    # HELP tsc_worker_requests_total Total number of worker requests
    # TYPE tsc_worker_requests_total counter
    tsc_worker_requests_total #{metrics.worker_requests}

    # HELP tsc_worker_crashes_total Total number of worker crashes
    # TYPE tsc_worker_crashes_total counter
    tsc_worker_crashes_total #{metrics.worker_crashes}
    """
  end

  defp export_gauges(metrics) do
    active_checks = length(Reporter.get_active_checks())

    """
    # HELP tsc_active_checks Number of currently active file checks
    # TYPE tsc_active_checks gauge
    tsc_active_checks #{active_checks}

    # HELP tsc_cache_hit_rate Cache hit rate percentage
    # TYPE tsc_cache_hit_rate gauge
    tsc_cache_hit_rate #{metrics.cache_hit_rate}

    # HELP tsc_avg_duration_ms Average file check duration in milliseconds
    # TYPE tsc_avg_duration_ms gauge
    tsc_avg_duration_ms #{metrics.avg_duration_ms}
    """
  end

  defp export_histograms(histograms) do
    file_check = Map.get(histograms, :file_check, %{})
    project_check = Map.get(histograms, :project_check, %{})

    """
    # HELP tsc_file_check_duration_ms File check duration in milliseconds
    # TYPE tsc_file_check_duration_ms histogram
    #{format_histogram("tsc_file_check_duration_ms", file_check)}

    # HELP tsc_project_check_duration_ms Project check duration in milliseconds
    # TYPE tsc_project_check_duration_ms histogram
    #{format_histogram("tsc_project_check_duration_ms", project_check)}
    """
  end

  defp export_phase_metrics(phase_metrics) do
    if map_size(phase_metrics) == 0 do
      ""
    else
      lines =
        phase_metrics
        |> Enum.map(fn {phase, data} ->
          ~s(tsc_phase_duration_ms{phase="#{phase}"} #{data.avg_ms})
        end)
        |> Enum.join("\n")

      """
      # HELP tsc_phase_duration_ms Average phase duration in milliseconds
      # TYPE tsc_phase_duration_ms gauge
      #{lines}

      # HELP tsc_phase_count Phase execution count
      # TYPE tsc_phase_count counter
      #{format_phase_counts(phase_metrics)}
      """
    end
  end

  defp format_histogram(name, data) when map_size(data) == 0 do
    buckets =
      @histogram_buckets
      |> Enum.map(fn bucket -> ~s(#{name}_bucket{le="#{bucket}"} 0) end)
      |> Enum.join("\n")

    """
    #{buckets}
    #{name}_bucket{le="+Inf"} 0
    #{name}_sum 0
    #{name}_count 0
    """
  end

  defp format_histogram(name, data) do
    buckets = Map.get(data, :buckets, %{})
    sum = Map.get(data, :sum, 0)
    count = Map.get(data, :count, 0)

    bucket_lines =
      @histogram_buckets
      |> Enum.map(fn bucket ->
        cumulative = cumulative_bucket_count(buckets, bucket)
        ~s(#{name}_bucket{le="#{bucket}"} #{cumulative})
      end)
      |> Enum.join("\n")

    """
    #{bucket_lines}
    #{name}_bucket{le="+Inf"} #{count}
    #{name}_sum #{sum}
    #{name}_count #{count}
    """
  end

  defp cumulative_bucket_count(buckets, le) do
    buckets
    |> Enum.filter(fn {bucket, _count} -> bucket <= le end)
    |> Enum.map(fn {_bucket, count} -> count end)
    |> Enum.sum()
  end

  defp format_phase_counts(phase_metrics) do
    phase_metrics
    |> Enum.map(fn {phase, data} ->
      ~s(tsc_phase_count{phase="#{phase}"} #{data.count})
    end)
    |> Enum.join("\n")
  end

  # ============================================================================
  # Private - Data Collection
  # ============================================================================

  defp get_phase_metrics do
    case :ets.lookup(:tsc_metrics, :phase_metrics) do
      [{:phase_metrics, metrics}] -> metrics
      [] -> %{}
    end
  end

  defp get_histograms do
    file_check =
      case :ets.lookup(:tsc_metrics, :file_check_histogram) do
        [{:file_check_histogram, h}] -> h
        [] -> %{}
      end

    project_check =
      case :ets.lookup(:tsc_metrics, :project_check_histogram) do
        [{:project_check_histogram, h}] -> h
        [] -> %{}
      end

    %{file_check: file_check, project_check: project_check}
  end
end
