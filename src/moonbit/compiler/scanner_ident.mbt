// Identifier and Keyword Scanning
// This module contains functions for scanning identifiers, keywords, and private identifiers.
// Extracted from scanner.mbt for better code organization.

///|
/// Scan an identifier or keyword
fn scan_identifier_or_keyword(
  scanner : Scanner,
  start_pos : Int,
  start_line : Int,
  start_col : Int,
) -> (Token, Scanner) {
  let mut scanner = scanner

  // Scan while identifier part (includes Unicode letters/digits)
  while scanner.position < scanner.length {
    let ch = peek_char(scanner)
    if is_identifier_part(ch) {
      scanner = advance(scanner)
    } else {
      break
    }
  }
  let text = scanner.source.substring(start=start_pos, end=scanner.position)
  let loc = SourceLocation::new(
    scanner.file_path,
    Position::new(start_line, start_col, start_pos),
    Position::new(scanner.line, scanner.column, scanner.position),
  )

  // Check if it's a keyword
  let token = match text {
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
  (token, scanner)
}

///|
/// Scan private identifier (#fieldName)
fn scan_private_identifier(
  scanner : Scanner,
  start_pos : Int,
  start_line : Int,
  start_col : Int,
) -> (Token, Scanner) {
  let mut scanner = advance(scanner) // Skip #

  // Check if followed by valid identifier start
  let ch = peek_char(scanner)
  match ch {
    'a'..='z' | 'A'..='Z' | '_' | '$' => ()
    _ => {
      // Not a valid private identifier - return Unknown("#")
      let loc = SourceLocation::new(
        scanner.file_path,
        Position::new(start_line, start_col, start_pos),
        Position::new(scanner.line, scanner.column, scanner.position),
      )
      return (Unknown("#", loc), scanner)
    }
  }

  // Scan identifier part
  while scanner.position < scanner.length {
    let ch = peek_char(scanner)
    match ch {
      'a'..='z' | 'A'..='Z' | '0'..='9' | '_' | '$' =>
        scanner = advance(scanner)
      _ => break
    }
  }
  let text = scanner.source.substring(start=start_pos, end=scanner.position)
  let loc = SourceLocation::new(
    scanner.file_path,
    Position::new(start_line, start_col, start_pos),
    Position::new(scanner.line, scanner.column, scanner.position),
  )
  (PrivateIdentifier(text, loc), scanner)
}
