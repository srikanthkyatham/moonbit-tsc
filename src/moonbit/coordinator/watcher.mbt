// File watcher for watch mode - polling-based implementation
// Uses @fs.mtime() to detect file modifications

///|
/// File state tracking for change detection
struct FileState {
  path : String
  mtime_sec : Int64
  mtime_nsec : Int
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
/// Get modification time for a file
async fn get_mtime(path : String) -> (Int64, Int) raise Error {
  @fs.mtime(path)
}

///|
/// Initialize watch state with current file modification times
pub async fn init_watch_state(paths : Array[String]) -> WatchState raise Error {
  let files : Map[String, FileState] = {}

  for path in paths {
    let (mtime_sec, mtime_nsec) = get_mtime(path)
    files[path] = { path, mtime_sec, mtime_nsec }
  }

  { files }
}

///|
/// Check for changed files and return list of changed paths
pub async fn check_for_changes(state : WatchState) -> Array[String] raise Error {
  let changed : Array[String] = []

  for path, file_state in state.files {
    let (new_sec, new_nsec) = get_mtime(path)

    // Check if modification time changed
    if new_sec != file_state.mtime_sec || new_nsec != file_state.mtime_nsec {
      changed.push(path)
    }
  }

  changed
}

///|
/// Update watch state with new modification times for changed files
pub async fn update_watch_state(
  state : WatchState,
  changed_paths : Array[String],
) -> Unit raise Error {
  for path in changed_paths {
    let (mtime_sec, mtime_nsec) = get_mtime(path)
    state.files[path] = { path, mtime_sec, mtime_nsec }
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
      let (mtime_sec, mtime_nsec) = get_mtime(path)
      state.files[path] = { path, mtime_sec, mtime_nsec }
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
  let hours = (secs / 3600L) % 24L
  let mins = (secs / 60L) % 60L
  let s = secs % 60L
  hours.to_string() + ":" +
    (if mins < 10L { "0" } else { "" }) + mins.to_string() + ":" +
    (if s < 10L { "0" } else { "" }) + s.to_string()
}

///|
/// Print watch mode status message
pub fn print_watch_message(msg : String) -> Unit {
  println("[" + format_time() + "] " + msg)
}
