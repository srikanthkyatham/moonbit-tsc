// Scanner Identifier and Keyword Handling
// Unicode identifiers and keyword recognition

///|
/// Check if character is a valid Unicode identifier start (simplified)
/// Covers ASCII letters, underscore, dollar, and common Unicode letter ranges
fn is_unicode_ident_start(ch : Char) -> Bool {
  let code = ch.to_int()
  // ASCII letters and common identifier characters
  (ch >= 'a' && ch <= 'z') ||
  (ch >= 'A' && ch <= 'Z') ||
  ch == '_' ||
  ch == '$' ||
  // Latin Extended-A, Extended-B (0x0100-0x024F)
  (code >= 0x0100 && code <= 0x024F) ||
  // Greek and Coptic (0x0370-0x03FF)
  (code >= 0x0370 && code <= 0x03FF) ||
  // Cyrillic (0x0400-0x04FF)
  (code >= 0x0400 && code <= 0x04FF) ||
  // Armenian (0x0530-0x058F)
  (code >= 0x0530 && code <= 0x058F) ||
  // Hebrew (0x0590-0x05FF)
  (code >= 0x0590 && code <= 0x05FF) ||
  // Arabic (0x0600-0x06FF)
  (code >= 0x0600 && code <= 0x06FF) ||
  // Devanagari (0x0900-0x097F)
  (code >= 0x0900 && code <= 0x097F) ||
  // Thai (0x0E00-0x0E7F)
  (code >= 0x0E00 && code <= 0x0E7F) ||
  // Hangul Jamo (0x1100-0x11FF)
  (code >= 0x1100 && code <= 0x11FF) ||
  // CJK Unified Ideographs (0x4E00-0x9FFF)
  (code >= 0x4E00 && code <= 0x9FFF) ||
  // Hiragana (0x3040-0x309F)
  (code >= 0x3040 && code <= 0x309F) ||
  // Katakana (0x30A0-0x30FF)
  (code >= 0x30A0 && code <= 0x30FF) ||
  // Hangul Syllables (0xAC00-0xD7AF)
  (code >= 0xAC00 && code <= 0xD7AF) ||
  // Other common letter ranges
  (code >= 0x00C0 && code <= 0x00FF && code != 0x00D7 && code != 0x00F7) // Latin-1 Supplement letters
}

///|
/// Check if character is a valid Unicode identifier continue (simplified)
fn is_unicode_ident_continue(ch : Char) -> Bool {
  // Identifier start characters plus digits and some combining marks
  is_unicode_ident_start(ch) ||
  (ch >= '0' && ch <= '9') ||
  ch == '\u{200C}' || // Zero Width Non-Joiner
  ch == '\u{200D}' // Zero Width Joiner
}

///|
/// Scan identifier characters (including Unicode)
fn scan_ident_chars(
  code : StringView,
  state : ScanState,
  ident : StringBuilder,
) -> StringView {
  for cur = code {
    match cur {
    ['a'..='z' | 'A'..='Z' | '0'..='9' | '_' | '$' as ch, .. rest] => {
      ident.write_char(ch)
      state.col += 1
      state.offset += 1
      continue rest
    }
    [ch, .. rest] if is_unicode_ident_continue(ch) => {
      ident.write_char(ch)
      state.col += 1
      state.offset += 1
      continue rest
    }
    remaining => break remaining
  }
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
    "bigint" => KeywordBigInt(loc)
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
    "accessor" => KeywordAccessor(loc)
    "using" => KeywordUsing(loc)
    _ => Identifier(text, loc)
  }
}
