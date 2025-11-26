// Scanner V2 - Using MoonBit Idiomatic Pattern Matching
// Based on https://github.com/moonbitlang/mbtcc/blob/master/lexer/lexer.mbt
//
// This scanner uses loop with StringView pattern matching instead of
// the traditional peek_char/advance approach.

///|
/// Scan all tokens from source - V2 API (pattern matching based)
/// Can be used as a drop-in replacement for Scanner::new() + scan_all()
/// This version handles template interpolations properly with TemplateMiddle/TemplateTail
pub fn scan_all_v2(source : String, file_path : String) -> Array[Token] {
  tokenize_with_template_tracking(source, file_path)
}

///|
/// Simple tokenizer - does NOT handle template interpolations properly
/// Use tokenize_with_template_tracking for full TypeScript compatibility
pub fn tokenize_v2_simple(source : String, file_path : String) -> Array[Token] {
  tokenize_v2(source, file_path)
}

///|
/// Scan all tokens with JSX support - V2 API
/// Handles JSX elements, text content, and expressions
pub fn scan_all_v2_jsx(source : String, file_path : String) -> Array[Token] {
  tokenize_with_jsx_support(source, file_path)
}

///|
/// JSX scanner mode
priv enum JsxModeV2 {
  Standard // Normal TypeScript/JavaScript
  JsxTag // Inside JSX tag (scanning attributes)
  JsxText // JSX text content (between tags)
  JsxExpression // Inside JSX expression {expr}
}

///|
/// Tokenize with proper template interpolation and regex handling
/// Produces TemplateHead, TemplateMiddle, TemplateTail for templates with ${...}
/// Produces RegExpLiteral when / follows an operator or keyword (vs division)
/// Also handles JSDoc comments, hashbang, and comment directives
fn tokenize_with_template_tracking(
  source : String,
  file_path : String,
) -> Array[Token] {
  let tokens : Array[Token] = []
  let state : ScanState = { line: 1, col: 1, offset: 0 }
  let mut template_depth = 0
  let mut scan_continuation = false
  let mut code : StringView = source[:]
  let mut prev_token : Token? = None

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

  // Check for hashbang at file start
  let (hashbang_token, code_after_hashbang) = scan_hashbang_v2(
    code,
    state,
    file_path,
  )
  match hashbang_token {
    Some(token) => {
      tokens.push(token)
      prev_token = Some(token)
      code = code_after_hashbang
    }
    None => ()
  }

  while true {
    // After CloseBrace inside template, scan template continuation
    if scan_continuation {
      scan_continuation = false
      let start_line = state.line
      let start_col = state.col
      let start_offset = state.offset
      let content = StringBuilder::new()
      let result = scan_template_continuation_v2(code, state, content)
      match result {
        TemplateScanResultV2::Complete(rest) => {
          let loc = make_loc(start_line, start_col, start_offset)
          let token = TemplateTail(content.to_string(), loc)
          tokens.push(token)
          prev_token = Some(token)
          template_depth -= 1
          code = rest
        }
        TemplateScanResultV2::Middle(rest) => {
          let loc = make_loc(start_line, start_col, start_offset)
          let token = TemplateMiddle(content.to_string(), loc)
          tokens.push(token)
          prev_token = Some(token)
          code = rest
        }
        TemplateScanResultV2::Head(_) => {
          // Should not happen for continuation, but handle gracefully
          abort("Unexpected Head result from template continuation")
        }
      }
      continue
    }

    // Skip whitespace and check for special comments (JSDoc, directives)
    let (code_after_ws, special_token) = skip_whitespace_with_special_comments_v2(
      code,
      state,
      file_path,
    )
    code = code_after_ws

    // If we found a special comment token, add it and continue
    match special_token {
      Some(token) => {
        tokens.push(token)
        prev_token = Some(token)
        continue
      }
      None => ()
    }

    // Scan single token with context for regex disambiguation
    let (token, rest) = scan_single_token_with_context_v2(
      code,
      state,
      file_path,
      prev_token,
    )
    tokens.push(token)
    code = rest

    // Track template depth and trigger continuation scanning
    match token {
      TemplateHead(_, _) => template_depth += 1
      TemplateLiteral(_, _) => () // Simple template, no interpolation
      CloseBrace(_) if template_depth > 0 => scan_continuation = true
      EOF(_) => break
      _ => ()
    }

    prev_token = Some(token)
  }
  tokens
}

