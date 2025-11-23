// Tests for the scanner

use ../../src/moonbit/compiler/scanner/scanner::*
use ../../src/moonbit/compiler/types/token::*

test "scan simple tokens" {
  let source = "let x = 42"
  let scanner = Scanner::new(source, "test.ts")
  let tokens = scan_all(scanner)

  // Should have: let, x, =, 42, EOF
  assert_eq!(tokens.length(), 5)

  match tokens.get(0) {
    Some(KeywordLet(_)) => {}
    _ => fail("Expected 'let' keyword")
  }

  match tokens.get(1) {
    Some(Identifier(name, _)) => assert_eq!(name, "x")
    _ => fail("Expected identifier 'x'")
  }

  match tokens.get(2) {
    Some(Equals(_)) => {}
    _ => fail("Expected '=' token")
  }

  match tokens.get(3) {
    Some(NumericLiteral(value, _)) => assert_eq!(value, "42")
    _ => fail("Expected numeric literal")
  }

  match tokens.get(4) {
    Some(EOF(_)) => {}
    _ => fail("Expected EOF")
  }
}

test "scan string literals" {
  let source = "\"hello world\""
  let scanner = Scanner::new(source, "test.ts")
  let tokens = scan_all(scanner)

  assert_eq!(tokens.length(), 2)  // string + EOF

  match tokens.get(0) {
    Some(StringLiteral(value, _)) => assert_eq!(value, "hello world")
    _ => fail("Expected string literal")
  }
}

test "scan operators" {
  let source = "+ - * / == === != !== && ||"
  let scanner = Scanner::new(source, "test.ts")
  let tokens = scan_all(scanner)

  // Should have all operators + EOF
  assert_eq!(tokens.length(), 11)

  match tokens.get(0) {
    Some(Plus(_)) => {}
    _ => fail("Expected '+' operator")
  }

  match tokens.get(4) {
    Some(EqualsEquals(_)) => {}
    _ => fail("Expected '==' operator")
  }

  match tokens.get(5) {
    Some(EqualsEqualsEquals(_)) => {}
    _ => fail("Expected '===' operator")
  }
}

test "scan keywords" {
  let source = "function class interface if while for"
  let scanner = Scanner::new(source, "test.ts")
  let tokens = scan_all(scanner)

  assert_eq!(tokens.length(), 7)  // 6 keywords + EOF

  match tokens.get(0) {
    Some(KeywordFunction(_)) => {}
    _ => fail("Expected 'function' keyword")
  }

  match tokens.get(1) {
    Some(KeywordClass(_)) => {}
    _ => fail("Expected 'class' keyword")
  }
}

test "scan with comments" {
  let source = "// comment\nlet x = 5"
  let scanner = Scanner::new(source, "test.ts")
  let tokens = scan_all(scanner)

  // Comments should be skipped
  assert_eq!(tokens.length(), 5)  // let, x, =, 5, EOF

  match tokens.get(0) {
    Some(KeywordLet(_)) => {}
    _ => fail("Expected 'let' keyword after comment")
  }
}

test "scan multi-line comment" {
  let source = "/* multi\nline\ncomment */\nconst y = 10"
  let scanner = Scanner::new(source, "test.ts")
  let tokens = scan_all(scanner)

  assert_eq!(tokens.length(), 5)  // const, y, =, 10, EOF
}

test "scan function declaration" {
  let source = "function add(a, b) { return a + b; }"
  let scanner = Scanner::new(source, "test.ts")
  let tokens = scan_all(scanner)

  // function, add, (, a, comma, b, ), {, return, a, +, b, ;, }, EOF
  assert_true!(tokens.length() > 10)

  match tokens.get(0) {
    Some(KeywordFunction(_)) => {}
    _ => fail("Expected 'function' keyword")
  }
}

test "scan arrow function" {
  let source = "const f = (x) => x * 2"
  let scanner = Scanner::new(source, "test.ts")
  let tokens = scan_all(scanner)

  let mut found_arrow = false
  for token in tokens {
    match token {
      Arrow(_) => { found_arrow = true }
      _ => {}
    }
  }

  assert_true!(found_arrow)
}

test "scan array and object" {
  let source = "[1, 2, 3] { x: 10 }"
  let scanner = Scanner::new(source, "test.ts")
  let tokens = scan_all(scanner)

  match tokens.get(0) {
    Some(OpenBracket(_)) => {}
    _ => fail("Expected '['")
  }

  // Find closing bracket
  let mut found_close_bracket = false
  for token in tokens {
    match token {
      CloseBracket(_) => { found_close_bracket = true }
      _ => {}
    }
  }
  assert_true!(found_close_bracket)
}

test "scan template literal" {
  let source = "`hello ${name}`"
  let scanner = Scanner::new(source, "test.ts")
  let tokens = scan_all(scanner)

  match tokens.get(0) {
    Some(TemplateLiteral(_, _)) => {}
    _ => fail("Expected template literal")
  }
}

test "scan with whitespace" {
  let source = "  let    x    =    5  "
  let scanner = Scanner::new(source, "test.ts")
  let tokens = scan_all(scanner)

  // Whitespace should be skipped
  assert_eq!(tokens.length(), 5)  // let, x, =, 5, EOF
}

test "is_keyword check" {
  let token = KeywordLet(SourceLocation::new("test.ts", Position::new(1, 1, 0), Position::new(1, 4, 3)))
  assert_true!(is_keyword(token))

  let token2 = Identifier("foo", SourceLocation::new("test.ts", Position::new(1, 1, 0), Position::new(1, 4, 3)))
  assert_false!(is_keyword(token2))
}
