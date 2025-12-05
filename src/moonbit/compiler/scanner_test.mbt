// Scanner Tests
// Tests for the TypeScript lexical analyzer (scanner)

///|
test "scan simple identifier" {
  let tokens = scan_all_v2("hello", "test.ts")
  assert_eq(tokens.length(), 2) // identifier + EOF
  match tokens[0] {
    Identifier(name, _) => assert_eq(name, "hello")
    _ => assert_true(false)
  }
}

///|
test "scan keywords" {
  let tokens = scan_all_v2("const let var function class", "test.ts")
  assert_eq(tokens.length(), 6) // 5 keywords + EOF
  match tokens[0] {
    KeywordConst(_) => ()
    _ => assert_true(false)
  }
  match tokens[1] {
    KeywordLet(_) => ()
    _ => assert_true(false)
  }
  match tokens[2] {
    KeywordVar(_) => ()
    _ => assert_true(false)
  }
  match tokens[3] {
    KeywordFunction(_) => ()
    _ => assert_true(false)
  }
  match tokens[4] {
    KeywordClass(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scan string literals" {
  let tokens = scan_all_v2("\"hello world\" 'test'", "test.ts")
  assert_eq(tokens.length(), 3) // 2 strings + EOF
  match tokens[0] {
    StringLiteral(value, _) => assert_eq(value, "hello world")
    _ => assert_true(false)
  }
  match tokens[1] {
    StringLiteral(value, _) => assert_eq(value, "test")
    _ => assert_true(false)
  }
}

///|
test "scan number literals" {
  let tokens = scan_all_v2("42 3.14", "test.ts")
  assert_eq(tokens.length(), 3) // 2 numbers + EOF
  match tokens[0] {
    NumericLiteral(value, _) => assert_eq(value, "42")
    _ => assert_true(false)
  }
  match tokens[1] {
    NumericLiteral(value, _) => assert_eq(value, "3.14")
    _ => assert_true(false)
  }
}

///|
test "scan operators" {
  let tokens = scan_all_v2("+ - * / = == === != !==", "test.ts")
  assert_eq(tokens.length(), 10) // 9 operators + EOF
  match tokens[0] {
    Plus(_) => ()
    _ => assert_true(false)
  }
  match tokens[1] {
    Minus(_) => ()
    _ => assert_true(false)
  }
  match tokens[2] {
    Star(_) => ()
    _ => assert_true(false)
  }
  match tokens[3] {
    Slash(_) => ()
    _ => assert_true(false)
  }
  match tokens[4] {
    Equals(_) => ()
    _ => assert_true(false)
  }
  match tokens[5] {
    EqualsEquals(_) => ()
    _ => assert_true(false)
  }
  match tokens[6] {
    EqualsEqualsEquals(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scan punctuation" {
  let tokens = scan_all_v2("( ) { } [ ] ; , .", "test.ts")
  assert_eq(tokens.length(), 10) // 9 punctuation + EOF
  match tokens[0] {
    OpenParen(_) => ()
    _ => assert_true(false)
  }
  match tokens[1] {
    CloseParen(_) => ()
    _ => assert_true(false)
  }
  match tokens[2] {
    OpenBrace(_) => ()
    _ => assert_true(false)
  }
  match tokens[3] {
    CloseBrace(_) => ()
    _ => assert_true(false)
  }
  match tokens[4] {
    OpenBracket(_) => ()
    _ => assert_true(false)
  }
  match tokens[5] {
    CloseBracket(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scan arrow function" {
  let tokens = scan_all_v2("=>", "test.ts")
  assert_eq(tokens.length(), 2) // arrow + EOF
  match tokens[0] {
    Arrow(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scan increment and decrement" {
  let tokens = scan_all_v2("++ --", "test.ts")
  assert_eq(tokens.length(), 3) // ++ -- EOF
  match tokens[0] {
    PlusPlus(_) => ()
    _ => assert_true(false)
  }
  match tokens[1] {
    MinusMinus(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scan simple variable declaration" {
  let tokens = scan_all_v2("const message = \"hello\";", "test.ts")

  // const, identifier, =, string, ;, EOF
  assert_eq(tokens.length(), 6)
  match tokens[0] {
    KeywordConst(_) => ()
    _ => assert_true(false)
  }
  match tokens[1] {
    Identifier(name, _) => assert_eq(name, "message")
    _ => assert_true(false)
  }
  match tokens[2] {
    Equals(_) => ()
    _ => assert_true(false)
  }
  match tokens[3] {
    StringLiteral(value, _) => assert_eq(value, "hello")
    _ => assert_true(false)
  }
  match tokens[4] {
    Semicolon(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scan function declaration" {
  let tokens = scan_all_v2("function greet() { }", "test.ts")

  // function, identifier, (, ), {, }, EOF
  assert_eq(tokens.length(), 7)
  match tokens[0] {
    KeywordFunction(_) => ()
    _ => assert_true(false)
  }
  match tokens[1] {
    Identifier(name, _) => assert_eq(name, "greet")
    _ => assert_true(false)
  }
}

///|
test "scan type annotation" {
  let tokens = scan_all_v2("x: number", "test.ts")

  // identifier, :, number keyword, EOF
  assert_eq(tokens.length(), 4)
  match tokens[1] {
    Colon(_) => ()
    _ => assert_true(false)
  }
  match tokens[2] {
    KeywordNumber(_) => () // "number" is a type keyword, not an identifier
    _ => assert_true(false)
  }
}

///|
test "scan comment skipping" {
  let tokens = scan_all_v2("// comment\nconst x = 5;", "test.ts")

  // Comments should be skipped: const, identifier, =, number, ;, EOF
  assert_eq(tokens.length(), 6)
  match tokens[0] {
    KeywordConst(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scan multiline comment skipping" {
  let tokens = scan_all_v2("/* multi\nline\ncomment */const x = 5;", "test.ts")

  // Comments should be skipped: const, identifier, =, number, ;, EOF
  assert_eq(tokens.length(), 6)
  match tokens[0] {
    KeywordConst(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scan comparison operators" {
  let tokens = scan_all_v2("< > <= >=", "test.ts")
  assert_eq(tokens.length(), 5) // 4 operators + EOF
  match tokens[0] {
    LessThan(_) => ()
    _ => assert_true(false)
  }
  match tokens[1] {
    GreaterThan(_) => ()
    _ => assert_true(false)
  }
  match tokens[2] {
    LessThanEquals(_) => ()
    _ => assert_true(false)
  }
  match tokens[3] {
    GreaterThanEquals(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scan logical operators" {
  let tokens = scan_all_v2("&& || !", "test.ts")
  assert_eq(tokens.length(), 4) // 3 operators + EOF
  match tokens[0] {
    AmpersandAmpersand(_) => ()
    _ => assert_true(false)
  }
  match tokens[1] {
    BarBar(_) => ()
    _ => assert_true(false)
  }
  match tokens[2] {
    Exclamation(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scan ternary operator" {
  let tokens = scan_all_v2("a ? b : c", "test.ts")

  // identifier, ?, identifier, :, identifier, EOF
  assert_eq(tokens.length(), 6)
  match tokens[1] {
    Question(_) => ()
    _ => assert_true(false)
  }
  match tokens[3] {
    Colon(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scan async await keywords" {
  let tokens = scan_all_v2("async await", "test.ts")
  assert_eq(tokens.length(), 3) // async, await, EOF
  match tokens[0] {
    KeywordAsync(_) => ()
    _ => assert_true(false)
  }
  match tokens[1] {
    KeywordAwait(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scan import export keywords" {
  let tokens = scan_all_v2("import export from", "test.ts")
  assert_eq(tokens.length(), 4) // import, export, from, EOF
  match tokens[0] {
    KeywordImport(_) => ()
    _ => assert_true(false)
  }
  match tokens[1] {
    KeywordExport(_) => ()
    _ => assert_true(false)
  }
  match tokens[2] {
    KeywordFrom(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scan interface and type keywords" {
  let tokens = scan_all_v2("interface type enum", "test.ts")
  assert_eq(tokens.length(), 4) // interface, type, enum, EOF
  match tokens[0] {
    KeywordInterface(_) => ()
    _ => assert_true(false)
  }
  match tokens[1] {
    KeywordType(_) => ()
    _ => assert_true(false)
  }
  match tokens[2] {
    KeywordEnum(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scan this and super keywords" {
  let tokens = scan_all_v2("this super", "test.ts")
  assert_eq(tokens.length(), 3) // this, super, EOF
  match tokens[0] {
    KeywordThis(_) => ()
    _ => assert_true(false)
  }
  match tokens[1] {
    KeywordSuper(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scan empty source" {
  let tokens = scan_all_v2("", "test.ts")
  assert_eq(tokens.length(), 1) // Only EOF
  match tokens[0] {
    EOF(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scan whitespace only" {
  let tokens = scan_all_v2("   \n  \t  ", "test.ts")
  assert_eq(tokens.length(), 1) // Only EOF (whitespace skipped)
  match tokens[0] {
    EOF(_) => ()
    _ => assert_true(false)
  }
}

// ============================================================================
// Unicode Escape Tests
// ============================================================================

///|
test "scan unicode escape 4-digit" {
  let tokens = scan_all_v2("\"\\u0041\\u0042\"", "test.ts")
  assert_eq(tokens.length(), 2) // string + EOF
  match tokens[0] {
    StringLiteral(value, _) => assert_eq(value, "AB")
    _ => assert_true(false)
  }
}

///|
test "scan unicode escape braces" {
  let tokens = scan_all_v2("\"\\u{41}\\u{42}\"", "test.ts")
  assert_eq(tokens.length(), 2) // string + EOF
  match tokens[0] {
    StringLiteral(value, _) => assert_eq(value, "AB")
    _ => assert_true(false)
  }
}

///|
test "scan unicode escape in template" {
  let tokens = scan_all_v2("`\\u0048\\u0069`", "test.ts")
  assert_eq(tokens.length(), 2) // template + EOF
  match tokens[0] {
    TemplateLiteral(value, _) => assert_eq(value, "Hi")
    _ => assert_true(false)
  }
}

///|
test "scan invalid unicode escape keeps literal" {
  let tokens = scan_all_v2("\"\\u00GG\"", "test.ts")
  assert_eq(tokens.length(), 2) // string + EOF
  match tokens[0] {
    StringLiteral(value, _) => assert_eq(value, "\\u00GG")
    _ => assert_true(false)
  }
}

// ============================================================================
// Hex Escape Tests
// ============================================================================

///|
test "scan hex escape in string" {
  let tokens = scan_all_v2("\"\\x41\\x42\\x43\"", "test.ts")
  assert_eq(tokens.length(), 2) // string + EOF
  match tokens[0] {
    StringLiteral(value, _) => assert_eq(value, "ABC")
    _ => assert_true(false)
  }
}

///|
test "scan hex escape in template" {
  let tokens = scan_all_v2("`\\x48\\x69`", "test.ts")
  assert_eq(tokens.length(), 2) // template + EOF
  match tokens[0] {
    TemplateLiteral(value, _) => assert_eq(value, "Hi")
    _ => assert_true(false)
  }
}

///|
test "scan invalid hex escape keeps literal" {
  let tokens = scan_all_v2("\"\\xGG\"", "test.ts")
  assert_eq(tokens.length(), 2) // string + EOF
  match tokens[0] {
    StringLiteral(value, _) => assert_eq(value, "\\xGG")
    _ => assert_true(false)
  }
}

// ============================================================================
// Numeric Format Tests
// ============================================================================

///|
test "scan hex number lowercase" {
  let tokens = scan_all_v2("0xff", "test.ts")
  assert_eq(tokens.length(), 2) // number + EOF
  match tokens[0] {
    NumericLiteral(value, _) => assert_eq(value, "0xff")
    _ => assert_true(false)
  }
}

///|
test "scan hex number uppercase" {
  let tokens = scan_all_v2("0XFF", "test.ts")
  assert_eq(tokens.length(), 2) // number + EOF
  match tokens[0] {
    NumericLiteral(value, _) => assert_eq(value, "0xFF")
    _ => assert_true(false)
  }
}

///|
test "scan octal number" {
  let tokens = scan_all_v2("0o777", "test.ts")
  assert_eq(tokens.length(), 2) // number + EOF
  match tokens[0] {
    NumericLiteral(value, _) => assert_eq(value, "0o777")
    _ => assert_true(false)
  }
}

///|
test "scan octal number uppercase" {
  let tokens = scan_all_v2("0O123", "test.ts")
  assert_eq(tokens.length(), 2) // number + EOF
  match tokens[0] {
    NumericLiteral(value, _) => assert_eq(value, "0o123")
    _ => assert_true(false)
  }
}

///|
test "scan binary number" {
  let tokens = scan_all_v2("0b1010", "test.ts")
  assert_eq(tokens.length(), 2) // number + EOF
  match tokens[0] {
    NumericLiteral(value, _) => assert_eq(value, "0b1010")
    _ => assert_true(false)
  }
}

///|
test "scan binary number uppercase" {
  let tokens = scan_all_v2("0B1111", "test.ts")
  assert_eq(tokens.length(), 2) // number + EOF
  match tokens[0] {
    NumericLiteral(value, _) => assert_eq(value, "0b1111")
    _ => assert_true(false)
  }
}

// ============================================================================
// BigInt Tests
// ============================================================================

///|
test "scan decimal bigint" {
  let tokens = scan_all_v2("123n", "test.ts")
  assert_eq(tokens.length(), 2) // bigint + EOF
  match tokens[0] {
    BigIntLiteral(value, _) => assert_eq(value, "123n")
    _ => assert_true(false)
  }
}

///|
test "scan hex bigint" {
  let tokens = scan_all_v2("0xFFn", "test.ts")
  assert_eq(tokens.length(), 2) // bigint + EOF
  match tokens[0] {
    BigIntLiteral(value, _) => assert_eq(value, "0xFFn")
    _ => assert_true(false)
  }
}

///|
test "scan octal bigint" {
  let tokens = scan_all_v2("0o77n", "test.ts")
  assert_eq(tokens.length(), 2) // bigint + EOF
  match tokens[0] {
    BigIntLiteral(value, _) => assert_eq(value, "0o77n")
    _ => assert_true(false)
  }
}

///|
test "scan binary bigint" {
  let tokens = scan_all_v2("0b1010n", "test.ts")
  assert_eq(tokens.length(), 2) // bigint + EOF
  match tokens[0] {
    BigIntLiteral(value, _) => assert_eq(value, "0b1010n")
    _ => assert_true(false)
  }
}

///|
test "scan zero bigint" {
  let tokens = scan_all_v2("0n", "test.ts")
  assert_eq(tokens.length(), 2) // bigint + EOF
  match tokens[0] {
    BigIntLiteral(value, _) => assert_eq(value, "0n")
    _ => assert_true(false)
  }
}

// ============================================================================
// Numeric Separator Tests
// ============================================================================

///|
test "scan decimal with separator" {
  let tokens = scan_all_v2("1_000_000", "test.ts")
  assert_eq(tokens.length(), 2) // number + EOF
  match tokens[0] {
    NumericLiteral(value, _) => assert_eq(value, "1000000")
    _ => assert_true(false)
  }
}

///|
test "scan hex with separator" {
  let tokens = scan_all_v2("0xFF_FF", "test.ts")
  assert_eq(tokens.length(), 2) // number + EOF
  match tokens[0] {
    NumericLiteral(value, _) => assert_eq(value, "0xFFFF")
    _ => assert_true(false)
  }
}

///|
test "scan binary with separator" {
  let tokens = scan_all_v2("0b1010_1010", "test.ts")
  assert_eq(tokens.length(), 2) // number + EOF
  match tokens[0] {
    NumericLiteral(value, _) => assert_eq(value, "0b10101010")
    _ => assert_true(false)
  }
}

///|
test "scan float with separator" {
  let tokens = scan_all_v2("1_000.5", "test.ts")
  assert_eq(tokens.length(), 2) // number + EOF
  match tokens[0] {
    NumericLiteral(value, _) => assert_eq(value, "1000.5")
    _ => assert_true(false)
  }
}

///|
test "scan bigint with separator" {
  let tokens = scan_all_v2("1_000n", "test.ts")
  assert_eq(tokens.length(), 2) // bigint + EOF
  match tokens[0] {
    BigIntLiteral(value, _) => assert_eq(value, "1000n")
    _ => assert_true(false)
  }
}

// ============================================================================
// Private Identifier Tests
// ============================================================================

///|
test "scan private identifier" {
  let tokens = scan_all_v2("#privateField", "test.ts")
  assert_eq(tokens.length(), 2) // private identifier + EOF
  match tokens[0] {
    PrivateIdentifier(name, _) => assert_eq(name, "#privateField")
    _ => assert_true(false)
  }
}

///|
test "scan private identifier in class" {
  let tokens = scan_all_v2("class Foo { #field = 1; }", "test.ts")
  // class, Foo, {, #field, =, 1, ;, }, EOF
  assert_eq(tokens.length(), 9)
  match tokens[3] {
    PrivateIdentifier(name, _) => assert_eq(name, "#field")
    _ => assert_true(false)
  }
}

///|
test "scan invalid private identifier" {
  let tokens = scan_all_v2("# notPrivate", "test.ts")
  // #, notPrivate, EOF
  assert_eq(tokens.length(), 3)
  match tokens[0] {
    Unknown(text, _) => assert_eq(text, "#")
    _ => assert_true(false)
  }
}

// ============================================================================
// String Escape Sequence Tests
// ============================================================================

///|
test "scan string with basic escapes" {
  let tokens = scan_all_v2("\"\\n\\r\\t\"", "test.ts")
  assert_eq(tokens.length(), 2) // string + EOF
  match tokens[0] {
    StringLiteral(value, _) => assert_eq(value, "\n\r\t")
    _ => assert_true(false)
  }
}

///|
test "scan string with quote escapes" {
  let tokens = scan_all_v2("\"\\\"hello\\\"\"", "test.ts")
  assert_eq(tokens.length(), 2) // string + EOF
  match tokens[0] {
    StringLiteral(value, _) => assert_eq(value, "\"hello\"")
    _ => assert_true(false)
  }
}

// ============================================================================
// Smart Quote Detection Tests (common copy-paste error)
// ============================================================================

///|
test "scan left double smart quote" {
  let tokens = scan_all_v2("\u{201C}hello", "test.ts") // "hello
  assert_eq(tokens.length(), 3) // smart quote + identifier + EOF
  match tokens[0] {
    SmartQuote(found, suggested, _) => {
      assert_eq(found, "\u{201C}")
      assert_eq(suggested, "\"")
    }
    _ => assert_true(false)
  }
}

///|
test "scan right double smart quote" {
  let tokens = scan_all_v2("\u{201D}hello", "test.ts") // "hello
  assert_eq(tokens.length(), 3) // smart quote + identifier + EOF
  match tokens[0] {
    SmartQuote(found, suggested, _) => {
      assert_eq(found, "\u{201D}")
      assert_eq(suggested, "\"")
    }
    _ => assert_true(false)
  }
}

///|
test "scan left single smart quote" {
  let tokens = scan_all_v2("\u{2018}hello", "test.ts") // 'hello
  assert_eq(tokens.length(), 3) // smart quote + identifier + EOF
  match tokens[0] {
    SmartQuote(found, suggested, _) => {
      assert_eq(found, "\u{2018}")
      assert_eq(suggested, "'")
    }
    _ => assert_true(false)
  }
}

///|
test "scan right single smart quote" {
  let tokens = scan_all_v2("\u{2019}hello", "test.ts") // 'hello
  assert_eq(tokens.length(), 3) // smart quote + identifier + EOF
  match tokens[0] {
    SmartQuote(found, suggested, _) => {
      assert_eq(found, "\u{2019}")
      assert_eq(suggested, "'")
    }
    _ => assert_true(false)
  }
}
