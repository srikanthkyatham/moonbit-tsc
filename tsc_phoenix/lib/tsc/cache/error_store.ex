defmodule TSC.Cache.ErrorStore do
  @moduledoc """
  ETS-based store for compilation errors per project.

  Stores diagnostics keyed by project path for persistent access
  across dashboard views and API calls.
  """

  use GenServer

  require Logger

  @table :tsc_error_store

  # ============================================================================
  # Public API
  # ============================================================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Store errors for a project.
  Replaces any existing errors for the project.
  """
  @spec put(String.t(), list(map())) :: :ok
  def put(project_path, diagnostics) when is_list(diagnostics) do
    timestamp = System.system_time(:millisecond)
    normalized_path = normalize_path(project_path)
    :ets.insert(@table, {normalized_path, diagnostics, timestamp})
    :ok
  end

  @doc """
  Get errors for a project.
  Returns {:ok, diagnostics} or :not_found.
  """
  @spec get(String.t()) :: {:ok, list(map()), integer()} | :not_found
  def get(project_path) do
    normalized_path = normalize_path(project_path)
    case :ets.lookup(@table, normalized_path) do
      [{^normalized_path, diagnostics, timestamp}] -> {:ok, diagnostics, timestamp}
      [] -> :not_found
    end
  end

  @doc """
  Get all stored projects with their error counts.
  """
  @spec list_projects() :: list(map())
  def list_projects do
    :ets.tab2list(@table)
    |> Enum.map(fn {path, diagnostics, timestamp} ->
      errors = Enum.count(diagnostics, &(&1[:category] == :error))
      warnings = Enum.count(diagnostics, &(&1[:category] == :warning))

      %{
        project: path,
        total: length(diagnostics),
        errors: errors,
        warnings: warnings,
        timestamp: timestamp,
        last_checked: format_timestamp(timestamp)
      }
    end)
    |> Enum.sort_by(& &1.timestamp, :desc)
  end

  @doc """
  Get the most recent project's errors.
  """
  @spec get_latest() :: {:ok, String.t(), list(map()), integer()} | :not_found
  def get_latest do
    case list_projects() do
      [%{project: path} | _] ->
        {:ok, diagnostics, timestamp} = get(path)
        {:ok, path, diagnostics, timestamp}
      [] ->
        :not_found
    end
  end

  @doc """
  Delete errors for a project.
  """
  @spec delete(String.t()) :: :ok
  def delete(project_path) do
    normalized_path = normalize_path(project_path)
    :ets.delete(@table, normalized_path)
    :ok
  end

  @doc """
  Clear all stored errors.
  """
  @spec clear() :: :ok
  def clear do
    :ets.delete_all_objects(@table)
    :ok
  end

  @doc """
  Get store statistics.
  """
  @spec stats() :: map()
  def stats do
    info = :ets.info(@table)
    projects = list_projects()

    total_errors = Enum.sum(Enum.map(projects, & &1.errors))
    total_warnings = Enum.sum(Enum.map(projects, & &1.warnings))

    %{
      projects: length(projects),
      total_diagnostics: Enum.sum(Enum.map(projects, & &1.total)),
      total_errors: total_errors,
      total_warnings: total_warnings,
      memory_bytes: info[:memory] * :erlang.system_info(:wordsize),
      memory_mb: Float.round(info[:memory] * :erlang.system_info(:wordsize) / 1_048_576, 2)
    }
  end

  @doc """
  Add errors from files to the store, using the common root as project path.
  """
  @spec put_from_files(list(String.t()), list(map())) :: :ok
  def put_from_files(files, diagnostics) when is_list(files) and is_list(diagnostics) do
    project_path = find_common_root(files)
    put(project_path, diagnostics)
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(_opts) do
    table = :ets.new(@table, [
      :named_table,
      :public,
      :set,
      read_concurrency: true,
      write_concurrency: true
    ])

    {:ok, %{table: table}}
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp normalize_path(path) when is_binary(path) do
    path
    |> Path.expand()
    |> String.trim_trailing("/")
  end

  defp normalize_path(nil), do: "default"
  defp normalize_path(path), do: to_string(path)

  defp find_common_root([]), do: "."
  defp find_common_root([file]), do: Path.dirname(file)
  defp find_common_root(files) do
    files
    |> Enum.map(&Path.dirname/1)
    |> Enum.map(&Path.split/1)
    |> find_common_prefix()
    |> Path.join()
    |> case do
      "" -> "."
      path -> path
    end
  end

  defp find_common_prefix([]), do: []
  defp find_common_prefix([first | rest]) do
    Enum.reduce(rest, first, fn path, acc ->
      common_prefix(acc, path)
    end)
  end

  defp common_prefix(a, b) do
    Enum.zip(a, b)
    |> Enum.take_while(fn {x, y} -> x == y end)
    |> Enum.map(&elem(&1, 0))
  end

  defp format_timestamp(timestamp) do
    DateTime.from_unix!(div(timestamp, 1000))
    |> Calendar.strftime("%Y-%m-%d %H:%M:%S")
  end
end
