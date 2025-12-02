defmodule TscPhoenixWeb.API.PerformanceController do
  @moduledoc """
  REST API for performance profiling and memory analysis.
  """

  use TscPhoenixWeb, :controller

  alias TSC.Telemetry.{Profiler, MemoryAnalyzer}

  @doc """
  GET /api/performance/memory
  Returns comprehensive memory report.
  """
  def memory(conn, _params) do
    report = MemoryAnalyzer.full_report()
    json(conn, %{memory: serialize_memory_report(report)})
  end

  @doc """
  GET /api/performance/processes
  Returns top processes by memory usage.
  """
  def processes(conn, params) do
    limit = Map.get(params, "limit", "20") |> String.to_integer()
    processes = MemoryAnalyzer.top_processes(limit)

    json(conn, %{
      processes: Enum.map(processes, &serialize_process/1),
      count: length(processes)
    })
  end

  @doc """
  GET /api/performance/ets
  Returns ETS table statistics.
  """
  def ets(conn, _params) do
    ets_stats = MemoryAnalyzer.ets_memory()

    json(conn, %{
      ets: %{
        tables: Enum.map(ets_stats.tables, &serialize_ets_table/1),
        total_count: ets_stats.total_count,
        total_bytes: ets_stats.total_bytes,
        total_mb: ets_stats.total_mb
      }
    })
  end

  @doc """
  POST /api/performance/sessions
  Start a new profiling session.
  """
  def start_session(conn, params) do
    name = Map.get(params, "name", "api-session")
    sample_interval = Map.get(params, "sample_interval", "100") |> parse_int(100)

    case Profiler.start_session(name, sample_interval: sample_interval) do
      {:ok, session_id} ->
        conn
        |> put_status(:created)
        |> json(%{
          session_id: session_id,
          name: name,
          status: "running"
        })

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: inspect(reason)})
    end
  end

  @doc """
  POST /api/performance/sessions/:id/stop
  Stop a profiling session.
  """
  def stop_session(conn, %{"id" => session_id}) do
    case Profiler.stop_session(session_id) do
      {:ok, session} ->
        json(conn, %{
          session: serialize_session(session)
        })

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Session not found"})
    end
  end

  @doc """
  GET /api/performance/sessions
  List all profiling sessions.
  """
  def list_sessions(conn, _params) do
    sessions = Profiler.list_sessions()

    json(conn, %{
      sessions: Enum.map(sessions, &serialize_session/1),
      count: length(sessions)
    })
  end

  @doc """
  GET /api/performance/sessions/:id
  Get a specific profiling session.
  """
  def get_session(conn, %{"id" => session_id}) do
    case Profiler.get_session(session_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Session not found"})

      session ->
        # Include hot path analysis for completed sessions
        response = serialize_session(session)

        response = if session.status == :completed do
          hot_paths = Profiler.analyze_hot_paths(session_id)
          bottlenecks = Profiler.detect_bottlenecks(session_id)

          response
          |> Map.put(:hot_paths, hot_paths)
          |> Map.put(:bottlenecks, bottlenecks)
        else
          response
        end

        json(conn, %{session: response})
    end
  end

  # ============================================================================
  # Serialization Helpers
  # ============================================================================

  defp serialize_memory_report(report) do
    %{
      system: report.system,
      beam: serialize_beam_memory(report.beam),
      caches: report.caches,
      ets: %{
        total_count: report.ets.total_count,
        total_mb: report.ets.total_mb
      },
      gc_stats: report.gc_stats,
      recommendations: report.recommendations
    }
  end

  defp serialize_beam_memory(beam) do
    Map.new(beam, fn {key, data} ->
      {key, %{
        bytes: data.bytes,
        mb: data.mb,
        percentage: data.percentage
      }}
    end)
  end

  defp serialize_process(proc) do
    %{
      pid: inspect(proc.pid),
      name: proc.name,
      memory_bytes: proc.memory_bytes,
      memory_mb: proc.memory_mb,
      heap_size: proc.heap_size,
      stack_size: proc.stack_size,
      message_queue: proc.message_queue,
      reductions: proc.reductions,
      current_function: proc.current_function,
      initial_call: proc.initial_call
    }
  end

  defp serialize_ets_table(table) do
    %{
      name: to_string(table.name),
      type: table.type,
      size: table.size,
      memory_bytes: table.memory_bytes,
      memory_mb: table.memory_mb,
      protection: table.protection
    }
  end

  defp serialize_session(session) do
    base = %{
      id: session.id,
      name: session.name,
      status: session.status,
      started_at: session.started_at,
      ended_at: session.ended_at
    }

    if session.summary do
      Map.put(base, :summary, session.summary)
    else
      base
    end
  end

  defp parse_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end
  defp parse_int(value, _default) when is_integer(value), do: value
  defp parse_int(_, default), do: default
end
