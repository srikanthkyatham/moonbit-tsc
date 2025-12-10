// Unit tests for function declaration return type inference
// Tests the conservative return type inference added to infer_function_declaration_type()

// ============================================================================
// Object Literal Return Type Inference Tests
// ============================================================================

///|
test "infer object literal return type - simple properties" {
  let source =
    #|function getPoint() {
    #|    return { x: 10, y: 20 };
    #|}
    #|const test: string = getPoint().x;

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have TS2322: Type 'number' is not assignable to type 'string'
  assert_true(has_error(diagnostics, 2322))
}

///|
test "infer object literal return type - nested objects" {
  let source =
    #|function getData() {
    #|    return { user: { name: "Alice", age: 30 } };
    #|}
    #|const test: number = getData().user.name;

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have TS2322: Type 'string' is not assignable to type 'number'
  assert_true(has_error(diagnostics, 2322))
}

///|
test "infer object literal return type - correct usage passes" {
  let source =
    #|function getConfig() {
    #|    return { port: 8080, host: "localhost" };
    #|}
    #|const port: number = getConfig().port;
    #|const host: string = getConfig().host;

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // No errors - types match
  assert_eq(diagnostics.length(), 0)
}

// ============================================================================
// Array Literal Return Type Inference Tests
// ============================================================================

///|
test "infer array literal return type" {
  let source =
    #|function getNumbers() {
    #|    return [1, 2, 3];
    #|}
    #|const test: string = getNumbers()[0];

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have TS2322: Type 'number' is not assignable to type 'string'
  assert_true(has_error(diagnostics, 2322))
}

///|
test "infer array literal return type - correct usage passes" {
  let source =
    #|function getItems() {
    #|    return ["a", "b", "c"];
    #|}
    #|const item: string = getItems()[0];

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // No errors - types match
  assert_eq(diagnostics.length(), 0)
}

// ============================================================================
// Primitive Literal Return Type Inference Tests
// ============================================================================

///|
test "infer string literal return type" {
  let source =
    #|function getMessage() {
    #|    return "hello";
    #|}
    #|const test: number = getMessage();

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have TS2322: Type 'string' is not assignable to type 'number'
  assert_true(has_error(diagnostics, 2322))
}

///|
test "infer number literal return type" {
  let source =
    #|function getValue() {
    #|    return 42;
    #|}
    #|const test: string = getValue();

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have TS2322: Type 'number' is not assignable to type 'string'
  assert_true(has_error(diagnostics, 2322))
}

///|
test "infer boolean literal return type" {
  let source =
    #|function getFlag() {
    #|    return true;
    #|}
    #|const test: number = getFlag();

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have TS2322: Type 'boolean' is not assignable to type 'number'
  assert_true(has_error(diagnostics, 2322))
}

// ============================================================================
// Cases Where Inference Should NOT Happen (Conservative Approach)
// ============================================================================

///|
test "no inference for function call expressions" {
  let source =
    #|function helper() {
    #|    return { value: 42 };
    #|}
    #|function outer() {
    #|    return helper();
    #|}
    #|const test: string = outer().value;

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // No error - outer() returns 'any' because it returns a function call
  // This is conservative to avoid scope/ordering issues
  assert_eq(diagnostics.length(), 0)
}

///|
test "no inference for identifier expressions" {
  let source =
    #|function getResult() {
    #|    const obj = { x: 0 };
    #|    return obj;
    #|}
    #|const test: string = getResult().x;

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // No error - returns 'any' because it returns an identifier
  assert_eq(diagnostics.length(), 0)
}

///|
test "no inference when return not in last statement" {
  let source =
    #|function conditional() {
    #|    if (true) {
    #|        return { x: 0 };
    #|    }
    #|}
    #|const test: string = conditional().x;

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // No error - return is not the last statement of the function body
  assert_eq(diagnostics.length(), 0)
}

