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

  alias TSC.Cache.{TypeCache, FileCache, ErrorStore}
  alias TSC.Graph.DependencyGraph
  alias TSC.Parser.ImportExtractor
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
  Check multiple files in a single CLI invocation.
  This is the most efficient way to check multiple files.

  Returns the full result from the CLI including all file diagnostics and stats.

  ## Options

  - `:use_dependency_order` - Build dependency graph and check in topological order (default: false)
  - `:concurrency` - Number of parallel workers (default: 4)
  """
  @spec check_files_batch(list(String.t()), keyword()) :: {:ok, map()} | {:error, term()}
  def check_files_batch(files, opts \\ []) do
    opts = Options.validate_check_project!(opts)
    use_dependency_order = Keyword.get(opts, :use_dependency_order, false)
    concurrency = Keyword.fetch!(opts, :concurrency)
    start_time = System.monotonic_time(:millisecond)

    Metrics.emit_project_check_start(length(files))

    # Optionally build dependency graph and order files
    {ordered_files, graph_stats, node_modules_files} = if use_dependency_order do
      {nm_files, _} = build_dependency_graph_fast(files, concurrency)
      levels = DependencyGraph.topological_levels(files)
      ordered = List.flatten(levels)
      stats = DependencyGraph.stats()
      Logger.info("Dependency graph: #{stats.files} files, #{stats.edges} edges, #{length(levels)} levels")
      Logger.info("Found #{length(nm_files)} node_modules dependencies")
      {ordered, Map.put(stats, :levels, length(levels)), nm_files}
    else
      {files, nil, []}
    end

    # First compile node_modules dependencies to populate type cache
    # Recursively discover and compile transitive node_modules dependencies
    _nm_result = if length(node_modules_files) > 0 do
      Logger.info("Compiling #{length(node_modules_files)} initial node_modules files...")

      # Recursively discover transitive dependencies in node_modules
      all_nm_files = discover_transitive_node_modules(node_modules_files, concurrency)
      Logger.info("Total node_modules files after transitive discovery: #{length(all_nm_files)}")

      # Sort node_modules files in dependency order and compile
      # First pass: compile leaf modules (no dependencies)
      # Then compile modules that depend on them, etc.
      compile_node_modules_in_order(all_nm_files, concurrency)
    else
      {:ok, %{}}
    end

    # Now compile project files with cached types from node_modules
    result = PoolSupervisor.check_files(ordered_files, %{use_cached_types: true})

    duration = System.monotonic_time(:millisecond) - start_time

    case result do
      {:ok, data} ->
        # Get stats from either :stats or "stats" key (JSON keys are strings)
        stats = data[:stats] || data["stats"] || %{}
        summary = data[:summary] || %{}

        # Enhance the result with timing info
        enhanced_result = %{
          success: data.success,
          diagnostics: data.diagnostics,
          stats: %{
            files_checked: stats["total_files"] || length(files),
            elapsed_ms: duration,
            errors: summary[:errors] || stats["total_errors"] || 0,
            warnings: summary[:warnings] || stats["total_warnings"] || 0,
            graph: graph_stats
          }
        }

        Metrics.emit_project_check_stop(
          length(files),
          duration,
          if(enhanced_result.success, do: :success, else: :errors)
        )

        # Store errors in ETS for persistence (convert structs to maps)
        diagnostics_as_maps = Enum.map(data.diagnostics, fn
          %TSC.Diagnostic{} = d -> TSC.Diagnostic.to_map(d)
          %{__struct__: _} = d -> Map.from_struct(d)
          d when is_map(d) -> d
          _ -> %{}
        end)
        ErrorStore.put_from_files(files, diagnostics_as_maps)

        # Broadcast results to LiveView subscribers
        Phoenix.PubSub.broadcast(
          TscPhoenix.PubSub,
          "compiler:updates",
          {:incremental_check_complete, enhanced_result}
        )

        {:ok, enhanced_result}

      error ->
        Metrics.emit_project_check_stop(length(files), duration, :error)
        error
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

  # Recursively discover all transitive node_modules dependencies
  defp discover_transitive_node_modules(initial_files, concurrency) do
    discover_transitive_node_modules(initial_files, MapSet.new(), concurrency)
  end

  defp discover_transitive_node_modules([], seen, _concurrency), do: MapSet.to_list(seen)

  defp discover_transitive_node_modules(files_to_check, seen, concurrency) do
    # Add current files to seen set
    new_seen = Enum.reduce(files_to_check, seen, fn f, acc -> MapSet.put(acc, f) end)

    # Extract imports from each file and resolve to absolute paths
    new_deps =
      files_to_check
      |> Task.async_stream(
        fn file ->
          case PoolSupervisor.list_imports(file) do
            {:ok, result} ->
              result.imports
              |> Enum.map(fn imp -> ImportExtractor.resolve(file, imp.specifier) end)
              |> Enum.reject(&is_nil/1)
              |> Enum.filter(&String.contains?(&1, "node_modules"))

            {:error, _} ->
              # Try Elixir parser fallback
              case ImportExtractor.extract(file) do
                {:ok, imports} ->
                  imports
                  |> Enum.map(fn imp -> ImportExtractor.resolve(file, imp.specifier) end)
                  |> Enum.reject(&is_nil/1)
                  |> Enum.filter(&String.contains?(&1, "node_modules"))

                {:error, _} ->
                  []
              end
          end
        end,
        max_concurrency: concurrency,
        timeout: 30_000
      )
      |> Enum.flat_map(fn
        {:ok, deps} -> deps
        {:exit, _} -> []
      end)
      |> Enum.reject(&MapSet.member?(new_seen, &1))
      |> Enum.uniq()

    # Recursively discover dependencies of new files
    if length(new_deps) > 0 do
      discover_transitive_node_modules(new_deps, new_seen, concurrency)
    else
      MapSet.to_list(new_seen)
    end
  end

  # Compile node_modules files in dependency order
  # Files with no dependencies are compiled first, then files that depend on them
  defp compile_node_modules_in_order(files, concurrency) do
    # Build a simple dependency map
    dep_map =
      files
      |> Task.async_stream(
        fn file ->
          deps =
            case PoolSupervisor.list_imports(file) do
              {:ok, result} ->
                result.imports
                |> Enum.map(fn imp -> ImportExtractor.resolve(file, imp.specifier) end)
                |> Enum.reject(&is_nil/1)
                |> Enum.filter(&String.contains?(&1, "node_modules"))

              {:error, _} ->
                []
            end

          {file, deps}
        end,
        max_concurrency: concurrency,
        timeout: 30_000
      )
      |> Enum.reduce(%{}, fn
        {:ok, {file, deps}}, acc -> Map.put(acc, file, deps)
        {:exit, _}, acc -> acc
      end)

    # Topological sort - compile files with no dependencies first
    file_set = MapSet.new(files)
    compile_in_levels(files, dep_map, file_set, [])
  end

  defp compile_in_levels([], _dep_map, _file_set, _compiled), do: {:ok, %{}}

  defp compile_in_levels(remaining, dep_map, file_set, compiled) do
    compiled_set = MapSet.new(compiled)

    # Find files whose dependencies are all compiled (or not in our set)
    {ready, not_ready} =
      Enum.split_with(remaining, fn file ->
        deps = Map.get(dep_map, file, [])

        Enum.all?(deps, fn dep ->
          MapSet.member?(compiled_set, dep) or not MapSet.member?(file_set, dep)
        end)
      end)

    if length(ready) == 0 and length(not_ready) > 0 do
      # Circular dependency or missing deps - just compile what's left
      Logger.warning("Possible circular dependency in node_modules, compiling remaining #{length(not_ready)} files")
      PoolSupervisor.check_files(not_ready, %{use_cached_types: true})
    else
      # Compile ready files
      if length(ready) > 0 do
        PoolSupervisor.check_files(ready, %{use_cached_types: true})
      end

      # Continue with remaining
      compile_in_levels(not_ready, dep_map, file_set, compiled ++ ready)
    end
  end

  # Build dependency graph using the CLI for accurate AST-based import extraction
  # This handles all TypeScript import syntaxes including import = require()
  defp build_dependency_graph_fast(files, concurrency) do
    DependencyGraph.clear()

    # Track node_modules files separately
    node_modules_files = :ets.new(:node_modules_files, [:set, :public])

    files
    |> Task.async_stream(
      fn file ->
        case PoolSupervisor.list_imports(file) do
          {:ok, result} ->
            # Resolve imports to absolute paths
            dependencies =
              result.imports
              |> Enum.map(fn imp ->
                resolved = ImportExtractor.resolve(file, imp.specifier)
                # Track node_modules files
                if resolved && String.contains?(resolved, "node_modules") do
                  :ets.insert(node_modules_files, {resolved, true})
                end
                resolved
              end)
              |> Enum.reject(&is_nil/1)

            {file, dependencies}

          {:error, _reason} ->
            # Fallback to Elixir parser if CLI fails
            case ImportExtractor.extract(file) do
              {:ok, imports} ->
                dependencies =
                  imports
                  |> Enum.map(fn imp ->
                    resolved = ImportExtractor.resolve(file, imp.specifier)
                    # Track node_modules files
                    if resolved && String.contains?(resolved, "node_modules") do
                      :ets.insert(node_modules_files, {resolved, true})
                    end
                    resolved
                  end)
                  |> Enum.reject(&is_nil/1)
                {file, dependencies}

              {:error, _} ->
                {file, []}
            end
        end
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

    # Collect and return node_modules files
    nm_files = :ets.tab2list(node_modules_files) |> Enum.map(fn {path, _} -> path end)
    :ets.delete(node_modules_files)

    {nm_files, :ok}
  end
end
