///|
/// Unit tests for return type inference
/// Tests the new feature that infers return types from return statements
/// for functions without explicit return type annotations

// ============================================================================
// Single Return Type Inference Tests
// ============================================================================

///|
test "single return - infer number type" {
  let source =
    #|function getNumber() {
    #|  return 42;
    #|}
    #|
    #|const x: number = getNumber();

  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

///|
test "single return - infer string type" {
  let source =
    #|function getString() {
    #|  return "hello";
    #|}
    #|
    #|const x: string = getString();

  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

///|
test "single return - infer object literal type" {
  let source =
    #|function getObject() {
    #|  return { value: 42, name: "test" };
    #|}
    #|
    #|const obj = getObject();
    #|const x: number = obj.value;
    #|const y: string = obj.name;

  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

///|
test "single return - infer empty object type" {
  let source =
    #|function getEmpty() {
    #|  return {};
    #|}
    #|
    #|const obj = getEmpty();

  let result = check_for_of(source)
  // Empty object should be inferred correctly (not 'any')
  assert_eq(error_count(result), 0)
}

// ============================================================================
// Multiple Return Types (Union) Tests
// ============================================================================

///|
test "multiple returns - infer union type" {
  let source =
    #|function getNumberOrString(flag: boolean) {
    #|  if (flag) {
    #|    return 42;
    #|  } else {
    #|    return "hello";
    #|  }
    #|}
    #|
    #|const x: number | string = getNumberOrString(true);

  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

///|
test "multiple returns - union assigned to valid type" {
  let source =
    #|function getNumberOrString(flag: boolean) {
    #|  if (flag) {
    #|    return 42;
    #|  } else {
    #|    return "hello";
    #|  }
    #|}
    #|
    #|const x = getNumberOrString(true);
    #|const y: number | string = x;

  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

///|
test "multiple returns - three types create union" {
  let source =
    #|function getMultiple(n: number) {
    #|  if (n === 1) {
    #|    return 42;
    #|  } else if (n === 2) {
    #|    return "hello";
    #|  } else {
    #|    return true;
    #|  }
    #|}
    #|
    #|const x: number | string | boolean = getMultiple(1);

  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

// ============================================================================
// Void Return Tests
// ============================================================================

///|
test "void return - no expression" {
  let source =
    #|function doSomething() {
    #|  console.log("hello");
    #|  return;
    #|}
    #|
    #|const x: void = doSomething();

  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

///|
test "no return statement - defaults to any" {
  let source =
    #|function noReturn() {
    #|  console.log("hello");
    #|}
    #|
    #|const x: any = noReturn();

  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

///|
test "mixed void and value returns create union" {
  let source =
    #|function maybeReturn(flag: boolean) {
    #|  if (flag) {
    #|    return 42;
    #|  }
    #|  return;
    #|}
    #|
    #|const x: number | void = maybeReturn(true);

  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

// ============================================================================
// Method Return Type Inference Tests
// ============================================================================

///|
test "method in object literal - infer return type" {
  let source =
    #|const obj = {
    #|  getValue() {
    #|    return 42;
    #|  }
    #|};
    #|
    #|const x: number = obj.getValue();

  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

///|
test "Symbol.iterator method - infer empty object (test 869)" {
  let source =
    #|var obj = {
    #|    [Symbol.iterator]() {
    #|        return {};
    #|    }
    #|};
    #|
    #|for (var v of obj) { }

  let result = check_for_of(source)
  let diagnostics = get_diagnostics(result)
  // Should have TS2488 error - empty object has no next() method
  assert_true(has_error(diagnostics, 2488))
}

///|
test "computed method with string literal - infer return type" {
  let source =
    #|const obj = {
    #|  ["getValue"]() {
    #|    return "computed";
    #|  }
    #|};
    #|
    #|const x = obj["getValue"]();
    #|const y: string = x;

  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

// ============================================================================
// Nested Function Tests
// ============================================================================

///|
test "nested functions - each has its own inferred return type" {
  let source =
    #|function outer() {
    #|  function inner() {
    #|    return 42;
    #|  }
    #|  return inner();
    #|}
    #|
    #|const x: number = outer();

  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

///|
test "nested functions - different return types" {
  let source =
    #|function outer() {
    #|  function inner() {
    #|    return "hello";
    #|  }
    #|  return 42;
    #|}
    #|
    #|const x: number = outer();

  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

// ============================================================================
// Arrow Function Tests
// ============================================================================

///|
test "arrow function - infer return type from expression" {
  let source =
    #|const getNumber = () => 42;
    #|const x: number = getNumber();

  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

///|
test "arrow function - infer return type from block" {
  let source =
    #|const getNumber = () => {
    #|  return 42;
    #|};
    #|const x: number = getNumber();

  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

// ============================================================================
// Edge Cases Tests
// ============================================================================

///|
test "explicit return type annotation - should not infer" {
  let source =
    #|function getString(): string {
    #|  return "hello";
    #|}
    #|
    #|const x: string = getString();

  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

///|
test "explicit return type with wrong implementation - should error" {
  let source =
    #|function getString(): string {
    #|  return 42;
    #|}

  let result = check_for_of(source)
  let diagnostics = get_diagnostics(result)
  // Should have TS2322 error for type mismatch
  assert_true(has_error(diagnostics, 2322))
}

///|
test "recursive function - infer return type" {
  let source =
    #|function factorial(n: number) {
    #|  if (n <= 1) {
    #|    return 1;
    #|  }
    #|  return n * factorial(n - 1);
    #|}
    #|
    #|const x: number = factorial(5);

  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

///|
test "array return - infer array type" {
  let source =
    #|function getArray() {
    #|  return [1, 2, 3];
    #|}
    #|
    #|const x: number[] = getArray();

  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}

///|
test "complex object return - infer nested structure" {
  let source =
    #|function getComplex() {
    #|  return {
    #|    value: 42,
    #|    nested: {
    #|      name: "test"
    #|    }
    #|  };
    #|}
    #|
    #|const obj = getComplex();
    #|const x: number = obj.value;
    #|const y: string = obj.nested.name;

  let result = check_for_of(source)
  assert_eq(error_count(result), 0)
}
