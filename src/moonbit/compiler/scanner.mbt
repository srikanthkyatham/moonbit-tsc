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
  let mut template_depth = 0 // Track nested template interpolations
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
      Some(CloseBrace(_)) if template_depth > 0 =>
        scan_template_continuation(current_scanner)
      _ => scan_token_with_context(current_scanner, prev_token)
    }
    tokens.push(token)
    // Track template depth
    match token {
      TemplateHead(_, _) | TemplateMiddle(_, _) =>
        template_depth = template_depth + 1
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
pub fn scan_token_with_context(
  scanner : Scanner,
  prev_token : Token?,
) -> (Token, Scanner) {
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
      return (
        SlashEquals(make_location(scanner, start_pos, start_line, start_col)),
        scanner,
      )
    }
    if next_ch == '>' {
      let scanner = advance(scanner_after_slash)
      return (
        SlashGreaterThan(
          make_location(scanner, start_pos, start_line, start_col),
        ),
        scanner,
      )
    }
    // Check if previous token allows regex
    if allows_regex(prev_token) {
      // Try to scan as regex
      match scan_regex(scanner_after_slash, start_pos, start_line, start_col) {
        Some(result) => return result
        None =>
          // Fall back to division
          return (
            Slash(
              make_location(
                scanner_after_slash, start_pos, start_line, start_col,
              ),
            ),
            scanner_after_slash,
          )
      }
    } else {
      return (
        // Division operator
        Slash(
          make_location(scanner_after_slash, start_pos, start_line, start_col),
        ),
        scanner_after_slash,
      )
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
                StarStarEquals(
                  make_location(scanner, start_pos, start_line, start_col),
                ),
                scanner,
              )
            }
            _ =>
              (
                StarStar(
                  make_location(scanner, start_pos, start_line, start_col),
                ),
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
                BarBarEquals(
                  make_location(scanner, start_pos, start_line, start_col),
                ),
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
    _ =>
      // Check if it's a Unicode identifier start
      if is_identifier_start(ch) {
        scan_identifier_or_keyword(scanner, start_pos, start_line, start_col)
      } else {
        let scanner = advance(scanner)
        let text = scanner.source.substring(
          start=start_pos,
          end=scanner.position,
        )
        (
          Unknown(
            text,
            make_location(scanner, start_pos, start_line, start_col),
          ),
          scanner,
        )
      }
  }
}








