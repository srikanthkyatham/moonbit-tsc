///|
/// Unit tests for circular reference detection (TS7022/TS7023)
/// Tests the --noImplicitAny flag for detecting circular references in variable initializers

// ============================================================================
// Basic Circular Reference Tests (TS7022)
// ============================================================================

///|
test "circular reference - variable references itself in initializer" {
  let source =
    #|for (const v of v) { }

  let result = check_for_of_with_no_implicit_any(source)
  let diagnostics = get_diagnostics(result)
  // Should have TS7022 error for circular reference
  assert_true(has_error(diagnostics, 7022))
}

///|
test "circular reference - variable in computed property" {
  let source =
    #|for (const v of [v]) { }

  let result = check_for_of_with_no_implicit_any(source)
  let diagnostics = get_diagnostics(result)
  // Should have TS7022 error for circular reference
  assert_true(has_error(diagnostics, 7022))
}

///|
test "circular reference - variable in object literal" {
  let source =
    #|for (const v of { prop: v }) { }

  let result = check_for_of_with_no_implicit_any(source)
  let diagnostics = get_diagnostics(result)
  // Should have TS7022 error for circular reference
  assert_true(has_error(diagnostics, 7022))
}

///|
test "circular reference - variable in method call" {
  let source =
    #|for (const v of foo(v)) { }

  let result = check_for_of_with_no_implicit_any(source)
  let diagnostics = get_diagnostics(result)
  // Should have TS7022 error for circular reference
  assert_true(has_error(diagnostics, 7022))
}

// ============================================================================
// No Circular Reference Tests (Should Pass)
// ============================================================================

///|
test "no circular reference - variable from outer scope" {
  let source =
    #|const v = [1, 2, 3];
    #|for (const x of v) { }

  let result = check_for_of_with_no_implicit_any(source)
  // Should not have TS7022 error - v is in outer scope
  assert_eq(error_count(result), 0)
}

///|
test "no circular reference - different variable name" {
  let source =
    #|const arr = [1, 2, 3];
    #|for (const v of arr) { }

  let result = check_for_of_with_no_implicit_any(source)
  // Should not have TS7022 error
  assert_eq(error_count(result), 0)
}

// ============================================================================
// Method Return Type Tests (TS7023)
// ============================================================================

///|
test "circular reference in method - next returns variable" {
  let source =
    #|for (const v of { next() { return v; } }) { }

  let result = check_for_of_with_no_implicit_any(source)
  let diagnostics = get_diagnostics(result)
  // Should have TS7022 error for circular reference in method
  assert_true(has_error(diagnostics, 7022))
}

///|
test "circular reference in method - Symbol.iterator returns variable" {
  let source =
    #|for (const v of { [Symbol.iterator]() { return v; } }) { }

  let result = check_for_of_with_no_implicit_any(source)
  let diagnostics = get_diagnostics(result)
  // Should have TS7022 error for circular reference in method
  assert_true(has_error(diagnostics, 7022))
}

// ============================================================================
// Helper Functions
// ============================================================================

///|
/// Helper function to check source code with --noImplicitAny flag
fn check_for_of_with_no_implicit_any(source : String) -> @compiler.CheckResult {
  // Parse the source code
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) => {
          // Check with no_implicit_any enabled
          @compiler.check_source_file_with_options(
            bound,
            false,
            @compiler.ES2015,
            no_implicit_any=true,
          )
        }
        Err(diagnostics) => Err(diagnostics)
      }
    Err(diagnostics) => Err(diagnostics)
  }
}
