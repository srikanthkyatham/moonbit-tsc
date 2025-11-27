// File discovery for TypeScript files
// Uses moonbitlang/async for parallel file I/O

///|
/// Maximum concurrent file reads (to avoid exhausting file descriptors)
let max_concurrent_reads : Int = 32

///|
/// Check if a file is a TypeScript file (not declaration file)
pub fn is_typescript_file(path : String) -> Bool {
  (path.ends_with(".ts") || path.ends_with(".tsx")) &&
  not(path.ends_with(".d.ts"))
}

///|
/// Discover TypeScript files from a list of paths (files or directories)
pub async fn discover_files(paths : Array[String]) -> Array[String] raise Error {
  let files : Array[String] = []

  for path in paths {
    if is_typescript_file(path) {
      // Direct file path
      files.push(path)
    } else {
      // Check if it's a directory
      let file_kind = @fs.kind(path)
      if file_kind == @fs.FileKind::Directory {
        // Walk directory for TypeScript files
        walk_directory(path, files)
      }
    }
  }

  files
}

///|
/// Walk a directory recursively and collect TypeScript files
async fn walk_directory(dir : String, files : Array[String]) -> Unit raise Error {
  @fs.walk(
    dir,
    async fn(current_dir, entries) {
      for entry in entries {
        let full_path = current_dir + "/" + entry
        if is_typescript_file(entry) {
          files.push(full_path)
        }
      }
    },
  )
}

///|
/// Read multiple files in parallel using task groups and semaphore for concurrency control
pub async fn read_files(
  paths : Array[String],
) -> Array[(String, String)] raise Error {
  if paths.length() == 0 {
    return []
  }

  // For small number of files, read sequentially
  if paths.length() <= 2 {
    let results : Array[(String, String)] = []
    for path in paths {
      let data = @fs.read_file(path)
      let content = data.text()
      results.push((path, content))
    }
    return results
  }

  // Use semaphore for concurrency control
  let sem = @semaphore.Semaphore::new(max_concurrent_reads)

  // Pre-allocate result array with placeholders
  let results : Array[(String, String)?] = Array::make(paths.length(), None)

  // Read files in parallel with concurrency limit
  @async.with_task_group(fn(group) {
    for i = 0; i < paths.length(); i = i + 1 {
      let path = paths[i]
      let idx = i
      let _ = group.spawn(
        async fn() {
          // Acquire semaphore before reading
          sem.acquire()

          // Read file
          let data = try {
            @fs.read_file(path)
          } catch {
            err => {
              sem.release()
              raise err
            }
          }
          let content = data.text()

          // Store result
          results[idx] = Some((path, content))

          // Release semaphore
          sem.release()
        },
      )
    }
  })

  // Convert to final array (unwrap Options)
  let final_results : Array[(String, String)] = []
  for result in results {
    match result {
      Some(pair) => final_results.push(pair)
      None => ()
    }
  }

  final_results
}
