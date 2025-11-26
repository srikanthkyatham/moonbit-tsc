// Scanner Escape Sequence Handling
// Unicode and hex escape parsing

///|
/// Convert hex character to its numeric value
fn hex_digit_value_v2(ch : Char) -> Int? {
  match ch {
    '0'..='9' => Some(ch.to_int() - '0'.to_int())
    'a'..='f' => Some(ch.to_int() - 'a'.to_int() + 10)
    'A'..='F' => Some(ch.to_int() - 'A'.to_int() + 10)
    _ => None
  }
}

///|
/// Convert code point to string
fn code_point_to_string_v2(code_point : Int) -> String {
  if code_point <= 0xFFFF {
    Char::from_int(code_point).to_string()
  } else {
    // Surrogate pair for code points > 0xFFFF
    let adjusted = code_point - 0x10000
    let high = 0xD800 + (adjusted >> 10)
    let low = 0xDC00 + (adjusted & 0x3FF)
    Char::from_int(high).to_string() + Char::from_int(low).to_string()
  }
}

///|
/// Parse Unicode escape sequence \uXXXX or \u{XXXXX}
/// Returns (parsed_string, chars_consumed) or None if invalid
fn parse_unicode_escape_v2(code : StringView) -> (String, Int)? {
  match code {
    ['{', .. rest] => {
      // Variable-length: \u{XXXXX}
      let mut i = 0
      let mut code_point = 0
      let mut digit_count = 0
      loop rest {
        ['}', ..] => {
          if digit_count == 0 || code_point > 0x10FFFF {
            return None
          }
          return Some((code_point_to_string_v2(code_point), i + 2)) // +2 for { and }
        }
        [ch, .. rest2] => {
          match hex_digit_value_v2(ch) {
            Some(value) => {
              code_point = code_point * 16 + value
              digit_count = digit_count + 1
              i = i + 1
              continue rest2
            }
            None => return None
          }
        }
        [] => return None
      }
    }
    _ => {
      // Fixed 4-digit: \uXXXX
      let mut code_point = 0
      let mut remaining = code
      for i = 0; i < 4; i = i + 1 {
        match remaining {
          [ch, .. rest] => {
            match hex_digit_value_v2(ch) {
              Some(value) => {
                code_point = code_point * 16 + value
                remaining = rest
              }
              None => return None
            }
          }
          [] => return None
        }
      }
      Some((code_point_to_string_v2(code_point), 4))
    }
  }
}

///|
/// Parse hex escape sequence \xXX
/// Returns (parsed_char, chars_consumed) or None if invalid
fn parse_hex_escape_v2(code : StringView) -> (String, Int)? {
  match code {
    [h1, h2, ..] => {
      match (hex_digit_value_v2(h1), hex_digit_value_v2(h2)) {
        (Some(v1), Some(v2)) => {
          let value = v1 * 16 + v2
          Some((Char::from_int(value).to_string(), 2))
        }
        _ => None
      }
    }
    _ => None
  }
}
