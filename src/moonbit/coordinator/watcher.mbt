// File watcher for watch mode - content hash-based implementation
// Uses content hashing to detect file modifications (more reliable than mtime)

///|
/// File state tracking for change detection
struct FileState {
  path : String
  content_hash : Int64 // Hash of file content
}

///|
/// Watch state containing all tracked files
pub struct WatchState {
  files : Map[String, FileState]
}

///|
/// Create a new watch state
pub fn WatchState::new() -> WatchState {
  { files: {} }
}

///|
/// Read file content and compute hash
async fn read_and_hash(path : String) -> Int64 raise Error {
  let data = @fs.read_file(path)
  let content = data.text()
  hash_source(content)
}

///|
/// Initialize watch state with current file content hashes
pub async fn init_watch_state(paths : Array[String]) -> WatchState raise Error {
  let files : Map[String, FileState] = {}
  for path in paths {
    let content_hash = read_and_hash(path)
    files[path] = { path, content_hash }
  }
  { files, }
}

///|
/// Check for changed files and return list of changed paths
pub async fn check_for_changes(state : WatchState) -> Array[String] raise Error {
  let changed : Array[String] = []
  for path, file_state in state.files {
    let new_hash = read_and_hash(path)

    // Check if content hash changed
    if new_hash != file_state.content_hash {
      changed.push(path)
    }
  }
  changed
}

///|
/// Update watch state with new content hashes for changed files
pub async fn update_watch_state(
  state : WatchState,
  changed_paths : Array[String],
) -> Unit raise Error {
  for path in changed_paths {
    let content_hash = read_and_hash(path)
    state.files[path] = { path, content_hash }
  }
}

///|
/// Add new files to watch state (for newly discovered files)
pub async fn add_files_to_watch(
  state : WatchState,
  new_paths : Array[String],
) -> Unit raise Error {
  for path in new_paths {
    if not(state.files.contains(path)) {
      let content_hash = read_and_hash(path)
      state.files[path] = { path, content_hash }
    }
  }
}

///|
/// Remove files from watch state (for deleted files)
pub fn remove_files_from_watch(
  state : WatchState,
  removed_paths : Array[String],
) -> Unit {
  for path in removed_paths {
    state.files.remove(path)
  }
}

///|
/// Get all watched file paths
pub fn get_watched_paths(state : WatchState) -> Array[String] {
  let paths : Array[String] = []
  for path, _ in state.files {
    paths.push(path)
  }
  paths
}

///|
/// Sleep for specified milliseconds
pub async fn sleep_ms(ms : Int) -> Unit {
  @async.sleep(ms) // @async.sleep takes milliseconds as Int
}

///|
/// Format current time for display
fn format_time() -> String {
  let now = @async.now()
  let secs = now / 1000L
  let hours = secs / 3600L % 24L
  let mins = secs / 60L % 60L
  let s = secs % 60L
  hours.to_string() +
  ":" +
  (if mins < 10L { "0" } else { "" }) +
  mins.to_string() +
  ":" +
  (if s < 10L { "0" } else { "" }) +
  s.to_string()
}

///|
/// Print watch mode status message
pub fn print_watch_message(msg : String) -> Unit {
  println("[" + format_time() + "] " + msg)
}
