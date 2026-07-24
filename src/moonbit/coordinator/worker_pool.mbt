// Worker pool management for parallel compilation
// Uses moonbitlang/async for process spawning and async queues for task distribution

///|
/// Represents a spawned worker process with pipe handles
pub struct WorkerHandle {
  pid : Int
  stdin : @process.WriteToProcess
  stdout : @process.ReadFromProcess
}

///|
/// Work item for the task queue
pub(all) struct WorkItem {
  request : @protocol.CompileRequest
  index : Int // Original index for result ordering
}

///|
/// Result item from workers
pub(all) struct ResultItem {
  response : @protocol.CompileResponse
  index : Int // Original index for result ordering
}

///|
/// Worker pool with task queue for distributing work
pub struct WorkerPool {
  workers : Array[WorkerHandle]
  work_queue : @aqueue.Queue[WorkItem]
  result_queue : @aqueue.Queue[ResultItem]
}

///|
/// Spawn a single worker process
pub async fn spawn_worker(executable : String) -> WorkerHandle raise Error {
  // Create pipes for communication
  let (stdin_for_process, stdin_write) = @process.write_to_process()
  let (stdout_read, stdout_for_process) = @process.read_from_process()

  // Spawn the worker process with --worker flag
  let pid = @process.spawn_orphan(
    executable,
    ["--worker"],
    stdin=stdin_for_process,
    stdout=stdout_for_process,
  )
  { pid, stdin: stdin_write, stdout: stdout_read }
}

///|
/// Spawn multiple worker processes
pub async fn spawn_workers(
  executable : String,
  count : Int,
) -> Array[WorkerHandle] raise Error {
  let workers : Array[WorkerHandle] = []
  for i = 0; i < count; i = i + 1 {
    let worker = spawn_worker(executable)
    workers.push(worker)
  }
  workers
}

///|
/// Create a worker pool with task queue
pub async fn create_worker_pool(
  executable : String,
  worker_count : Int,
) -> WorkerPool raise Error {
  let workers = spawn_workers(executable, worker_count)

  // Create bounded queues for work distribution and result collection
  let work_queue = @aqueue.Queue(kind=@aqueue.Blocking(worker_count * 2))
  let result_queue = @aqueue.Queue(kind=@aqueue.Unbounded)
  { workers, work_queue, result_queue }
}

///|
/// Send a compile request to a worker and wait for response
pub async fn send_request(
  worker : WorkerHandle,
  request : @protocol.CompileRequest,
) -> @protocol.CompileResponse raise Error {
  // Send request as newline-delimited JSON
  let request_json = request.to_ndjson()
  worker.stdin.write(request_json)

  // Read response
  let response_line = worker.stdout.read_until("\n")
  match response_line {
    None =>
      @protocol.CompileResponse::error(
        request.file_path,
        "Worker closed unexpectedly",
      )
    Some(json_str) =>
      @protocol.parse_response(json_str) catch {
        err =>
          @protocol.CompileResponse::error(
            request.file_path,
            "Failed to parse worker response: \{err}",
          )
      }
  }
}

///|
/// Worker loop - continuously pulls work from queue and sends to worker process
async fn worker_loop(
  worker : WorkerHandle,
  work_queue : @aqueue.Queue[WorkItem],
  result_queue : @aqueue.Queue[ResultItem],
) -> Unit raise Error {
  // Process items until queue signals completion (via task group cancellation)
  while true {
    let item = work_queue.get()
    let response = send_request(worker, item.request)
    result_queue.put({ response, index: item.index })
  }
}

///|
/// Run compilation using worker pool with async queues
pub async fn run_with_pool(
  pool : WorkerPool,
  files : Array[(String, String)], // (file_path, source) pairs
  options : CoordinatorOptions,
) -> Array[@protocol.CompileResponse] raise Error {
  if files.length() == 0 {
    return []
  }

  // Pre-allocate results array
  let results : Array[@protocol.CompileResponse?] = Array::make(
    files.length(),
    None,
  )
  let total_count = files.length()
  @async.with_task_group(async fn(group) {
    // Start worker loops in background
    for worker in pool.workers {
      group.spawn_bg(allow_failure=true, async fn() {
        worker_loop(worker, pool.work_queue, pool.result_queue)
      })
    }

    // Enqueue all work items
    let module_kind_str = match options.module_kind {
      @compiler.CommonJS => "commonjs"
      @compiler.Node16 => "node16"
      @compiler.NodeNext => "nodenext"
      _ => "esmodule"
    }
    // Tri-state strict-flag overrides forwarded to the worker (None = unset)
    let ov = options.strict_overrides.unwrap_or(
      @compiler.StrictFlagOverrides::default(),
    )
    for i = 0; i < files.length(); i = i + 1 {
      let (file_path, source) = files[i]
      let request = @protocol.CompileRequest::new(
        file_path,
        source,
        target=options.target,
        module_kind=module_kind_str,
        source_map=options.source_map,
        declaration=options.declaration,
        always_strict=options.always_strict,
        strict=ov.strict,
        no_implicit_any=ov.no_implicit_any,
        strict_null_checks=ov.strict_null_checks,
        strict_function_types=ov.strict_function_types,
        strict_property_initialization=ov.strict_property_initialization,
      )
      pool.work_queue.put({ request, index: i })
    }

    // Collect all results
    let mut collected = 0
    while collected < total_count {
      let result_item = pool.result_queue.get()
      results[result_item.index] = Some(result_item.response)
      collected = collected + 1
    }

    // All results collected - worker loops will be cancelled when task group ends
  })

  // Convert to final array
  let final_results : Array[@protocol.CompileResponse] = []
  for result in results {
    match result {
      Some(response) => final_results.push(response)
      None => ()
    }
  }
  final_results
}

///|
/// Close a worker's stdin to signal shutdown
pub fn close_worker(worker : WorkerHandle) -> Unit {
  worker.stdin.close()
}

///|
/// Kill a worker process by PID
pub async fn kill_worker(worker : WorkerHandle) -> Unit raise Error {
  // First close stdin to signal graceful shutdown
  worker.stdin.close()
  // Then forcefully kill the process to ensure it terminates
  let _ = @process.run("kill", [worker.pid.to_string()])

}

///|
/// Close all workers
pub fn close_workers(workers : Array[WorkerHandle]) -> Unit {
  for worker in workers {
    close_worker(worker)
  }
}

///|
/// Kill all worker processes
pub async fn kill_workers(workers : Array[WorkerHandle]) -> Unit raise Error {
  for worker in workers {
    kill_worker(worker)
  }
}

///|
/// Shutdown worker pool (kills all worker processes)
pub async fn shutdown_pool(pool : WorkerPool) -> Unit raise Error {
  kill_workers(pool.workers)
}
