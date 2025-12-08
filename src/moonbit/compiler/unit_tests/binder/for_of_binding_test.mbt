// For-of and For-in Statement Binding Tests
// Tests for variable binding in for-of and for-in loops

///|
/// Helper function to parse and bind source code
fn parse_and_bind_for_of(
  source : String,
) -> Result[@compiler.BoundSourceFile, Array[@compiler.Diagnostic]] {
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) => @compiler.bind_source_file(source_file)
    Err(_) => Err([])
  }
}

// ============================================================================
// For-of Statement Tests
// ============================================================================

///|
test "for-of with var declaration - basic" {
  // var declarations in for-of loops should bind
  let source =
    #|for (var x of [1, 2, 3]) {
    #|  console.log(x);
    #|}
  let result = parse_and_bind_for_of(source)
  match result {
    Ok(bound) => {
      // Should have no errors
      assert_eq(bound.diagnostics.length(), 0)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "for-of with var declaration - hoisting" {
  // var should be accessible before the loop due to hoisting
  let source =
    #|v; // Should be accessible
    #|for (var v of [1, 2, 3]) {
    #|  console.log(v);
    #|}
  let result = parse_and_bind_for_of(source)
  match result {
    Ok(bound) => {
      // Should have no errors - v is hoisted
      assert_eq(bound.diagnostics.length(), 0)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "for-of with let declaration" {
  // let declarations in for-of loops
  let source =
    #|for (let x of [1, 2, 3]) {
    #|  console.log(x);
    #|}
  let result = parse_and_bind_for_of(source)
  match result {
    Ok(bound) => {
      assert_eq(bound.diagnostics.length(), 0)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "for-of with const declaration" {
  // const declarations in for-of loops
  let source =
    #|for (const x of [1, 2, 3]) {
    #|  console.log(x);
    #|}
  let result = parse_and_bind_for_of(source)
  match result {
    Ok(bound) => {
      assert_eq(bound.diagnostics.length(), 0)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "for-of with array destructuring" {
  // Array destructuring in for-of loop variable
  let source =
    #|for (var [a, b] of [[1, 2], [3, 4]]) {
    #|  console.log(a, b);
    #|}
  let result = parse_and_bind_for_of(source)
  match result {
    Ok(bound) => {
      assert_eq(bound.diagnostics.length(), 0)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "for-of with object destructuring" {
  // Object destructuring in for-of loop variable
  let source =
    #|for (var {x, y} of [{x: 1, y: 2}]) {
    #|  console.log(x, y);
    #|}
  let result = parse_and_bind_for_of(source)
  match result {
    Ok(bound) => {
      assert_eq(bound.diagnostics.length(), 0)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "for-of with nested destructuring" {
  // Nested destructuring in for-of
  let source =
    #|for (var {a, b: [c, d]} of [{a: 1, b: [2, 3]}]) {
    #|  console.log(a, c, d);
    #|}
  let result = parse_and_bind_for_of(source)
  match result {
    Ok(bound) => {
      assert_eq(bound.diagnostics.length(), 0)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "for-of with existing variable" {
  // Using an already-declared variable in for-of
  let source =
    #|var x: any;
    #|for (x of [1, 2, 3]) {
    #|  console.log(x);
    #|}
  let result = parse_and_bind_for_of(source)
  match result {
    Ok(bound) => {
      assert_eq(bound.diagnostics.length(), 0)
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// For-in Statement Tests
// ============================================================================

///|
test "for-in with var declaration" {
  // var declarations in for-in loops
  let source =
    #|for (var key in {a: 1, b: 2}) {
    #|  console.log(key);
    #|}
  let result = parse_and_bind_for_of(source)
  match result {
    Ok(bound) => {
      assert_eq(bound.diagnostics.length(), 0)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "for-in with var declaration - hoisting" {
  // var in for-in should be hoisted
  let source =
    #|key; // Should be accessible
    #|for (var key in {a: 1}) {
    #|  console.log(key);
    #|}
  let result = parse_and_bind_for_of(source)
  match result {
    Ok(bound) => {
      assert_eq(bound.diagnostics.length(), 0)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "for-in with let declaration" {
  // let declarations in for-in loops
  let source =
    #|for (let key in {a: 1}) {
    #|  console.log(key);
    #|}
  let result = parse_and_bind_for_of(source)
  match result {
    Ok(bound) => {
      assert_eq(bound.diagnostics.length(), 0)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "for-in with const declaration" {
  // const declarations in for-in loops
  let source =
    #|for (const key in {a: 1}) {
    #|  console.log(key);
    #|}
  let result = parse_and_bind_for_of(source)
  match result {
    Ok(bound) => {
      assert_eq(bound.diagnostics.length(), 0)
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Conformance Test Cases
// ============================================================================

///|
test "conformance: for-of22 - var hoisting with iterator" {
  // From for-of22.ts - var should be accessible before loop
  let source =
    #|class Foo { }
    #|class FooIterator {
    #|    next() {
    #|        return {
    #|            value: new Foo,
    #|            done: false
    #|        };
    #|    }
    #|    [Symbol.iterator]() {
    #|        return this;
    #|    }
    #|}
    #|
    #|v;
    #|for (var v of new FooIterator) {
    #|
    #|}
  let result = parse_and_bind_for_of(source)
  match result {
    Ok(bound) => {
      // Should have no errors - v is hoisted
      assert_eq(bound.diagnostics.length(), 0)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "conformance: for-of38 - destructuring in for-of" {
  // From for-of38.ts - destructuring with Map
  let source =
    #|var map = new Map([["", true]]);
    #|for (var [k, v] of map) {
    #|    k;
    #|    v;
    #|}
  let result = parse_and_bind_for_of(source)
  match result {
    Ok(bound) => {
      // Should have no errors - k and v are bound
      assert_eq(bound.diagnostics.length(), 0)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "for-of with rest element in destructuring" {
  // Rest element in array destructuring
  let source =
    #|for (var [first, ...rest] of [[1, 2, 3], [4, 5, 6]]) {
    #|  console.log(first, rest);
    #|}
  let result = parse_and_bind_for_of(source)
  match result {
    Ok(bound) => {
      assert_eq(bound.diagnostics.length(), 0)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "for-of multiple loops with same var name" {
  // Multiple for-of loops with same var name (should merge)
  let source =
    #|for (var x of [1, 2]) {
    #|  console.log(x);
    #|}
    #|for (var x of [3, 4]) {
    #|  console.log(x);
    #|}
  let result = parse_and_bind_for_of(source)
  match result {
    Ok(bound) => {
      // Should have no errors - var declarations merge
      assert_eq(bound.diagnostics.length(), 0)
    }
    Err(_) => assert_true(false)
  }
}
