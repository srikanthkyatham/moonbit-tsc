// Coordinator for parallel TypeScript compilation
// Uses moonbitlang/async for process management and task coordination

///|
/// Compilation options for the coordinator
pub(all) struct CoordinatorOptions {
  target : String
  source_map : Bool
  declaration : Bool
  worker_count : Int
  verbose : Bool
} derive(Show)

///|
/// Default coordinator options
pub fn CoordinatorOptions::default() -> CoordinatorOptions {
  {
    target: "es2015",
    source_map: false,
    declaration: false,
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
    source_map: options.source_map,
    declaration: options.declaration,
    strict: false,
    isolated_modules: false,
    exact_optional_property_types: false,
    no_unchecked_indexed_access: false,
    verbatim_module_syntax: false,
    no_emit: false,
  }

  let start_time = @async.now()
  let result = @compiler.compile_source(source, file_path, compile_options)
  let end_time = @async.now()

  @protocol.CompileResponse::from_result(file_path, result, end_time - start_time)
}
