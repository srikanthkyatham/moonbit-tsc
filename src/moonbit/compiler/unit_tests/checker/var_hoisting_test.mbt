///|
/// Unit tests for var hoisting and TS2403 redeclaration checking

// ============================================================================
// ES5For-of7 - The original test case
// ============================================================================

///|
test "TS2403 - ES5For-of7 var redeclaration type mismatch" {
  // This is the exact test case from ES5For-of7.ts
  let source =
    #|for (var w of []) {
    #|    var x = w;
    #|}
    #|
    #|for (var v of []) {
    #|    var x = [w, v];
    #|}

  let result = check_for_of(source)
  let diagnostics = get_diagnostics(result)
  
  // Should have TS2403 error: 'x' redeclared with different type
  // First: x: any (from w)
  // Second: x: any[] (from [w, v])
  assert_true(has_error(diagnostics, 2403))
}

// ============================================================================
// Basic Var Hoisting Tests
// ============================================================================

///|
test "var hoisting - multiple blocks same function" {
  let source =
    #|function test() {
    #|    {
    #|        var x: number = 1;
    #|    }
    #|    {
    #|        var x: number = 2;  // OK - same type
    #|    }
    #|}

  let result = check_for_of(source)
  
  // Should have no errors - both var x are number type
  assert_eq(error_count(result), 0)
}

///|
test "var hoisting - type mismatch across blocks" {
  let source =
    #|function test() {
    #|    {
    #|        var x: number = 1;
    #|    }
    #|    {
    #|        var x: string = "hello";  // TS2403
    #|    }
    #|}

  let result = check_for_of(source)
  let diagnostics = get_diagnostics(result)
  
  // Should have TS2403 error
  assert_true(has_error(diagnostics, 2403))
}

///|
test "var hoisting - accessible before declaration" {
  let source =
    #|function test() {
    #|    console.log(x);  // x is hoisted
    #|    var x = 10;
    #|}

  let result = check_for_of(source)
  
  // Should have no errors - var is hoisted
  assert_eq(error_count(result), 0)
}

///|
test "let/const not hoisted to function scope" {
  let source =
    #|function test() {
    #|    {
    #|        let x: number = 1;
    #|    }
    #|    {
    #|        let x: string = "hello";  // OK - different block scope
    #|    }
    #|}

  let result = check_for_of(source)
  
  // Should have no errors - let is block-scoped
  assert_eq(error_count(result), 0)
}

///|
test "var hoisting - for-of loops" {
  let source =
    #|for (var x: number of [1, 2]) {
    #|}
    #|for (var x: number of [3, 4]) {
    #|}

  let result = check_for_of(source)
  
  // Should have no errors - same type
  assert_eq(error_count(result), 0)
}

///|
test "var hoisting - for-of type mismatch" {
  let source =
    #|for (var x: number of [1, 2]) {
    #|}
    #|for (var x: string of ["a", "b"]) {
    #|}

  let result = check_for_of(source)
  let diagnostics = get_diagnostics(result)

  // Should have TS2403 error
  assert_true(has_error(diagnostics, 2403))
}

// ============================================================================
// Nested For-of Loop Tests
// ============================================================================

///|
test "var hoisting - nested for-of same type" {
  let source =
    #|for (var x: number of [1, 2]) {
    #|    for (var x: number of [3, 4]) {
    #|        console.log(x);
    #|    }
    #|}

  let result = check_for_of(source)

  // Should have no errors - both var x are number type and hoisted to same scope
  assert_eq(error_count(result), 0)
}

///|
test "var hoisting - nested for-of type mismatch" {
  let source =
    #|for (var x: number of [1, 2]) {
    #|    for (var x: string of ["a", "b"]) {
    #|        console.log(x);
    #|    }
    #|}

  let result = check_for_of(source)
  let diagnostics = get_diagnostics(result)

  // Should have TS2403 error - var x redeclared with different type
  assert_true(has_error(diagnostics, 2403))
}

///|
test "var hoisting - triple nested same type" {
  let source =
    #|for (var i: number of [1, 2]) {
    #|    for (var j: number of [3, 4]) {
    #|        for (var k: number of [5, 6]) {
    #|            console.log(i, j, k);
    #|        }
    #|    }
    #|}

  let result = check_for_of(source)

  // Should have no errors - all different variable names
  assert_eq(error_count(result), 0)
}

///|
test "var hoisting - triple nested with redeclaration" {
  let source =
    #|for (var x: number of [1, 2]) {
    #|    for (var y: string of ["a"]) {
    #|        for (var x: boolean of [true]) {
    #|            console.log(x);
    #|        }
    #|    }
    #|}

  let result = check_for_of(source)
  let diagnostics = get_diagnostics(result)

  // Should have TS2403 error - innermost x redeclared with different type
  assert_true(has_error(diagnostics, 2403))
}

///|
test "var hoisting - nested with var accessible from inner loop" {
  let source =
    #|for (var outer: number of [1, 2]) {
    #|    for (var inner: string of ["a"]) {
    #|        console.log(outer);  // outer is accessible due to hoisting
    #|        console.log(inner);
    #|    }
    #|    console.log(outer);  // outer still accessible
    #|}

  let result = check_for_of(source)

  // Should have no errors - var hoisting makes variables accessible
  assert_eq(error_count(result), 0)
}

///|
test "var hoisting - nested in function scope" {
  let source =
    #|function test() {
    #|    for (var x: number of [1, 2]) {
    #|        for (var x: number of [3, 4]) {
    #|            console.log(x);
    #|        }
    #|    }
    #|}

  let result = check_for_of(source)

  // Should have no errors - both var x hoisted to function scope with same type
  assert_eq(error_count(result), 0)
}

///|
test "var hoisting - nested in function with type mismatch" {
  let source =
    #|function test() {
    #|    for (var x: number of [1, 2]) {
    #|        {
    #|            for (var x: string of ["a"]) {
    #|                console.log(x);
    #|            }
    #|        }
    #|    }
    #|}

  let result = check_for_of(source)
  let diagnostics = get_diagnostics(result)

  // Should have TS2403 error - var x redeclared with different type in function scope
  assert_true(has_error(diagnostics, 2403))
}

///|
test "var hoisting - multiple vars in nested loops" {
  let source =
    #|for (var x: number of [1, 2]) {
    #|    for (var y: string of ["a"]) {
    #|        for (var x: number of [3, 4]) {
    #|            for (var y: string of ["b"]) {
    #|                console.log(x, y);
    #|            }
    #|        }
    #|    }
    #|}

  let result = check_for_of(source)

  // Should have no errors - same types for x and y across all levels
  assert_eq(error_count(result), 0)
}
