// Unit tests for TS2308: Export star conflicts

///|
/// Helper to compile multi-file test
fn check_multi_file_ts2308(source : String) -> Array[@compiler.Diagnostic] {
  let opts = @compiler.CompileOptions::default()
  let result = @compiler.compile_multi_file_test(source, "test.ts", opts)
  result.diagnostics
}

test "TS2308: export star conflict with same member name" {
  let source =
    #|// @filename: t1.ts
    #|export var x = 1;
    #|export var y = 2;
    #|
    #|// @filename: t3.ts
    #|export var x = "x";
    #|export var z = "z";
    #|
    #|// @filename: t4.ts
    #|export * from "./t1";
    #|export * from "./t3";

  let diagnostics = check_multi_file_ts2308(source)

  // Should have TS2308 error for 'x' conflict
  let has_ts2308 = diagnostics.iter().any(fn(d) { d.code == 2308 })
  assert_true(has_ts2308)

  // Check message mentions 'x'
  let mut found_x_conflict = false
  for d in diagnostics {
    if d.code == 2308 && d.message.contains(" 'x'") {
      found_x_conflict = true
      break
    }
  }
  assert_true(found_x_conflict)
}

test "TS2308: multiple conflicts in export star" {
  let source =
    #|// @filename: t1.ts
    #|export var x = 1;
    #|export var y = 2;
    #|
    #|// @filename: t3.ts
    #|export var x = "x";
    #|export var y = "y";
    #|export var z = "z";
    #|
    #|// @filename: t4.ts
    #|export * from "./t1";
    #|export * from "./t3";

  let diagnostics = check_multi_file_ts2308(source)

  // Should have 2 TS2308 errors (for x and y)
  let ts2308_count = diagnostics.iter().filter(fn(d) { d.code == 2308 }).count()
  assert_eq(ts2308_count, 2)
}

test "NO TS2308: export star with no conflicts" {
  let source =
    #|// @filename: t1.ts
    #|export var x = 1;
    #|export var y = 2;
    #|
    #|// @filename: t3.ts
    #|export var z = "z";
    #|export var w = "w";
    #|
    #|// @filename: t4.ts
    #|export * from "./t1";
    #|export * from "./t3";

  let diagnostics = check_multi_file_ts2308(source)

  // Should NOT have TS2308 errors
  let has_ts2308 = diagnostics.iter().any(fn(d) { d.code == 2308 })
  assert_false(has_ts2308)
}

test "NO TS2308: single export star" {
  let source =
    #|// @filename: t1.ts
    #|export var x = 1;
    #|export var y = 2;
    #|
    #|// @filename: t4.ts
    #|export * from "./t1";

  let diagnostics = check_multi_file_ts2308(source)

  // Should NOT have TS2308 with only one export *
  let has_ts2308 = diagnostics.iter().any(fn(d) { d.code == 2308 })
  assert_false(has_ts2308)
}

test "TS2308: three export star with conflicts" {
  let source =
    #|// @filename: t1.ts
    #|export var x = 1;
    #|
    #|// @filename: t2.ts
    #|export var y = 2;
    #|
    #|// @filename: t3.ts
    #|export var x = "x";
    #|export var y = "y";
    #|
    #|// @filename: t4.ts
    #|export * from "./t1";
    #|export * from "./t2";
    #|export * from "./t3";

  let diagnostics = check_multi_file_ts2308(source)

  // Should have TS2308 errors for both x and y
  let ts2308_count = diagnostics.iter().filter(fn(d) { d.code == 2308 }).count()
  assert_true(ts2308_count >= 2)
}

test "NO TS2308: named export doesn't conflict with export star" {
  let source =
    #|// @filename: t1.ts
    #|export var x = 1;
    #|
    #|// @filename: t4.ts
    #|export * from "./t1";
    #|export var x = "local";

  let diagnostics = check_multi_file_ts2308(source)

  // Named export takes precedence, no conflict with export *
  let has_ts2308 = diagnostics.iter().any(fn(d) { d.code == 2308 })
  assert_false(has_ts2308)
}

test "TS2308: message format" {
  let source =
    #|// @filename: t1.ts
    #|export var foo = 1;
    #|
    #|// @filename: t3.ts
    #|export var foo = "x";
    #|
    #|// @filename: t4.ts
    #|export * from "./t1";
    #|export * from "./t3";

  let diagnostics = check_multi_file_ts2308(source)

  // Find TS2308 error and check message format
  let mut found_message = ""
  for d in diagnostics {
    if d.code == 2308 {
      found_message = d.message
      break
    }
  }

  assert_true(found_message.contains("already exported"))
  assert_true(found_message.contains("foo"))
  assert_true(found_message.contains("Consider explicitly re-exporting"))
}
