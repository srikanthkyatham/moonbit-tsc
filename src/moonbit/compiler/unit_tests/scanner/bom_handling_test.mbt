// BOM (Byte Order Mark) Handling Tests
// Tests for UTF-8 BOM support in the scanner
// TypeScript treats BOM (\uFEFF) as whitespace

///|
test "scan source with BOM at start" {
  // UTF-8 BOM is \uFEFF (0xEF 0xBB 0xBF in UTF-8)
  let source = "\u{FEFF}const x = 1;"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  // const, x, =, 1, ;, EOF
  assert_eq(tokens.length(), 6)
  match tokens[0] {
    @compiler.KeywordConst(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scan source with BOM - variable declaration" {
  let source = "\u{FEFF}var hello = 'world';"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  // var, hello, =, 'world', ;, EOF
  assert_eq(tokens.length(), 6)
  match tokens[0] {
    @compiler.KeywordVar(_) => ()
    _ => assert_true(false)
  }
  match tokens[1] {
    @compiler.Identifier(name, _) => assert_eq(name, "hello")
    _ => assert_true(false)
  }
}

///|
test "scan source with BOM - function declaration" {
  let source = "\u{FEFF}function foo() { }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  // function, foo, (, ), {, }, EOF
  assert_eq(tokens.length(), 7)
  match tokens[0] {
    @compiler.KeywordFunction(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scan source with BOM - template literal" {
  let source = "\u{FEFF}const x = `hello world`;"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  // const, x, =, `hello world`, ;, EOF
  assert_eq(tokens.length(), 6)
  match tokens[3] {
    @compiler.TemplateLiteral(content, _) => assert_eq(content, "hello world")
    _ => assert_true(false)
  }
}

///|
test "scan source with BOM - template with interpolation" {
  let source = "\u{FEFF}const x = `hello ${name}`;"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  // const, x, =, TemplateHead, name, CloseBrace, TemplateTail, ;, EOF
  assert_eq(tokens.length(), 9)
  match tokens[3] {
    @compiler.TemplateHead(content, _) => assert_eq(content, "hello ")
    _ => assert_true(false)
  }
  match tokens[4] {
    @compiler.Identifier(name, _) => assert_eq(name, "name")
    _ => assert_true(false)
  }
  // tokens[5] is CloseBrace
  match tokens[6] {
    @compiler.TemplateTail(content, _) => assert_eq(content, "")
    _ => assert_true(false)
  }
}

///|
test "scan source with BOM followed by newlines" {
  let source = "\u{FEFF}\n\nconst x = 1;"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  // const, x, =, 1, ;, EOF
  assert_eq(tokens.length(), 6)
  match tokens[0] {
    @compiler.KeywordConst(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scan source with BOM and comment" {
  let source = "\u{FEFF}// This is a comment\nconst x = 1;"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  // const, x, =, 1, ;, EOF
  assert_eq(tokens.length(), 6)
  match tokens[0] {
    @compiler.KeywordConst(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scan source with BOM and block comment" {
  let source = "\u{FEFF}/* comment */const x = 1;"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  // const, x, =, 1, ;, EOF
  assert_eq(tokens.length(), 6)
  match tokens[0] {
    @compiler.KeywordConst(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scan source with BOM - interface declaration" {
  let source = "\u{FEFF}interface Foo { x: number; }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  // interface, Foo, {, x, :, number, ;, }, EOF
  assert_eq(tokens.length(), 9)
  match tokens[0] {
    @compiler.KeywordInterface(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scan source with BOM - class declaration" {
  let source = "\u{FEFF}class MyClass { }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  // class, MyClass, {, }, EOF
  assert_eq(tokens.length(), 5)
  match tokens[0] {
    @compiler.KeywordClass(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scan source with BOM - arrow function" {
  let source = "\u{FEFF}const fn = () => 42;"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  // const, fn, =, (, ), =>, 42, ;, EOF
  assert_eq(tokens.length(), 9)
  match tokens[0] {
    @compiler.KeywordConst(_) => ()
    _ => assert_true(false)
  }
  match tokens[5] {
    @compiler.Arrow(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scan source without BOM works normally" {
  let source = "const x = 1;"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  // const, x, =, 1, ;, EOF
  assert_eq(tokens.length(), 6)
  match tokens[0] {
    @compiler.KeywordConst(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scan source with BOM and rest parameters" {
  let source = "\u{FEFF}function f(...args: any[]) { }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  // function, f, (, ..., args, :, any, [, ], ), {, }, EOF
  assert_true(tokens.length() > 5)
  match tokens[0] {
    @compiler.KeywordFunction(_) => ()
    _ => assert_true(false)
  }
}
