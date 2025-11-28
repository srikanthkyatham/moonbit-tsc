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

  // Pre-allocate results array
  let results : Array[@protocol.CompileResponse?] = Array::make(files.length(), None)

  // Use semaphore to limit concurrency to worker_count
  let sem = @semaphore.Semaphore::new(options.worker_count)

  // Compile all files in parallel using task group
  @async.with_task_group(fn(group) {
    for i = 0; i < files.length(); i = i + 1 {
      let idx = i
      let (file_path, source) = files[i]
      let opts = options

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
    no_emit: false,
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
  let result = @compiler.compile_source(source, file_path, compile_options)
  let end_time = @async.now()

  @protocol.CompileResponse::from_result(file_path, result, end_time - start_time)
}
