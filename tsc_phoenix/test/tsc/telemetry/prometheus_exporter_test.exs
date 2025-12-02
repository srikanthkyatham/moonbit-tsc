defmodule TSC.Telemetry.PrometheusExporterTest do
  use ExUnit.Case, async: false

  alias TSC.Telemetry.PrometheusExporter
  alias TSC.Telemetry.Reporter

  setup do
    # Reset metrics before each test
    Reporter.reset()
    :ok
  end

  describe "export/0" do
    test "returns valid Prometheus format" do
      output = PrometheusExporter.export()

      assert is_binary(output)
      assert String.contains?(output, "# HELP")
      assert String.contains?(output, "# TYPE")
    end

    test "includes counter metrics" do
      output = PrometheusExporter.export()

      assert String.contains?(output, "tsc_file_checks_total")
      assert String.contains?(output, "tsc_cache_hits_total")
      assert String.contains?(output, "tsc_cache_misses_total")
      assert String.contains?(output, "tsc_errors_total")
      assert String.contains?(output, "tsc_warnings_total")
      assert String.contains?(output, "tsc_worker_crashes_total")
    end

    test "includes gauge metrics" do
      output = PrometheusExporter.export()

      assert String.contains?(output, "tsc_active_checks")
      assert String.contains?(output, "tsc_cache_hit_rate")
      assert String.contains?(output, "tsc_avg_duration_ms")
    end

    test "includes histogram metrics" do
      output = PrometheusExporter.export()

      assert String.contains?(output, "tsc_file_check_duration_ms")
      assert String.contains?(output, "tsc_project_check_duration_ms")
      assert String.contains?(output, "_bucket{le=")
      assert String.contains?(output, "_sum")
      assert String.contains?(output, "_count")
    end

    test "includes build info" do
      output = PrometheusExporter.export()

      assert String.contains?(output, "tsc_build_info")
      assert String.contains?(output, ~s(version="0.1.0"))
    end
  end

  describe "export_json/0" do
    test "returns valid JSON structure" do
      result = PrometheusExporter.export_json()

      assert is_map(result)
      assert Map.has_key?(result, :counters)
      assert Map.has_key?(result, :gauges)
      assert Map.has_key?(result, :phases)
      assert Map.has_key?(result, :histograms)
    end

    test "counters include expected fields" do
      result = PrometheusExporter.export_json()

      counters = result.counters
      assert Map.has_key?(counters, :file_checks_total)
      assert Map.has_key?(counters, :cache_hits_total)
      assert Map.has_key?(counters, :cache_misses_total)
      assert Map.has_key?(counters, :errors_total)
      assert Map.has_key?(counters, :warnings_total)
      assert Map.has_key?(counters, :worker_crashes_total)
    end

    test "gauges include expected fields" do
      result = PrometheusExporter.export_json()

      gauges = result.gauges
      assert Map.has_key?(gauges, :active_checks)
      assert Map.has_key?(gauges, :cache_hit_rate)
      assert Map.has_key?(gauges, :avg_duration_ms)
    end

    test "histograms have expected structure" do
      result = PrometheusExporter.export_json()

      histograms = result.histograms
      assert Map.has_key?(histograms, :file_check)
      assert Map.has_key?(histograms, :project_check)
    end

    test "counters return numeric values" do
      result = PrometheusExporter.export_json()

      counters = result.counters
      assert is_number(counters.file_checks_total)
      assert is_number(counters.cache_hits_total)
      assert is_number(counters.errors_total)
    end
  end
end
