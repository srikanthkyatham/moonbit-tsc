defmodule TSC.Worker.PoolSupervisor do
  @moduledoc """
  Supervisor for MoonBit worker pool.

  Manages multiple worker processes with automatic restart on crash.

  ## Options

  #{NimbleOptions.docs(TSC.Options.pool_supervisor_schema())}
  """

  use Supervisor

  alias TSC.Worker.CLIWorker
  alias TSC.Options

  # ============================================================================
  # Public API
  # ============================================================================

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get the next available worker using round-robin.
  """
  @spec get_worker() :: pos_integer()
  def get_worker do
    counter = :atomics.add_get(worker_counter(), 1, 1)
    rem(counter - 1, pool_size()) + 1
  end

  @doc """
  Get status of all workers.
  """
  @spec status() :: list(map())
  def status do
    1..pool_size()
    |> Enum.map(fn id ->
      try do
        CLIWorker.status(id)
      catch
        :exit, _ -> %{worker_id: id, status: :down}
      end
    end)
  end

  @doc """
  Get pool size.
  """
  @spec pool_size() :: pos_integer()
  def pool_size do
    Application.get_env(:tsc_phoenix, :worker_pool_size, 4)
  end

  @doc """
  Check a file using an available worker.
  """
  @spec check(map(), timeout()) :: {:ok, map()} | {:error, term()}
  def check(request, timeout \\ 60_000) do
    worker_id = get_worker()
    CLIWorker.check(worker_id, request, timeout)
  end

  @doc """
  Parse a file using an available worker (delegates to check for now).
  """
  @spec parse(map(), timeout()) :: {:ok, map()} | {:error, term()}
  def parse(request, timeout \\ 60_000) do
    worker_id = get_worker()
    CLIWorker.check(worker_id, request, timeout)
  end

  @doc """
  Extract imports using an available worker (placeholder - returns empty for now).
  """
  @spec extract_imports(map(), timeout()) :: {:ok, map()} | {:error, term()}
  def extract_imports(_request, _timeout \\ 60_000) do
    # TODO: Implement import extraction via CLI or parse output
    {:ok, %{imports: []}}
  end

  # ============================================================================
  # Supervisor Callbacks
  # ============================================================================

  @impl true
  def init(opts) do
    {:ok, validated} = Options.validate_pool_supervisor(opts)
    pool_size = Keyword.fetch!(validated, :pool_size)
    binary_path = Keyword.get(validated, :binary_path)

    # Initialize the round-robin counter
    ref = :atomics.new(1, [])
    :persistent_term.put({__MODULE__, :counter}, ref)

    # Store pool size for easy access
    Application.put_env(:tsc_phoenix, :worker_pool_size, pool_size)

    children = [
      # Registry for worker lookup
      {Registry, keys: :unique, name: TSC.Worker.Registry}
    ] ++ worker_children(pool_size, binary_path)

    Supervisor.init(children, strategy: :one_for_one, max_restarts: 10, max_seconds: 60)
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp worker_children(pool_size, binary_path) do
    for id <- 1..pool_size do
      opts = [worker_id: id]
      opts = if binary_path, do: Keyword.put(opts, :binary_path, binary_path), else: opts

      Supervisor.child_spec(
        {CLIWorker, opts},
        id: {:cli_worker, id}
      )
    end
  end

  defp worker_counter do
    :persistent_term.get({__MODULE__, :counter})
  end
end
