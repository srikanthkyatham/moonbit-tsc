// Regex Literal Scanning Functions
// Extracted from scanner.mbt to improve code organization
//
// This module contains all regex literal scanning logic:
// - scan_regex: Scan a regex literal /pattern/flags
// - allows_regex: Check if previous token allows regex literal

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
      '\n' | '\r' =>
        // Invalid - newline in regex
        return None
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
    None => true // Start of file
    Some(token) =>
      match token {
        // Operators that can precede a regex
        Equals(_)
        | PlusEquals(_)
        | MinusEquals(_)
        | StarEquals(_)
        | SlashEquals(_)
        | PercentEquals(_)
        | AmpersandEquals(_)
        | BarEquals(_)
        | CaretEquals(_)
        | StarStarEquals(_)
        | LessThanLessThanEquals(_)
        | GreaterThanGreaterThanEquals(_)
        | GreaterThanGreaterThanGreaterThanEquals(_)
        | AmpersandAmpersandEquals(_)
        | BarBarEquals(_)
        | QuestionQuestionEquals(_) => true
        // Comparison/logical operators
        EqualsEquals(_)
        | ExclamationEquals(_)
        | EqualsEqualsEquals(_)
        | ExclamationEqualsEquals(_)
        | LessThan(_)
        | GreaterThan(_)
        | LessThanEquals(_)
        | GreaterThanEquals(_)
        | AmpersandAmpersand(_)
        | BarBar(_)
        | QuestionQuestion(_) => true
        // Arithmetic operators (but not + or - which could be unary)
        Star(_) | Slash(_) | Percent(_) | StarStar(_) => true
        // Bitwise operators
        Ampersand(_)
        | Bar(_)
        | Caret(_)
        | Tilde(_)
        | LessThanLessThan(_)
        | GreaterThanGreaterThan(_)
        | GreaterThanGreaterThanGreaterThan(_) => true
        // Other operators
        Exclamation(_) | Question(_) | Colon(_) | Arrow(_) | Comma(_) => true
        // Opening brackets/parens
        OpenParen(_) | OpenBracket(_) | OpenBrace(_) => true
        // Semicolon (statement boundary)
        Semicolon(_) => true
        // Keywords that precede expressions
        KeywordReturn(_)
        | KeywordThrow(_)
        | KeywordCase(_)
        | KeywordIn(_)
        | KeywordTypeOf(_)
        | KeywordDelete(_)
        | KeywordNew(_)
        | KeywordAwait(_)
        | KeywordYield(_) => true
        _ => false
      }
  }
}
