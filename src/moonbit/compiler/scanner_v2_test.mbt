// Scanner V2 Tests
// Tests for the pattern-matching based scanner

///|
/// Helper function to compare token types (ignoring locations)
fn token_type_eq(t1 : Token, t2 : Token) -> Bool {
  match (t1, t2) {
    (NumericLiteral(v1, _), NumericLiteral(v2, _)) => v1 == v2
    (BigIntLiteral(v1, _), BigIntLiteral(v2, _)) => v1 == v2
    (StringLiteral(v1, _), StringLiteral(v2, _)) => v1 == v2
    (TemplateLiteral(v1, _), TemplateLiteral(v2, _)) => v1 == v2
    (TemplateHead(v1, _), TemplateHead(v2, _)) => v1 == v2
    (Identifier(v1, _), Identifier(v2, _)) => v1 == v2
    (PrivateIdentifier(v1, _), PrivateIdentifier(v2, _)) => v1 == v2
    (Unknown(v1, _), Unknown(v2, _)) => v1 == v2
    (KeywordAny(_), KeywordAny(_)) => true
    (KeywordBoolean(_), KeywordBoolean(_)) => true
    (KeywordNumber(_), KeywordNumber(_)) => true
    (KeywordString(_), KeywordString(_)) => true
    (KeywordSymbol(_), KeywordSymbol(_)) => true
    (KeywordObject(_), KeywordObject(_)) => true
    (KeywordVoid(_), KeywordVoid(_)) => true
    (KeywordUnknown(_), KeywordUnknown(_)) => true
    (KeywordNever(_), KeywordNever(_)) => true
    (KeywordUndefined(_), KeywordUndefined(_)) => true
    (KeywordNull(_), KeywordNull(_)) => true
    (KeywordLet(_), KeywordLet(_)) => true
    (KeywordConst(_), KeywordConst(_)) => true
    (KeywordVar(_), KeywordVar(_)) => true
    (KeywordFunction(_), KeywordFunction(_)) => true
    (KeywordClass(_), KeywordClass(_)) => true
    (KeywordInterface(_), KeywordInterface(_)) => true
    (KeywordEnum(_), KeywordEnum(_)) => true
    (KeywordType(_), KeywordType(_)) => true
    (KeywordNamespace(_), KeywordNamespace(_)) => true
    (KeywordModule(_), KeywordModule(_)) => true
    (KeywordIf(_), KeywordIf(_)) => true
    (KeywordElse(_), KeywordElse(_)) => true
    (KeywordSwitch(_), KeywordSwitch(_)) => true
    (KeywordCase(_), KeywordCase(_)) => true
    (KeywordDefault(_), KeywordDefault(_)) => true
    (KeywordFor(_), KeywordFor(_)) => true
    (KeywordWhile(_), KeywordWhile(_)) => true
    (KeywordDo(_), KeywordDo(_)) => true
    (KeywordBreak(_), KeywordBreak(_)) => true
    (KeywordContinue(_), KeywordContinue(_)) => true
    (KeywordReturn(_), KeywordReturn(_)) => true
    (KeywordThrow(_), KeywordThrow(_)) => true
    (KeywordTry(_), KeywordTry(_)) => true
    (KeywordCatch(_), KeywordCatch(_)) => true
    (KeywordFinally(_), KeywordFinally(_)) => true
    (KeywordPublic(_), KeywordPublic(_)) => true
    (KeywordPrivate(_), KeywordPrivate(_)) => true
    (KeywordProtected(_), KeywordProtected(_)) => true
    (KeywordStatic(_), KeywordStatic(_)) => true
    (KeywordReadonly(_), KeywordReadonly(_)) => true
    (KeywordAbstract(_), KeywordAbstract(_)) => true
    (KeywordAsync(_), KeywordAsync(_)) => true
    (KeywordAwait(_), KeywordAwait(_)) => true
    (KeywordDeclare(_), KeywordDeclare(_)) => true
    (KeywordNew(_), KeywordNew(_)) => true
    (KeywordThis(_), KeywordThis(_)) => true
    (KeywordSuper(_), KeywordSuper(_)) => true
    (KeywordImport(_), KeywordImport(_)) => true
    (KeywordExport(_), KeywordExport(_)) => true
    (KeywordFrom(_), KeywordFrom(_)) => true
    (KeywordAs(_), KeywordAs(_)) => true
    (KeywordSatisfies(_), KeywordSatisfies(_)) => true
    (KeywordExtends(_), KeywordExtends(_)) => true
    (KeywordImplements(_), KeywordImplements(_)) => true
    (KeywordYield(_), KeywordYield(_)) => true
    (KeywordIn(_), KeywordIn(_)) => true
    (KeywordOf(_), KeywordOf(_)) => true
    (KeywordInstanceOf(_), KeywordInstanceOf(_)) => true
    (KeywordTypeOf(_), KeywordTypeOf(_)) => true
    (KeywordDelete(_), KeywordDelete(_)) => true
    (KeywordDebugger(_), KeywordDebugger(_)) => true
    (Plus(_), Plus(_)) => true
    (Minus(_), Minus(_)) => true
    (Star(_), Star(_)) => true
    (Slash(_), Slash(_)) => true
    (Percent(_), Percent(_)) => true
    (StarStar(_), StarStar(_)) => true
    (LessThan(_), LessThan(_)) => true
    (GreaterThan(_), GreaterThan(_)) => true
    (LessThanEquals(_), LessThanEquals(_)) => true
    (GreaterThanEquals(_), GreaterThanEquals(_)) => true
    (EqualsEquals(_), EqualsEquals(_)) => true
    (ExclamationEquals(_), ExclamationEquals(_)) => true
    (EqualsEqualsEquals(_), EqualsEqualsEquals(_)) => true
    (ExclamationEqualsEquals(_), ExclamationEqualsEquals(_)) => true
    (AmpersandAmpersand(_), AmpersandAmpersand(_)) => true
    (BarBar(_), BarBar(_)) => true
    (Exclamation(_), Exclamation(_)) => true
    (QuestionQuestion(_), QuestionQuestion(_)) => true
    (Ampersand(_), Ampersand(_)) => true
    (Bar(_), Bar(_)) => true
    (Caret(_), Caret(_)) => true
    (Tilde(_), Tilde(_)) => true
    (LessThanLessThan(_), LessThanLessThan(_)) => true
    (GreaterThanGreaterThan(_), GreaterThanGreaterThan(_)) => true
    (GreaterThanGreaterThanGreaterThan(_), GreaterThanGreaterThanGreaterThan(_)) =>
      true
    (Equals(_), Equals(_)) => true
    (PlusEquals(_), PlusEquals(_)) => true
    (MinusEquals(_), MinusEquals(_)) => true
    (StarEquals(_), StarEquals(_)) => true
    (SlashEquals(_), SlashEquals(_)) => true
    (PercentEquals(_), PercentEquals(_)) => true
    (AmpersandEquals(_), AmpersandEquals(_)) => true
    (BarEquals(_), BarEquals(_)) => true
    (CaretEquals(_), CaretEquals(_)) => true
    (StarStarEquals(_), StarStarEquals(_)) => true
    (LessThanLessThanEquals(_), LessThanLessThanEquals(_)) => true
    (GreaterThanGreaterThanEquals(_), GreaterThanGreaterThanEquals(_)) => true
    (
      GreaterThanGreaterThanGreaterThanEquals(_),
      GreaterThanGreaterThanGreaterThanEquals(_),
    ) => true
    (AmpersandAmpersandEquals(_), AmpersandAmpersandEquals(_)) => true
    (BarBarEquals(_), BarBarEquals(_)) => true
    (QuestionQuestionEquals(_), QuestionQuestionEquals(_)) => true
    (PlusPlus(_), PlusPlus(_)) => true
    (MinusMinus(_), MinusMinus(_)) => true
    (Question(_), Question(_)) => true
    (Colon(_), Colon(_)) => true
    (QuestionDot(_), QuestionDot(_)) => true
    (ExclamationDot(_), ExclamationDot(_)) => true
    (Arrow(_), Arrow(_)) => true
    (Dot(_), Dot(_)) => true
    (DotDotDot(_), DotDotDot(_)) => true
    (OpenBrace(_), OpenBrace(_)) => true
    (CloseBrace(_), CloseBrace(_)) => true
    (OpenParen(_), OpenParen(_)) => true
    (CloseParen(_), CloseParen(_)) => true
    (OpenBracket(_), OpenBracket(_)) => true
    (CloseBracket(_), CloseBracket(_)) => true
    (Semicolon(_), Semicolon(_)) => true
    (Comma(_), Comma(_)) => true
    (At(_), At(_)) => true
    (LessThanSlash(_), LessThanSlash(_)) => true
    (SlashGreaterThan(_), SlashGreaterThan(_)) => true
    (EOF(_), EOF(_)) => true
    _ => false
  }
}

