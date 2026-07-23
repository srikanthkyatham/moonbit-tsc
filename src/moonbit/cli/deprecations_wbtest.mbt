// Whitebox tests for deprecated-option diagnostics (TS5107)

///|
fn opts_with(
  target? : String,
  module_system? : String,
  ignore_deprecations~ : Bool = false,
) -> CLIOptions {
  let base = CLIOptions::default()
  { ..base, target, module_system, ignore_deprecations, }
}

///|
test "explicit target es5 emits TS5107" {
  let diags = option_deprecation_diags(opts_with(target="es5"))
  assert_eq(diags.length(), 1)
  assert_true(diags[0].has_prefix("error TS5107: Option 'target=ES5'"))
}

///|
test "explicit target ES5 uppercase also emits TS5107" {
  let diags = option_deprecation_diags(opts_with(target="ES5"))
  assert_eq(diags.length(), 1)
}

///|
test "explicit target es3 emits TS5107" {
  let diags = option_deprecation_diags(opts_with(target="es3"))
  assert_eq(diags.length(), 1)
  assert_true(diags[0].has_prefix("error TS5107: Option 'target=ES3'"))
}

///|
test "non-deprecated targets emit nothing" {
  assert_eq(option_deprecation_diags(opts_with(target="es2015")).length(), 0)
  assert_eq(option_deprecation_diags(opts_with(target="es6")).length(), 0)
  assert_eq(option_deprecation_diags(opts_with(target="esnext")).length(), 0)
}

///|
test "no explicit target emits nothing (defaults are exempt)" {
  assert_eq(option_deprecation_diags(CLIOptions::default()).length(), 0)
}

///|
test "deprecated module values emit TS5107" {
  assert_true(
    option_deprecation_diags(opts_with(module_system="amd"))[0].has_prefix(
      "error TS5107: Option 'module=AMD'",
    ),
  )
  assert_eq(option_deprecation_diags(opts_with(module_system="umd")).length(), 1)
  assert_eq(
    option_deprecation_diags(opts_with(module_system="system")).length(),
    1,
  )
  assert_eq(
    option_deprecation_diags(opts_with(module_system="none")).length(),
    1,
  )
}

///|
test "non-deprecated module values emit nothing" {
  assert_eq(
    option_deprecation_diags(opts_with(module_system="commonjs")).length(),
    0,
  )
  assert_eq(
    option_deprecation_diags(opts_with(module_system="esnext")).length(),
    0,
  )
}

///|
test "deprecated target and module both emit" {
  let diags = option_deprecation_diags(
    opts_with(target="es5", module_system="amd"),
  )
  assert_eq(diags.length(), 2)
}

///|
test "--ignoreDeprecations suppresses TS5107" {
  let diags = option_deprecation_diags(
    opts_with(target="es5", module_system="amd", ignore_deprecations=true),
  )
  assert_eq(diags.length(), 0)
}

///|
test "message matches tsc wording" {
  let diags = option_deprecation_diags(opts_with(target="es5"))
  assert_eq(
    diags[0],
    "error TS5107: Option 'target=ES5' is deprecated and will stop functioning in TypeScript 7.0. Specify compilerOption '\"ignoreDeprecations\": \"6.0\"' to silence this error.",
  )
}

///|
test "parse_args accepts --ignoreDeprecations with value" {
  let cmd = parse_args([
    "cli", "file.ts", "--ignoreDeprecations", "6.0", "--target", "es5",
  ])
  match cmd {
    Ok(Command::Compile(_, options)) => {
      assert_true(options.ignore_deprecations)
      assert_eq(options.target, Some("es5"))
    }
    _ => fail("expected Compile command")
  }
}

///|
test "parse_args accepts bare --ignoreDeprecations before another flag" {
  let cmd = parse_args(["cli", "file.ts", "--ignoreDeprecations", "--noEmit"])
  match cmd {
    Ok(Command::Compile(_, options)) => {
      assert_true(options.ignore_deprecations)
      assert_true(options.no_emit)
    }
    _ => fail("expected Compile command")
  }
}
