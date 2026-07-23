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
