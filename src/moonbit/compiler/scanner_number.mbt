// Number Literal Scanning Functions
// Extracted from scanner.mbt to improve code organization
//
// This module contains all number literal scanning logic including:
// - scan_number: Main entry point for number scanning
// - scan_hex_number: Hexadecimal numbers (0xFF, 0xFFn)
// - scan_octal_number: Octal numbers (0o77, 0o77n)
// - scan_binary_number: Binary numbers (0b1010, 0b1010n)
// - scan_decimal_number: Decimal numbers with full support (separators, floats, exponents, BigInt)

///|
/// Scan a number literal (all formats: decimal, hex, octal, binary, BigInt, separators)
fn scan_number(
  scanner : Scanner,
  start_pos : Int,
  start_line : Int,
  start_col : Int,
) -> (Token, Scanner) {
  let first_char = peek_char(scanner)

  // Check for special prefixes (0x, 0o, 0b)
  if first_char == '0' {
    let scanner_after_zero = advance(scanner)
    if scanner_after_zero.position < scanner_after_zero.length {
      let second_char = peek_char(scanner_after_zero)
      match second_char {
        'x' | 'X' =>
          return scan_hex_number(
            scanner_after_zero, start_pos, start_line, start_col,
          )
        'o' | 'O' =>
          return scan_octal_number(
            scanner_after_zero, start_pos, start_line, start_col,
          )
        'b' | 'B' =>
          return scan_binary_number(
            scanner_after_zero, start_pos, start_line, start_col,
          )
        _ => ()
      }
    }
  }

  // Decimal number
  scan_decimal_number(scanner, start_pos, start_line, start_col)
}

///|
/// Scan hexadecimal number (0xFF, 0xFFn)
fn scan_hex_number(
  scanner : Scanner,
  start_pos : Int,
  start_line : Int,
  start_col : Int,
) -> (Token, Scanner) {
  let mut scanner = advance(scanner) // Skip x/X
  let mut text = "0x"
  while scanner.position < scanner.length {
    let ch = peek_char(scanner)
    match ch {
      '0'..='9' | 'a'..='f' | 'A'..='F' => {
        text = text + Char::to_string(ch)
        scanner = advance(scanner)
      }
      '_' =>
        // Numeric separator - skip but don't include
        scanner = advance(scanner)
      _ => break
    }
  }

  // Check for BigInt suffix
  let is_bigint = peek_char(scanner) == 'n'
  if is_bigint {
    text = text + "n"
    scanner = advance(scanner)
  }
  let loc = SourceLocation::new(
    scanner.file_path,
    Position::new(start_line, start_col, start_pos),
    Position::new(scanner.line, scanner.column, scanner.position),
  )
  if is_bigint {
    (BigIntLiteral(text, loc), scanner)
  } else {
    (NumericLiteral(text, loc), scanner)
  }
}

///|
/// Scan octal number (0o77, 0o77n)
fn scan_octal_number(
  scanner : Scanner,
  start_pos : Int,
  start_line : Int,
  start_col : Int,
) -> (Token, Scanner) {
  let mut scanner = advance(scanner) // Skip o/O
  let mut text = "0o"
  while scanner.position < scanner.length {
    let ch = peek_char(scanner)
    match ch {
      '0'..='7' => {
        text = text + Char::to_string(ch)
        scanner = advance(scanner)
      }
      '_' => scanner = advance(scanner)
      _ => break
    }
  }

  // Check for BigInt suffix
  let is_bigint = peek_char(scanner) == 'n'
  if is_bigint {
    text = text + "n"
    scanner = advance(scanner)
  }
  let loc = SourceLocation::new(
    scanner.file_path,
    Position::new(start_line, start_col, start_pos),
    Position::new(scanner.line, scanner.column, scanner.position),
  )
  if is_bigint {
    (BigIntLiteral(text, loc), scanner)
  } else {
    (NumericLiteral(text, loc), scanner)
  }
}

///|
/// Scan binary number (0b1010, 0b1010n)
fn scan_binary_number(
  scanner : Scanner,
  start_pos : Int,
  start_line : Int,
  start_col : Int,
) -> (Token, Scanner) {
  let mut scanner = advance(scanner) // Skip b/B
  let mut text = "0b"
  while scanner.position < scanner.length {
    let ch = peek_char(scanner)
    match ch {
      '0' | '1' => {
        text = text + Char::to_string(ch)
        scanner = advance(scanner)
      }
      '_' => scanner = advance(scanner)
      _ => break
    }
  }

  // Check for BigInt suffix
  let is_bigint = peek_char(scanner) == 'n'
  if is_bigint {
    text = text + "n"
    scanner = advance(scanner)
  }
  let loc = SourceLocation::new(
    scanner.file_path,
    Position::new(start_line, start_col, start_pos),
    Position::new(scanner.line, scanner.column, scanner.position),
  )
  if is_bigint {
    (BigIntLiteral(text, loc), scanner)
  } else {
    (NumericLiteral(text, loc), scanner)
  }
}

///|
/// Scan decimal number with full support (separators, floats, exponents, BigInt)
fn scan_decimal_number(
  scanner : Scanner,
  start_pos : Int,
  start_line : Int,
  start_col : Int,
) -> (Token, Scanner) {
  let mut scanner = scanner
  let mut text = ""
  let mut has_dot = false
  let mut has_exponent = false

  // Integer part
  while scanner.position < scanner.length {
    let ch = peek_char(scanner)
    match ch {
      '0'..='9' => {
        text = text + Char::to_string(ch)
        scanner = advance(scanner)
      }
      '_' =>
        // Numeric separator - skip
        scanner = advance(scanner)
      _ => break
    }
  }

  // Decimal part
  if peek_char(scanner) == '.' {
    // Check it's not .. (range operator in some contexts)
    let next_scanner = advance(scanner)
    if peek_char(next_scanner) != '.' {
      has_dot = true
      text = text + "."
      scanner = next_scanner
      while scanner.position < scanner.length {
        let ch = peek_char(scanner)
        match ch {
          '0'..='9' => {
            text = text + Char::to_string(ch)
            scanner = advance(scanner)
          }
          '_' => scanner = advance(scanner)
          _ => break
        }
      }
    }
  }

  // Exponent part
  let ch = peek_char(scanner)
  if ch == 'e' || ch == 'E' {
    has_exponent = true
    text = text + Char::to_string(ch)
    scanner = advance(scanner)

    // Optional sign
    let sign = peek_char(scanner)
    if sign == '+' || sign == '-' {
      text = text + Char::to_string(sign)
      scanner = advance(scanner)
    }

    // Exponent digits
    while scanner.position < scanner.length {
      let ch = peek_char(scanner)
      match ch {
        '0'..='9' => {
          text = text + Char::to_string(ch)
          scanner = advance(scanner)
        }
        '_' => scanner = advance(scanner)
        _ => break
      }
    }
  }

  // BigInt suffix (only valid without decimal or exponent)
  let is_bigint = not(has_dot) && not(has_exponent) && peek_char(scanner) == 'n'
  if is_bigint {
    text = text + "n"
    scanner = advance(scanner)
  }
  let loc = SourceLocation::new(
    scanner.file_path,
    Position::new(start_line, start_col, start_pos),
    Position::new(scanner.line, scanner.column, scanner.position),
  )
  if is_bigint {
    (BigIntLiteral(text, loc), scanner)
  } else {
    (NumericLiteral(text, loc), scanner)
  }
}
