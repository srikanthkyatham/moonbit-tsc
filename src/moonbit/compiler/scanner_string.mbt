// String Literal Scanning Functions
// Extracted from scanner.mbt to improve code organization
//
// This module contains all string literal scanning logic including:
// - scan_string: Main entry point for string scanning with full escape support
// - parse_unicode_escape: Parse \uXXXX and \u{XXXXX} sequences
// - parse_hex_escape: Parse \xXX sequences

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
          'u' =>
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
          'x' =>
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
          '\n' =>
            // Line continuation - skip the newline
            scanner = advance_line(scanner)
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
