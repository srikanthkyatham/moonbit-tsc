// Unit tests for TS1192: Module has no default export

///|
/// Helper to compile multi-file test
fn check_multi_file_ts1192(source : String) -> Array[@compiler.Diagnostic] {
  let opts = @compiler.CompileOptions::default()
  let result = @compiler.compile_multi_file_test(source, "test.ts", opts)
  result.diagnostics
}

test "TS1192: import default from module without default export" {
  let source =
    #|// @filename: lib.ts
    #|export const foo = 1;
    #|export const bar = 2;
    #|
    #|// @filename: main.ts
    #|import myDefault from "./lib";

  let diagnostics = check_multi_file_ts1192(source)

  // Should have TS1192 error
  let has_ts1192 = diagnostics.iter().any(fn(d) { d.code == 1192 })
  assert_true(has_ts1192)

  // Check message
  let mut found_message = ""
  for d in diagnostics {
    if d.code == 1192 {
      found_message = d.message
      break
    }
  }
  assert_true(found_message.contains("no default export"))
}

test "TS1192: import default when module only has named exports" {
  let source =
    #|// @filename: utils.ts
    #|export function helper() {}
    #|export class MyClass {}
    #|
    #|// @filename: app.ts
    #|import Utils from "./utils";

  let diagnostics = check_multi_file_ts1192(source)

  let has_ts1192 = diagnostics.iter().any(fn(d) { d.code == 1192 })
  assert_true(has_ts1192)
}

test "NO TS1192: import default when module has default export" {
  let source =
    #|// @filename: lib.ts
    #|export default function() {}
    #|export const foo = 1;
    #|
    #|// @filename: main.ts
    #|import myDefault from "./lib";

  let diagnostics = check_multi_file_ts1192(source)

  // Should NOT have TS1192 error
  let has_ts1192 = diagnostics.iter().any(fn(d) { d.code == 1192 })
  assert_false(has_ts1192)
}

test "NO TS1192: import named exports works fine" {
  let source =
    #|// @filename: lib.ts
    #|export const foo = 1;
    #|
    #|// @filename: main.ts
    #|import { foo } from "./lib";

  let diagnostics = check_multi_file_ts1192(source)

  let has_ts1192 = diagnostics.iter().any(fn(d) { d.code == 1192 })
  assert_false(has_ts1192)
}

test "TS1192: combined import with default and named" {
  let source =
    #|// @filename: lib.ts
    #|export const foo = 1;
    #|
    #|// @filename: main.ts
    #|import myDefault, { foo } from "./lib";

  let diagnostics = check_multi_file_ts1192(source)

  // Should have TS1192 for the default import
  let has_ts1192 = diagnostics.iter().any(fn(d) { d.code == 1192 })
  assert_true(has_ts1192)
}
