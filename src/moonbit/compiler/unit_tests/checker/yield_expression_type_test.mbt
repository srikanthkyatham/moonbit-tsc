// Unit tests for yield expression type inference
// Tests that yield expressions return 'any' type (TNext) instead of yielded value type

// Uses helper functions from diagnostic_code_test.mbt:
// - check_source(source: String) -> CheckResult
// - get_diagnostics(result: CheckResult) -> Array[Diagnostic]
// - has_error(diagnostics: Array[Diagnostic], code: Int) -> Bool

///|
test "No TS2464 - yield in computed property (FunctionDeclaration9_es6)" {
  // This is the exact test case from FunctionDeclaration9_es6.ts
  let source =
    #|function * foo() {
    #|  var v = { [yield]: foo }
    #|}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should NOT have TS2464 - yield expressions have 'any' type which is valid for computed properties
  let ts2464_errors = diagnostics.iter().filter(fn(d) { d.code == 2464 }).to_array()
  assert_eq(ts2464_errors.length(), 0)
}

///|
test "No TS2464 - yield with value in computed property" {
  let source =
    #|function * foo() {
    #|  var v = { [yield 5]: "value" }
    #|}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should NOT have TS2464 - yield expressions have 'any' type
  let ts2464_errors = diagnostics.iter().filter(fn(d) { d.code == 2464 }).to_array()
  assert_eq(ts2464_errors.length(), 0)
}

///|
test "No TS2464 - yield in array element access" {
  let source =
    #|function * foo() {
    #|  var arr = [1, 2, 3];
    #|  var v = arr[yield];
    #|}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should NOT have TS2464 - yield has 'any' type which is valid for array index
  let ts2464_errors = diagnostics.iter().filter(fn(d) { d.code == 2464 }).to_array()
  assert_eq(ts2464_errors.length(), 0)
}

///|
test "No TS2464 - yield in property assignment" {
  let source =
    #|function * foo() {
    #|  var obj: any = {};
    #|  obj.prop = yield;
    #|}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should NOT have TS2464
  let ts2464_errors = diagnostics.iter().filter(fn(d) { d.code == 2464 }).to_array()
  assert_eq(ts2464_errors.length(), 0)
}

///|
test "No TS2464 - yield in binary expression" {
  let source =
    #|function * foo() {
    #|  var x = (yield) + 5;
    #|}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should NOT have TS2464
  let ts2464_errors = diagnostics.iter().filter(fn(d) { d.code == 2464 }).to_array()
  assert_eq(ts2464_errors.length(), 0)
}

///|
test "No TS2464 - yield in conditional expression" {
  let source =
    #|function * foo() {
    #|  var x = (yield) ? "yes" : "no";
    #|}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should NOT have TS2464
  let ts2464_errors = diagnostics.iter().filter(fn(d) { d.code == 2464 }).to_array()
  assert_eq(ts2464_errors.length(), 0)
}

///|
test "No TS2464 - yield in function call" {
  let source =
    #|function * foo() {
    #|  function bar(x: any) { return x; }
    #|  var x = bar(yield);
    #|}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should NOT have TS2464
  let ts2464_errors = diagnostics.iter().filter(fn(d) { d.code == 2464 }).to_array()
  assert_eq(ts2464_errors.length(), 0)
}

///|
test "No TS2464 - yield with expression in computed property" {
  let source =
    #|function * foo() {
    #|  var obj = { [yield "key"]: "value" };
    #|}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should NOT have TS2464
  let ts2464_errors = diagnostics.iter().filter(fn(d) { d.code == 2464 }).to_array()
  assert_eq(ts2464_errors.length(), 0)
}

///|
test "No TS2464 - bare yield in computed property" {
  let source =
    #|function * foo() {
    #|  var obj = { [yield]: 123 };
    #|}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should NOT have TS2464 - bare yield also has 'any' type
  let ts2464_errors = diagnostics.iter().filter(fn(d) { d.code == 2464 }).to_array()
  assert_eq(ts2464_errors.length(), 0)
}

