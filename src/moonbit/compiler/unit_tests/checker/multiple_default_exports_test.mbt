// Unit tests for TS2528: A module cannot have multiple default exports

test "TS2528: multiple default exports - class and function" {
  let source =
    #|export default class Foo {}
    #|export default function bar() {}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have at least one TS2528 error
  let has_ts2528 = diagnostics.iter().any(fn(d) { d.code == 2528 })
  assert_true(has_ts2528)
}

test "TS2528: multiple default exports - function and variable" {
  let source =
    #|export default function foo() {}
    #|const x = 10;
    #|export default x;

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have at least one TS2528 error
  let has_ts2528 = diagnostics.iter().any(fn(d) { d.code == 2528 })
  assert_true(has_ts2528)
}

test "TS2528: multiple default exports - three defaults" {
  let source =
    #|export default class Foo {}
    #|export default function bar() {}
    #|export default 123;

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have TS2528 errors (second and third default exports)
  let ts2528_count = diagnostics.iter().filter(fn(d) { d.code == 2528 }).count()
  assert_true(ts2528_count >= 2)
}

test "TS2528: single default export - should pass" {
  let source =
    #|export default function foo() {}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should not have TS2528 error
  let has_ts2528 = diagnostics.iter().any(fn(d) { d.code == 2528 })
  assert_false(has_ts2528)
}

test "TS2528: export equals not affected" {
  let source =
    #|function foo() {}
    #|export = foo;

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should not have TS2528 error (export = is different from export default)
  let has_ts2528 = diagnostics.iter().any(fn(d) { d.code == 2528 })
  assert_false(has_ts2528)
}

test "TS2528: default export with named exports" {
  let source =
    #|export function foo() {}
    #|export default class Bar {}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should not have TS2528 error (named export + single default is fine)
  let has_ts2528 = diagnostics.iter().any(fn(d) { d.code == 2528 })
  assert_false(has_ts2528)
}
