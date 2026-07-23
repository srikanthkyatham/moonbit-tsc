// Unit tests for CLI exit code computation (whitebox tests: the cli
// package is a main package, so these run as part of the package itself
// and can exercise both public and private helpers).

///|
/// Build a CompileResponse for tests
fn make_response(
  file_path : String,
  success : Bool,
  diagnostics : Array[String],
) -> @protocol.CompileResponse {
  @protocol.CompileResponse::{
    file_path,
    success,
    javascript: "",
    source_map: None,
    declaration: None,
    diagnostics,
    compile_time_ms: 0L,
    module_types_json: None,
  }
}

///|
/// Build a CompilationSummary for tests
fn make_summary(
  results : Array[@protocol.CompileResponse],
  failed : Int,
) -> @coordinator.CompilationSummary {
  @coordinator.CompilationSummary::{
    results,
    total_files: results.length(),
    successful: results.length() - failed,
    failed,
    total_time_ms: 0L,
  }
}

///|
test "clean compile exits 0" {
  let summary = make_summary([make_response("a.ts", true, [])], 0)
  assert_eq(compute_exit_code(summary), EXIT_SUCCESS)
}

///|
test "empty summary exits 0" {
  let summary = make_summary([], 0)
  assert_eq(compute_exit_code(summary), EXIT_SUCCESS)
}

///|
test "type error with successful emit exits 1 (noEmit/type-check case)" {
  // TypeScript-style behavior: type errors don't stop emit, so the file
  // reports success=true, but the process must still exit non-zero.
  let summary = make_summary(
    [
      make_response("a.ts", true, [
        "a.ts:1:7 - error TS2322: Type 'string' is not assignable to type 'number'",
      ]),
    ],
    0,
  )
  assert_eq(compute_exit_code(summary), EXIT_FAILURE)
}

///|
test "failed file (parse error) exits 1" {
  let summary = make_summary(
    [
      make_response("a.ts", false, [
        "a.ts:1:1 - error TS1005: ';' expected",
      ]),
    ],
    1,
  )
  assert_eq(compute_exit_code(summary), EXIT_FAILURE)
}

///|
test "failed count without diagnostics still exits 1" {
  let summary = make_summary([make_response("a.ts", false, [])], 1)
  assert_eq(compute_exit_code(summary), EXIT_FAILURE)
}

///|
test "warnings only exit 0" {
  let summary = make_summary(
    [
      make_response("a.ts", true, [
        "a.ts:2:3 - warning TS6133: 'x' is declared but its value is never read",
      ]),
    ],
    0,
  )
  assert_eq(compute_exit_code(summary), EXIT_SUCCESS)
}

///|
test "error in one of many files exits 1" {
  let summary = make_summary(
    [
      make_response("a.ts", true, []),
      make_response("b.ts", true, [
        "b.ts:5:1 - error TS2304: Cannot find name 'foo'",
      ]),
      make_response("c.ts", true, []),
    ],
    0,
  )
  assert_eq(compute_exit_code(summary), EXIT_FAILURE)
}

///|
test "non-standard error diagnostic format still exits 1 (substring fallback)" {
  // Diagnostic without the file:line:col prefix can't be parsed by
  // parse_diagnostic_string; the " - error " fallback must catch it.
  let summary = make_summary(
    [make_response("a.ts", true, [" - error TS0000: something went wrong"])],
    0,
  )
  assert_eq(compute_exit_code(summary), EXIT_FAILURE)
}

///|
test "is_error_diagnostic recognizes standard format" {
  assert_eq(
    is_error_diagnostic(
      "/tmp/x.ts:1:7 - error TS2322: Type 'string' is not assignable to type 'number'",
    ),
    true,
  )
  assert_eq(
    is_error_diagnostic(
      "/tmp/x.ts:1:7 - warning TS6133: 'x' is declared but never read",
    ),
    false,
  )
}

///|
test "is_warning_diagnostic recognizes standard format" {
  assert_eq(
    is_warning_diagnostic(
      "/tmp/x.ts:1:7 - warning TS6133: 'x' is declared but never read",
    ),
    true,
  )
  assert_eq(
    is_warning_diagnostic(
      "/tmp/x.ts:1:7 - error TS2322: Type 'string' is not assignable to type 'number'",
    ),
    false,
  )
}
