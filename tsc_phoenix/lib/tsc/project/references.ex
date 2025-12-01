defmodule TSC.Project.References do
  @moduledoc """
  Handles TypeScript project references for composite builds.

  Project references allow TypeScript projects to depend on other projects,
  enabling incremental builds and proper build ordering.

  ## Example tsconfig.json with references

  ```json
  {
    "compilerOptions": {
      "composite": true,
      "declaration": true
    },
    "references": [
      { "path": "../core" },
      { "path": "../utils" }
    ]
  }
  ```
  """

  require Logger

  @type project_ref :: %{
          path: String.t(),
          prepend: boolean(),
          circular: boolean()
        }

  @type project_info :: %{
          path: String.t(),
          tsconfig_path: String.t(),
          config: map(),
          references: [project_ref()],
          is_composite: boolean()
        }

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Parse project references from a tsconfig.json file.

  Returns a list of project reference paths resolved relative to the tsconfig.
  """
  @spec parse_references(String.t()) :: {:ok, [project_ref()]} | {:error, term()}
  def parse_references(tsconfig_path) do
    with {:ok, content} <- File.read(tsconfig_path),
         {:ok, config} <- Jason.decode(content) do
      references = config["references"] || []
      project_dir = Path.dirname(tsconfig_path)

      parsed =
        references
        |> Enum.map(fn ref ->
          path = resolve_reference_path(project_dir, ref["path"])

          %{
            path: path,
            prepend: Map.get(ref, "prepend", false),
            circular: Map.get(ref, "circular", false)
          }
        end)

      {:ok, parsed}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Load full project information including references.
  """
  @spec load_project(String.t()) :: {:ok, project_info()} | {:error, term()}
  def load_project(tsconfig_path) do
    with {:ok, content} <- File.read(tsconfig_path),
         {:ok, config} <- Jason.decode(content),
         {:ok, references} <- parse_references(tsconfig_path) do
      compiler_opts = config["compilerOptions"] || %{}

      info = %{
        path: Path.dirname(tsconfig_path),
        tsconfig_path: Path.expand(tsconfig_path),
        config: config,
        references: references,
        is_composite: Map.get(compiler_opts, "composite", false)
      }

      {:ok, info}
    end
  end

  @doc """
  Build a dependency graph of all projects starting from a root tsconfig.

  Returns a map of project paths to their project info.
  """
  @spec build_project_graph(String.t()) :: {:ok, %{String.t() => project_info()}} | {:error, term()}
  def build_project_graph(root_tsconfig) do
    case load_project(root_tsconfig) do
      {:ok, root_info} ->
        graph = collect_projects(%{root_info.path => root_info}, root_info.references)
        {:ok, graph}

      error ->
        error
    end
  end

  @doc """
  Get the build order for projects (topological sort).

  Projects are returned in order such that dependencies are built before
  dependents.
  """
  @spec build_order(String.t()) :: {:ok, [String.t()]} | {:error, :circular_dependency}
  def build_order(root_tsconfig) do
    with {:ok, graph} <- build_project_graph(root_tsconfig) do
      case topological_sort(graph) do
        {:ok, order} -> {:ok, order}
        :circular -> {:error, :circular_dependency}
      end
    end
  end

  @doc """
  Get the build order as project info structs.
  """
  @spec build_order_with_info(String.t()) :: {:ok, [project_info()]} | {:error, term()}
  def build_order_with_info(root_tsconfig) do
    with {:ok, graph} <- build_project_graph(root_tsconfig),
         {:ok, order} <- build_order(root_tsconfig) do
      projects = Enum.map(order, &Map.get(graph, &1))
      {:ok, projects}
    end
  end

  @doc """
  Check if a project has project references.
  """
  @spec has_references?(String.t()) :: boolean()
  def has_references?(tsconfig_path) do
    case parse_references(tsconfig_path) do
      {:ok, refs} -> length(refs) > 0
      _ -> false
    end
  end

  @doc """
  Get files to compile for a project, respecting outDir and rootDir.
  """
  @spec get_project_files(project_info()) :: [String.t()]
  def get_project_files(%{config: config, path: project_path}) do
    include_patterns = config["include"] || ["**/*.ts", "**/*.tsx"]
    exclude_patterns = config["exclude"] || ["node_modules", "dist"]

    # Include patterns are relative to the project root, not rootDir
    include_patterns
    |> Enum.flat_map(fn pattern ->
      Path.wildcard(Path.join(project_path, pattern))
    end)
    |> Enum.reject(fn file ->
      rel_path = Path.relative_to(file, project_path)

      Enum.any?(exclude_patterns, fn pattern ->
        String.starts_with?(rel_path, pattern) or
          String.contains?(rel_path, "/#{pattern}/")
      end)
    end)
    |> Enum.uniq()
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp resolve_reference_path(project_dir, ref_path) do
    full_path = Path.join(project_dir, ref_path)

    # Check if it's a directory (look for tsconfig.json)
    tsconfig_path =
      if File.dir?(full_path) do
        Path.join(full_path, "tsconfig.json")
      else
        full_path
      end

    Path.expand(Path.dirname(tsconfig_path))
  end

  defp collect_projects(graph, []), do: graph

  defp collect_projects(graph, [ref | rest]) do
    if Map.has_key?(graph, ref.path) do
      # Already visited
      collect_projects(graph, rest)
    else
      tsconfig_path = Path.join(ref.path, "tsconfig.json")

      case load_project(tsconfig_path) do
        {:ok, info} ->
          updated_graph = Map.put(graph, ref.path, info)
          # Add this project's references to the queue
          collect_projects(updated_graph, rest ++ info.references)

        {:error, reason} ->
          Logger.warning("Failed to load referenced project #{ref.path}: #{inspect(reason)}")
          collect_projects(graph, rest)
      end
    end
  end

  defp topological_sort(graph) do
    # Build adjacency list (project -> its dependencies)
    # A project's references are projects it depends ON
    deps_map =
      graph
      |> Enum.map(fn {path, info} ->
        dep_paths = Enum.map(info.references, & &1.path)
        {path, dep_paths}
      end)
      |> Map.new()

    all_nodes = Map.keys(graph)

    # Use simple DFS-based topological sort
    # Start from nodes with no dependencies
    visited = MapSet.new()
    result = []

    {final_visited, final_result} =
      Enum.reduce(all_nodes, {visited, result}, fn node, {vis, res} ->
        if MapSet.member?(vis, node) do
          {vis, res}
        else
          visit_node(node, deps_map, vis, res)
        end
      end)

    if MapSet.size(final_visited) == length(all_nodes) do
      {:ok, final_result}
    else
      :circular
    end
  end

  defp visit_node(node, deps_map, visited, result) do
    if MapSet.member?(visited, node) do
      {visited, result}
    else
      # Mark as visited
      visited = MapSet.put(visited, node)

      # First visit all dependencies
      deps = Map.get(deps_map, node, [])

      {visited, result} =
        Enum.reduce(deps, {visited, result}, fn dep, {vis, res} ->
          if Map.has_key?(deps_map, dep) and not MapSet.member?(vis, dep) do
            visit_node(dep, deps_map, vis, res)
          else
            {vis, res}
          end
        end)

      # Add this node after its dependencies
      {visited, result ++ [node]}
    end
  end
end
