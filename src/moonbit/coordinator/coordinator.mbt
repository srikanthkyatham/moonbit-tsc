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
} derive(Show)

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
    worker_count: 4, // Default to 4 workers
    verbose: false,
    external_types_json: None,
    no_emit: false,
  }
}

///|
/// Result of compiling multiple files
pub(all) struct CompilationSummary {
  results : Array[@protocol.CompileResponse]
  total_files : Int
  successful : Int
  failed : Int
  total_time_ms : Int64
} derive(Show)

///|
/// Compile multiple files in parallel using async task groups
/// Uses in-process parallelism via MoonBit's async runtime
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

  // Pre-pass: Extract global namespaces from all .d.ts files
  // This ensures global declarations are available to all files during compilation
  let global_namespaces = extract_global_namespaces_from_dts_files(files)

  // Build combined external types JSON that includes global namespaces
  let combined_options = if global_namespaces.length() > 0 {
    let combined_json = build_external_types_with_globals(options.external_types_json, global_namespaces)
    { ..options, external_types_json: Some(combined_json) }
  } else {
    options
  }

  // Pre-allocate results array
  let results : Array[@protocol.CompileResponse?] = Array::make(files.length(), None)

  // Use semaphore to limit concurrency to worker_count
  let sem = @semaphore.Semaphore::new(combined_options.worker_count)

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
    // Only process .d.ts files
    if file_path.ends_with(".d.ts") {
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
    if not(first) {
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
    Some(_) => {
      // TODO: Merge existing external types
      ()
    }
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
    no_implicit_any: false,
    strict_null_checks: false,
    no_implicit_this: false,
    no_unused_locals: false,
    no_unused_parameters: false,
    no_implicit_returns: false,
    no_fallthrough_cases_in_switch: false,
    strict_property_initialization: false,
  }

  let start_time = @async.now()

  // Check if this is a multi-file test (contains @filename: directives)
  let result = if @compiler.is_multi_file_test(source) {
    // Use multi-file compilation for tests with @filename: directives
    @compiler.compile_multi_file_test(source, file_path, compile_options)
  } else {
    // Use compile_source_with_external_types if external types are provided
    match options.external_types_json {
      Some(external_types_json) =>
        // Parse the JSON string into ExternalTypeRegistry
        match @compiler.ExternalTypeRegistry::from_json(external_types_json) {
          Some(registry) =>
            @compiler.compile_source_with_external_types(source, file_path, compile_options, registry)
          None =>
            // If parsing fails, fall back to regular compilation
            @compiler.compile_source(source, file_path, compile_options)
        }
      None =>
        @compiler.compile_source(source, file_path, compile_options)
    }
  }

  let end_time = @async.now()

  @protocol.CompileResponse::from_result(file_path, result, end_time - start_time)
}
