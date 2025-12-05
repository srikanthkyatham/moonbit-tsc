// Scanner Comments and Whitespace Handling
// Line comments, block comments, JSDoc, and comment directives

///|
/// Skip whitespace and comments, returning remaining code
/// Also handles UTF-8 BOM (Byte Order Mark) which is \uFEFF
fn skip_whitespace_v2(code : StringView, state : ScanState) -> StringView {
  loop code {
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
    // UTF-8 BOM (Byte Order Mark) - \uFEFF (0xEF 0xBB 0xBF in UTF-8)
    // TypeScript treats BOM as whitespace
    ['\u{FEFF}', .. rest] => {
      // BOM is 3 bytes in UTF-8 but 1 character
      state.offset += 3
      continue rest
    }
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
    remaining => remaining
  }
}

///|
/// Skip single-line comment and return remaining code
fn skip_line_comment(code : StringView, state : ScanState) -> StringView {
  loop code {
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
    remaining => remaining // End of input or after newline
  }
}

///|
/// Skip block comment and return remaining code
fn skip_block_comment(code : StringView, state : ScanState) -> StringView {
  loop code {
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
    remaining => remaining // End of input (unterminated comment)
  }
}

///|
/// Check if code starts with JSDoc comment (/** but not /**/)
fn is_jsdoc_start_v2(code : StringView) -> Bool {
  match code {
    [.. "/**", ch, ..] if ch != '/' => true
    _ => false
  }
}

///|
/// Check if code starts with a comment directive (// @ts-* or /// <reference)
fn is_comment_directive_start_v2(code : StringView) -> Bool {
  match code {
    // Triple-slash reference directive: /// <reference or /// <amd-
    [.. "///", ' ', '<', ..] => true
    [.. "///<", ..] => true
    // @ts-* directives: // @ts-ignore, // @ts-expect-error, etc.
    [.. "// @ts-", ..] => true
    [.. "//@ts-", ..] => true
    _ => false
  }
}

