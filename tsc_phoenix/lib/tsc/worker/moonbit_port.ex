defmodule TSC.Worker.MoonbitPort do
  @moduledoc """
  GenServer managing a MoonBit worker process via Erlang Port.

  Handles communication with the MoonBit compiler binary through stdin/stdout.
  """

  use GenServer

  alias TSC.Worker.Protocol
  alias TSC.Telemetry.Metrics

  require Logger

  @default_timeout 30_000

  defstruct [:port, :pending, :worker_id, :status, :processed_count, :started_at]

  # ============================================================================
  # Public API
  # ============================================================================

  def start_link(opts) do
    worker_id = Keyword.get(opts, :worker_id, 1)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(worker_id))
  end

  @doc """
  Check a TypeScript file.
  """
  @spec check(pos_integer(), map(), timeout()) :: {:ok, map()} | {:error, term()}
  def check(worker_id, request, timeout \\ @default_timeout) do
    GenServer.call(via_tuple(worker_id), {:check, request}, timeout)
  end

  @doc """
  Parse a TypeScript file (no type checking).
  """
  @spec parse(pos_integer(), map(), timeout()) :: {:ok, map()} | {:error, term()}
  def parse(worker_id, request, timeout \\ @default_timeout) do
    GenServer.call(via_tuple(worker_id), {:parse, request}, timeout)
  end

  @doc """
  Extract imports from a TypeScript file.
  """
  @spec extract_imports(pos_integer(), map(), timeout()) :: {:ok, list()} | {:error, term()}
  def extract_imports(worker_id, request, timeout \\ @default_timeout) do
    GenServer.call(via_tuple(worker_id), {:extract_imports, request}, timeout)
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
    worker_id = Keyword.get(opts, :worker_id, 1)
    binary_path = Keyword.get(opts, :binary_path, default_binary_path())

    Process.flag(:trap_exit, true)

    {:ok, port} = start_port(binary_path)

    state = %__MODULE__{
      port: port,
      pending: %{},
      worker_id: worker_id,
      status: :ready,
      processed_count: 0,
      started_at: System.system_time(:second)
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:check, request}, from, state) do
    request_id = :erlang.unique_integer([:positive])
    json = Protocol.encode_check_request(Map.put(request, :id, request_id))

    Metrics.emit_worker_request_start(state.worker_id, request.file)

    send_to_port(state.port, json)

    new_state = %{state |
      pending: Map.put(state.pending, request_id, {from, request.file, System.monotonic_time(:millisecond)}),
      status: :busy
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_call({:parse, request}, from, state) do
    request_id = :erlang.unique_integer([:positive])
    json = Protocol.encode_parse_request(Map.put(request, :id, request_id))

    send_to_port(state.port, json)

    new_state = %{state |
      pending: Map.put(state.pending, request_id, {from, request.file, System.monotonic_time(:millisecond)}),
      status: :busy
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_call({:extract_imports, request}, from, state) do
    request_id = :erlang.unique_integer([:positive])
    json = Protocol.encode_extract_imports_request(Map.put(request, :id, request_id))

    send_to_port(state.port, json)

    new_state = %{state |
      pending: Map.put(state.pending, request_id, {from, request.file, System.monotonic_time(:millisecond)}),
      status: :busy
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    uptime = System.system_time(:second) - state.started_at

    status = %{
      worker_id: state.worker_id,
      status: state.status,
      processed_count: state.processed_count,
      pending_count: map_size(state.pending),
      uptime_seconds: uptime
    }

    {:reply, status, state}
  end

  @impl true
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    # Handle line-based output from the port
    case Protocol.decode_response(data) do
      {:ok, %{id: id, result: result}} ->
        handle_response(state, id, {:ok, result})

      {:error, %{id: id, error: error}} ->
        handle_response(state, id, {:error, error})

      {:error, reason} ->
        Logger.warning("Failed to decode port response: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    Logger.error("MoonBit worker #{state.worker_id} exited with status #{status}")
    Metrics.emit_worker_crash(state.worker_id, status)

    # Reply to all pending requests with error
    Enum.each(state.pending, fn {_id, {from, _file, _start}} ->
      GenServer.reply(from, {:error, :worker_crashed})
    end)

    {:stop, {:worker_crashed, status}, %{state | port: nil, pending: %{}}}
  end

  @impl true
  def handle_info({:EXIT, port, reason}, %{port: port} = state) do
    Logger.error("MoonBit worker #{state.worker_id} port exited: #{inspect(reason)}")
    Metrics.emit_worker_crash(state.worker_id, reason)

    {:stop, {:port_exit, reason}, %{state | port: nil}}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("MoonBit worker #{state.worker_id} terminating: #{inspect(reason)}")

    if state.port do
      Port.close(state.port)
    end

    :ok
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp via_tuple(worker_id) do
    {:via, Registry, {TSC.Worker.Registry, {:worker, worker_id}}}
  end

  defp default_binary_path do
    Application.get_env(:tsc_phoenix, :moonbit_binary, "./priv/moonbit_worker")
  end

  defp start_port(binary_path) do
    if File.exists?(binary_path) do
      port = Port.open({:spawn_executable, binary_path}, [
        :binary,
        :exit_status,
        {:line, 1_048_576},  # 1MB line buffer
        :use_stdio,
        :stderr_to_stdout
      ])

      {:ok, port}
    else
      Logger.warning("MoonBit binary not found at #{binary_path}, using mock mode")
      {:ok, nil}  # Mock mode for development
    end
  end

  defp send_to_port(nil, _json) do
    # Mock mode - do nothing
    :ok
  end

  defp send_to_port(port, json) do
    Port.command(port, json <> "\n")
  end

  defp handle_response(state, id, result) do
    case Map.pop(state.pending, id) do
      {{from, file, start_time}, new_pending} ->
        duration = System.monotonic_time(:millisecond) - start_time

        Metrics.emit_worker_request_stop(state.worker_id, file, duration, result)

        GenServer.reply(from, result)

        new_status = if map_size(new_pending) == 0, do: :ready, else: :busy

        new_state = %{state |
          pending: new_pending,
          processed_count: state.processed_count + 1,
          status: new_status
        }

        {:noreply, new_state}

      {nil, _} ->
        Logger.warning("Received response for unknown request id: #{id}")
        {:noreply, state}
    end
  end
end
