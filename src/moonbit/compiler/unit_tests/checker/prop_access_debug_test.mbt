///|
test "PropertyAccessExpression - simple object property (should pass)" {
  // Test that PropertyAccessExpression type checking works for simple object properties
  let source =
    #|var obj = { x: 0 };
    #|for (obj.x of ['a', 'b', 'c']) {
    #|}

  let result = check_for_of(source)
  let diagnostics = get_diagnostics(result)

  // Should have TS2322: Type 'string' is not assignable to type 'number'
  assert_true(has_error(diagnostics, 2322))
}

///|
test "PropertyAccessExpression - function call result (ES5For-of8)" {
  // Test that PropertyAccessExpression type checking works for function call results
  let source =
    #|function foo() {
    #|    return { x: 0 };
    #|}
    #|for (foo().x of ['a', 'b', 'c']) {
    #|    var p = foo().x;
    #|}

  let result = check_for_of(source)
  let diagnostics = get_diagnostics(result)

  // Should have TS2322: Type 'string' is not assignable to type 'number'
  assert_true(has_error(diagnostics, 2322))
}
