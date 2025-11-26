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
/// Alias for scan_all_v2_jsx for backwards compatibility
pub fn scan_all_jsx(source : String, file_path : String) -> Array[Token] {
  tokenize_with_jsx_support(source, file_path)
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
