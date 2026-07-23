// Scanner Number Handling
// Hex, octal, binary, and decimal number scanning

///|
/// Scan hex digits
fn scan_hex_digits(
  code : StringView,
  state : ScanState,
  digits : StringBuilder,
) -> StringView {
  for cur = code {
    match cur {
    ['0'..='9' | 'a'..='f' | 'A'..='F' as ch, .. rest] => {
      digits.write_char(ch)
      state.col += 1
      state.offset += 1
      continue rest
    }
    ['_', .. rest] => {
      state.col += 1
      state.offset += 1
      continue rest
    }
    remaining => break remaining
  }
  }
}

///|
/// Scan octal digits
fn scan_octal_digits(
  code : StringView,
  state : ScanState,
  digits : StringBuilder,
) -> StringView {
  for cur = code {
    match cur {
    ['0'..='7' as ch, .. rest] => {
      digits.write_char(ch)
      state.col += 1
      state.offset += 1
      continue rest
    }
    ['_', .. rest] => {
      state.col += 1
      state.offset += 1
      continue rest
    }
    remaining => break remaining
  }
  }
}

///|
/// Scan binary digits
fn scan_binary_digits(
  code : StringView,
  state : ScanState,
  digits : StringBuilder,
) -> StringView {
  for cur = code {
    match cur {
    ['0' | '1' as ch, .. rest] => {
      digits.write_char(ch)
      state.col += 1
      state.offset += 1
      continue rest
    }
    ['_', .. rest] => {
      state.col += 1
      state.offset += 1
      continue rest
    }
    remaining => break remaining
  }
  }
}

///|
/// Scan decimal digits
fn scan_decimal_digits(
  code : StringView,
  state : ScanState,
  num : StringBuilder,
) -> StringView {
  for cur = code {
    match cur {
    ['0'..='9' as ch, .. rest] => {
      num.write_char(ch)
      state.col += 1
      state.offset += 1
      continue rest
    }
    ['_', .. rest] => {
      state.col += 1
      state.offset += 1
      continue rest
    }
    remaining => break remaining
  }
  }
}
