// Coordinator for parallel TypeScript compilation
// Uses moonbitlang/async for process management and task coordination

///|
/// Compilation options for the coordinator
pub(all) struct CoordinatorOptions {
  target : String
  module_kind : @compiler.ModuleKind // ESModule or CommonJS
  source_map : Bool
  inline_source_map : Bool // Embed source map as base64 data URL in JS output
  inline_sources : Bool // Include original source in source map
  declaration : Bool
  always_strict : Bool // Emit "use strict"
  es_module_interop : Bool // Emit helpers for CommonJS/ES module interoperability
  worker_count : Int
  verbose : Bool
  external_types_json : String? // JSON string containing external types for cross-file checking
  no_emit : Bool // Only run type checking, don't emit JavaScript
  no_implicit_any : Bool // Raise error on expressions and declarations with an implied 'any' type
  import_helpers : Bool // Import emit helpers from tslib
  strict_overrides : @compiler.StrictFlagOverrides? // Tri-state strict flags from CLI/tsconfig (None = unset; file directives win)
} derive(Debug)

///|
/// Default coordinator options
pub fn CoordinatorOptions::default() -> CoordinatorOptions {
  {
    target: "es2015",
    module_kind: @compiler.ESModule,
    source_map: false,
    inline_source_map: false,
    inline_sources: false,
    declaration: false,
    always_strict: false,
    es_module_interop: false,
    worker_count: 4,
    verbose: false,
    external_types_json: None,
    no_emit: false,
    no_implicit_any: false,
    import_helpers: false,
    strict_overrides: None,
  } // Default to 4 workers
}

///|
/// Result of compiling multiple files
pub(all) struct CompilationSummary {
  results : Array[@protocol.CompileResponse]
  total_files : Int
  successful : Int
  failed : Int
  total_time_ms : Int64
} derive(Debug)

///|
/// Compile multiple files in parallel using async task groups
/// Uses in-process parallelism via MoonBit's async runtime
/// Files are compiled in topological order (level by level) to ensure
/// dependencies are compiled before dependents.
///
/// Key feature: After compiling each level, the exported types are cached
/// and fed to dependent files in subsequent levels. This enables proper
/// cross-file type checking similar to tsc-phoenix.
pub async fn compile_parallel(
  _executable : String,
  files : Array[(String, String)], // (file_path, source) pairs
  options : CoordinatorOptions,
) -> CompilationSummary raise Error {
  let start_time = @async.now()

  // Handle edge cases
  if files.length() == 0 {
    return {
      results: [],
      total_files: 0,
      successful: 0,
      failed: 0,
      total_time_ms: 0,
    }
  }

  // Create type cache for storing exported types between levels
  let type_cache = TypeCache::new()

  // Pre-pass: Extract global namespaces from all .d.ts files
  // This ensures global declarations are available to all files during compilation
  let global_namespaces = extract_global_namespaces_from_dts_files(files)

  // Store global namespaces in type cache so they're available to all files
  for entry in global_namespaces {
    let (file_path, types_json) = entry
    type_cache.put(file_path, types_json)
  }

  // Build dependency graph for level-based compilation
  let dag = build_dependency_graph(files)

  // Get file paths for topological level computation
  let file_paths : Array[String] = []
  for file in files {
    let (path, _) = file
    file_paths.push(path)
  }

  // Compute topological levels (dependencies first)
  let levels = topological_levels(dag, file_paths)
  if options.verbose {
    println(
      "Compiling in " + levels.length().to_string() + " dependency levels",
    )
  }

  // Build a map from file_path to (path, source) for quick lookup
  let file_map : Map[String, (String, String)] = Map([])
  for file in files {
    let (path, source) = file
    file_map[path] = (path, source)
  }

  // Pre-allocate results map for ordering
  let results_map : Map[String, @protocol.CompileResponse] = Map([])

  // Use semaphore to limit concurrency within each level
  let sem = @semaphore.Semaphore(options.worker_count)

  // Compile level by level (all files in a level can be compiled in parallel)
  for level_idx = 0; level_idx < levels.length(); level_idx = level_idx + 1 {
    let level_files = levels[level_idx]
    if options.verbose {
      println(
        "  Level " +
        level_idx.to_string() +
        ": " +
        level_files.length().to_string() +
        " file(s)",
      )
    }

    // Build external types JSON from cached types (excluding files in current level)
    // This passes type information from dependencies to dependent files
    let external_types_json = type_cache.build_external_types_json(level_files)

    // Merge with any provided external types
    let level_options = match
      (external_types_json, options.external_types_json) {
      (Some(cached), Some(provided)) => {
        // Merge cached types with provided types
        let merged = merge_external_types_json(cached, provided)
        { ..options, external_types_json: Some(merged) }
      }
      (Some(cached), None) => { ..options, external_types_json: Some(cached) }
      (None, Some(provided)) =>
        { ..options, external_types_json: Some(provided) }
      (None, None) => options
    }

    // Compile all files in this level in parallel
    @async.with_task_group(fn(group) {
      for file_path in level_files {
        let path = file_path
        let opts = level_options
        let _ = group.spawn(async fn() {
          // Acquire semaphore to limit concurrency
          sem.acquire()

          // Get source from map
          match file_map.get(path) {
            Some((_, source)) => {
              // Compile the file
              let result = compile_single(path, source, opts)
              results_map[path] = result

              // Cache exported types for use by dependent files in later levels
              match result.module_types_json {
                Some(types_json) => type_cache.put(path, types_json)
                None => ()
              }
            }
            None => ()
          }

          // Release semaphore
          sem.release()
        })

      }
    })
    if options.verbose {
      let cached_count = type_cache.length()
      println("    Cached types: " + cached_count.to_string() + " module(s)")
    }
  }
  let end_time = @async.now()

  // Convert to final array preserving original order and calculate summary
  let final_results : Array[@protocol.CompileResponse] = []
  let mut successful = 0
  let mut failed = 0
  for file in files {
    let (path, _) = file
    match results_map.get(path) {
      Some(response) => {
        final_results.push(response)
        if response.success {
          successful = successful + 1
        } else {
          failed = failed + 1
        }
      }
      None => ()
    }
  }
  {
    results: final_results,
    total_files: files.length(),
    successful,
    failed,
    total_time_ms: end_time - start_time,
  }
}