///|
/// Tokenize with JSX support
/// Handles JSX elements, text, expressions, plus templates and regex
fn tokenize_with_jsx_support(
  source : String,
  file_path : String,
) -> Array[Token] {
  let tokens : Array[Token] = []
  let state : ScanState = { line: 1, col: 1, offset: 0 }
  let mut template_depth = 0
  let mut scan_template_continuation = false
  let mut code : StringView = source[:]
  let mut prev_token : Token? = None
  let mut jsx_mode : JsxModeV2 = JsxModeV2::Standard
  let jsx_mode_stack : Array[JsxModeV2] = []

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

  fn push_jsx_mode(new_mode : JsxModeV2) -> Unit {
    jsx_mode_stack.push(jsx_mode)
    jsx_mode = new_mode
  }

  fn pop_jsx_mode() -> Unit {
    match jsx_mode_stack.pop() {
      Some(mode) => jsx_mode = mode
      None => jsx_mode = JsxModeV2::Standard
    }
  }

  // Check for hashbang at file start
  let (hashbang_token, code_after_hashbang) = scan_hashbang_v2(
    code,
    state,
    file_path,
  )
  match hashbang_token {
    Some(token) => {
      tokens.push(token)
      prev_token = Some(token)
      code = code_after_hashbang
    }
    None => ()
  }

  while true {
    // Handle template continuation after CloseBrace
    if scan_template_continuation {
      scan_template_continuation = false
      let start_line = state.line
      let start_col = state.col
      let start_offset = state.offset
      let content = StringBuilder::new()
      let result = scan_template_continuation_v2(code, state, content)
      match result {
        TemplateScanResultV2::Complete(rest) => {
          let loc = make_loc(start_line, start_col, start_offset)
          let token = TemplateTail(content.to_string(), loc)
          tokens.push(token)
          prev_token = Some(token)
          template_depth -= 1
          code = rest
        }
        TemplateScanResultV2::Middle(rest) => {
          let loc = make_loc(start_line, start_col, start_offset)
          let token = TemplateMiddle(content.to_string(), loc)
          tokens.push(token)
          prev_token = Some(token)
          code = rest
        }
        TemplateScanResultV2::Head(_) =>
          abort("Unexpected Head result from template continuation")
      }
      continue
    }

    // Mode-specific scanning
    match jsx_mode {
      JsxModeV2::Standard => {
        // Skip whitespace and check for special comments (JSDoc, directives)
        let (code_after_ws, special_token) = skip_whitespace_with_special_comments_v2(
          code,
          state,
          file_path,
        )
        code = code_after_ws

        // If we found a special comment token, add it and continue
        match special_token {
          Some(token) => {
            tokens.push(token)
            prev_token = Some(token)
            continue
          }
          None => ()
        }

        // Check for JSX start (<)
        match code_after_ws {
          ['<', '/', .. rest] => {
            // Closing tag </
            let start_line = state.line
            let start_col = state.col
            let start_offset = state.offset
            state.col += 2
            state.offset += 2
            let loc = make_loc(start_line, start_col, start_offset)
            let token = LessThanSlash(loc)
            tokens.push(token)
            prev_token = Some(token)
            code = rest
            push_jsx_mode(JsxModeV2::JsxTag)
          }
          ['<', ch, ..] if is_jsx_tag_start(ch) => {
            // Opening tag <
            let start_line = state.line
            let start_col = state.col
            let start_offset = state.offset
            state.col += 1
            state.offset += 1
            let loc = make_loc(start_line, start_col, start_offset)
            let token = JsxTagOpen(loc)
            tokens.push(token)
            prev_token = Some(token)
            code = try! code_after_ws[1:]
            push_jsx_mode(JsxModeV2::JsxTag)
          }
          _ => {
            // Regular token scanning with context
            let (token, rest) = scan_single_token_with_context_v2(
              code,
              state,
              file_path,
              prev_token,
            )
            tokens.push(token)
            code = rest
            // Track template depth
            match token {
              TemplateHead(_, _) => template_depth += 1
              CloseBrace(_) if template_depth > 0 =>
                scan_template_continuation = true
              EOF(_) => break
              _ => ()
            }
            prev_token = Some(token)
          }
        }
      }
      JsxModeV2::JsxTag => {
        // Inside JSX tag, scanning tag name and attributes
        let code_after_ws = skip_whitespace_v2(code, state)
        match code_after_ws {
          [] => {
            let loc = make_loc(state.line, state.col, state.offset)
            tokens.push(EOF(loc))
            break
          }
          ['/', '>', .. rest] => {
            // Self-closing />
            let start_line = state.line
            let start_col = state.col
            let start_offset = state.offset
            state.col += 2
            state.offset += 2
            let loc = make_loc(start_line, start_col, start_offset)
            let token = SlashGreaterThan(loc)
            tokens.push(token)
            prev_token = Some(token)
            code = rest
            pop_jsx_mode()
          }
          ['>', .. rest] => {
            // Tag close >
            let start_line = state.line
            let start_col = state.col
            let start_offset = state.offset
            state.col += 1
            state.offset += 1
            let loc = make_loc(start_line, start_col, start_offset)
            let token = JsxTagClose(loc)
            tokens.push(token)
            prev_token = Some(token)
            code = rest
            // After >, switch to JsxText mode
            jsx_mode = JsxModeV2::JsxText
          }
          ['{', .. rest] => {
            // Expression in attribute {expr}
            let start_line = state.line
            let start_col = state.col
            let start_offset = state.offset
            state.col += 1
            state.offset += 1
            let loc = make_loc(start_line, start_col, start_offset)
            let token = JsxExpressionStart(loc)
            tokens.push(token)
            prev_token = Some(token)
            code = rest
            push_jsx_mode(JsxModeV2::JsxExpression)
          }
          ['=', .. rest] => {
            let start_line = state.line
            let start_col = state.col
            let start_offset = state.offset
            state.col += 1
            state.offset += 1
            let loc = make_loc(start_line, start_col, start_offset)
            let token = Token::Equals(loc)
            tokens.push(token)
            prev_token = Some(token)
            code = rest
          }
          ['"', .. rest] => {
            // String attribute value
            let start_line = state.line
            let start_col = state.col
            let start_offset = state.offset
            state.col += 1
            state.offset += 1
            let content = StringBuilder::new()
            let rest2 = scan_double_string(rest, state, content)
            let loc = make_loc(start_line, start_col, start_offset)
            let token = Token::StringLiteral(content.to_string(), loc)
            tokens.push(token)
            prev_token = Some(token)
            code = rest2
          }
          ['\'', .. rest] => {
            // Single-quoted attribute value
            let start_line = state.line
            let start_col = state.col
            let start_offset = state.offset
            state.col += 1
            state.offset += 1
            let content = StringBuilder::new()
            let rest2 = scan_single_string(rest, state, content)
            let loc = make_loc(start_line, start_col, start_offset)
            let token = Token::StringLiteral(content.to_string(), loc)
            tokens.push(token)
            prev_token = Some(token)
            code = rest2
          }
          _ => {
            // Identifier (tag name or attribute name)
            let (token, rest) = scan_jsx_identifier(code_after_ws, state, file_path)
            tokens.push(token)
            prev_token = Some(token)
            code = rest
          }
        }
      }
      JsxModeV2::JsxText => {
        // JSX text content between tags
        match code {
          [] => {
            let loc = make_loc(state.line, state.col, state.offset)
            tokens.push(EOF(loc))
            break
          }
          ['<', '/', ..] => {
            // Closing tag </
            let start_line = state.line
            let start_col = state.col
            let start_offset = state.offset
            state.col += 2
            state.offset += 2
            let loc = make_loc(start_line, start_col, start_offset)
            let token = LessThanSlash(loc)
            tokens.push(token)
            prev_token = Some(token)
            code = try! code[2:]
            jsx_mode = JsxModeV2::JsxTag
          }
          ['<', ch, ..] if is_jsx_tag_start(ch) => {
            // Nested opening tag
            let start_line = state.line
            let start_col = state.col
            let start_offset = state.offset
            state.col += 1
            state.offset += 1
            let loc = make_loc(start_line, start_col, start_offset)
            let token = JsxTagOpen(loc)
            tokens.push(token)
            prev_token = Some(token)
            code = try! code[1:]
            push_jsx_mode(JsxModeV2::JsxTag)
          }
          ['{', .. rest] => {
            // Expression {expr}
            let start_line = state.line
            let start_col = state.col
            let start_offset = state.offset
            state.col += 1
            state.offset += 1
            let loc = make_loc(start_line, start_col, start_offset)
            let token = JsxExpressionStart(loc)
            tokens.push(token)
            prev_token = Some(token)
            code = rest
            push_jsx_mode(JsxModeV2::JsxExpression)
          }
          _ => {
            // Scan text content
            let (token, rest) = scan_jsx_text_v2(code, state, file_path)
            tokens.push(token)
            prev_token = Some(token)
            code = rest
          }
        }
      }
      JsxModeV2::JsxExpression => {
        // Inside JSX expression {expr}
        let code_after_ws = skip_whitespace_v2(code, state)
        match code_after_ws {
          [] => {
            let loc = make_loc(state.line, state.col, state.offset)
            tokens.push(EOF(loc))
            break
          }
          ['}', .. rest] => {
            // End of expression
            let start_line = state.line
            let start_col = state.col
            let start_offset = state.offset
            state.col += 1
            state.offset += 1
            let loc = make_loc(start_line, start_col, start_offset)
            let token = JsxExpressionEnd(loc)
            tokens.push(token)
            prev_token = Some(token)
            code = rest
            pop_jsx_mode()
          }
          _ => {
            // Regular token inside expression
            let (token, rest) = scan_single_token_with_context_v2(
              code,
              state,
              file_path,
              prev_token,
            )
            tokens.push(token)
            code = rest
            match token {
              TemplateHead(_, _) => template_depth += 1
              CloseBrace(_) if template_depth > 0 =>
                scan_template_continuation = true
              EOF(_) => break
              _ => ()
            }
            prev_token = Some(token)
          }
        }
      }
    }
  }
  tokens
}

