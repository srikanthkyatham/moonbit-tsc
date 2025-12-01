defmodule MoonbitTsc.Watcher do
  @moduledoc """
  File watcher for incremental compilation.

  Watches TypeScript files for changes and triggers recompilation.
  """

  use GenServer

  require Logger

  @poll_interval 500

  # ============================================================================
  # Public API
  # ============================================================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Start watching patterns for changes.
  """
  @spec start_watching([String.t()], keyword()) :: {:ok, pid()} | {:error, term()}
  def start_watching(patterns, opts \\ []) do
    start_link(patterns: patterns, compile_opts: opts)
  end

  @doc """
  Stop watching.
  """
  @spec stop(pid()) :: :ok
  def stop(pid) do
    GenServer.stop(pid)
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(opts) do
    patterns = Keyword.get(opts, :patterns, [])
    compile_opts = Keyword.get(opts, :compile_opts, [])

    # Get initial file states
    files = expand_patterns(patterns)
    file_states = get_file_states(files)

    state = %{
      patterns: patterns,
      compile_opts: compile_opts,
      file_states: file_states,
      last_compile: nil
    }

    # Schedule first poll
    schedule_poll()

    # Do initial compile
    do_compile(files, compile_opts)

    {:ok, state}
  end

  @impl true
  def handle_info(:poll, state) do
    files = expand_patterns(state.patterns)
    new_states = get_file_states(files)

    # Find changed files
    changed = find_changed_files(state.file_states, new_states)

    new_state = if length(changed) > 0 do
      Logger.info("Detected changes in #{length(changed)} file(s)")
      Enum.each(changed, fn file ->
        Logger.debug("  Changed: #{file}")
      end)

      # Recompile changed files
      do_compile(changed, state.compile_opts)

      %{state |
        file_states: new_states,
        last_compile: System.system_time(:second)
      }
    else
      %{state | file_states: new_states}
    end

    schedule_poll()
    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp schedule_poll do
    Process.send_after(self(), :poll, @poll_interval)
  end

  defp expand_patterns(patterns) do
    patterns
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.filter(&String.ends_with?(&1, [".ts", ".tsx"]))
    |> Enum.uniq()
  end

  defp get_file_states(files) do
    files
    |> Enum.map(fn file ->
      case File.stat(file) do
        {:ok, stat} -> {file, stat.mtime}
        {:error, _} -> {file, nil}
      end
    end)
    |> Map.new()
  end

  defp find_changed_files(old_states, new_states) do
    # Find new or modified files
    changed = Enum.filter(new_states, fn {file, mtime} ->
      case Map.get(old_states, file) do
        nil -> true  # New file
        old_mtime -> old_mtime != mtime  # Modified
      end
    end)
    |> Enum.map(fn {file, _} -> file end)

    changed
  end

  defp do_compile(files, opts) do
    if length(files) > 0 do
      Logger.info("Compiling #{length(files)} file(s)...")

      case MoonbitTsc.Compiler.compile(files, opts) do
        {:ok, _result} ->
          Logger.info("Compilation successful")

        {:error, %{errors: errors}} when is_list(errors) ->
          Logger.error("Compilation failed with #{length(errors)} error(s)")
          Enum.each(errors, fn error ->
            Logger.error("  #{format_error(error)}")
          end)

        {:error, reason} ->
          Logger.error("Compilation failed: #{inspect(reason)}")
      end
    end
  end

  defp format_error(%{file: file, line: line, column: col, message: msg}) do
    "#{file}(#{line},#{col}): #{msg}"
  end

  defp format_error(error) do
    inspect(error)
  end
end
