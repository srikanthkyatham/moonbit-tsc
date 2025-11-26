// Template Literal Scanning Functions
// Extracted from scanner.mbt to improve code organization
//
// This module contains all template literal scanning logic including:
// - scan_template: Main entry point for template literal scanning
// - scan_template_continuation: Continue scanning after an interpolation

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
      if next_scanner.position < next_scanner.length &&
        peek_char(next_scanner) == '{' {
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
      if next_scanner.position < next_scanner.length &&
        peek_char(next_scanner) == '{' {
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
