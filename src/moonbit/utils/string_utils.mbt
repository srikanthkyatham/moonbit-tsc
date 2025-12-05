// String utility functions to replace deprecated APIs

///|
/// Safe substring helper that mimics the old substring behavior
/// Uses the new str[:] slicing syntax internally with error handling
pub fn substr(s : String, start? : Int = 0, end? : Int = -1) -> String {
  let actual_end = if end < 0 { s.length() } else { end }
  if start >= actual_end || start < 0 || actual_end > s.length() {
    return ""
  }
  s[start:actual_end].to_string() catch {
    _ => ""
  }
}

///|
/// Convert an integer (from string indexing) to a Char safely
/// Replaces deprecated Char::from_int (now use i.unsafe_to_char())
pub fn int_to_char(i : Int) -> Char {
  i.unsafe_to_char()
}
