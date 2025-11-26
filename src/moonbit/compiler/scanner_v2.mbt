// Scanner V2 - Using MoonBit Idiomatic Pattern Matching
// Based on https://github.com/moonbitlang/mbtcc/blob/master/lexer/lexer.mbt
//
// This scanner uses loop with StringView pattern matching instead of
// the traditional peek_char/advance approach.

///|
/// State for tracking position in the scanner
struct ScanState {
  mut line : Int
  mut col : Int
  mut offset : Int
}

///|
/// Skip single-line comment and return remaining code
fn skip_line_comment(
  code : StringView,
  state : ScanState,
) -> StringView {
  loop code {
    [] => code
    ['\n', .. rest] => {
      state.line += 1
      state.col = 1
      state.offset += 1
      rest
    }
    [_, .. rest] => {
      state.col += 1
      state.offset += 1
      continue rest
    }
  }
}

///|
/// Skip block comment and return remaining code
fn skip_block_comment(
  code : StringView,
  state : ScanState,
) -> StringView {
  loop code {
    [] => code
    [.. "*/", .. rest] => {
      state.col += 2
      state.offset += 2
      rest
    }
    ['\n', .. rest] => {
      state.line += 1
      state.col = 1
      state.offset += 1
      continue rest
    }
    [_, .. rest] => {
      state.col += 1
      state.offset += 1
      continue rest
    }
  }
}

///|
/// Scan double-quoted string
fn scan_double_string(
  code : StringView,
  state : ScanState,
  content : StringBuilder,
) -> StringView {
  loop code {
    [] => code
    ['"', .. rest] => {
      state.col += 1
      state.offset += 1
      rest
    }
    [.. "\\n", .. rest] => {
      content.write_char('\n')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\r", .. rest] => {
      content.write_char('\r')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\t", .. rest] => {
      content.write_char('\t')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\\\", .. rest] => {
      content.write_char('\\')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\\"", .. rest] => {
      content.write_char('"')
      state.col += 2
      state.offset += 2
      continue rest
    }
    ['\n', ..] => code // Unterminated at newline
    [ch, .. rest] => {
      content.write_char(ch)
      state.col += 1
      state.offset += 1
      continue rest
    }
  }
}

///|
/// Scan single-quoted string
fn scan_single_string(
  code : StringView,
  state : ScanState,
  content : StringBuilder,
) -> StringView {
  loop code {
    [] => code
    ['\'', .. rest] => {
      state.col += 1
      state.offset += 1
      rest
    }
    [.. "\\n", .. rest] => {
      content.write_char('\n')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\r", .. rest] => {
      content.write_char('\r')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\t", .. rest] => {
      content.write_char('\t')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\\\", .. rest] => {
      content.write_char('\\')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\'", .. rest] => {
      content.write_char('\'')
      state.col += 2
      state.offset += 2
      continue rest
    }
    ['\n', ..] => code // Unterminated at newline
    [ch, .. rest] => {
      content.write_char(ch)
      state.col += 1
      state.offset += 1
      continue rest
    }
  }
}

///|
/// Template literal scanning result
enum TemplateScanResultV2 {
  Complete(StringView)
  Head(StringView)
}

///|
/// Scan template literal
fn scan_template_literal_v2(
  code : StringView,
  state : ScanState,
  content : StringBuilder,
) -> TemplateScanResultV2 {
  loop code {
    [] => Complete(code)
    ['`', .. rest] => {
      state.col += 1
      state.offset += 1
      Complete(rest)
    }
    [.. "${", .. rest] => {
      state.col += 2
      state.offset += 2
      Head(rest)
    }
    [.. "\\`", .. rest] => {
      content.write_char('`')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\$", .. rest] => {
      content.write_char('$')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\n", .. rest] => {
      content.write_char('\n')
      state.col += 2
      state.offset += 2
      continue rest
    }
    ['\n', .. rest] => {
      content.write_char('\n')
      state.line += 1
      state.col = 1
      state.offset += 1
      continue rest
    }
    [ch, .. rest] => {
      content.write_char(ch)
      state.col += 1
      state.offset += 1
      continue rest
    }
  }
}