///|
test "scanner_v2 simple identifier" {
  let tokens = tokenize_v2("hello", "test.ts")
  assert_eq(tokens.length(), 2) // identifier + EOF
  match tokens[0] {
    Identifier(name, _) => assert_eq(name, "hello")
    _ => assert_true(false)
  }
}

///|
test "scanner_v2 keywords" {
  let tokens = tokenize_v2("const let var function class", "test.ts")
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
test "scanner_v2 string literals" {
  let tokens = tokenize_v2("\"hello world\" 'test'", "test.ts")
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
test "scanner_v2 number literals" {
  let tokens = tokenize_v2("42 3.14", "test.ts")
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
test "scanner_v2 operators" {
  let tokens = tokenize_v2("+ - * / = == === != !==", "test.ts")
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
test "scanner_v2 punctuation" {
  let tokens = tokenize_v2("( ) { } [ ] ; , .", "test.ts")
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
test "scanner_v2 arrow function" {
  let tokens = tokenize_v2("=>", "test.ts")
  assert_eq(tokens.length(), 2) // arrow + EOF
  match tokens[0] {
    Arrow(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scanner_v2 comment skipping" {
  let tokens = tokenize_v2("// comment\nconst x = 5;", "test.ts")
  // Comments should be skipped: const, identifier, =, number, ;, EOF
  assert_eq(tokens.length(), 6)
  match tokens[0] {
    KeywordConst(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scanner_v2 multiline comment skipping" {
  let tokens = tokenize_v2("/* multi\nline\ncomment */const x = 5;", "test.ts")
  // Comments should be skipped: const, identifier, =, number, ;, EOF
  assert_eq(tokens.length(), 6)
  match tokens[0] {
    KeywordConst(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scanner_v2 hex number" {
  let tokens = tokenize_v2("0xff 0XFF", "test.ts")
  assert_eq(tokens.length(), 3) // 2 numbers + EOF
  match tokens[0] {
    NumericLiteral(value, _) => assert_eq(value, "0xff")
    _ => assert_true(false)
  }
  match tokens[1] {
    NumericLiteral(value, _) => assert_eq(value, "0xFF")
    _ => assert_true(false)
  }
}

///|
test "scanner_v2 octal number" {
  let tokens = tokenize_v2("0o777 0O123", "test.ts")
  assert_eq(tokens.length(), 3) // 2 numbers + EOF
  match tokens[0] {
    NumericLiteral(value, _) => assert_eq(value, "0o777")
    _ => assert_true(false)
  }
  match tokens[1] {
    NumericLiteral(value, _) => assert_eq(value, "0o123")
    _ => assert_true(false)
  }
}

///|
test "scanner_v2 binary number" {
  let tokens = tokenize_v2("0b1010 0B1111", "test.ts")
  assert_eq(tokens.length(), 3) // 2 numbers + EOF
  match tokens[0] {
    NumericLiteral(value, _) => assert_eq(value, "0b1010")
    _ => assert_true(false)
  }
  match tokens[1] {
    NumericLiteral(value, _) => assert_eq(value, "0b1111")
    _ => assert_true(false)
  }
}

///|
test "scanner_v2 bigint" {
  let tokens = tokenize_v2("123n 0xFFn 0o77n 0b1010n", "test.ts")
  assert_eq(tokens.length(), 5) // 4 bigints + EOF
  match tokens[0] {
    BigIntLiteral(value, _) => assert_eq(value, "123n")
    _ => assert_true(false)
  }
  match tokens[1] {
    BigIntLiteral(value, _) => assert_eq(value, "0xFFn")
    _ => assert_true(false)
  }
  match tokens[2] {
    BigIntLiteral(value, _) => assert_eq(value, "0o77n")
    _ => assert_true(false)
  }
  match tokens[3] {
    BigIntLiteral(value, _) => assert_eq(value, "0b1010n")
    _ => assert_true(false)
  }
}

///|
test "scanner_v2 numeric separator" {
  let tokens = tokenize_v2("1_000_000 0xFF_FF", "test.ts")
  assert_eq(tokens.length(), 3) // 2 numbers + EOF
  match tokens[0] {
    NumericLiteral(value, _) => assert_eq(value, "1000000")
    _ => assert_true(false)
  }
  match tokens[1] {
    NumericLiteral(value, _) => assert_eq(value, "0xFFFF")
    _ => assert_true(false)
  }
}

///|
test "scanner_v2 private identifier" {
  let tokens = tokenize_v2("#privateField", "test.ts")
  assert_eq(tokens.length(), 2) // private identifier + EOF
  match tokens[0] {
    PrivateIdentifier(name, _) => assert_eq(name, "#privateField")
    _ => assert_true(false)
  }
}

///|
test "scanner_v2 template literal" {
  let tokens = tokenize_v2("`hello world`", "test.ts")
  assert_eq(tokens.length(), 2) // template + EOF
  match tokens[0] {
    TemplateLiteral(value, _) => assert_eq(value, "hello world")
    _ => assert_true(false)
  }
}

///|
test "scanner_v2 template head" {
  let tokens = tokenize_v2("`hello ${", "test.ts")
  assert_eq(tokens.length(), 2) // template head + EOF
  match tokens[0] {
    TemplateHead(value, _) => assert_eq(value, "hello ")
    _ => assert_true(false)
  }
}

///|
test "scanner_v2 empty source" {
  let tokens = tokenize_v2("", "test.ts")
  assert_eq(tokens.length(), 1) // Only EOF
  match tokens[0] {
    EOF(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scanner_v2 whitespace only" {
  let tokens = tokenize_v2("   \n  \t  ", "test.ts")
  assert_eq(tokens.length(), 1) // Only EOF (whitespace skipped)
  match tokens[0] {
    EOF(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scanner_v2 spread operator" {
  let tokens = tokenize_v2("...", "test.ts")
  assert_eq(tokens.length(), 2) // ... + EOF
  match tokens[0] {
    DotDotDot(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scanner_v2 logical operators" {
  let tokens = tokenize_v2("&& || ?? ?.", "test.ts")
  assert_eq(tokens.length(), 5) // 4 operators + EOF
  match tokens[0] {
    AmpersandAmpersand(_) => ()
    _ => assert_true(false)
  }
  match tokens[1] {
    BarBar(_) => ()
    _ => assert_true(false)
  }
  match tokens[2] {
    QuestionQuestion(_) => ()
    _ => assert_true(false)
  }
  match tokens[3] {
    QuestionDot(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scanner_v2 assignment operators" {
  let tokens = tokenize_v2("+= -= *= /= %= **=", "test.ts")
  assert_eq(tokens.length(), 7) // 6 operators + EOF
  match tokens[0] {
    PlusEquals(_) => ()
    _ => assert_true(false)
  }
  match tokens[1] {
    MinusEquals(_) => ()
    _ => assert_true(false)
  }
  match tokens[2] {
    StarEquals(_) => ()
    _ => assert_true(false)
  }
  match tokens[3] {
    SlashEquals(_) => ()
    _ => assert_true(false)
  }
  match tokens[4] {
    PercentEquals(_) => ()
    _ => assert_true(false)
  }
  match tokens[5] {
    StarStarEquals(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scanner_v2 bitwise operators" {
  let tokens = tokenize_v2("<< >> >>>", "test.ts")
  assert_eq(tokens.length(), 4) // 3 operators + EOF
  match tokens[0] {
    LessThanLessThan(_) => ()
    _ => assert_true(false)
  }
  match tokens[1] {
    GreaterThanGreaterThan(_) => ()
    _ => assert_true(false)
  }
  match tokens[2] {
    GreaterThanGreaterThanGreaterThan(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scanner_v2 complex expression" {
  let tokens = tokenize_v2("const x = 1 + 2 * 3;", "test.ts")
  // const, x, =, 1, +, 2, *, 3, ;, EOF
  assert_eq(tokens.length(), 10)
  match tokens[0] {
    KeywordConst(_) => ()
    _ => assert_true(false)
  }
  match tokens[1] {
    Identifier(name, _) => assert_eq(name, "x")
    _ => assert_true(false)
  }
  match tokens[3] {
    NumericLiteral(value, _) => assert_eq(value, "1")
    _ => assert_true(false)
  }
}

///|
test "scanner_v2 exponent number" {
  let tokens = tokenize_v2("1e10 1E10 1e+10 1e-10", "test.ts")
  assert_eq(tokens.length(), 5) // 4 numbers + EOF
  match tokens[0] {
    NumericLiteral(value, _) => assert_eq(value, "1e10")
    _ => assert_true(false)
  }
  match tokens[1] {
    NumericLiteral(value, _) => assert_eq(value, "1e10")
    _ => assert_true(false)
  }
  match tokens[2] {
    NumericLiteral(value, _) => assert_eq(value, "1e+10")
    _ => assert_true(false)
  }
  match tokens[3] {
    NumericLiteral(value, _) => assert_eq(value, "1e-10")
    _ => assert_true(false)
  }
}

///|
test "scanner_v2 jsx operators" {
  let tokens = tokenize_v2("</  />", "test.ts")
  assert_eq(tokens.length(), 3) // </ /> EOF
  match tokens[0] {
    LessThanSlash(_) => ()
    _ => assert_true(false)
  }
  match tokens[1] {
    SlashGreaterThan(_) => ()
    _ => assert_true(false)
  }
}