///|
/// Scan JSDoc comment /** ... */ and return token with content
fn scan_jsdoc_comment_v2(
  code : StringView,
  state : ScanState,
  file_path : String,
) -> (Token, StringView) {
  let start_line = state.line
  let start_col = state.col
  let start_offset = state.offset
  let content = StringBuilder::new()

  // Skip "/**"
  state.col += 3
  state.offset += 3
  fn make_loc() -> SourceLocation {
    SourceLocation::new(
      file_path,
      Position::new(start_line, start_col, start_offset),
      Position::new(state.line, state.col, state.offset),
    )
  }

  // Skip the opening /** and scan content
  let rest = loop code {
    // Skip opening /**
    [.. "/**", .. rest] => continue rest
    // End of JSDoc
    [.. "*/", .. rest] => {
      state.col += 2
      state.offset += 2
      rest
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
    [] as remaining => remaining // Unterminated
  }
  (JSDocComment(content.to_string(), make_loc()), rest)
}

///|
/// Scan comment directive (// @ts-* or /// <reference) and return token
fn scan_comment_directive_v2(
  code : StringView,
  state : ScanState,
  file_path : String,
) -> (Token, StringView) {
  let start_line = state.line
  let start_col = state.col
  let start_offset = state.offset
  fn make_loc() -> SourceLocation {
    SourceLocation::new(
      file_path,
      Position::new(start_line, start_col, start_offset),
      Position::new(state.line, state.col, state.offset),
    )
  }

  // Check for triple-slash directive first
  match code {
    [.. "///", .. rest] => {
      state.col += 3
      state.offset += 3
      // Scan rest of line as content
      let content = StringBuilder::new()
      let rest2 = loop rest {
        ['\n', ..] as remaining => remaining
        [ch, .. rest3] => {
          content.write_char(ch)
          state.col += 1
          state.offset += 1
          continue rest3
        }
        [] as remaining => remaining
      }
      return (
        CommentDirective(TripleSlashRef, content.to_string(), make_loc()),
        rest2,
      )
    }
    _ => ()
  }

  // Handle // @ts-* directives
  let (directive_kind, rest) = loop code {
    [.. "// @ts-ignore", .. rest] => {
      state.col += 13
      state.offset += 13
      (TsIgnore, rest)
    }
    [.. "//@ts-ignore", .. rest] => {
      state.col += 12
      state.offset += 12
      (TsIgnore, rest)
    }
    [.. "// @ts-expect-error", .. rest] => {
      state.col += 19
      state.offset += 19
      (TsExpectError, rest)
    }
    [.. "//@ts-expect-error", .. rest] => {
      state.col += 18
      state.offset += 18
      (TsExpectError, rest)
    }
    [.. "// @ts-nocheck", .. rest] => {
      state.col += 14
      state.offset += 14
      (TsNocheck, rest)
    }
    [.. "//@ts-nocheck", .. rest] => {
      state.col += 13
      state.offset += 13
      (TsNocheck, rest)
    }
    [.. "// @ts-check", .. rest] => {
      state.col += 12
      state.offset += 12
      (TsCheck, rest)
    }
    [.. "//@ts-check", .. rest] => {
      state.col += 11
      state.offset += 11
      (TsCheck, rest)
    }
    _ => {
      // Default fallback - skip // and treat as unknown directive
      state.col += 2
      state.offset += 2
      match code {
        [.. "//", .. rest] => (TsIgnore, rest)
        _ => (TsIgnore, code)
      }
    }
  }

  // Scan rest of line as argument
  let arg = StringBuilder::new()
  let rest2 = loop rest {
    ['\n', ..] as remaining => remaining
    [ch, .. rest3] => {
      arg.write_char(ch)
      state.col += 1
      state.offset += 1
      continue rest3
    }
    [] as remaining => remaining
  }
  (CommentDirective(directive_kind, arg.to_string(), make_loc()), rest2)
}

///|
/// Scan hashbang at start of file (#!/usr/bin/env node)
/// Returns (Some(token), rest) if hashbang found, (None, code) otherwise
fn scan_hashbang_v2(
  code : StringView,
  state : ScanState,
  file_path : String,
) -> (Token?, StringView) {
  // Hashbang only valid at position 0
  if state.offset != 0 {
    return (None, code)
  }
  match code {
    [.. "#!", .. rest] => {
      let start_line = state.line
      let start_col = state.col
      let start_offset = state.offset
      let content = StringBuilder::new()
      content.write_string("#!")
      state.col += 2
      state.offset += 2

      // Scan to end of line
      let rest2 = loop rest {
        ['\n', .. rest3] => {
          // Don't include newline in content, but advance past it
          state.line += 1
          state.col = 1
          state.offset += 1
          rest3
        }
        [ch, .. rest3] => {
          content.write_char(ch)
          state.col += 1
          state.offset += 1
          continue rest3
        }
        [] as remaining => remaining
      }
      let loc = SourceLocation::new(
        file_path,
        Position::new(start_line, start_col, start_offset),
        Position::new(state.line, state.col, state.offset),
      )
      (Some(Hashbang(content.to_string(), loc)), rest2)
    }
    _ => (None, code)
  }
}

///|
/// Skip whitespace and regular comments, but NOT JSDoc or directives
/// Returns (code_after_skip, Option<special_comment_token>)
/// Also handles UTF-8 BOM (Byte Order Mark) which is \uFEFF
fn skip_whitespace_with_special_comments_v2(
  code : StringView,
  state : ScanState,
  file_path : String,
) -> (StringView, Token?) {
  let input = code
  loop input {
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
    // UTF-8 BOM (Byte Order Mark) - \uFEFF (0xEF 0xBB 0xBF in UTF-8)
    // TypeScript treats BOM as whitespace
    ['\u{FEFF}', .. rest] => {
      // BOM is 3 bytes in UTF-8 but 1 character
      state.offset += 3
      continue rest
    }
    // Check for JSDoc comment first (/** but not /**/)
    [.. "/**", ch, ..] as current if ch != '/' => {
      let (token, rest) = scan_jsdoc_comment_v2(current, state, file_path)
      (rest, Some(token))
    }
    // Check for comment directive - triple slash
    [.. "///", ' ', '<', ..] as current => {
      let (token, rest) = scan_comment_directive_v2(current, state, file_path)
      (rest, Some(token))
    }
    [.. "///<", ..] as current => {
      let (token, rest) = scan_comment_directive_v2(current, state, file_path)
      (rest, Some(token))
    }
    // Check for comment directive - ts directives
    [.. "// @ts-", ..] as current => {
      let (token, rest) = scan_comment_directive_v2(current, state, file_path)
      (rest, Some(token))
    }
    [.. "//@ts-", ..] as current => {
      let (token, rest) = scan_comment_directive_v2(current, state, file_path)
      (rest, Some(token))
    }
    // Regular single-line comment
    [.. "//", .. rest] => {
      state.col += 2
      state.offset += 2
      let rest2 = skip_line_comment(rest, state)
      continue rest2
    }
    // Regular block comment
    [.. "/*", .. rest] => {
      state.col += 2
      state.offset += 2
      let rest2 = skip_block_comment(rest, state)
      continue rest2
    }
    remaining => (remaining, None)
  }
}
