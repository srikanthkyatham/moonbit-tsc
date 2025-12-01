defmodule TSC.Cache.FileCache do
  @moduledoc """
  ETS-based cache for file contents and metadata.

  Tracks file modification times to enable incremental compilation.
  """

  use GenServer

  @table :tsc_file_cache

  # ============================================================================
  # Public API
  # ============================================================================

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Get cached file info.
  Returns {:ok, info} or :not_found.
  """
  @spec get(String.t()) :: {:ok, map()} | :not_found
  def get(file_path) do
    case :ets.lookup(@table, file_path) do
      [{^file_path, info}] -> {:ok, info}
      [] -> :not_found
    end
  end

  @doc """
  Store file info.
  """
  @spec put(String.t(), map()) :: :ok
  def put(file_path, info) do
    :ets.insert(@table, {file_path, info})
    :ok
  end

  @doc """
  Check if file has changed since cached.
  Returns true if file changed or not cached.
  """
  @spec changed?(String.t()) :: boolean()
  def changed?(file_path) do
    case get(file_path) do
      {:ok, %{mtime: cached_mtime}} ->
        case File.stat(file_path, time: :posix) do
          {:ok, %{mtime: current_mtime}} -> current_mtime > cached_mtime
          {:error, _} -> true
        end
      :not_found ->
        true
    end
  end

  @doc """
  Update cache with current file state.
  """
  @spec update(String.t()) :: {:ok, map()} | {:error, term()}
  def update(file_path) do
    case File.stat(file_path, time: :posix) do
      {:ok, stat} ->
        info = %{
          mtime: stat.mtime,
          size: stat.size,
          cached_at: System.system_time(:millisecond)
        }
        put(file_path, info)
        {:ok, info}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Delete cached file info.
  """
  @spec delete(String.t()) :: :ok
  def delete(file_path) do
    :ets.delete(@table, file_path)
    :ok
  end

  @doc """
  Clear all cached file info.
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
  Get all cached file paths.
  """
  @spec keys() :: [String.t()]
  def keys do
    :ets.select(@table, [{{:"$1", :_}, [], [:"$1"]}])
  end

  @doc """
  Get files that have changed since cached.
  """
  @spec get_changed_files() :: [String.t()]
  def get_changed_files do
    keys()
    |> Enum.filter(&changed?/1)
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
end
