// Template String Scanning Tests
// Tests for template literal scanning including unterminated templates (TS1160)

///|
test "scan unterminated template literal - simple" {
  // Just a backtick with no closing
  let source = "`"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  // Should have ScanError token and EOF
  assert_eq(tokens.length(), 2)
  match tokens[0] {
    @compiler.ScanError(msg, code, _) => {
      assert_eq(code, 1160)
      assert_true(msg.contains("Unterminated"))
    }
    _ => assert_true(false)
  }
}

///|
test "scan unterminated template literal - with content" {
  // Template with content but no closing backtick
  let source = "`hello world"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  assert_eq(tokens.length(), 2)
  match tokens[0] {
    @compiler.ScanError(_, code, _) => assert_eq(code, 1160)
    _ => assert_true(false)
  }
}

///|
test "scan unterminated template literal - with escaped backtick" {
  // Template with escaped backtick but no closing
  let source = "`\\`"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  assert_eq(tokens.length(), 2)
  match tokens[0] {
    @compiler.ScanError(_, code, _) => assert_eq(code, 1160)
    _ => assert_true(false)
  }
}

///|
test "scan unterminated template literal - with multiple escapes" {
  // Template with multiple escapes but no closing
  let source = "`\\\\\\`"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  assert_eq(tokens.length(), 2)
  match tokens[0] {
    @compiler.ScanError(_, code, _) => assert_eq(code, 1160)
    _ => assert_true(false)
  }
}

///|
test "scan valid template literal - simple" {
  // Valid complete template
  let source = "`hello`"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  assert_eq(tokens.length(), 2) // TemplateLiteral + EOF
  match tokens[0] {
    @compiler.TemplateLiteral(content, _) => assert_eq(content, "hello")
    _ => assert_true(false)
  }
}

///|
test "scan valid template literal - with escaped backtick" {
  // Valid template with escaped backtick
  let source = "`\\``"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  assert_eq(tokens.length(), 2)
  match tokens[0] {
    @compiler.TemplateLiteral(content, _) => assert_eq(content, "`")
    _ => assert_true(false)
  }
}

///|
test "scan valid template literal - empty" {
  // Valid empty template
  let source = "``"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  assert_eq(tokens.length(), 2)
  match tokens[0] {
    @compiler.TemplateLiteral(content, _) => assert_eq(content, "")
    _ => assert_true(false)
  }
}
