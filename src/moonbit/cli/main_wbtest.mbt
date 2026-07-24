// Unit tests for strict-flag override construction (whitebox tests: the cli
// package is a main package, so these run as part of the package itself).

///|
test "build_strict_overrides carries CLI tri-state flags" {
  let options = {
    ..CLIOptions::default(),
    strict: Some(false),
    strict_null_checks: Some(true),
  }
  let ov = build_strict_overrides(options)
  assert_eq(ov.strict, Some(false))
  assert_eq(ov.strict_null_checks, Some(true))
  assert_eq(ov.no_implicit_any, None)
  assert_eq(ov.strict_function_types, None)
  assert_eq(ov.strict_property_initialization, None)
}

///|
test "coordinator options carry strict overrides from CLI" {
  let options = {
    ..CLIOptions::default(),
    no_implicit_any: Some(false),
  }
  let coord = build_coordinator_options(options)
  match coord.strict_overrides {
    Some(ov) => {
      assert_eq(ov.no_implicit_any, Some(false))
      assert_eq(ov.strict, None)
    }
    None => fail("expected strict overrides to be set")
  }
  // The legacy force-on bool stays unset so file directives keep precedence
  assert_false(coord.no_implicit_any)
}

///|
test "tsconfig strict flags flow into overrides with CLI precedence" {
  let ts_opts = {
    ..@config.CompilerOptions::default(),
    strict: Some(true),
    strict_null_checks: Some(false),
    strict_property_initialization: Some(false),
  }
  let tsconfig = { ..@config.TSConfig::default(), compiler_options: Some(ts_opts) }

  // No CLI flags: tsconfig values pass through
  let ov = build_strict_overrides_from_tsconfig(tsconfig, CLIOptions::default())
  assert_eq(ov.strict, Some(true))
  assert_eq(ov.strict_null_checks, Some(false))
  assert_eq(ov.strict_property_initialization, Some(false))
  assert_eq(ov.no_implicit_any, None)

  // CLI flag overrides the tsconfig value
  let cli = { ..CLIOptions::default(), strict_null_checks: Some(true) }
  let ov2 = build_strict_overrides_from_tsconfig(tsconfig, cli)
  assert_eq(ov2.strict_null_checks, Some(true))
  assert_eq(ov2.strict, Some(true))
}

///|
test "tsconfig without compilerOptions yields empty overrides" {
  let ov = build_strict_overrides_from_tsconfig(
    @config.TSConfig::default(),
    CLIOptions::default(),
  )
  assert_eq(ov.strict, None)
  assert_eq(ov.no_implicit_any, None)
  assert_eq(ov.strict_null_checks, None)
  assert_eq(ov.strict_function_types, None)
  assert_eq(ov.strict_property_initialization, None)
}
