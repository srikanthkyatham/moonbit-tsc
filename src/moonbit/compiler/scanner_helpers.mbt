// Scanner Helper Functions
// Utility functions extracted from scanner.mbt for better modularity

///|
/// Peek at current character
fn peek_char(scanner : Scanner) -> Char {
  if scanner.position < scanner.length {
    match scanner.source.get(scanner.position) {
      Some(ch) => Char::from_int(ch)
      None => '\u{0000}'
    }
  } else {
    '\u{0000}'
  }
}

///|
/// Advance scanner by one character
fn advance(scanner : Scanner) -> Scanner {
  if scanner.position < scanner.length {
    { ..scanner, position: scanner.position + 1, column: scanner.column + 1 }
  } else {
    scanner
  }
}

///|
/// Advance scanner to next line
fn advance_line(scanner : Scanner) -> Scanner {
  {
    ..scanner,
    position: scanner.position + 1,
    line: scanner.line + 1,
    column: 1,
  }
}

///|
/// Get current location
fn current_location(scanner : Scanner) -> SourceLocation {
  let pos = Position::new(scanner.line, scanner.column, scanner.position)
  SourceLocation::new(scanner.file_path, pos, pos)
}

///|
/// Create SourceLocation from start position to current position
fn make_location_from(
  scanner : Scanner,
  start_line : Int,
  start_column : Int,
  start_offset : Int,
) -> SourceLocation {
  let start_pos = Position::new(start_line, start_column, start_offset)
  let end_pos = Position::new(scanner.line, scanner.column, scanner.position)
  SourceLocation::new(scanner.file_path, start_pos, end_pos)
}

///|
/// Get hex digit value (0-15) or None
fn hex_digit_value(ch : Char) -> Int? {
  match ch {
    '0'..='9' => Some(ch.to_int() - '0'.to_int())
    'a'..='f' => Some(ch.to_int() - 'a'.to_int() + 10)
    'A'..='F' => Some(ch.to_int() - 'A'.to_int() + 10)
    _ => None
  }
}

///|
/// Convert code point to string (handles BMP and supplementary planes)
fn code_point_to_string(code_point : Int) -> String {
  if code_point <= 0xFFFF {
    match code_point.to_char() {
      Some(ch) => ch.to_string()
      None => "" // Invalid code point
    }
  } else {
    // Create surrogate pair for supplementary plane characters
    let adjusted = code_point - 0x10000
    let high_surrogate = 0xD800 + (adjusted >> 10)
    let low_surrogate = 0xDC00 + (adjusted & 0x3FF)
    let high_str = match high_surrogate.to_char() {
      Some(ch) => ch.to_string()
      None => ""
    }
    let low_str = match low_surrogate.to_char() {
      Some(ch) => ch.to_string()
      None => ""
    }
    high_str + low_str
  }
}

///|
/// Check if character can start an identifier (including Unicode letters)
fn is_identifier_start(ch : Char) -> Bool {
  match ch {
    'a'..='z' | 'A'..='Z' | '_' | '$' => true
    _ => {
      let code = ch.to_int()
      is_unicode_letter(code) || code == 0x200C || code == 0x200D
    }
  }
}

///|
/// Check if character can continue an identifier (including Unicode letters/digits)
fn is_identifier_part(ch : Char) -> Bool {
  match ch {
    'a'..='z' | 'A'..='Z' | '0'..='9' | '_' | '$' => true
    _ => {
      let code = ch.to_int()
      is_unicode_letter(code) ||
      is_unicode_digit(code) ||
      is_unicode_combining_mark(code) ||
      code == 0x200C || // ZWNJ
      code == 0x200D // ZWJ
    }
  }
}

///|
/// Check if code point is a Unicode letter (simplified version covering common ranges)
fn is_unicode_letter(code : Int) -> Bool {
  // Latin Extended
  (code >= 0x00C0 && code <= 0x00D6) ||
  (code >= 0x00D8 && code <= 0x00F6) ||
  (code >= 0x00F8 && code <= 0x00FF) ||
  // Latin Extended-A
  (code >= 0x0100 && code <= 0x017F) ||
  // Latin Extended-B
  (code >= 0x0180 && code <= 0x024F) ||
  // Greek
  (code >= 0x0370 && code <= 0x03FF) ||
  // Cyrillic
  (code >= 0x0400 && code <= 0x04FF) ||
  // Hebrew
  (code >= 0x0590 && code <= 0x05FF) ||
  // Arabic
  (code >= 0x0600 && code <= 0x06FF) ||
  // Devanagari
  (code >= 0x0900 && code <= 0x097F) ||
  // Thai
  (code >= 0x0E00 && code <= 0x0E7F) ||
  // CJK Unified Ideographs
  (code >= 0x4E00 && code <= 0x9FFF) ||
  // Hiragana
  (code >= 0x3040 && code <= 0x309F) ||
  // Katakana
  (code >= 0x30A0 && code <= 0x30FF) ||
  // Hangul Syllables
  (code >= 0xAC00 && code <= 0xD7AF) ||
  // Latin Extended Additional
  (code >= 0x1E00 && code <= 0x1EFF)
}

///|
/// Check if code point is a Unicode digit
fn is_unicode_digit(code : Int) -> Bool {
  // Arabic-Indic digits
  (code >= 0x0660 && code <= 0x0669) ||
  // Extended Arabic-Indic digits
  (code >= 0x06F0 && code <= 0x06F9) ||
  // Devanagari digits
  (code >= 0x0966 && code <= 0x096F) ||
  // Bengali digits
  (code >= 0x09E6 && code <= 0x09EF) ||
  // Thai digits
  (code >= 0x0E50 && code <= 0x0E59)
}

///|
/// Check if code point is a Unicode combining mark
fn is_unicode_combining_mark(code : Int) -> Bool {
  // Combining Diacritical Marks
  (code >= 0x0300 && code <= 0x036F) ||
  // Combining Diacritical Marks Extended
  (code >= 0x1AB0 && code <= 0x1AFF) ||
  // Combining Diacritical Marks Supplement
  (code >= 0x1DC0 && code <= 0x1DFF)
}
