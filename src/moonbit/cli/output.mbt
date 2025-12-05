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
    Some(idx) => @utils.substr(path, end=idx)
    None => "."
  }
}

///|
/// Get the base name without extension
fn get_base_name(path : String) -> String {
  let name = match find_last_char(path, '/') {
    Some(idx) => @utils.substr(path, start=idx + 1)
    None => path
  }

  // Remove .ts or .tsx extension
  if name.has_suffix(".tsx") {
    @utils.substr(name, end=name.length() - 4)
  } else if name.has_suffix(".ts") {
    @utils.substr(name, end=name.length() - 3)
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
    result.write_char(alphabet[c0].unsafe_to_char())
    result.write_char(alphabet[c1].unsafe_to_char())
    if i + 1 < len {
      result.write_char(alphabet[c2].unsafe_to_char())
    } else {
      result.write_char('=')
    }
    if i + 2 < len {
      result.write_char(alphabet[c3].unsafe_to_char())
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
        let parent = @utils.substr(path, end=idx)
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

  // Skip all output if noEmit is set
  if options.no_emit {
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
    SourceMapMode::Inline =>
      match response.source_map {
        Some(sm) => {
          let encoded = base64_encode(sm)
          response.javascript +
          "\n//# sourceMappingURL=data:application/json;base64," +
          encoded
        }
        None => response.javascript
      }
    SourceMapMode::External =>
      response.javascript + "\n//# sourceMappingURL=" + base_name + ".js.map"
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

///|
/// Parsed diagnostic structure for JSON output
pub(all) struct DiagnosticInfo {
  file : String
  line : Int
  column : Int
  category : String // "error", "warning", "suggestion", "message"
  code : String // "TS2322"
  code_number : Int // 2322
  message : String
} derive(Show, ToJson)

///|
/// Parse a diagnostic string into structured info
/// Format: `file:line:column - category TScode: message`
fn parse_diagnostic_string(diag : String) -> DiagnosticInfo? {
  // Find the pattern: file:line:col - category TSnnn: message
  // First find the " - " separator
  let dash_sep = " - "
  let mut dash_idx = -1
  for i = 0; i < diag.length() - dash_sep.length(); i = i + 1 {
    if @utils.substr(diag, start=i, end=i + 3) == dash_sep {
      dash_idx = i
      break
    }
  }
  if dash_idx == -1 {
    return None
  }
  let file_part = @utils.substr(diag, end=dash_idx)
  let rest = @utils.substr(diag, start=dash_idx + 3)

  // Parse file:line:column
  // Find last two colons for line and column
  let mut last_colon = -1
  let mut second_last_colon = -1
  for i = file_part.length() - 1; i >= 0; i = i - 1 {
    if file_part[i] == ':' {
      if last_colon == -1 {
        last_colon = i
      } else {
        second_last_colon = i
        break
      }
    }
  }
  if second_last_colon == -1 || last_colon == -1 {
    return None
  }
  let file = @utils.substr(file_part, end=second_last_colon)
  let line_str = @utils.substr(
    file_part,
    start=second_last_colon + 1,
    end=last_colon,
  )
  let col_str = @utils.substr(file_part, start=last_colon + 1)
  let line = @strconv.parse_int(line_str) catch { _ => return None }
  let column = @strconv.parse_int(col_str) catch { _ => return None }

  // Parse category TScode: message
  // Find space after category
  let mut space_idx = -1
  for i = 0; i < rest.length(); i = i + 1 {
    if rest[i] == ' ' {
      space_idx = i
      break
    }
  }
  if space_idx == -1 {
    return None
  }
  let category = @utils.substr(rest, end=space_idx)
  let code_and_msg = @utils.substr(rest, start=space_idx + 1)

  // Find colon after TS code
  let mut colon_idx = -1
  for i = 0; i < code_and_msg.length(); i = i + 1 {
    if code_and_msg[i] == ':' {
      colon_idx = i
      break
    }
  }
  if colon_idx == -1 {
    return None
  }
  let code = @utils.substr(code_and_msg, end=colon_idx)
  let message = @utils.substr(code_and_msg, start=colon_idx + 2) // Skip ": "

  // Parse code number from TSnnnn
  let code_number = if code.length() > 2 && code.has_prefix("TS") {
    @strconv.parse_int(@utils.substr(code, start=2)) catch {
      _ => 0
    }
  } else {
    0
  }
  Some(DiagnosticInfo::{
    file,
    line,
    column,
    category,
    code,
    code_number,
    message,
  })
}

///|
/// File result for JSON output
pub(all) struct FileResult {
  file_path : String
  success : Bool
  compile_time_ms : Int64
  diagnostics : Array[DiagnosticInfo]
  module_types_json : String? // Exported types for cross-file type checking cache
} derive(Show, ToJson)

///|
/// Summary stats for JSON output
pub(all) struct SummaryStats {
  total_files : Int
  successful : Int
  failed : Int
  total_errors : Int
  total_warnings : Int
  total_time_ms : Int64
} derive(Show, ToJson)

///|
/// Full JSON output structure
pub(all) struct JsonOutput {
  success : Bool
  stats : SummaryStats
  files : Array[FileResult]
} derive(Show, ToJson)

///|
/// Build JSON output from compilation summary
pub fn build_json_output(
  summary : @coordinator.CompilationSummary,
) -> JsonOutput {
  let mut total_errors = 0
  let mut total_warnings = 0
  let files : Array[FileResult] = []
  for result in summary.results {
    let diags : Array[DiagnosticInfo] = []
    for diag_str in result.diagnostics {
      match parse_diagnostic_string(diag_str) {
        Some(diag) => {
          diags.push(diag)
          if diag.category == "error" {
            total_errors = total_errors + 1
          } else if diag.category == "warning" {
            total_warnings = total_warnings + 1
          }
        }
        None => ()
      }
    }
    files.push(FileResult::{
      file_path: result.file_path,
      success: result.success,
      compile_time_ms: result.compile_time_ms,
      diagnostics: diags,
      module_types_json: result.module_types_json,
    })
  }
  JsonOutput::{
    success: summary.failed == 0 && total_errors == 0,
    stats: SummaryStats::{
      total_files: summary.total_files,
      successful: summary.successful,
      failed: summary.failed,
      total_errors,
      total_warnings,
      total_time_ms: summary.total_time_ms,
    },
    files,
  }
}

///|
/// Print JSON output for compilation summary
pub fn print_json_summary(summary : @coordinator.CompilationSummary) -> Unit {
  let output = build_json_output(summary)
  println(output.to_json().stringify())
}
