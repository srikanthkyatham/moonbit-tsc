defmodule TSC.Cache.TypeCache do
  @moduledoc """
  ETS-based cache for TypeScript type exports with disk persistence.

  Stores exported types for each module to enable cross-file type checking.
  Uses ETS for fast, concurrent reads without process bottlenecks.
  Supports persisting to disk for faster startup on subsequent runs.
  """

  use GenServer

  require Logger

  alias TSC.Options

  @table :tsc_type_cache
  @default_cache_dir ".tsc_cache"
  @cache_file "type_cache.etf"
  @tsconfig_hash_file "tsconfig_hash.txt"

  # ============================================================================
  # Public API
  # ============================================================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
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
  Get cached keys with pagination.
  """
  @spec keys(non_neg_integer(), non_neg_integer()) :: [String.t()]
  def keys(offset, limit) do
    keys()
    |> Enum.drop(offset)
    |> Enum.take(limit)
  end

  @doc """
  Invalidate a specific cache entry.
  """
  @spec invalidate(String.t()) :: :ok
  def invalidate(key) do
    :ets.delete(@table, key)
    :ok
  end

  @doc """
  Invalidate entries matching a pattern.
  """
  @spec invalidate_pattern(String.t()) :: non_neg_integer()
  def invalidate_pattern(pattern) do
    regex = Regex.compile!(pattern)

    keys()
    |> Enum.filter(&Regex.match?(regex, &1))
    |> Enum.each(&:ets.delete(@table, &1))
    |> length()
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

  @doc """
  Save cache to disk.
  """
  @spec save_to_disk(keyword()) :: :ok | {:error, term()}
  def save_to_disk(opts \\ []) do
    GenServer.call(__MODULE__, {:save_to_disk, opts})
  end

  @doc """
  Load cache from disk.
  """
  @spec load_from_disk(keyword()) :: :ok | {:error, term()}
  def load_from_disk(opts \\ []) do
    GenServer.call(__MODULE__, {:load_from_disk, opts})
  end

  @doc """
  Invalidate cache if tsconfig has changed.
  Returns :invalidated if cache was cleared, :unchanged if not.
  """
  @spec invalidate_on_tsconfig_change(String.t(), keyword()) :: :invalidated | :unchanged
  def invalidate_on_tsconfig_change(tsconfig_path, opts \\ []) do
    GenServer.call(__MODULE__, {:check_tsconfig, tsconfig_path, opts})
  end

  @doc """
  Warm the cache by loading from disk if configured.
  """
  @spec warm_cache(keyword()) :: :ok | {:error, term()}
  def warm_cache(opts \\ []) do
    GenServer.call(__MODULE__, {:warm_cache, opts})
  end

  @doc """
  Prune expired entries based on TTL.
  """
  @spec prune_expired(pos_integer()) :: non_neg_integer()
  def prune_expired(ttl_hours \\ 24) do
    GenServer.call(__MODULE__, {:prune_expired, ttl_hours})
  end

  @doc """
  Get the cache directory path.
  """
  @spec cache_dir(keyword()) :: String.t()
  def cache_dir(opts \\ []) do
    opts = validated_opts(opts)
    Keyword.get(opts, :cache_dir) || @default_cache_dir
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(opts) do
    table = :ets.new(@table, [
      :named_table,
      :public,
      :set,
      read_concurrency: true,
      write_concurrency: true
    ])

    state = %{
      table: table,
      opts: validated_opts(opts)
    }

    # Warm cache on startup if configured
    if Keyword.get(state.opts, :warm_on_startup, true) do
      do_load_from_disk(state.opts)
    end

    {:ok, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    {:reply, stats(), state}
  end

  @impl true
  def handle_call({:save_to_disk, opts}, _from, state) do
    merged_opts = Keyword.merge(state.opts, validated_opts(opts))
    result = do_save_to_disk(merged_opts)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:load_from_disk, opts}, _from, state) do
    merged_opts = Keyword.merge(state.opts, validated_opts(opts))
    result = do_load_from_disk(merged_opts)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:check_tsconfig, tsconfig_path, opts}, _from, state) do
    merged_opts = Keyword.merge(state.opts, validated_opts(opts))
    result = do_check_tsconfig(tsconfig_path, merged_opts)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:warm_cache, opts}, _from, state) do
    merged_opts = Keyword.merge(state.opts, validated_opts(opts))

    result = if Keyword.get(merged_opts, :warm_on_startup, true) do
      do_load_from_disk(merged_opts)
    else
      :ok
    end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:prune_expired, ttl_hours}, _from, state) do
    count = do_prune_expired(ttl_hours)
    {:reply, count, state}
  end

  @impl true
  def terminate(_reason, state) do
    # Save to disk on shutdown if persistence is enabled
    if Keyword.get(state.opts, :persist_to_disk, true) do
      do_save_to_disk(state.opts)
    end

    :ok
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp validated_opts(opts) do
    case Options.validate_cache(opts) do
      {:ok, validated} -> validated
      {:error, _} -> []
    end
  end

  defp do_save_to_disk(opts) do
    if Keyword.get(opts, :persist_to_disk, true) do
      dir = Keyword.get(opts, :cache_dir) || @default_cache_dir
      File.mkdir_p!(dir)

      cache_path = Path.join(dir, @cache_file)

      # Get all entries from ETS
      entries = :ets.tab2list(@table)

      # Serialize to binary
      binary = :erlang.term_to_binary(entries, [:compressed])

      case File.write(cache_path, binary) do
        :ok ->
          Logger.debug("Saved #{length(entries)} cache entries to #{cache_path}")
          :ok

        {:error, reason} ->
          Logger.warning("Failed to save cache: #{inspect(reason)}")
          {:error, reason}
      end
    else
      :ok
    end
  end

  defp do_load_from_disk(opts) do
    if Keyword.get(opts, :persist_to_disk, true) do
      dir = Keyword.get(opts, :cache_dir) || @default_cache_dir
      cache_path = Path.join(dir, @cache_file)

      if File.exists?(cache_path) do
        case File.read(cache_path) do
          {:ok, binary} ->
            try do
              entries = :erlang.binary_to_term(binary)

              # Filter out expired entries
              ttl_hours = Keyword.get(opts, :ttl_hours, 24)
              cutoff = System.system_time(:millisecond) - (ttl_hours * 60 * 60 * 1000)

              valid_entries = Enum.filter(entries, fn {_path, _exports, timestamp} ->
                timestamp > cutoff
              end)

              # Insert into ETS
              :ets.insert(@table, valid_entries)

              Logger.info("Loaded #{length(valid_entries)} cache entries from disk (#{length(entries) - length(valid_entries)} expired)")
              :ok
            rescue
              e ->
                Logger.warning("Failed to parse cache file: #{inspect(e)}")
                {:error, :invalid_cache}
            end

          {:error, reason} ->
            Logger.debug("No cache file found: #{inspect(reason)}")
            {:error, reason}
        end
      else
        Logger.debug("No cache file exists at #{cache_path}")
        :ok
      end
    else
      :ok
    end
  end

  defp do_check_tsconfig(tsconfig_path, opts) do
    dir = Keyword.get(opts, :cache_dir) || @default_cache_dir
    hash_path = Path.join(dir, @tsconfig_hash_file)

    # Compute current hash
    current_hash = compute_tsconfig_hash(tsconfig_path)

    # Check stored hash
    stored_hash = case File.read(hash_path) do
      {:ok, content} -> String.trim(content)
      {:error, _} -> nil
    end

    if current_hash != stored_hash do
      # tsconfig changed, invalidate cache
      Logger.info("tsconfig.json changed, invalidating type cache")
      clear()

      # Store new hash
      File.mkdir_p!(dir)
      File.write!(hash_path, current_hash)

      :invalidated
    else
      :unchanged
    end
  end

  defp compute_tsconfig_hash(tsconfig_path) do
    case File.read(tsconfig_path) do
      {:ok, content} ->
        :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)

      {:error, _} ->
        "no_tsconfig"
    end
  end

  defp do_prune_expired(ttl_hours) do
    cutoff = System.system_time(:millisecond) - (ttl_hours * 60 * 60 * 1000)

    # Find expired entries
    expired = :ets.select(@table, [
      {{:"$1", :_, :"$2"}, [{:<, :"$2", cutoff}], [:"$1"]}
    ])

    # Delete them
    Enum.each(expired, &:ets.delete(@table, &1))

    length(expired)
  end
end
