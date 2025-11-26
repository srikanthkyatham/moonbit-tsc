// File discovery for TypeScript files

///|
/// Check if a file is a TypeScript file (not declaration file)
pub fn is_typescript_file(path : String) -> Bool {
  (path.ends_with(".ts") || path.ends_with(".tsx")) &&
  not(path.ends_with(".d.ts"))
}

///|
/// Discover TypeScript files from a list of paths (files or directories)
pub async fn discover_files(paths : Array[String]) -> Array[String]!Error {
  let files : Array[String] = []

  for path in paths {
    if is_typescript_file(path) {
      // Direct file path
      files.push(path)
    } else {
      // Check if it's a directory
      let file_kind = @fs.kind!(path)
      if file_kind == @fs.FileKind::Directory {
        // Walk directory for TypeScript files
        walk_directory!(path, files)
      }
    }
  }

  files
}

///|
/// Walk a directory recursively and collect TypeScript files
async fn walk_directory(dir : String, files : Array[String]) -> Unit!Error {
  @fs.walk!(
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
/// Read multiple files asynchronously
pub async fn read_files(
  paths : Array[String],
) -> Array[(String, String)]!Error {
  let results : Array[(String, String)] = []

  // Read files sequentially for now (simpler and avoids race conditions on results array)
  for path in paths {
    let data = @fs.read_file!(path)
    let content = data.text!()
    results.push((path, content))
  }

  results
}
