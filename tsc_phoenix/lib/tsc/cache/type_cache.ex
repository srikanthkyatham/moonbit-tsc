defmodule TSC.Cache.TypeCache do
  @moduledoc """
  ETS-based cache for TypeScript type exports.

  Stores exported types for each module to enable cross-file type checking.
  Uses ETS for fast, concurrent reads without process bottlenecks.
  """

  use GenServer

  @table :tsc_type_cache

  # ============================================================================
  # Public API
  # ============================================================================

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Get exported types for a module.
  Returns {:ok, exports} or :not_found.
  """
  @spec get(String.t()) :: {:ok, map()} | :not_found
  def get(module_path) do
    case :ets.lookup(@table, module_path) do
      [{^module_path, exports, _timestamp}] -> {:ok, exports}
      [] -> :not_found
    end
  end

  @doc """
  Store exported types for a module.
  """
  @spec put(String.t(), map()) :: :ok
  def put(module_path, exports) do
    timestamp = System.system_time(:millisecond)
    :ets.insert(@table, {module_path, exports, timestamp})
    :ok
  end

  @doc """
  Delete cached types for a module.
  """
  @spec delete(String.t()) :: :ok
  def delete(module_path) do
    :ets.delete(@table, module_path)
    :ok
  end

  @doc """
  Clear all cached types.
  """
  @spec clear() :: :ok
  def clear do
    :ets.delete_all_objects(@table)
    :ok
  end

  @doc """
  Get cache statistics.
  """
  @spec stats() :: map()
  def stats do
    info = :ets.info(@table)

    %{
      entries: info[:size],
      memory_bytes: info[:memory] * :erlang.system_info(:wordsize),
      memory_mb: Float.round(info[:memory] * :erlang.system_info(:wordsize) / 1_048_576, 2)
    }
  end

  @doc """
  Get all cached module paths.
  """
  @spec keys() :: [String.t()]
  def keys do
    :ets.select(@table, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  @doc """
  Check if module is cached.
  """
  @spec has?(String.t()) :: boolean()
  def has?(module_path) do
    case :ets.lookup(@table, module_path) do
      [{^module_path, _, _}] -> true
      [] -> false
    end
  end

  @doc """
  Get multiple modules' exports at once.
  Returns a map of module_path => exports for found modules.
  """
  @spec get_many([String.t()]) :: map()
  def get_many(module_paths) do
    module_paths
    |> Enum.reduce(%{}, fn path, acc ->
      case get(path) do
        {:ok, exports} -> Map.put(acc, path, exports)
        :not_found -> acc
      end
    end)
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(_) do
    table = :ets.new(@table, [
      :named_table,
      :public,
      :set,
      read_concurrency: true,
      write_concurrency: true
    ])

    {:ok, %{table: table}}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    {:reply, stats(), state}
  end
end
