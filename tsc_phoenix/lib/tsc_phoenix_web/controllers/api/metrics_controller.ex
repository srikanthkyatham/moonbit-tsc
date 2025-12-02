defmodule TscPhoenixWeb.API.MetricsController do
  @moduledoc """
  API controller for metrics export.

  Provides endpoints for Prometheus scraping and JSON metrics export.
  """

  use TscPhoenixWeb, :controller

  alias TSC.Telemetry.PrometheusExporter
  alias TSC.Telemetry.Reporter

  @doc """
  GET /api/metrics/prometheus
  Returns metrics in Prometheus text format.
  """
  def prometheus(conn, _params) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, PrometheusExporter.export())
  end

  @doc """
  GET /api/metrics/json
  Returns metrics in JSON format.
  """
  def json_export(conn, _params) do
    json(conn, PrometheusExporter.export_json())
  end

  @doc """
  GET /api/metrics/phases
  Returns phase timing metrics.
  """
  def phases(conn, _params) do
    phases = Reporter.get_phase_metrics()

    json(conn, %{
      phases: phases,
      summary: summarize_phases(phases)
    })
  end

  @doc """
  GET /api/metrics/history/:metric
  Returns historical data for a specific metric.
  """
  def history(conn, %{"metric" => metric}) do
    allowed_metrics = ~w(avg_duration_ms cache_hit_rate errors_count file_checks)

    if metric in allowed_metrics do
      history = Reporter.get_history(String.to_existing_atom(metric), 720)

      formatted = Enum.map(history, fn {timestamp, value} ->
        %{timestamp: timestamp, value: value}
      end)

      json(conn, %{
        metric: metric,
        data: formatted,
        count: length(formatted)
      })
    else
      conn
      |> put_status(400)
      |> json(%{error: "Invalid metric name", allowed: allowed_metrics})
    end
  end

  @doc """
  GET /api/metrics/summary
  Returns a summary of all metrics.
  """
  def summary(conn, _params) do
    metrics = Reporter.get_metrics()
    current_build = Reporter.get_current_build()
    active = Reporter.get_active_checks()

    json(conn, %{
      metrics: metrics,
      current_build: current_build,
      active_checks: active,
      active_count: length(active)
    })
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp summarize_phases(phases) when map_size(phases) == 0 do
    %{total_phases: 0, total_time_ms: 0}
  end

  defp summarize_phases(phases) do
    total_time = phases |> Map.values() |> Enum.map(&Map.get(&1, :total_ms, 0)) |> Enum.sum()
    total_count = phases |> Map.values() |> Enum.map(&Map.get(&1, :count, 0)) |> Enum.sum()

    slowest = phases
    |> Enum.max_by(fn {_phase, data} -> Map.get(data, :avg_ms, 0) end, fn -> nil end)

    %{
      total_phases: map_size(phases),
      total_executions: total_count,
      total_time_ms: total_time,
      slowest_phase: elem(slowest || {:none, %{}}, 0)
    }
  end
end
