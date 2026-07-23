// Exit code computation for the CLI.
//
// Convention (established in commit c0f0bda "fix: Add proper exit codes for
// compilation errors"): the CLI exits with 1 when compilation produced any
// error (failed files or error diagnostics, even if emit succeeded), and 0
// on a clean compile. All terminal code paths (text mode, JSON mode, project
// mode, build mode) must go through compute_exit_code so the behavior stays
// consistent.

///|
/// Exit code for a clean compilation
pub const EXIT_SUCCESS : Int = 0

///|
/// Exit code when compilation produced errors
pub const EXIT_FAILURE : Int = 1

///|
/// Check whether a diagnostic string represents an error.
/// Prefers the structured diagnostic parse; falls back to substring
/// matching for diagnostics that don't follow the standard
/// `file:line:col - category TSnnnn: message` format.
fn is_error_diagnostic(diag : String) -> Bool {
  match parse_diagnostic_string(diag) {
    Some(info) => info.category == "error"
    None => diag.contains(" - error ")
  }
}

///|
/// Check whether a diagnostic string represents a warning.
fn is_warning_diagnostic(diag : String) -> Bool {
  match parse_diagnostic_string(diag) {
    Some(info) => info.category == "warning"
    None => diag.contains(" - warning ")
  }
}

///|
/// Compute the process exit code for a compilation summary.
/// Returns EXIT_FAILURE when any file failed to compile or any error
/// diagnostic was produced (type errors don't stop emit, matching tsc
/// behavior, but must still fail the process). Returns EXIT_SUCCESS
/// otherwise (warnings alone don't fail the build).
pub fn compute_exit_code(summary : @coordinator.CompilationSummary) -> Int {
  if summary.failed > 0 {
    return EXIT_FAILURE
  }
  for result in summary.results {
    for diag in result.diagnostics {
      if is_error_diagnostic(diag) {
        return EXIT_FAILURE
      }
    }
  }
  EXIT_SUCCESS
}

///|
/// Exit the process with a non-zero code if the summary contains errors.
fn exit_if_errors(summary : @coordinator.CompilationSummary) -> Unit {
  let code = compute_exit_code(summary)
  if code != EXIT_SUCCESS {
    exit(code)
  }
}
