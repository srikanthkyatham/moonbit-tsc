defmodule TSC.Cluster.DistributedCache do
  @moduledoc """
  Distributed caching layer for cross-node file and type caching.

  Implements:
  - Local-first caching with remote fallback
  - Cache synchronization between nodes
  - Invalidation propagation
  """

  use GenServer

  alias TSC.Cluster.NodeRegistry
  alias TSC.Cache.{TypeCache, FileCache}

  require Logger

  @sync_batch_size 100

  # ============================================================================
  # Public API
  # ============================================================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get a cached type, checking local first then remote nodes.
  """
  @spec get_type(String.t()) :: {:ok, map()} | :not_found
  def get_type(key) do
    # Try local first
    case TypeCache.get(key) do
      {:ok, value} ->
        {:ok, value}

      :not_found ->
        # Try remote nodes
        get_from_remote(:type, key)
    end
  end

  @doc """
  Get a cached file, checking local first then remote nodes.
  """
  @spec get_file(String.t()) :: {:ok, map()} | :not_found
  def get_file(file_path) do
    # Try local first
    case FileCache.get(file_path) do
      {:ok, value} ->
        {:ok, value}

      :not_found ->
        # Try remote nodes
        get_from_remote(:file, file_path)
    end
  end

  @doc """
  Put a type in cache and optionally broadcast to cluster.
  """
  @spec put_type(String.t(), map(), keyword()) :: :ok
  def put_type(key, value, opts \\ []) do
    TypeCache.put(key, value)

    if Keyword.get(opts, :broadcast, false) do
      broadcast_cache_update(:type, :put, key, value)
    end

    :ok
  end

  @doc """
  Put a file in cache and optionally broadcast to cluster.
  """
  @spec put_file(String.t(), map(), keyword()) :: :ok
  def put_file(file_path, value, opts \\ []) do
    FileCache.put(file_path, value)

    if Keyword.get(opts, :broadcast, false) do
      broadcast_cache_update(:file, :put, file_path, value)
    end

    :ok
  end

  @doc """
  Invalidate a cache entry across the cluster.
  """
  @spec invalidate(atom(), String.t()) :: :ok
  def invalidate(type, key) do
    case type do
      :type -> TypeCache.invalidate(key)
      :file -> FileCache.invalidate(key)
    end

    # Broadcast invalidation
    broadcast_cache_update(type, :invalidate, key, nil)

    :ok
  end

  @doc """
  Invalidate all entries matching a pattern.
  """
  @spec invalidate_pattern(atom(), String.t()) :: :ok
  def invalidate_pattern(type, pattern) do
    case type do
      :type -> TypeCache.invalidate_pattern(pattern)
      :file -> FileCache.invalidate_pattern(pattern)
    end

    # Broadcast pattern invalidation
    broadcast_cache_update(type, :invalidate_pattern, pattern, nil)

    :ok
  end

  @doc """
  Clear all caches across the cluster.
  """
  @spec clear_all() :: :ok
  def clear_all do
    TypeCache.clear()
    FileCache.clear()

    # Broadcast clear
    for node <- Node.list() do
      GenServer.cast({__MODULE__, node}, :clear_all)
    end

    :ok
  end

  @doc """
  Warm cache from another node.
  """
  @spec warm_from_node(node()) :: {:ok, map()} | {:error, term()}
  def warm_from_node(source_node) do
    GenServer.call(__MODULE__, {:warm_from_node, source_node}, 60_000)
  end

  @doc """
  Get cache statistics across cluster.
  """
  @spec cluster_cache_stats() :: map()
  def cluster_cache_stats do
    local_stats = %{
      node: node(),
      type_cache: TypeCache.stats(),
      file_cache: FileCache.stats()
    }

    remote_stats = for remote_node <- Node.list() do
      try do
        GenServer.call({__MODULE__, remote_node}, :get_local_stats, 5_000)
      catch
        _, _ -> nil
      end
    end
    |> Enum.reject(&is_nil/1)

    %{
      nodes: [local_stats | remote_stats],
      total_type_entries: Enum.sum(Enum.map([local_stats | remote_stats], & &1.type_cache.entries)),
      total_file_entries: Enum.sum(Enum.map([local_stats | remote_stats], & &1.file_cache.entries)),
      total_memory_mb: Enum.sum(Enum.map([local_stats | remote_stats], fn s ->
        s.type_cache.memory_mb + s.file_cache.memory_mb
      end))
    }
  end

  @doc """
  Request cache entry from specific node.
  """
  @spec request_from_node(node(), atom(), String.t()) :: {:ok, any()} | :not_found
  def request_from_node(target_node, cache_type, key) do
    try do
      GenServer.call({__MODULE__, target_node}, {:get_local, cache_type, key}, 5_000)
    catch
      _, _ -> :not_found
    end
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(_opts) do
    # Subscribe to cluster updates
    Phoenix.PubSub.subscribe(TscPhoenix.PubSub, "cache:updates")

    {:ok, %{}}
  end

  @impl true
  def handle_call({:get_local, :type, key}, _from, state) do
    result = TypeCache.get(key)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:get_local, :file, key}, _from, state) do
    result = FileCache.get(key)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:get_local_stats, _from, state) do
    stats = %{
      node: node(),
      type_cache: TypeCache.stats(),
      file_cache: FileCache.stats()
    }
    {:reply, stats, state}
  end

  @impl true
  def handle_call({:warm_from_node, source_node}, _from, state) do
    result = do_warm_from_node(source_node)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:get_cache_keys, cache_type, batch_offset}, _from, state) do
    keys = case cache_type do
      :type -> TypeCache.keys(batch_offset, @sync_batch_size)
      :file -> FileCache.keys(batch_offset, @sync_batch_size)
    end
    {:reply, keys, state}
  end

  @impl true
  def handle_call({:get_cache_entries, cache_type, keys}, _from, state) do
    entries = case cache_type do
      :type ->
        Enum.map(keys, fn key ->
          case TypeCache.get(key) do
            {:ok, value} -> {key, value}
            :not_found -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      :file ->
        Enum.map(keys, fn key ->
          case FileCache.get(key) do
            {:ok, value} -> {key, value}
            :not_found -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)
    end

    {:reply, entries, state}
  end

  @impl true
  def handle_cast({:cache_update, :type, :put, key, value}, state) do
    TypeCache.put(key, value)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:cache_update, :file, :put, key, value}, state) do
    FileCache.put(key, value)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:cache_update, :type, :invalidate, key, _}, state) do
    TypeCache.invalidate(key)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:cache_update, :file, :invalidate, key, _}, state) do
    FileCache.invalidate(key)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:cache_update, :type, :invalidate_pattern, pattern, _}, state) do
    TypeCache.invalidate_pattern(pattern)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:cache_update, :file, :invalidate_pattern, pattern, _}, state) do
    FileCache.invalidate_pattern(pattern)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:clear_all, state) do
    TypeCache.clear()
    FileCache.clear()
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp get_from_remote(cache_type, key) do
    nodes = NodeRegistry.nodes_with_capability(:cache)
    |> Enum.filter(&(&1.node != node()))
    |> Enum.shuffle()  # Randomize to distribute load

    Enum.reduce_while(nodes, :not_found, fn node_info, _acc ->
      case request_from_node(node_info.node, cache_type, key) do
        {:ok, value} ->
          # Cache locally for future use
          case cache_type do
            :type -> TypeCache.put(key, value)
            :file -> FileCache.put(key, value)
          end
          {:halt, {:ok, value}}

        :not_found ->
          {:cont, :not_found}
      end
    end)
  end

  defp broadcast_cache_update(cache_type, action, key, value) do
    # Broadcast to local PubSub
    Phoenix.PubSub.broadcast(
      TscPhoenix.PubSub,
      "cache:updates",
      {:cache_update, cache_type, action, key, value}
    )

    # Send to all connected nodes
    for remote_node <- Node.list() do
      GenServer.cast({__MODULE__, remote_node}, {:cache_update, cache_type, action, key, value})
    end
  end

  defp do_warm_from_node(source_node) do
    Logger.info("Warming cache from node #{source_node}")

    type_result = warm_cache_type(source_node, :type)
    file_result = warm_cache_type(source_node, :file)

    {:ok, %{
      type_entries: type_result,
      file_entries: file_result
    }}
  end

  defp warm_cache_type(source_node, cache_type) do
    warm_cache_batch(source_node, cache_type, 0, 0)
  end

  defp warm_cache_batch(source_node, cache_type, offset, total_synced) do
    # Get keys from source
    keys = try do
      GenServer.call({__MODULE__, source_node}, {:get_cache_keys, cache_type, offset}, 10_000)
    catch
      _, _ -> []
    end

    if length(keys) == 0 do
      total_synced
    else
      # Get entries for those keys
      entries = try do
        GenServer.call({__MODULE__, source_node}, {:get_cache_entries, cache_type, keys}, 30_000)
      catch
        _, _ -> []
      end

      # Store locally
      Enum.each(entries, fn {key, value} ->
        case cache_type do
          :type -> TypeCache.put(key, value)
          :file -> FileCache.put(key, value)
        end
      end)

      synced = length(entries)

      if length(keys) < @sync_batch_size do
        total_synced + synced
      else
        warm_cache_batch(source_node, cache_type, offset + @sync_batch_size, total_synced + synced)
      end
    end
  end
end
