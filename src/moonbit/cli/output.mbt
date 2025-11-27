// Output file writing

///|
/// Find the last index of a character in a string
fn find_last_char(s : String, c : Char) -> Int? {
  let mut last_idx : Int? = None
  for i = 0; i < s.length(); i = i + 1 {
    if s[i] == c.to_int() {
      last_idx = Some(i)
    }
  }
  last_idx
}

///|
/// Get the directory from a file path
fn get_directory(path : String) -> String {
  match find_last_char(path, '/') {
    Some(idx) => path.substring(end=idx)
    None => "."
  }
}

///|
/// Get the base name without extension
fn get_base_name(path : String) -> String {
  let name = match find_last_char(path, '/') {
    Some(idx) => path.substring(start=idx + 1)
    None => path
  }

  // Remove .ts or .tsx extension
  if name.ends_with(".tsx") {
    name.substring(end=name.length() - 4)
  } else if name.ends_with(".ts") {
    name.substring(end=name.length() - 3)
  } else {
    name
  }
}

///|
/// Simple base64 encoding for inline source maps
fn base64_encode(input : String) -> String {
  let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  let bytes = input.to_bytes()
  let len = bytes.length()
  let result = StringBuilder::new()

  let mut i = 0
  while i < len {
    let b0 = bytes[i].to_int()
    let b1 = if i + 1 < len { bytes[i + 1].to_int() } else { 0 }
    let b2 = if i + 2 < len { bytes[i + 2].to_int() } else { 0 }

    let c0 = b0 >> 2
    let c1 = ((b0 & 0x03) << 4) | (b1 >> 4)
    let c2 = ((b1 & 0x0F) << 2) | (b2 >> 6)
    let c3 = b2 & 0x3F

    result.write_char(Char::from_int(alphabet[c0]))
    result.write_char(Char::from_int(alphabet[c1]))
    if i + 1 < len {
      result.write_char(Char::from_int(alphabet[c2]))
    } else {
      result.write_char('=')
    }
    if i + 2 < len {
      result.write_char(Char::from_int(alphabet[c3]))
    } else {
      result.write_char('=')
    }

    i = i + 3
  }

  result.to_string()
}

///|
/// Ensure directory exists (create parent directories if needed)
async fn ensure_dir(path : String) -> Unit raise Error {
  // Try to create the directory, ignore if exists
  let exists = @fs.exists(path)
  if not(exists) {
    // Create parent directories first if needed
    match find_last_char(path, '/') {
      Some(idx) if idx > 0 => {
        let parent = path.substring(end=idx)
        ensure_dir(parent)
      }
      _ => ()
    }
    @fs.mkdir(path, permission=0o755)
  }
}

///|
/// Write compilation output files
pub async fn write_output(
  response : @protocol.CompileResponse,
  options : CLIOptions,
) -> Unit raise Error {
  if not(response.success) {
    return
  }

  let out_dir = match options.out_dir {
    Some(dir) => dir
    None => get_directory(response.file_path)
  }

  let base_name = get_base_name(response.file_path)

  // Ensure output directory exists
  ensure_dir(out_dir)

  // Build JavaScript content with source map handling
  let source_map_mode = get_effective_source_map(options)
  let js_content = match source_map_mode {
    SourceMapMode::Inline => {
      match response.source_map {
        Some(sm) => {
          let encoded = base64_encode(sm)
          response.javascript +
          "\n//# sourceMappingURL=data:application/json;base64," +
          encoded
        }
        None => response.javascript
      }
    }
    SourceMapMode::External => {
      response.javascript +
      "\n//# sourceMappingURL=" +
      base_name +
      ".js.map"
    }
    SourceMapMode::None => response.javascript
  }

  // Write JavaScript file
  let js_path = out_dir + "/" + base_name + ".js"
  @fs.write_file(js_path, js_content, create=0o644, truncate=true)

  // Write external source map if requested
  if source_map_mode == SourceMapMode::External {
    match response.source_map {
      Some(sm) => {
        let map_path = out_dir + "/" + base_name + ".js.map"
        @fs.write_file(map_path, sm, create=0o644, truncate=true)
      }
      None => ()
    }
  }

  // Write declaration file if available
  match response.declaration {
    Some(decl) => {
      let dts_path = out_dir + "/" + base_name + ".d.ts"
      @fs.write_file(dts_path, decl, create=0o644, truncate=true)
    }
    None => ()
  }
}

///|
/// Write all compilation outputs
pub async fn write_all_outputs(
  results : Array[@protocol.CompileResponse],
  options : CLIOptions,
) -> Unit raise Error {
  for result in results {
    write_output(result, options)
  }
}
