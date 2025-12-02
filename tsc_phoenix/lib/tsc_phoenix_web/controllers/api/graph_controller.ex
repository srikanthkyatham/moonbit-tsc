defmodule TscPhoenixWeb.API.GraphController do
  @moduledoc """
  REST API controller for dependency graph operations.

  Provides endpoints for building and querying the TypeScript dependency graph.
  """

  use TscPhoenixWeb, :controller

  alias TSC.Graph.DependencyGraph
  alias TSC.Parser.ImportExtractor
  alias TSC.Project.TsConfig

  @doc """
  POST /api/graph/build
  Body: { "project": "./path" } or { "files": ["src/a.ts", "src/b.ts"] }

  Builds the dependency graph from TypeScript files.

  Response: {
    "success": true,
    "stats": { "files": 10, "edges": 25, "avg_deps": 2.5 },
    "build_time_ms": 123
  }
  """
  def build(conn, params) do
    start_time = System.monotonic_time(:millisecond)

    files = discover_files(params)

    # Clear existing graph and build new one
    DependencyGraph.clear()

    # Build graph by extracting imports from each file
    Enum.each(files, fn file ->
      case ImportExtractor.extract(file) do
        {:ok, imports} ->
          # Resolve imports to absolute paths, filtering out external modules
          dependencies =
            imports
            |> Enum.map(fn imp -> ImportExtractor.resolve(file, imp.specifier) end)
            |> Enum.reject(&is_nil/1)

          DependencyGraph.add(file, dependencies)

        {:error, _reason} ->
          # File couldn't be read, add with no dependencies
          DependencyGraph.add(file, [])
      end
    end)

    elapsed = System.monotonic_time(:millisecond) - start_time
    stats = DependencyGraph.stats()

    json(conn, %{
      success: true,
      stats: stats,
      build_time_ms: elapsed
    })
  end

  @doc """
  GET /api/graph
  Query params: ?project=./path (optional)

  Returns the full dependency graph.

  Response: {
    "nodes": [{ "id": "src/a.ts", "label": "a.ts" }],
    "edges": [{ "source": "src/a.ts", "target": "src/b.ts" }],
    "stats": { "files": 10, "edges": 25, "avg_deps": 2.5 }
  }
  """
  def index(conn, params) do
    # Optionally rebuild if project specified
    if params["project"] || params["files"] do
      build_graph_from_params(params)
    end

    files = DependencyGraph.all_files()

    nodes =
      files
      |> Enum.map(fn file ->
        deps = DependencyGraph.get_dependencies(file)
        dependents = DependencyGraph.get_dependents(file)

        %{
          id: file,
          label: Path.basename(file),
          directory: Path.dirname(file),
          dependencies_count: length(deps),
          dependents_count: length(dependents)
        }
      end)

    edges =
      files
      |> Enum.flat_map(fn file ->
        DependencyGraph.get_dependencies(file)
        |> Enum.map(fn dep ->
          %{source: file, target: dep}
        end)
      end)

    stats = DependencyGraph.stats()

    json(conn, %{
      nodes: nodes,
      edges: edges,
      stats: stats
    })
  end

  @doc """
  GET /api/graph/file/:path
  Returns dependencies and dependents for a specific file.

  Response: {
    "file": "src/a.ts",
    "dependencies": ["src/b.ts", "src/c.ts"],
    "dependents": ["src/main.ts"],
    "transitive_affected": ["src/main.ts", "src/app.ts"]
  }
  """
  def file(conn, %{"path" => path}) do
    # URL decode the path
    file = URI.decode(path)

    dependencies = DependencyGraph.get_dependencies(file)
    dependents = DependencyGraph.get_dependents(file)
    affected = DependencyGraph.get_affected_files([file])

    json(conn, %{
      file: file,
      dependencies: dependencies,
      dependents: dependents,
      transitive_affected: affected
    })
  end

  @doc """
  GET /api/graph/levels
  Query params: ?files=src/a.ts,src/b.ts (optional, defaults to all)

  Returns topological levels for parallel compilation.

  Response: {
    "levels": [
      ["src/utils.ts", "src/types.ts"],
      ["src/core.ts"],
      ["src/main.ts"]
    ],
    "total_levels": 3
  }
  """
  def levels(conn, params) do
    files =
      case params["files"] do
        nil -> DependencyGraph.all_files()
        files_str -> String.split(files_str, ",") |> Enum.map(&String.trim/1)
      end

    levels = DependencyGraph.topological_levels(files)

    json(conn, %{
      levels: levels,
      total_levels: length(levels)
    })
  end

  @doc """
  GET /api/graph/affected
  Query params: ?files=src/a.ts,src/b.ts

  Returns files affected by changes to the specified files.

  Response: {
    "changed": ["src/a.ts"],
    "affected": ["src/main.ts", "src/app.ts"],
    "total_affected": 2
  }
  """
  def affected(conn, %{"files" => files_str}) do
    changed = String.split(files_str, ",") |> Enum.map(&String.trim/1)
    affected = DependencyGraph.get_affected_files(changed)

    json(conn, %{
      changed: changed,
      affected: affected,
      total_affected: length(affected)
    })
  end

  def affected(conn, _params) do
    conn
    |> put_status(400)
    |> json(%{error: "Missing 'files' query parameter"})
  end

  @doc """
  GET /api/graph/stats
  Returns graph statistics.

  Response: {
    "files": 10,
    "edges": 25,
    "avg_deps": 2.5,
    "most_imported": [{ "file": "src/types.ts", "count": 8 }],
    "most_dependencies": [{ "file": "src/main.ts", "count": 5 }]
  }
  """
  def stats(conn, _params) do
    base_stats = DependencyGraph.stats()
    files = DependencyGraph.all_files()

    # Find most imported files (highest number of dependents)
    most_imported =
      files
      |> Enum.map(fn file ->
        count = DependencyGraph.get_dependents(file) |> length()
        %{file: file, count: count}
      end)
      |> Enum.sort_by(& &1.count, :desc)
      |> Enum.take(10)

    # Find files with most dependencies
    most_dependencies =
      files
      |> Enum.map(fn file ->
        count = DependencyGraph.get_dependencies(file) |> length()
        %{file: file, count: count}
      end)
      |> Enum.sort_by(& &1.count, :desc)
      |> Enum.take(10)

    json(conn, Map.merge(base_stats, %{
      most_imported: most_imported,
      most_dependencies: most_dependencies
    }))
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp discover_files(params) do
    files = params["files"]

    cond do
      is_list(files) and length(files) > 0 ->
        files

      is_binary(params["project"]) ->
        discover_project_files(params["project"])

      is_binary(params["tsconfig"]) ->
        discover_files_from_tsconfig(params["tsconfig"])

      true ->
        discover_project_files("./")
    end
  end

  defp discover_project_files(project_path) when is_binary(project_path) do
    Path.wildcard(Path.join(project_path, "**/*.{ts,tsx}"))
    |> Enum.reject(&String.contains?(&1, "node_modules"))
  end

  defp discover_project_files(_), do: discover_project_files("./")

  defp discover_files_from_tsconfig(tsconfig_path) when is_binary(tsconfig_path) do
    case TsConfig.load(tsconfig_path) do
      {:ok, config} ->
        TsConfig.get_files(config)

      {:error, _reason} ->
        if File.dir?(tsconfig_path) do
          discover_project_files(tsconfig_path)
        else
          discover_project_files(Path.dirname(tsconfig_path))
        end
    end
  end

  defp discover_files_from_tsconfig(_), do: discover_project_files("./")

  defp build_graph_from_params(params) do
    files = discover_files(params)

    DependencyGraph.clear()

    Enum.each(files, fn file ->
      case ImportExtractor.extract(file) do
        {:ok, imports} ->
          dependencies =
            imports
            |> Enum.map(fn imp -> ImportExtractor.resolve(file, imp.specifier) end)
            |> Enum.reject(&is_nil/1)

          DependencyGraph.add(file, dependencies)

        {:error, _reason} ->
          DependencyGraph.add(file, [])
      end
    end)
  end
end
