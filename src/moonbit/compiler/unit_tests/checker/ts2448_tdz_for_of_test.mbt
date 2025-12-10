// Unit tests for TS2448 Temporal Dead Zone validation in for-of loops
// Tests detection of block-scoped variables used before declaration in iterable expressions

// Uses helper functions from diagnostic_code_test.mbt and for_of_test.mbt:
// - check_source(source: String) -> CheckResult
// - get_diagnostics(result: CheckResult) -> Array[Diagnostic]
// - has_error(diagnostics: Array[Diagnostic], code: Int) -> Bool

///|
test "TS2448 - simple TDZ violation (let v of [v])" {
  let source =
    #|for (let v of [v]) { }

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have 1 TS2448 error - v used before declaration
  assert_true(has_error(diagnostics, 2448))

  let ts2448_errors = diagnostics.iter().filter(fn(d) { d.code == 2448 }).to_array()
  assert_eq(ts2448_errors.length(), 1)
  assert_true(ts2448_errors[0].message.contains("Block-scoped variable"))
  assert_true(ts2448_errors[0].message.contains("used before its declaration"))
}

///|
test "TS2448 - nested for-of with TDZ (ES5For-of17)" {
  let source =
    #|for (let v of []) {
    #|    v;
    #|    for (let v of [v]) {
    #|        var x = v;
    #|        v++;
    #|    }
    #|}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have 1 TS2448 error at the inner for-of
  assert_true(has_error(diagnostics, 2448))

  let ts2448_errors = diagnostics.iter().filter(fn(d) { d.code == 2448 }).to_array()
  assert_eq(ts2448_errors.length(), 1)
}

///|
test "TS2448 - const with TDZ violation" {
  let source =
    #|for (const v of [v]) { }

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have 1 TS2448 error
  assert_true(has_error(diagnostics, 2448))
}

///|
test "No TS2448 - var does not have TDZ" {
  let source =
    #|for (var v of [v]) { }

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // var doesn't have TDZ, so should NOT have TS2448
  // (will have TS2304 instead - variable not found)
  let ts2448_errors = diagnostics.iter().filter(fn(d) { d.code == 2448 }).to_array()
  assert_eq(ts2448_errors.length(), 0)
}

///|
test "TS2448 - TDZ in complex expression" {
  let source =
    #|for (let x of [x + 1]) { }

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have 1 TS2448 error
  assert_true(has_error(diagnostics, 2448))
}

///|
test "TS2448 - TDZ in object literal" {
  let source =
    #|for (let v of [{prop: v}]) { }

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have 1 TS2448 error
  assert_true(has_error(diagnostics, 2448))
}

///|
test "TS2448 - TDZ in function call" {
  let source =
    #|function helper(x: any) { return [x]; }
    #|for (let v of helper(v)) { }

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have 1 TS2448 error
  assert_true(has_error(diagnostics, 2448))
}

///|
test "No TS2448 - using outer variable" {
  let source =
    #|let v = [1, 2, 3];
    #|for (let x of v) { }

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // No TDZ violation - v is declared outside the loop
  let ts2448_errors = diagnostics.iter().filter(fn(d) { d.code == 2448 }).to_array()
  assert_eq(ts2448_errors.length(), 0)
}

///|
test "No TS2448 - using different variable" {
  let source =
    #|const arr = [1, 2, 3];
    #|for (let v of arr) { }

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // No TDZ violation - arr is different from v
  let ts2448_errors = diagnostics.iter().filter(fn(d) { d.code == 2448 }).to_array()
  assert_eq(ts2448_errors.length(), 0)
}

///|
test "No TS2448 - variable used in body is OK" {
  let source =
    #|for (let v of [1, 2, 3]) {
    #|    v;
    #|}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Using v in the loop body is fine - it's declared by then
  let ts2448_errors = diagnostics.iter().filter(fn(d) { d.code == 2448 }).to_array()
  assert_eq(ts2448_errors.length(), 0)
}

///|
test "TS2448 - destructuring with TDZ" {
  let source =
    #|for (let [a, b] of [[a, b]]) { }

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have 2 TS2448 errors - one for each variable
  let ts2448_errors = diagnostics.iter().filter(fn(d) { d.code == 2448 }).to_array()
  assert_eq(ts2448_errors.length(), 2)
}

///|
test "TS2448 - object destructuring with TDZ" {
  let source =
    #|for (let {x, y} of [{x: x, y: y}]) { }

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have 2 TS2448 errors
  let ts2448_errors = diagnostics.iter().filter(fn(d) { d.code == 2448 }).to_array()
  assert_eq(ts2448_errors.length(), 2)
}

