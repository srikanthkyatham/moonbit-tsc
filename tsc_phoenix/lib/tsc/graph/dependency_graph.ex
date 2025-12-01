defmodule TSC.Graph.DependencyGraph do
  @moduledoc """
  ETS-based dependency graph for TypeScript files.

  Tracks import relationships and computes topological order for type checking.
  """

  @table :tsc_dependency_graph
  @reverse_table :tsc_reverse_deps

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Initialize the dependency graph ETS tables.
  """
  @spec init() :: :ok
  def init do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    end

    if :ets.whereis(@reverse_table) == :undefined do
      :ets.new(@reverse_table, [:named_table, :public, :bag, read_concurrency: true])
    end

    :ok
  end

  @doc """
  Add a file and its dependencies to the graph.
  """
  @spec add(String.t(), list(String.t())) :: :ok
  def add(file, dependencies) do
    # Store forward dependencies (file -> [deps])
    :ets.insert(@table, {file, dependencies})

    # Store reverse dependencies (dep -> file)
    Enum.each(dependencies, fn dep ->
      :ets.insert(@reverse_table, {dep, file})
    end)

    :ok
  end

  @doc """
  Get dependencies of a file.
  """
  @spec get_dependencies(String.t()) :: list(String.t())
  def get_dependencies(file) do
    case :ets.lookup(@table, file) do
      [{^file, deps}] -> deps
      [] -> []
    end
  end

  @doc """
  Get files that depend on the given file.
  """
  @spec get_dependents(String.t()) :: list(String.t())
  def get_dependents(file) do
    :ets.lookup(@reverse_table, file)
    |> Enum.map(fn {_dep, dependent} -> dependent end)
  end

  @doc """
  Remove a file from the graph.
  """
  @spec remove(String.t()) :: :ok
  def remove(file) do
    # Remove from forward deps
    deps = get_dependencies(file)
    :ets.delete(@table, file)

    # Remove from reverse deps
    Enum.each(deps, fn dep ->
      :ets.match_delete(@reverse_table, {dep, file})
    end)

    :ok
  end

  @doc """
  Clear the entire graph.
  """
  @spec clear() :: :ok
  def clear do
    :ets.delete_all_objects(@table)
    :ets.delete_all_objects(@reverse_table)
    :ok
  end

  @doc """
  Get all files in the graph.
  """
  @spec all_files() :: list(String.t())
  def all_files do
    :ets.select(@table, [{{:"$1", :_}, [], [:"$1"]}])
  end

  @doc """
  Compute topological levels for parallel type checking.

  Returns a list of levels, where each level contains files that can be
  checked in parallel (all their dependencies are in earlier levels).
  """
  @spec topological_levels(list(String.t())) :: list(list(String.t()))
  def topological_levels(files) do
    # Build adjacency map from the files we're interested in
    file_set = MapSet.new(files)

    deps_map = files
    |> Enum.map(fn file ->
      deps = get_dependencies(file) |> Enum.filter(&MapSet.member?(file_set, &1))
      {file, deps}
    end)
    |> Map.new()

    compute_levels(deps_map, [])
  end

  @doc """
  Get files affected by changes to the given files.
  Returns all transitive dependents.
  """
  @spec get_affected_files(list(String.t())) :: list(String.t())
  def get_affected_files(changed_files) do
    changed_files
    |> Enum.flat_map(&get_transitive_dependents/1)
    |> Enum.uniq()
    |> Kernel.--(changed_files)
  end

  @doc """
  Get statistics about the graph.
  """
  @spec stats() :: map()
  def stats do
    files = all_files()
    total_edges = files
    |> Enum.map(&(get_dependencies(&1) |> length()))
    |> Enum.sum()

    %{
      files: length(files),
      edges: total_edges,
      avg_deps: if(length(files) > 0, do: Float.round(total_edges / length(files), 2), else: 0.0)
    }
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp compute_levels(deps_map, acc) when map_size(deps_map) == 0 do
    Enum.reverse(acc)
  end

  defp compute_levels(deps_map, acc) do
    # Find files with no remaining dependencies (roots at this level)
    {level, remaining} = deps_map
    |> Enum.split_with(fn {_file, deps} -> deps == [] end)

    case level do
      [] ->
        # Cycle detected, just return remaining files as a single level
        remaining_files = Map.keys(deps_map)
        Enum.reverse([remaining_files | acc])

      _ ->
        level_files = Enum.map(level, fn {file, _} -> file end)
        level_set = MapSet.new(level_files)

        # Remove processed files from remaining dependencies
        new_deps_map = remaining
        |> Enum.map(fn {file, deps} ->
          {file, Enum.reject(deps, &MapSet.member?(level_set, &1))}
        end)
        |> Map.new()

        compute_levels(new_deps_map, [level_files | acc])
    end
  end

  defp get_transitive_dependents(file, visited \\ MapSet.new()) do
    if MapSet.member?(visited, file) do
      []
    else
      direct = get_dependents(file)
      new_visited = MapSet.put(visited, file)

      transitive = direct
      |> Enum.flat_map(&get_transitive_dependents(&1, new_visited))

      [file | direct ++ transitive]
      |> Enum.uniq()
    end
  end
end
