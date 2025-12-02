defmodule TSC.Watcher.FileWatcher do
  @moduledoc """
  File system watcher for incremental compilation.

  Watches directories for changes and triggers recompilation.
  Uses file_system library for cross-platform file watching.

  ## Options

  #{NimbleOptions.docs(TSC.Options.file_watcher_schema())}
  """

  use GenServer

  alias TSC.Coordinator
  alias TSC.Options

  require Logger

  defstruct [:watcher_pid, :dirs, :pending_changes, :debounce_ref, :watching, :debounce_ms, :extensions]

  # ============================================================================
  # Public API
  # ============================================================================

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Start watching directories for changes.
  """
  @spec watch(list(String.t())) :: :ok | {:error, term()}
  def watch(dirs) do
    GenServer.call(__MODULE__, {:watch, dirs})
  end

  @doc """
  Stop watching for changes.
  """
  @spec stop_watching() :: :ok
  def stop_watching do
    GenServer.call(__MODULE__, :stop_watching)
  end

  @doc """
  Check if currently watching.
  """
  @spec watching?() :: boolean()
  def watching? do
    GenServer.call(__MODULE__, :watching?)
  end

  @doc """
  Get currently watched directories.
  """
  @spec watched_dirs() :: list(String.t())
  def watched_dirs do
    GenServer.call(__MODULE__, :watched_dirs)
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(opts) do
    {:ok, validated} = Options.validate_file_watcher(opts)

    state = %__MODULE__{
      watcher_pid: nil,
      dirs: Keyword.fetch!(validated, :dirs),
      pending_changes: MapSet.new(),
      debounce_ref: nil,
      watching: false,
      debounce_ms: Keyword.fetch!(validated, :debounce_ms),
      extensions: Keyword.fetch!(validated, :extensions)
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:watch, dirs}, _from, state) do
    expanded_dirs = Enum.map(dirs, &Path.expand/1)

    case start_watcher(expanded_dirs) do
      {:ok, pid} ->
        new_state = %{state |
          watcher_pid: pid,
          dirs: expanded_dirs,
          watching: true
        }
        Logger.info("Started watching: #{inspect(expanded_dirs)}")
        {:reply, :ok, new_state}

      {:error, reason} = error ->
        Logger.error("Failed to start file watcher: #{inspect(reason)}")
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:stop_watching, _from, state) do
    new_state = stop_watcher(state)
    Logger.info("Stopped watching for file changes")
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:watching?, _from, state) do
    {:reply, state.watching, state}
  end

  @impl true
  def handle_call(:watched_dirs, _from, state) do
    {:reply, state.dirs, state}
  end

  @impl true
  def handle_info({:file_event, _watcher_pid, {path, events}}, state) do
    if should_process?(path, events, state.extensions) do
      # Add to pending changes
      new_pending = MapSet.put(state.pending_changes, path)

      # Cancel existing debounce timer
      if state.debounce_ref do
        Process.cancel_timer(state.debounce_ref)
      end

      # Set new debounce timer using configured debounce_ms
      ref = Process.send_after(self(), :process_changes, state.debounce_ms)

      {:noreply, %{state | pending_changes: new_pending, debounce_ref: ref}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:file_event, _watcher_pid, :stop}, state) do
    Logger.warning("File watcher stopped unexpectedly")
    {:noreply, %{state | watching: false}}
  end

  @impl true
  def handle_info(:process_changes, state) do
    changed_files = MapSet.to_list(state.pending_changes)

    if length(changed_files) > 0 do
      Logger.info("Processing #{length(changed_files)} file changes...")

      # Broadcast change event
      Phoenix.PubSub.broadcast(
        TscPhoenix.PubSub,
        "compiler:updates",
        {:files_changed, changed_files}
      )

      # Trigger incremental compilation
      Task.start(fn ->
        result = Coordinator.check_project(changed_files, incremental: true)

        Phoenix.PubSub.broadcast(
          TscPhoenix.PubSub,
          "compiler:updates",
          {:incremental_check_complete, result}
        )
      end)
    end

    {:noreply, %{state | pending_changes: MapSet.new(), debounce_ref: nil}}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    stop_watcher(state)
    :ok
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp start_watcher(dirs) do
    case FileSystem.start_link(dirs: dirs, latency: 0) do
      {:ok, pid} ->
        FileSystem.subscribe(pid)
        {:ok, pid}

      error ->
        error
    end
  end

  defp stop_watcher(state) do
    if state.watcher_pid do
      GenServer.stop(state.watcher_pid)
    end

    if state.debounce_ref do
      Process.cancel_timer(state.debounce_ref)
    end

    %{state |
      watcher_pid: nil,
      watching: false,
      pending_changes: MapSet.new(),
      debounce_ref: nil
    }
  end

  defp should_process?(path, events, extensions) do
    # Only process files with configured extensions
    has_extension? = Enum.any?(extensions, fn ext ->
      String.ends_with?(path, ext)
    end)

    # Only process modifications and creations
    relevant_event? = Enum.any?(events, fn event ->
      event in [:modified, :created, :renamed]
    end)

    has_extension? and relevant_event?
  end
end
