// Tuple and array-literal contextual assignability tests (TS2322 / TS2345)
//
// Rules verified against tsc:
// - array -> tuple: only assignable when the tuple has no required elements
//   and has a rest element (unbounded), e.g. number[] -> [...number[]]
// - tuple -> tuple: length rules (fewer than required, more than allowed),
//   optional and rest elements, element-wise assignability
// - array literals contextually typed against tuple targets (including
//   spread elements, nested tuples, return positions, and call arguments)

// ============================================================================
// Array -> Tuple assignability
// ============================================================================

///|
test "tuple-assign: array not assignable to tuple with required elements" {
  let source =
    #|declare var arr: number[];
    #|let t: [number] = arr;
  let result = check_tuple_array(source)
  assert_true(has_error_code(get_diagnostics(result), 2322))
}

///|
test "tuple-assign: array not assignable to bounded optional tuple" {
  // Target allows only 1 element(s) but source may have more
  let source =
    #|declare var arr: number[];
    #|let t: [number?] = arr;
  let result = check_tuple_array(source)
  assert_true(has_error_code(get_diagnostics(result), 2322))
}

///|
test "tuple-assign: array not assignable to empty tuple" {
  let source =
    #|declare var arr: number[];
    #|let t: [] = arr;
  let result = check_tuple_array(source)
  assert_true(has_error_code(get_diagnostics(result), 2322))
}

