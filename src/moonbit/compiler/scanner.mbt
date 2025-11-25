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

  // Check for hashbang at file start
  let (hashbang, scanner_after_hashbang) = scan_hashbang(current_scanner)
  match hashbang {
    Some(token) => {
      tokens.push(token)
      prev_token = Some(token)
      current_scanner = scanner_after_hashbang
    }
    None => ()
  }

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

  // Check for JSDoc comment
  if is_jsdoc_comment_start(scanner) {
    return scan_jsdoc_comment(scanner)
  }

  // Check for comment directive
  if is_comment_directive_start(scanner) {
    match scan_comment_directive(scanner) {
      (Some(token), scanner) => return (token, scanner)
      (None, _) => ()
    }
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

  // Check for JSDoc comment
  if is_jsdoc_comment_start(scanner) {
    return scan_jsdoc_comment(scanner)
  }

  // Check for comment directive
  if is_comment_directive_start(scanner) {
    match scan_comment_directive(scanner) {
      (Some(token), scanner) => return (token, scanner)
      (None, _) => ()
    }
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
        '.' => {
          let scanner = advance(scanner)
          (
            ExclamationDot(
              make_location(scanner, start_pos, start_line, start_col),
            ),
            scanner,
          )
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
    '#' => scan_private_identifier(scanner, start_pos, start_line, start_col)
    _ => {
      // Check if it's a Unicode identifier start
      if is_identifier_start(ch) {
        scan_identifier_or_keyword(scanner, start_pos, start_line, start_col)
      } else {
        let scanner = advance(scanner)
        let text = scanner.source.substring(start=start_pos, end=scanner.position)
        (
          Unknown(text, make_location(scanner, start_pos, start_line, start_col)),
          scanner,
        )
      }
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

  // Scan while identifier part (includes Unicode letters/digits)
  while scanner.position < scanner.length {
    let ch = peek_char(scanner)
    if is_identifier_part(ch) {
      scanner = advance(scanner)
    } else {
      break
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
/// Scan a number literal (all formats: decimal, hex, octal, binary, BigInt, separators)
fn scan_number(
  scanner : Scanner,
  start_pos : Int,
  start_line : Int,
  start_col : Int,
) -> (Token, Scanner) {
  let first_char = peek_char(scanner)

  // Check for special prefixes (0x, 0o, 0b)
  if first_char == '0' {
    let scanner_after_zero = advance(scanner)
    if scanner_after_zero.position < scanner_after_zero.length {
      let second_char = peek_char(scanner_after_zero)
      match second_char {
        'x' | 'X' => return scan_hex_number(scanner_after_zero, start_pos, start_line, start_col)
        'o' | 'O' => return scan_octal_number(scanner_after_zero, start_pos, start_line, start_col)
        'b' | 'B' => return scan_binary_number(scanner_after_zero, start_pos, start_line, start_col)
        _ => ()
      }
    }
  }

  // Decimal number
  scan_decimal_number(scanner, start_pos, start_line, start_col)
}

///|
/// Scan hexadecimal number (0xFF, 0xFFn)
fn scan_hex_number(
  scanner : Scanner,
  start_pos : Int,
  start_line : Int,
  start_col : Int,
) -> (Token, Scanner) {
  let mut scanner = advance(scanner) // Skip x/X
  let mut text = "0x"

  while scanner.position < scanner.length {
    let ch = peek_char(scanner)
    match ch {
      '0'..='9' | 'a'..='f' | 'A'..='F' => {
        text = text + Char::to_string(ch)
        scanner = advance(scanner)
      }
      '_' => {
        // Numeric separator - skip but don't include
        scanner = advance(scanner)
      }
      _ => break
    }
  }

  // Check for BigInt suffix
  let is_bigint = peek_char(scanner) == 'n'
  if is_bigint {
    text = text + "n"
    scanner = advance(scanner)
  }

  let loc = SourceLocation::new(
    scanner.file_path,
    Position::new(start_line, start_col, start_pos),
    Position::new(scanner.line, scanner.column, scanner.position),
  )

  if is_bigint {
    (BigIntLiteral(text, loc), scanner)
  } else {
    (NumericLiteral(text, loc), scanner)
  }
}

///|
/// Scan octal number (0o77, 0o77n)
fn scan_octal_number(
  scanner : Scanner,
  start_pos : Int,
  start_line : Int,
  start_col : Int,
) -> (Token, Scanner) {
  let mut scanner = advance(scanner) // Skip o/O
  let mut text = "0o"

  while scanner.position < scanner.length {
    let ch = peek_char(scanner)
    match ch {
      '0'..='7' => {
        text = text + Char::to_string(ch)
        scanner = advance(scanner)
      }
      '_' => {
        scanner = advance(scanner)
      }
      _ => break
    }
  }

  // Check for BigInt suffix
  let is_bigint = peek_char(scanner) == 'n'
  if is_bigint {
    text = text + "n"
    scanner = advance(scanner)
  }

  let loc = SourceLocation::new(
    scanner.file_path,
    Position::new(start_line, start_col, start_pos),
    Position::new(scanner.line, scanner.column, scanner.position),
  )

  if is_bigint {
    (BigIntLiteral(text, loc), scanner)
  } else {
    (NumericLiteral(text, loc), scanner)
  }
}

///|
/// Scan binary number (0b1010, 0b1010n)
fn scan_binary_number(
  scanner : Scanner,
  start_pos : Int,
  start_line : Int,
  start_col : Int,
) -> (Token, Scanner) {
  let mut scanner = advance(scanner) // Skip b/B
  let mut text = "0b"

  while scanner.position < scanner.length {
    let ch = peek_char(scanner)
    match ch {
      '0' | '1' => {
        text = text + Char::to_string(ch)
        scanner = advance(scanner)
      }
      '_' => {
        scanner = advance(scanner)
      }
      _ => break
    }
  }

  // Check for BigInt suffix
  let is_bigint = peek_char(scanner) == 'n'
  if is_bigint {
    text = text + "n"
    scanner = advance(scanner)
  }

  let loc = SourceLocation::new(
    scanner.file_path,
    Position::new(start_line, start_col, start_pos),
    Position::new(scanner.line, scanner.column, scanner.position),
  )

  if is_bigint {
    (BigIntLiteral(text, loc), scanner)
  } else {
    (NumericLiteral(text, loc), scanner)
  }
}

///|
/// Scan decimal number with full support (separators, floats, exponents, BigInt)
fn scan_decimal_number(
  scanner : Scanner,
  start_pos : Int,
  start_line : Int,
  start_col : Int,
) -> (Token, Scanner) {
  let mut scanner = scanner
  let mut text = ""
  let mut has_dot = false
  let mut has_exponent = false

  // Integer part
  while scanner.position < scanner.length {
    let ch = peek_char(scanner)
    match ch {
      '0'..='9' => {
        text = text + Char::to_string(ch)
        scanner = advance(scanner)
      }
      '_' => {
        // Numeric separator - skip
        scanner = advance(scanner)
      }
      _ => break
    }
  }

  // Decimal part
  if peek_char(scanner) == '.' {
    // Check it's not .. (range operator in some contexts)
    let next_scanner = advance(scanner)
    if peek_char(next_scanner) != '.' {
      has_dot = true
      text = text + "."
      scanner = next_scanner

      while scanner.position < scanner.length {
        let ch = peek_char(scanner)
        match ch {
          '0'..='9' => {
            text = text + Char::to_string(ch)
            scanner = advance(scanner)
          }
          '_' => {
            scanner = advance(scanner)
          }
          _ => break
        }
      }
    }
  }

  // Exponent part
  let ch = peek_char(scanner)
  if ch == 'e' || ch == 'E' {
    has_exponent = true
    text = text + Char::to_string(ch)
    scanner = advance(scanner)

    // Optional sign
    let sign = peek_char(scanner)
    if sign == '+' || sign == '-' {
      text = text + Char::to_string(sign)
      scanner = advance(scanner)
    }

    // Exponent digits
    while scanner.position < scanner.length {
      let ch = peek_char(scanner)
      match ch {
        '0'..='9' => {
          text = text + Char::to_string(ch)
          scanner = advance(scanner)
        }
        '_' => {
          scanner = advance(scanner)
        }
        _ => break
      }
    }
  }

  // BigInt suffix (only valid without decimal or exponent)
  let is_bigint = not(has_dot) && not(has_exponent) && peek_char(scanner) == 'n'
  if is_bigint {
    text = text + "n"
    scanner = advance(scanner)
  }

  let loc = SourceLocation::new(
    scanner.file_path,
    Position::new(start_line, start_col, start_pos),
    Position::new(scanner.line, scanner.column, scanner.position),
  )

  if is_bigint {
    (BigIntLiteral(text, loc), scanner)
  } else {
    (NumericLiteral(text, loc), scanner)
  }
}

///|
/// Scan private identifier (#fieldName)
fn scan_private_identifier(
  scanner : Scanner,
  start_pos : Int,
  start_line : Int,
  start_col : Int,
) -> (Token, Scanner) {
  let mut scanner = advance(scanner) // Skip #

  // Check if followed by valid identifier start
  let ch = peek_char(scanner)
  match ch {
    'a'..='z' | 'A'..='Z' | '_' | '$' => ()
    _ => {
      // Not a valid private identifier - return Unknown("#")
      let loc = SourceLocation::new(
        scanner.file_path,
        Position::new(start_line, start_col, start_pos),
        Position::new(scanner.line, scanner.column, scanner.position),
      )
      return (Unknown("#", loc), scanner)
    }
  }

  // Scan identifier part
  while scanner.position < scanner.length {
    let ch = peek_char(scanner)
    match ch {
      'a'..='z' | 'A'..='Z' | '0'..='9' | '_' | '$' => scanner = advance(scanner)
      _ => break
    }
  }

  let text = scanner.source.substring(start=start_pos, end=scanner.position)
  let loc = SourceLocation::new(
    scanner.file_path,
    Position::new(start_line, start_col, start_pos),
    Position::new(scanner.line, scanner.column, scanner.position),
  )
  (PrivateIdentifier(text, loc), scanner)
}

///|
/// Scan a string literal with full escape sequence support
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
        match escaped {
          'n' => {
            text = text + "\n"
            scanner = advance(scanner)
          }
          'r' => {
            text = text + "\r"
            scanner = advance(scanner)
          }
          't' => {
            text = text + "\t"
            scanner = advance(scanner)
          }
          'b' => {
            text = text + "\u{0008}"
            scanner = advance(scanner)
          }
          'f' => {
            text = text + "\u{000C}"
            scanner = advance(scanner)
          }
          'v' => {
            text = text + "\u{000B}"
            scanner = advance(scanner)
          }
          '0' => {
            text = text + "\u{0000}"
            scanner = advance(scanner)
          }
          '\\' => {
            text = text + "\\"
            scanner = advance(scanner)
          }
          '\'' => {
            text = text + "'"
            scanner = advance(scanner)
          }
          '"' => {
            text = text + "\""
            scanner = advance(scanner)
          }
          'u' => {
            match parse_unicode_escape(scanner) {
              Some((code_point, new_scanner)) => {
                text = text + code_point_to_string(code_point)
                scanner = new_scanner
              }
              None => {
                text = text + "\\u"
                scanner = advance(scanner)
              }
            }
          }
          'x' => {
            match parse_hex_escape(scanner) {
              Some((value, new_scanner)) => {
                text = text + code_point_to_string(value)
                scanner = new_scanner
              }
              None => {
                text = text + "\\x"
                scanner = advance(scanner)
              }
            }
          }
          '\n' => {
            // Line continuation - skip the newline
            scanner = advance_line(scanner)
          }
          '\r' => {
            // Line continuation - skip CR and possibly LF
            scanner = advance(scanner)
            if peek_char(scanner) == '\n' {
              scanner = advance_line(scanner)
            }
          }
          _ => {
            // Unknown escape - keep literal character
            text = text + Char::to_string(escaped)
            scanner = advance(scanner)
          }
        }
      }
    } else if ch == '\n' || ch == '\r' {
      // Unterminated string - break here
      break
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
          'n' => {
            text = text + "\n"
            scanner = advance(scanner)
          }
          'r' => {
            text = text + "\r"
            scanner = advance(scanner)
          }
          't' => {
            text = text + "\t"
            scanner = advance(scanner)
          }
          'b' => {
            text = text + "\u{0008}"
            scanner = advance(scanner)
          }
          'f' => {
            text = text + "\u{000C}"
            scanner = advance(scanner)
          }
          'v' => {
            text = text + "\u{000B}"
            scanner = advance(scanner)
          }
          '0' => {
            text = text + "\u{0000}"
            scanner = advance(scanner)
          }
          '\\' => {
            text = text + "\\"
            scanner = advance(scanner)
          }
          '`' => {
            text = text + "`"
            scanner = advance(scanner)
          }
          '$' => {
            text = text + "$"
            scanner = advance(scanner)
          }
          'u' => {
            match parse_unicode_escape(scanner) {
              Some((code_point, new_scanner)) => {
                text = text + code_point_to_string(code_point)
                scanner = new_scanner
              }
              None => {
                text = text + "\\u"
                scanner = advance(scanner)
              }
            }
          }
          'x' => {
            match parse_hex_escape(scanner) {
              Some((value, new_scanner)) => {
                text = text + code_point_to_string(value)
                scanner = new_scanner
              }
              None => {
                text = text + "\\x"
                scanner = advance(scanner)
              }
            }
          }
          _ => {
            text = text + "\\"
            text = text + Char::to_string(escaped)
            scanner = advance(scanner)
          }
        }
        continue
      }
    }
    if ch == '\n' {
      text = text + Char::to_string(ch)
      scanner = advance_line(scanner)
    } else {
      text = text + Char::to_string(ch)
      scanner = advance(scanner)
    }
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
          'n' => {
            text = text + "\n"
            scanner = advance(scanner)
          }
          'r' => {
            text = text + "\r"
            scanner = advance(scanner)
          }
          't' => {
            text = text + "\t"
            scanner = advance(scanner)
          }
          'b' => {
            text = text + "\u{0008}"
            scanner = advance(scanner)
          }
          'f' => {
            text = text + "\u{000C}"
            scanner = advance(scanner)
          }
          'v' => {
            text = text + "\u{000B}"
            scanner = advance(scanner)
          }
          '0' => {
            text = text + "\u{0000}"
            scanner = advance(scanner)
          }
          '\\' => {
            text = text + "\\"
            scanner = advance(scanner)
          }
          '`' => {
            text = text + "`"
            scanner = advance(scanner)
          }
          '$' => {
            text = text + "$"
            scanner = advance(scanner)
          }
          'u' => {
            match parse_unicode_escape(scanner) {
              Some((code_point, new_scanner)) => {
                text = text + code_point_to_string(code_point)
                scanner = new_scanner
              }
              None => {
                text = text + "\\u"
                scanner = advance(scanner)
              }
            }
          }
          'x' => {
            match parse_hex_escape(scanner) {
              Some((value, new_scanner)) => {
                text = text + code_point_to_string(value)
                scanner = new_scanner
              }
              None => {
                text = text + "\\x"
                scanner = advance(scanner)
              }
            }
          }
          _ => {
            text = text + "\\"
            text = text + Char::to_string(escaped)
            scanner = advance(scanner)
          }
        }
        continue
      }
    }
    if ch == '\n' {
      text = text + Char::to_string(ch)
      scanner = advance_line(scanner)
    } else {
      text = text + Char::to_string(ch)
      scanner = advance(scanner)
    }
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
            Some('/') => {
              // Check if it's a comment directive - don't skip those
              if is_comment_directive_start(scanner) {
                break
              }
              // Single-line comment
              scanner = skip_single_line_comment(scanner)
            }
            Some('*') => {
              // Check if it's a JSDoc comment - don't skip those
              if is_jsdoc_comment_start(scanner) {
                break
              }
              // Regular multi-line comment
              scanner = skip_multi_line_comment(scanner)
            }
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
/// Check if at JSDoc comment start (/** but not /**/)
fn is_jsdoc_comment_start(scanner : Scanner) -> Bool {
  if scanner.position + 3 < scanner.length {
    let c0 = scanner.source.get(scanner.position)
    let c1 = scanner.source.get(scanner.position + 1)
    let c2 = scanner.source.get(scanner.position + 2)
    let c3 = scanner.source.get(scanner.position + 3)
    // Check for /** followed by non-/ (to exclude /**/)
    c0 == Some('/'.to_int()) &&
    c1 == Some('*'.to_int()) &&
    c2 == Some('*'.to_int()) &&
    c3 != Some('/'.to_int())
  } else {
    false
  }
}

