// JSX Scanning Mode Support
// Extracted from scanner.mbt to improve code organization
//
// This module contains all JSX scanning logic:
// - ScannerMode: Scanner mode enum for context-sensitive scanning
// - ScannerState: Extended scanner state with mode tracking
// - scan_jsx_text: Scan JSX text content
// - scan_jsx_tag_open: Scan JSX opening tag start
// - scan_jsx_tag_token: Scan token in JSX mode
// - scan_jsx_expression_token: Scan token in JSX expression mode
// - scan_jsx_token: Main JSX-aware scanning function
// - scan_all_jsx: Scan all tokens with JSX support
// - enter_jsx_mode: Enter JSX mode from standard scanning

///|
/// Scanner mode for context-sensitive scanning
pub enum ScannerMode {
  Standard // Normal TypeScript/JavaScript
  JSX // Inside JSX element (after <tag)
  JSXExpression // Inside JSX expression {expr}
  JSXText // JSX text content (between tags)
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
  { scanner: Scanner::new(source, file_path), mode: Standard, mode_stack: [] }
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
      '<' | '{' => break // End of text content
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
  (JsxText(text, loc), { ..state, scanner, })
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
  let state = { ..state, scanner, }
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
        (SlashGreaterThan(loc), pop_mode({ ..state, scanner, }))
      } else {
        let loc = SourceLocation::new(
          scanner.file_path,
          Position::new(start_line, start_col, start_pos),
          Position::new(scanner.line, scanner.column, scanner.position),
        )
        (Slash(loc), { ..state, scanner, })
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
      (JsxExpressionStart(loc), push_mode({ ..state, scanner, }, JSXExpression))
    }
    '=' => {
      let scanner = advance(scanner)
      let loc = SourceLocation::new(
        scanner.file_path,
        Position::new(start_line, start_col, start_pos),
        Position::new(scanner.line, scanner.column, scanner.position),
      )
      (Equals(loc), { ..state, scanner, })
    }
    '"' | '\'' => {
      // Scan string attribute value
      let (token, scanner) = scan_string(
        scanner, start_pos, start_line, start_col,
      )
      (token, { ..state, scanner, })
    }
    _ =>
      // Scan identifier (tag name or attribute name)
      if is_identifier_start(ch) {
        let (token, scanner) = scan_identifier_or_keyword(
          scanner, start_pos, start_line, start_col,
        )
        (token, { ..state, scanner, })
      } else {
        let scanner = advance(scanner)
        let text = scanner.source.substring(
          start=start_pos,
          end=scanner.position,
        )
        let loc = SourceLocation::new(
          scanner.file_path,
          Position::new(start_line, start_col, start_pos),
          Position::new(scanner.line, scanner.column, scanner.position),
        )
        (Unknown(text, loc), { ..state, scanner, })
      }
  }
}

///|
/// Scan token in JSX expression mode (inside {})
fn scan_jsx_expression_token(state : ScannerState) -> (Token, ScannerState) {
  let scanner = skip_trivia(state.scanner)
  let state = { ..state, scanner, }
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
    return (JsxExpressionEnd(loc), pop_mode({ ..state, scanner, }))
  }

  // Use standard token scanning
  let (token, scanner) = scan_token(scanner)
  (token, { ..state, scanner, })
}

///|
/// Main JSX-aware scanning function
pub fn scan_jsx_token(state : ScannerState) -> (Token, ScannerState) {
  match state.mode {
    Standard => {
      // In standard mode, check for JSX start (<)
      let scanner = skip_trivia(state.scanner)
      let state = { ..state, scanner, }
      if scanner.position < scanner.length {
        let ch = peek_char(scanner)
        if ch == '<' {
          // Looks like JSX, scan as JSX tag open
          return scan_jsx_tag_open(state)
        }
      }

      // Otherwise use regular scanning
      let (token, scanner) = scan_token(state.scanner)
      (token, { ..state, scanner, })
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
          (
            JsxExpressionStart(loc),
            push_mode({ ..state, scanner, }, JSXExpression),
          )
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