///|
/// Check if character can start a JSX tag name
fn is_jsx_tag_start(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') ||
  (ch >= 'A' && ch <= 'Z') ||
  ch == '_' ||
  ch == '$'
}

///|
/// Scan JSX text content (between tags)
fn scan_jsx_text_v2(
  code : StringView,
  state : ScanState,
  file_path : String,
) -> (Token, StringView) {
  let start_line = state.line
  let start_col = state.col
  let start_offset = state.offset
  let text = StringBuilder::new()

  let rest = loop code {
    [] as remaining => remaining
    ['<' | '{', ..] as remaining => remaining // End of text
    ['\n', .. rest] => {
      text.write_char('\n')
      state.line += 1
      state.col = 1
      state.offset += 1
      continue rest
    }
    [ch, .. rest] => {
      text.write_char(ch)
      state.col += 1
      state.offset += 1
      continue rest
    }
  }

  let loc = SourceLocation::new(
    file_path,
    Position::new(start_line, start_col, start_offset),
    Position::new(state.line, state.col, state.offset),
  )
  (JsxText(text.to_string(), loc), rest)
}

///|
/// Scan JSX identifier (tag name or attribute name, may contain -)
fn scan_jsx_identifier(
  code : StringView,
  state : ScanState,
  file_path : String,
) -> (Token, StringView) {
  let start_line = state.line
  let start_col = state.col
  let start_offset = state.offset
  let ident = StringBuilder::new()

  let rest = loop code {
    ['a'..='z' | 'A'..='Z' | '0'..='9' | '_' | '$' | '-' as ch, .. rest] => {
      ident.write_char(ch)
      state.col += 1
      state.offset += 1
      continue rest
    }
    remaining => remaining
  }

  let loc = SourceLocation::new(
    file_path,
    Position::new(start_line, start_col, start_offset),
    Position::new(state.line, state.col, state.offset),
  )
  (Identifier(ident.to_string(), loc), rest)
}

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
    ['#', .. rest] => {
      let start_line = state.line
      let start_col = state.col
      let start_offset = state.offset
      state.col += 1
      state.offset += 1
      let ident = StringBuilder::new()
      ident.write_char('#')
      let rest2 = scan_ident_chars(rest, state, ident)
      let loc = SourceLocation::new(
        file_path,
        Position::new(start_line, start_col, start_offset),
        Position::new(state.line, state.col, state.offset),
      )
      (PrivateIdentifier(ident.to_string(), loc), rest2)
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
        TemplateScanResultV2::Head(rest2) | TemplateScanResultV2::Middle(rest2) => {
          let loc = SourceLocation::new(
            file_path,
            Position::new(start_line, start_col, start_offset),
            Position::new(state.line, state.col, state.offset),
          )
          (TemplateHead(content.to_string(), loc), rest2)
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

///|
/// Skip whitespace and comments, returning remaining code
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
/// Internal state for tracking position in the scanner
priv struct ScanState {
  mut line : Int
  mut col : Int
  mut offset : Int
}

///|
/// Skip single-line comment and return remaining code
fn skip_line_comment(
  code : StringView,
  state : ScanState,
) -> StringView {
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
fn skip_block_comment(
  code : StringView,
  state : ScanState,
) -> StringView {
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
fn skip_whitespace_with_special_comments_v2(
  code : StringView,
  state : ScanState,
  file_path : String,
) -> (StringView, Token?) {
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
    // Check for JSDoc comment first (/** but not /**/)
    [.. "/**", ch, ..] if ch != '/' => {
      let (token, rest) = scan_jsdoc_comment_v2(code, state, file_path)
      (rest, Some(token))
    }
    // Check for comment directive
    [.. "///", ' ', '<', ..] | [.. "///<", ..] | [.. "// @ts-", ..] | [.. "//@ts-", ..] => {
      let (token, rest) = scan_comment_directive_v2(code, state, file_path)
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

///|
/// Scan double-quoted string
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
    ['\n', .. remaining] => remaining // Unterminated at newline
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
/// Scan single-quoted string
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
    ['\n', .. remaining] => remaining // Unterminated at newline
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
/// Template literal scanning result
priv enum TemplateScanResultV2 {
  Complete(StringView) // Full template literal or template tail
  Head(StringView) // Template head (has interpolation after)
  Middle(StringView) // Template middle (has interpolation after)
}

///|
/// Scan template literal
fn scan_template_literal_v2(
  code : StringView,
  state : ScanState,
  content : StringBuilder,
) -> TemplateScanResultV2 {
  loop code {
    [] as remaining => Complete(remaining)
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
    [] as remaining => Complete(remaining) // Unterminated
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
    [.. "\\\\", .. rest] => {
      content.write_char('\\')
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

///|
/// Scan hex digits
fn scan_hex_digits(
  code : StringView,
  state : ScanState,
  digits : StringBuilder,
) -> StringView {
  loop code {
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
    remaining => remaining
  }
}

///|
/// Scan octal digits
fn scan_octal_digits(
  code : StringView,
  state : ScanState,
  digits : StringBuilder,
) -> StringView {
  loop code {
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
    remaining => remaining
  }
}

///|
/// Scan binary digits
fn scan_binary_digits(
  code : StringView,
  state : ScanState,
  digits : StringBuilder,
) -> StringView {
  loop code {
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
    remaining => remaining
  }
}

///|
/// Scan decimal digits
fn scan_decimal_digits(
  code : StringView,
  state : ScanState,
  num : StringBuilder,
) -> StringView {
  loop code {
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
    remaining => remaining
  }
}

///|
/// Scan identifier characters
fn scan_ident_chars(
  code : StringView,
  state : ScanState,
  ident : StringBuilder,
) -> StringView {
  loop code {
    ['a'..='z' | 'A'..='Z' | '0'..='9' | '_' | '$' as ch, .. rest] => {
      ident.write_char(ch)
      state.col += 1
      state.offset += 1
      continue rest
    }
    remaining => remaining
  }
}

///|
/// Get keyword token from identifier
fn keyword_token(text : String, loc : SourceLocation) -> Token {
  match text {
    "any" => KeywordAny(loc)
    "boolean" => KeywordBoolean(loc)
    "number" => KeywordNumber(loc)
    "string" => KeywordString(loc)
    "symbol" => KeywordSymbol(loc)
    "object" => KeywordObject(loc)
    "void" => KeywordVoid(loc)
    "unknown" => KeywordUnknown(loc)
    "never" => KeywordNever(loc)
    "undefined" => KeywordUndefined(loc)
    "null" => KeywordNull(loc)
    "let" => KeywordLet(loc)
    "const" => KeywordConst(loc)
    "var" => KeywordVar(loc)
    "function" => KeywordFunction(loc)
    "class" => KeywordClass(loc)
    "interface" => KeywordInterface(loc)
    "enum" => KeywordEnum(loc)
    "type" => KeywordType(loc)
    "namespace" => KeywordNamespace(loc)
    "module" => KeywordModule(loc)
    "if" => KeywordIf(loc)
    "else" => KeywordElse(loc)
    "switch" => KeywordSwitch(loc)
    "case" => KeywordCase(loc)
    "default" => KeywordDefault(loc)
    "for" => KeywordFor(loc)
    "while" => KeywordWhile(loc)
    "do" => KeywordDo(loc)
    "break" => KeywordBreak(loc)
    "continue" => KeywordContinue(loc)
    "return" => KeywordReturn(loc)
    "throw" => KeywordThrow(loc)
    "try" => KeywordTry(loc)
    "catch" => KeywordCatch(loc)
    "finally" => KeywordFinally(loc)
    "public" => KeywordPublic(loc)
    "private" => KeywordPrivate(loc)
    "protected" => KeywordProtected(loc)
    "static" => KeywordStatic(loc)
    "readonly" => KeywordReadonly(loc)
    "abstract" => KeywordAbstract(loc)
    "async" => KeywordAsync(loc)
    "await" => KeywordAwait(loc)
    "new" => KeywordNew(loc)
    "this" => KeywordThis(loc)
    "super" => KeywordSuper(loc)
    "import" => KeywordImport(loc)
    "export" => KeywordExport(loc)
    "from" => KeywordFrom(loc)
    "as" => KeywordAs(loc)
    "satisfies" => KeywordSatisfies(loc)
    "extends" => KeywordExtends(loc)
    "implements" => KeywordImplements(loc)
    "yield" => KeywordYield(loc)
    "in" => KeywordIn(loc)
    "of" => KeywordOf(loc)
    "instanceof" => KeywordInstanceOf(loc)
    "typeof" => KeywordTypeOf(loc)
    "delete" => KeywordDelete(loc)
    "debugger" => KeywordDebugger(loc)
    "declare" => KeywordDeclare(loc)
    _ => Identifier(text, loc)
  }
}

///|
/// Tokenize the entire source using pattern matching
pub fn tokenize_v2(source : String, file_path : String) -> Array[Token] {
  let tokens : Array[Token] = []
  let state : ScanState = { line: 1, col: 1, offset: 0 }

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

  // Main tokenization loop
  loop source[:] {
    // End of input
    [] => {
      let loc = make_loc(state.line, state.col, state.offset)
      tokens.push(EOF(loc))
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
      tokens.push(GreaterThanGreaterThanGreaterThanEquals(loc))
      continue rest
    }
    [.. "===", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 3
      state.offset += 3
      tokens.push(EqualsEqualsEquals(loc))
      continue rest
    }
    [.. "!==", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 3
      state.offset += 3
      tokens.push(ExclamationEqualsEquals(loc))
      continue rest
    }
    [.. ">>>", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 3
      state.offset += 3
      tokens.push(GreaterThanGreaterThanGreaterThan(loc))
      continue rest
    }
    [.. "<<=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 3
      state.offset += 3
      tokens.push(LessThanLessThanEquals(loc))
      continue rest
    }
    [.. ">>=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 3
      state.offset += 3
      tokens.push(GreaterThanGreaterThanEquals(loc))
      continue rest
    }
    [.. "**=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 3
      state.offset += 3
      tokens.push(StarStarEquals(loc))
      continue rest
    }
    [.. "&&=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 3
      state.offset += 3
      tokens.push(AmpersandAmpersandEquals(loc))
      continue rest
    }
    [.. "||=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 3
      state.offset += 3
      tokens.push(BarBarEquals(loc))
      continue rest
    }
    [.. "??=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 3
      state.offset += 3
      tokens.push(QuestionQuestionEquals(loc))
      continue rest
    }
    [.. "...", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 3
      state.offset += 3
      tokens.push(DotDotDot(loc))
      continue rest
    }

    // 2-character operators
    [.. "==", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(EqualsEquals(loc))
      continue rest
    }
    [.. "!=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(ExclamationEquals(loc))
      continue rest
    }
    [.. "<=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(LessThanEquals(loc))
      continue rest
    }
    [.. ">=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(GreaterThanEquals(loc))
      continue rest
    }
    [.. "<<", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(LessThanLessThan(loc))
      continue rest
    }
    [.. ">>", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(GreaterThanGreaterThan(loc))
      continue rest
    }
    [.. "++", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(PlusPlus(loc))
      continue rest
    }
    [.. "--", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(MinusMinus(loc))
      continue rest
    }
    [.. "**", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(StarStar(loc))
      continue rest
    }
    [.. "&&", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(AmpersandAmpersand(loc))
      continue rest
    }
    [.. "||", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(BarBar(loc))
      continue rest
    }
    [.. "??", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(QuestionQuestion(loc))
      continue rest
    }
    [.. "?.", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(QuestionDot(loc))
      continue rest
    }
    [.. "+=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(PlusEquals(loc))
      continue rest
    }
    [.. "-=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(MinusEquals(loc))
      continue rest
    }
    [.. "*=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(StarEquals(loc))
      continue rest
    }
    [.. "/=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(SlashEquals(loc))
      continue rest
    }
    [.. "%=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(PercentEquals(loc))
      continue rest
    }
    [.. "&=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(AmpersandEquals(loc))
      continue rest
    }
    [.. "|=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(BarEquals(loc))
      continue rest
    }
    [.. "^=", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(CaretEquals(loc))
      continue rest
    }
    [.. "=>", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(Arrow(loc))
      continue rest
    }
    [.. "</", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(LessThanSlash(loc))
      continue rest
    }
    [.. "/>", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(SlashGreaterThan(loc))
      continue rest
    }
    [.. "!.", .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 2
      state.offset += 2
      tokens.push(ExclamationDot(loc))
      continue rest
    }

    // === Single-character operators ===
    ['+', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(Plus(loc))
      continue rest
    }
    ['-', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(Minus(loc))
      continue rest
    }
    ['*', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(Star(loc))
      continue rest
    }
    ['/', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(Slash(loc))
      continue rest
    }
    ['%', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(Percent(loc))
      continue rest
    }
    ['<', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(LessThan(loc))
      continue rest
    }
    ['>', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(GreaterThan(loc))
      continue rest
    }
    ['=', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(Equals(loc))
      continue rest
    }
    ['!', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(Exclamation(loc))
      continue rest
    }
    ['&', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(Ampersand(loc))
      continue rest
    }
    ['|', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(Bar(loc))
      continue rest
    }
    ['^', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(Caret(loc))
      continue rest
    }
    ['~', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(Tilde(loc))
      continue rest
    }
    ['?', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(Question(loc))
      continue rest
    }
    [':', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(Colon(loc))
      continue rest
    }
    [';', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(Semicolon(loc))
      continue rest
    }
    [',', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(Comma(loc))
      continue rest
    }
    ['.', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(Dot(loc))
      continue rest
    }
    ['(', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(OpenParen(loc))
      continue rest
    }
    [')', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(CloseParen(loc))
      continue rest
    }
    ['{', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(OpenBrace(loc))
      continue rest
    }
    ['}', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(CloseBrace(loc))
      continue rest
    }
    ['[', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(OpenBracket(loc))
      continue rest
    }
    [']', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(CloseBracket(loc))
      continue rest
    }
    ['@', .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(At(loc))
      continue rest
    }

    // === Private identifier (#name) ===
    ['#', .. rest] => {
      let start_line = state.line
      let start_col = state.col
      let start_offset = state.offset
      state.col += 1
      state.offset += 1
      let ident = StringBuilder::new()
      ident.write_char('#')
      let rest2 = scan_ident_chars(rest, state, ident)
      let loc = SourceLocation::new(
        file_path,
        Position::new(start_line, start_col, start_offset),
        Position::new(state.line, state.col, state.offset),
      )
      tokens.push(PrivateIdentifier(ident.to_string(), loc))
      continue rest2
    }

    // === String literals ===
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
      tokens.push(StringLiteral(content.to_string(), loc))
      continue rest2
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
      tokens.push(StringLiteral(content.to_string(), loc))
      continue rest2
    }

    // === Template literal ===
    ['`', .. rest] => {
      let start_line = state.line
      let start_col = state.col
      let start_offset = state.offset
      state.col += 1
      state.offset += 1
      let content = StringBuilder::new()
      match scan_template_literal_v2(rest, state, content) {
        TemplateScanResultV2::Complete(rest2) => {
          let loc = SourceLocation::new(
            file_path,
            Position::new(start_line, start_col, start_offset),
            Position::new(state.line, state.col, state.offset),
          )
          tokens.push(TemplateLiteral(content.to_string(), loc))
          continue rest2
        }
        TemplateScanResultV2::Head(rest2)
        | TemplateScanResultV2::Middle(rest2) => {
          let loc = SourceLocation::new(
            file_path,
            Position::new(start_line, start_col, start_offset),
            Position::new(state.line, state.col, state.offset),
          )
          tokens.push(TemplateHead(content.to_string(), loc))
          continue rest2
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
          tokens.push(BigIntLiteral(digits.to_string() + "n", loc))
          continue rest3
        }
        _ => {
          let loc = SourceLocation::new(
            file_path,
            Position::new(state.line, start_col, start_offset),
            Position::new(state.line, state.col, state.offset),
          )
          tokens.push(NumericLiteral(digits.to_string(), loc))
          continue rest2
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
          tokens.push(BigIntLiteral(digits.to_string() + "n", loc))
          continue rest3
        }
        _ => {
          let loc = SourceLocation::new(
            file_path,
            Position::new(state.line, start_col, start_offset),
            Position::new(state.line, state.col, state.offset),
          )
          tokens.push(NumericLiteral(digits.to_string(), loc))
          continue rest2
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
          tokens.push(BigIntLiteral(digits.to_string() + "n", loc))
          continue rest3
        }
        _ => {
          let loc = SourceLocation::new(
            file_path,
            Position::new(state.line, start_col, start_offset),
            Position::new(state.line, state.col, state.offset),
          )
          tokens.push(NumericLiteral(digits.to_string(), loc))
          continue rest2
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
          tokens.push(BigIntLiteral(num.to_string() + "n", loc))
          continue rest5
        }
        _ => {
          let loc = SourceLocation::new(
            file_path,
            Position::new(state.line, start_col, start_offset),
            Position::new(state.line, state.col, state.offset),
          )
          tokens.push(NumericLiteral(num.to_string(), loc))
          continue rest4
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
      tokens.push(keyword_token(ident.to_string(), loc))
      continue rest2
    }

    // === Unknown character ===
    [ch, .. rest] => {
      let loc = make_loc(state.line, state.col, state.offset)
      state.col += 1
      state.offset += 1
      tokens.push(Unknown(Char::to_string(ch), loc))
      continue rest
    }
  }
  tokens
}
