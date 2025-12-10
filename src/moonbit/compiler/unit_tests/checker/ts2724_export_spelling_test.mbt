// Unit tests for TS2724: Export spelling suggestions

///|
/// Helper to compile multi-file test and get diagnostics
fn check_multi_file_ts2724(source : String) -> Array[@compiler.Diagnostic] {
  let opts = @compiler.CompileOptions::default()
  let result = @compiler.compile_multi_file_test(source, "test.ts", opts)
  result.diagnostics
}

test "TS2724: spelling suggestion for close match" {
  let source =
    #|// @filename: a.ts
    #|export function assertNever(x: never, msg: string) {}
    #|
    #|// @filename: b.ts
    #|import { assertNevar } from "./a";

  let diagnostics = check_multi_file_ts2724(source)

  // Should have TS2724 error with suggestion
  let has_ts2724 = diagnostics.iter().any(fn(d) { d.code == 2724 })
  assert_true(has_ts2724)

  // Check message contains suggestion
  let mut found_message = ""
  for d in diagnostics {
    if d.code == 2724 {
      found_message = d.message
      break
    }
  }
  assert_true(found_message.contains("assertNevar"))
  assert_true(found_message.contains("Did you mean"))
  assert_true(found_message.contains("assertNever"))
}

test "TS2724: suggestion for single character typo" {
  let source =
    #|// @filename: utils.ts
    #|export const myValue = 42;
    #|
    #|// @filename: main.ts
    #|import { myValu } from "./utils";

  let diagnostics = check_multi_file_ts2724(source)

  let has_ts2724 = diagnostics.iter().any(fn(d) { d.code == 2724 })
  assert_true(has_ts2724)

  let mut found_suggestion = ""
  for d in diagnostics {
    if d.code == 2724 && d.message.contains("Did you mean") {
      found_suggestion = d.message
      break
    }
  }
  assert_true(found_suggestion.contains("myValue"))
}

test "TS2724: suggestion for transposed characters" {
  let source =
    #|// @filename: api.ts
    #|export function fetchData() {}
    #|
    #|// @filename: app.ts
    #|import { fechData } from "./api";

  let diagnostics = check_multi_file_ts2724(source)

  let has_ts2724 = diagnostics.iter().any(fn(d) { d.code == 2724 })
  assert_true(has_ts2724)
}

test "NO TS2724: exact match should not error" {
  let source =
    #|// @filename: mod.ts
    #|export const foo = 1;
    #|
    #|// @filename: use.ts
    #|import { foo } from "./mod";

  let diagnostics = check_multi_file_ts2724(source)

  // Should have NO errors at all
  let has_ts2724 = diagnostics.iter().any(fn(d) { d.code == 2724 })
  assert_false(has_ts2724)

  let has_ts2305 = diagnostics.iter().any(fn(d) { d.code == 2305 })
  assert_false(has_ts2305)
}

test "TS2305: no suggestion for very different name" {
  let source =
    #|// @filename: lib.ts
    #|export const shortName = 1;
    #|
    #|// @filename: use.ts
    #|import { completelyDifferentLongName } from "./lib";

  let diagnostics = check_multi_file_ts2724(source)

  // Should have TS2305 (no suggestion) because distance is too large
  let has_ts2305 = diagnostics.iter().any(fn(d) { d.code == 2305 })
  assert_true(has_ts2305)

  // Should NOT have TS2724
  let has_ts2724 = diagnostics.iter().any(fn(d) { d.code == 2724 })
  assert_false(has_ts2724)
}

test "TS2724: suggestion with multiple exports" {
  let source =
    #|// @filename: utils.ts
    #|export const foo = 1;
    #|export const bar = 2;
    #|export const baz = 3;
    #|
    #|// @filename: main.ts
    #|import { baz } from "./utils";

  let diagnostics = check_multi_file_ts2724(source)

  // "baz" should match "baz" exactly, no error
  let has_error = diagnostics.iter().any(fn(d) { d.code == 2724 || d.code == 2305 })
  assert_false(has_error)
}

test "TS2724: pick closest match among multiple exports" {
  let source =
    #|// @filename: api.ts
    #|export const getUserData = () => {};
    #|export const getUseData = () => {};
    #|export const fetchData = () => {};
    #|
    #|// @filename: app.ts
    #|import { getUserDat } from "./api";

  let diagnostics = check_multi_file_ts2724(source)

  // Should suggest "getUserData" (distance 1) over "getUseData" (distance higher)
  let has_ts2724 = diagnostics.iter().any(fn(d) { d.code == 2724 })
  assert_true(has_ts2724)

  let mut suggestion = ""
  for d in diagnostics {
    if d.code == 2724 && d.message.contains("Did you mean") {
      suggestion = d.message
      break
    }
  }
  assert_true(suggestion.contains("getUserData"))
}

test "TS2724: multiple import specifiers with typos" {
  let source =
    #|// @filename: lib.ts
    #|export const alpha = 1;
    #|export const beta = 2;
    #|
    #|// @filename: use.ts
    #|import { alfa, bta } from "./lib";

  let diagnostics = check_multi_file_ts2724(source)

  // Should have 2 TS2724 errors
  let ts2724_count = diagnostics.iter().filter(fn(d) { d.code == 2724 }).count()
  assert_eq(ts2724_count, 2)
}

test "TS2306: empty file is not a module" {
  let source =
    #|// @filename: empty.ts
    #|// Empty module
    #|
    #|// @filename: main.ts
    #|import { anything } from "./empty";

  let diagnostics = check_multi_file_ts2724(source)

  // Should have TS2306 (file is not a module)
  let has_ts2306 = diagnostics.iter().any(fn(d) { d.code == 2306 })
  assert_true(has_ts2306)

  // Should NOT have TS2724 or TS2305
  let has_ts2724 = diagnostics.iter().any(fn(d) { d.code == 2724 })
  assert_false(has_ts2724)

  let has_ts2305 = diagnostics.iter().any(fn(d) { d.code == 2305 })
  assert_false(has_ts2305)
}
