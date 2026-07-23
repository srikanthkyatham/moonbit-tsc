// Scanner JSX Handling
// JSX tags, text, identifiers, and expressions

///|
/// Check if character can start a JSX tag name
fn is_jsx_tag_start(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch == '_' || ch == '$'
}

///|
/// Scan JSX text content (between tags)
fn scan_jsx_text_v2(
  code : StringView,
  state : ScanState,
  file_path : String,
) -> (Token, StringView) {
  let start_line = state.line
  let start_col = state.col
  let start_offset = state.offset
  let text = StringBuilder::new()
  let rest = for cur = code {
    match cur {
    [] as remaining => break remaining
    ['<' | '{', ..] as remaining => break remaining // End of text
    ['\n', .. rest] => {
      text.write_char('\n')
      state.line += 1
      state.col = 1
      state.offset += 1
      continue rest
    }
    [ch, .. rest] => {
      text.write_char(ch)
      state.col += 1
      state.offset += 1
      continue rest
    }
  }
  }
  let loc = SourceLocation::new(
    file_path,
    Position::new(start_line, start_col, start_offset),
    Position::new(state.line, state.col, state.offset),
  )
  (JsxText(text.to_string(), loc), rest)
}

///|
/// Scan JSX identifier (tag name or attribute name, may contain -)
fn scan_jsx_identifier(
  code : StringView,
  state : ScanState,
  file_path : String,
) -> (Token, StringView) {
  let start_line = state.line
  let start_col = state.col
  let start_offset = state.offset
  let ident = StringBuilder::new()
  let rest = for cur = code {
    match cur {
    ['a'..='z' | 'A'..='Z' | '0'..='9' | '_' | '$' | '-' as ch, .. rest] => {
      ident.write_char(ch)
      state.col += 1
      state.offset += 1
      continue rest
    }
    remaining => break remaining
  }
  }
  let loc = SourceLocation::new(
    file_path,
    Position::new(start_line, start_col, start_offset),
    Position::new(state.line, state.col, state.offset),
  )
  (Identifier(ident.to_string(), loc), rest)
}
