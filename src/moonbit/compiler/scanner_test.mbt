// Scanner Tests
// Tests for the TypeScript lexical analyzer (scanner)

test "scan simple identifier" {
  let scanner = Scanner::new("hello", "test.ts")
  let tokens = scan_all(scanner)

  assert_eq!(tokens.length(), 2) // identifier + EOF
  match tokens[0] {
    Identifier(name, _) => assert_eq!(name, "hello")
    _ => assert_true!(false)
  }
}

test "scan keywords" {
  let scanner = Scanner::new("const let var function class", "test.ts")
  let tokens = scan_all(scanner)

  assert_eq!(tokens.length(), 6) // 5 keywords + EOF
  match tokens[0] {
    KeywordConst(_) => ()
    _ => assert_true!(false)
  }
  match tokens[1] {
    KeywordLet(_) => ()
    _ => assert_true!(false)
  }
  match tokens[2] {
    KeywordVar(_) => ()
    _ => assert_true!(false)
  }
  match tokens[3] {
    KeywordFunction(_) => ()
    _ => assert_true!(false)
  }
  match tokens[4] {
    KeywordClass(_) => ()
    _ => assert_true!(false)
  }
}

test "scan string literals" {
  let scanner = Scanner::new("\"hello world\" 'test'", "test.ts")
  let tokens = scan_all(scanner)

  assert_eq!(tokens.length(), 3) // 2 strings + EOF
  match tokens[0] {
    StringLiteral(value, _) => assert_eq!(value, "hello world")
    _ => assert_true!(false)
  }
  match tokens[1] {
    StringLiteral(value, _) => assert_eq!(value, "test")
    _ => assert_true!(false)
  }
}

test "scan number literals" {
  let scanner = Scanner::new("42 3.14", "test.ts")
  let tokens = scan_all(scanner)

  assert_eq!(tokens.length(), 3) // 2 numbers + EOF
  match tokens[0] {
    NumericLiteral(value, _) => assert_eq!(value, "42")
    _ => assert_true!(false)
  }
  match tokens[1] {
    NumericLiteral(value, _) => assert_eq!(value, "3.14")
    _ => assert_true!(false)
  }
}

test "scan operators" {
  let scanner = Scanner::new("+ - * / = == === != !==", "test.ts")
  let tokens = scan_all(scanner)

  assert_eq!(tokens.length(), 10) // 9 operators + EOF
  match tokens[0] {
    Plus(_) => ()
    _ => assert_true!(false)
  }
  match tokens[1] {
    Minus(_) => ()
    _ => assert_true!(false)
  }
  match tokens[2] {
    Star(_) => ()
    _ => assert_true!(false)
  }
  match tokens[3] {
    Slash(_) => ()
    _ => assert_true!(false)
  }
  match tokens[4] {
    Equals(_) => ()
    _ => assert_true!(false)
  }
  match tokens[5] {
    EqualsEquals(_) => ()
    _ => assert_true!(false)
  }
  match tokens[6] {
    EqualsEqualsEquals(_) => ()
    _ => assert_true!(false)
  }
}

test "scan punctuation" {
  let scanner = Scanner::new("( ) { } [ ] ; , .", "test.ts")
  let tokens = scan_all(scanner)

  assert_eq!(tokens.length(), 10) // 9 punctuation + EOF
  match tokens[0] {
    OpenParen(_) => ()
    _ => assert_true!(false)
  }
  match tokens[1] {
    CloseParen(_) => ()
    _ => assert_true!(false)
  }
  match tokens[2] {
    OpenBrace(_) => ()
    _ => assert_true!(false)
  }
  match tokens[3] {
    CloseBrace(_) => ()
    _ => assert_true!(false)
  }
  match tokens[4] {
    OpenBracket(_) => ()
    _ => assert_true!(false)
  }
  match tokens[5] {
    CloseBracket(_) => ()
    _ => assert_true!(false)
  }
}

test "scan arrow function" {
  let scanner = Scanner::new("=>", "test.ts")
  let tokens = scan_all(scanner)

  assert_eq!(tokens.length(), 2) // arrow + EOF
  match tokens[0] {
    Arrow(_) => ()
    _ => assert_true!(false)
  }
}

test "scan increment and decrement" {
  let scanner = Scanner::new("++ --", "test.ts")
  let tokens = scan_all(scanner)

  assert_eq!(tokens.length(), 3) // ++ -- EOF
  match tokens[0] {
    PlusPlus(_) => ()
    _ => assert_true!(false)
  }
  match tokens[1] {
    MinusMinus(_) => ()
    _ => assert_true!(false)
  }
}

test "scan simple variable declaration" {
  let scanner = Scanner::new("const message = \"hello\";", "test.ts")
  let tokens = scan_all(scanner)

  // const, identifier, =, string, ;, EOF
  assert_eq!(tokens.length(), 6)
  match tokens[0] {
    KeywordConst(_) => ()
    _ => assert_true!(false)
  }
  match tokens[1] {
    Identifier(name, _) => assert_eq!(name, "message")
    _ => assert_true!(false)
  }
  match tokens[2] {
    Equals(_) => ()
    _ => assert_true!(false)
  }
  match tokens[3] {
    StringLiteral(value, _) => assert_eq!(value, "hello")
    _ => assert_true!(false)
  }
  match tokens[4] {
    Semicolon(_) => ()
    _ => assert_true!(false)
  }
}