///|
test "No TS2464 - yield in switch statement" {
  let source =
    #|function * foo() {
    #|  switch(yield) {
    #|    case 1: break;
    #|    default: break;
    #|  }
    #|}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should NOT have TS2464
  let ts2464_errors = diagnostics.iter().filter(fn(d) { d.code == 2464 }).to_array()
  assert_eq(ts2464_errors.length(), 0)
}

///|
test "TS1163 - yield outside generator function" {
  let source =
    #|function foo() {
    #|  var v = { [yield]: "test" };
    #|}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have TS1163: A 'yield' expression is only allowed in a generator body
  assert_true(has_error(diagnostics, 1163))
}

///|
test "No TS2464 - yield in for-of loop expression" {
  let source =
    #|function * foo() {
    #|  for (var x of yield) { }
    #|}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should NOT have TS2464 - yield has 'any' type
  // Note: May have other errors (TS2461) since 'any' is not iterable, but not TS2464
  let ts2464_errors = diagnostics.iter().filter(fn(d) { d.code == 2464 }).to_array()
  assert_eq(ts2464_errors.length(), 0)
}

///|
test "No TS2464 - yield in return statement" {
  let source =
    #|function * foo() {
    #|  return yield;
    #|}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should NOT have TS2464
  let ts2464_errors = diagnostics.iter().filter(fn(d) { d.code == 2464 }).to_array()
  assert_eq(ts2464_errors.length(), 0)
}

///|
test "No TS2464 - yield in variable declaration" {
  let source =
    #|function * foo() {
    #|  var x = yield;
    #|  var y = yield 5;
    #|}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should NOT have TS2464
  let ts2464_errors = diagnostics.iter().filter(fn(d) { d.code == 2464 }).to_array()
  assert_eq(ts2464_errors.length(), 0)
}

///|
test "No TS2464 - yield in object literal property" {
  let source =
    #|function * foo() {
    #|  var obj = { prop: yield };
    #|}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should NOT have TS2464
  let ts2464_errors = diagnostics.iter().filter(fn(d) { d.code == 2464 }).to_array()
  assert_eq(ts2464_errors.length(), 0)
}

///|
test "No TS2464 - yield in array literal" {
  let source =
    #|function * foo() {
    #|  var arr = [yield, yield 1, yield 2];
    #|}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should NOT have TS2464
  let ts2464_errors = diagnostics.iter().filter(fn(d) { d.code == 2464 }).to_array()
  assert_eq(ts2464_errors.length(), 0)
}

///|
test "No TS2464 - yield in template literal" {
  let source =
    #|function * foo() {
    #|  var str = `value: ${yield}`;
    #|}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should NOT have TS2464
  let ts2464_errors = diagnostics.iter().filter(fn(d) { d.code == 2464 }).to_array()
  assert_eq(ts2464_errors.length(), 0)
}

///|
test "No TS2464 - multiple yields in same expression" {
  let source =
    #|function * foo() {
    #|  var obj = { [yield]: yield, [yield]: yield };
    #|}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should NOT have TS2464 for any of the yield expressions
  let ts2464_errors = diagnostics.iter().filter(fn(d) { d.code == 2464 }).to_array()
  assert_eq(ts2464_errors.length(), 0)
}

///|
test "No TS2464 - yield in unary expression" {
  let source =
    #|function * foo() {
    #|  var x = !(yield);
    #|}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should NOT have TS2464
  let ts2464_errors = diagnostics.iter().filter(fn(d) { d.code == 2464 }).to_array()
  assert_eq(ts2464_errors.length(), 0)
}

///|
test "No TS2464 - yield in typeof expression" {
  let source =
    #|function * foo() {
    #|  var t = typeof (yield);
    #|}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should NOT have TS2464
  let ts2464_errors = diagnostics.iter().filter(fn(d) { d.code == 2464 }).to_array()
  assert_eq(ts2464_errors.length(), 0)
}
