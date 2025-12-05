// Scanner Regex Literal Handling
// Regex pattern scanning and regex vs division disambiguation

///|
/// Scan regex literal pattern (after opening /)
/// Returns (pattern, flags, remaining_code) or None if invalid
fn scan_regex_pattern_v2(
  code : StringView,
  state : ScanState,
) -> (String, String, StringView)? {
  let pattern = StringBuilder::new()
  let mut in_char_class = false

  // Scan pattern
  let rest = loop code {
    [] => return None // Unterminated regex
    ['\n' | '\r', ..] => return None // Newline in regex is invalid
    ['/', .. rest] if not(in_char_class) => {
      state.col += 1
      state.offset += 1
      rest // Found closing /
    }
    ['[', .. rest] => {
      in_char_class = true
      pattern.write_char('[')
      state.col += 1
      state.offset += 1
      continue rest
    }
    [']', .. rest] => {
      in_char_class = false
      pattern.write_char(']')
      state.col += 1
      state.offset += 1
      continue rest
    }
    ['\\', ch, .. rest] => {
      // Escape sequence - include both backslash and next char
      pattern.write_char('\\')
      pattern.write_char(ch)
      state.col += 2
      state.offset += 2
      continue rest
    }
    ['\\'] => return None // Backslash at end
    [ch, .. rest] => {
      pattern.write_char(ch)
      state.col += 1
      state.offset += 1
      continue rest
    }
  }

  // Scan flags (g, i, m, s, u, y, d, v)
  let flags = StringBuilder::new()
  let rest2 = loop rest {
    ['g' | 'i' | 'm' | 's' | 'u' | 'y' | 'd' | 'v' as ch, .. rest3] => {
      flags.write_char(ch)
      state.col += 1
      state.offset += 1
      continue rest3
    }
    remaining => remaining
  }
  Some((pattern.to_string(), flags.to_string(), rest2))
}

///|
/// Check if previous token allows regex literal (vs division)
fn allows_regex_v2(prev_token : Token?) -> Bool {
  match prev_token {
    None => true // Start of file
    Some(token) =>
      match token {
        // Assignment operators that can precede a regex
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
