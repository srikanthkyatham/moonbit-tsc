// Tests for the coordinator/worker protocol messages, focusing on the
// tri-state strict-flag fields added for CLI flag plumbing.

///|
test "CompileRequest roundtrips tri-state strict flags" {
  let request = @protocol.CompileRequest::new(
    "a.ts",
    "let x = 1;",
    strict=Some(false),
    no_implicit_any=Some(true),
    strict_null_checks=Some(false),
  )
  let json_line = request.to_ndjson()
  let parsed = @protocol.parse_request(json_line)
  assert_eq(parsed.file_path, "a.ts")
  assert_eq(parsed.strict, Some(false))
  assert_eq(parsed.no_implicit_any, Some(true))
  assert_eq(parsed.strict_null_checks, Some(false))
  assert_eq(parsed.strict_function_types, None)
  assert_eq(parsed.strict_property_initialization, None)
}

///|
test "CompileRequest strict flags default to unset" {
  let request = @protocol.CompileRequest::new("a.ts", "let x = 1;")
  assert_eq(request.strict, None)
  assert_eq(request.no_implicit_any, None)
  assert_eq(request.strict_null_checks, None)
  assert_eq(request.strict_function_types, None)
  assert_eq(request.strict_property_initialization, None)
  let parsed = @protocol.parse_request(request.to_ndjson())
  assert_eq(parsed.strict, None)
  assert_eq(parsed.no_implicit_any, None)
}
