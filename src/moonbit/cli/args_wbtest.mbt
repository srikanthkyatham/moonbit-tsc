// Unit tests for CLI argument parsing (whitebox tests: the cli package is a
// main package, so these run as part of the package itself).

///|
test "parse_args accepts --external-types-file with a path" {
  let result = parse_args([
    "moonbit-tsc", "--json", "--external-types-file", "/tmp/types.json", "a.ts",
  ])
  match result {
    Ok(Command::JsonCompile(files, options)) => {
      assert_eq(files, ["a.ts"])
      assert_eq(options.external_types_file, Some("/tmp/types.json"))
      assert_eq(options.external_types_json, None)
    }
    _ => fail("expected JsonCompile command")
  }
}

///|
test "parse_args rejects --external-types-file without a path" {
  let result = parse_args(["moonbit-tsc", "--external-types-file"])
  match result {
    Err(msg) => assert_eq(msg, "--external-types-file requires a file path")
    Ok(_) => fail("expected an error for missing file path")
  }
}

///|
test "parse_args keeps --external-types and --external-types-file independent" {
  let result = parse_args([
    "moonbit-tsc", "--external-types", "{\"modules\":{}}", "a.ts",
  ])
  match result {
    Ok(Command::Compile(_, options)) => {
      assert_eq(options.external_types_json, Some("{\"modules\":{}}"))
      assert_eq(options.external_types_file, None)
    }
    _ => fail("expected Compile command")
  }
}

///|
test "parse_args leaves strict flags unset by default" {
  let result = parse_args(["moonbit-tsc", "a.ts"])
  match result {
    Ok(Command::Compile(_, options)) => {
      assert_eq(options.strict, None)
      assert_eq(options.no_implicit_any, None)
      assert_eq(options.strict_null_checks, None)
      assert_eq(options.strict_function_types, None)
    }
    _ => fail("expected Compile command")
  }
}

///|
test "parse_args treats bare strict flags as true" {
  let result = parse_args([
    "moonbit-tsc", "--strict", "--strictNullChecks", "a.ts",
  ])
  match result {
    Ok(Command::Compile(files, options)) => {
      assert_eq(files, ["a.ts"])
      assert_eq(options.strict, Some(true))
      assert_eq(options.strict_null_checks, Some(true))
      // --strict no longer force-expands the specific flags; the checker
      // resolves the fallback so file directives keep precedence
      assert_eq(options.no_implicit_any, None)
      assert_eq(options.strict_function_types, None)
    }
    _ => fail("expected Compile command")
  }
}

///|
test "parse_args accepts tsc-style boolean values for strict flags" {
  let result = parse_args([
    "moonbit-tsc", "--strictNullChecks", "false", "--noImplicitAny", "true", "--strictFunctionTypes",
    "false", "--strict", "false", "a.ts",
  ])
  match result {
    Ok(Command::Compile(files, options)) => {
      assert_eq(files, ["a.ts"])
      assert_eq(options.strict, Some(false))
      assert_eq(options.no_implicit_any, Some(true))
      assert_eq(options.strict_null_checks, Some(false))
      assert_eq(options.strict_function_types, Some(false))
    }
    _ => fail("expected Compile command")
  }
}

///|
test "parse_args does not consume a filename after a bare strict flag" {
  // "snc.ts" is not a boolean value, so --strictNullChecks stays bare/true
  // and the file is still compiled
  let result = parse_args(["moonbit-tsc", "--strictNullChecks", "snc.ts"])
  match result {
    Ok(Command::Compile(files, options)) => {
      assert_eq(files, ["snc.ts"])
      assert_eq(options.strict_null_checks, Some(true))
    }
    _ => fail("expected Compile command")
  }
}
