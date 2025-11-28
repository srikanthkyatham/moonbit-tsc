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
/// Compile multiple files in parallel using worker processes
pub async fn compile_parallel(
  executable : String,
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

  // For single file, don't bother with workers
  if files.length() == 1 {
    let (file_path, source) = files[0]
    let result = compile_single(file_path, source, options)
    let end_time = @async.now()
    return {
      results: [result],
      total_files: 1,
      successful: if result.success { 1 } else { 0 },
      failed: if result.success { 0 } else { 1 },
      total_time_ms: end_time - start_time,
    }
  }

  // Spawn workers
  let worker_count = if options.worker_count > files.length() {
    files.length()
  } else {
    options.worker_count
  }

  let workers = spawn_workers(executable, worker_count)

  // Distribute work and collect results
  let results = @async.with_task_group(fn(group) {
    let all_results : Array[@protocol.CompileResponse] = []

    // Process each file, distributing round-robin to workers
    for i = 0; i < files.length(); i = i + 1 {
      let (file_path, source) = files[i]
      let worker = workers[i % workers.length()]

      let request = @protocol.CompileRequest::new(
        file_path,
        source,
        target=options.target,
        source_map=options.source_map,
        declaration=options.declaration,
      )

      // Spawn a task for each compilation
      let task = group.spawn(
        async fn() {
          send_request(worker, request)
        },
      )

      // Collect result when task completes
      let result = task.wait()
      all_results.push(result)
    }

    all_results
  })

  // Cleanup workers
  close_workers(workers)

  let end_time = @async.now()

  // Calculate summary
  let mut successful = 0
  let mut failed = 0
  for result in results {
    if result.success {
      successful = successful + 1
    } else {
      failed = failed + 1
    }
  }

  {
    results,
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
  }

  let start_time = @async.now()
  let result = @compiler.compile_source(source, file_path, compile_options)
  let end_time = @async.now()

  @protocol.CompileResponse::from_result(file_path, result, end_time - start_time)
}
