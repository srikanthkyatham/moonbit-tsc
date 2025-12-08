// For-Of Error Validation Tests
// Tests for parser-level error validation in for-of statements

///|
/// Helper function to check source code
fn check_for_of_errors(source : String) -> Array[@compiler.Diagnostic] {
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  let diags = match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) => 
          match @compiler.check_source_file(bound) {
            Ok(_) => []
            Err(diagnostics) => diagnostics
          }
        Err(diagnostics) => diagnostics
      }
    Err(diagnostics) => diagnostics
  }
  diags
}

// ============================================================================
// TS1188: Only single variable declaration in for-of
// ============================================================================

///|
test "for-of with single declaration - should pass" {
  let source =
    #|for (const x of [1, 2, 3]) {
    #|  console.log(x);
    #|}
  let diags = check_for_of_errors(source)
  assert_false(has_error_code(diags, 1188))
}

///|
test "for-of with excess declarations - should error TS1188" {
  let source =
    #|for (const a, b of [1, 2, 3]) {
    #|}
  let diags = check_for_of_errors(source)
  assert_true(has_error_code(diags, 1188))
}

///|
test "for-of with excess declarations and destructuring - should error TS1188" {
  let source =
    #|for (const a, { b } of [1]) {
    #|}
  let diags = check_for_of_errors(source)
  assert_true(has_error_code(diags, 1188))
}

///|
test "for-of with let and multiple declarations - should error TS1188" {
  let source =
    #|for (let x, y of []) {
    #|}
  let diags = check_for_of_errors(source)
  assert_true(has_error_code(diags, 1188))
}

///|
test "for-of with var and multiple declarations - should error TS1188" {
  let source =
    #|for (var x, y, z of []) {
    #|}
  let diags = check_for_of_errors(source)
  assert_true(has_error_code(diags, 1188))
}

// ============================================================================
// TS2480: 'let' not allowed in let/const declarations
// ============================================================================

///|
test "for-of with let 'let' - should error TS2480" {
  let source =
    #|for (let let of []) {}
  let diags = check_for_of_errors(source)
  assert_true(has_error_code(diags, 2480))
}

///|
test "for-of with const 'let' - should error TS2480" {
  let source =
    #|for (const let of []) {}
  let diags = check_for_of_errors(source)
  assert_true(has_error_code(diags, 2480))
}

///|
test "for-of with var 'let' - should pass (var allows 'let')" {
  let source =
    #|for (var let of []) {}
  let diags = check_for_of_errors(source)
  assert_false(has_error_code(diags, 2480))
}

///|
test "for-of with let 'x' - should pass" {
  let source =
    #|for (let x of []) {}
  let diags = check_for_of_errors(source)
  assert_false(has_error_code(diags, 2480))
}

///|
test "for-of with let 'await' - should pass (await is allowed)" {
  let source =
    #|for (let await of []) {}
  let diags = check_for_of_errors(source)
  assert_false(has_error_code(diags, 2480))
}

///|
test "for-of with let 'yield' - should pass (yield is allowed)" {
  let source =
    #|for (let yield of []) {}
  let diags = check_for_of_errors(source)
  assert_false(has_error_code(diags, 2480))
}

// ============================================================================
// Combined Tests
// ============================================================================

///|
test "for-of with single let declaration - should pass both validations" {
  let source =
    #|for (let x of [1, 2, 3]) {
    #|  console.log(x);
    #|}
  let diags = check_for_of_errors(source)
  assert_false(has_error_code(diags, 1188))
  assert_false(has_error_code(diags, 2480))
}

///|
test "for-of with single const declaration - should pass both validations" {
  let source =
    #|for (const x of [1, 2, 3]) {
    #|  console.log(x);
    #|}
  let diags = check_for_of_errors(source)
  assert_false(has_error_code(diags, 1188))
  assert_false(has_error_code(diags, 2480))
}

///|
test "for-of with destructuring - should pass both validations" {
  let source =
    #|for (const [x, y] of [[1, 2]]) {
    #|  console.log(x, y);
    #|}
  let diags = check_for_of_errors(source)
  assert_false(has_error_code(diags, 1188))
  assert_false(has_error_code(diags, 2480))
}

///|
test "for-of with object destructuring - should pass both validations" {
  let source =
    #|for (const {x, y} of [{x: 1, y: 2}]) {
    #|  console.log(x, y);
    #|}
  let diags = check_for_of_errors(source)
  assert_false(has_error_code(diags, 1188))
  assert_false(has_error_code(diags, 2480))
}

// ============================================================================
// Edge Cases
// ============================================================================

///|
test "for-of with bare identifier - should not trigger parser errors" {
  let source =
    #|let x: number;
    #|for (x of [1, 2, 3]) {
    #|  console.log(x);
    #|}
  let diags = check_for_of_errors(source)
  assert_false(has_error_code(diags, 1188))
  assert_false(has_error_code(diags, 2480))
}

///|
test "for-of with property access - should not trigger parser errors" {
  let source =
    #|const obj = { prop: 0 };
    #|for (obj.prop of [1, 2, 3]) {
    #|  console.log(obj.prop);
    #|}
  let diags = check_for_of_errors(source)
  assert_false(has_error_code(diags, 1188))
  assert_false(has_error_code(diags, 2480))
}

///|
test "regular for loop with multiple declarations - should not trigger TS1188" {
  let source =
    #|for (let i = 0, j = 0; i < 10; i++) {
    #|  console.log(i, j);
    #|}
  let diags = check_for_of_errors(source)
  assert_false(has_error_code(diags, 1188))
}
