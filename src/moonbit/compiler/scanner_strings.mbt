// Scanner String and Template Literal Handling
// Double-quoted, single-quoted strings and template literals

///|
/// Scan double-quoted string with full escape support
fn scan_double_string(
  code : StringView,
  state : ScanState,
  content : StringBuilder,
) -> StringView {
  loop code {
    ['"', .. rest] => {
      state.col += 1
      state.offset += 1
      rest
    }
    [.. "\\n", .. rest] => {
      content.write_char('\n')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\r", .. rest] => {
      content.write_char('\r')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\t", .. rest] => {
      content.write_char('\t')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\b", .. rest] => {
      content.write_char('\u{0008}')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\f", .. rest] => {
      content.write_char('\u{000C}')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\v", .. rest] => {
      content.write_char('\u{000B}')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\0", .. rest] => {
      content.write_char('\u{0000}')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\\\", .. rest] => {
      content.write_char('\\')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\\"", .. rest] => {
      content.write_char('"')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\'", .. rest] => {
      content.write_char('\'')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\u", .. rest] => {
      // Unicode escape: \uXXXX or \u{XXXXX}
      match parse_unicode_escape_v2(rest) {
        Some((str, chars_consumed)) => {
          content.write_string(str)
          state.col += 2 + chars_consumed
          state.offset += 2 + chars_consumed
          continue try! rest[chars_consumed:]
        }
        None => {
          // Invalid escape - keep literal
          content.write_string("\\u")
          state.col += 2
          state.offset += 2
          continue rest
        }
      }
    }
    [.. "\\x", .. rest] => {
      // Hex escape: \xXX
      match parse_hex_escape_v2(rest) {
        Some((str, chars_consumed)) => {
          content.write_string(str)
          state.col += 2 + chars_consumed
          state.offset += 2 + chars_consumed
          continue try! rest[chars_consumed:]
        }
        None => {
          // Invalid escape - keep literal
          content.write_string("\\x")
          state.col += 2
          state.offset += 2
          continue rest
        }
      }
    }
    ['\n', .. remaining] => remaining // Unterminated at newline
    ['\\', '\n', .. rest] => {
      // Line continuation - skip the newline
      state.line += 1
      state.col = 1
      state.offset += 2
      continue rest
    }
    ['\\', '\r', '\n', .. rest] => {
      // Line continuation - skip CR LF
      state.line += 1
      state.col = 1
      state.offset += 3
      continue rest
    }
    ['\\', '\r', .. rest] => {
      // Line continuation - skip CR
      state.line += 1
      state.col = 1
      state.offset += 2
      continue rest
    }
    ['\\', ch, .. rest] => {
      // Unknown escape - keep literal character
      content.write_char(ch)
      state.col += 2
      state.offset += 2
      continue rest
    }
    [ch, .. rest] => {
      content.write_char(ch)
      state.col += 1
      state.offset += 1
      continue rest
    }
    remaining => remaining // End of input (unterminated string)
  }
}

///|
/// Scan single-quoted string with full escape support
fn scan_single_string(
  code : StringView,
  state : ScanState,
  content : StringBuilder,
) -> StringView {
  loop code {
    ['\'', .. rest] => {
      state.col += 1
      state.offset += 1
      rest
    }
    [.. "\\n", .. rest] => {
      content.write_char('\n')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\r", .. rest] => {
      content.write_char('\r')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\t", .. rest] => {
      content.write_char('\t')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\b", .. rest] => {
      content.write_char('\u{0008}')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\f", .. rest] => {
      content.write_char('\u{000C}')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\v", .. rest] => {
      content.write_char('\u{000B}')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\0", .. rest] => {
      content.write_char('\u{0000}')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\\\", .. rest] => {
      content.write_char('\\')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\'", .. rest] => {
      content.write_char('\'')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\\"", .. rest] => {
      content.write_char('"')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\u", .. rest] => {
      // Unicode escape: \uXXXX or \u{XXXXX}
      match parse_unicode_escape_v2(rest) {
        Some((str, chars_consumed)) => {
          content.write_string(str)
          state.col += 2 + chars_consumed
          state.offset += 2 + chars_consumed
          continue try! rest[chars_consumed:]
        }
        None => {
          // Invalid escape - keep literal
          content.write_string("\\u")
          state.col += 2
          state.offset += 2
          continue rest
        }
      }
    }
    [.. "\\x", .. rest] => {
      // Hex escape: \xXX
      match parse_hex_escape_v2(rest) {
        Some((str, chars_consumed)) => {
          content.write_string(str)
          state.col += 2 + chars_consumed
          state.offset += 2 + chars_consumed
          continue try! rest[chars_consumed:]
        }
        None => {
          // Invalid escape - keep literal
          content.write_string("\\x")
          state.col += 2
          state.offset += 2
          continue rest
        }
      }
    }
    ['\n', .. remaining] => remaining // Unterminated at newline
    ['\\', '\n', .. rest] => {
      // Line continuation - skip the newline
      state.line += 1
      state.col = 1
      state.offset += 2
      continue rest
    }
    ['\\', '\r', '\n', .. rest] => {
      // Line continuation - skip CR LF
      state.line += 1
      state.col = 1
      state.offset += 3
      continue rest
    }
    ['\\', '\r', .. rest] => {
      // Line continuation - skip CR
      state.line += 1
      state.col = 1
      state.offset += 2
      continue rest
    }
    ['\\', ch, .. rest] => {
      // Unknown escape - keep literal character
      content.write_char(ch)
      state.col += 2
      state.offset += 2
      continue rest
    }
    [ch, .. rest] => {
      content.write_char(ch)
      state.col += 1
      state.offset += 1
      continue rest
    }
    remaining => remaining // End of input (unterminated string)
  }
}

