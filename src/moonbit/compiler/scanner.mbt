// Scanner (Lexical Analyzer) for TypeScript
// Converts source text into a stream of tokens

///|
/// Scanner state
pub struct Scanner {
  source : String
  file_path : String
  position : Int
  line : Int
  column : Int
  length : Int
} derive(Show)

///|
/// Create a new scanner
pub fn Scanner::new(source : String, file_path : String) -> Scanner {
  {
    source,
    file_path,
    position: 0,
    line: 1,
    column: 1,
    length: source.length(),
  }
}

///|
/// Scan all tokens from source
pub fn scan_all(scanner : Scanner) -> Array[Token] {
  let tokens : Array[Token] = []
  let mut current_scanner = scanner
  let mut prev_token : Token? = None
  let mut template_depth = 0  // Track nested template interpolations
  let mut should_continue = true
  while should_continue {
    // After CloseBrace inside a template interpolation, scan template continuation
    let (token, next_scanner) = match prev_token {
      Some(CloseBrace(_)) if template_depth > 0 => {
        scan_template_continuation(current_scanner)
      }
      _ => scan_token_with_context(current_scanner, prev_token)
    }
    tokens.push(token)
    // Track template depth
    match token {
      TemplateHead(_, _) | TemplateMiddle(_, _) => template_depth = template_depth + 1
      TemplateTail(_, _) => template_depth = template_depth - 1
      EOF(_) => should_continue = false
      _ => ()
    }
    match token {
      EOF(_) => ()
      _ => {
        prev_token = Some(token)
        current_scanner = next_scanner
      }
    }
  }
  tokens
}

///|
/// Scan a single token with context (for regex disambiguation)
pub fn scan_token_with_context(scanner : Scanner, prev_token : Token?) -> (Token, Scanner) {
  // Skip whitespace and comments
  let scanner = skip_trivia(scanner)

  // Check if at end
  if scanner.position >= scanner.length {
    let loc = current_location(scanner)
    return (EOF(loc), scanner)
  }

  let start_pos = scanner.position
  let start_line = scanner.line
  let start_col = scanner.column
  let ch = peek_char(scanner)

  // Helper to create location
  fn make_location(
    scanner : Scanner,
    start_pos : Int,
    start_line : Int,
    start_col : Int,
  ) -> SourceLocation {
    SourceLocation::new(
      scanner.file_path,
      Position::new(start_line, start_col, start_pos),
      Position::new(scanner.line, scanner.column, scanner.position),
    )
  }

  // Special handling for / - could be regex or division
  if ch == '/' {
    let scanner_after_slash = advance(scanner)
    let next_ch = peek_char(scanner_after_slash)
    // Check for comments first
    if next_ch == '/' || next_ch == '*' {
      // It's a comment, let regular scan_token handle it
      return scan_token(scanner)
    }
    // Check for /= and />
    if next_ch == '=' {
      let scanner = advance(scanner_after_slash)
      return (SlashEquals(make_location(scanner, start_pos, start_line, start_col)), scanner)
    }
    if next_ch == '>' {
      let scanner = advance(scanner_after_slash)
      return (SlashGreaterThan(make_location(scanner, start_pos, start_line, start_col)), scanner)
    }
    // Check if previous token allows regex
    if allows_regex(prev_token) {
      // Try to scan as regex
      match scan_regex(scanner_after_slash, start_pos, start_line, start_col) {
        Some(result) => return result
        None => {
          // Fall back to division
          return (Slash(make_location(scanner_after_slash, start_pos, start_line, start_col)), scanner_after_slash)
        }
      }
    } else {
      // Division operator
      return (Slash(make_location(scanner_after_slash, start_pos, start_line, start_col)), scanner_after_slash)
    }
  }

  // Delegate to regular scan_token for other cases
  scan_token(scanner)
}