///|
/// Scan JSDoc comment and return token
fn scan_jsdoc_comment(scanner : Scanner) -> (Token, Scanner) {
  let start_line = scanner.line
  let start_col = scanner.column
  let start_pos = scanner.position
  let mut scanner = scanner
  let mut content = ""

  // Skip "/**"
  scanner = advance(scanner)
  scanner = advance(scanner)
  scanner = advance(scanner)

  // Collect content until "*/"
  while scanner.position < scanner.length {
    let ch = peek_char(scanner)
    if ch == '*' && scanner.position + 1 < scanner.length {
      let next = scanner.source.get(scanner.position + 1)
      if next == Some('/'.to_int()) {
        scanner = advance(scanner) // Skip '*'
        scanner = advance(scanner) // Skip '/'
        break
      }
    }
    content = content + Char::to_string(ch)
    if ch == '\n' {
      scanner = advance_line(scanner)
    } else {
      scanner = advance(scanner)
    }
  }

  let loc = SourceLocation::new(
    scanner.file_path,
    Position::new(start_line, start_col, start_pos),
    Position::new(scanner.line, scanner.column, scanner.position),
  )
  (JSDocComment(content, loc), scanner)
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
/// Get hex digit value (0-15) or None
fn hex_digit_value(ch : Char) -> Int? {
  match ch {
    '0'..='9' => Some(ch.to_int() - '0'.to_int())
    'a'..='f' => Some(ch.to_int() - 'a'.to_int() + 10)
    'A'..='F' => Some(ch.to_int() - 'A'.to_int() + 10)
    _ => None
  }
}

///|
/// Convert code point to string (handles BMP and supplementary planes)
fn code_point_to_string(code_point : Int) -> String {
  if code_point <= 0xFFFF {
    match code_point.to_char() {
      Some(ch) => ch.to_string()
      None => "" // Invalid code point
    }
  } else {
    // Create surrogate pair for supplementary plane characters
    let adjusted = code_point - 0x10000
    let high_surrogate = 0xD800 + (adjusted >> 10)
    let low_surrogate = 0xDC00 + (adjusted & 0x3FF)
    let high_str = match high_surrogate.to_char() {
      Some(ch) => ch.to_string()
      None => ""
    }
    let low_str = match low_surrogate.to_char() {
      Some(ch) => ch.to_string()
      None => ""
    }
    high_str + low_str
  }
}

///|
/// Parse Unicode escape sequence \uXXXX or \u{XXXXX}
/// Scanner should be positioned at 'u' (after the backslash)
fn parse_unicode_escape(scanner : Scanner) -> (Int, Scanner)? {
  let mut scanner = advance(scanner) // Skip 'u'

  if peek_char(scanner) == '{' {
    // Variable-length: \u{XXXXX}
    scanner = advance(scanner) // Skip {
    let mut code_point = 0
    let mut digit_count = 0

    while scanner.position < scanner.length {
      let ch = peek_char(scanner)
      if ch == '}' {
        scanner = advance(scanner)
        if digit_count == 0 {
          return None // Empty \u{}
        }
        if code_point > 0x10FFFF {
          return None // Invalid code point
        }
        return Some((code_point, scanner))
      }

      match hex_digit_value(ch) {
        Some(value) => {
          code_point = code_point * 16 + value
          digit_count = digit_count + 1
          scanner = advance(scanner)
        }
        None => return None // Invalid hex digit
      }
    }
    None // No closing }
  } else {
    // Fixed 4-digit: \uXXXX
    let mut code_point = 0
    for i = 0; i < 4; i = i + 1 {
      if scanner.position >= scanner.length {
        return None
      }
      let ch = peek_char(scanner)
      match hex_digit_value(ch) {
        Some(value) => {
          code_point = code_point * 16 + value
          scanner = advance(scanner)
        }
        None => return None
      }
    }
    Some((code_point, scanner))
  }
}

///|
/// Parse hex escape sequence \xXX
/// Scanner should be positioned at 'x' (after the backslash)
fn parse_hex_escape(scanner : Scanner) -> (Int, Scanner)? {
  let mut scanner = advance(scanner) // Skip 'x'

  // Read exactly 2 hex digits
  let mut value = 0
  for i = 0; i < 2; i = i + 1 {
    if scanner.position >= scanner.length {
      return None
    }
    let ch = peek_char(scanner)
    match hex_digit_value(ch) {
      Some(digit) => {
        value = value * 16 + digit
        scanner = advance(scanner)
      }
      None => return None
    }
  }
  Some((value, scanner))
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

///|
/// Check if character can start an identifier (including Unicode letters)
fn is_identifier_start(ch : Char) -> Bool {
  match ch {
    'a'..='z' | 'A'..='Z' | '_' | '$' => true
    _ => {
      let code = ch.to_int()
      is_unicode_letter(code) || code == 0x200C || code == 0x200D
    }
  }
}

///|
/// Check if character can continue an identifier (including Unicode letters/digits)
fn is_identifier_part(ch : Char) -> Bool {
  match ch {
    'a'..='z' | 'A'..='Z' | '0'..='9' | '_' | '$' => true
    _ => {
      let code = ch.to_int()
      is_unicode_letter(code) ||
      is_unicode_digit(code) ||
      is_unicode_combining_mark(code) ||
      code == 0x200C ||  // ZWNJ
      code == 0x200D     // ZWJ
    }
  }
}

///|
/// Check if code point is a Unicode letter (simplified version covering common ranges)
fn is_unicode_letter(code : Int) -> Bool {
  // Latin Extended
  (code >= 0x00C0 && code <= 0x00D6) ||
  (code >= 0x00D8 && code <= 0x00F6) ||
  (code >= 0x00F8 && code <= 0x00FF) ||
  // Latin Extended-A
  (code >= 0x0100 && code <= 0x017F) ||
  // Latin Extended-B
  (code >= 0x0180 && code <= 0x024F) ||
  // Greek
  (code >= 0x0370 && code <= 0x03FF) ||
  // Cyrillic
  (code >= 0x0400 && code <= 0x04FF) ||
  // Hebrew
  (code >= 0x0590 && code <= 0x05FF) ||
  // Arabic
  (code >= 0x0600 && code <= 0x06FF) ||
  // Devanagari
  (code >= 0x0900 && code <= 0x097F) ||
  // Thai
  (code >= 0x0E00 && code <= 0x0E7F) ||
  // CJK Unified Ideographs
  (code >= 0x4E00 && code <= 0x9FFF) ||
  // Hiragana
  (code >= 0x3040 && code <= 0x309F) ||
  // Katakana
  (code >= 0x30A0 && code <= 0x30FF) ||
  // Hangul Syllables
  (code >= 0xAC00 && code <= 0xD7AF) ||
  // Latin Extended Additional
  (code >= 0x1E00 && code <= 0x1EFF)
}

///|
/// Check if code point is a Unicode digit
fn is_unicode_digit(code : Int) -> Bool {
  // Arabic-Indic digits
  (code >= 0x0660 && code <= 0x0669) ||
  // Extended Arabic-Indic digits
  (code >= 0x06F0 && code <= 0x06F9) ||
  // Devanagari digits
  (code >= 0x0966 && code <= 0x096F) ||
  // Bengali digits
  (code >= 0x09E6 && code <= 0x09EF) ||
  // Thai digits
  (code >= 0x0E50 && code <= 0x0E59)
}

///|
/// Check if code point is a Unicode combining mark
fn is_unicode_combining_mark(code : Int) -> Bool {
  // Combining Diacritical Marks
  (code >= 0x0300 && code <= 0x036F) ||
  // Combining Diacritical Marks Extended
  (code >= 0x1AB0 && code <= 0x1AFF) ||
  // Combining Diacritical Marks Supplement
  (code >= 0x1DC0 && code <= 0x1DFF)
}

///|
/// Scan hashbang at start of file (#!/usr/bin/env node)
pub fn scan_hashbang(scanner : Scanner) -> (Token?, Scanner) {
  // Hashbang only valid at position 0
  if scanner.position != 0 {
    return (None, scanner)
  }

  // Check for #!
  if peek_char(scanner) != '#' {
    return (None, scanner)
  }

  let next = advance(scanner)
  if peek_char(next) != '!' {
    return (None, scanner)
  }

  // It's a hashbang - scan to end of line
  let start_pos = scanner.position
  let start_line = scanner.line
  let start_col = scanner.column
  let mut scanner = advance(next)  // Skip #!
  let mut text = "#!"

  while scanner.position < scanner.length {
    let ch = peek_char(scanner)
    if ch == '\n' {
      break
    }
    text = text + Char::to_string(ch)
    scanner = advance(scanner)
  }

  let loc = SourceLocation::new(
    scanner.file_path,
    Position::new(start_line, start_col, start_pos),
    Position::new(scanner.line, scanner.column, scanner.position),
  )

  // Skip the newline if present
  if scanner.position < scanner.length && peek_char(scanner) == '\n' {
    scanner = advance_line(scanner)
  }

  (Some(Hashbang(text, loc)), scanner)
}

///|
/// Check if current position is a comment directive (// @ts-... or /// <reference...)
fn is_comment_directive_start(scanner : Scanner) -> Bool {
  // Must start with //
  if peek_char(scanner) != '/' {
    return false
  }
  if scanner.position + 1 >= scanner.length {
    return false
  }
  match scanner.source.get(scanner.position + 1) {
    Some('/') => {
      // Check for /// <reference (triple-slash directive)
      if scanner.position + 2 < scanner.length {
        match scanner.source.get(scanner.position + 2) {
          Some('/') => {
            // Triple-slash, check if it's a reference directive
            if scanner.position + 5 < scanner.length {
              // Look for "/ <" pattern after ///
              match scanner.source.get(scanner.position + 3) {
                Some(' ') | Some('<') => return true
                _ => ()
              }
            }
          }
          Some(' ') | Some('@') => {
            // Check for @ts- directive
            return is_ts_directive(scanner, scanner.position + 2)
          }
          _ => ()
        }
      }
      false
    }
    _ => false
  }
}

///|
/// Check if position contains a @ts- directive
fn is_ts_directive(scanner : Scanner, pos : Int) -> Bool {
  // Skip whitespace
  let mut p = pos
  while p < scanner.length {
    match scanner.source.get(p) {
      Some(' ') | Some('\t') => p = p + 1
      _ => break
    }
  }

  // Check for @ts-
  if p + 4 >= scanner.length {
    return false
  }
  match (scanner.source.get(p), scanner.source.get(p + 1), scanner.source.get(p + 2), scanner.source.get(p + 3)) {
    (Some('@'), Some('t'), Some('s'), Some('-')) => true
    _ => false
  }
}

///|
/// Scan a comment directive (// @ts-... or /// <reference...)
pub fn scan_comment_directive(scanner : Scanner) -> (Token?, Scanner) {
  if not(is_comment_directive_start(scanner)) {
    return (None, scanner)
  }

  let start_pos = scanner.position
  let start_line = scanner.line
  let start_col = scanner.column

  // Skip //
  let mut scanner = advance(scanner)
  scanner = advance(scanner)

  // Check for triple-slash directive
  if peek_char(scanner) == '/' {
    scanner = advance(scanner)
    // Scan to end of line
    let mut text = ""
    while scanner.position < scanner.length {
      let ch = peek_char(scanner)
      if ch == '\n' {
        break
      }
      text = text + Char::to_string(ch)
      scanner = advance(scanner)
    }

    let loc = SourceLocation::new(
      scanner.file_path,
      Position::new(start_line, start_col, start_pos),
      Position::new(scanner.line, scanner.column, scanner.position),
    )

    return (Some(CommentDirective(TripleSlashRef, text, loc)), scanner)
  }

  // Skip whitespace
  while scanner.position < scanner.length {
    let ch = peek_char(scanner)
    if ch == ' ' || ch == '\t' {
      scanner = advance(scanner)
    } else {
      break
    }
  }

  // Parse @ts-XXX
  if peek_char(scanner) != '@' {
    return (None, scanner)
  }
  scanner = advance(scanner) // Skip @

  // Read the directive name
  let mut directive = ""
  while scanner.position < scanner.length {
    let ch = peek_char(scanner)
    match ch {
      'a'..='z' | 'A'..='Z' | '-' | '_' => {
        directive = directive + Char::to_string(ch)
        scanner = advance(scanner)
      }
      _ => break
    }
  }

  // Scan rest of the line as the argument
  let mut arg = ""
  while scanner.position < scanner.length {
    let ch = peek_char(scanner)
    if ch == '\n' {
      break
    }
    arg = arg + Char::to_string(ch)
    scanner = advance(scanner)
  }

  let loc = SourceLocation::new(
    scanner.file_path,
    Position::new(start_line, start_col, start_pos),
    Position::new(scanner.line, scanner.column, scanner.position),
  )

  // Determine directive kind
  let kind : CommentDirectiveKind = match directive {
    "ts-ignore" => TsIgnore
    "ts-expect-error" => TsExpectError
    "ts-nocheck" => TsNocheck
    "ts-check" => TsCheck
    _ => TsIgnore // Default for unknown directives
  }

  (Some(CommentDirective(kind, arg, loc)), scanner)
}

// ============================================================================
// JSX Scanning Mode Support
// ============================================================================

///|
/// Scanner mode for context-sensitive scanning
pub enum ScannerMode {
  Standard      // Normal TypeScript/JavaScript
  JSX           // Inside JSX element (after <tag)
  JSXExpression // Inside JSX expression {expr}
  JSXText       // JSX text content (between tags)
} derive(Show, Eq)

///|
/// Extended scanner state with mode tracking
pub struct ScannerState {
  scanner : Scanner
  mode : ScannerMode
  mode_stack : Array[ScannerMode]
} derive(Show)

///|
/// Create a new scanner state
pub fn ScannerState::new(source : String, file_path : String) -> ScannerState {
  {
    scanner: Scanner::new(source, file_path),
    mode: Standard,
    mode_stack: [],
  }
}

///|
/// Push a new scanning mode onto the stack
fn push_mode(state : ScannerState, new_mode : ScannerMode) -> ScannerState {
  let new_stack = state.mode_stack.copy()
  new_stack.push(state.mode)
  { ..state, mode: new_mode, mode_stack: new_stack }
}

///|
/// Pop to previous scanning mode
fn pop_mode(state : ScannerState) -> ScannerState {
  if state.mode_stack.is_empty() {
    { ..state, mode: Standard }
  } else {
    let new_stack = state.mode_stack.copy()
    match new_stack.pop() {
      Some(prev_mode) => { ..state, mode: prev_mode, mode_stack: new_stack }
      None => { ..state, mode: Standard }
    }
  }
}

///|
/// Scan JSX text content (between tags)
fn scan_jsx_text(state : ScannerState) -> (Token, ScannerState) {
  let scanner = state.scanner
  let start_pos = scanner.position
  let start_line = scanner.line
  let start_col = scanner.column
  let mut scanner = scanner
  let mut text = ""

  while scanner.position < scanner.length {
    let ch = peek_char(scanner)
    match ch {
      '<' | '{' => break  // End of text content
      _ => {
        text = text + Char::to_string(ch)
        if ch == '\n' {
          scanner = advance_line(scanner)
        } else {
          scanner = advance(scanner)
        }
      }
    }
  }

  let loc = SourceLocation::new(
    scanner.file_path,
    Position::new(start_line, start_col, start_pos),
    Position::new(scanner.line, scanner.column, scanner.position),
  )

  (JsxText(text, loc), { ..state, scanner })
}

///|
/// Scan JSX opening tag start (<)
fn scan_jsx_tag_open(state : ScannerState) -> (Token, ScannerState) {
  let scanner = state.scanner
  let start_pos = scanner.position
  let start_line = scanner.line
  let start_col = scanner.column
  let scanner = advance(scanner) // Skip <

  // Check for </
  if peek_char(scanner) == '/' {
    let scanner = advance(scanner)
    let loc = SourceLocation::new(
      scanner.file_path,
      Position::new(start_line, start_col, start_pos),
      Position::new(scanner.line, scanner.column, scanner.position),
    )
    return (LessThanSlash(loc), { ..state, scanner, mode: JSX })
  }

  let loc = SourceLocation::new(
    scanner.file_path,
    Position::new(start_line, start_col, start_pos),
    Position::new(scanner.line, scanner.column, scanner.position),
  )
  (JsxTagOpen(loc), { ..state, scanner, mode: JSX })
}

///|
/// Scan token in JSX mode (inside tag, scanning attributes)
fn scan_jsx_tag_token(state : ScannerState) -> (Token, ScannerState) {
  let scanner = skip_trivia(state.scanner)
  let state = { ..state, scanner }

  if scanner.position >= scanner.length {
    let loc = current_location(scanner)
    return (EOF(loc), state)
  }

  let start_pos = scanner.position
  let start_line = scanner.line
  let start_col = scanner.column
  let ch = peek_char(scanner)

  match ch {
    '>' => {
      let scanner = advance(scanner)
      let loc = SourceLocation::new(
        scanner.file_path,
        Position::new(start_line, start_col, start_pos),
        Position::new(scanner.line, scanner.column, scanner.position),
      )
      // After >, switch to JSXText mode
      (JsxTagClose(loc), { ..state, scanner, mode: JSXText })
    }
    '/' => {
      let scanner = advance(scanner)
      if peek_char(scanner) == '>' {
        let scanner = advance(scanner)
        let loc = SourceLocation::new(
          scanner.file_path,
          Position::new(start_line, start_col, start_pos),
          Position::new(scanner.line, scanner.column, scanner.position),
        )
        // Self-closing tag, pop mode
        (SlashGreaterThan(loc), pop_mode({ ..state, scanner }))
      } else {
        let loc = SourceLocation::new(
          scanner.file_path,
          Position::new(start_line, start_col, start_pos),
          Position::new(scanner.line, scanner.column, scanner.position),
        )
        (Slash(loc), { ..state, scanner })
      }
    }
    '{' => {
      let scanner = advance(scanner)
      let loc = SourceLocation::new(
        scanner.file_path,
        Position::new(start_line, start_col, start_pos),
        Position::new(scanner.line, scanner.column, scanner.position),
      )
      // Push JSXExpression mode
      (JsxExpressionStart(loc), push_mode({ ..state, scanner }, JSXExpression))
    }
    '=' => {
      let scanner = advance(scanner)
      let loc = SourceLocation::new(
        scanner.file_path,
        Position::new(start_line, start_col, start_pos),
        Position::new(scanner.line, scanner.column, scanner.position),
      )
      (Equals(loc), { ..state, scanner })
    }
    '"' | '\'' => {
      // Scan string attribute value
      let (token, scanner) = scan_string(scanner, start_pos, start_line, start_col)
      (token, { ..state, scanner })
    }
    _ => {
      // Scan identifier (tag name or attribute name)
      if is_identifier_start(ch) {
        let (token, scanner) = scan_identifier_or_keyword(scanner, start_pos, start_line, start_col)
        (token, { ..state, scanner })
      } else {
        let scanner = advance(scanner)
        let text = scanner.source.substring(start=start_pos, end=scanner.position)
        let loc = SourceLocation::new(
          scanner.file_path,
          Position::new(start_line, start_col, start_pos),
          Position::new(scanner.line, scanner.column, scanner.position),
        )
        (Unknown(text, loc), { ..state, scanner })
      }
    }
  }
}

///|
/// Scan token in JSX expression mode (inside {})
fn scan_jsx_expression_token(state : ScannerState) -> (Token, ScannerState) {
  let scanner = skip_trivia(state.scanner)
  let state = { ..state, scanner }

  if scanner.position >= scanner.length {
    let loc = current_location(scanner)
    return (EOF(loc), state)
  }

  let ch = peek_char(scanner)
  if ch == '}' {
    let start_pos = scanner.position
    let start_line = scanner.line
    let start_col = scanner.column
    let scanner = advance(scanner)
    let loc = SourceLocation::new(
      scanner.file_path,
      Position::new(start_line, start_col, start_pos),
      Position::new(scanner.line, scanner.column, scanner.position),
    )
    // Pop back to previous mode
    return (JsxExpressionEnd(loc), pop_mode({ ..state, scanner }))
  }

  // Use standard token scanning
  let (token, scanner) = scan_token(scanner)
  (token, { ..state, scanner })
}

///|
/// Main JSX-aware scanning function
pub fn scan_jsx_token(state : ScannerState) -> (Token, ScannerState) {
  match state.mode {
    Standard => {
      // In standard mode, check for JSX start (<)
      let scanner = skip_trivia(state.scanner)
      let state = { ..state, scanner }

      if scanner.position < scanner.length {
        let ch = peek_char(scanner)
        if ch == '<' {
          // Looks like JSX, scan as JSX tag open
          return scan_jsx_tag_open(state)
        }
      }

      // Otherwise use regular scanning
      let (token, scanner) = scan_token(state.scanner)
      (token, { ..state, scanner })
    }
    JSXText => {
      let scanner = state.scanner
      if scanner.position >= scanner.length {
        let loc = current_location(scanner)
        return (EOF(loc), state)
      }

      let ch = peek_char(scanner)
      match ch {
        '<' => scan_jsx_tag_open(state)
        '{' => {
          let start_pos = scanner.position
          let start_line = scanner.line
          let start_col = scanner.column
          let scanner = advance(scanner)
          let loc = SourceLocation::new(
            scanner.file_path,
            Position::new(start_line, start_col, start_pos),
            Position::new(scanner.line, scanner.column, scanner.position),
          )
          (JsxExpressionStart(loc), push_mode({ ..state, scanner }, JSXExpression))
        }
        _ => scan_jsx_text(state)
      }
    }
    JSX => scan_jsx_tag_token(state)
    JSXExpression => scan_jsx_expression_token(state)
  }
}

///|
/// Scan all tokens with JSX support
pub fn scan_all_jsx(source : String, file_path : String) -> Array[Token] {
  let tokens : Array[Token] = []
  let mut state = ScannerState::new(source, file_path)
  let mut should_continue = true

  // Check for hashbang at file start
  let (hashbang, scanner_after_hashbang) = scan_hashbang(state.scanner)
  match hashbang {
    Some(token) => {
      tokens.push(token)
      state = { ..state, scanner: scanner_after_hashbang }
    }
    None => ()
  }

  while should_continue {
    let (token, new_state) = scan_jsx_token(state)
    tokens.push(token)
    match token {
      EOF(_) => should_continue = false
      _ => state = new_state
    }
  }

  tokens
}

///|
/// Enter JSX mode from standard scanning (called when < is detected in expression context)
pub fn enter_jsx_mode(state : ScannerState) -> ScannerState {
  push_mode(state, JSXText)
}

// ============================================================================
// JSDoc Tag Parsing
// ============================================================================

///|
/// Parsed JSDoc tag types (scanner-level, distinct from AST types)
pub enum ParsedJSDocTag {
  Param(ParsedJSDocParam)       // @param {type} name description
  Returns(ParsedJSDocType)      // @returns {type} description
  Type(ParsedJSDocType)         // @type {type}
  TypeDef(ParsedJSDocTypeDef)   // @typedef {type} name
  Template(Array[String])       // @template T, U
  Deprecated(String?)           // @deprecated [reason]
  Example(String)               // @example
  See(String)                   // @see reference
  Author(String)                // @author name
  Since(String)                 // @since version
  Throws(ParsedJSDocType)       // @throws {type} description
  Private                       // @private
  Public                        // @public
  Protected                     // @protected
  Readonly                      // @readonly
  Override                      // @override
  Abstract                      // @abstract
  Other(String, String)         // Unknown tag
} derive(Show, Eq)

///|
/// Parsed JSDoc param tag
pub struct ParsedJSDocParam {
  name : String
  type_annotation : String?
  description : String
  is_optional : Bool
} derive(Show, Eq)

///|
/// Parsed JSDoc type tag (for @returns, @type, @throws)
pub struct ParsedJSDocType {
  type_annotation : String?
  description : String
} derive(Show, Eq)

///|
/// Parsed JSDoc typedef tag
pub struct ParsedJSDocTypeDef {
  name : String
  type_annotation : String?
  description : String
} derive(Show, Eq)

///|
/// Parsed JSDoc comment
pub struct ParsedJSDoc {
  description : String
  tags : Array[ParsedJSDocTag]
} derive(Show, Eq)

///|
/// Parse a JSDoc comment content into structured form
pub fn parse_jsdoc(content : String) -> ParsedJSDoc {
  let lines = split_lines(content)
  let mut description = ""
  let tags : Array[ParsedJSDocTag] = []
  let mut in_description = true
  let mut current_tag_lines : Array[String] = []
  let mut current_tag_name = ""

  for line in lines {
    let trimmed = trim_jsdoc_line_scanner(line)

    // Check if line starts a new tag
    if trimmed.length() > 0 && starts_with_char(trimmed, '@') {
      // Process previous tag if any
      if current_tag_name.length() > 0 {
        let tag = parse_jsdoc_tag_scanner(current_tag_name, join_lines(current_tag_lines))
        tags.push(tag)
      }

      // Start new tag
      in_description = false
      let (tag_name, rest) = extract_tag_name_scanner(trimmed)
      current_tag_name = tag_name
      current_tag_lines = [rest]
    } else if in_description {
      if description.length() > 0 {
        description = description + "\n" + trimmed
      } else {
        description = trimmed
      }
    } else {
      // Continuation of current tag
      current_tag_lines.push(trimmed)
    }
  }

  // Process last tag if any
  if current_tag_name.length() > 0 {
    let tag = parse_jsdoc_tag_scanner(current_tag_name, join_lines(current_tag_lines))
    tags.push(tag)
  }

  { description: description.trim_space(), tags }
}

///|
/// Split content into lines
fn split_lines(content : String) -> Array[String] {
  let lines : Array[String] = []
  let mut current = ""

  for i = 0; i < content.length(); i = i + 1 {
    match content.get(i) {
      Some(code) => {
        let ch = code.unsafe_to_char()
        if ch == '\n' {
          lines.push(current)
          current = ""
        } else {
          current = current + Char::to_string(ch)
        }
      }
      None => ()
    }
  }
  if current.length() > 0 {
    lines.push(current)
  }
  lines
}

///|
/// Trim JSDoc line (remove leading *, whitespace)
fn trim_jsdoc_line_scanner(line : String) -> String {
  let mut start = 0

  // Skip leading whitespace
  while start < line.length() {
    match line.get(start) {
      Some(code) => {
        let ch = code.unsafe_to_char()
        if ch == ' ' || ch == '\t' {
          start = start + 1
        } else {
          break
        }
      }
      None => break
    }
  }

  // Skip leading *
  if start < line.length() {
    match line.get(start) {
      Some(code) => {
        if code.unsafe_to_char() == '*' {
          start = start + 1
          // Skip whitespace after *
          while start < line.length() {
            match line.get(start) {
              Some(code2) => {
                let ch = code2.unsafe_to_char()
                if ch == ' ' || ch == '\t' {
                  start = start + 1
                } else {
                  break
                }
              }
              None => break
            }
          }
        }
      }
      None => ()
    }
  }

  line.substring(start=start, end=line.length())
}

///|
/// Check if string starts with a character
fn starts_with_char(s : String, ch : Char) -> Bool {
  match s.get(0) {
    Some(code) => code.unsafe_to_char() == ch
    None => false
  }
}

///|
/// Extract tag name from line starting with @
fn extract_tag_name_scanner(line : String) -> (String, String) {
  let mut end = 1 // Start after @

  while end < line.length() {
    match line.get(end) {
      Some(code) => {
        let ch = code.unsafe_to_char()
        match ch {
          'a'..='z' | 'A'..='Z' | '0'..='9' | '-' | '_' => end = end + 1
          _ => break
        }
      }
      None => break
    }
  }

  let tag_name = line.substring(start=1, end=end) // Skip @
  let rest = if end < line.length() {
    line.substring(start=end, end=line.length()).trim_space()
  } else {
    ""
  }
  (tag_name, rest)
}

///|
/// Join lines with space
fn join_lines(lines : Array[String]) -> String {
  let mut result = ""
  for i = 0; i < lines.length(); i = i + 1 {
    if i > 0 {
      result = result + " "
    }
    result = result + lines[i]
  }
  result
}

///|
/// Parse a single JSDoc tag
fn parse_jsdoc_tag_scanner(tag_name : String, content : String) -> ParsedJSDocTag {
  match tag_name {
    "param" | "arg" | "argument" => parse_param_tag(content)
    "returns" | "return" => parse_type_tag_as_returns(content)
    "type" => parse_type_tag_as_type(content)
    "typedef" => parse_typedef_tag(content)
    "template" => parse_template_tag(content)
    "deprecated" => ParsedJSDocTag::Deprecated(if content.length() > 0 { Some(content) } else { None })
    "example" => ParsedJSDocTag::Example(content)
    "see" => ParsedJSDocTag::See(content)
    "author" => ParsedJSDocTag::Author(content)
    "since" | "version" => ParsedJSDocTag::Since(content)
    "throws" | "exception" => parse_type_tag_as_throws(content)
    "private" => ParsedJSDocTag::Private
    "public" => ParsedJSDocTag::Public
    "protected" => ParsedJSDocTag::Protected
    "readonly" => ParsedJSDocTag::Readonly
    "override" => ParsedJSDocTag::Override
    "abstract" | "virtual" => ParsedJSDocTag::Abstract
    _ => ParsedJSDocTag::Other(tag_name, content)
  }
}

///|
/// Parse @param tag
fn parse_param_tag(content : String) -> ParsedJSDocTag {
  let (type_annotation, rest) = extract_type_annotation(content)
  let (name, is_optional, description) = extract_param_name(rest)

  ParsedJSDocTag::Param({
    name,
    type_annotation,
    description,
    is_optional,
  })
}

///|
/// Parse @returns tag
fn parse_type_tag_as_returns(content : String) -> ParsedJSDocTag {
  let (type_annotation, description) = extract_type_annotation(content)
  ParsedJSDocTag::Returns({ type_annotation, description })
}

///|
/// Parse @type tag
fn parse_type_tag_as_type(content : String) -> ParsedJSDocTag {
  let (type_annotation, description) = extract_type_annotation(content)
  ParsedJSDocTag::Type({ type_annotation, description })
}

///|
/// Parse @throws tag
fn parse_type_tag_as_throws(content : String) -> ParsedJSDocTag {
  let (type_annotation, description) = extract_type_annotation(content)
  ParsedJSDocTag::Throws({ type_annotation, description })
}

///|
/// Parse @typedef tag
fn parse_typedef_tag(content : String) -> ParsedJSDocTag {
  let (type_annotation, rest) = extract_type_annotation(content)
  let (name, description) = extract_first_word(rest)

  ParsedJSDocTag::TypeDef({
    name,
    type_annotation,
    description,
  })
}

///|
/// Parse @template tag
fn parse_template_tag(content : String) -> ParsedJSDocTag {
  let params : Array[String] = []
  let mut current = ""

  for i = 0; i < content.length(); i = i + 1 {
    match content.get(i) {
      Some(code) => {
        let ch = code.unsafe_to_char()
        match ch {
          ',' | ' ' => {
            if current.length() > 0 {
              params.push(current.trim_space())
              current = ""
            }
          }
          _ => current = current + Char::to_string(ch)
        }
      }
      None => ()
    }
  }
  if current.length() > 0 {
    params.push(current.trim_space())
  }

  ParsedJSDocTag::Template(params)
}

///|
/// Extract type annotation from {type} prefix
fn extract_type_annotation(content : String) -> (String?, String) {
  let trimmed = content.trim_space()

  if not(starts_with_char(trimmed, '{')) {
    return (None, trimmed)
  }

  // Find matching }
  let mut depth = 0
  let mut end = 0

  for i = 0; i < trimmed.length(); i = i + 1 {
    match trimmed.get(i) {
      Some(code) => {
        let ch = code.unsafe_to_char()
        if ch == '{' {
          depth = depth + 1
        } else if ch == '}' {
          depth = depth - 1
          if depth == 0 {
            end = i
            break
          }
        }
      }
      None => ()
    }
  }

  if end == 0 {
    return (None, trimmed)
  }

  let type_str = trimmed.substring(start=1, end=end) // Skip { and }
  let rest = trimmed.substring(start=end + 1, end=trimmed.length()).trim_space()

  (Some(type_str), rest)
}

///|
/// Extract param name (handles [name] for optional)
fn extract_param_name(content : String) -> (String, Bool, String) {
  let trimmed = content.trim_space()

  // Check for [name] optional syntax
  if starts_with_char(trimmed, '[') {
    let mut end = 1
    while end < trimmed.length() {
      match trimmed.get(end) {
        Some(code) => {
          if code.unsafe_to_char() == ']' {
            break
          }
          end = end + 1
        }
        None => break
      }
    }

    let name_part = trimmed.substring(start=1, end=end)
    // Handle [name=default]
    let name = extract_before_equals(name_part)
    let description = trimmed.substring(start=end + 1, end=trimmed.length()).trim_space()

    return (name, true, description)
  }

  // Regular name
  let (name, description) = extract_first_word(trimmed)
  (name, false, description)
}

///|
/// Extract content before = (for optional params with defaults)
fn extract_before_equals(s : String) -> String {
  let mut end = 0
  while end < s.length() {
    match s.get(end) {
      Some(code) => {
        if code.unsafe_to_char() == '=' {
          break
        }
        end = end + 1
      }
      None => break
    }
  }
  s.substring(start=0, end=end).trim_space()
}

///|
/// Extract first word from string
fn extract_first_word(s : String) -> (String, String) {
  let trimmed = s.trim_space()
  let mut end = 0

  while end < trimmed.length() {
    match trimmed.get(end) {
      Some(code) => {
        let ch = code.unsafe_to_char()
        if ch == ' ' || ch == '\t' || ch == '\n' || ch == '-' {
          break
        }
        end = end + 1
      }
      None => break
    }
  }

  let word = trimmed.substring(start=0, end=end)
  let rest = trimmed.substring(start=end, end=trimmed.length()).trim_space()

  // Remove leading - from description
  let rest = if starts_with_char(rest, '-') {
    rest.substring(start=1, end=rest.length()).trim_space()
  } else {
    rest
  }

  (word, rest)
}

///|
/// Helper to trim whitespace from string
fn String::trim_space(self : String) -> String {
  let mut start = 0
  let mut end = self.length()

  // Find start
  while start < end {
    match self.get(start) {
      Some(code) => {
        let ch = code.unsafe_to_char()
        if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
          start = start + 1
        } else {
          break
        }
      }
      None => break
    }
  }

  // Find end
  while end > start {
    match self.get(end - 1) {
      Some(code) => {
        let ch = code.unsafe_to_char()
        if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
          end = end - 1
        } else {
          break
        }
      }
      None => break
    }
  }

  self.substring(start=start, end=end)
}