///|
test "TS2448 - TDZ in nested array" {
  let source =
    #|for (let v of [[v]]) { }

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have 1 TS2448 error
  assert_true(has_error(diagnostics, 2448))
}

///|
test "TS2448 - TDZ with property access" {
  let source =
    #|for (let v of [v.length]) { }

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have 1 TS2448 error
  assert_true(has_error(diagnostics, 2448))
}

///|
test "TS2448 - TDZ with method call" {
  let source =
    #|for (let v of [v.toString()]) { }

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have 1 TS2448 error
  assert_true(has_error(diagnostics, 2448))
}

///|
test "TS2448 - multiple nested loops with TDZ" {
  let source =
    #|for (let v of []) {
    #|    for (let w of [w]) {
    #|        v; w;
    #|    }
    #|}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have 1 TS2448 error for w
  assert_true(has_error(diagnostics, 2448))

  let ts2448_errors = diagnostics.iter().filter(fn(d) { d.code == 2448 }).to_array()
  assert_eq(ts2448_errors.length(), 1)
}

///|
test "TS2448 - TDZ with ternary operator" {
  let source =
    #|for (let v of [true ? v : 0]) { }

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have 1 TS2448 error
  assert_true(has_error(diagnostics, 2448))
}

///|
test "TS2448 - TDZ with binary operator" {
  let source =
    #|for (let x of [x + x]) { }

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have 2 TS2448 errors - one for each usage
  let ts2448_errors = diagnostics.iter().filter(fn(d) { d.code == 2448 }).to_array()
  assert_eq(ts2448_errors.length(), 2)
}

///|
test "TS2448 - TDZ with unary operator" {
  let source =
    #|for (let x of [!x]) { }

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have 1 TS2448 error
  assert_true(has_error(diagnostics, 2448))
}

///|
test "No TS2448 - const declared before loop" {
  let source =
    #|const v = [1, 2, 3];
    #|for (const x of v) { }

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // No TDZ violation
  let ts2448_errors = diagnostics.iter().filter(fn(d) { d.code == 2448 }).to_array()
  assert_eq(ts2448_errors.length(), 0)
}

///|
test "TS2448 - TDZ with typeof operator" {
  let source =
    #|for (let x of [typeof x]) { }

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have 1 TS2448 error
  assert_true(has_error(diagnostics, 2448))
}

///|
test "TS2448 - deeply nested TDZ" {
  let source =
    #|for (let a of []) {
    #|    for (let b of []) {
    #|        for (let c of [c]) {
    #|            a; b; c;
    #|        }
    #|    }
    #|}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have 1 TS2448 error for c
  assert_true(has_error(diagnostics, 2448))

  let ts2448_errors = diagnostics.iter().filter(fn(d) { d.code == 2448 }).to_array()
  assert_eq(ts2448_errors.length(), 1)
}

///|
test "TS2448 - TDZ with array spread" {
  let source =
    #|for (let v of [...[v]]) { }

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have 1 TS2448 error
  assert_true(has_error(diagnostics, 2448))
}

///|
test "TS2448 - TDZ in template literal" {
  let source =
    #|for (let v of [`${v}`]) { }

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have 1 TS2448 error
  assert_true(has_error(diagnostics, 2448))
}

///|
test "No TS2448 - same name in different scope" {
  let source =
    #|let v = [1, 2, 3];
    #|for (let x of v) {
    #|    let v = 5;
    #|    v;
    #|}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // No TDZ violation - outer v is used in for-of, inner v is in body
  let ts2448_errors = diagnostics.iter().filter(fn(d) { d.code == 2448 }).to_array()
  assert_eq(ts2448_errors.length(), 0)
}

///|
test "TS2448 - TDZ with element access" {
  let source =
    #|for (let v of [v[0]]) { }

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have 1 TS2448 error
  assert_true(has_error(diagnostics, 2448))
}

///|
test "TS2448 - TDZ with new expression" {
  let source =
    #|for (let v of [new Array(v)]) { }

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have 1 TS2448 error
  assert_true(has_error(diagnostics, 2448))
}

///|
test "No TS2448 - literals in expression" {
  let source =
    #|for (let v of [1, 2, 3]) { }

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // No TDZ violation - no reference to v
  let ts2448_errors = diagnostics.iter().filter(fn(d) { d.code == 2448 }).to_array()
  assert_eq(ts2448_errors.length(), 0)
}

///|
test "TS2448 - TDZ with logical operator" {
  let source =
    #|for (let x of [x && true]) { }

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have 1 TS2448 error
  assert_true(has_error(diagnostics, 2448))
}
