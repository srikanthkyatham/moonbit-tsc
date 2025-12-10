// Unit tests for TS1214: Reserved word in strict mode

///|
/// Helper to check source and get diagnostics (TS1214-specific)
fn check_source_ts1214(source : String) -> @compiler.CheckResult {
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) => @compiler.check_source_file(bound)
        Err(diags) => Err(diags)
      }
    Err(diags) => Err(diags)
  }
}

///|
/// Helper to get diagnostics from result (TS1214-specific)
fn get_diagnostics_ts1214(result : @compiler.CheckResult) -> Array[@compiler.Diagnostic] {
  match result {
    Ok(typed) => typed.diagnostics
    Err(diags) => diags
  }
}

test "TS1214: import with 'yield' as alias" {
  let source =
    #|export let foo = 10;
    #|import { foo as yield } from "./utils";

  let result = check_source_ts1214(source)
  let diagnostics = get_diagnostics_ts1214(result)

  // Should have TS1214 error
  let has_ts1214 = diagnostics.iter().any(fn(d) { d.code == 1214 })
  assert_true(has_ts1214)

  // Check message
  let mut found_message = ""
  for d in diagnostics {
    if d.code == 1214 {
      found_message = d.message
      break
    }
  }
  assert_true(found_message.contains("yield"))
  assert_true(found_message.contains("strict mode"))
}

test "TS1214: import with 'arguments' as alias" {
  let source =
    #|export let foo = 10;
    #|import { foo as arguments } from "./utils";

  let result = check_source_ts1214(source)
  let diagnostics = get_diagnostics_ts1214(result)

  // Should have TS1214 error
  let has_ts1214 = diagnostics.iter().any(fn(d) { d.code == 1214 })
  assert_true(has_ts1214)
}

test "TS1214: import with 'eval' as alias" {
  let source =
    #|export let foo = 10;
    #|import { foo as eval } from "./utils";

  let result = check_source_ts1214(source)
  let diagnostics = get_diagnostics_ts1214(result)

  // Should have TS1214 error
  let has_ts1214 = diagnostics.iter().any(fn(d) { d.code == 1214 })
  assert_true(has_ts1214)
}

test "TS1214: import with 'let' as alias" {
  let source =
    #|export let foo = 10;
    #|import { foo as let } from "./utils";

  let result = check_source_ts1214(source)
  let diagnostics = get_diagnostics_ts1214(result)

  // Should have TS1214 error
  let has_ts1214 = diagnostics.iter().any(fn(d) { d.code == 1214 })
  assert_true(has_ts1214)
}

test "TS1214: import with 'static' as alias" {
  let source =
    #|export let foo = 10;
    #|import { foo as static } from "./utils";

  let result = check_source_ts1214(source)
  let diagnostics = get_diagnostics_ts1214(result)

  // Should have TS1214 error
  let has_ts1214 = diagnostics.iter().any(fn(d) { d.code == 1214 })
  assert_true(has_ts1214)
}

test "TS1214: import with 'implements' as alias" {
  let source =
    #|export let foo = 10;
    #|import { foo as implements } from "./utils";

  let result = check_source_ts1214(source)
  let diagnostics = get_diagnostics_ts1214(result)

  // Should have TS1214 error
  let has_ts1214 = diagnostics.iter().any(fn(d) { d.code == 1214 })
  assert_true(has_ts1214)
}

test "TS1214: import with 'package' as alias" {
  let source =
    #|export let foo = 10;
    #|import { foo as package } from "./utils";

  let result = check_source_ts1214(source)
  let diagnostics = get_diagnostics_ts1214(result)

  // Should have TS1214 error
  let has_ts1214 = diagnostics.iter().any(fn(d) { d.code == 1214 })
  assert_true(has_ts1214)
}

test "TS1214: import with 'private' as alias" {
  let source =
    #|export let foo = 10;
    #|import { foo as private } from "./utils";

  let result = check_source_ts1214(source)
  let diagnostics = get_diagnostics_ts1214(result)

  // Should have TS1214 error
  let has_ts1214 = diagnostics.iter().any(fn(d) { d.code == 1214 })
  assert_true(has_ts1214)
}

test "TS1214: import with 'protected' as alias" {
  let source =
    #|export let foo = 10;
    #|import { foo as protected } from "./utils";

  let result = check_source_ts1214(source)
  let diagnostics = get_diagnostics_ts1214(result)

  // Should have TS1214 error
  let has_ts1214 = diagnostics.iter().any(fn(d) { d.code == 1214 })
  assert_true(has_ts1214)
}

test "TS1214: import with 'public' as alias" {
  let source =
    #|export let foo = 10;
    #|import { foo as public } from "./utils";

  let result = check_source_ts1214(source)
  let diagnostics = get_diagnostics_ts1214(result)

  // Should have TS1214 error
  let has_ts1214 = diagnostics.iter().any(fn(d) { d.code == 1214 })
  assert_true(has_ts1214)
}

test "TS1214: namespace import with reserved word" {
  let source =
    #|export let foo = 10;
    #|import * as yield from "./utils";

  let result = check_source_ts1214(source)
  let diagnostics = get_diagnostics_ts1214(result)

  // Should have TS1214 error
  let has_ts1214 = diagnostics.iter().any(fn(d) { d.code == 1214 })
  assert_true(has_ts1214)
}

test "NO TS1214: import with valid identifier" {
  let source =
    #|export let foo = 10;
    #|import { foo as bar } from "./utils";

  let result = check_source_ts1214(source)
  let diagnostics = get_diagnostics_ts1214(result)

  // Should NOT have TS1214 error
  let has_ts1214 = diagnostics.iter().any(fn(d) { d.code == 1214 })
  assert_false(has_ts1214)
}

test "NO TS1214: import without alias" {
  let source =
    #|export let yield = 10;
    #|import { yield } from "./utils";

  let result = check_source_ts1214(source)
  let diagnostics = get_diagnostics_ts1214(result)

  // Should NOT have TS1214 error (reserved word as exported name is ok)
  let has_ts1214 = diagnostics.iter().any(fn(d) { d.code == 1214 })
  assert_false(has_ts1214)
}

test "TS1214: multiple imports with reserved words" {
  let source =
    #|export let foo = 10;
    #|export let bar = 20;
    #|import { foo as yield, bar as eval } from "./utils";

  let result = check_source_ts1214(source)
  let diagnostics = get_diagnostics_ts1214(result)

  // Should have 2 TS1214 errors
  let ts1214_count = diagnostics.iter().filter(fn(d) { d.code == 1214 }).count()
  assert_eq(ts1214_count, 2)
}
