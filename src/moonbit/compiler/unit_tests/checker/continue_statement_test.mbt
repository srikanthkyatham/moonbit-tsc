// Unit tests for TS1104: Continue statement validation
// Uses helper functions from diagnostic_code_test.mbt:
// - check_source(source: String) -> CheckResult
// - get_diagnostics(result: CheckResult) -> Array[Diagnostic]

test "TS1104 - continue in switch statement" {
  let source =
    #|switch (12) {
    #|    case 5:
    #|        continue;
    #|}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have TS1104
  let has_1104 = diagnostics.iter().any(fn(d) { d.code == 1104 })
  assert_true(has_1104)
}

test "TS1104 - continue outside any loop" {
  let source = "continue;"

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have TS1104
  let has_1104 = diagnostics.iter().any(fn(d) { d.code == 1104 })
  assert_true(has_1104)
}

test "TS1104 - continue in function" {
  let source =
    #|function foo() {
    #|    continue;
    #|}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have TS1104
  let has_1104 = diagnostics.iter().any(fn(d) { d.code == 1104 })
  assert_true(has_1104)
}

test "No TS1104 - continue in for loop" {
  let source =
    #|for (let i = 0; i < 10; i++) {
    #|    continue;
    #|}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should NOT have TS1104
  let has_1104 = diagnostics.iter().any(fn(d) { d.code == 1104 })
  assert_false(has_1104)
}

test "No TS1104 - continue in while loop" {
  let source =
    #|while (true) {
    #|    continue;
    #|}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should NOT have TS1104
  let has_1104 = diagnostics.iter().any(fn(d) { d.code == 1104 })
  assert_false(has_1104)
}

test "No TS1104 - continue in do-while loop" {
  let source =
    #|do {
    #|    continue;
    #|} while (true);

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should NOT have TS1104
  let has_1104 = diagnostics.iter().any(fn(d) { d.code == 1104 })
  assert_false(has_1104)
}

test "No TS1104 - continue in for-in loop" {
  let source =
    #|for (let x in obj) {
    #|    continue;
    #|}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should NOT have TS1104
  let has_1104 = diagnostics.iter().any(fn(d) { d.code == 1104 })
  assert_false(has_1104)
}

test "No TS1104 - continue in for-of loop" {
  let source =
    #|for (let x of arr) {
    #|    continue;
    #|}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should NOT have TS1104
  let has_1104 = diagnostics.iter().any(fn(d) { d.code == 1104 })
  assert_false(has_1104)
}

test "No TS1104 - continue in nested loop" {
  let source =
    #|for (let i = 0; i < 10; i++) {
    #|    for (let j = 0; j < 10; j++) {
    #|        continue;
    #|    }
    #|}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should NOT have TS1104
  let has_1104 = diagnostics.iter().any(fn(d) { d.code == 1104 })
  assert_false(has_1104)
}

test "TS1104 - continue in function inside loop" {
  let source =
    #|for (let i = 0; i < 10; i++) {
    #|    function foo() {
    #|        continue;
    #|    }
    #|}

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should have TS1104 (continue not allowed in nested function even if function is inside loop)
  let has_1104 = diagnostics.iter().any(fn(d) { d.code == 1104 })
  assert_true(has_1104)
}
