// Token types for the TypeScript compiler
// Based on TypeScript's SyntaxKind enum

///|
/// Token represents a lexical token in the source code
pub enum Token {
  // Literals
  NumericLiteral(String, SourceLocation)
  StringLiteral(String, SourceLocation)
  TemplateLiteral(String, SourceLocation)
  RegExpLiteral(String, SourceLocation)

  // Identifiers and Keywords
  Identifier(String, SourceLocation)

  // Reserved Keywords
  // Type Keywords
  KeywordAny(SourceLocation)
  KeywordBoolean(SourceLocation)
  KeywordNumber(SourceLocation)
  KeywordString(SourceLocation)
  KeywordSymbol(SourceLocation)
  KeywordObject(SourceLocation)
  KeywordVoid(SourceLocation)
  KeywordUnknown(SourceLocation)
  KeywordNever(SourceLocation)
  KeywordUndefined(SourceLocation)
  KeywordNull(SourceLocation)

  // Declaration Keywords
  KeywordLet(SourceLocation)
  KeywordConst(SourceLocation)
  KeywordVar(SourceLocation)
  KeywordFunction(SourceLocation)
  KeywordClass(SourceLocation)
  KeywordInterface(SourceLocation)
  KeywordEnum(SourceLocation)
  KeywordType(SourceLocation)
  KeywordNamespace(SourceLocation)
  KeywordModule(SourceLocation)

  // Control Flow Keywords
  KeywordIf(SourceLocation)
  KeywordElse(SourceLocation)
  KeywordSwitch(SourceLocation)
  KeywordCase(SourceLocation)
  KeywordDefault(SourceLocation)
  KeywordFor(SourceLocation)
  KeywordWhile(SourceLocation)
  KeywordDo(SourceLocation)
  KeywordBreak(SourceLocation)
  KeywordContinue(SourceLocation)
  KeywordReturn(SourceLocation)
  KeywordThrow(SourceLocation)
  KeywordTry(SourceLocation)
  KeywordCatch(SourceLocation)
  KeywordFinally(SourceLocation)

  // Modifier Keywords
  KeywordPublic(SourceLocation)
  KeywordPrivate(SourceLocation)
  KeywordProtected(SourceLocation)
  KeywordStatic(SourceLocation)
  KeywordReadonly(SourceLocation)
  KeywordAbstract(SourceLocation)
  KeywordAsync(SourceLocation)
  KeywordAwait(SourceLocation)
  KeywordDeclare(SourceLocation)

  // Other Keywords
  KeywordNew(SourceLocation)
  KeywordThis(SourceLocation)
  KeywordSuper(SourceLocation)
  KeywordImport(SourceLocation)
  KeywordExport(SourceLocation)
  KeywordFrom(SourceLocation)
  KeywordAs(SourceLocation)
  KeywordSatisfies(SourceLocation)
  KeywordExtends(SourceLocation)
  KeywordImplements(SourceLocation)
  KeywordYield(SourceLocation)
  KeywordIn(SourceLocation)
  KeywordOf(SourceLocation)
  KeywordInstanceOf(SourceLocation)
  KeywordTypeOf(SourceLocation)
  KeywordDelete(SourceLocation)
  KeywordDebugger(SourceLocation)

  // Operators
  // Arithmetic
  Plus(SourceLocation) // +
  Minus(SourceLocation) // -
  Star(SourceLocation) // *
  Slash(SourceLocation) // /
  Percent(SourceLocation) // %
  StarStar(SourceLocation) // **

  // Comparison
  LessThan(SourceLocation) // <
  GreaterThan(SourceLocation) // >
  LessThanEquals(SourceLocation) // <=
  GreaterThanEquals(SourceLocation) // >=
  EqualsEquals(SourceLocation) // ==
  ExclamationEquals(SourceLocation) // !=
  EqualsEqualsEquals(SourceLocation) // ===
  ExclamationEqualsEquals(SourceLocation) // !==

  // Logical
  AmpersandAmpersand(SourceLocation) // &&
  BarBar(SourceLocation) // ||
  Exclamation(SourceLocation) // !
  QuestionQuestion(SourceLocation) // ??

  // Bitwise
  Ampersand(SourceLocation) // &
  Bar(SourceLocation) // |
  Caret(SourceLocation) // ^
  Tilde(SourceLocation) // ~
  LessThanLessThan(SourceLocation) // <<
  GreaterThanGreaterThan(SourceLocation) // >>
  GreaterThanGreaterThanGreaterThan(SourceLocation) // >>>

