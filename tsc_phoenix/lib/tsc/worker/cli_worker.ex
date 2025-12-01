defmodule TSC.Worker.CLIWorker do
  @moduledoc """
  Worker that invokes the MoonBit CLI directly for each file.

  This is a simpler approach than Port-based communication,
  executing the CLI binary for each check request.

  ## Options

  #{NimbleOptions.docs(TSC.Options.cli_worker_schema())}
  """

  use GenServer

  alias TSC.Telemetry.Metrics
  alias TSC.Options
  alias TSC.Diagnostic

  require Logger

  defstruct [:binary_path, :worker_id, :status, :processed_count, :started_at, :current_task]

  # ============================================================================
  # Public API
  # ============================================================================

  def start_link(opts) do
    {:ok, validated} = Options.validate_cli_worker(opts)
    worker_id = Keyword.fetch!(validated, :worker_id)
    GenServer.start_link(__MODULE__, validated, name: via_tuple(worker_id))
  end

  @doc """
  Check a TypeScript file using the CLI.
  """
  @spec check(pos_integer(), map(), timeout()) :: {:ok, map()} | {:error, term()}
  def check(worker_id, request, timeout \\ 60_000) do
    GenServer.call(via_tuple(worker_id), {:check, request}, timeout)
  end

  @doc """
  Check multiple TypeScript files using the CLI in a single invocation.
  This is more efficient than calling check/3 multiple times.
  """
  @spec check_files(pos_integer(), list(String.t()), map(), timeout()) :: {:ok, map()} | {:error, term()}
  def check_files(worker_id, files, options \\ %{}, timeout \\ 60_000) do
    GenServer.call(via_tuple(worker_id), {:check_files, files, options}, timeout)
  end

  @doc """
  Get worker status.
  """
  @spec status(pos_integer()) :: map()
  def status(worker_id) do
    GenServer.call(via_tuple(worker_id), :status)
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(opts) do
    worker_id = Keyword.fetch!(opts, :worker_id)
    binary_path = Keyword.get(opts, :binary_path) || default_binary_path()

    state = %__MODULE__{
      binary_path: binary_path,
      worker_id: worker_id,
      status: :ready,
      processed_count: 0,
      started_at: System.system_time(:second),
      current_task: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:check, request}, _from, state) do
    start_time = System.monotonic_time(:millisecond)
    file = request.file

    Metrics.emit_file_check_start(file)

    new_state = %{state | status: :busy, current_task: file}

    result = run_check(state.binary_path, file, request[:options] || %{})

    duration = System.monotonic_time(:millisecond) - start_time

    Metrics.emit_file_check_stop(file, duration, result)

    final_state = %{new_state |
      status: :ready,
      processed_count: state.processed_count + 1,
      current_task: nil
    }

    {:reply, result, final_state}
  end

  @impl true
  def handle_call({:check_files, files, options}, _from, state) do
    start_time = System.monotonic_time(:millisecond)

    Enum.each(files, &Metrics.emit_file_check_start/1)

    new_state = %{state | status: :busy, current_task: "batch: #{length(files)} files"}

    result = run_check_files(state.binary_path, files, options)

    duration = System.monotonic_time(:millisecond) - start_time

    Enum.each(files, fn file -> Metrics.emit_file_check_stop(file, duration, result) end)

    final_state = %{new_state |
      status: :ready,
      processed_count: state.processed_count + length(files),
      current_task: nil
    }

    {:reply, result, final_state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    uptime = System.system_time(:second) - state.started_at

    status = %{
      worker_id: state.worker_id,
      status: state.status,
      processed_count: state.processed_count,
      uptime_seconds: uptime,
      current_task: state.current_task
    }

    {:reply, status, state}
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp via_tuple(worker_id) do
    {:via, Registry, {TSC.Worker.Registry, {:cli_worker, worker_id}}}
  end

  defp default_binary_path do
    Application.get_env(:tsc_phoenix, :moonbit_binary,
      "/Users/srikanthkyatham/Personal/moonbit/pure-moonbit-cli/src/moonbit/target/native/release/build/cli/cli.exe"
    )
  end

  defp run_check(binary_path, file, options) do
    if File.exists?(binary_path) do
      args = build_args([file], options)

      case System.cmd(binary_path, args, stderr_to_stdout: true) do
        {output, _exit_code} ->
          parse_json_output(output)
      end
    else
      Logger.warning("MoonBit binary not found at #{binary_path}")
      {:ok, mock_result(file)}
    end
  end

  defp run_check_files(binary_path, files, options) do
    if File.exists?(binary_path) do
      args = build_args(files, options)

      case System.cmd(binary_path, args, stderr_to_stdout: true) do
        {output, _exit_code} ->
          parse_json_output(output)
      end
    else
      Logger.warning("MoonBit binary not found at #{binary_path}")
      {:ok, mock_result_files(files)}
    end
  end

  defp build_args(files, options) when is_list(files) do
    # Use --json for structured JSON output, followed by all file paths
    args = ["--json"] ++ files

    args = if options[:verbose], do: args ++ ["--verbose"], else: args
    args = if options[:out_dir], do: args ++ ["--outDir", options[:out_dir]], else: args

    args
  end

  defp parse_json_output(output) do
    case Jason.decode(output) do
      {:ok, json} ->
        {:ok, parse_json_response(json)}

      {:error, _reason} ->
        # Fallback to text parsing if JSON parsing fails
        Logger.warning("Failed to parse JSON output, falling back to text parsing")
        diagnostics = Diagnostic.parse(output)
        {:ok, %{
          diagnostics: diagnostics,
          diagnostics_maps: Enum.map(diagnostics, &Diagnostic.to_map/1),
          summary: Diagnostic.summary(diagnostics),
          exports: %{},
          success: Enum.empty?(Diagnostic.filter_by_category(diagnostics, :error))
        }}
    end
  end

  defp parse_json_response(json) do
    # Parse the JSON response from the CLI
    # JSON format: {success, stats, files: [{file_path, success, compile_time_ms, diagnostics}]}
    files = Map.get(json, "files", [])

    # Convert JSON diagnostics to Diagnostic structs
    diagnostics =
      files
      |> Enum.flat_map(fn file -> Map.get(file, "diagnostics", []) end)
      |> Enum.map(&json_diagnostic_to_struct/1)

    stats = Map.get(json, "stats", %{})

    %{
      diagnostics: diagnostics,
      diagnostics_maps: Enum.map(diagnostics, &Diagnostic.to_map/1),
      summary: %{
        total: length(diagnostics),
        errors: stats["total_errors"] || 0,
        warnings: stats["total_warnings"] || 0,
        suggestions: 0,
        by_type: diagnostics |> Enum.group_by(& &1.error_type) |> Enum.map(fn {k, v} -> {k, length(v)} end) |> Map.new(),
        files_with_errors: length(files)
      },
      exports: %{},
      success: Map.get(json, "success", false),
      stats: stats
    }
  end

  defp json_diagnostic_to_struct(diag) do
    code_number = diag["code_number"] || 0

    %Diagnostic{
      file: diag["file"],
      line: diag["line"],
      column: diag["column"],
      end_line: nil,
      end_column: nil,
      category: String.to_atom(diag["category"] || "error"),
      code: diag["code"],
      code_number: code_number,
      message: diag["message"],
      error_type: Diagnostic.categorize_error(code_number)
    }
  end

  defp mock_result(_file) do
    %{
      diagnostics: [],
      exports: %{},
      success: true,
      mock: true
    }
  end

  defp mock_result_files(files) do
    %{
      diagnostics: [],
      diagnostics_maps: [],
      summary: %{
        total: 0,
        errors: 0,
        warnings: 0,
        suggestions: 0,
        by_type: %{},
        files_with_errors: 0
      },
      exports: %{},
      success: true,
      stats: %{
        "total_files" => length(files),
        "successful" => length(files),
        "failed" => 0
      },
      mock: true
    }
  end
end