///|
/// Scan a single token (without context)
pub fn scan_token(scanner : Scanner) -> (Token, Scanner) {
  // Skip whitespace and comments
  let scanner = skip_trivia(scanner)
  if scanner.position >= scanner.length {
    return (EOF(current_location(scanner)), scanner)
  }
  let ch = peek_char(scanner)
  let start_pos = scanner.position
  let start_line = scanner.line
  let start_col = scanner.column

  // Helper to create location
  fn make_location(
    scanner : Scanner,
    start_pos : Int,
    start_line : Int,
    start_col : Int,
  ) -> SourceLocation {
    SourceLocation::new(
      scanner.file_path,
      Position::new(start_line, start_col, start_pos),
      Position::new(scanner.line, scanner.column, scanner.position),
    )
  }

  match ch {
    // Identifiers and keywords
    'a'..='z' | 'A'..='Z' | '_' | '$' =>
      scan_identifier_or_keyword(scanner, start_pos, start_line, start_col)

    // Numbers
    '0'..='9' => scan_number(scanner, start_pos, start_line, start_col)

    // Strings
    '"' | '\'' => scan_string(scanner, start_pos, start_line, start_col)

    // Template literals
    '`' => scan_template(scanner, start_pos, start_line, start_col)

    // Operators and punctuation
    '+' => {
      let scanner = advance(scanner)
      match peek_char(scanner) {
        '+' => {
          let scanner = advance(scanner)
          (
            PlusPlus(make_location(scanner, start_pos, start_line, start_col)),
            scanner,
          )
        }
        '=' => {
          let scanner = advance(scanner)
          (
            PlusEquals(make_location(scanner, start_pos, start_line, start_col)),
            scanner,
          )
        }
        _ =>
          (
            Plus(make_location(scanner, start_pos, start_line, start_col)),
            scanner,
          )
      }
    }
    '-' => {
      let scanner = advance(scanner)
      match peek_char(scanner) {
        '-' => {
          let scanner = advance(scanner)
          (
            MinusMinus(make_location(scanner, start_pos, start_line, start_col)),
            scanner,
          )
        }
        '=' => {
          let scanner = advance(scanner)
          (
            MinusEquals(
              make_location(scanner, start_pos, start_line, start_col),
            ),
            scanner,
          )
        }
        _ =>
          (
            Minus(make_location(scanner, start_pos, start_line, start_col)),
            scanner,
          )
      }
    }
    '*' => {
      let scanner = advance(scanner)
      match peek_char(scanner) {
        '*' => {
          let scanner = advance(scanner)
          match peek_char(scanner) {
            '=' => {
              let scanner = advance(scanner)
              (
                StarStarEquals(make_location(scanner, start_pos, start_line, start_col)),
                scanner,
              )
            }
            _ =>
              (
                StarStar(make_location(scanner, start_pos, start_line, start_col)),
                scanner,
              )
          }
        }
        '=' => {
          let scanner = advance(scanner)
          (
            StarEquals(make_location(scanner, start_pos, start_line, start_col)),
            scanner,
          )
        }
        _ =>
          (
            Star(make_location(scanner, start_pos, start_line, start_col)),
            scanner,
          )
      }
    }
    '/' => {
      let scanner = advance(scanner)
      match peek_char(scanner) {
        '=' => {
          let scanner = advance(scanner)
          (
            SlashEquals(
              make_location(scanner, start_pos, start_line, start_col),
            ),
            scanner,
          )
        }
        '>' => {
          let scanner = advance(scanner)
          (
            SlashGreaterThan(
              make_location(scanner, start_pos, start_line, start_col),
            ),
            scanner,
          )
        }
        _ =>
          (
            Slash(make_location(scanner, start_pos, start_line, start_col)),
            scanner,
          )
      }
    }
    '%' => {
      let scanner = advance(scanner)
      match peek_char(scanner) {
        '=' => {
          let scanner = advance(scanner)
          (
            PercentEquals(
              make_location(scanner, start_pos, start_line, start_col),
            ),
            scanner,
          )
        }
        _ =>
          (
            Percent(make_location(scanner, start_pos, start_line, start_col)),
            scanner,
          )
      }
    }
    '<' => {
      let scanner = advance(scanner)
      match peek_char(scanner) {
        '<' => {
          let scanner = advance(scanner)
          match peek_char(scanner) {
            '=' => {
              let scanner = advance(scanner)
              (
                LessThanLessThanEquals(
                  make_location(scanner, start_pos, start_line, start_col),
                ),
                scanner,
              )
            }
            _ =>
              (
                LessThanLessThan(
                  make_location(scanner, start_pos, start_line, start_col),
                ),
                scanner,
              )
          }
        }
        '=' => {
          let scanner = advance(scanner)
          (
            LessThanEquals(
              make_location(scanner, start_pos, start_line, start_col),
            ),
            scanner,
          )
        }
        '/' => {
          let scanner = advance(scanner)
          (
            LessThanSlash(
              make_location(scanner, start_pos, start_line, start_col),
            ),
            scanner,
          )
        }
        _ =>
          (
            LessThan(make_location(scanner, start_pos, start_line, start_col)),
            scanner,
          )
      }
    }
    '>' => {
      let scanner = advance(scanner)
      match peek_char(scanner) {
        '>' => {
          let scanner = advance(scanner)
          match peek_char(scanner) {
            '>' => {
              let scanner = advance(scanner)
              match peek_char(scanner) {
                '=' => {
                  let scanner = advance(scanner)
                  (
                    GreaterThanGreaterThanGreaterThanEquals(
                      make_location(scanner, start_pos, start_line, start_col),
                    ),
                    scanner,
                  )
                }
                _ =>
                  (
                    GreaterThanGreaterThanGreaterThan(
                      make_location(scanner, start_pos, start_line, start_col),
                    ),
                    scanner,
                  )
              }
            }
            '=' => {
              let scanner = advance(scanner)
              (
                GreaterThanGreaterThanEquals(
                  make_location(scanner, start_pos, start_line, start_col),
                ),
                scanner,
              )
            }
            _ =>
              (
                GreaterThanGreaterThan(
                  make_location(scanner, start_pos, start_line, start_col),
                ),
                scanner,
              )
          }
        }
        '=' => {
          let scanner = advance(scanner)
          (
            GreaterThanEquals(
              make_location(scanner, start_pos, start_line, start_col),
            ),
            scanner,
          )
        }
        _ =>
          (
            GreaterThan(
              make_location(scanner, start_pos, start_line, start_col),
            ),
            scanner,
          )
      }
    }
    '=' => {
      let scanner = advance(scanner)
      match peek_char(scanner) {
        '=' => {
          let scanner = advance(scanner)
          match peek_char(scanner) {
            '=' => {
              let scanner = advance(scanner)
              (
                EqualsEqualsEquals(
                  make_location(scanner, start_pos, start_line, start_col),
                ),
                scanner,
              )
            }
            _ =>
              (
                EqualsEquals(
                  make_location(scanner, start_pos, start_line, start_col),
                ),
                scanner,
              )
          }
        }
        '>' => {
          let scanner = advance(scanner)
          (
            Arrow(make_location(scanner, start_pos, start_line, start_col)),
            scanner,
          )
        }
        _ =>
          (
            Equals(make_location(scanner, start_pos, start_line, start_col)),
            scanner,
          )
      }
    }
    '!' => {
      let scanner = advance(scanner)
      match peek_char(scanner) {
        '=' => {
          let scanner = advance(scanner)
          match peek_char(scanner) {
            '=' => {
              let scanner = advance(scanner)
              (
                ExclamationEqualsEquals(
                  make_location(scanner, start_pos, start_line, start_col),
                ),
                scanner,
              )
            }
            _ =>
              (
                ExclamationEquals(
                  make_location(scanner, start_pos, start_line, start_col),
                ),
                scanner,
              )
          }
        }
        _ =>
          (
            Exclamation(
              make_location(scanner, start_pos, start_line, start_col),
            ),
            scanner,
          )
      }
    }
    '&' => {
      let scanner = advance(scanner)
      match peek_char(scanner) {
        '&' => {
          let scanner = advance(scanner)
          match peek_char(scanner) {
            '=' => {
              let scanner = advance(scanner)
              (
                AmpersandAmpersandEquals(
                  make_location(scanner, start_pos, start_line, start_col),
                ),
                scanner,
              )
            }
            _ =>
              (
                AmpersandAmpersand(
                  make_location(scanner, start_pos, start_line, start_col),
                ),
                scanner,
              )
          }
        }
        '=' => {
          let scanner = advance(scanner)
          (
            AmpersandEquals(
              make_location(scanner, start_pos, start_line, start_col),
            ),
            scanner,
          )
        }
        _ =>
          (
            Ampersand(make_location(scanner, start_pos, start_line, start_col)),
            scanner,
          )
      }
    }
    '|' => {
      let scanner = advance(scanner)
      match peek_char(scanner) {
        '|' => {
          let scanner = advance(scanner)
          match peek_char(scanner) {
            '=' => {
              let scanner = advance(scanner)
              (
                BarBarEquals(make_location(scanner, start_pos, start_line, start_col)),
                scanner,
              )
            }
            _ =>
              (
                BarBar(make_location(scanner, start_pos, start_line, start_col)),
                scanner,
              )
          }
        }
        '=' => {
          let scanner = advance(scanner)
          (
            BarEquals(make_location(scanner, start_pos, start_line, start_col)),
            scanner,
          )
        }
        _ =>
          (
            Bar(make_location(scanner, start_pos, start_line, start_col)),
            scanner,
          )
      }
    }
    '^' => {
      let scanner = advance(scanner)
      match peek_char(scanner) {
        '=' => {
          let scanner = advance(scanner)
          (
            CaretEquals(
              make_location(scanner, start_pos, start_line, start_col),
            ),
            scanner,
          )
        }
        _ =>
          (
            Caret(make_location(scanner, start_pos, start_line, start_col)),
            scanner,
          )
      }
    }
    '~' => {
      let scanner = advance(scanner)
      (Tilde(make_location(scanner, start_pos, start_line, start_col)), scanner)
    }
    '?' => {
      let scanner = advance(scanner)
      match peek_char(scanner) {
        '?' => {
          let scanner = advance(scanner)
          match peek_char(scanner) {
            '=' => {
              let scanner = advance(scanner)
              (
                QuestionQuestionEquals(
                  make_location(scanner, start_pos, start_line, start_col),
                ),
                scanner,
              )
            }
            _ =>
              (
                QuestionQuestion(
                  make_location(scanner, start_pos, start_line, start_col),
                ),
                scanner,
              )
          }
        }
        '.' => {
          let scanner = advance(scanner)
          (
            QuestionDot(
              make_location(scanner, start_pos, start_line, start_col),
            ),
            scanner,
          )
        }
        _ =>
          (
            Question(make_location(scanner, start_pos, start_line, start_col)),
            scanner,
          )
      }
    }
    ':' => {
      let scanner = advance(scanner)
      (Colon(make_location(scanner, start_pos, start_line, start_col)), scanner)
    }
    '.' => {
      let scanner = advance(scanner)
      match peek_char(scanner) {
        '.' => {
          let scanner = advance(scanner)
          match peek_char(scanner) {
            '.' => {
              let scanner = advance(scanner)
              (
                DotDotDot(
                  make_location(scanner, start_pos, start_line, start_col),
                ),
                scanner,
              )
            }
            _ =>
              // Two dots is an error, but we'll emit a single dot
              (
                Dot(make_location(scanner, start_pos, start_line, start_col)),
                scanner,
              )
          }
        }
        _ =>
          (
            Dot(make_location(scanner, start_pos, start_line, start_col)),
            scanner,
          )
      }
    }
    '(' => {
      let scanner = advance(scanner)
      (
        OpenParen(make_location(scanner, start_pos, start_line, start_col)),
        scanner,
      )
    }
    ')' => {
      let scanner = advance(scanner)
      (
        CloseParen(make_location(scanner, start_pos, start_line, start_col)),
        scanner,
      )
    }
    '{' => {
      let scanner = advance(scanner)
      (
        OpenBrace(make_location(scanner, start_pos, start_line, start_col)),
        scanner,
      )
    }
    '}' => {
      let scanner = advance(scanner)
      (
        CloseBrace(make_location(scanner, start_pos, start_line, start_col)),
        scanner,
      )
    }
    '[' => {
      let scanner = advance(scanner)
      (
        OpenBracket(make_location(scanner, start_pos, start_line, start_col)),
        scanner,
      )
    }
    ']' => {
      let scanner = advance(scanner)
      (
        CloseBracket(make_location(scanner, start_pos, start_line, start_col)),
        scanner,
      )
    }
    ';' => {
      let scanner = advance(scanner)
      (
        Semicolon(make_location(scanner, start_pos, start_line, start_col)),
        scanner,
      )
    }
    ',' => {
      let scanner = advance(scanner)
      (Comma(make_location(scanner, start_pos, start_line, start_col)), scanner)
    }
    '@' => {
      let scanner = advance(scanner)
      (At(make_location(scanner, start_pos, start_line, start_col)), scanner)
    }
    _ => {
      let scanner = advance(scanner)
      let text = scanner.source.substring(start=start_pos, end=scanner.position)
      (
        Unknown(text, make_location(scanner, start_pos, start_line, start_col)),
        scanner,
      )
    }
  }
}

