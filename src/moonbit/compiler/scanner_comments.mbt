// Comment and Trivia Scanning Functions
// Extracted from scanner.mbt to improve code organization
//
// This module contains all comment and whitespace handling:
// - skip_trivia: Skip whitespace and comments
// - skip_single_line_comment: Skip // comments
// - skip_multi_line_comment: Skip /* */ comments
// - is_jsdoc_comment_start: Check for /** comments
// - scan_jsdoc_comment: Scan JSDoc comments
// - scan_hashbang: Scan #!/usr/bin/env node
// - is_comment_directive_start: Check for @ts-* directives
// - is_ts_directive: Check for @ts- pattern
// - scan_comment_directive: Scan comment directives

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
  let mut scanner = advance(next) // Skip #!
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
          Some('/') =>
            // Triple-slash, check if it's a reference directive
            if scanner.position + 5 < scanner.length {
              // Look for "/ <" pattern after ///
              match scanner.source.get(scanner.position + 3) {
                Some(' ') | Some('<') => return true
                _ => ()
              }
            }
          Some(' ') | Some('@') =>
            // Check for @ts- directive
            return is_ts_directive(scanner, scanner.position + 2)
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
  match
    (
      scanner.source.get(p),
      scanner.source.get(p + 1),
      scanner.source.get(p + 2),
      scanner.source.get(p + 3),
    ) {
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