///|
/// Merge two external types JSON strings
/// Combines modules from both sources, with first (cached) taking precedence
fn merge_external_types_json(first : String, _second : String) -> String {
  // Simple approach: for now, just use the cached types which should include everything
  // The cached types already include globals from pre-pass
  // A more sophisticated merge would parse both JSONs and combine modules
  first
}

///|
/// Compile multiple files in parallel WITHOUT dependency ordering
/// Use this for simple cases where dependency order doesn't matter
pub async fn compile_parallel_unordered(
  _executable : String,
  files : Array[(String, String)], // (file_path, source) pairs
  options : CoordinatorOptions,
) -> CompilationSummary raise Error {
  let start_time = @async.now()

  // Handle edge cases
  if files.length() == 0 {
    return {
      results: [],
      total_files: 0,
      successful: 0,
      failed: 0,
      total_time_ms: 0,
    }
  }

  // Pre-pass: Extract global namespaces from all .d.ts files
  let global_namespaces = extract_global_namespaces_from_dts_files(files)

  // Build combined external types JSON that includes global namespaces
  let combined_options = if global_namespaces.length() > 0 {
    let combined_json = build_external_types_with_globals(
      options.external_types_json,
      global_namespaces,
    )
    { ..options, external_types_json: Some(combined_json) }
  } else {
    options
  }

  // Pre-allocate results array
  let results : Array[@protocol.CompileResponse?] = Array::make(
    files.length(),
    None,
  )

  // Use semaphore to limit concurrency to worker_count
  let sem = @semaphore.Semaphore(combined_options.worker_count)

  // Compile all files in parallel using task group
  @async.with_task_group(fn(group) {
    for i = 0; i < files.length(); i = i + 1 {
      let idx = i
      let (file_path, source) = files[i]
      let opts = combined_options
      let _ = group.spawn(async fn() {
        // Acquire semaphore to limit concurrency
        sem.acquire()

        // Compile the file
        let result = compile_single(file_path, source, opts)
        results[idx] = Some(result)

        // Release semaphore
        sem.release()
      })

    }
  })
  let end_time = @async.now()

  // Convert to final array and calculate summary
  let final_results : Array[@protocol.CompileResponse] = []
  let mut successful = 0
  let mut failed = 0
  for result in results {
    match result {
      Some(response) => {
        final_results.push(response)
        if response.success {
          successful = successful + 1
        } else {
          failed = failed + 1
        }
      }
      None => ()
    }
  }
  {
    results: final_results,
    total_files: files.length(),
    successful,
    failed,
    total_time_ms: end_time - start_time,
  }
}

