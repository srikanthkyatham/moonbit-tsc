defmodule TscPhoenixWeb.API.CheckController do
  @moduledoc """
  REST API controller for TypeScript checking.

  Provides endpoints for CI/CD integration.
  """

  use TscPhoenixWeb, :controller

  alias TSC.Coordinator
  alias TSC.Telemetry.Reporter

  @doc """
  POST /api/check
  Body: { "files": ["src/foo.ts"], "project": "./path", "options": {} }

  Response: {
    "success": true,
    "diagnostics": [...],
    "stats": { "files_checked": 10, "elapsed_ms": 234 }
  }
  """
  def create(conn, params) do
    files = case params do
      %{"files" => files} when is_list(files) -> files
      %{"project" => project} -> discover_project_files(project)
      _ -> discover_project_files("./")
    end

    options = parse_options(params["options"])

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
    metrics = Reporter.get_metrics()
    active = Reporter.get_active_checks()
    current_build = Reporter.get_current_build()

    json(conn, %{
      building: length(active) > 0,
      active_files: active,
      current_build: current_build,
      metrics: metrics
    })
  end

  @doc """
  GET /api/metrics
  Returns detailed metrics.
  """
  def metrics(conn, _params) do
    metrics = Reporter.get_metrics()

    json(conn, %{
      metrics: metrics,
      history: %{
        avg_duration: Reporter.get_history(:avg_duration_ms, 60),
        cache_hit_rate: Reporter.get_history(:cache_hit_rate, 60),
        errors_count: Reporter.get_history(:errors_count, 60)
      }
    })
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp discover_project_files(project_path) when is_binary(project_path) do
    Path.wildcard(Path.join(project_path, "**/*.{ts,tsx}"))
    |> Enum.reject(&String.contains?(&1, "node_modules"))
  end

  defp discover_project_files(_), do: discover_project_files("./")

  defp parse_options(nil), do: []
  defp parse_options(options) when is_map(options) do
    [
      incremental: Map.get(options, "incremental", true),
      concurrency: Map.get(options, "concurrency", 4)
    ]
  end

  defp format_diagnostics(diagnostics) do
    Enum.map(diagnostics, fn d ->
      %{
        file: d[:file],
        line: d[:line],
        column: d[:column],
        end_line: d[:end_line],
        end_column: d[:end_column],
        code: d[:code],
        category: to_string(d[:category]),
        message: d[:message]
      }
    end)
  end
end