  // Assignment
  Equals(SourceLocation) // =
  PlusEquals(SourceLocation) // +=
  MinusEquals(SourceLocation) // -=
  StarEquals(SourceLocation) // *=
  SlashEquals(SourceLocation) // /=
  PercentEquals(SourceLocation) // %=
  AmpersandEquals(SourceLocation) // &=
  BarEquals(SourceLocation) // |=
  CaretEquals(SourceLocation) // ^=
  StarStarEquals(SourceLocation) // **=
  LessThanLessThanEquals(SourceLocation) // <<=
  GreaterThanGreaterThanEquals(SourceLocation) // >>=
  GreaterThanGreaterThanGreaterThanEquals(SourceLocation) // >>>=
  AmpersandAmpersandEquals(SourceLocation) // &&=
  BarBarEquals(SourceLocation) // ||=
  QuestionQuestionEquals(SourceLocation) // ??=

  // Increment/Decrement
  PlusPlus(SourceLocation) // ++
  MinusMinus(SourceLocation) // --

  // Other
  Question(SourceLocation) // ?
  Colon(SourceLocation) // :
  QuestionDot(SourceLocation) // ?.
  ExclamationDot(SourceLocation) // !. (non-null assertion)
  Arrow(SourceLocation) // =>
  Dot(SourceLocation) // .
  DotDotDot(SourceLocation) // ...

  // Punctuation
  OpenBrace(SourceLocation) // {
  CloseBrace(SourceLocation) // }
  OpenParen(SourceLocation) // (
  CloseParen(SourceLocation) // )
  OpenBracket(SourceLocation) // [
  CloseBracket(SourceLocation) // ]
  Semicolon(SourceLocation) // ;
  Comma(SourceLocation) // ,

  // Template
  TemplateHead(String, SourceLocation) // `...${
  TemplateMiddle(String, SourceLocation) // }...${
  TemplateTail(String, SourceLocation) // }...`

  // JSX
  LessThanSlash(SourceLocation) // </
  SlashGreaterThan(SourceLocation) // />

  // Decorator
  At(SourceLocation) // @

  // Special
  EOF(SourceLocation)
  Unknown(String, SourceLocation)
} derive(Show, Eq)

///|
/// Source location for error reporting
pub struct SourceLocation {
  file_path : String
  start : Position
  end : Position
} derive(Show, Eq)

///|
/// Position in source file
#valtype
pub struct Position {
  line : Int
  column : Int
  offset : Int
} derive(Show, Eq)

///|
/// Get the source location from a token
pub fn Token::location(self : Token) -> SourceLocation {
  match self {
    NumericLiteral(_, loc)
    | StringLiteral(_, loc)
    | TemplateLiteral(_, loc)
    | RegExpLiteral(_, loc)
    | Identifier(_, loc)
    | KeywordAny(loc)
    | KeywordBoolean(loc)
    | KeywordNumber(loc)
    | KeywordString(loc)
    | KeywordSymbol(loc)
    | KeywordObject(loc)
    | KeywordVoid(loc)
    | KeywordUnknown(loc)
    | KeywordNever(loc)
    | KeywordUndefined(loc)
    | KeywordNull(loc)
    | KeywordLet(loc)
    | KeywordConst(loc)
    | KeywordVar(loc)
    | KeywordFunction(loc)
    | KeywordClass(loc)
    | KeywordInterface(loc)
    | KeywordEnum(loc)
    | KeywordType(loc)
    | KeywordNamespace(loc)
    | KeywordModule(loc)
    | KeywordIf(loc)
    | KeywordElse(loc)
    | KeywordSwitch(loc)
    | KeywordCase(loc)
    | KeywordDefault(loc)
    | KeywordFor(loc)
    | KeywordWhile(loc)
    | KeywordDo(loc)
    | KeywordBreak(loc)
    | KeywordContinue(loc)
    | KeywordReturn(loc)
    | KeywordThrow(loc)
    | KeywordTry(loc)
    | KeywordCatch(loc)
    | KeywordFinally(loc)
    | KeywordPublic(loc)
    | KeywordPrivate(loc)
    | KeywordProtected(loc)
    | KeywordStatic(loc)
    | KeywordReadonly(loc)
    | KeywordAbstract(loc)
    | KeywordAsync(loc)
    | KeywordAwait(loc)
    | KeywordDeclare(loc)
    | KeywordNew(loc)
    | KeywordThis(loc)
    | KeywordSuper(loc)
    | KeywordImport(loc)
    | KeywordExport(loc)
    | KeywordFrom(loc)
    | KeywordAs(loc)
    | KeywordSatisfies(loc)
    | KeywordExtends(loc)
    | KeywordImplements(loc)
    | KeywordYield(loc)
    | KeywordIn(loc)
    | KeywordOf(loc)
    | KeywordInstanceOf(loc)
    | KeywordTypeOf(loc)
    | KeywordDelete(loc)
    | KeywordDebugger(loc)
    | Plus(loc)
    | Minus(loc)
    | Star(loc)
    | Slash(loc)
    | Percent(loc)
    | StarStar(loc)
    | LessThan(loc)
    | GreaterThan(loc)
    | LessThanEquals(loc)
    | GreaterThanEquals(loc)
    | EqualsEquals(loc)
    | ExclamationEquals(loc)
    | EqualsEqualsEquals(loc)
    | ExclamationEqualsEquals(loc)
    | AmpersandAmpersand(loc)
    | BarBar(loc)
    | Exclamation(loc)
    | QuestionQuestion(loc)
    | Ampersand(loc)
    | Bar(loc)
    | Caret(loc)
    | Tilde(loc)
    | LessThanLessThan(loc)
    | GreaterThanGreaterThan(loc)
    | GreaterThanGreaterThanGreaterThan(loc)
    | Equals(loc)
    | PlusEquals(loc)
    | MinusEquals(loc)
    | StarEquals(loc)
    | SlashEquals(loc)
    | PercentEquals(loc)
    | AmpersandEquals(loc)
    | BarEquals(loc)
    | CaretEquals(loc)
    | StarStarEquals(loc)
    | LessThanLessThanEquals(loc)
    | GreaterThanGreaterThanEquals(loc)
    | GreaterThanGreaterThanGreaterThanEquals(loc)
    | AmpersandAmpersandEquals(loc)
    | BarBarEquals(loc)
    | QuestionQuestionEquals(loc)
    | PlusPlus(loc)
    | MinusMinus(loc)
    | Question(loc)
    | Colon(loc)
    | QuestionDot(loc)
    | ExclamationDot(loc)
    | Arrow(loc)
    | Dot(loc)
    | DotDotDot(loc)
    | OpenBrace(loc)
    | CloseBrace(loc)
    | OpenParen(loc)
    | CloseParen(loc)
    | OpenBracket(loc)
    | CloseBracket(loc)
    | Semicolon(loc)
    | Comma(loc)
    | TemplateHead(_, loc)
    | TemplateMiddle(_, loc)
    | TemplateTail(_, loc)
    | LessThanSlash(loc)
    | SlashGreaterThan(loc)
    | At(loc)
    | EOF(loc)
    | Unknown(_, loc) => loc
  }
}

