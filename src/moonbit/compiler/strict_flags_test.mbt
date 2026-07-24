// Tests for CLI/tsconfig strict-flag overrides (StrictFlagOverrides) and
// their precedence against file-level directives:
//   file directive > CLI/tsconfig override > default (strict ON)

///|
fn has_code(result : CompileResult, code : Int) -> Bool {
  result.diagnostics.iter().any(fn(d) { d.code == code })
}

///|
fn compile_with_overrides(
  source : String,
  overrides : StrictFlagOverrides?,
) -> CompileResult {
  compile_source(
    source,
    "strict_flags_test.ts",
    CompileOptions::default(),
    strict_overrides=overrides,
  )
}

// ---------------------------------------------------------------------------
// strictNullChecks
// ---------------------------------------------------------------------------

///|
test "strictNullChecks defaults to ON without overrides" {
  let result = compile_with_overrides("let x: string = null;", None)
  assert_true(has_code(result, 2322))
}

///|
test "strictNullChecks override false disables the null check" {
  let overrides = Some(StrictFlagOverrides::{
    ..StrictFlagOverrides::default(),
    strict_null_checks: Some(false),
  })
  let result = compile_with_overrides("let x: string = null;", overrides)
  assert_false(has_code(result, 2322))
}

///|
test "strict override false disables strictNullChecks via fallback" {
  let overrides = Some(StrictFlagOverrides::{
    ..StrictFlagOverrides::default(),
    strict: Some(false),
  })
  let result = compile_with_overrides("let x: string = null;", overrides)
  assert_false(has_code(result, 2322))
}

///|
test "specific override beats general strict override" {
  // --strict false --strictNullChecks true
  let overrides = Some(StrictFlagOverrides::{
    ..StrictFlagOverrides::default(),
    strict: Some(false),
    strict_null_checks: Some(true),
  })
  let result = compile_with_overrides("let x: string = null;", overrides)
  assert_true(has_code(result, 2322))
}

///|
test "file directive wins over strictNullChecks override false" {
  let source = "// @strictNullChecks: true\nlet x: string = null;"
  let overrides = Some(StrictFlagOverrides::{
    ..StrictFlagOverrides::default(),
    strict_null_checks: Some(false),
  })
  let result = compile_with_overrides(source, overrides)
  assert_true(has_code(result, 2322))
}

///|
test "file directive wins over strictNullChecks override true" {
  let source = "// @strictNullChecks: false\nlet x: string = null;"
  let overrides = Some(StrictFlagOverrides::{
    ..StrictFlagOverrides::default(),
    strict_null_checks: Some(true),
  })
  let result = compile_with_overrides(source, overrides)
  assert_false(has_code(result, 2322))
}

// ---------------------------------------------------------------------------
// noImplicitAny
// ---------------------------------------------------------------------------

///|
test "noImplicitAny override false suppresses TS7006" {
  let source = "function f(a) { return a; }"
  let default_result = compile_with_overrides(source, None)
  assert_true(has_code(default_result, 7006))
  let overrides = Some(StrictFlagOverrides::{
    ..StrictFlagOverrides::default(),
    no_implicit_any: Some(false),
  })
  let result = compile_with_overrides(source, overrides)
  assert_false(has_code(result, 7006))
}

///|
test "noImplicitAny directive wins over override false" {
  let source = "// @noImplicitAny: true\nfunction f(a) { return a; }"
  let overrides = Some(StrictFlagOverrides::{
    ..StrictFlagOverrides::default(),
    no_implicit_any: Some(false),
  })
  let result = compile_with_overrides(source, overrides)
  assert_true(has_code(result, 7006))
}

///|
test "strict override false disables noImplicitAny via fallback" {
  let source = "function f(a) { return a; }"
  let overrides = Some(StrictFlagOverrides::{
    ..StrictFlagOverrides::default(),
    strict: Some(false),
  })
  let result = compile_with_overrides(source, overrides)
  assert_false(has_code(result, 7006))
}

// ---------------------------------------------------------------------------
// overrides flow through the external-types entry point too
// ---------------------------------------------------------------------------

///|
test "strictNullChecks override applies with external type registry" {
  let registry = ExternalTypeRegistry::new()
  let overrides = Some(StrictFlagOverrides::{
    ..StrictFlagOverrides::default(),
    strict_null_checks: Some(false),
  })
  let result = compile_source_with_external_types(
    "let x: string = null;",
    "strict_flags_test.ts",
    CompileOptions::default(),
    registry,
    strict_overrides=overrides,
  )
  assert_false(has_code(result, 2322))
}
