// String utility functions to replace deprecated APIs

///|
/// Safe substring helper that mimics the old substring behavior
/// Uses the new str[:] slicing syntax internally with error handling
pub fn substr(s : String, start? : Int = 0, end? : Int = -1) -> String {
  let actual_end = if end < 0 { s.length() } else { end }
  if start >= actual_end || start < 0 || actual_end > s.length() {
    return ""
  }
  s[start:actual_end].to_owned()
}

///|
/// Convert an integer (from string indexing) to a Char safely
/// Replaces deprecated Char::from_int (now use i.unsafe_to_char())
pub fn int_to_char(i : Int) -> Char {
  i.unsafe_to_char()
}

///|
/// Bounds-checked UTF-16 code unit access, returned as Int.
/// Replacement for the deprecated `String::get` (whose return type is
/// changing to `UInt16?`); preserves the old `Int?` semantics.
pub fn code_unit(s : String, i : Int) -> Int? {
  if i >= 0 && i < s.length() {
    Some(s.code_unit_at(i).to_int())
  } else {
    None
  }
}
