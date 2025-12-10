// Unit tests for TS2307: Cannot find module

///|
/// Helper to check source and get diagnostics (TS2307-specific)
fn check_source_ts2307(source : String) -> @compiler.CheckResult {
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
/// Helper to get diagnostics from result (TS2307-specific)
fn get_diagnostics_ts2307(result : @compiler.CheckResult) -> Array[@compiler.Diagnostic] {
  match result {
    Ok(typed) => typed.diagnostics
    Err(diags) => diags
  }
}

test "TS2307: import from non-existent external module" {
  let source = "import {} from 'module-not-existed'"

  let result = check_source_ts2307(source)
  let diagnostics = get_diagnostics_ts2307(result)

  // Should have TS2307 error
  let has_ts2307 = diagnostics.iter().any(fn(d) { d.code == 2307 })
  assert_true(has_ts2307)

  // Check message
  let mut found_message = ""
  for d in diagnostics {
    if d.code == 2307 {
      found_message = d.message
      break
    }
  }
  assert_true(found_message.contains("Cannot find module"))
  assert_true(found_message.contains("module-not-existed"))
}

test "TS2307: import named from non-existent module" {
  let source = "import { foo } from 'some-package'"

  let result = check_source_ts2307(source)
  let diagnostics = get_diagnostics_ts2307(result)

  // Should have TS2307 error
  let has_ts2307 = diagnostics.iter().any(fn(d) { d.code == 2307 })
  assert_true(has_ts2307)
}

test "TS2307: import default from non-existent module" {
  let source = "import React from 'react'"

  let result = check_source_ts2307(source)
  let diagnostics = get_diagnostics_ts2307(result)

  // Should have TS2307 error
  let has_ts2307 = diagnostics.iter().any(fn(d) { d.code == 2307 })
  assert_true(has_ts2307)
}

test "TS2307: import star from non-existent module" {
  let source = "import * as lib from 'my-library'"

  let result = check_source_ts2307(source)
  let diagnostics = get_diagnostics_ts2307(result)

  // Should have TS2307 error
  let has_ts2307 = diagnostics.iter().any(fn(d) { d.code == 2307 })
  assert_true(has_ts2307)
}

test "TS2307: side-effect import from non-existent module" {
  let source = "import 'polyfill'"

  let result = check_source_ts2307(source)
  let diagnostics = get_diagnostics_ts2307(result)

  // Should have TS2307 error
  let has_ts2307 = diagnostics.iter().any(fn(d) { d.code == 2307 })
  assert_true(has_ts2307)
}

test "NO TS2307: import from relative path (should not error in single-file context)" {
  let source = "import { foo } from './utils'"

  let result = check_source_ts2307(source)
  let diagnostics = get_diagnostics_ts2307(result)

  // Should NOT have TS2307 error for relative imports
  let has_ts2307 = diagnostics.iter().any(fn(d) { d.code == 2307 })
  assert_false(has_ts2307)
}

test "NO TS2307: import from parent relative path" {
  let source = "import { bar } from '../helpers'"

  let result = check_source_ts2307(source)
  let diagnostics = get_diagnostics_ts2307(result)

  // Should NOT have TS2307 error for relative imports
  let has_ts2307 = diagnostics.iter().any(fn(d) { d.code == 2307 })
  assert_false(has_ts2307)
}

test "TS2307: multiple imports from different non-existent modules" {
  let source =
    #|import { a } from 'package-a'
    #|import { b } from 'package-b'
    #|import { c } from 'package-c'

  let result = check_source_ts2307(source)
  let diagnostics = get_diagnostics_ts2307(result)

  // Should have 3 TS2307 errors
  let ts2307_count = diagnostics.iter().filter(fn(d) { d.code == 2307 }).count()
  assert_eq(ts2307_count, 3)
}

test "TS2307: scoped package import" {
  let source = "import { Component } from '@angular/core'"

  let result = check_source_ts2307(source)
  let diagnostics = get_diagnostics_ts2307(result)

  // Should have TS2307 error
  let has_ts2307 = diagnostics.iter().any(fn(d) { d.code == 2307 })
  assert_true(has_ts2307)
}

test "TS2307: node built-in module" {
  let source = "import { readFile } from 'fs'"

  let result = check_source_ts2307(source)
  let diagnostics = get_diagnostics_ts2307(result)

  // Should have TS2307 error (even for node built-ins in single-file context)
  let has_ts2307 = diagnostics.iter().any(fn(d) { d.code == 2307 })
  assert_true(has_ts2307)
}
