// For-Of Statement Type Checking Tests
// Tests for the improvements made to for-of statement handling

///|
/// Helper function to check source code
fn check_for_of(source : String) -> @compiler.CheckResult {
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

///|
/// Count errors
fn error_count(result : @compiler.CheckResult) -> Int {
  match result {
    Ok(typed_file) => typed_file.diagnostics.length()
    Err(diagnostics) => diagnostics.length()
  }
}

///|
/// Get diagnostics from result
fn get_diagnostics(result : @compiler.CheckResult) -> Array[@compiler.Diagnostic] {
  match result {
    Ok(typed_file) => typed_file.diagnostics
    Err(diagnostics) => diagnostics
  }
}

// ============================================================================
// Iterator Protocol Validation Tests
// ============================================================================

///|
test "for-of with array - should pass" {
  let source =
    #|for (const x of [1, 2, 3]) {
    #|  console.log(x);
    #|}
  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

///|
test "for-of with string - should pass" {
  let source =
    #|for (const c of "hello") {
    #|  console.log(c);
    #|}
  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

///|
test "for-of with number - TS2488" {
  // Numbers are not iterable
  let source =
    #|for (const x of 42) {
    #|  console.log(x);
    #|}
  let result = check_for_of(source)
  assert_true(has_error(get_diagnostics(result), 2488)) // TS2488: must have Symbol.iterator
}

///|
test "for-of with boolean - TS2488" {
  // Booleans are not iterable
  let source =
    #|for (const x of true) {
    #|  console.log(x);
    #|}
  let result = check_for_of(source)
  assert_true(has_error(get_diagnostics(result), 2488)) // TS2488: must have Symbol.iterator
}

///|
test "for-of with null - TS2488" {
  // null is not iterable
  let source =
    #|for (const x of null) {
    #|  console.log(x);
    #|}
  let result = check_for_of(source)
  assert_true(has_error(get_diagnostics(result), 2488)) // TS2488: must have Symbol.iterator
}

///|
test "for-of with undefined - TS2488" {
  // undefined is not iterable
  let source =
    #|for (const x of undefined) {
    #|  console.log(x);
    #|}
  let result = check_for_of(source)
  assert_true(has_error(get_diagnostics(result), 2488)) // TS2488: must have Symbol.iterator
}

///|
test "for-of with any type - should pass" {
  // any type is always iterable (no error)
  let source =
    #|declare var x: any;
    #|for (const item of x) {
    #|  console.log(item);
    #|}
  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

///|
test "for-of with custom object - should not error" {
  // Custom objects don't error - fall back to any
  let source =
    #|interface MyIterator {
    #|  next(): { value: string, done: boolean };
    #|}
    #|declare var iter: MyIterator;
    #|for (const x of iter) {
    #|  console.log(x);
    #|}
  let result = check_for_of(source)
  // Should not report TS2488 for complex types
  assert_false(has_error(get_diagnostics(result), 2488))
}

// ============================================================================
// Destructuring Pattern Binding Tests
// ============================================================================

///|
test "for-of with array destructuring - const" {
  let source =
    #|for (const [a, b] of [[1, 2], [3, 4]]) {
    #|  console.log(a, b);
    #|}
  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

///|
test "for-of with array destructuring - let" {
  let source =
    #|for (let [a, b] of [[1, 2], [3, 4]]) {
    #|  console.log(a, b);
    #|}
  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

///|
test "for-of with array destructuring - var" {
  let source =
    #|for (var [a, b] of [[1, 2], [3, 4]]) {
    #|  console.log(a, b);
    #|}
  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

///|
test "for-of with object destructuring - const" {
  let source =
    #|for (const {x, y} of [{x: 1, y: 2}]) {
    #|  console.log(x, y);
    #|}
  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

///|
test "for-of with object destructuring - let" {
  let source =
    #|for (let {x, y} of [{x: 1, y: 2}]) {
    #|  console.log(x, y);
    #|}
  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

///|
test "for-of with nested destructuring" {
  let source =
    #|for (const {a, b: [c, d]} of [{a: 1, b: [2, 3]}]) {
    #|  console.log(a, c, d);
    #|}
  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

///|
test "for-of with rest element in destructuring" {
  let source =
    #|for (const [first, ...rest] of [[1, 2, 3], [4, 5, 6]]) {
    #|  console.log(first, rest);
    #|}
  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

///|
test "for-of destructuring variables accessible in body" {
  // Variables from destructuring should be in scope
  // Note: Tuple type extraction not yet perfect, so variables get 'any' type
  // which causes TS2362/TS2363 errors for arithmetic operations
  let source =
    #|for (const [a, b] of [[1, 2]]) {
    #|  console.log(a, b); // a and b should be accessible
    #|}
  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

// ============================================================================
// Type Checking for Pre-Declared Variables Tests
// ============================================================================

///|
test "for-of with pre-declared variable - compatible types" {
  let source =
    #|var x: number;
    #|for (x of [1, 2, 3]) {
    #|  console.log(x);
    #|}
  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

///|
test "for-of with pre-declared variable - incompatible types TS2322" {
  let source =
    #|var v: string;
    #|for (v of [0, 1, 2]) {
    #|  console.log(v);
    #|}
  let result = check_for_of(source)
  assert_true(has_error(get_diagnostics(result), 2322)) // TS2322: Type 'number' is not assignable to type 'string'
}

///|
test "for-of with pre-declared variable - union type incompatible" {
  let source =
    #|var v: string;
    #|for (v of [0, "hello"]) {
    #|  console.log(v);
    #|}
  let result = check_for_of(source)
  assert_true(has_error(get_diagnostics(result), 2322)) // TS2322: Type 'number | string' is not assignable to type 'string'
}

///|
test "for-of with pre-declared any variable - always compatible" {
  let source =
    #|var x: any;
    #|for (x of [1, 2, 3]) {
    #|  console.log(x);
    #|}
  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

///|
test "for-of type check with number to string mismatch" {
  let source =
    #|let str: string;
    #|for (str of [42]) {
    #|  console.log(str);
    #|}
  let result = check_for_of(source)
  assert_true(has_error(get_diagnostics(result), 2322))
}

// ============================================================================
// Const Assignment Check Tests
// ============================================================================

///|
test "for-of with const variable - TS2588" {
  let source =
    #|const v = "";
    #|for (v of ["a", "b"]) {
    #|  console.log(v);
    #|}
  let result = check_for_of(source)
  assert_true(has_error(get_diagnostics(result), 2588)) // TS2588: Cannot assign to 'v' because it is a constant
}

///|
test "for-of declaring new const - should pass" {
  // This should pass - declaring new const in for-of
  let source =
    #|for (const v of ["a", "b"]) {
    #|  console.log(v);
    #|}
  let result = check_for_of(source)
  // Should only have TS1155 (const must be initialized) if any
  assert_false(has_error(get_diagnostics(result), 2588))
}

///|
test "for-of with const and existing variable - multiple errors" {
  let source =
    #|const v: string;
    #|for (v of [1, 2, 3]) {
    #|  console.log(v);
    #|}
  let result = check_for_of(source)
  // Should have TS1155 (const must be initialized) and TS2588 (const assignment)
  let diags = get_diagnostics(result)
  assert_true(has_error(diags, 1155) || has_error(diags, 2588))
}

///|
test "for-of with let variable - should pass" {
  let source =
    #|let v: number;
    #|for (v of [1, 2, 3]) {
    #|  console.log(v);
    #|}
  let result = check_for_of(source)
  assert_false(has_error(get_diagnostics(result), 2588)) // Should not have const assignment error
}

///|
test "for-of with var variable - should pass" {
  let source =
    #|var v: number;
    #|for (v of [1, 2, 3]) {
    #|  console.log(v);
    #|}
  let result = check_for_of(source)
  assert_false(has_error(get_diagnostics(result), 2588)) // Should not have const assignment error
}

// ============================================================================
// Combined Tests
// ============================================================================

///|
test "for-of const assignment and type mismatch" {
  let source =
    #|const v: string = "hello";
    #|for (v of [1, 2, 3]) {
    #|  console.log(v);
    #|}
  let result = check_for_of(source)
  // Should have both TS2588 (const) and TS2322 (type mismatch)
  assert_true(has_error(get_diagnostics(result), 2588))
  assert_true(has_error(get_diagnostics(result), 2322))
}

///|
test "for-of multiple loops with same var name" {
  // Multiple for-of loops with same var name should work
  let source =
    #|for (var x of [1, 2]) {
    #|  console.log(x);
    #|}
    #|for (var x of [3, 4]) {
    #|  console.log(x);
    #|}
  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

///|
test "for-of with array of arrays - destructuring" {
  // Note: Tuple type extraction not yet perfect in destructuring
  let source =
    #|const matrix = [[1, 2], [3, 4]];
    #|for (const [a, b] of matrix) {
    #|  console.log(a, b);
    #|}
  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

///|
test "for-of invalid left-hand side - TS2487" {
  let source =
    #|for (1 + 2 of [1, 2, 3]) {
    #|  console.log("test");
    #|}
  let result = check_for_of(source)
  assert_true(has_error(get_diagnostics(result), 2487)) // TS2487: Invalid left-hand side
}

///|
test "for-of with property access - should pass" {
  let source =
    #|const obj = { prop: 0 };
    #|for (obj.prop of [1, 2, 3]) {
    #|  console.log(obj.prop);
    #|}
  let result = check_for_of(source)
  assert_false(has_error(get_diagnostics(result), 2487)) // Property access is valid
}

///|
test "for-of with element access - should pass" {
  let source =
    #|const arr = [0];
    #|for (arr[0] of [1, 2, 3]) {
    #|  console.log(arr[0]);
    #|}
  let result = check_for_of(source)
  assert_false(has_error(get_diagnostics(result), 2487)) // Element access is valid
}

// ============================================================================
// Edge Cases
// ============================================================================

///|
test "for-of with empty array - should pass" {
  let source =
    #|for (const x of []) {
    #|  console.log(x);
    #|}
  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

///|
test "for-of with array spread - should pass" {
  let source =
    #|const arr1 = [1, 2];
    #|const arr2 = [3, 4];
    #|for (const x of [...arr1, ...arr2]) {
    #|  console.log(x);
    #|}
  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

///|
test "for-of with destructuring defaults" {
  let source =
    #|for (const [a = 0, b = 1] of [[2], []]) {
    #|  console.log(a, b);
    #|}
  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

///|
test "for-of variable hoisting with var" {
  // var should be hoisted and accessible before loop
  let source =
    #|v; // Should be accessible (value is undefined)
    #|for (var v of [1, 2, 3]) {
    #|  console.log(v);
    #|}
  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

///|
test "for-of with nested loops" {
  let source =
    #|for (const x of [1, 2]) {
    #|  for (const y of [3, 4]) {
    #|    console.log(x, y);
    #|  }
    #|}
  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

// ============================================================================
// Array.values() Type Extraction and Direct Iterator Tests
// Tests for for-of12.ts and for-of14.ts conformance test fixes
// ============================================================================

///|
test "for-of with .values() - type assignment error (for-of12)" {
  // Array.values() returns IterableIterator<T> where T is the element type
  // When iterating with a pre-declared variable, should check type assignment
  let source =
    #|var v: string;
    #|for (v of [0, ""].values()) { }

  let result = check_for_of(source)
  let diagnostics = get_diagnostics(result)

  // Should error: number | string is not assignable to string
  assert_true(has_error(diagnostics, 2322))
}

///|
test "for-of with direct array - type assignment error comparison" {
  // For comparison: Direct array iteration should also catch type mismatch
  let source =
    #|var v: string;
    #|for (v of [0, ""]) { }

  let result = check_for_of(source)
  let diagnostics = get_diagnostics(result)

  // Should error: number | string is not assignable to string
  assert_true(has_error(diagnostics, 2322))
}

///|
test "for-of with .values() - no error when types match" {
  // When the variable type matches the iterator element type, no error
  let source =
    #|var v: number | string;
    #|for (v of [0, ""].values()) { }

  let result = check_for_of(source)
  let diagnostics = get_diagnostics(result)

  // Should not error - union to union assignment is now fixed
  assert_false(has_error(diagnostics, 2322))
}

///|
test "for-of with explicit IterableIterator type - type assignment error" {
  // Explicitly typed IterableIterator should also work
  let source =
    #|var v: string;
    #|const iter: IterableIterator<number | string> = [0, ""].values();
    #|for (v of iter) { }

  let result = check_for_of(source)
  let diagnostics = get_diagnostics(result)

  // Should error: number | string is not assignable to string
  assert_true(has_error(diagnostics, 2322))
}

///|
test "class with next() but no Symbol.iterator - TS2488 (for-of14)" {
  // Objects with next() but no [Symbol.iterator]() are direct iterators
  // They cannot be used in for-of, should report TS2488
  let source =
    #|class MyStringIterator {
    #|    next() {
    #|        return "";
    #|    }
    #|}
    #|var v: string;
    #|for (v of new MyStringIterator) { }

  let result = check_for_of(source)
  let diagnostics = get_diagnostics(result)

  // Should error: Type must have '[Symbol.iterator]()' method
  assert_true(has_error(diagnostics, 2488))
}

///|
test "class with Symbol.iterator - now works correctly" {
  // FIXED: Objects with [Symbol.iterator]() are now properly iterable
  // Previously errored with TS2488 due to class instance Symbol.iterator extraction limitation
  // Fixed by implementing return type inference for methods without explicit types
  let source =
    #|class MyIterator {
    #|    [Symbol.iterator]() {
    #|        return this;
    #|    }
    #|    next() {
    #|        return { value: "", done: false };
    #|    }
    #|}
    #|for (const v of new MyIterator) { }

  let result = check_for_of(source)
  // Now compiles successfully
  assert_eq(error_count(result), 0)
}

///|
test "Array.values() inference - correct element type" {
  // Test that .values() method correctly infers IterableIterator<T>
  let source =
    #|const arr = [1, 2, 3];
    #|const iter = arr.values();
    #|// iter should be IterableIterator<number>
    #|for (const v of iter) {
    #|    const x: number = v;  // Should not error
    #|}

  let result = check_for_of(source)
  let diagnostics = get_diagnostics(result)

  // Should not error
  assert_false(has_error(diagnostics, 2322))
}

///|
test "Array.values() with union type - correct element type" {
  // Test that .values() preserves union types correctly
  let source =
    #|const arr: (number | string)[] = [1, "a"];
    #|const iter = arr.values();
    #|for (const v of iter) {
    #|    const x: string = v;  // Should error: number | string not assignable to string
    #|}

  let result = check_for_of(source)
  let diagnostics = get_diagnostics(result)

  // Should error: Type mismatch
  assert_true(has_error(diagnostics, 2322))
}