///|
/// Scan an identifier or keyword
fn scan_identifier_or_keyword(
  scanner : Scanner,
  start_pos : Int,
  start_line : Int,
  start_col : Int,
) -> (Token, Scanner) {
  let mut scanner = scanner

  // Scan while alphanumeric or underscore
  while scanner.position < scanner.length {
    let ch = peek_char(scanner)
    match ch {
      'a'..='z' | 'A'..='Z' | '0'..='9' | '_' | '$' =>
        scanner = advance(scanner)
      _ => break
    }
  }
  let text = scanner.source.substring(start=start_pos, end=scanner.position)
  let loc = SourceLocation::new(
    scanner.file_path,
    Position::new(start_line, start_col, start_pos),
    Position::new(scanner.line, scanner.column, scanner.position),
  )

  // Check if it's a keyword
  let token = match text {
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
  (token, scanner)
}

///|
/// Scan a number literal
fn scan_number(
  scanner : Scanner,
  start_pos : Int,
  start_line : Int,
  start_col : Int,
) -> (Token, Scanner) {
  let mut scanner = scanner

  // Simple number scanning (decimal only for now)
  while scanner.position < scanner.length {
    let ch = peek_char(scanner)
    match ch {
      '0'..='9' | '.' | 'e' | 'E' | '+' | '-' => scanner = advance(scanner)
      _ => break
    }
  }
  let text = scanner.source.substring(start=start_pos, end=scanner.position)
  let loc = SourceLocation::new(
    scanner.file_path,
    Position::new(start_line, start_col, start_pos),
    Position::new(scanner.line, scanner.column, scanner.position),
  )
  (NumericLiteral(text, loc), scanner)
}

///|
/// Scan a string literal
fn scan_string(
  scanner : Scanner,
  start_pos : Int,
  start_line : Int,
  start_col : Int,
) -> (Token, Scanner) {
  let quote = peek_char(scanner)
  let mut scanner = advance(scanner) // Skip opening quote
  let mut text = ""
  while scanner.position < scanner.length {
    let ch = peek_char(scanner)
    if ch == quote {
      scanner = advance(scanner) // Skip closing quote
      break
    }
    if ch == '\\' {
      scanner = advance(scanner)
      if scanner.position < scanner.length {
        let escaped = peek_char(scanner)
        text = text + "\\" + Char::to_string(escaped)
        scanner = advance(scanner)
      }
    } else {
      text = text + Char::to_string(ch)
      scanner = advance(scanner)
    }
  }
  let loc = SourceLocation::new(
    scanner.file_path,
    Position::new(start_line, start_col, start_pos),
    Position::new(scanner.line, scanner.column, scanner.position),
  )
  (StringLiteral(text, loc), scanner)
}

///|
/// Scan a template literal - handles interpolations properly
fn scan_template(
  scanner : Scanner,
  start_pos : Int,
  start_line : Int,
  start_col : Int,
) -> (Token, Scanner) {
  let mut scanner = advance(scanner) // Skip opening backtick
  let mut text = ""
  while scanner.position < scanner.length {
    let ch = peek_char(scanner)
    if ch == '`' {
      // End of template
      scanner = advance(scanner)
      let loc = SourceLocation::new(
        scanner.file_path,
        Position::new(start_line, start_col, start_pos),
        Position::new(scanner.line, scanner.column, scanner.position),
      )
      return (TemplateLiteral(text, loc), scanner)
    }
    if ch == '$' {
      let next_scanner = advance(scanner)
      if next_scanner.position < next_scanner.length && peek_char(next_scanner) == '{' {
        // Start of interpolation - return TemplateHead
        scanner = advance(next_scanner) // Skip ${
        let loc = SourceLocation::new(
          scanner.file_path,
          Position::new(start_line, start_col, start_pos),
          Position::new(scanner.line, scanner.column, scanner.position),
        )
        return (TemplateHead(text, loc), scanner)
      }
    }
    if ch == '\\' {
      // Escape sequence
      scanner = advance(scanner)
      if scanner.position < scanner.length {
        let escaped = peek_char(scanner)
        match escaped {
          'n' => text = text + "\n"
          'r' => text = text + "\r"
          't' => text = text + "\t"
          '\\' => text = text + "\\"
          '`' => text = text + "`"
          '$' => text = text + "$"
          _ => {
            text = text + "\\"
            text = text + Char::to_string(escaped)
          }
        }
        scanner = advance(scanner)
        continue
      }
    }
    text = text + Char::to_string(ch)
    scanner = advance(scanner)
  }
  // Reached end of file without closing backtick
  let loc = SourceLocation::new(
    scanner.file_path,
    Position::new(start_line, start_col, start_pos),
    Position::new(scanner.line, scanner.column, scanner.position),
  )
  (TemplateLiteral(text, loc), scanner)
}

///|
/// Continue scanning after an interpolation - returns TemplateMiddle or TemplateTail
pub fn scan_template_continuation(scanner : Scanner) -> (Token, Scanner) {
  let start_pos = scanner.position
  let start_line = scanner.line
  let start_col = scanner.column
  let mut scanner = scanner
  let mut text = ""
  while scanner.position < scanner.length {
    let ch = peek_char(scanner)
    if ch == '`' {
      // End of template
      scanner = advance(scanner)
      let loc = SourceLocation::new(
        scanner.file_path,
        Position::new(start_line, start_col, start_pos),
        Position::new(scanner.line, scanner.column, scanner.position),
      )
      return (TemplateTail(text, loc), scanner)
    }
    if ch == '$' {
      let next_scanner = advance(scanner)
      if next_scanner.position < next_scanner.length && peek_char(next_scanner) == '{' {
        // Another interpolation - return TemplateMiddle
        scanner = advance(next_scanner) // Skip ${
        let loc = SourceLocation::new(
          scanner.file_path,
          Position::new(start_line, start_col, start_pos),
          Position::new(scanner.line, scanner.column, scanner.position),
        )
        return (TemplateMiddle(text, loc), scanner)
      }
    }
    if ch == '\\' {
      // Escape sequence
      scanner = advance(scanner)
      if scanner.position < scanner.length {
        let escaped = peek_char(scanner)
        match escaped {
          'n' => text = text + "\n"
          'r' => text = text + "\r"
          't' => text = text + "\t"
          '\\' => text = text + "\\"
          '`' => text = text + "`"
          '$' => text = text + "$"
          _ => {
            text = text + "\\"
            text = text + Char::to_string(escaped)
          }
        }
        scanner = advance(scanner)
        continue
      }
    }
    text = text + Char::to_string(ch)
    scanner = advance(scanner)
  }
  // Reached end of file without closing backtick
  let loc = SourceLocation::new(
    scanner.file_path,
    Position::new(start_line, start_col, start_pos),
    Position::new(scanner.line, scanner.column, scanner.position),
  )
  (TemplateTail(text, loc), scanner)
}

///|
/// Skip whitespace and comments
fn skip_trivia(scanner : Scanner) -> Scanner {
  let mut scanner = scanner
  while scanner.position < scanner.length {
    let ch = peek_char(scanner)
    match ch {
      ' ' | '\t' | '\r' => scanner = advance(scanner)
      '\n' => scanner = advance_line(scanner)
      '/' =>
        // Check for comments
        if scanner.position + 1 < scanner.length {
          let next = scanner.source.get(scanner.position + 1)
          match next {
            Some('/') =>
              // Single-line comment
              scanner = skip_single_line_comment(scanner)
            Some('*') =>
              // Multi-line comment
              scanner = skip_multi_line_comment(scanner)
            _ => break
          }
        } else {
          break
        }
      _ => break
    }
  }
  scanner
}

///|
/// Skip single-line comment
fn skip_single_line_comment(scanner : Scanner) -> Scanner {
  let mut scanner = scanner

  // Skip "//"
  scanner = advance(scanner)
  scanner = advance(scanner)
  while scanner.position < scanner.length {
    let ch = peek_char(scanner)
    if ch == '\n' {
      scanner = advance_line(scanner)
      break
    }
    scanner = advance(scanner)
  }
  scanner
}

///|
/// Skip multi-line comment
fn skip_multi_line_comment(scanner : Scanner) -> Scanner {
  let mut scanner = scanner

  // Skip "/*"
  scanner = advance(scanner)
  scanner = advance(scanner)
  while scanner.position < scanner.length {
    let ch = peek_char(scanner)
    if ch == '*' && scanner.position + 1 < scanner.length {
      let next = scanner.source.get(scanner.position + 1)
      if next == Some('/') {
        scanner = advance(scanner) // Skip '*'
        scanner = advance(scanner) // Skip '/'
        break
      }
    }
    if ch == '\n' {
      scanner = advance_line(scanner)
    } else {
      scanner = advance(scanner)
    }
  }
  scanner
}

///|
/// Peek at current character
fn peek_char(scanner : Scanner) -> Char {
  if scanner.position < scanner.length {
    match scanner.source.get(scanner.position) {
      Some(ch) => Char::from_int(ch)
      None => '\u{0000}'
    }
  } else {
    '\u{0000}'
  }
}

///|
/// Advance scanner by one character
fn advance(scanner : Scanner) -> Scanner {
  if scanner.position < scanner.length {
    { ..scanner, position: scanner.position + 1, column: scanner.column + 1 }
  } else {
    scanner
  }
}

///|
/// Advance scanner to next line
fn advance_line(scanner : Scanner) -> Scanner {
  {
    ..scanner,
    position: scanner.position + 1,
    line: scanner.line + 1,
    column: 1,
  }
}

///|
/// Get current location
fn current_location(scanner : Scanner) -> SourceLocation {
  let pos = Position::new(scanner.line, scanner.column, scanner.position)
  SourceLocation::new(scanner.file_path, pos, pos)
}

///|
/// Scan a regex literal: /pattern/flags
fn scan_regex(
  scanner : Scanner,
  start_pos : Int,
  start_line : Int,
  start_col : Int,
) -> (Token, Scanner)? {
  // Already consumed the opening /
  let mut scanner = scanner
  let mut pattern = ""
  let mut in_char_class = false
  let mut found_closing_slash = false

  // Scan the pattern
  while scanner.position < scanner.length {
    let ch = peek_char(scanner)
    match ch {
      '/' if not(in_char_class) => {
        // End of pattern
        scanner = advance(scanner) // consume closing /
        found_closing_slash = true
        break
      }
      '[' => {
        in_char_class = true
        pattern = pattern + "["
        scanner = advance(scanner)
      }
      ']' => {
        in_char_class = false
        pattern = pattern + "]"
        scanner = advance(scanner)
      }
      '\\' => {
        // Escape sequence
        pattern = pattern + "\\"
        scanner = advance(scanner)
        if scanner.position < scanner.length {
          let escaped = peek_char(scanner)
          pattern = pattern + Char::to_string(escaped)
          scanner = advance(scanner)
        }
      }
      '\n' | '\r' => {
        // Invalid - newline in regex
        return None
      }
      _ => {
        pattern = pattern + Char::to_string(ch)
        scanner = advance(scanner)
      }
    }
  }

  // Must have found the closing /
  if not(found_closing_slash) {
    return None
  }

  // Scan flags (g, i, m, s, u, y)
  let mut flags = ""
  while scanner.position < scanner.length {
    let ch = peek_char(scanner)
    match ch {
      'g' | 'i' | 'm' | 's' | 'u' | 'y' => {
        flags = flags + Char::to_string(ch)
        scanner = advance(scanner)
      }
      _ => break
    }
  }

  let full_regex = "/" + pattern + "/" + flags
  let loc = SourceLocation::new(
    scanner.file_path,
    Position::new(start_line, start_col, start_pos),
    Position::new(scanner.line, scanner.column, scanner.position),
  )
  Some((RegExpLiteral(full_regex, loc), scanner))
}

///|
/// Check if previous token allows regex literal
fn allows_regex(prev_token : Token?) -> Bool {
  match prev_token {
    None => true  // Start of file
    Some(token) => match token {
      // Operators that can precede a regex
      Equals(_) | PlusEquals(_) | MinusEquals(_) | StarEquals(_) | SlashEquals(_)
      | PercentEquals(_) | AmpersandEquals(_) | BarEquals(_) | CaretEquals(_)
      | StarStarEquals(_) | LessThanLessThanEquals(_) | GreaterThanGreaterThanEquals(_)
      | GreaterThanGreaterThanGreaterThanEquals(_) | AmpersandAmpersandEquals(_)
      | BarBarEquals(_) | QuestionQuestionEquals(_) => true
      // Comparison/logical operators
      EqualsEquals(_) | ExclamationEquals(_) | EqualsEqualsEquals(_)
      | ExclamationEqualsEquals(_) | LessThan(_) | GreaterThan(_)
      | LessThanEquals(_) | GreaterThanEquals(_) | AmpersandAmpersand(_)
      | BarBar(_) | QuestionQuestion(_) => true
      // Arithmetic operators (but not + or - which could be unary)
      Star(_) | Slash(_) | Percent(_) | StarStar(_) => true
      // Bitwise operators
      Ampersand(_) | Bar(_) | Caret(_) | Tilde(_)
      | LessThanLessThan(_) | GreaterThanGreaterThan(_)
      | GreaterThanGreaterThanGreaterThan(_) => true
      // Other operators
      Exclamation(_) | Question(_) | Colon(_) | Arrow(_) | Comma(_) => true
      // Opening brackets/parens
      OpenParen(_) | OpenBracket(_) | OpenBrace(_) => true
      // Semicolon (statement boundary)
      Semicolon(_) => true
      // Keywords that precede expressions
      KeywordReturn(_) | KeywordThrow(_) | KeywordCase(_) | KeywordIn(_)
      | KeywordTypeOf(_) | KeywordDelete(_) | KeywordNew(_) | KeywordAwait(_)
      | KeywordYield(_) => true
      _ => false
    }
  }
}
