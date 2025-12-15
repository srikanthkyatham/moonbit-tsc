// For-Of Error Validation Tests
// Tests for parser-level error validation in for-of statements

///|
/// Helper function to check source code
fn check_for_of_errors(source : String) -> Array[@compiler.Diagnostic] {
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  let diags = match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      // Check parse diagnostics first (for parser-level validations like TS1188, TS2480)
      if source_file.parse_diagnostics.length() > 0 {
        source_file.parse_diagnostics
      } else {
        // Then proceed with binding and checking
        match @compiler.bind_source_file(source_file) {
          Ok(bound) =>
            match @compiler.check_source_file(bound) {
              Ok(_) => []
              Err(diagnostics) => diagnostics
            }
          Err(diagnostics) => diagnostics
        }
      }
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

// ============================================================================
// TS2451: Cannot redeclare block-scoped variable in destructuring
// ============================================================================

///|
test "for-of with duplicate bindings in array pattern - should error TS2451" {
  let source =
    #|for (let [v, v] of [[]]) {}
  let diags = check_for_of_errors(source)
  assert_true(has_error_code(diags, 2451))
}

///|
test "for-of with duplicate bindings in nested pattern - should error TS2300/TS2451" {
  let source =
    #|for (const [[x, y], [x, z]] of []) {}
  let diags = check_for_of_errors(source)
  // Can be either TS2300 (binder) or TS2451 (checker)
  assert_true(has_error_code(diags, 2300) || has_error_code(diags, 2451))
}

///|
test "for-of with duplicate bindings in object pattern - should error TS2451" {
  let source =
    #|for (let {a, a} of []) {}
  let diags = check_for_of_errors(source)
  assert_true(has_error_code(diags, 2451))
}

///|
test "for-of with no duplicate bindings - should pass" {
  let source =
    #|for (let [x, y] of [[]]) {}
  let diags = check_for_of_errors(source)
  assert_false(has_error_code(diags, 2451))
}

///|
test "for-of with var and duplicate bindings - should pass (var allows duplicates)" {
  let source =
    #|for (var [v, v] of [[]]) {}
  let diags = check_for_of_errors(source)
  assert_false(has_error_code(diags, 2451))
}

///|
test "for-of with complex nested pattern no duplicates - should pass" {
  let source =
    #|for (const {a: {b, c}, d: [e, f]} of []) {}
  let diags = check_for_of_errors(source)
  assert_false(has_error_code(diags, 2451))
}

// ============================================================================
// TS2304: Cannot find name (undeclared variable)
// ============================================================================

///|
test "for-of with bare identifier that doesn't exist - should error TS2304" {
  let source =
    #|for (v of [1, 2, 3]) {}
  let diags = check_for_of_errors(source)
  assert_true(has_error_code(diags, 2304))
}

///|
test "for-of with bare identifier declared in body - should error TS2304" {
  let source =
    #|for (v of [0]) {
    #|  let v;
    #|}
  let diags = check_for_of_errors(source)
  assert_true(has_error_code(diags, 2304))
}

///|
test "for-of with bare identifier pre-declared - should pass" {
  let source =
    #|let v: number;
    #|for (v of [1, 2, 3]) {}
  let diags = check_for_of_errors(source)
  assert_false(has_error_code(diags, 2304))
}

///|
test "for-of with let declaration - should not trigger TS2304" {
  let source =
    #|for (let v of [1, 2, 3]) {}
  let diags = check_for_of_errors(source)
  assert_false(has_error_code(diags, 2304))
}

// ============================================================================
// TS2481: Cannot initialize outer scoped variable
// ============================================================================

///|
test "for-of with var in body conflicting with let binding - should error TS2481" {
  let source =
    #|for (let v of []) {
    #|  var v;
    #|}
  let diags = check_for_of_errors(source)
  assert_true(has_error_code(diags, 2481))
}

///|
test "for-of with var initializer in body conflicting with let - should error TS2481" {
  let source =
    #|for (let v of []) {
    #|  var v = 0;
    #|}
  let diags = check_for_of_errors(source)
  assert_true(has_error_code(diags, 2481))
}

///|
test "for-of with var in body conflicting with const binding - should error TS2481" {
  let source =
    #|for (const v of []) {
    #|  var v;
    #|}
  let diags = check_for_of_errors(source)
  assert_true(has_error_code(diags, 2481))
}

///|
test "for-of with let in body (no conflict) - should pass" {
  let source =
    #|for (let v of []) {
    #|  let x;
    #|}
  let diags = check_for_of_errors(source)
  assert_false(has_error_code(diags, 2481))
}

///|
test "for-of with var binding (not nested) - should pass" {
  let source =
    #|for (var v of []) {
    #|  var x;
    #|}
  let diags = check_for_of_errors(source)
  assert_false(has_error_code(diags, 2481))
}

// ============================================================================
// TS2448: Block-scoped variable used before its declaration
// ============================================================================

///|
test "for-of where expression references the declared variable - should error TS2448" {
  let source =
    #|let v = [1];
    #|for (let v of v) {
    #|  v;
    #|}
  let diags = check_for_of_errors(source)
  assert_true(has_error_code(diags, 2448))
}

///|
test "for-of with const where expression references itself - should error TS2448" {
  let source =
    #|let arr = [1, 2];
    #|for (const arr of arr) {
    #|  console.log(arr);
    #|}
  let diags = check_for_of_errors(source)
  assert_true(has_error_code(diags, 2448))
}

///|
test "for-of with different names - should pass" {
  let source =
    #|let arr = [1];
    #|for (let v of arr) {
    #|  v;
    #|}
  let diags = check_for_of_errors(source)
  assert_false(has_error_code(diags, 2448))
}

///|
test "for-of with var where expression references itself - should pass (var allows this)" {
  let source =
    #|var v = [1];
    #|for (var v of v) {
    #|  v;
    #|}
  let diags = check_for_of_errors(source)
  assert_false(has_error_code(diags, 2448))
}

///|
test "for-of with destructuring - should not trigger TS2448 for different name" {
  let source =
    #|let v = [[1, 2]];
    #|for (let [a, b] of v) {
    #|  console.log(a, b);
    #|}
  let diags = check_for_of_errors(source)
  assert_false(has_error_code(diags, 2448))
}