///|
/// Scan hex digits
fn scan_hex_digits(
  code : StringView,
  state : ScanState,
  digits : StringBuilder,
) -> StringView {
  loop code {
    ['0'..='9' | 'a'..='f' | 'A'..='F' as ch, .. rest] => {
      digits.write_char(ch)
      state.col += 1
      state.offset += 1
      continue rest
    }
    ['_', .. rest] => {
      state.col += 1
      state.offset += 1
      continue rest
    }
    remaining => remaining
  }
}

///|
/// Scan octal digits
fn scan_octal_digits(
  code : StringView,
  state : ScanState,
  digits : StringBuilder,
) -> StringView {
  loop code {
    ['0'..='7' as ch, .. rest] => {
      digits.write_char(ch)
      state.col += 1
      state.offset += 1
      continue rest
    }
    ['_', .. rest] => {
      state.col += 1
      state.offset += 1
      continue rest
    }
    remaining => remaining
  }
}

///|
/// Scan binary digits
fn scan_binary_digits(
  code : StringView,
  state : ScanState,
  digits : StringBuilder,
) -> StringView {
  loop code {
    ['0' | '1' as ch, .. rest] => {
      digits.write_char(ch)
      state.col += 1
      state.offset += 1
      continue rest
    }
    ['_', .. rest] => {
      state.col += 1
      state.offset += 1
      continue rest
    }
    remaining => remaining
  }
}

///|
/// Scan decimal digits
fn scan_decimal_digits(
  code : StringView,
  state : ScanState,
  num : StringBuilder,
) -> StringView {
  loop code {
    ['0'..='9' as ch, .. rest] => {
      num.write_char(ch)
      state.col += 1
      state.offset += 1
      continue rest
    }
    ['_', .. rest] => {
      state.col += 1
      state.offset += 1
      continue rest
    }
    remaining => remaining
  }
}

///|
/// Scan identifier characters
fn scan_ident_chars(
  code : StringView,
  state : ScanState,
  ident : StringBuilder,
) -> StringView {
  loop code {
    ['a'..='z' | 'A'..='Z' | '0'..='9' | '_' | '$' as ch, .. rest] => {
      ident.write_char(ch)
      state.col += 1
      state.offset += 1
      continue rest
    }
    remaining => remaining
  }
}

///|
/// Get keyword token from identifier
fn keyword_token(text : String, loc : SourceLocation) -> Token {
  match text {
    "any" => KeywordAny(loc)
    "boolean" => KeywordBoolean(loc)
    "number" => KeywordNumber(loc)
    "string" => KeywordString(loc)
    "symbol" => KeywordSymbol(loc)
    "object" => KeywordObject(loc)
    "void" => KeywordVoid(loc)
    "unknown" => KeywordUnknown(loc)
    "never" => KeywordNever(loc)
    "undefined" => KeywordUndefined(loc)
    "null" => KeywordNull(loc)
    "let" => KeywordLet(loc)
    "const" => KeywordConst(loc)
    "var" => KeywordVar(loc)
    "function" => KeywordFunction(loc)
    "class" => KeywordClass(loc)
    "interface" => KeywordInterface(loc)
    "enum" => KeywordEnum(loc)
    "type" => KeywordType(loc)
    "namespace" => KeywordNamespace(loc)
    "module" => KeywordModule(loc)
    "if" => KeywordIf(loc)
    "else" => KeywordElse(loc)
    "switch" => KeywordSwitch(loc)
    "case" => KeywordCase(loc)
    "default" => KeywordDefault(loc)
    "for" => KeywordFor(loc)
    "while" => KeywordWhile(loc)
    "do" => KeywordDo(loc)
    "break" => KeywordBreak(loc)
    "continue" => KeywordContinue(loc)
    "return" => KeywordReturn(loc)
    "throw" => KeywordThrow(loc)
    "try" => KeywordTry(loc)
    "catch" => KeywordCatch(loc)
    "finally" => KeywordFinally(loc)
    "public" => KeywordPublic(loc)
    "private" => KeywordPrivate(loc)
    "protected" => KeywordProtected(loc)
    "static" => KeywordStatic(loc)
    "readonly" => KeywordReadonly(loc)
    "abstract" => KeywordAbstract(loc)
    "async" => KeywordAsync(loc)
    "await" => KeywordAwait(loc)
    "new" => KeywordNew(loc)
    "this" => KeywordThis(loc)
    "super" => KeywordSuper(loc)
    "import" => KeywordImport(loc)
    "export" => KeywordExport(loc)
    "from" => KeywordFrom(loc)
    "as" => KeywordAs(loc)
    "satisfies" => KeywordSatisfies(loc)
    "extends" => KeywordExtends(loc)
    "implements" => KeywordImplements(loc)
    "yield" => KeywordYield(loc)
    "in" => KeywordIn(loc)
    "of" => KeywordOf(loc)
    "instanceof" => KeywordInstanceOf(loc)
    "typeof" => KeywordTypeOf(loc)
    "delete" => KeywordDelete(loc)
    "debugger" => KeywordDebugger(loc)
    "declare" => KeywordDeclare(loc)
    _ => Identifier(text, loc)
  }
}