test "scan function declaration" {
  let scanner = Scanner::new("function greet() { }", "test.ts")
  let tokens = scan_all(scanner)

  // function, identifier, (, ), {, }, EOF
  assert_eq!(tokens.length(), 7)
  match tokens[0] {
    KeywordFunction(_) => ()
    _ => assert_true!(false)
  }
  match tokens[1] {
    Identifier(name, _) => assert_eq!(name, "greet")
    _ => assert_true!(false)
  }
}

test "scan type annotation" {
  let scanner = Scanner::new("x: number", "test.ts")
  let tokens = scan_all(scanner)

  // identifier, :, number keyword, EOF
  assert_eq!(tokens.length(), 4)
  match tokens[1] {
    Colon(_) => ()
    _ => assert_true!(false)
  }
  match tokens[2] {
    KeywordNumber(_) => ()  // "number" is a type keyword, not an identifier
    _ => assert_true!(false)
  }
}

test "scan comment skipping" {
  let scanner = Scanner::new("// comment\nconst x = 5;", "test.ts")
  let tokens = scan_all(scanner)

  // Comments should be skipped: const, identifier, =, number, ;, EOF
  assert_eq!(tokens.length(), 6)
  match tokens[0] {
    KeywordConst(_) => ()
    _ => assert_true!(false)
  }
}

test "scan multiline comment skipping" {
  let scanner = Scanner::new("/* multi\nline\ncomment */const x = 5;", "test.ts")
  let tokens = scan_all(scanner)

  // Comments should be skipped: const, identifier, =, number, ;, EOF
  assert_eq!(tokens.length(), 6)
  match tokens[0] {
    KeywordConst(_) => ()
    _ => assert_true!(false)
  }
}

test "scan comparison operators" {
  let scanner = Scanner::new("< > <= >=", "test.ts")
  let tokens = scan_all(scanner)

  assert_eq!(tokens.length(), 5) // 4 operators + EOF
  match tokens[0] {
    LessThan(_) => ()
    _ => assert_true!(false)
  }
  match tokens[1] {
    GreaterThan(_) => ()
    _ => assert_true!(false)
  }
  match tokens[2] {
    LessThanEquals(_) => ()
    _ => assert_true!(false)
  }
  match tokens[3] {
    GreaterThanEquals(_) => ()
    _ => assert_true!(false)
  }
}

test "scan logical operators" {
  let scanner = Scanner::new("&& || !", "test.ts")
  let tokens = scan_all(scanner)

  assert_eq!(tokens.length(), 4) // 3 operators + EOF
  match tokens[0] {
    AmpersandAmpersand(_) => ()
    _ => assert_true!(false)
  }
  match tokens[1] {
    BarBar(_) => ()
    _ => assert_true!(false)
  }
  match tokens[2] {
    Exclamation(_) => ()
    _ => assert_true!(false)
  }
}

test "scan ternary operator" {
  let scanner = Scanner::new("a ? b : c", "test.ts")
  let tokens = scan_all(scanner)

  // identifier, ?, identifier, :, identifier, EOF
  assert_eq!(tokens.length(), 6)
  match tokens[1] {
    Question(_) => ()
    _ => assert_true!(false)
  }
  match tokens[3] {
    Colon(_) => ()
    _ => assert_true!(false)
  }
}

test "scan async await keywords" {
  let scanner = Scanner::new("async await", "test.ts")
  let tokens = scan_all(scanner)

  assert_eq!(tokens.length(), 3) // async, await, EOF
  match tokens[0] {
    KeywordAsync(_) => ()
    _ => assert_true!(false)
  }
  match tokens[1] {
    KeywordAwait(_) => ()
    _ => assert_true!(false)
  }
}

test "scan import export keywords" {
  let scanner = Scanner::new("import export from", "test.ts")
  let tokens = scan_all(scanner)

  assert_eq!(tokens.length(), 4) // import, export, from, EOF
  match tokens[0] {
    KeywordImport(_) => ()
    _ => assert_true!(false)
  }
  match tokens[1] {
    KeywordExport(_) => ()
    _ => assert_true!(false)
  }
  match tokens[2] {
    KeywordFrom(_) => ()
    _ => assert_true!(false)
  }
}

test "scan interface and type keywords" {
  let scanner = Scanner::new("interface type enum", "test.ts")
  let tokens = scan_all(scanner)

  assert_eq!(tokens.length(), 4) // interface, type, enum, EOF
  match tokens[0] {
    KeywordInterface(_) => ()
    _ => assert_true!(false)
  }
  match tokens[1] {
    KeywordType(_) => ()
    _ => assert_true!(false)
  }
  match tokens[2] {
    KeywordEnum(_) => ()
    _ => assert_true!(false)
  }
}

test "scan this and super keywords" {
  let scanner = Scanner::new("this super", "test.ts")
  let tokens = scan_all(scanner)

  assert_eq!(tokens.length(), 3) // this, super, EOF
  match tokens[0] {
    KeywordThis(_) => ()
    _ => assert_true!(false)
  }
  match tokens[1] {
    KeywordSuper(_) => ()
    _ => assert_true!(false)
  }
}

test "scan empty source" {
  let scanner = Scanner::new("", "test.ts")
  let tokens = scan_all(scanner)

  assert_eq!(tokens.length(), 1) // Only EOF
  match tokens[0] {
    EOF(_) => ()
    _ => assert_true!(false)
  }
}

test "scan whitespace only" {
  let scanner = Scanner::new("   \n  \t  ", "test.ts")
  let tokens = scan_all(scanner)

  assert_eq!(tokens.length(), 1) // Only EOF (whitespace skipped)
  match tokens[0] {
    EOF(_) => ()
    _ => assert_true!(false)
  }
}
