// Tuple Array Type Inference Tests
// Tests for the array-of-tuples contextual typing improvements

///|
/// Helper function to check source code
fn check_tuple_array(source : String) -> @compiler.CheckResult {
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) => @compiler.check_source_file(bound)
        Err(diagnostics) => Err(diagnostics)
      }
    Err(diagnostics) => Err(diagnostics)
  }
}

// ============================================================================
// Basic Array-of-Tuples Tests
// ============================================================================

///|
test "simple array of tuples - should pass" {
  let source =
    #|var array: [number, string][] = [[0, "hello"]];
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

///|
test "array of tuples with multiple elements - should pass" {
  let source =
    #|var array: [number, string][] = [[0, "a"], [1, "b"], [2, "c"]];
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

///|
test "array of tuples with union types - should pass" {
  let source =
    #|var array: [number, string | boolean][] = [[0, "hello"], [1, true]];
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

///|
test "array of tuples with three elements - should pass" {
  let source =
    #|var array: [number, string, boolean][] = [[0, "test", true], [1, "foo", false]];
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

// ============================================================================
// For-Of with Array-of-Tuples Tests
// ============================================================================

///|
test "for-of with array of tuples - should pass" {
  let source =
    #|var array: [number, string][] = [[0, "hello"]];
    #|for (var [num, str] of array) {
    #|  console.log(num, str);
    #|}
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

///|
test "for-of with tuple union types - should pass" {
  let source =
    #|var array: [number, string | boolean | symbol][] = [[0, ""], [0, true], [1, Symbol()]];
    #|for (var [num, strBoolSym] of array) {
    #|  num;
    #|  strBoolSym;
    #|}
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

///|
test "for-of with const destructuring - should pass" {
  let source =
    #|var array: [number, string][] = [[1, "a"], [2, "b"]];
    #|for (const [num, str] of array) {
    #|  console.log(num, str);
    #|}
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

///|
test "for-of with let destructuring - should pass" {
  let source =
    #|var array: [number, string][] = [[1, "a"], [2, "b"]];
    #|for (let [num, str] of array) {
    #|  console.log(num, str);
    #|}
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

// ============================================================================
// Type Mismatch Tests (commented out - tuple validation not yet complete)
// ============================================================================

// Note: These tests are commented out because tuple element type validation
// and length checking are not yet fully implemented. The contextual typing
// fix enables tuple inference but doesn't add comprehensive tuple validation.

// test "array of tuples with wrong element type - should error" {
//   // String where number expected
//   let source =
//     #|var array: [number, string][] = [["hello", "world"]];
//   let result = check_tuple_array(source)
//   assert_true(error_count(result) > 0)
// }

// test "array of tuples with wrong length - should error" {
//   // 3 elements where 2 expected
//   let source =
//     #|var array: [number, string][] = [[0, "hello", true]];
//   let result = check_tuple_array(source)
//   assert_true(error_count(result) > 0)
// }

// ============================================================================
// Complex Tuple Types Tests
// ============================================================================

///|
test "nested tuples - should pass" {
  let source =
    #|var array: [[number, string], boolean][] = [[[0, "a"], true], [[1, "b"], false]];
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

///|
test "tuple with optional elements - should pass" {
  let source =
    #|var array: [number, string?][] = [[0, "hello"], [1], [2, "world"]];
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

// ============================================================================
// Mixed Declaration Tests
// ============================================================================

///|
test "const array of tuples - should pass" {
  let source =
    #|const array: [number, string][] = [[0, "hello"], [1, "world"]];
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

///|
test "let array of tuples - should pass" {
  let source =
    #|let array: [number, string][] = [[0, "hello"], [1, "world"]];
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

// ============================================================================
// Regression Tests
// ============================================================================

///|
test "regression: for-of44.ts from conformance suite" {
  // This is the exact test case from for-of44.ts
  let source =
    #|var array: [number, string | boolean | symbol][] = [[0, ""], [0, true], [1, Symbol()]];
    #|for (var [num, strBoolSym] of array) {
    #|  num;
    #|  strBoolSym;
    #|}
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

///|
test "regression: simple tuple array assignment" {
  // This was the simplified reproduction case
  let source =
    #|var array: [number, string][] = [[0, "hello"]];
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

// ============================================================================
// Edge Cases
// ============================================================================

///|
test "empty array of tuples - should pass" {
  let source =
    #|var array: [number, string][] = [];
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

///|
test "single element tuple array - should pass" {
  let source =
    #|var array: [number][] = [[0], [1], [2]];
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

///|
test "array of tuples with any - should pass" {
  let source =
    #|var array: [number, any][] = [[0, "hello"], [1, 42], [2, true]];
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

///|
test "array of tuples without initializer - should pass" {
  let source =
    #|var array: [number, string][];
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

///|
test "array of tuples with spread - should pass" {
  let source =
    #|var arr1: [number, string][] = [[0, "a"]];
    #|var arr2: [number, string][] = [[1, "b"]];
    #|var combined: [number, string][] = [...arr1, ...arr2];
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

// ============================================================================
// Without Type Annotation Tests (should still work)
// ============================================================================

///|
test "array without annotation - should infer" {
  let source =
    #|var array = [[0, "hello"]];
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

///|
test "for-of without tuple annotation - should infer" {
  let source =
    #|var array = [[0, "hello"], [1, "world"]];
    #|for (var [num, str] of array) {
    #|  console.log(num, str);
    #|}
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}
