// Type Check API for TypeScript
// Provides a convenient interface for type checking TypeScript source code

///|
/// Type check TypeScript source code
/// Returns a TypedFile on success or diagnostics on failure
pub fn type_check(source : String, file_path : String) -> CheckResult {
  let tokens = scan_all_v2(source, file_path)
  match parse_source_file(tokens, file_path) {
    Ok(source_file) =>
      match bind_source_file(source_file) {
        Ok(bound) => check_source_file(bound)
        Err(diagnostics) => Err(diagnostics)
      }
    Err(diagnostics) => Err(diagnostics)
  }
}

///|
/// Type check TypeScript source code with additional options
/// Returns a TypedFile on success or diagnostics on failure
pub fn type_check_with_options(
  source : String,
  file_path : String,
  no_implicit_any? : Bool = false,
) -> CheckResult {
  let tokens = scan_all_v2(source, file_path)
  match parse_source_file(tokens, file_path) {
    Ok(source_file) =>
      match bind_source_file(source_file) {
        Ok(bound) =>
          check_source_file_with_options(bound, false, ES2015, no_implicit_any~)
        Err(diagnostics) => Err(diagnostics)
      }
    Err(diagnostics) => Err(diagnostics)
  }
}

///|
/// Type check TypeScript source code and return all diagnostics
/// (including warnings) even on success
pub fn type_check_with_all_diagnostics(
  source : String,
  file_path : String,
) -> (TypedFile?, Array[Diagnostic]) {
  let tokens = scan_all_v2(source, file_path)
  match parse_source_file(tokens, file_path) {
    Ok(source_file) =>
      match bind_source_file(source_file) {
        Ok(bound) =>
          match check_source_file(bound) {
            Ok(typed_file) => (Some(typed_file), typed_file.diagnostics)
            Err(diagnostics) => (None, diagnostics)
          }
        Err(diagnostics) => (None, diagnostics)
      }
    Err(diagnostics) => (None, diagnostics)
  }
}

///|
/// Get the inferred type for a node by its key from a TypedFile
pub fn get_node_type(typed_file : TypedFile, node_key : String) -> Type? {
  typed_file.types.get(node_key)
}

///|
/// Format a diagnostic as a human-readable string
pub fn format_diagnostic(d : Diagnostic) -> String {
  let category = match d.category {
    Error => "error"
    Warning => "warning"
    Message => "message"
    Suggestion => "suggestion"
  }
  let loc = d.location
  let line = loc.start.line.to_string()
  let col = loc.start.column.to_string()
  loc.file_path + ":" + line + ":" + col + ": " + category + ": " + d.message
}