///|
test "tuple-assign: array assignable to open-ended rest tuple" {
  let source =
    #|declare var arr: number[];
    #|let t: [...number[]] = arr;
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

///|
test "tuple-assign: array with wrong element type not assignable to rest tuple" {
  let source =
    #|declare var arr: string[];
    #|let t: [...number[]] = arr;
  let result = check_tuple_array(source)
  assert_true(has_error_code(get_diagnostics(result), 2322))
}

// ============================================================================
// Tuple -> Array assignability
// ============================================================================

///|
test "tuple-assign: tuple assignable to array of compatible element type" {
  let source =
    #|declare var tup: [number, number];
    #|let a: number[] = tup;
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

///|
test "tuple-assign: tuple not assignable to array of incompatible element type" {
  let source =
    #|declare var tup: [number, string];
    #|let a: number[] = tup;
  let result = check_tuple_array(source)
  assert_true(has_error_code(get_diagnostics(result), 2322))
}

// ============================================================================
// Tuple -> Tuple length rules
// ============================================================================

///|
test "tuple-assign: literal with too few elements" {
  let source =
    #|let t: [number, string] = [1];
  let result = check_tuple_array(source)
  assert_true(has_error_code(get_diagnostics(result), 2322))
}

///|
test "tuple-assign: literal with excess elements" {
  let source =
    #|let t: [number, string] = [1, "a", true];
  let result = check_tuple_array(source)
  assert_true(has_error_code(get_diagnostics(result), 2322))
}

///|
test "tuple-assign: longer declared tuple not assignable to shorter tuple" {
  let source =
    #|declare var src: [number, string, boolean];
    #|let t: [number, string] = src;
  let result = check_tuple_array(source)
  assert_true(has_error_code(get_diagnostics(result), 2322))
}

///|
test "tuple-assign: matching literal has no errors" {
  let source =
    #|let t: [number, string] = [1, "a"];
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

///|
test "tuple-assign: element type mismatch" {
  let source =
    #|let t: [number] = ["a"];
  let result = check_tuple_array(source)
  assert_true(has_error_code(get_diagnostics(result), 2322))
}

///|
test "tuple-assign: incompatible declared tuple element" {
  let source =
    #|declare var src: [string];
    #|let t: [number] = src;
  let result = check_tuple_array(source)
  assert_true(has_error_code(get_diagnostics(result), 2322))
}

// ============================================================================
// Optional tuple elements
// ============================================================================

///|
test "tuple-assign: optional element may be omitted" {
  let source =
    #|let t: [number, string?] = [1];
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

///|
test "tuple-assign: optional element accepts a value" {
  let source =
    #|let t: [number, string?] = [1, "a"];
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

///|
test "tuple-assign: optional element accepts undefined" {
  let source =
    #|let t: [number, string?] = [1, undefined];
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

///|
test "tuple-assign: excess beyond optional elements" {
  // Source has 3 element(s) but target allows only 2
  let source =
    #|let t: [number, string?] = [1, "a", 2];
  let result = check_tuple_array(source)
  assert_true(has_error_code(get_diagnostics(result), 2322))
}

///|
test "tuple-assign: optional source element has no match for required target" {
  let source =
    #|declare var src: [number, string?];
    #|let t: [number, string] = src;
  let result = check_tuple_array(source)
  assert_true(has_error_code(get_diagnostics(result), 2322))
}

// ============================================================================
// Rest tuple elements
// ============================================================================

///|
test "tuple-assign: rest tuple accepts matching extra elements" {
  let source =
    #|let t: [number, ...string[]] = [1, "a", "b"];
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

///|
test "tuple-assign: rest tuple accepts just the fixed elements" {
  let source =
    #|let t: [number, ...string[]] = [1];
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

///|
test "tuple-assign: rest tuple rejects incompatible extra element" {
  let source =
    #|let t: [number, ...string[]] = [1, "a", 2];
  let result = check_tuple_array(source)
  assert_true(has_error_code(get_diagnostics(result), 2322))
}

///|
test "tuple-assign: source rest tuple not assignable to bounded tuple" {
  // Target requires 2 element(s) but source may have fewer
  let source =
    #|declare var src: [number, ...number[]];
    #|let t: [number, number] = src;
  let result = check_tuple_array(source)
  assert_true(has_error_code(get_diagnostics(result), 2322))
}

// ============================================================================
// Spread elements in tuple-contextual array literals
// ============================================================================

///|
test "tuple-assign: spreading a tuple splices its elements" {
  let source =
    #|declare var pair: [number, number];
    #|let t: [number, number] = [...pair];
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

///|
test "tuple-assign: spreading a tuple into an array literal" {
  let source =
    #|declare var pair: [number, number];
    #|let a: number[] = [...pair];
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

///|
test "tuple-assign: spreading an array into a bounded tuple errors" {
  // [number, ...number[]] may have fewer than 2 elements
  let source =
    #|declare var nums: number[];
    #|let t: [number, number] = [1, ...nums];
  let result = check_tuple_array(source)
  assert_true(has_error_code(get_diagnostics(result), 2322))
}

///|
test "tuple-assign: spreading an array into a rest tuple is fine" {
  let source =
    #|declare var strs: string[];
    #|let t: [number, ...string[]] = [1, ...strs];
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

// ============================================================================
// Nested tuples
// ============================================================================

///|
test "tuple-assign: nested array literal typed against nested tuple" {
  let source =
    #|var t: [[string | number], boolean] = [[1], true];
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

///|
test "tuple-assign: nested tuple element mismatch" {
  let source =
    #|var t: [[string], boolean] = [[1], true];
  let result = check_tuple_array(source)
  assert_true(has_error_code(get_diagnostics(result), 2322))
}

// ============================================================================
// Return-position contextual typing
// ============================================================================

///|
test "tuple-assign: function declaration returning a tuple literal" {
  let source =
    #|function f(): [number, string] { return [1, "a"]; }
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

///|
test "tuple-assign: function declaration returning too few elements" {
  let source =
    #|function f(): [number, string] { return [1]; }
  let result = check_tuple_array(source)
  assert_true(has_error_code(get_diagnostics(result), 2322))
}

///|
test "tuple-assign: function expression with contextual tuple return" {
  let source =
    #|var g: () => [number, string] = function () { return [1, "a"]; };
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

///|
test "tuple-assign: arrow with expression body and tuple return context" {
  let source =
    #|var h: () => [number, string] = () => [1, "a"];
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

///|
test "tuple-assign: arrow with block body and tuple return context" {
  let source =
    #|var h: () => [number, string] = () => { return [1, "a"]; };
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

// ============================================================================
// Assignment expressions
// ============================================================================

///|
test "tuple-assign: assignment expression with tuple-typed target" {
  let source =
    #|declare var t: [number, string];
    #|t = [1, "a"];
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

///|
test "tuple-assign: assignment expression with too few elements" {
  let source =
    #|declare var t: [number, string];
    #|t = [1];
  let result = check_tuple_array(source)
  assert_true(has_error_code(get_diagnostics(result), 2322))
}

// ============================================================================
// Call arguments against tuple parameters (TS2345)
// ============================================================================

///|
test "tuple-assign: call with matching tuple literal argument" {
  let source =
    #|declare function f(t: [number, string]): void;
    #|f([1, "a"]);
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

///|
test "tuple-assign: call with short tuple literal argument" {
  let source =
    #|declare function f(t: [number, string]): void;
    #|f([1]);
  let result = check_tuple_array(source)
  assert_true(has_error_code(get_diagnostics(result), 2345))
}

///|
test "tuple-assign: call with incompatible tuple literal argument" {
  let source =
    #|declare function f(t: [number, string]): void;
    #|f(["a", "b"]);
  let result = check_tuple_array(source)
  assert_true(has_error_code(get_diagnostics(result), 2345))
}

///|
test "tuple-assign: rest parameter of tuples accepts matching literals" {
  let source =
    #|declare function g(...pairs: [number, string][]): void;
    #|g([1, "a"], [2, "b"]);
  let result = check_tuple_array(source)
  assert_eq(error_count(result), 0)
}

///|
test "tuple-assign: rest parameter of tuples rejects short literal" {
  let source =
    #|declare function g(...pairs: [number, string][]): void;
    #|g([1]);
  let result = check_tuple_array(source)
  assert_true(has_error_code(get_diagnostics(result), 2345))
}
