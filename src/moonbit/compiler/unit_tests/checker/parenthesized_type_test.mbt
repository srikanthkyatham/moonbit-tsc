// Unit tests for ParenthesizedType handling in type resolution
// Tests the fix for union types wrapped in parentheses like (number | string)[]

///|
test "Parenthesized union in array type parameter" {
  let source =
    #|function foo(arr: (number | string)[]) {
    #|  return arr;
    #|}
    #|foo([1, "hello"]);

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should compile without errors
  assert_eq(diagnostics.length(), 0)
}

///|
test "Parenthesized union in rest parameter" {
  let source =
    #|function foo(...arr: (number | string)[]) {
    #|  return arr;
    #|}
    #|foo(1, "hello");

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should compile without errors
  assert_eq(diagnostics.length(), 0)
}

///|
test "Rest parameter with union - type mismatch detected" {
  let source =
    #|function foo(...s: (symbol | number)[]) { }
    #|class StringIterator {
    #|  next() { return { value: "", done: false }; }
    #|  [Symbol.iterator]() { return this; }
    #|}
    #|foo(...new StringIterator);

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should detect TS2345: string is not assignable to symbol | number
  assert_true(has_error(diagnostics, 2345))
  assert_true(diagnostics.iter().any(fn(d) {
    d.message.contains("string") && d.message.contains("symbol | number")
  }))
}

///|
test "Parenthesized type in nested array" {
  let source =
    #|function foo(matrix: (number | string)[][]) {
    #|  return matrix;
    #|}
    #|foo([[1, "a"], [2, "b"]]);

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should compile without errors
  assert_eq(diagnostics.length(), 0)
}

///|
test "Multiple parenthesized types" {
  let source =
    #|function foo(a: (number | string)[], b: (boolean | null)[]) {
    #|  return [a, b];
    #|}
    #|foo([1, "x"], [true, null]);

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should compile without errors
  assert_eq(diagnostics.length(), 0)
}

///|
test "Parenthesized simple type" {
  let source =
    #|function foo(x: (number)) {
    #|  return x;
    #|}
    #|foo(42);

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should compile without errors - parentheses around simple types are valid
  assert_eq(diagnostics.length(), 0)
}
