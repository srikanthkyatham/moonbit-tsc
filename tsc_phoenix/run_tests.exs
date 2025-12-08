projects_dir = "/Users/srikanthkyatham/Personal/moonbit/typescript-repo/tests/cases/projects"

# Get all project directories (including nested ones for NodeModulesSearch)
projects = File.ls!(projects_dir)
|> Enum.filter(fn name ->
  full_path = Path.join(projects_dir, name)
  File.dir?(full_path) && name != "baseline"
end)
|> Enum.flat_map(fn name ->
  full_path = Path.join(projects_dir, name)
  # Check if this project has subdirectories with their own tsconfig.json (like NodeModulesSearch)
  subdirs = File.ls!(full_path)
  |> Enum.filter(fn subname ->
    subpath = Path.join(full_path, subname)
    File.dir?(subpath) && File.exists?(Path.join(subpath, "tsconfig.json"))
  end)

  if length(subdirs) > 0 do
    # This is a multi-project directory, return each subproject
    Enum.map(subdirs, fn subname -> "#{name}/#{subname}" end)
  else
    # Single project
    [name]
  end
end)
|> Enum.sort()

IO.puts("Found #{length(projects)} test projects\n")

# Run compiler on each project
results = Enum.map(projects, fn project ->
  project_path = Path.join(projects_dir, project)

  # Clear caches between projects to avoid cross-contamination
  TSC.Cache.TypeCache.clear()
  TSC.Cache.TypeCache.clear_mappings()

  # Include both .ts and .d.ts files (for triple-slash reference directives)
  # But exclude node_modules - those will be resolved and compiled automatically
  ts_files = Path.wildcard(Path.join(project_path, "**/*.ts"))
  |> Enum.reject(&String.contains?(&1, "node_modules"))
  dts_files = Path.wildcard(Path.join(project_path, "**/*.d.ts"))
  |> Enum.reject(&String.contains?(&1, "node_modules"))
  files = Enum.uniq(ts_files ++ dts_files)

  if length(files) > 0 do
    result = TSC.Coordinator.check_files_batch(files, use_dependency_order: true)

    case result do
      {:ok, data} ->
        %{
          project: project,
          success: data.success,
          files: length(files),
          errors: data.stats[:errors] || 0,
          warnings: data.stats[:warnings] || 0,
          diagnostics: Enum.take(data.diagnostics, 5)
        }
      {:error, reason} ->
        %{
          project: project,
          success: false,
          files: length(files),
          errors: -1,
          warnings: 0,
          error_reason: inspect(reason)
        }
    end
  else
    %{project: project, success: true, files: 0, errors: 0, warnings: 0, skipped: true}
  end
end)

# Categorize results
successful = Enum.filter(results, & &1.success)
failed = Enum.reject(results, & &1.success)

IO.puts("\n========== SUMMARY ==========\n")
IO.puts("Total projects: #{length(results)}")
IO.puts("Successful: #{length(successful)}")
IO.puts("Failed: #{length(failed)}")

IO.puts("\n========== SUCCESSFUL PROJECTS ==========\n")
Enum.each(successful, fn r ->
  IO.puts("✓ #{r.project} (#{r.files} files, #{r.warnings} warnings)")
end)

IO.puts("\n========== FAILED PROJECTS ==========\n")
Enum.each(failed, fn r ->
  IO.puts("✗ #{r.project} (#{r.files} files, #{r.errors} errors)")
  if r[:error_reason] do
    IO.puts("  Error: #{r.error_reason}")
  end
  if r[:diagnostics] do
    Enum.each(r.diagnostics, fn d ->
      if d do
        file = Map.get(d, :file, "unknown") || "unknown"
        msg = Map.get(d, :message, "no message") || "no message"
        line = Map.get(d, :line, 0) || 0
        IO.puts("  - #{Path.basename(to_string(file))}:#{line}: #{msg}")
      end
    end)
  end
  IO.puts("")
end)
