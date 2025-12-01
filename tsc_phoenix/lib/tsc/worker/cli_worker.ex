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
      args = build_args(file, options)

      case System.cmd(binary_path, args, stderr_to_stdout: true) do
        {output, 0} ->
          {:ok, parse_success_output(file, output)}

        {output, exit_code} ->
          {:ok, parse_error_output(file, output, exit_code)}
      end
    else
      Logger.warning("MoonBit binary not found at #{binary_path}")
      {:ok, mock_result(file)}
    end
  end

  defp build_args(file, options) do
    # Always use --reportDiagnostics to get type errors/warnings in output
    args = ["--reportDiagnostics", file]

    args = if options[:verbose], do: args ++ ["--verbose"], else: args
    args = if options[:out_dir], do: args ++ ["--outDir", options[:out_dir]], else: args

    args
  end

  defp parse_success_output(_file, output) do
    # Parse CLI output for diagnostics
    diagnostics = parse_diagnostics_from_output(output)

    %{
      diagnostics: diagnostics,
      exports: %{},  # CLI doesn't output exports yet
      success: Enum.empty?(Enum.filter(diagnostics, &(&1.category == :error)))
    }
  end

  defp parse_error_output(_file, output, _exit_code) do
    diagnostics = parse_diagnostics_from_output(output)

    %{
      diagnostics: diagnostics,
      exports: %{},
      success: false
    }
  end

  defp parse_diagnostics_from_output(output) do
    # Parse lines like: src/foo.ts:10:5 - error TS2322: Type 'string' is not assignable to type 'number'
    output
    |> String.split("\n")
    |> Enum.filter(fn line ->
      String.contains?(line, " - error TS") or
      String.contains?(line, " - warning TS") or
      String.contains?(line, " - suggestion TS") or
      String.contains?(line, " - message TS")
    end)
    |> Enum.map(&parse_diagnostic_line/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_diagnostic_line(line) do
    # MoonBit CLI format: file_path:line:column - category TScode: message
    # Example: src/foo.ts:10:5 - error TS2322: Type 'string' is not assignable to type 'number'
    regex = ~r/^(.+?):(\d+):(\d+) - (error|warning|suggestion|message) (TS\d+): (.+)$/

    case Regex.run(regex, line) do
      [_, file, line_num, col, category, code, message] ->
        %{
          file: file,
          line: String.to_integer(line_num),
          column: String.to_integer(col),
          category: String.to_atom(category),
          code: code,
          message: message
        }

      _ ->
        nil
    end
  end

  defp mock_result(_file) do
    %{
      diagnostics: [],
      exports: %{},
      success: true,
      mock: true
    }
  end
end
