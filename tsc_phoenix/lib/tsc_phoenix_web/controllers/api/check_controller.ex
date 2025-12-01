defmodule TscPhoenixWeb.API.CheckController do
  @moduledoc """
  REST API controller for TypeScript checking.

  Provides endpoints for CI/CD integration.

  ## API Check Options

  #{NimbleOptions.docs(TSC.Options.api_check_schema())}
  """

  use TscPhoenixWeb, :controller

  alias TSC.Coordinator
  alias TSC.Telemetry.Reporter
  alias TSC.Options
  alias TSC.Project.TsConfig

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
    case parse_and_validate_params(params) do
      {:ok, files, coordinator_opts} ->
        # Use batch check for direct file lists (more efficient)
        # Use check_project for tsconfig-based checking (handles dependency ordering)
        result = if Keyword.get(coordinator_opts, :use_batch, true) do
          case Coordinator.check_files_batch(files, coordinator_opts) do
            {:ok, r} -> r
            {:error, reason} -> %{success: false, diagnostics: [], stats: %{error: inspect(reason)}}
          end
        else
          Coordinator.check_project(files, coordinator_opts)
        end

        conn
        |> put_status(if result.success, do: 200, else: 400)
        |> json(%{
          success: result.success,
          diagnostics: format_diagnostics(result.diagnostics),
          stats: result.stats
        })

      {:error, %NimbleOptions.ValidationError{} = error} ->
        conn
        |> put_status(400)
        |> json(%{
          success: false,
          error: Exception.message(error),
          diagnostics: [],
          stats: %{}
        })
    end
  end

  defp parse_and_validate_params(params) do
    # Convert params to keyword list for validation
    api_opts = params_to_keyword(params)

    case Options.validate_api_check(api_opts) do
      {:ok, validated} ->
        files = discover_files(validated)
        coordinator_opts = extract_coordinator_opts(validated)
        {:ok, files, coordinator_opts}

      {:error, error} ->
        {:error, error}
    end
  end

  defp params_to_keyword(params) do
    [
      files: Map.get(params, "files", []),
      project: Map.get(params, "project"),
      tsconfig: Map.get(params, "tsconfig"),
      incremental: get_in(params, ["options", "incremental"]) |> to_boolean(true),
      concurrency: get_in(params, ["options", "concurrency"]) || 4
    ]
  end

  defp to_boolean(nil, default), do: default
  defp to_boolean(value, _default) when is_boolean(value), do: value
  defp to_boolean("true", _default), do: true
  defp to_boolean("false", _default), do: false
  defp to_boolean(_, default), do: default

  defp discover_files(validated) do
    cond do
      length(Keyword.fetch!(validated, :files)) > 0 ->
        Keyword.fetch!(validated, :files)

      tsconfig = Keyword.fetch!(validated, :tsconfig) ->
        discover_files_from_tsconfig(tsconfig)

      project = Keyword.fetch!(validated, :project) ->
        discover_project_files(project)

      true ->
        discover_project_files("./")
    end
  end

  defp extract_coordinator_opts(validated) do
    [
      incremental: Keyword.fetch!(validated, :incremental),
      concurrency: Keyword.fetch!(validated, :concurrency)
    ]
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

  defp discover_files_from_tsconfig(tsconfig_path) when is_binary(tsconfig_path) do
    case TsConfig.load(tsconfig_path) do
      {:ok, config} ->
        TsConfig.get_files(config)

      {:error, _reason} ->
        # Fall back to directory scanning
        if File.dir?(tsconfig_path) do
          discover_project_files(tsconfig_path)
        else
          discover_project_files(Path.dirname(tsconfig_path))
        end
    end
  end

  defp discover_files_from_tsconfig(_), do: discover_project_files("./")


  defp format_diagnostics(diagnostics) do
    Enum.map(diagnostics, fn d ->
      case d do
        %TSC.Diagnostic{} ->
          TSC.Diagnostic.to_map(d)

        %{} ->
          # Legacy map format fallback
          %{
            file: d[:file] || d.file,
            line: d[:line] || d.line,
            column: d[:column] || d.column,
            end_line: d[:end_line],
            end_column: d[:end_column],
            code: d[:code] || d.code,
            code_number: d[:code_number],
            category: to_string(d[:category] || d.category),
            message: d[:message] || d.message,
            error_type: to_string(d[:error_type] || :other),
            error_type_label: d[:error_type_label] || "Other"
          }
      end
    end)
  end
end