///|
/// Scan template literal with full escape support
fn scan_template_literal_v2(
  code : StringView,
  state : ScanState,
  content : StringBuilder,
) -> TemplateScanResultV2 {
  loop code {
    [] as remaining => Unterminated(remaining) // EOF without closing backtick
    ['`', .. rest] => {
      state.col += 1
      state.offset += 1
      Complete(rest)
    }
    [.. "${", .. rest] => {
      state.col += 2
      state.offset += 2
      Head(rest)
    }
    [.. "\\`", .. rest] => {
      content.write_char('`')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\$", .. rest] => {
      content.write_char('$')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\n", .. rest] => {
      content.write_char('\n')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\r", .. rest] => {
      content.write_char('\r')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\t", .. rest] => {
      content.write_char('\t')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\b", .. rest] => {
      content.write_char('\u{0008}')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\f", .. rest] => {
      content.write_char('\u{000C}')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\v", .. rest] => {
      content.write_char('\u{000B}')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\0", .. rest] => {
      content.write_char('\u{0000}')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\\\", .. rest] => {
      content.write_char('\\')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\u", .. rest] => {
      // Unicode escape: \uXXXX or \u{XXXXX}
      match parse_unicode_escape_v2(rest) {
        Some((str, chars_consumed)) => {
          content.write_string(str)
          state.col += 2 + chars_consumed
          state.offset += 2 + chars_consumed
          continue try! rest[chars_consumed:]
        }
        None => {
          // Invalid escape - keep literal
          content.write_string("\\u")
          state.col += 2
          state.offset += 2
          continue rest
        }
      }
    }
    [.. "\\x", .. rest] => {
      // Hex escape: \xXX
      match parse_hex_escape_v2(rest) {
        Some((str, chars_consumed)) => {
          content.write_string(str)
          state.col += 2 + chars_consumed
          state.offset += 2 + chars_consumed
          continue try! rest[chars_consumed:]
        }
        None => {
          // Invalid escape - keep literal
          content.write_string("\\x")
          state.col += 2
          state.offset += 2
          continue rest
        }
      }
    }
    ['\\', ch, .. rest] => {
      // Unknown escape - keep literal character
      content.write_char(ch)
      state.col += 2
      state.offset += 2
      continue rest
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
  }
}

///|
/// Scan template continuation (after closing } of interpolation)
/// Returns Complete for TemplateTail or Middle for TemplateMiddle
fn scan_template_continuation_v2(
  code : StringView,
  state : ScanState,
  content : StringBuilder,
) -> TemplateScanResultV2 {
  loop code {
    [] as remaining => Unterminated(remaining) // EOF without closing backtick
    ['`', .. rest] => {
      state.col += 1
      state.offset += 1
      Complete(rest) // TemplateTail
    }
    [.. "${", .. rest] => {
      state.col += 2
      state.offset += 2
      Middle(rest) // TemplateMiddle
    }
    [.. "\\`", .. rest] => {
      content.write_char('`')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\$", .. rest] => {
      content.write_char('$')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\n", .. rest] => {
      content.write_char('\n')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\r", .. rest] => {
      content.write_char('\r')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\t", .. rest] => {
      content.write_char('\t')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\b", .. rest] => {
      content.write_char('\u{0008}')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\f", .. rest] => {
      content.write_char('\u{000C}')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\v", .. rest] => {
      content.write_char('\u{000B}')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\0", .. rest] => {
      content.write_char('\u{0000}')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\\\", .. rest] => {
      content.write_char('\\')
      state.col += 2
      state.offset += 2
      continue rest
    }
    [.. "\\u", .. rest] => {
      // Unicode escape: \uXXXX or \u{XXXXX}
      match parse_unicode_escape_v2(rest) {
        Some((str, chars_consumed)) => {
          content.write_string(str)
          state.col += 2 + chars_consumed
          state.offset += 2 + chars_consumed
          continue try! rest[chars_consumed:]
        }
        None => {
          // Invalid escape - keep literal
          content.write_string("\\u")
          state.col += 2
          state.offset += 2
          continue rest
        }
      }
    }
    [.. "\\x", .. rest] => {
      // Hex escape: \xXX
      match parse_hex_escape_v2(rest) {
        Some((str, chars_consumed)) => {
          content.write_string(str)
          state.col += 2 + chars_consumed
          state.offset += 2 + chars_consumed
          continue try! rest[chars_consumed:]
        }
        None => {
          // Invalid escape - keep literal
          content.write_string("\\x")
          state.col += 2
          state.offset += 2
          continue rest
        }
      }
    }
    ['\\', ch, .. rest] => {
      // Unknown escape - keep literal character
      content.write_char(ch)
      state.col += 2
      state.offset += 2
      continue rest
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
  }
}