///|
/// Check if token is a keyword
pub fn Token::is_keyword(self : Token) -> Bool {
  match self {
    KeywordAny(_)
    | KeywordBoolean(_)
    | KeywordNumber(_)
    | KeywordString(_)
    | KeywordSymbol(_)
    | KeywordObject(_)
    | KeywordVoid(_)
    | KeywordUnknown(_)
    | KeywordNever(_)
    | KeywordUndefined(_)
    | KeywordNull(_)
    | KeywordLet(_)
    | KeywordConst(_)
    | KeywordVar(_)
    | KeywordFunction(_)
    | KeywordClass(_)
    | KeywordInterface(_)
    | KeywordEnum(_)
    | KeywordType(_)
    | KeywordNamespace(_)
    | KeywordModule(_)
    | KeywordIf(_)
    | KeywordElse(_)
    | KeywordSwitch(_)
    | KeywordCase(_)
    | KeywordDefault(_)
    | KeywordFor(_)
    | KeywordWhile(_)
    | KeywordDo(_)
    | KeywordBreak(_)
    | KeywordContinue(_)
    | KeywordReturn(_)
    | KeywordThrow(_)
    | KeywordTry(_)
    | KeywordCatch(_)
    | KeywordFinally(_)
    | KeywordPublic(_)
    | KeywordPrivate(_)
    | KeywordProtected(_)
    | KeywordStatic(_)
    | KeywordReadonly(_)
    | KeywordAbstract(_)
    | KeywordAsync(_)
    | KeywordAwait(_)
    | KeywordDeclare(_)
    | KeywordNew(_)
    | KeywordThis(_)
    | KeywordSuper(_)
    | KeywordImport(_)
    | KeywordExport(_)
    | KeywordFrom(_)
    | KeywordAs(_)
    | KeywordSatisfies(_)
    | KeywordExtends(_)
    | KeywordImplements(_)
    | KeywordYield(_)
    | KeywordIn(_)
    | KeywordOf(_)
    | KeywordInstanceOf(_)
    | KeywordTypeOf(_)
    | KeywordDelete(_)
    | KeywordDebugger(_) => true
    _ => false
  }
}

///|
/// Helper to create a position
pub fn Position::new(line : Int, column : Int, offset : Int) -> Position {
  { line, column, offset }
}

///|
/// Helper to create a source location
pub fn SourceLocation::new(
  file_path : String,
  start : Position,
  end : Position,
) -> SourceLocation {
  { file_path, start, end }
}

///|
/// Combine two source locations (for spanning)
pub fn SourceLocation::span(
  start : SourceLocation,
  end : SourceLocation,
) -> SourceLocation {
  { file_path: start.file_path, start: start.start, end: end.end }
}