///|
/// Extract global namespaces from all .d.ts files
/// Returns a list of (module_path, global_namespaces_json) pairs
fn extract_global_namespaces_from_dts_files(
  files : Array[(String, String)],
) -> Array[(String, String)] {
  let result : Array[(String, String)] = []
  for file in files {
    let (file_path, source) = file
    // Only process declaration files (.d.ts and the .d.mts/.d.cts variants)
    if file_path.has_suffix(".d.ts") ||
      file_path.has_suffix(".d.mts") ||
      file_path.has_suffix(".d.cts") {
      // Parse and extract module types
      match @compiler.extract_module_types_from_source(source, file_path) {
        Some(module_types) => {
          // Serialize just the global_namespaces part
          let json = module_types.to_json_string()
          result.push((file_path, json))
        }
        None => ()
      }
    }
  }
  result
}

///|
/// Build combined external types JSON including global namespaces
fn build_external_types_with_globals(
  existing_json : String?,
  global_ns_files : Array[(String, String)],
) -> String {
  let sb = StringBuilder::new()
  sb.write_string("{\"modules\":{")
  let mut first = true

  // Add entries from global namespace files
  for entry in global_ns_files {
    let (file_path, module_json) = entry
    if !(first) {
      sb.write_string(",")
    }
    first = false
    sb.write_string("\"")
    sb.write_string(escape_json_string(file_path))
    sb.write_string("\":")
    sb.write_string(module_json)
  }

  // If there's existing external types JSON, we'd need to merge it
  // For now, we just use the global namespaces
  match existing_json {
    Some(_) =>
      // TODO: Merge existing external types
      ()
    None => ()
  }
  sb.write_string("}}")
  sb.to_string()
}

///|
/// Escape a string for JSON
fn escape_json_string(s : String) -> String {
  let sb = StringBuilder::new()
  for c in s {
    match c {
      '"' => sb.write_string("\\\"")
      '\\' => sb.write_string("\\\\")
      '\n' => sb.write_string("\\n")
      '\r' => sb.write_string("\\r")
      '\t' => sb.write_string("\\t")
      _ => sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
/// Compile a single file without workers (for single-file case)
fn compile_single(
  file_path : String,
  source : String,
  options : CoordinatorOptions,
) -> @protocol.CompileResponse {
  let compile_options = @compiler.CompileOptions::{
    target: @compiler.parse_target(options.target),
    module_kind: options.module_kind,
    source_map: options.source_map,
    inline_source_map: options.inline_source_map,
    inline_sources: options.inline_sources,
    declaration: options.declaration,
    strict: false,
    always_strict: options.always_strict,
    isolated_modules: false,
    exact_optional_property_types: false,
    no_unchecked_indexed_access: false,
    verbatim_module_syntax: false,
    no_emit: options.no_emit,
    es_module_interop: options.es_module_interop,
    import_helpers: options.import_helpers,
    no_implicit_any: options.no_implicit_any,
    strict_null_checks: false,
    no_implicit_this: false,
    no_unused_locals: false,
    no_unused_parameters: false,
    no_implicit_returns: false,
    no_fallthrough_cases_in_switch: false,
    strict_property_initialization: false,
  }
  let start_time = @async.now()
  let strict_overrides = options.strict_overrides

  // Check if this is a multi-file test (contains @filename: directives)
  let result = if @compiler.is_multi_file_test(source) {
    // Use multi-file compilation for tests with @filename: directives
    @compiler.compile_multi_file_test(
      source, file_path, compile_options, strict_overrides~,
    )
  } else {
    // Use compile_source_with_external_types if external types are provided
    match options.external_types_json {
      Some(external_types_json) =>
        // Parse the JSON string into ExternalTypeRegistry
        match @compiler.ExternalTypeRegistry::from_json(external_types_json) {
          Some(registry) =>
            @compiler.compile_source_with_external_types(
              source, file_path, compile_options, registry, strict_overrides~,
            )
          None =>
            // If parsing fails, fall back to regular compilation
            @compiler.compile_source(
              source, file_path, compile_options, strict_overrides~,
            )
        }
      None =>
        @compiler.compile_source(
          source, file_path, compile_options, strict_overrides~,
        )
    }
  }
  let end_time = @async.now()
  @protocol.CompileResponse::from_result(
    file_path,
    result,
    end_time - start_time,
  )
}
