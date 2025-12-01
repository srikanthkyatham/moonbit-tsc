defmodule TSC.Coordinator do
  @moduledoc """
  Main coordinator for TypeScript compilation.

  Orchestrates the compilation process:
  1. Discover and read files
  2. Extract imports and build dependency graph
  3. Type check files in topological order
  4. Collect and report diagnostics

  ## Options

  #{NimbleOptions.docs(TSC.Options.check_project_schema())}
  """

  alias TSC.Cache.{TypeCache, FileCache}
  alias TSC.Graph.DependencyGraph
  alias TSC.Worker.PoolSupervisor
  alias TSC.Telemetry.Metrics
  alias TSC.Options
  alias TSC.Project.References

  require Logger

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Check a TypeScript project.

  See module documentation for available options.
  """
  @spec check_project(list(String.t()), keyword()) :: map()
  def check_project(files, opts \\ []) do
    opts = Options.validate_check_project!(opts)
    incremental = Keyword.fetch!(opts, :incremental)
    concurrency = Keyword.fetch!(opts, :concurrency)

    start_time = System.monotonic_time(:millisecond)

    # Filter to changed files if incremental
    files_to_check = if incremental do
      filter_changed_files(files)
    else
      files
    end

    Metrics.emit_project_check_start(length(files_to_check))

    # Phase 1: Extract imports and build dependency graph
    Logger.info("Building dependency graph for #{length(files_to_check)} files...")
    build_dependency_graph(files_to_check, concurrency)

    # Phase 2: Get affected files if incremental
    all_affected = if incremental and length(files_to_check) < length(files) do
      affected = DependencyGraph.get_affected_files(files_to_check)
      Logger.info("#{length(affected)} additional files affected by changes")
      Enum.uniq(files_to_check ++ affected)
    else
      files_to_check
    end

    # Phase 3: Compute topological levels
    levels = DependencyGraph.topological_levels(all_affected)
    Logger.info("Type checking in #{length(levels)} levels...")

    # Phase 4: Type check level by level
    all_diagnostics = check_levels(levels, concurrency)

    duration = System.monotonic_time(:millisecond) - start_time

    result = %{
      success: Enum.all?(all_diagnostics, &(&1.category != :error)),
      diagnostics: all_diagnostics,
      stats: %{
        files_checked: length(all_affected),
        elapsed_ms: duration,
        levels: length(levels),
        errors: Enum.count(all_diagnostics, &(&1.category == :error)),
        warnings: Enum.count(all_diagnostics, &(&1.category == :warning))
      }
    }

    Metrics.emit_project_check_stop(
      length(all_affected),
      duration,
      if(result.success, do: :success, else: :errors)
    )

    result
  end

  @doc """
  Build a project with references (composite build).

  Builds all referenced projects in dependency order, then the root project.

  ## Options

  Same as `check_project/2`.
  """
  @spec build_with_references(String.t(), keyword()) :: map()
  def build_with_references(tsconfig_path, opts \\ []) do
    opts = Options.validate_check_project!(opts)
    start_time = System.monotonic_time(:millisecond)

    case References.build_order_with_info(tsconfig_path) do
      {:ok, projects} ->
        Logger.info("Building #{length(projects)} projects in dependency order")

        # Build each project in order
        results =
          projects
          |> Enum.with_index(1)
          |> Enum.map(fn {project, index} ->
            Logger.info("[#{index}/#{length(projects)}] Building #{project.path}")

            files = References.get_project_files(project)
            project_result = check_project(files, opts)

            %{
              project: project.path,
              result: project_result
            }
          end)

        duration = System.monotonic_time(:millisecond) - start_time

        # Aggregate results
        all_diagnostics = Enum.flat_map(results, fn r -> r.result.diagnostics end)
        total_files = Enum.sum(Enum.map(results, fn r -> r.result.stats.files_checked end))
        success = Enum.all?(results, fn r -> r.result.success end)

        %{
          success: success,
          diagnostics: all_diagnostics,
          projects: results,
          stats: %{
            projects_built: length(projects),
            total_files_checked: total_files,
            elapsed_ms: duration,
            errors: Enum.count(all_diagnostics, &(&1.category == :error)),
            warnings: Enum.count(all_diagnostics, &(&1.category == :warning))
          }
        }

      {:error, :circular_dependency} ->
        Logger.error("Circular dependency detected in project references")
        %{
          success: false,
          error: :circular_dependency,
          diagnostics: [],
          stats: %{elapsed_ms: System.monotonic_time(:millisecond) - start_time}
        }

      {:error, reason} ->
        Logger.error("Failed to build project graph: #{inspect(reason)}")
        %{
          success: false,
          error: reason,
          diagnostics: [],
          stats: %{elapsed_ms: System.monotonic_time(:millisecond) - start_time}
        }
    end
  end

  @doc """
  Check a single file.

  ## Options

  #{NimbleOptions.docs(TSC.Options.check_file_schema())}
  """
  @spec check_file(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def check_file(file, opts \\ []) do
    opts = Options.validate_check_file!(opts)
    start_time = System.monotonic_time(:millisecond)

    Metrics.emit_file_check_start(file)

    # Get imported types from cache (merge with any provided)
    imported_types = Map.merge(
      get_imported_types_for_file(file),
      Keyword.fetch!(opts, :imported_types)
    )

    # Read file content
    content = case Keyword.fetch!(opts, :content) do
      nil -> File.read!(file)
      c -> c
    end

    # Check with worker
    request = %{
      file: file,
      content: content,
      imported_types: imported_types
    }

    result = PoolSupervisor.check(request)

    duration = System.monotonic_time(:millisecond) - start_time

    # Cache exports if successful
    case result do
      {:ok, %{exports: exports}} when map_size(exports) > 0 ->
        TypeCache.put(file, exports)
        Metrics.emit_cache_miss(:type_cache, file)

      _ ->
        :ok
    end

    # Update file cache
    FileCache.update(file)

    Metrics.emit_file_check_stop(file, duration, result)

    result
  end

  @doc """
  Extract imports from a file.
  """
  @spec extract_imports(String.t()) :: {:ok, list()} | {:error, term()}
  def extract_imports(file) do
    content = File.read!(file)

    request = %{
      file: file,
      content: content
    }

    PoolSupervisor.extract_imports(request)
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp filter_changed_files(files) do
    files
    |> Enum.filter(&FileCache.changed?/1)
  end

  defp build_dependency_graph(files, concurrency) do
    # Extract imports in parallel
    files
    |> Task.async_stream(
      fn file ->
        {:ok, %{imports: imports}} = extract_imports(file)
        resolved = resolve_imports(file, imports)
        {file, resolved}
      end,
      max_concurrency: concurrency,
      timeout: 30_000
    )
    |> Enum.each(fn
      {:ok, {file, deps}} ->
        DependencyGraph.add(file, deps)

      {:exit, reason} ->
        Logger.warning("Failed to extract imports: #{inspect(reason)}")
    end)
  end

  defp resolve_imports(source_file, imports) do
    source_dir = Path.dirname(source_file)

    imports
    |> Enum.map(fn import ->
      resolve_import_path(source_dir, import)
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp resolve_import_path(source_dir, %{"specifier" => specifier}) do
    resolve_import_path(source_dir, specifier)
  end

  defp resolve_import_path(source_dir, specifier) when is_binary(specifier) do
    # Handle relative imports
    if String.starts_with?(specifier, ".") do
      base_path = Path.join(source_dir, specifier)

      # Try various extensions
      extensions = [".ts", ".tsx", "/index.ts", "/index.tsx"]

      Enum.find_value(extensions, fn ext ->
        full_path = base_path <> ext
        if File.exists?(full_path), do: Path.expand(full_path)
      end)
    else
      # Node module - skip for now
      nil
    end
  end

  defp resolve_import_path(_, _), do: nil

  defp check_levels(levels, concurrency) do
    levels
    |> Enum.with_index()
    |> Enum.flat_map(fn {level_files, level_index} ->
      Metrics.emit_level_check_start(level_index, length(level_files))
      start_time = System.monotonic_time(:millisecond)

      diagnostics = check_level(level_files, concurrency)

      duration = System.monotonic_time(:millisecond) - start_time
      Metrics.emit_level_check_stop(level_index, length(level_files), duration)

      diagnostics
    end)
  end

  defp check_level(files, concurrency) do
    files
    |> Task.async_stream(
      fn file ->
        case check_file(file) do
          {:ok, %{diagnostics: diags}} -> diags
          {:error, _} -> []
        end
      end,
      max_concurrency: concurrency,
      timeout: 60_000
    )
    |> Enum.flat_map(fn
      {:ok, diags} -> diags
      {:exit, _} -> []
    end)
  end

  defp get_imported_types_for_file(file) do
    deps = DependencyGraph.get_dependencies(file)

    deps
    |> Enum.reduce(%{}, fn dep, acc ->
      case TypeCache.get(dep) do
        {:ok, exports} ->
          Metrics.emit_cache_hit(:type_cache, dep)
          Map.put(acc, dep, exports)

        :not_found ->
          Metrics.emit_cache_miss(:type_cache, dep)
          acc
      end
    end)
  end
end
