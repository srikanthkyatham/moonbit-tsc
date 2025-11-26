// Worker pool management for parallel compilation

///|
/// Represents a spawned worker process with pipe handles
pub struct WorkerHandle {
  pid : Int
  stdin : @pipe.PipeWrite
  stdout : @pipe.PipeRead
  reader : @io.BufferedReader[@pipe.PipeRead]
}

///|
/// Spawn a single worker process
pub async fn spawn_worker(executable : String) -> WorkerHandle!Error {
  // Create pipes for communication
  let (stdin_for_process, stdin_write) = @process.write_to_process!()
  let (stdout_read, stdout_for_process) = @process.read_from_process!()

  // Spawn the worker process with --worker flag
  let pid = @process.spawn_orphan!(
    executable,
    ["--worker"],
    stdin=stdin_for_process,
    stdout=stdout_for_process,
  )

  let reader = @io.BufferedReader::new(stdout_read)

  { pid, stdin: stdin_write, stdout: stdout_read, reader }
}

///|
/// Spawn multiple worker processes
pub async fn spawn_workers(
  executable : String,
  count : Int,
) -> Array[WorkerHandle]!Error {
  let workers : Array[WorkerHandle] = []

  for i = 0; i < count; i = i + 1 {
    let worker = spawn_worker!(executable)
    workers.push(worker)
  }

  workers
}

///|
/// Send a compile request to a worker and wait for response
pub async fn send_request(
  worker : WorkerHandle,
  request : @protocol.CompileRequest,
) -> @protocol.CompileResponse!Error {
  // Send request as newline-delimited JSON
  let request_json = request.to_ndjson()
  worker.stdin.write(request_json)

  // Read response
  let response_line = worker.reader.read_line()

  match response_line {
    None =>
      @protocol.CompileResponse::error(
        request.file_path,
        "Worker closed unexpectedly",
      )
    Some(json_str) => {
      try {
        @protocol.parse_response!(json_str)
      } catch {
        err =>
          @protocol.CompileResponse::error(
            request.file_path,
            "Failed to parse worker response: \{err}",
          )
      }
    }
  }
}

///|
/// Close a worker's stdin to signal shutdown
pub fn close_worker(worker : WorkerHandle) -> Unit {
  worker.stdin.close()
}

///|
/// Close all workers
pub fn close_workers(workers : Array[WorkerHandle]) -> Unit {
  for worker in workers {
    close_worker(worker)
  }
}