///|
/// Tokenize the entire source using pattern matching
pub fn tokenize_v2(source : String, file_path : String) -> Array[Token] {
  let tokens : Array[Token] = []
  let state : ScanState = { line: 1, col: 1, offset: 0 }

  fn make_loc(
    start_line : Int,
    start_col : Int,
    start_offset : Int,
  ) -> SourceLocation {
    SourceLocation::new(
      file_path,
      Position::new(start_line, start_col, start_offset),
      Position::new(state.line, state.col, state.offset),
    )
  }

  // Main tokenization loop
  loop source[:] {
    // End of input
    [] => {
      let loc = make_loc(state.line, state.col, state.offset)
      tokens.push(EOF(loc))
    }

    // === Whitespace ===
    [' ' | '\t', .. rest] => {
      state.col += 1
      state.offset += 1
      continue rest
    }
    ['\r', .. rest] => {
      state.offset += 1
      continue rest
    }
    ['\n', .. rest] => {
      state.line += 1
      state.col = 1
      state.offset += 1
      continue rest
    }

    // === Comments ===
    [.. "//", .. rest] => {
      state.col += 2
      state.offset += 2
      let rest2 = skip_line_comment(rest, state)
      continue rest2
    }
    [.. "/*", .. rest] => {
      state.col += 2
      state.offset += 2
      let rest2 = skip_block_comment(rest, state)
      continue rest2
    }

    // === Multi-character operators (longest match first) ===
    [.. ">>>=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 4
      state.offset += 4
      tokens.push(GreaterThanGreaterThanGreaterThanEquals(loc))
      continue rest
    }
    [.. "===", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 3
      state.offset += 3
      tokens.push(EqualsEqualsEquals(loc))
      continue rest
    }
    [.. "!==", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 3
      state.offset += 3
      tokens.push(ExclamationEqualsEquals(loc))
      continue rest
    }
    [.. ">>>", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 3
      state.offset += 3
      tokens.push(GreaterThanGreaterThanGreaterThan(loc))
      continue rest
    }
    [.. "<<=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 3
      state.offset += 3
      tokens.push(LessThanLessThanEquals(loc))
      continue rest
    }
    [.. ">>=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 3
      state.offset += 3
      tokens.push(GreaterThanGreaterThanEquals(loc))
      continue rest
    }
    [.. "**=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 3
      state.offset += 3
      tokens.push(StarStarEquals(loc))
      continue rest
    }
    [.. "&&=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 3
      state.offset += 3
      tokens.push(AmpersandAmpersandEquals(loc))
      continue rest
    }
    [.. "||=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 3
      state.offset += 3
      tokens.push(BarBarEquals(loc))
      continue rest
    }
    [.. "??=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 3
      state.offset += 3
      tokens.push(QuestionQuestionEquals(loc))
      continue rest
    }
    [.. "...", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 3
      state.offset += 3
      tokens.push(DotDotDot(loc))
      continue rest
    }

    // 2-character operators
    [.. "==", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(EqualsEquals(loc))
      continue rest
    }
    [.. "!=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(ExclamationEquals(loc))
      continue rest
    }
    [.. "<=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(LessThanEquals(loc))
      continue rest
    }
    [.. ">=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(GreaterThanEquals(loc))
      continue rest
    }
    [.. "<<", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(LessThanLessThan(loc))
      continue rest
    }
    [.. ">>", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(GreaterThanGreaterThan(loc))
      continue rest
    }
    [.. "++", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(PlusPlus(loc))
      continue rest
    }
    [.. "--", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(MinusMinus(loc))
      continue rest
    }
    [.. "**", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(StarStar(loc))
      continue rest
    }
    [.. "&&", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(AmpersandAmpersand(loc))
      continue rest
    }
    [.. "||", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(BarBar(loc))
      continue rest
    }
    [.. "??", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(QuestionQuestion(loc))
      continue rest
    }
    [.. "?.", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(QuestionDot(loc))
      continue rest
    }
    [.. "+=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(PlusEquals(loc))
      continue rest
    }
    [.. "-=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(MinusEquals(loc))
      continue rest
    }
    [.. "*=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(StarEquals(loc))
      continue rest
    }
    [.. "/=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(SlashEquals(loc))
      continue rest
    }
    [.. "%=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(PercentEquals(loc))
      continue rest
    }
    [.. "&=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(AmpersandEquals(loc))
      continue rest
    }
    [.. "|=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(BarEquals(loc))
      continue rest
    }
    [.. "^=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(CaretEquals(loc))
      continue rest
    }
    [.. "=>", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(Arrow(loc))
      continue rest
    }
    [.. "</", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(LessThanSlash(loc))
      continue rest
    }
    [.. "/>", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(SlashGreaterThan(loc))
      continue rest
    }
    [.. "!.", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(ExclamationDot(loc))
      continue rest
    }

    // === Single-character operators ===
    ['+', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(Plus(loc))
      continue rest
    }
    ['-', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(Minus(loc))
      continue rest
    }
    ['*', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(Star(loc))
      continue rest
    }
    ['/', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(Slash(loc))
      continue rest
    }
    ['%', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(Percent(loc))
      continue rest
    }
    ['<', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(LessThan(loc))
      continue rest
    }
    ['>', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(GreaterThan(loc))
      continue rest
    }
    ['=', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(Equals(loc))
      continue rest
    }
    ['!', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(Exclamation(loc))
      continue rest
    }
    ['&', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(Ampersand(loc))
      continue rest
    }
    ['|', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(Bar(loc))
      continue rest
    }
    ['^', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(Caret(loc))
      continue rest
    }
    ['~', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(Tilde(loc))
      continue rest
    }
    ['?', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(Question(loc))
      continue rest
    }
    [':', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(Colon(loc))
      continue rest
    }
    [';', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(Semicolon(loc))
      continue rest
    }
    [',', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(Comma(loc))
      continue rest
    }
    ['.', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(Dot(loc))
      continue rest
    }
    ['(', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(OpenParen(loc))
      continue rest
    }
    [')', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(CloseParen(loc))
      continue rest
    }
    ['{', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(OpenBrace(loc))
      continue rest
    }
    ['}', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(CloseBrace(loc))
      continue rest
    }
    ['[', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(OpenBracket(loc))
      continue rest
    }
    [']', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(CloseBracket(loc))
      continue rest
    }
    ['@', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(At(loc))
      continue rest
    }

    // === Private identifier (#name) ===
    ['#', .. rest] => {
      let start_line = state.line
      let start_col = state.col
      let start_offset = state.offset
      state.col += 1
      state.offset += 1
      let ident = StringBuilder::new()
      ident.write_char('#')
      let rest2 = scan_ident_chars(rest, state, ident)
      let loc = SourceLocation::new(
        file_path,
        Position::new(start_line, start_col, start_offset),
        Position::new(state.line, state.col, state.offset),
      )
      tokens.push(PrivateIdentifier(ident.to_string(), loc))
      continue rest2
    }

    // === String literals ===
    ['"', .. rest] => {
      let start_line = state.line
      let start_col = state.col
      let start_offset = state.offset
      state.col += 1
      state.offset += 1
      let content = StringBuilder::new()
      let rest2 = scan_double_string(rest, state, content)
      let loc = SourceLocation::new(
        file_path,
        Position::new(start_line, start_col, start_offset),
        Position::new(state.line, state.col, state.offset),
      )
      tokens.push(StringLiteral(content.to_string(), loc))
      continue rest2
    }
    ['\'', .. rest] => {
      let start_line = state.line
      let start_col = state.col
      let start_offset = state.offset
      state.col += 1
      state.offset += 1
      let content = StringBuilder::new()
      let rest2 = scan_single_string(rest, state, content)
      let loc = SourceLocation::new(
        file_path,
        Position::new(start_line, start_col, start_offset),
        Position::new(state.line, state.col, state.offset),
      )
      tokens.push(StringLiteral(content.to_string(), loc))
      continue rest2
    }

    // === Template literal ===
    ['`', .. rest] => {
      let start_line = state.line
      let start_col = state.col
      let start_offset = state.offset
      state.col += 1
      state.offset += 1
      let content = StringBuilder::new()
      match scan_template_literal_v2(rest, state, content) {
        TemplateScanResultV2::Complete(rest2) => {
          let loc = SourceLocation::new(
            file_path,
            Position::new(start_line, start_col, start_offset),
            Position::new(state.line, state.col, state.offset),
          )
          tokens.push(TemplateLiteral(content.to_string(), loc))
          continue rest2
        }
        TemplateScanResultV2::Head(rest2) => {
          let loc = SourceLocation::new(
            file_path,
            Position::new(start_line, start_col, start_offset),
            Position::new(state.line, state.col, state.offset),
          )
          tokens.push(TemplateHead(content.to_string(), loc))
          continue rest2
        }
      }
    }

    // === Numbers ===
    [.. "0x", .. rest] | [.. "0X", .. rest] => {
      let start_col = state.col
      let start_offset = state.offset
      state.col += 2
      state.offset += 2
      let digits = StringBuilder::new()
      digits.write_string("0x")
      let rest2 = scan_hex_digits(rest, state, digits)
      match rest2 {
        ['n', .. rest3] => {
          state.col += 1
          state.offset += 1
          let loc = SourceLocation::new(
            file_path,
            Position::new(state.line, start_col, start_offset),
            Position::new(state.line, state.col, state.offset),
          )
          tokens.push(BigIntLiteral(digits.to_string() + "n", loc))
          continue rest3
        }
        _ => {
          let loc = SourceLocation::new(
            file_path,
            Position::new(state.line, start_col, start_offset),
            Position::new(state.line, state.col, state.offset),
          )
          tokens.push(NumericLiteral(digits.to_string(), loc))
          continue rest2
        }
      }
    }
    [.. "0o", .. rest] | [.. "0O", .. rest] => {
      let start_col = state.col
      let start_offset = state.offset
      state.col += 2
      state.offset += 2
      let digits = StringBuilder::new()
      digits.write_string("0o")
      let rest2 = scan_octal_digits(rest, state, digits)
      match rest2 {
        ['n', .. rest3] => {
          state.col += 1
          state.offset += 1
          let loc = SourceLocation::new(
            file_path,
            Position::new(state.line, start_col, start_offset),
            Position::new(state.line, state.col, state.offset),
          )
          tokens.push(BigIntLiteral(digits.to_string() + "n", loc))
          continue rest3
        }
        _ => {
          let loc = SourceLocation::new(
            file_path,
            Position::new(state.line, start_col, start_offset),
            Position::new(state.line, state.col, state.offset),
          )
          tokens.push(NumericLiteral(digits.to_string(), loc))
          continue rest2
        }
      }
    }
    [.. "0b", .. rest] | [.. "0B", .. rest] => {
      let start_col = state.col
      let start_offset = state.offset
      state.col += 2
      state.offset += 2
      let digits = StringBuilder::new()
      digits.write_string("0b")
      let rest2 = scan_binary_digits(rest, state, digits)
      match rest2 {
        ['n', .. rest3] => {
          state.col += 1
          state.offset += 1
          let loc = SourceLocation::new(
            file_path,
            Position::new(state.line, start_col, start_offset),
            Position::new(state.line, state.col, state.offset),
          )
          tokens.push(BigIntLiteral(digits.to_string() + "n", loc))
          continue rest3
        }
        _ => {
          let loc = SourceLocation::new(
            file_path,
            Position::new(state.line, start_col, start_offset),
            Position::new(state.line, state.col, state.offset),
          )
          tokens.push(NumericLiteral(digits.to_string(), loc))
          continue rest2
        }
      }
    }
    // Decimal number
    ['0'..='9' as first_digit, .. rest] => {
      let start_col = state.col
      let start_offset = state.offset
      state.col += 1
      state.offset += 1
      let num = StringBuilder::new()
      num.write_char(first_digit)
      // Integer part
      let rest2 = scan_decimal_digits(rest, state, num)
      // Decimal part
      let (rest3, has_dot) = match rest2 {
        ['.', '0'..='9' as ch, .. rest4] => {
          num.write_char('.')
          num.write_char(ch)
          state.col += 2
          state.offset += 2
          (scan_decimal_digits(rest4, state, num), true)
        }
        _ => (rest2, false)
      }
      // Exponent part
      let (rest4, has_exp) = match rest3 {
        ['e' | 'E', '+' | '-' as sign, '0'..='9' as ch, .. rest5] => {
          num.write_char('e')
          num.write_char(sign)
          num.write_char(ch)
          state.col += 3
          state.offset += 3
          (scan_decimal_digits(rest5, state, num), true)
        }
        ['e' | 'E', '0'..='9' as ch, .. rest5] => {
          num.write_char('e')
          num.write_char(ch)
          state.col += 2
          state.offset += 2
          (scan_decimal_digits(rest5, state, num), true)
        }
        _ => (rest3, false)
      }
      // BigInt suffix
      match rest4 {
        ['n', .. rest5] if not(has_dot) && not(has_exp) => {
          state.col += 1
          state.offset += 1
          let loc = SourceLocation::new(
            file_path,
            Position::new(state.line, start_col, start_offset),
            Position::new(state.line, state.col, state.offset),
          )
          tokens.push(BigIntLiteral(num.to_string() + "n", loc))
          continue rest5
        }
        _ => {
          let loc = SourceLocation::new(
            file_path,
            Position::new(state.line, start_col, start_offset),
            Position::new(state.line, state.col, state.offset),
          )
          tokens.push(NumericLiteral(num.to_string(), loc))
          continue rest4
        }
      }
    }

    // === Identifiers and keywords ===
    ['a'..='z' | 'A'..='Z' | '_' | '$' as first_char, .. rest] => {
      let start_col = state.col
      let start_offset = state.offset
      state.col += 1
      state.offset += 1
      let ident = StringBuilder::new()
      ident.write_char(first_char)
      let rest2 = scan_ident_chars(rest, state, ident)
      let loc = SourceLocation::new(
        file_path,
        Position::new(state.line, start_col, start_offset),
        Position::new(state.line, state.col, state.offset),
      )
      tokens.push(keyword_token(ident.to_string(), loc))
      continue rest2
    }

    // === Unknown character ===
    [ch, .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(Unknown(Char::to_string(ch), loc))
      continue rest
    }
  }
  tokens
}
