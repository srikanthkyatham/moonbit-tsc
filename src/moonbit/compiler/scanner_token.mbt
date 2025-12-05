// Scanner Core Token Scanning
// Main single token scanning with operators and punctuation

///|
/// Scan a single token from the source
/// Returns the token and the remaining source
fn scan_single_token_v2(
  code : StringView,
  state : ScanState,
  file_path : String,
) -> (Token, StringView) {
  fn make_loc(
    start_line : Int,
    start_col : Int,
    start_offset : Int,
  ) -> SourceLocation {
    SourceLocation::new(
      file_path,
      Position::new(start_line, start_col, start_offset),
      Position::new(state.line, state.col, state.offset),
    )
  }

  loop code {
    // End of input
    [] as remaining => {
      let loc = make_loc(state.line, state.col, state.offset)
      (EOF(loc), remaining)
    }

    // === Whitespace ===
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

    // === Comments ===
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

    // === Multi-character operators (longest match first) ===
    [.. ">>>=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 4
      state.offset += 4
      (GreaterThanGreaterThanGreaterThanEquals(loc), rest)
    }
    [.. "===", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 3
      state.offset += 3
      (EqualsEqualsEquals(loc), rest)
    }
    [.. "!==", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 3
      state.offset += 3
      (ExclamationEqualsEquals(loc), rest)
    }
    [.. ">>>", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 3
      state.offset += 3
      (GreaterThanGreaterThanGreaterThan(loc), rest)
    }
    [.. "<<=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 3
      state.offset += 3
      (LessThanLessThanEquals(loc), rest)
    }
    [.. ">>=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 3
      state.offset += 3
      (GreaterThanGreaterThanEquals(loc), rest)
    }
    [.. "**=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 3
      state.offset += 3
      (StarStarEquals(loc), rest)
    }
    [.. "&&=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 3
      state.offset += 3
      (AmpersandAmpersandEquals(loc), rest)
    }
    [.. "||=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 3
      state.offset += 3
      (BarBarEquals(loc), rest)
    }
    [.. "??=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 3
      state.offset += 3
      (QuestionQuestionEquals(loc), rest)
    }
    [.. "...", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 3
      state.offset += 3
      (DotDotDot(loc), rest)
    }

    // 2-character operators
    [.. "==", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      (EqualsEquals(loc), rest)
    }
    [.. "!=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      (ExclamationEquals(loc), rest)
    }
    [.. "<=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      (LessThanEquals(loc), rest)
    }
    [.. ">=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      (GreaterThanEquals(loc), rest)
    }
    [.. "<<", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      (LessThanLessThan(loc), rest)
    }
    [.. ">>", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      (GreaterThanGreaterThan(loc), rest)
    }
    [.. "++", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      (PlusPlus(loc), rest)
    }
    [.. "--", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      (MinusMinus(loc), rest)
    }
    [.. "**", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      (StarStar(loc), rest)
    }
    [.. "&&", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      (AmpersandAmpersand(loc), rest)
    }
    [.. "||", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      (BarBar(loc), rest)
    }
    [.. "??", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      (QuestionQuestion(loc), rest)
    }
    [.. "?.", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      (QuestionDot(loc), rest)
    }
    [.. "=>", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      (Arrow(loc), rest)
    }
    [.. "+=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      (PlusEquals(loc), rest)
    }
    [.. "-=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      (MinusEquals(loc), rest)
    }
    [.. "*=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      (StarEquals(loc), rest)
    }
    [.. "/=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      (SlashEquals(loc), rest)
    }
    [.. "%=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      (PercentEquals(loc), rest)
    }
    [.. "&=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      (AmpersandEquals(loc), rest)
    }
    [.. "|=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      (BarEquals(loc), rest)
    }
    [.. "^=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      (CaretEquals(loc), rest)
    }
    [.. "</", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      (LessThanSlash(loc), rest)
    }
    [.. "/>", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      (SlashGreaterThan(loc), rest)
    }
    [.. "!.", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      (ExclamationDot(loc), rest)
    }

    // === Single-character operators ===
    ['+', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      (Plus(loc), rest)
    }
    ['-', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      (Minus(loc), rest)
    }
    ['*', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      (Star(loc), rest)
    }
    ['/', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      (Slash(loc), rest)
    }
    ['%', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      (Percent(loc), rest)
    }
    ['<', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      (LessThan(loc), rest)
    }
    ['>', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      (GreaterThan(loc), rest)
    }
    ['=', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      (Equals(loc), rest)
    }
    ['!', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      (Exclamation(loc), rest)
    }
    ['&', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      (Ampersand(loc), rest)
    }
    ['|', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      (Bar(loc), rest)
    }
    ['^', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      (Caret(loc), rest)
    }
    ['~', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      (Tilde(loc), rest)
    }
    ['?', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      (Question(loc), rest)
    }
    [':', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      (Colon(loc), rest)
    }
    [';', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      (Semicolon(loc), rest)
    }
    [',', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      (Comma(loc), rest)
    }
    ['.', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      (Dot(loc), rest)
    }
    ['(', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      (OpenParen(loc), rest)
    }
    [')', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      (CloseParen(loc), rest)
    }
    ['{', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      (OpenBrace(loc), rest)
    }
    ['}', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      (CloseBrace(loc), rest)
    }
    ['[', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      (OpenBracket(loc), rest)
    }
    [']', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      (CloseBracket(loc), rest)
    }
    ['@', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      (At(loc), rest)
    }

    // === Private identifier (#name) ===
    // Only valid if followed by identifier start character
    ['#', ch, .. rest] if (ch >= 'a' && ch <= 'z') ||
      (ch >= 'A' && ch <= 'Z') ||
      ch == '_' ||
      ch == '$' => {
      let start_line = state.line
      let start_col = state.col
      let start_offset = state.offset
      state.col += 1
      state.offset += 1
      let ident = StringBuilder::new()
      ident.write_char('#')
      // Re-include the first identifier char
      ident.write_char(ch)
      state.col += 1
      state.offset += 1
      let rest2 = scan_ident_chars(rest, state, ident)
      let loc = SourceLocation::new(
        file_path,
        Position::new(start_line, start_col, start_offset),
        Position::new(state.line, state.col, state.offset),
      )
      (PrivateIdentifier(ident.to_string(), loc), rest2)
    }
    // Invalid private identifier - just # followed by non-identifier char
    ['#', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      (Unknown("#", loc), rest)
    }

    // === Strings ===
    ['"', .. rest] => {
      let start_line = state.line
      let start_col = state.col
      let start_offset = state.offset
      state.col += 1
      state.offset += 1
      let content = StringBuilder::new()
      let rest2 = scan_double_string(rest, state, content)
      let loc = SourceLocation::new(
        file_path,
        Position::new(start_line, start_col, start_offset),
        Position::new(state.line, state.col, state.offset),
      )
      (StringLiteral(content.to_string(), loc), rest2)
    }
    ['\'', .. rest] => {
      let start_line = state.line
      let start_col = state.col
      let start_offset = state.offset
      state.col += 1
      state.offset += 1
      let content = StringBuilder::new()
      let rest2 = scan_single_string(rest, state, content)
      let loc = SourceLocation::new(
        file_path,
        Position::new(start_line, start_col, start_offset),
        Position::new(state.line, state.col, state.offset),
      )
      (StringLiteral(content.to_string(), loc), rest2)
    }

    // === Template literal ===
    ['`', .. rest] => {
      let start_line = state.line
      let start_col = state.col
      let start_offset = state.offset
      state.col += 1
      state.offset += 1
      let content = StringBuilder::new()
      let result = scan_template_literal_v2(rest, state, content)
      match result {
        TemplateScanResultV2::Complete(rest2) => {
          let loc = SourceLocation::new(
            file_path,
            Position::new(start_line, start_col, start_offset),
            Position::new(state.line, state.col, state.offset),
          )
          (TemplateLiteral(content.to_string(), loc), rest2)
        }
        TemplateScanResultV2::Head(rest2)
        | TemplateScanResultV2::Middle(rest2) => {
          let loc = SourceLocation::new(
            file_path,
            Position::new(start_line, start_col, start_offset),
            Position::new(state.line, state.col, state.offset),
          )
          (TemplateHead(content.to_string(), loc), rest2)
        }
        TemplateScanResultV2::Unterminated(rest2) => {
          let loc = SourceLocation::new(
            file_path,
            Position::new(start_line, start_col, start_offset),
            Position::new(state.line, state.col, state.offset),
          )
          (ScanError("Unterminated template literal.", 1160, loc), rest2)
        }
      }
    }

    // === Numbers ===
    [.. "0x", .. rest] | [.. "0X", .. rest] => {
      let start_col = state.col
      let start_offset = state.offset
      state.col += 2
      state.offset += 2
      let digits = StringBuilder::new()
      digits.write_string("0x")
      let rest2 = scan_hex_digits(rest, state, digits)
      match rest2 {
        ['n', .. rest3] => {
          state.col += 1
          state.offset += 1
          let loc = SourceLocation::new(
            file_path,
            Position::new(state.line, start_col, start_offset),
            Position::new(state.line, state.col, state.offset),
          )
          (BigIntLiteral(digits.to_string() + "n", loc), rest3)
        }
        _ => {
          let loc = SourceLocation::new(
            file_path,
            Position::new(state.line, start_col, start_offset),
            Position::new(state.line, state.col, state.offset),
          )
          (NumericLiteral(digits.to_string(), loc), rest2)
        }
      }
    }
    [.. "0o", .. rest] | [.. "0O", .. rest] => {
      let start_col = state.col
      let start_offset = state.offset
      state.col += 2
      state.offset += 2
      let digits = StringBuilder::new()
      digits.write_string("0o")
      let rest2 = scan_octal_digits(rest, state, digits)
      match rest2 {
        ['n', .. rest3] => {
          state.col += 1
          state.offset += 1
          let loc = SourceLocation::new(
            file_path,
            Position::new(state.line, start_col, start_offset),
            Position::new(state.line, state.col, state.offset),
          )
          (BigIntLiteral(digits.to_string() + "n", loc), rest3)
        }
        _ => {
          let loc = SourceLocation::new(
            file_path,
            Position::new(state.line, start_col, start_offset),
            Position::new(state.line, state.col, state.offset),
          )
          (NumericLiteral(digits.to_string(), loc), rest2)
        }
      }
    }
    [.. "0b", .. rest] | [.. "0B", .. rest] => {
      let start_col = state.col
      let start_offset = state.offset
      state.col += 2
      state.offset += 2
      let digits = StringBuilder::new()
      digits.write_string("0b")
      let rest2 = scan_binary_digits(rest, state, digits)
      match rest2 {
        ['n', .. rest3] => {
          state.col += 1
          state.offset += 1
          let loc = SourceLocation::new(
            file_path,
            Position::new(state.line, start_col, start_offset),
            Position::new(state.line, state.col, state.offset),
          )
          (BigIntLiteral(digits.to_string() + "n", loc), rest3)
        }
        _ => {
          let loc = SourceLocation::new(
            file_path,
            Position::new(state.line, start_col, start_offset),
            Position::new(state.line, state.col, state.offset),
          )
          (NumericLiteral(digits.to_string(), loc), rest2)
        }
      }
    }
    // Decimal number
    ['0'..='9' as first_digit, .. rest] => {
      let start_col = state.col
      let start_offset = state.offset
      state.col += 1
      state.offset += 1
      let num = StringBuilder::new()
      num.write_char(first_digit)
      // Integer part
      let rest2 = scan_decimal_digits(rest, state, num)
      // Decimal part
      let (rest3, has_dot) = match rest2 {
        ['.', '0'..='9' as ch, .. rest4] => {
          num.write_char('.')
          num.write_char(ch)
          state.col += 2
          state.offset += 2
          (scan_decimal_digits(rest4, state, num), true)
        }
        _ => (rest2, false)
      }
      // Exponent part
      let (rest4, has_exp) = match rest3 {
        ['e' | 'E', '+' | '-' as sign, '0'..='9' as ch, .. rest5] => {
          num.write_char('e')
          num.write_char(sign)
          num.write_char(ch)
          state.col += 3
          state.offset += 3
          (scan_decimal_digits(rest5, state, num), true)
        }
        ['e' | 'E', '0'..='9' as ch, .. rest5] => {
          num.write_char('e')
          num.write_char(ch)
          state.col += 2
          state.offset += 2
          (scan_decimal_digits(rest5, state, num), true)
        }
        _ => (rest3, false)
      }
      // BigInt suffix
      match rest4 {
        ['n', .. rest5] if not(has_dot) && not(has_exp) => {
          state.col += 1
          state.offset += 1
          let loc = SourceLocation::new(
            file_path,
            Position::new(state.line, start_col, start_offset),
            Position::new(state.line, state.col, state.offset),
          )
          (BigIntLiteral(num.to_string() + "n", loc), rest5)
        }
        _ => {
          let loc = SourceLocation::new(
            file_path,
            Position::new(state.line, start_col, start_offset),
            Position::new(state.line, state.col, state.offset),
          )
          (NumericLiteral(num.to_string(), loc), rest4)
        }
      }
    }

    // === Identifiers and keywords ===
    ['a'..='z' | 'A'..='Z' | '_' | '$' as first_char, .. rest] => {
      let start_col = state.col
      let start_offset = state.offset
      state.col += 1
      state.offset += 1
      let ident = StringBuilder::new()
      ident.write_char(first_char)
      let rest2 = scan_ident_chars(rest, state, ident)
      let loc = SourceLocation::new(
        file_path,
        Position::new(state.line, start_col, start_offset),
        Position::new(state.line, state.col, state.offset),
      )
      (keyword_token(ident.to_string(), loc), rest2)
    }

    // === Unicode identifiers ===
    [ch, .. rest] if is_unicode_ident_start(ch) => {
      let start_col = state.col
      let start_offset = state.offset
      state.col += 1
      state.offset += 1
      let ident = StringBuilder::new()
      ident.write_char(ch)
      let rest2 = scan_ident_chars(rest, state, ident)
      let loc = SourceLocation::new(
        file_path,
        Position::new(state.line, start_col, start_offset),
        Position::new(state.line, state.col, state.offset),
      )
      (Identifier(ident.to_string(), loc), rest2)
    }

    // === Smart quotes (common copy-paste error from documents/websites) ===
    // Left double quotation mark (U+201C), Right double quotation mark (U+201D)
    [ch, .. rest] if ch.to_int() == 0x201C || ch.to_int() == 0x201D => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      (SmartQuote(Char::to_string(ch), "\"", loc), rest)
    }
    // Left single quotation mark (U+2018), Right single quotation mark (U+2019)
    [ch, .. rest] if ch.to_int() == 0x2018 || ch.to_int() == 0x2019 => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      (SmartQuote(Char::to_string(ch), "'", loc), rest)
    }

    // === Unknown character ===
    [ch, .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      (Unknown(Char::to_string(ch), loc), rest)
    }
  }
}