// ============================================================================
// ES5For-of8 Pattern - The Original Bug Report
// ============================================================================

///|
test "ES5For-of8 pattern - PropertyAccessExpression in for-of" {
  let source =
    #|function foo() {
    #|    return { x: 0 };
    #|}
    #|for (foo().x of ['a', 'b', 'c']) {
    #|    var p = foo().x;
    #|}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have TS2322: Type 'string' is not assignable to type 'number'
  // This was the original failing test case
  assert_true(has_error(diagnostics, 2322))
}

///|
test "simple PropertyAccessExpression in for-of with inferred type" {
  let source =
    #|function getObj() {
    #|    return { count: 0 };
    #|}
    #|for (getObj().count of [1, 2, 3]) {
    #|    var x = getObj().count;
    #|}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // No errors - types match (number to number)
  assert_eq(diagnostics.length(), 0)
}

// ============================================================================
// Edge Cases and Special Scenarios
// ============================================================================

///|
test "function with explicit return type - no inference needed" {
  let source =
    #|function explicit(): { x: number } {
    #|    return { x: 0 };
    #|}
    #|const test: string = explicit().x;

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have TS2322 from explicit type, not inference
  assert_true(has_error(diagnostics, 2322))
}

///|
test "empty function body - returns any" {
  let source =
    #|function empty() {
    #|}
    #|const test: number = empty();

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // No error - empty function returns 'any'
  assert_eq(diagnostics.length(), 0)
}

///|
test "function with no return statement - returns any" {
  let source =
    #|function noReturn() {
    #|    console.log("hello");
    #|}
    #|const test: number = noReturn();

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // No error - function without return returns 'any'
  assert_eq(diagnostics.length(), 0)
}

///|
test "return with no expression - returns any" {
  let source =
    #|function emptyReturn() {
    #|    return;
    #|}
    #|const test: number = emptyReturn();

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // No error - return with no expression is 'any'
  assert_eq(diagnostics.length(), 0)
}

// ============================================================================
// Circular Reference Protection Tests
// ============================================================================

///|
test "recursive function - no infinite loop" {
  let source =
    #|function factorial(n: number) {
    #|    if (n <= 1) return 1;
    #|    return n * factorial(n - 1);
    #|}
    #|const result = factorial(5);

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // No crash - circular reference protection prevents infinite recursion
  // The function returns 'any' because it calls itself
  assert_eq(diagnostics.length(), 0)
}

///|
test "mutually recursive functions - no infinite loop" {
  let source =
    #|function isEven(n: number): boolean {
    #|    if (n === 0) return true;
    #|    return isOdd(n - 1);
    #|}
    #|function isOdd(n: number): boolean {
    #|    if (n === 0) return false;
    #|    return isEven(n - 1);
    #|}
    #|const test = isEven(4);

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // No crash - explicit return types prevent inference issues
  assert_eq(diagnostics.length(), 0)
}

// ============================================================================
// Complex Property Access Patterns
// ============================================================================

///|
test "chained property access with inferred type" {
  let source =
    #|function getDeep() {
    #|    return { a: { b: { c: "value" } } };
    #|}
    #|const test: number = getDeep().a.b.c;

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have TS2322: Type 'string' is not assignable to type 'number'
  assert_true(has_error(diagnostics, 2322))
}

///|
test "array access with inferred array type" {
  let source =
    #|function getMatrix() {
    #|    return [[1, 2], [3, 4]];
    #|}
    #|const test: string = getMatrix()[0][0];

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have TS2322: Type 'number' is not assignable to type 'string'
  assert_true(has_error(diagnostics, 2322))
}

///|
test "mixed object and array access" {
  let source =
    #|function getData() {
    #|    return { items: [{ id: 1 }, { id: 2 }] };
    #|}
    #|const test: string = getData().items[0].id;

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have TS2322: Type 'number' is not assignable to type 'string'
  assert_true(has_error(diagnostics, 2322))
}