///|
/// Scan a single token with context for regex vs division disambiguation
fn scan_single_token_with_context_v2(
  code : StringView,
  state : ScanState,
  file_path : String,
  prev_token : Token?,
) -> (Token, StringView) {
  // Skip whitespace first to check what's next
  let code_after_ws = skip_whitespace_v2(code, state)

  // Check if we might be at a regex literal
  match code_after_ws {
    ['/', ..] if allows_regex_v2(prev_token) => {
      // Could be regex - try to scan it
      let start_line = state.line
      let start_col = state.col
      let start_offset = state.offset
      // Skip the opening /
      state.col += 1
      state.offset += 1
      match code_after_ws {
        ['/', .. rest_after_slash] =>
          match scan_regex_pattern_v2(rest_after_slash, state) {
            Some((pattern, flags, rest)) => {
              let full_regex = "/" + pattern + "/" + flags
              let loc = SourceLocation::new(
                file_path,
                Position::new(start_line, start_col, start_offset),
                Position::new(state.line, state.col, state.offset),
              )
              (RegExpLiteral(full_regex, loc), rest)
            }
            None => {
              // Failed to parse as regex, restore state and scan as slash
              state.line = start_line
              state.col = start_col
              state.offset = start_offset
              scan_single_token_v2(code, state, file_path)
            }
          }
        _ => scan_single_token_v2(code, state, file_path)
      }
    }
    _ => scan_single_token_v2(code, state, file_path)
  }
}
