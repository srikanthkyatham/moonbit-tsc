// Parser for TypeScript
// Converts token stream into Abstract Syntax Tree (AST)
// Uses recursive descent parsing strategy

///|
/// Maximum recursion depth for expression parsing
/// Prevents stack overflow on deeply nested expressions
let max_expression_depth : Int = 1000

///|
/// Maximum errors before giving up
let max_errors : Int = 100

///|
/// Parser context flags for handling ambiguous constructs
pub struct ParserContext {
  /// Allow 'in' operator (false in for-in initializer)
  allow_in : Bool
  /// Allow 'yield' as identifier (false in generators)
  allow_yield : Bool
  /// Allow 'await' as identifier (false in async functions)
  allow_await : Bool
  /// Currently parsing type context
  in_type_context : Bool
  /// Currently parsing expression context
  in_expression_context : Bool
  /// Currently in strict mode
  strict_mode : Bool
  /// Currently parsing JSX
  in_jsx : Bool
  /// Currently parsing decorator
  in_decorator : Bool
  /// Disallow comma operator
  disallow_comma : Bool
  /// In conditional expression (for : vs ? disambiguation)
  in_conditional : Bool
  /// Currently inside a function body (for return statement validation)
  in_function : Bool
} derive(Show)

///|
/// Default parser context
pub fn ParserContext::default() -> ParserContext {
  {
    allow_in: true,
    allow_yield: true,
    allow_await: false,
    in_type_context: false,
    in_expression_context: false,
    strict_mode: false,
    in_jsx: false,
    in_decorator: false,
    disallow_comma: false,
    in_conditional: false,
    in_function: false,
  }
}

///|
/// Parser state
pub struct Parser {
  tokens : Array[Token]
  position : Int
  diagnostics : Array[Diagnostic]
  depth : Int // Current recursion depth for expression parsing
  context : ParserContext
  /// Stack of saved contexts for restoration
  context_stack : Array[ParserContext]
} derive(Show)

///|
/// Parser result type
pub type ParseResult[T] = Result[T, Array[Diagnostic]]

///|
/// Create a new parser
pub fn Parser::new(tokens : Array[Token]) -> Parser {
  {
    tokens,
    position: 0,
    diagnostics: [],
    depth: 0,
    context: ParserContext::default(),
    context_stack: [],
  }
}

///|
/// Save current context and push new one
fn push_context(parser : Parser, new_context : ParserContext) -> Parser {
  let stack = parser.context_stack.copy()
  stack.push(parser.context)
  { ..parser, context: new_context, context_stack: stack }
}

///|
/// Restore previous context
fn pop_context(parser : Parser) -> Parser {
  if parser.context_stack.is_empty() {
    parser
  } else {
    let stack = parser.context_stack.copy()
    match stack.pop() {
      Some(prev_context) =>
        { ..parser, context: prev_context, context_stack: stack }
      None => parser
    }
  }
}

///|
/// Modify context temporarily
fn with_context(
  parser : Parser,
  modifier : (ParserContext) -> ParserContext,
) -> Parser {
  { ..parser, context: modifier(parser.context) }
}

///|
/// Add error with limit check
fn add_error_checked(
  parser : Parser,
  message : String,
  location : SourceLocation,
  code : Int,
) -> Parser {
  if parser.diagnostics.length() >= max_errors {
    parser // Stop adding errors
  } else {
    let diagnostic = Diagnostic::error(message, location, code)
    let diagnostics = parser.diagnostics
    diagnostics.push(diagnostic)
    { ..parser, diagnostics, }
  }
}

// ============================================================================
// Enhanced Error Recovery
// ============================================================================

///|
/// Parser error codes
/// Aligned with TypeScript's official diagnostic codes where applicable
pub enum ParserErrorCode {
  // ============================================================================
  // Expected Token Errors (all use TS1005: "{0} expected")
  // These map to TypeScript's TS1005 generic expected token error
  // ============================================================================
  ExpectedSemicolon // TS1005: ';' expected
  ExpectedColon // TS1005: ':' expected
  ExpectedOpenParen // TS1005: '(' expected
  ExpectedCloseParen // TS1005: ')' expected
  ExpectedOpenBrace // TS1005: '{' expected
  ExpectedCloseBrace // TS1005: '}' expected
  ExpectedCloseBracket // TS1005: ']' expected
  ExpectedFunctionKeyword // TS1005: 'function' expected
  ExpectedClassKeyword // TS1005: 'class' expected
  ExpectedEquals // TS1005: '=' expected

  // ============================================================================
  // JSX Errors (TS17xxx)
  // ============================================================================
  JSXClosingTagMismatch // TS17004: Expected corresponding JSX closing tag
  JSXExpectedClosingTag // TS17008: JSX element has no corresponding closing tag
  JSXExpectedAttributeValue // TS17001: JSX attribute expected

  // ============================================================================
  // JSON Errors
  // ============================================================================
  JSONExpectedPropertyName // TS1005: Property name expected
  JSONExpectedValue // TS1005: Value expected
  JSONTrailingComma // TS1009: Trailing comma not allowed

  // ============================================================================
  // Critical Parser Errors (TS1000-1185)
  // These are official TypeScript error codes for parser/syntax errors
  // ============================================================================

  // Identifier errors
  IdentifierExpected // TS1003

  // String/Literal errors
  UnterminatedStringLiteral // TS1002
  UnterminatedTemplateLiteral // TS1160
  UnterminatedRegexLiteral // TS1161

  // Trailing comma
  TrailingCommaNotAllowed // TS1009

  // Rest parameter errors
  RestParameterMustBeLast // TS1014
  RequiredParamAfterOptional // TS1016
  RestParameterCannotBeOptional // TS1048
  RestParameterCannotHaveInitializer // TS1049

  // Ambient context errors
  StatementsNotAllowedInAmbient // TS1036
  DeclareInAmbientContext // TS1038
  InitializerNotAllowedInAmbient // TS1039
  AmbientEnumInitializerMustBeConstant // TS1066

  // Modifier errors
  AsyncModifierNotAllowed // TS1042
  ModifierCannotAppearOnClassElement(String) // TS1044
  ModifierCannotAppearOnConstructor(String) // TS1089
  ModifiersNotAllowedHere // TS1184
  ParameterPropertyBindingPattern // TS1187: A parameter property may not be declared using a binding pattern

  // Constructor errors
  TypeParamsOnConstructor // TS1092

  // Accessor errors
  SetAccessorCannotHaveReturnType // TS1093
  GetAccessorCannotHaveParams // TS1094
  SetAccessorMustHaveOneParam // TS1095

  // Statement context errors
  ReturnOutsideFunction // TS1108
  ExpressionExpected // TS1109
  TypeExpected // TS1110
  UnexpectedEndOfText // TS1126
  DeclarationOrStatementExpected // TS1128
  PropertyOrSignatureExpected // TS1131
  StringLiteralExpected // TS1141
  LineBreakNotPermitted // TS1142

  // Declaration errors
  ConstDeclarationMustBeInitialized // TS1155
  DestructuringDeclarationMustHaveInitializer // TS1182: A destructuring declaration must have an initializer

  // Merge conflict
  MergeConflictMarker // TS1185

  // Decorator errors
  DecoratorsNotValidHere // TS1206
  ExperimentalDecoratorsWarning // TS1219
  UnableToResolveClassDecorator // TS1239
  UnableToResolveParameterDecorator // TS1240
  UnableToResolvePropertyDecorator // TS1241
  DecoratorReturnTypeMustBeAssignable // TS1270

  // Enum errors
  EnumMemberExpectedCommaOrEquals // TS1357: An enum member name must be followed by a ',', '=', or '}'
  NumericEnumMemberName // TS2452: An enum member cannot have a numeric name

  // Module/Import errors
  ModuleHasNoDefaultExport(String) // TS1192
  ImportAssignmentNotAllowedInESModules // TS1202
  IsolatedModulesScriptFile(String) // TS1208
  IsolatedModulesConstEnum(String) // TS1209
  AmbientConstEnumsNotAllowedWithIsolatedModules // TS1211
  ExportAssignmentNotAllowedWithModuleExports // TS1218
  TypeAssertionNotAllowedInExponentiation // TS1227
  ImportAliasCannotReferenceTypeExport // TS1232
  DeleteCannotBeCalledOnIdentifier // TS1243
  ClassMemberCannotHaveConst // TS1248
  ConstInitializerMustBeLiteral // TS1254
  AwaitOnlyAllowedAtTopLevel // TS1278
  EqualsOnlyInDestructuring // TS1312
  AwaitNotAllowedInParameterInitializer // TS1313
  DynamicImportSecondArgOnlyEsnext // TS1323
  TopLevelAwaitRequiresEsnext // TS1378
  TopLevelForAwaitNotSupported // TS1431
  DecoratorsNotAfterExport // TS1432
  DecoratorReturnTypeNotAssignable(String) // TS1433
  AwaitUsingOnlyInAsyncFunctions // TS1437
  ImportPathNotStringLiteral // TS1440
  ModifierOnlyInTypeScriptFiles(String) // TS1450
  TypeAnnotationsOnlyInTypeScriptFiles // TS1451
  VariableDeclarationExpected // TS1462
  UsingDeclarationsRequireAwait // TS1463
  UsingDeclarationNotInParameter // TS1484
  ESMImportExportNotValid // TS1486
  LineTerminatorBeforeArrow // TS1200: Line terminator not permitted before arrow
  InvalidUseOfInStrictMode(String) // TS1210: Invalid use of '{0}'. Class definitions are automatically in strict mode.
  // Note: TS2xxx (type checker) and TS4xxx (build/emit) errors are in
  // DiagnosticCode enum in symbol.mbt, not in ParserErrorCode
} derive(Show, Eq)

///|
/// Get numeric code for error
/// Returns official TypeScript diagnostic codes where applicable
pub fn ParserErrorCode::to_int(self : ParserErrorCode) -> Int {
  match self {
    // ============================================================================
    // Expected Token Errors (TS1005)
    // ============================================================================
    ExpectedSemicolon => 1005
    ExpectedColon => 1005
    ExpectedOpenParen => 1005
    ExpectedCloseParen => 1005
    ExpectedOpenBrace => 1005
    ExpectedCloseBrace => 1005
    ExpectedCloseBracket => 1005
    ExpectedFunctionKeyword => 1005
    ExpectedClassKeyword => 1005
    ExpectedEquals => 1005

    // JSX Errors (TS17xxx)
    JSXClosingTagMismatch => 17004
    JSXExpectedClosingTag => 17008
    JSXExpectedAttributeValue => 17001

    // JSON Errors
    JSONExpectedPropertyName => 1005 // Property name expected
    JSONExpectedValue => 1005 // Value expected
    JSONTrailingComma => 1009 // Trailing comma not allowed

    // ============================================================================
    // Critical Parser Errors - Official TypeScript Error Codes
    // ============================================================================

    // Identifier errors
    IdentifierExpected => 1003 // TS1003: Identifier expected

    // String/Literal errors
    UnterminatedStringLiteral => 1002 // TS1002: Unterminated string literal
    UnterminatedTemplateLiteral => 1160 // TS1160: Unterminated template literal
    UnterminatedRegexLiteral => 1161 // TS1161: Unterminated regular expression literal

    // Trailing comma
    TrailingCommaNotAllowed => 1009 // TS1009: Trailing comma not allowed

    // Rest parameter errors
    RestParameterMustBeLast => 1014 // TS1014: A rest parameter must be last in a parameter list
    RequiredParamAfterOptional => 1016 // TS1016: A required parameter cannot follow an optional parameter
    RestParameterCannotBeOptional => 1048 // TS1048: A rest parameter cannot be optional
    RestParameterCannotHaveInitializer => 1049 // TS1049: A rest parameter cannot have an initializer

    // Ambient context errors
    StatementsNotAllowedInAmbient => 1036 // TS1036: Statements are not allowed in ambient contexts
    DeclareInAmbientContext => 1038 // TS1038: A 'declare' modifier cannot be used in an already ambient context
    InitializerNotAllowedInAmbient => 1039 // TS1039: Initializers are not allowed in ambient contexts
    AmbientEnumInitializerMustBeConstant => 1066 // TS1066: In ambient enum declarations member initializer must be constant

    // Modifier errors
    AsyncModifierNotAllowed => 1042 // TS1042: 'async' modifier cannot be used here
    ModifierCannotAppearOnClassElement(_) => 1044 // TS1044: '{0}' modifier cannot appear on a class element
    ModifierCannotAppearOnConstructor(_) => 1089 // TS1089: '{0}' modifier cannot appear on a constructor declaration
    ModifiersNotAllowedHere => 1184 // TS1184: Modifiers cannot appear here
    ParameterPropertyBindingPattern => 1187 // TS1187: A parameter property may not be declared using a binding pattern

    // Constructor errors
    TypeParamsOnConstructor => 1092 // TS1092: Type parameters cannot appear on a constructor declaration

    // Accessor errors
    SetAccessorCannotHaveReturnType => 1093 // TS1093: A 'set' accessor cannot have a return type annotation
    GetAccessorCannotHaveParams => 1094 // TS1094: A 'get' accessor cannot have parameters
    SetAccessorMustHaveOneParam => 1095 // TS1095: A 'set' accessor must have exactly one parameter

    // Statement context errors
    ReturnOutsideFunction => 1108 // TS1108: A 'return' statement can only be used within a function body
    ExpressionExpected => 1109 // TS1109: Expression expected
    TypeExpected => 1110 // TS1110: Type expected
    UnexpectedEndOfText => 1126 // TS1126: Unexpected end of text
    DeclarationOrStatementExpected => 1128 // TS1128: Declaration or statement expected
    PropertyOrSignatureExpected => 1131 // TS1131: Property or signature expected
    StringLiteralExpected => 1141 // TS1141: String literal expected
    LineBreakNotPermitted => 1142 // TS1142: Line break not permitted here

    // Declaration errors
    ConstDeclarationMustBeInitialized => 1155 // TS1155: 'const' declarations must be initialized
    DestructuringDeclarationMustHaveInitializer => 1182 // TS1182: A destructuring declaration must have an initializer

    // Merge conflict
    MergeConflictMarker => 1185 // TS1185: Merge conflict marker encountered

    // Decorator errors
    DecoratorsNotValidHere => 1206 // TS1206: Decorators are not valid here
    ExperimentalDecoratorsWarning => 1219 // TS1219: Experimental support for decorators
    UnableToResolveClassDecorator => 1239 // TS1239: Unable to resolve signature of class decorator
    UnableToResolveParameterDecorator => 1240 // TS1240: Unable to resolve signature of parameter decorator
    UnableToResolvePropertyDecorator => 1241 // TS1241: Unable to resolve signature of property decorator
    DecoratorReturnTypeMustBeAssignable => 1270 // TS1270: Decorator function return type must be assignable

    // Enum errors
    EnumMemberExpectedCommaOrEquals => 1357 // TS1357: An enum member name must be followed by a ',', '=', or '}'
    NumericEnumMemberName => 2452 // TS2452: An enum member cannot have a numeric name

    // Module/Import errors
    ModuleHasNoDefaultExport(_) => 1192
    ImportAssignmentNotAllowedInESModules => 1202
    IsolatedModulesScriptFile(_) => 1208
    IsolatedModulesConstEnum(_) => 1209
    AmbientConstEnumsNotAllowedWithIsolatedModules => 1211
    ExportAssignmentNotAllowedWithModuleExports => 1218
    TypeAssertionNotAllowedInExponentiation => 1227
    ImportAliasCannotReferenceTypeExport => 1232
    DeleteCannotBeCalledOnIdentifier => 1243
    ClassMemberCannotHaveConst => 1248
    ConstInitializerMustBeLiteral => 1254
    AwaitOnlyAllowedAtTopLevel => 1278
    EqualsOnlyInDestructuring => 1312
    AwaitNotAllowedInParameterInitializer => 1313
    DynamicImportSecondArgOnlyEsnext => 1323
    TopLevelAwaitRequiresEsnext => 1378
    TopLevelForAwaitNotSupported => 1431
    DecoratorsNotAfterExport => 1432
    DecoratorReturnTypeNotAssignable(_) => 1433
    AwaitUsingOnlyInAsyncFunctions => 1437
    ImportPathNotStringLiteral => 1440
    ModifierOnlyInTypeScriptFiles(_) => 1450
    TypeAnnotationsOnlyInTypeScriptFiles => 1451
    VariableDeclarationExpected => 1462
    UsingDeclarationsRequireAwait => 1463
    UsingDeclarationNotInParameter => 1484
    ESMImportExportNotValid => 1486
    LineTerminatorBeforeArrow => 1200
    InvalidUseOfInStrictMode(_) => 1210
  }
}

///|
/// Get the human-readable error message for this error code
/// Messages are aligned with official TypeScript diagnostic messages
pub fn ParserErrorCode::to_message(self : ParserErrorCode) -> String {
  match self {
    // ============================================================================
    // Expected Token Errors (TS1005)
    // ============================================================================
    ExpectedSemicolon => "';' expected."
    ExpectedColon => "':' expected."
    ExpectedOpenParen => "'(' expected."
    ExpectedCloseParen => "')' expected."
    ExpectedOpenBrace => "'{' expected."
    ExpectedCloseBrace => "'}' expected."
    ExpectedCloseBracket => "']' expected."
    ExpectedFunctionKeyword => "'function' expected."
    ExpectedClassKeyword => "'class' expected."
    ExpectedEquals => "'=' expected."

    // JSX Errors
    JSXClosingTagMismatch => "Expected corresponding JSX closing tag."
    JSXExpectedClosingTag => "JSX element has no corresponding closing tag."
    JSXExpectedAttributeValue => "JSX attribute expected."

    // JSON Errors
    JSONExpectedPropertyName => "Property name expected."
    JSONExpectedValue => "Value expected."
    JSONTrailingComma => "Trailing comma not allowed."

    // ============================================================================
    // Critical Parser Errors - Official TypeScript Error Messages
    // ============================================================================

    // Identifier errors
    IdentifierExpected => "Identifier expected."

    // String/Literal errors
    UnterminatedStringLiteral => "Unterminated string literal."
    UnterminatedTemplateLiteral => "Unterminated template literal."
    UnterminatedRegexLiteral => "Unterminated regular expression literal."

    // Trailing comma
    TrailingCommaNotAllowed => "Trailing comma not allowed."

    // Rest parameter errors
    RestParameterMustBeLast =>
      "A rest parameter must be last in a parameter list."
    RequiredParamAfterOptional =>
      "A required parameter cannot follow an optional parameter."
    RestParameterCannotBeOptional => "A rest parameter cannot be optional."
    RestParameterCannotHaveInitializer =>
      "A rest parameter cannot have an initializer."

    // Ambient context errors
    StatementsNotAllowedInAmbient =>
      "Statements are not allowed in ambient contexts."
    DeclareInAmbientContext =>
      "A 'declare' modifier cannot be used in an already ambient context."
    InitializerNotAllowedInAmbient =>
      "Initializers are not allowed in ambient contexts."
    AmbientEnumInitializerMustBeConstant =>
      "In ambient enum declarations member initializer must be constant expression."

    // Modifier errors
    AsyncModifierNotAllowed => "'async' modifier cannot be used here."
    ModifierCannotAppearOnClassElement(modifier) =>
      "'" + modifier + "' modifier cannot appear on a class element."
    ModifierCannotAppearOnConstructor(modifier) =>
      "'" + modifier + "' modifier cannot appear on a constructor declaration."
    ModifiersNotAllowedHere => "Modifiers cannot appear here."
    ParameterPropertyBindingPattern =>
      "A parameter property may not be declared using a binding pattern."

    // Constructor errors
    TypeParamsOnConstructor =>
      "Type parameters cannot appear on a constructor declaration."

    // Accessor errors
    SetAccessorCannotHaveReturnType =>
      "A 'set' accessor cannot have a return type annotation."
    GetAccessorCannotHaveParams => "An accessor cannot have parameters."
    SetAccessorMustHaveOneParam =>
      "A 'set' accessor must have exactly one parameter."

    // Statement context errors
    ReturnOutsideFunction =>
      "A 'return' statement can only be used within a function body."
    ExpressionExpected => "Expression expected."
    TypeExpected => "Type expected."
    UnexpectedEndOfText => "Unexpected end of text."
    DeclarationOrStatementExpected => "Declaration or statement expected."
    PropertyOrSignatureExpected => "Property or signature expected."
    StringLiteralExpected => "String literal expected."
    LineBreakNotPermitted => "Line break not permitted here."

    // Declaration errors
    ConstDeclarationMustBeInitialized =>
      "'const' declarations must be initialized."
    DestructuringDeclarationMustHaveInitializer =>
      "A destructuring declaration must have an initializer."

    // Merge conflict
    MergeConflictMarker => "Merge conflict marker encountered."

    // Decorator errors
    DecoratorsNotValidHere => "Decorators are not valid here."
    ExperimentalDecoratorsWarning =>
      "Experimental support for decorators is a feature that is subject to change in a future release."
    UnableToResolveClassDecorator =>
      "Unable to resolve signature of class decorator when called as an expression."
    UnableToResolveParameterDecorator =>
      "Unable to resolve signature of parameter decorator when called as an expression."
    UnableToResolvePropertyDecorator =>
      "Unable to resolve signature of property decorator when called as an expression."
    DecoratorReturnTypeMustBeAssignable =>
      "Decorator function return type is not assignable to type of the decorated target."

    // Enum errors
    EnumMemberExpectedCommaOrEquals =>
      "An enum member name must be followed by a ',', '=', or '}'."
    NumericEnumMemberName => "An enum member cannot have a numeric name."

    // Module/Import errors
    ModuleHasNoDefaultExport(module_name) =>
      "Module '\{module_name}' has no default export."
    ImportAssignmentNotAllowedInESModules =>
      "Import assignment cannot be used when targeting ECMAScript modules. Consider using 'import * as ns from \"mod\"', 'import {a} from \"mod\"', 'import d from \"mod\"', or another module format instead."
    IsolatedModulesScriptFile(name) =>
      "'\{name}' cannot be compiled under '--isolatedModules' because it is considered a global script file. Add an import, export, or an empty 'export {}' statement to make it a module."
    IsolatedModulesConstEnum(name) =>
      "'\{name}' cannot be compiled under '--isolatedModules' because it is considered a global script file. Add an import, export, or an empty 'export {}' statement to make it a module."
    AmbientConstEnumsNotAllowedWithIsolatedModules =>
      "Ambient const enums are not allowed when the '--isolatedModules' flag is provided."
    ExportAssignmentNotAllowedWithModuleExports =>
      "An export assignment cannot be used in a module with other exported elements."
    TypeAssertionNotAllowedInExponentiation =>
      "A type assertion expression is not allowed in the left-hand side of an exponentiation expression. Consider enclosing the expression in parentheses."
    ImportAliasCannotReferenceTypeExport =>
      "An import alias cannot reference a declaration that was exported using 'export type'."
    DeleteCannotBeCalledOnIdentifier =>
      "'delete' cannot be called on an identifier in strict mode."
    ClassMemberCannotHaveConst =>
      "A class member cannot have the 'const' keyword."
    ConstInitializerMustBeLiteral =>
      "A 'const' initializer in an ambient context must be a string or numeric literal or literal enum reference."
    AwaitOnlyAllowedAtTopLevel =>
      "'await' expressions are only allowed at the top level of a file when that file is a module, but this file has no imports or exports. Consider adding an empty 'export {}' to make this file a module."
    EqualsOnlyInDestructuring =>
      "'=' can only be used in an object literal property inside a destructuring assignment."
    AwaitNotAllowedInParameterInitializer =>
      "'await' expressions cannot be used in a parameter initializer."
    DynamicImportSecondArgOnlyEsnext =>
      "Dynamic imports only support a second argument when the '--module' option is set to 'esnext', 'node16', or 'nodenext'."
    TopLevelAwaitRequiresEsnext =>
      "Top-level 'await' expressions are only allowed when the 'module' option is set to 'es2022', 'esnext', 'system', 'node16', or 'nodenext', and the 'target' option is set to 'es2017' or higher."
    TopLevelForAwaitNotSupported =>
      "Top-level 'for await' statements are only allowed when the 'module' option is set to 'es2022', 'esnext', 'system', 'node16', or 'nodenext', and the 'target' option is set to 'es2017' or higher."
    DecoratorsNotAfterExport =>
      "Decorators must precede the name and all keywords of property declarations."
    DecoratorReturnTypeNotAssignable(type_name) =>
      "Decorator function return type '\{type_name}' is not assignable to type of decorated declaration."
    AwaitUsingOnlyInAsyncFunctions =>
      "'await using' statements are only allowed within async functions and at the top levels of modules."
    ImportPathNotStringLiteral => "The 'import' path must be a string literal."
    ModifierOnlyInTypeScriptFiles(modifier) =>
      "The '\{modifier}' modifier can only be used in TypeScript files."
    TypeAnnotationsOnlyInTypeScriptFiles =>
      "Type annotations can only be used in TypeScript files."
    VariableDeclarationExpected => "Variable declaration expected."
    UsingDeclarationsRequireAwait =>
      "'using' declarations may not have a binding pattern, and must have an initializer."
    UsingDeclarationNotInParameter =>
      "A 'using' declaration may not be declared in a parameter."
    ESMImportExportNotValid =>
      "This file has an import or export that cannot be used outside of ECMAScript modules."
    LineTerminatorBeforeArrow => "Line terminator not permitted before arrow."
    InvalidUseOfInStrictMode(name) =>
      "Invalid use of '\{name}'. Class definitions are automatically in strict mode."
  }
}

// ============================================================================
// Public test helper functions for ParserErrorCode
// These allow external tests to verify error codes without constructing enum variants
// ============================================================================

///|
/// Get the integer error code for a parser error by name
/// Used by external tests to verify error code mappings
pub fn get_parser_error_int(name : String) -> Int {
  get_parser_error_int_with_arg(name, None)
}

///|
/// Get the integer error code for a parser error by name with optional argument
pub fn get_parser_error_int_with_arg(name : String, arg : String?) -> Int {
  match name {
    "UnterminatedStringLiteral" => UnterminatedStringLiteral.to_int()
    "UnterminatedTemplateLiteral" => UnterminatedTemplateLiteral.to_int()
    "UnterminatedRegexLiteral" => UnterminatedRegexLiteral.to_int()
    "TrailingCommaNotAllowed" => TrailingCommaNotAllowed.to_int()
    "RestParameterMustBeLast" => RestParameterMustBeLast.to_int()
    "RequiredParamAfterOptional" => RequiredParamAfterOptional.to_int()
    "RestParameterCannotBeOptional" => RestParameterCannotBeOptional.to_int()
    "RestParameterCannotHaveInitializer" =>
      RestParameterCannotHaveInitializer.to_int()
    "StatementsNotAllowedInAmbient" => StatementsNotAllowedInAmbient.to_int()
    "DeclareInAmbientContext" => DeclareInAmbientContext.to_int()
    "InitializerNotAllowedInAmbient" => InitializerNotAllowedInAmbient.to_int()
    "AmbientEnumInitializerMustBeConstant" =>
      AmbientEnumInitializerMustBeConstant.to_int()
    "AsyncModifierNotAllowed" => AsyncModifierNotAllowed.to_int()
    "ModifierCannotAppearOnClassElement" =>
      ModifierCannotAppearOnClassElement(arg.unwrap_or("")).to_int()
    "ModifierCannotAppearOnConstructor" =>
      ModifierCannotAppearOnConstructor(arg.unwrap_or("")).to_int()
    "ModifiersNotAllowedHere" => ModifiersNotAllowedHere.to_int()
    "TypeParamsOnConstructor" => TypeParamsOnConstructor.to_int()
    "SetAccessorCannotHaveReturnType" =>
      SetAccessorCannotHaveReturnType.to_int()
    "GetAccessorCannotHaveParams" => GetAccessorCannotHaveParams.to_int()
    "SetAccessorMustHaveOneParam" => SetAccessorMustHaveOneParam.to_int()
    "ReturnOutsideFunction" => ReturnOutsideFunction.to_int()
    "TypeExpected" => TypeExpected.to_int()
    "DeclarationOrStatementExpected" => DeclarationOrStatementExpected.to_int()
    "PropertyOrSignatureExpected" => PropertyOrSignatureExpected.to_int()
    "StringLiteralExpected" => StringLiteralExpected.to_int()
    "LineBreakNotPermitted" => LineBreakNotPermitted.to_int()
    "ConstDeclarationMustBeInitialized" =>
      ConstDeclarationMustBeInitialized.to_int()
    "MergeConflictMarker" => MergeConflictMarker.to_int()
    // Decorator errors
    "DecoratorsNotValidHere" => DecoratorsNotValidHere.to_int()
    "ExperimentalDecoratorsWarning" => ExperimentalDecoratorsWarning.to_int()
    "UnableToResolveClassDecorator" => UnableToResolveClassDecorator.to_int()
    "UnableToResolveParameterDecorator" =>
      UnableToResolveParameterDecorator.to_int()
    "UnableToResolvePropertyDecorator" =>
      UnableToResolvePropertyDecorator.to_int()
    "DecoratorReturnTypeMustBeAssignable" =>
      DecoratorReturnTypeMustBeAssignable.to_int()
    // Module/Import errors
    "ModuleHasNoDefaultExport" =>
      ModuleHasNoDefaultExport(arg.unwrap_or("")).to_int()
    "ImportAssignmentNotAllowedInESModules" =>
      ImportAssignmentNotAllowedInESModules.to_int()
    "IsolatedModulesScriptFile" =>
      IsolatedModulesScriptFile(arg.unwrap_or("")).to_int()
    "IsolatedModulesConstEnum" =>
      IsolatedModulesConstEnum(arg.unwrap_or("")).to_int()
    "AmbientConstEnumsNotAllowedWithIsolatedModules" =>
      AmbientConstEnumsNotAllowedWithIsolatedModules.to_int()
    "ExportAssignmentNotAllowedWithModuleExports" =>
      ExportAssignmentNotAllowedWithModuleExports.to_int()
    "TypeAssertionNotAllowedInExponentiation" =>
      TypeAssertionNotAllowedInExponentiation.to_int()
    "ImportAliasCannotReferenceTypeExport" =>
      ImportAliasCannotReferenceTypeExport.to_int()
    "DeleteCannotBeCalledOnIdentifier" =>
      DeleteCannotBeCalledOnIdentifier.to_int()
    "ClassMemberCannotHaveConst" => ClassMemberCannotHaveConst.to_int()
    "ConstInitializerMustBeLiteral" => ConstInitializerMustBeLiteral.to_int()
    "AwaitOnlyAllowedAtTopLevel" => AwaitOnlyAllowedAtTopLevel.to_int()
    "EqualsOnlyInDestructuring" => EqualsOnlyInDestructuring.to_int()
    "AwaitNotAllowedInParameterInitializer" =>
      AwaitNotAllowedInParameterInitializer.to_int()
    "DynamicImportSecondArgOnlyEsnext" =>
      DynamicImportSecondArgOnlyEsnext.to_int()
    "TopLevelAwaitRequiresEsnext" => TopLevelAwaitRequiresEsnext.to_int()
    "TopLevelForAwaitNotSupported" => TopLevelForAwaitNotSupported.to_int()
    "DecoratorsNotAfterExport" => DecoratorsNotAfterExport.to_int()
    "DecoratorReturnTypeNotAssignable" =>
      DecoratorReturnTypeNotAssignable(arg.unwrap_or("")).to_int()
    "AwaitUsingOnlyInAsyncFunctions" => AwaitUsingOnlyInAsyncFunctions.to_int()
    "ImportPathNotStringLiteral" => ImportPathNotStringLiteral.to_int()
    "ModifierOnlyInTypeScriptFiles" =>
      ModifierOnlyInTypeScriptFiles(arg.unwrap_or("")).to_int()
    "TypeAnnotationsOnlyInTypeScriptFiles" =>
      TypeAnnotationsOnlyInTypeScriptFiles.to_int()
    "VariableDeclarationExpected" => VariableDeclarationExpected.to_int()
    "UsingDeclarationsRequireAwait" => UsingDeclarationsRequireAwait.to_int()
    "UsingDeclarationNotInParameter" => UsingDeclarationNotInParameter.to_int()
    "ESMImportExportNotValid" => ESMImportExportNotValid.to_int()
    "InvalidUseOfInStrictMode" =>
      InvalidUseOfInStrictMode(arg.unwrap_or("")).to_int()
    // Note: TS2xxx and TS4xxx codes are in DiagnosticCode in symbol.mbt
    _ => -1
  }
}

///|
/// Get the error message for a parser error by name
pub fn get_parser_error_message(name : String) -> String {
  get_parser_error_message_with_arg(name, None)
}

///|
/// Get the error message for a parser error by name with optional argument
pub fn get_parser_error_message_with_arg(
  name : String,
  arg : String?,
) -> String {
  match name {
    "UnterminatedStringLiteral" => UnterminatedStringLiteral.to_message()
    "UnterminatedTemplateLiteral" => UnterminatedTemplateLiteral.to_message()
    "UnterminatedRegexLiteral" => UnterminatedRegexLiteral.to_message()
    "TrailingCommaNotAllowed" => TrailingCommaNotAllowed.to_message()
    "RestParameterMustBeLast" => RestParameterMustBeLast.to_message()
    "RequiredParamAfterOptional" => RequiredParamAfterOptional.to_message()
    "RestParameterCannotBeOptional" =>
      RestParameterCannotBeOptional.to_message()
    "RestParameterCannotHaveInitializer" =>
      RestParameterCannotHaveInitializer.to_message()
    "StatementsNotAllowedInAmbient" =>
      StatementsNotAllowedInAmbient.to_message()
    "DeclareInAmbientContext" => DeclareInAmbientContext.to_message()
    "InitializerNotAllowedInAmbient" =>
      InitializerNotAllowedInAmbient.to_message()
    "AmbientEnumInitializerMustBeConstant" =>
      AmbientEnumInitializerMustBeConstant.to_message()
    "AsyncModifierNotAllowed" => AsyncModifierNotAllowed.to_message()
    "ModifierCannotAppearOnClassElement" =>
      ModifierCannotAppearOnClassElement(arg.unwrap_or("")).to_message()
    "ModifierCannotAppearOnConstructor" =>
      ModifierCannotAppearOnConstructor(arg.unwrap_or("")).to_message()
    "ModifiersNotAllowedHere" => ModifiersNotAllowedHere.to_message()
    "TypeParamsOnConstructor" => TypeParamsOnConstructor.to_message()
    "SetAccessorCannotHaveReturnType" =>
      SetAccessorCannotHaveReturnType.to_message()
    "GetAccessorCannotHaveParams" => GetAccessorCannotHaveParams.to_message()
    "SetAccessorMustHaveOneParam" => SetAccessorMustHaveOneParam.to_message()
    "ReturnOutsideFunction" => ReturnOutsideFunction.to_message()
    "TypeExpected" => TypeExpected.to_message()
    "DeclarationOrStatementExpected" =>
      DeclarationOrStatementExpected.to_message()
    "PropertyOrSignatureExpected" => PropertyOrSignatureExpected.to_message()
    "StringLiteralExpected" => StringLiteralExpected.to_message()
    "LineBreakNotPermitted" => LineBreakNotPermitted.to_message()
    "ConstDeclarationMustBeInitialized" =>
      ConstDeclarationMustBeInitialized.to_message()
    "MergeConflictMarker" => MergeConflictMarker.to_message()
    // Decorator errors
    "DecoratorsNotValidHere" => DecoratorsNotValidHere.to_message()
    "ExperimentalDecoratorsWarning" =>
      ExperimentalDecoratorsWarning.to_message()
    "UnableToResolveClassDecorator" =>
      UnableToResolveClassDecorator.to_message()
    "UnableToResolveParameterDecorator" =>
      UnableToResolveParameterDecorator.to_message()
    "UnableToResolvePropertyDecorator" =>
      UnableToResolvePropertyDecorator.to_message()
    "DecoratorReturnTypeMustBeAssignable" =>
      DecoratorReturnTypeMustBeAssignable.to_message()
    // Module/Import errors
    "ModuleHasNoDefaultExport" =>
      ModuleHasNoDefaultExport(arg.unwrap_or("")).to_message()
    "ImportAssignmentNotAllowedInESModules" =>
      ImportAssignmentNotAllowedInESModules.to_message()
    "IsolatedModulesScriptFile" =>
      IsolatedModulesScriptFile(arg.unwrap_or("")).to_message()
    "IsolatedModulesConstEnum" =>
      IsolatedModulesConstEnum(arg.unwrap_or("")).to_message()
    "AmbientConstEnumsNotAllowedWithIsolatedModules" =>
      AmbientConstEnumsNotAllowedWithIsolatedModules.to_message()
    "ExportAssignmentNotAllowedWithModuleExports" =>
      ExportAssignmentNotAllowedWithModuleExports.to_message()
    "TypeAssertionNotAllowedInExponentiation" =>
      TypeAssertionNotAllowedInExponentiation.to_message()
    "ImportAliasCannotReferenceTypeExport" =>
      ImportAliasCannotReferenceTypeExport.to_message()
    "DeleteCannotBeCalledOnIdentifier" =>
      DeleteCannotBeCalledOnIdentifier.to_message()
    "ClassMemberCannotHaveConst" => ClassMemberCannotHaveConst.to_message()
    "ConstInitializerMustBeLiteral" =>
      ConstInitializerMustBeLiteral.to_message()
    "AwaitOnlyAllowedAtTopLevel" => AwaitOnlyAllowedAtTopLevel.to_message()
    "EqualsOnlyInDestructuring" => EqualsOnlyInDestructuring.to_message()
    "AwaitNotAllowedInParameterInitializer" =>
      AwaitNotAllowedInParameterInitializer.to_message()
    "DynamicImportSecondArgOnlyEsnext" =>
      DynamicImportSecondArgOnlyEsnext.to_message()
    "TopLevelAwaitRequiresEsnext" => TopLevelAwaitRequiresEsnext.to_message()
    "TopLevelForAwaitNotSupported" => TopLevelForAwaitNotSupported.to_message()
    "DecoratorsNotAfterExport" => DecoratorsNotAfterExport.to_message()
    "DecoratorReturnTypeNotAssignable" =>
      DecoratorReturnTypeNotAssignable(arg.unwrap_or("")).to_message()
    "AwaitUsingOnlyInAsyncFunctions" =>
      AwaitUsingOnlyInAsyncFunctions.to_message()
    "ImportPathNotStringLiteral" => ImportPathNotStringLiteral.to_message()
    "ModifierOnlyInTypeScriptFiles" =>
      ModifierOnlyInTypeScriptFiles(arg.unwrap_or("")).to_message()
    "TypeAnnotationsOnlyInTypeScriptFiles" =>
      TypeAnnotationsOnlyInTypeScriptFiles.to_message()
    "VariableDeclarationExpected" => VariableDeclarationExpected.to_message()
    "UsingDeclarationsRequireAwait" =>
      UsingDeclarationsRequireAwait.to_message()
    "UsingDeclarationNotInParameter" =>
      UsingDeclarationNotInParameter.to_message()
    "ESMImportExportNotValid" => ESMImportExportNotValid.to_message()
    "InvalidUseOfInStrictMode" =>
      InvalidUseOfInStrictMode(arg.unwrap_or("")).to_message()
    // Note: TS2xxx and TS4xxx codes are in DiagnosticCode in symbol.mbt
    _ => "Unknown error"
  }
}

///|
/// Add error with specific error code
fn add_error_with_code(
  parser : Parser,
  message : String,
  location : SourceLocation,
  code : ParserErrorCode,
) -> Parser {
  add_error_checked(parser, message, location, code.to_int())
}

///|
/// Check if token is a statement start (synchronization point)
fn is_statement_start(token : Token) -> Bool {
  match token {
    KeywordLet(_)
    | KeywordConst(_)
    | KeywordVar(_)
    | KeywordFunction(_)
    | KeywordClass(_)
    | KeywordInterface(_)
    | KeywordType(_)
    | KeywordEnum(_)
    | KeywordIf(_)
    | KeywordFor(_)
    | KeywordWhile(_)
    | KeywordDo(_)
    | KeywordReturn(_)
    | KeywordThrow(_)
    | KeywordTry(_)
    | KeywordSwitch(_)
    | KeywordBreak(_)
    | KeywordContinue(_)
    | KeywordImport(_)
    | KeywordExport(_)
    | OpenBrace(_)
    | Semicolon(_)
    | KeywordDebugger(_) => true
    _ => false
  }
}

///|
/// Synchronize to next statement (enhanced version)
fn synchronize_to_statement(parser : Parser) -> Parser {
  let mut parser = parser
  while !is_at_end(parser) {
    // Check if current token is a statement start
    if is_statement_start(current_token(parser)) {
      return parser
    }

    // Check if previous token ended a statement
    match current_token(parser) {
      Semicolon(_) => return advance_parser(parser)
      CloseBrace(_) => return parser
      _ => parser = advance_parser(parser)
    }
  }
  parser
}

///|
/// Synchronize to expression end
fn synchronize_to_expression_end(parser : Parser) -> Parser {
  let mut parser = parser
  let mut paren_depth = 0
  let mut bracket_depth = 0
  let mut brace_depth = 0
  while !is_at_end(parser) {
    match current_token(parser) {
      OpenParen(_) => paren_depth = paren_depth + 1
      CloseParen(_) => {
        if paren_depth == 0 {
          return parser
        }
        paren_depth = paren_depth - 1
      }
      OpenBracket(_) => bracket_depth = bracket_depth + 1
      CloseBracket(_) => {
        if bracket_depth == 0 {
          return parser
        }
        bracket_depth = bracket_depth - 1
      }
      OpenBrace(_) => brace_depth = brace_depth + 1
      CloseBrace(_) => {
        if brace_depth == 0 {
          return parser
        }
        brace_depth = brace_depth - 1
      }
      Semicolon(_) | Comma(_) =>
        if paren_depth == 0 && bracket_depth == 0 && brace_depth == 0 {
          return parser
        }
      _ => ()
    }
    parser = advance_parser(parser)
  }
  parser
}

///|
/// Split source code by @filename directives into virtual files
/// Returns None if no @filename directives found
pub fn split_by_filename_directives(source : String) -> TestVirtualFileSet? {
  let lines = source.split("\n").collect()
  let mut current_filename : String? = None
  let mut current_content = StringBuilder::new()
  let mut current_start_line = 1
  let global_directives = CompilerDirectives::default()
  let virtual_files : Array[TestVirtualFile] = []

  for i = 0; i < lines.length(); i = i + 1 {
    let line = lines[i].to_string()
    let line_num = i + 1

    // Check for @filename directive
    if line.contains("@filename:") || line.contains("@filename :") {
      // Save previous file if it exists
      match current_filename {
        Some(filename) => {
          virtual_files.push(TestVirtualFile::{
            filename,
            content: current_content.to_string(),
            start_line: current_start_line,
          })
          current_content = StringBuilder::new()
        }
        None => ()
      }

      // Extract new filename
      let parts = line.split(":").collect()
      if parts.length() >= 2 {
        let filename_part = parts[1].to_string()
        let trimmed = trim_whitespace(filename_part)
        current_filename = Some(trimmed)
        current_start_line = line_num + 1
      }
    } else {
      // Regular line - add to current file
      match current_filename {
        Some(_) => {
          current_content.write_string(line)
          current_content.write_char('\n')
        }
        None => () // Skip lines before first @filename
      }
    }
  }

  // Save last file
  match current_filename {
    Some(filename) => {
      virtual_files.push(TestVirtualFile::{
        filename,
        content: current_content.to_string(),
        start_line: current_start_line,
      })
    }
    None => ()
  }

  // Return TestVirtualFileSet if we found any files
  if virtual_files.length() > 0 {
    Some(TestVirtualFileSet::{ files: virtual_files, global_directives })
  } else {
    None
  }
}

///|
/// Parsed virtual file result
pub struct ParsedVirtualFile {
  filename : String
  source_file : SourceFile
} derive(Show)

///|
/// Multi-file parse result
pub struct MultiFileParseResult {
  files : Array[ParsedVirtualFile]
  parse_errors : Array[(String, Array[Diagnostic])]  // (filename, diagnostics)
} derive(Show)

///|
/// Function signature info for emit helper validation
pub struct FunctionSignatureInfo {
  name : String
  param_count : Int
  module_path : String
} derive(Show)

///|
/// Helper signature registry for TS2807 validation
pub struct HelperSignatureRegistry {
  signatures : Map[String, FunctionSignatureInfo]  // "module:function" -> info
} derive(Show)

///|
/// Create empty helper signature registry
pub fn HelperSignatureRegistry::new() -> HelperSignatureRegistry {
  { signatures: Map::new() }
}

///|
/// Add a function signature to the registry
pub fn HelperSignatureRegistry::add(
  self : HelperSignatureRegistry,
  module_path : String,
  function_name : String,
  param_count : Int,
) -> Unit {
  let key = module_path + ":" + function_name
  self.signatures.set(
    key,
    FunctionSignatureInfo::{ name: function_name, param_count, module_path },
  )
}

///|
/// Look up a function signature
pub fn HelperSignatureRegistry::lookup(
  self : HelperSignatureRegistry,
  module_path : String,
  function_name : String,
) -> FunctionSignatureInfo? {
  let key = module_path + ":" + function_name
  self.signatures.get(key)
}

///|
/// Parse all virtual files from a TestVirtualFileSet
/// Returns parsed SourceFiles for each virtual file
pub fn parse_virtual_files(
  virtual_file_set : TestVirtualFileSet
) -> MultiFileParseResult {
  let parsed_files : Array[ParsedVirtualFile] = []
  let parse_errors : Array[(String, Array[Diagnostic])] = []

  for vfile in virtual_file_set.files {
    // Tokenize the virtual file
    let tokens = scan_all_v2(vfile.content, vfile.filename)

    // Parse into SourceFile
    match parse_source_file(tokens, vfile.filename) {
      Ok(source_file) => {
        // Check if there are validation errors even though parsing succeeded
        if source_file.parse_diagnostics.length() > 0 {
          // Files with parse errors are not added to the files list
          parse_errors.push((vfile.filename, source_file.parse_diagnostics))
        } else {
          // Only add files without errors to the parsed_files list
          parsed_files.push(ParsedVirtualFile::{
            filename: vfile.filename,
            source_file,
          })
        }
      }
      Err(diagnostics) => {
        parse_errors.push((vfile.filename, diagnostics))
      }
    }
  }

  MultiFileParseResult::{ files: parsed_files, parse_errors }
}

///|
/// Extract function parameter count from a function declaration/expression
fn get_function_param_count(func : Node) -> Int {
  match func {
    FunctionDeclaration(decl) => decl.parameters.length()
    FunctionExpression(expr) => expr.parameters.length()
    ArrowFunction(arrow) => arrow.parameters.length()
    _ => 0
  }
}

///|
/// Extract exported functions from statements (for .d.ts files)
/// Returns Map of export name -> parameter count
fn extract_exported_functions(statements : Array[Node]) -> Map[String, Int] {
  let exports = Map::new()

  for stmt in statements {
    match stmt {
      // export function foo(...) { } - has Export modifier
      FunctionDeclaration(func) => {
        // Check if function has Export modifier
        let mut is_exported = false
        for modifier in func.modifiers {
          if modifier == Export {
            is_exported = true
            break
          }
        }

        if is_exported {
          // Extract function name from Identifier node
          match func.name {
            Some(Identifier(id)) => {
              exports.set(id.name, func.parameters.length())
            }
            _ => ()
          }
        }
      }

      // declare module "foo" { function bar(...) } - ambient module with exports
      ModuleDeclaration(mod_decl) =>
        if mod_decl.is_ambient {
          // For ambient modules (declare module "foo"), all functions are implicitly exported
          match mod_decl.body {
            Some(BlockStatement(block)) => {
              // Recursively extract functions from module body
              for inner_stmt in block.statements {
                match inner_stmt {
                  FunctionDeclaration(func) =>
                    match func.name {
                      Some(Identifier(id)) => {
                        exports.set(id.name, func.parameters.length())
                      }
                      _ => ()
                    }
                  _ => ()
                }
              }
            }
            _ => ()
          }
        }

      _ => ()
    }
  }

  exports
}

///|
/// Build helper signature registry from parsed virtual files
/// This extracts function signatures for emit helper validation (TS2807)
pub fn build_helper_signatures(
  parse_result : MultiFileParseResult
) -> HelperSignatureRegistry {
  let helper_registry = HelperSignatureRegistry::new()

  for parsed_file in parse_result.files {
    // Bind to get the AST
    match bind_source_file(parsed_file.source_file) {
      Ok(bound) => {
        // Extract exported functions
        let exported_functions = extract_exported_functions(bound.statements)

        // Add each function to the helper registry
        exported_functions.iter().each(fn(entry) {
          let (name, param_count) = entry
          helper_registry.add(parsed_file.filename, name, param_count)
        })
      }
      Err(_) => {
        // Skip files that fail to bind
        ()
      }
    }
  }

  helper_registry
}

///|
/// Build ExternalTypeRegistry from parsed virtual files
/// This binds each file and extracts exported types for cross-file type checking
pub fn build_registry_from_virtual_files(
  parse_result : MultiFileParseResult
) -> ExternalTypeRegistry {
  let registry = ExternalTypeRegistry::new()

  // Bind each parsed file and register its exports
  for parsed_file in parse_result.files {
    // Bind the source file to get symbols
    match bind_source_file(parsed_file.source_file) {
      Ok(bound) => {
        // Create ModuleTypes for this file
        let module_types = ModuleTypes::empty(parsed_file.filename)

        // Extract exported functions from the AST and add to ModuleTypes
        // This creates simple function types based on parameter counts
        let exported_funcs = extract_exported_functions(bound.statements)
        exported_funcs.iter().each(fn(entry) {
          let (func_name, param_count) = entry
          // Create a simple function type: (any, any, ...) => any
          let params : Array[ParamInfoV2] = []
          for _i = 0; _i < param_count; _i = _i + 1 {
            params.push(ParamInfoV2::{
              name: "p\{_i}",
              ty: TAny,
              optional: false,
              is_rest: false,
            })
          }
          let func_type = FunctionTypeV2::{
            type_params: [],
            params,
            rest_param: None,
            return_type: TAny,
            type_predicate: None,
            this_type: None,
          }
          let export_info = ExternalTypeInfo::{
            ty: TFunction(func_type),
            is_type_only: false,
            original_name: func_name,
          }
          module_types.add_export(func_name, export_info)
        })

        // Register this module in the registry
        registry.register_module(parsed_file.filename, module_types)

        // Register common module mappings for tslib
        if parsed_file.filename == "tslib.d.ts" {
          registry.register_mapping("tslib", "tslib.d.ts")
        }
      }
      Err(_) => {
        // Skip files that fail to bind
        ()
      }
    }
  }

  registry
}

///|
/// Parse compiler directives from comment tokens
/// Format: @directive: value or @directive (boolean)
fn parse_compiler_directives(
  tokens : Array[(String, SourceLocation)]
) -> CompilerDirectives {
  let mut import_helpers = false
  let mut target : String? = None
  let mut filename : String? = None
  let mut no_emit = false
  let mut isolated_modules = false
  let mut no_types_and_symbols = false

  for i = 0; i < tokens.length(); i = i + 1 {
    let (content, _loc) = tokens[i]
    // Check if content contains ":"
    let has_colon = content.iter().any(fn(c) { c == ':' })
    if has_colon {
      // Split on ":" and collect into array
      let parts = content.split(":").collect()
      if parts.length() >= 2 {
        // Convert StringView to String and trim whitespace
        let directive_name = trim_whitespace(parts[0].to_string())
        let directive_value = trim_whitespace(parts[1].to_string())
        match directive_name {
          "importHelpers" => import_helpers = directive_value == "true"
          "target" => target = Some(directive_value)
          "filename" => filename = Some(directive_value)
          "noEmit" => no_emit = directive_value == "true"
          "isolatedModules" => isolated_modules = directive_value == "true"
          "noTypesAndSymbols" => no_types_and_symbols = directive_value == "true"
          _ => () // Unknown directive, ignore
        }
      }
    }
  }

  CompilerDirectives::{
    import_helpers,
    target,
    filename,
    no_emit,
    isolated_modules,
    no_types_and_symbols,
  }
}

///|
/// Parse a complete source file
pub fn parse_source_file(
  tokens : Array[Token],
  file_path : String,
) -> ParseResult[SourceFile] {
  // Extract triple-slash directive tokens, hashbang, ts-expect-error directives, compiler directives, and filter out comment tokens
  let directive_tokens : Array[(String, SourceLocation)] = []
  let ts_expect_error_directives : Array[SourceLocation] = []
  let compiler_directive_tokens : Array[(String, SourceLocation)] = []
  let scanner_errors : Array[Diagnostic] = []
  let filtered_tokens : Array[Token] = []
  let mut hashbang : String? = None
  for i = 0; i < tokens.length(); i = i + 1 {
    match tokens[i] {
      Hashbang(content, _) => hashbang = Some(content) // Extract hashbang
      CommentDirective(TripleSlashRef, content, loc) =>
        directive_tokens.push((content, loc))
      // Don't add to filtered_tokens - skip directive tokens during parsing
      CommentDirective(TsExpectError, _, loc) =>
        // Track @ts-expect-error directives for TS2578 checking
        ts_expect_error_directives.push(loc)
      CommentDirective(CompilerDirective, content, loc) =>
        // Track compiler directives (@importHelpers, @filename, @target, etc.)
        compiler_directive_tokens.push((content, loc))
      CommentDirective(_, _, _) => () // Skip other comment directives (@ts-ignore, @ts-nocheck, etc.)
      JSDocComment(_, _) => () // Skip JSDoc comments - handled separately
      ScanError(message, code, loc) =>
        // Convert scanner errors to diagnostics
        scanner_errors.push(Diagnostic::error(message, loc, code))
      token => filtered_tokens.push(token)
    }
  }
  let parser = Parser::new(filtered_tokens)
  // Enable JSX mode for .tsx and .jsx files
  let parser = if file_path.has_suffix(".tsx") || file_path.has_suffix(".jsx") {
    { ..parser, context: { ..parser.context, in_jsx: true } }
  } else {
    parser
  }
  let (statements, parser) = parse_statements(parser)
  let eof_token = current_token(parser)
  // Parse compiler directives
  let compiler_directives = parse_compiler_directives(compiler_directive_tokens)
  // Combine scanner errors with parser diagnostics
  let all_diagnostics = scanner_errors.copy()
  for d in parser.diagnostics {
    all_diagnostics.push(d)
  }
  // Always return Ok with AST, even if there are parse diagnostics
  // This allows type checking to continue and report additional errors
  Ok(SourceFile::{
    file_path,
    statements,
    end_of_file_token: eof_token,
    has_no_default_lib: false,
    directive_tokens,
    hashbang,
    ts_expect_error_directives,
    compiler_directives,
    parse_diagnostics: all_diagnostics,
  })
}

///|
/// Parse all statements until EOF
fn parse_statements(parser : Parser) -> (Array[Node], Parser) {
  parse_statements_aux(parser, [])
}

///|
/// Tail-recursive helper for parse_statements with accumulator
fn parse_statements_aux(
  parser : Parser,
  acc : Array[Node],
) -> (Array[Node], Parser) {
  if is_at_end(parser) {
    (acc, parser)
  } else {
    let current_position = parser.position
    match parse_statement(parser) {
      Ok((stmt, next_parser)) => {
        acc.push(stmt)
        // Safeguard: ensure parser advanced
        if next_parser.position == current_position {
          // Parser stuck - force advance to prevent infinite loop
          parse_statements_aux(advance_parser(next_parser), acc)
        } else {
          parse_statements_aux(next_parser, acc)
        }
      }
      Err(next_parser) => {
        // Error recovery: skip to next statement
        let recovered_parser = skip_to_next_statement(next_parser)
        // Safeguard: ensure error recovery advanced parser
        if recovered_parser.position == current_position {
          // Still stuck - force advance and stop parsing to prevent infinite loop
          (acc, advance_parser(recovered_parser))
        } else {
          parse_statements_aux(recovered_parser, acc)
        }
      }
    }
  }
}

///|
/// Parse a single statement
fn parse_statement(parser : Parser) -> Result[(Node, Parser), Parser] {
  let token = current_token(parser)
  match token {
    // Variable declarations
    KeywordLet(_) | KeywordVar(_) => parse_variable_statement(parser)

    // Function declaration
    KeywordFunction(_) => parse_function_declaration(parser, false, false)

    // Async function
    KeywordAsync(_) => {
      let parser = advance_parser(parser)
      match current_token(parser) {
        KeywordFunction(_) => parse_function_declaration(parser, true, false)
        _ => parse_expression_statement(parser)
      }
    }

    // Decorator(s) followed by class/function declaration
    At(_) => {
      let (decorators, parser) = parse_decorators(parser)
      match current_token(parser) {
        KeywordClass(_) =>
          parse_class_declaration_with_decorators(parser, false, decorators)
        KeywordAbstract(_) => {
          let parser = advance_parser(parser)
          match current_token(parser) {
            KeywordClass(_) =>
              parse_class_declaration_with_decorators(parser, true, decorators)
            _ => {
              let loc = current_token(parser).location()
              Err(
                add_error_with_code(
                  parser,
                  ExpectedClassKeyword.to_message(),
                  loc,
                  ExpectedClassKeyword,
                ),
              )
            }
          }
        }
        KeywordFunction(_) => parse_function_declaration(parser, false, false)
        KeywordAsync(_) => {
          let parser = advance_parser(parser)
          match current_token(parser) {
            KeywordFunction(_) =>
              parse_function_declaration(parser, true, false)
            _ => {
              let loc = current_token(parser).location()
              Err(
                add_error_with_code(
                  parser,
                  ExpectedFunctionKeyword.to_message(),
                  loc,
                  ExpectedFunctionKeyword,
                ),
              )
            }
          }
        }
        // @decorator export class ... - handle decorated exports
        KeywordExport(_) =>
          parse_export_declaration_with_decorators(parser, decorators)
        // Decorators not valid on these declarations - TS1206
        KeywordInterface(_)
        | KeywordType(_)
        | KeywordEnum(_)
        | KeywordConst(_)
        | KeywordLet(_)
        | KeywordVar(_) => {
          let loc = get_location(decorators[0])
          Err(
            add_error_with_code(
              parser,
              DecoratorsNotValidHere.to_message(),
              loc,
              DecoratorsNotValidHere,
            ),
          )
        }
        _ => {
          let loc = current_token(parser).location()
          Err(
            add_error_with_code(
              parser,
              DecoratorsNotValidHere.to_message(),
              loc,
              DecoratorsNotValidHere,
            ),
          )
        }
      }
    }

    // Class declaration
    KeywordClass(_) =>
      parse_class_declaration_with_decorators(parser, false, [])

    // Abstract class declaration
    KeywordAbstract(_) => {
      let parser = advance_parser(parser) // consume 'abstract'
      match current_token(parser) {
        KeywordClass(_) =>
          parse_class_declaration_with_decorators(parser, true, [])
        _ => {
          let loc = current_token(parser).location()
          Err(
            add_error_with_code(
              parser,
              ExpectedClassKeyword.to_message(),
              loc,
              ExpectedClassKeyword,
            ),
          )
        }
      }
    }

    // Interface declaration
    KeywordInterface(_) => parse_interface_declaration(parser)

    // Type alias
    KeywordType(_) => parse_type_alias_declaration(parser)

    // Enum declaration (check for const enum)
    KeywordConst(_) => {
      // Look ahead for enum keyword
      let next_token = peek_token(parser)
      match next_token {
        KeywordEnum(_) => {
          // const enum
          let parser = advance_parser(parser) // consume 'const'
          parse_enum_declaration(parser, true) // is_const = true
        }
        _ =>
          // Regular const declaration
          parse_variable_statement(parser)
      }
    }
    KeywordEnum(_) => parse_enum_declaration(parser, false)

    // Namespace declaration
    KeywordNamespace(_) => parse_module_declaration(parser)

    // Module declaration OR module.exports (CommonJS)
    KeywordModule(_) =>
      // Check if this is module.exports (CommonJS pattern)
      if parser.position + 1 < parser.tokens.length() {
        match parser.tokens[parser.position + 1] {
          Dot(_) => parse_expression_statement(parser) // module.exports
          _ => parse_module_declaration(parser)
        }
      } else {
        parse_module_declaration(parser)
      }

    // Import declaration or dynamic import expression
    KeywordImport(_) =>
      // Check if this is a dynamic import (import followed by open paren)
      if parser.position + 1 < parser.tokens.length() {
        match parser.tokens[parser.position + 1] {
          OpenParen(_) => parse_expression_statement(parser) // Dynamic import
          _ => parse_import_declaration(parser)
        }
      } else {
        parse_import_declaration(parser)
      }

    // Export declaration
    KeywordExport(_) => parse_export_declaration(parser)

    // Declare (ambient) declaration or expression statement
    // "declare" can be used as an identifier (e.g., function name) when followed by:
    // - Template literal: declare `hello`
    // - Open paren: declare()
    // - Type arguments: declare<T>
    KeywordDeclare(_) =>
      // Look ahead to see if this is an expression statement
      if parser.position + 1 < parser.tokens.length() {
        match parser.tokens[parser.position + 1] {
          TemplateLiteral(_, _)
          | TemplateHead(_, _)
          | OpenParen(_)
          | LessThan(_) => parse_expression_statement(parser)
          _ => parse_declare_declaration(parser)
        }
      } else {
        parse_declare_declaration(parser)
      }

    // Using statement (TS 5.2+): using x = expr;
    KeywordUsing(start_loc) => parse_using_statement(parser, start_loc, false)

    // Await using statement (TS 5.2+): await using x = expr;
    // Or await expression used as statement (await Promise.resolve();)
    KeywordAwait(_) => {
      // Check if this is "await using" (save parser state to potentially backtrack)
      let saved_parser = parser
      let parser_after_await = advance_parser(parser)
      match current_token(parser_after_await) {
        KeywordUsing(loc) =>
          parse_using_statement(parser_after_await, loc, true)
        // Not "await using", so this is an await expression statement
        // Use the original parser (with await token) so parse_expression_statement
        // can properly parse the await expression
        _ => parse_expression_statement(saved_parser)
      }
    }

    // Control flow
    KeywordIf(_) => parse_if_statement(parser)
    KeywordSwitch(_) => parse_switch_statement(parser)
    KeywordFor(_) => parse_for_statement(parser)
    KeywordWhile(_) => parse_while_statement(parser)
    KeywordDo(_) => parse_do_while_statement(parser)
    KeywordBreak(_) => parse_break_statement(parser)
    KeywordContinue(_) => parse_continue_statement(parser)
    KeywordReturn(_) => parse_return_statement(parser)
    KeywordThrow(_) => parse_throw_statement(parser)
    KeywordTry(_) => parse_try_statement(parser)
    KeywordDebugger(loc) => {
      let parser = advance_parser(parser)
      // Optional semicolon
      let parser = match current_token(parser) {
        Semicolon(_) => advance_parser(parser)
        _ => parser
      }
      Ok(
        (Node::DebuggerStatement(DebuggerStatement::{ location: loc }), parser),
      )
    }

    // Block statement
    OpenBrace(_) => parse_block_statement(parser)

    // Empty statement
    Semicolon(_) => {
      let loc = token.location()
      Ok(
        (
          Node::EmptyStatement(EmptyStatement::{ location: loc }),
          advance_parser(parser),
        ),
      )
    }

    // Check for labeled statement: identifier followed by colon
    Identifier(name, loc) => {
      let next_token = peek_token(parser)
      match next_token {
        Colon(_) => {
          // This is a labeled statement
          let parser = advance_parser(parser) // consume identifier
          let parser = advance_parser(parser) // consume colon
          match parse_statement(parser) {
            Ok((stmt, parser)) =>
              Ok(
                (
                  Node::LabeledStatement(LabeledStatement::{
                    label: name,
                    statement: stmt,
                    location: loc,
                  }),
                  parser,
                ),
              )
            Err(parser) => Err(parser)
          }
        }
        _ => parse_expression_statement(parser)
      }
    }

    // Expression statement (default)
    _ => parse_expression_statement(parser)
  }
}

///|
/// Helper: Parse variable declarations without consuming trailing semicolon
/// Used in contexts like for-loops where semicolon is handled separately
fn parse_variable_declaration_list(
  parser : Parser,
  consume_keyword : Bool,
) -> Result[
  (Array[VariableDeclaration], Bool, Bool, SourceLocation, Parser),
  Parser,
] {
  let start_token = current_token(parser)
  let is_const = match start_token {
    KeywordConst(_) => true
    _ => false
  }
  let is_let = match start_token {
    KeywordLet(_) => true
    _ => false
  }
  let parser = if consume_keyword { advance_parser(parser) } else { parser }

  // Parse variable declarations
  let declarations : Array[VariableDeclaration] = []
  let mut parser = parser
  let mut should_continue = true
  while should_continue {
    match parse_variable_declaration(parser) {
      Ok((decl, next_parser)) => {
        declarations.push(decl)
        parser = next_parser

        // Check for comma (multiple declarations)
        match current_token(parser) {
          Comma(_) => parser = advance_parser(parser)
          // Continue loop
          _ => should_continue = false
        }
      }
      Err(err_parser) => return Err(err_parser)
    }
  }
  let location = start_token.location()
  Ok((declarations, is_const, is_let, location, parser))
}

///|
/// Validate that const declarations have initializers
fn validate_const_initializers(
  parser : Parser,
  declarations : Array[VariableDeclaration],
) -> Parser {
  let mut parser = parser
  for decl in declarations {
    if decl.initializer.is_empty() {
      parser = add_error_with_code(
        parser,
        ConstDeclarationMustBeInitialized.to_message(),
        decl.location,
        ConstDeclarationMustBeInitialized,
      )
    }
  }
  parser
}

///|
/// Parse variable statement (let/const/var)
fn parse_variable_statement(parser : Parser) -> Result[(Node, Parser), Parser] {
  match parse_variable_declaration_list(parser, true) {
    Ok((declarations, is_const, is_let, location, parser)) => {
      // Note: TS1155 (const must be initialized) is checked in the checker
      // because we need to know if 'declare' modifier is present
      // (declare const doesn't require initializer)
      // Expect semicolon for standalone variable statements
      let parser = expect_semicolon(parser)
      Ok(
        (
          Node::VariableStatement(VariableStatement::{
            declarations,
            is_const,
            is_let,
            modifiers: [],
            location,
          }),
          parser,
        ),
      )
    }
    Err(parser) => Err(parser)
  }
}

///|
/// Parse using statement (TS 5.2+)
/// `using x = expr;` or `await using x = expr;`
fn parse_using_statement(
  parser : Parser,
  start_loc : SourceLocation,
  is_await : Bool,
) -> Result[(Node, Parser), Parser] {
  let parser = advance_parser(parser) // consume 'using'

  // Parse declarations
  let declarations : Array[VariableDeclaration] = []
  let mut parser = parser
  let mut first = true
  while true {
    if not(first) {
      // Check for comma to continue
      match current_token(parser) {
        Comma(_) => parser = advance_parser(parser)
        _ => break
      }
    }
    first = false

    // Parse identifier
    match parse_identifier(parser) {
      Ok((id, p)) => {
        parser = p
        let name = Node::Identifier(id)

        // Optional type annotation
        let (type_annotation, p2) = match current_token(parser) {
          Colon(_) => {
            let p = advance_parser(parser)
            match parse_type(p) {
              Ok((ty, p3)) => (Some(ty), p3)
              Err(p3) => (None, p3)
            }
          }
          _ => (None, parser)
        }
        parser = p2

        // Initializer (required for using)
        let (initializer, p3) = match current_token(parser) {
          Equals(_) => {
            let p = advance_parser(parser)
            match parse_assignment_expression(p) {
              Ok((expr, p4)) => (Some(expr), p4)
              Err(p4) => (None, p4)
            }
          }
          _ => (None, parser)
        }
        parser = p3
        declarations.push(VariableDeclaration::{
          name,
          type_annotation,
          initializer,
          location: id.location,
        })
      }
      Err(p) => {
        parser = p
        break
      }
    }
  }

  // Consume semicolon
  let parser = expect_semicolon(parser)
  Ok(
    (
      Node::UsingStatement(UsingStatement::{
        declarations,
        is_await,
        location: start_loc,
      }),
      parser,
    ),
  )
}

///|
/// Parse a single variable declaration
fn parse_variable_declaration(
  parser : Parser,
) -> Result[(VariableDeclaration, Parser), Parser] {
  let start_loc = current_token(parser).location()

  // Parse name (identifier or binding pattern)
  let (name, parser) = match current_token(parser) {
    OpenBracket(_) =>
      // Array destructuring pattern
      match parse_array_binding_pattern(parser) {
        Ok((pattern, p)) => (pattern, p)
        Err(p) => return Err(p)
      }
    OpenBrace(_) =>
      // Object destructuring pattern
      match parse_object_binding_pattern(parser) {
        Ok((pattern, p)) => (pattern, p)
        Err(p) => return Err(p)
      }
    _ =>
      // Regular identifier
      match parse_identifier(parser) {
        Ok((id, p)) => (Node::Identifier(id), p)
        Err(p) => return Err(add_error(p, "Identifier expected", start_loc))
      }
  }

  // Optional type annotation
  let (type_annotation, parser) = match current_token(parser) {
    Colon(_) => {
      let parser = advance_parser(parser)
      match parse_type(parser) {
        Ok((ty, p)) => (Some(ty), p)
        Err(p) => (None, p)
      }
    }
    _ => (None, parser)
  }

  // Optional initializer
  let (initializer, parser) = match current_token(parser) {
    Equals(_) => {
      let parser = advance_parser(parser)
      match parse_assignment_expression(parser) {
        Ok((expr, p)) => (Some(expr), p)
        Err(p) => (None, p)
      }
    }
    _ => (None, parser)
  }

  // Note: TS1182 (A destructuring declaration must have an initializer) is checked
  // in the checker because:
  // - Ambient declarations (declare var) don't need initializers
  // - For-of/for-in loop bindings get values from iteration, not initializers
  Ok(
    (
      VariableDeclaration::{
        name,
        type_annotation,
        initializer,
        location: start_loc,
      },
      parser,
    ),
  )
}

///|
/// Parse array binding pattern: [a, b] or [a, , c]
fn parse_array_binding_pattern(
  parser : Parser,
) -> Result[(Node, Parser), Parser] {
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume '['
  let elements = []
  let mut parser = parser
  while true {
    match current_token(parser) {
      CloseBracket(_) => {
        parser = advance_parser(parser)
        break
      }
      Comma(_) => {
        // Hole in array pattern
        elements.push(None)
        parser = advance_parser(parser)
      }
      DotDotDot(spread_loc) => {
        // Rest element: [...rest] or [...[a, b]] or [...{x, y}]
        parser = advance_parser(parser) // consume '...'
        let (rest_target, p) = match current_token(parser) {
          Identifier(name, loc) => {
            let rest_name = Node::Identifier(Identifier::{ name, location: loc })
            (rest_name, advance_parser(parser))
          }
          OpenBracket(_) =>
            // Nested array pattern: [...[a, b]]
            match parse_array_binding_pattern(parser) {
              Ok((pattern, p)) => (pattern, p)
              Err(p) => return Err(p)
            }
          OpenBrace(_) =>
            // Nested object pattern: [...{x, y}]
            match parse_object_binding_pattern(parser) {
              Ok((pattern, p)) => (pattern, p)
              Err(p) => return Err(p)
            }
          _ => break // Invalid rest syntax
        }
        parser = p

        // TS1186: A rest element cannot have an initializer
        // Check for and report any initializer
        parser = match current_token(parser) {
          Equals(eq_loc) => {
            // Report error but continue parsing for error recovery
            let parser = add_error_checked(
              parser, "A rest element cannot have an initializer.", eq_loc, 1186,
            )
            let parser = advance_parser(parser) // consume '='
            // Parse and discard the initializer expression for error recovery
            match parse_assignment_expression(parser) {
              Ok((_, p)) => p
              Err(p) => p
            }
          }
          _ => parser
        }

        // Wrap in SpreadExpression to mark as rest element
        let spread_node = Node::SpreadExpression(SpreadExpression::{
          expression: rest_target,
          location: spread_loc,
        })
        elements.push(Some(spread_node))
        // Optional comma (though rest should be last element)
        match current_token(parser) {
          Comma(_) => parser = advance_parser(parser)
          _ => ()
        }
      }
      OpenBracket(arr_loc) =>
        // Nested array pattern with optional default: [x] = [0]
        match parse_array_binding_pattern(parser) {
          Ok((pattern, p)) => {
            parser = p
            // Check for default value initializer
            let element_node = match current_token(parser) {
              Equals(_) => {
                parser = advance_parser(parser) // consume '='
                match parse_assignment_expression(parser) {
                  Ok((init_expr, p2)) => {
                    parser = p2
                    Node::BindingElement(BindingElement::{
                      property_name: "",
                      name: pattern,
                      initializer: Some(init_expr),
                      location: arr_loc,
                    })
                  }
                  Err(p2) => {
                    parser = p2
                    pattern // Fallback if parse fails
                  }
                }
              }
              _ => pattern
            }
            elements.push(Some(element_node))
            match current_token(parser) {
              Comma(_) => parser = advance_parser(parser)
              _ => ()
            }
          }
          Err(p) => return Err(p)
        }
      OpenBrace(obj_loc) =>
        // Nested object pattern with optional default: { x } = { x: 0 }
        match parse_object_binding_pattern(parser) {
          Ok((pattern, p)) => {
            parser = p
            // Check for default value initializer
            let element_node = match current_token(parser) {
              Equals(_) => {
                parser = advance_parser(parser) // consume '='
                match parse_assignment_expression(parser) {
                  Ok((init_expr, p2)) => {
                    parser = p2
                    Node::BindingElement(BindingElement::{
                      property_name: "",
                      name: pattern,
                      initializer: Some(init_expr),
                      location: obj_loc,
                    })
                  }
                  Err(p2) => {
                    parser = p2
                    pattern // Fallback if parse fails
                  }
                }
              }
              _ => pattern
            }
            elements.push(Some(element_node))
            match current_token(parser) {
              Comma(_) => parser = advance_parser(parser)
              _ => ()
            }
          }
          Err(p) => return Err(p)
        }
      // Handle identifiers and contextual keywords (number, string, any, etc.)
      _ =>
        match try_get_identifier_name(current_token(parser)) {
          Some((name, loc)) => {
            let id_node = Node::Identifier(Identifier::{ name, location: loc })
            parser = advance_parser(parser)

            // Check for default value initializer (a = expr)
            let element_node = match current_token(parser) {
              Equals(_) => {
                parser = advance_parser(parser) // consume '='
                match parse_assignment_expression(parser) {
                  Ok((init_expr, p)) => {
                    parser = p
                    Node::BindingElement(BindingElement::{
                      property_name: name,
                      name: id_node,
                      initializer: Some(init_expr),
                      location: loc,
                    })
                  }
                  Err(p) => {
                    parser = p
                    id_node // Fallback if parse fails
                  }
                }
              }
              _ => id_node
            }
            elements.push(Some(element_node))

            // Optional comma
            match current_token(parser) {
              Comma(_) => parser = advance_parser(parser)
              _ => ()
            }
          }
          None => break
        }
    }
  }
  Ok(
    (
      Node::ArrayBindingPattern(ArrayBindingPattern::{
        elements,
        location: start_loc,
      }),
      parser,
    ),
  )
}

///|
/// Parse object binding pattern: { x, y } or { x: a, y: b }
/// Supports identifiers, contextual keywords (like 'as'), numeric, string, and computed properties
fn parse_object_binding_pattern(
  parser : Parser,
) -> Result[(Node, Parser), Parser] {
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume '{'
  let properties = []
  let mut parser = parser
  while true {
    match current_token(parser) {
      CloseBrace(_) => {
        parser = advance_parser(parser)
        break
      }
      // Handle rest element: { ...rest }
      DotDotDot(rest_loc) => {
        parser = advance_parser(parser) // consume '...'
        // Parse the rest target (must be identifier or contextual keyword)
        match try_get_identifier_name(current_token(parser)) {
          Some((rest_name, id_loc)) => {
            parser = advance_parser(parser)
            properties.push(BindingElement::{
              property_name: "...",
              name: Node::Identifier(Identifier::{
                name: rest_name,
                location: id_loc,
              }),
              initializer: None,
              location: rest_loc,
            })
          }
          None =>
            match current_token(parser) {
              OpenBrace(_) | OpenBracket(_) =>
                // TS2566: A rest element cannot contain a binding pattern
                return Err(
                  add_error_checked(
                    parser, "A rest element cannot contain a binding pattern.", rest_loc,
                    2566,
                  ),
                )
              _ =>
                return Err(
                  add_error(
                    parser, "Identifier expected after rest element", rest_loc,
                  ),
                )
            }
        }
        // Optional comma (though rest should be last)
        match current_token(parser) {
          Comma(_) => parser = advance_parser(parser)
          _ => ()
        }
      }
      // Handle numeric property: { 1: x }
      NumericLiteral(num_val, num_loc) => {
        let prop_name = num_val.to_string()
        parser = advance_parser(parser)

        // Must have colon after numeric property name
        match current_token(parser) {
          Colon(_) => {
            parser = advance_parser(parser)

            // Parse the binding name (identifier, contextual keyword, or nested pattern)
            // Also detect reserved keywords as binding targets - these should error with TS1359
            let (name, p2) = match
              try_get_binding_target_with_reserved(current_token(parser)) {
              Some((bind_name, bind_loc, is_reserved_binding)) =>
                if is_reserved_binding {
                  // TS1359: Reserved word cannot be used as binding target
                  let error_msg = "Identifier expected. '\{bind_name}' is a reserved word that cannot be used here."
                  let p3 = add_error_checked(parser, error_msg, bind_loc, 1359)
                  // Still advance past the reserved keyword to continue parsing
                  (
                    Node::Identifier(Identifier::{
                      name: bind_name,
                      location: bind_loc,
                    }),
                    advance_parser(p3),
                  )
                } else {
                  (
                    Node::Identifier(Identifier::{
                      name: bind_name,
                      location: bind_loc,
                    }),
                    advance_parser(parser),
                  )
                }
              None =>
                match current_token(parser) {
                  OpenBracket(_) =>
                    match parse_array_binding_pattern(parser) {
                      Ok((pattern, p)) => (pattern, p)
                      Err(p) => return Err(p)
                    }
                  OpenBrace(_) =>
                    match parse_object_binding_pattern(parser) {
                      Ok((pattern, p)) => (pattern, p)
                      Err(p) => return Err(p)
                    }
                  _ =>
                    return Err(
                      add_error(parser, "Identifier expected", num_loc),
                    )
                }
            }
            parser = p2

            // Check for default value initializer
            let (initializer, parser2) = match current_token(parser) {
              Equals(_) => {
                let p = advance_parser(parser)
                match parse_assignment_expression(p) {
                  Ok((expr, p2)) => (Some(expr), p2)
                  Err(p2) => return Err(p2)
                }
              }
              _ => (None, parser)
            }
            parser = parser2
            properties.push(BindingElement::{
              property_name: prop_name,
              name,
              initializer,
              location: num_loc,
            })

            // Optional comma
            match current_token(parser) {
              Comma(_) => parser = advance_parser(parser)
              _ => ()
            }
          }
          _ => return Err(add_error(parser, "':' expected", num_loc))
        }
      }
      // Handle string literal property: { "prop": x }
      StringLiteral(str_val, str_loc) => {
        let prop_name = str_val
        parser = advance_parser(parser)

        // Must have colon after string property name (no shorthand for string literals)
        match current_token(parser) {
          Colon(_) => {
            parser = advance_parser(parser)

            // Parse the binding name (identifier, contextual keyword, or nested pattern)
            // Also detect reserved keywords as binding targets - these should error with TS1359
            let (name, p2) = match
              try_get_binding_target_with_reserved(current_token(parser)) {
              Some((bind_name, bind_loc, is_reserved_binding)) =>
                if is_reserved_binding {
                  // TS1359: Reserved word cannot be used as binding target
                  let error_msg = "Identifier expected. '\{bind_name}' is a reserved word that cannot be used here."
                  let p3 = add_error_checked(parser, error_msg, bind_loc, 1359)
                  // Still advance past the reserved keyword to continue parsing
                  (
                    Node::Identifier(Identifier::{
                      name: bind_name,
                      location: bind_loc,
                    }),
                    advance_parser(p3),
                  )
                } else {
                  (
                    Node::Identifier(Identifier::{
                      name: bind_name,
                      location: bind_loc,
                    }),
                    advance_parser(parser),
                  )
                }
              None =>
                match current_token(parser) {
                  OpenBracket(_) =>
                    match parse_array_binding_pattern(parser) {
                      Ok((pattern, p)) => (pattern, p)
                      Err(p) => return Err(p)
                    }
                  OpenBrace(_) =>
                    match parse_object_binding_pattern(parser) {
                      Ok((pattern, p)) => (pattern, p)
                      Err(p) => return Err(p)
                    }
                  _ =>
                    return Err(
                      add_error(parser, "Identifier expected", str_loc),
                    )
                }
            }
            parser = p2

            // Check for default value initializer
            let (initializer, parser2) = match current_token(parser) {
              Equals(_) => {
                let p = advance_parser(parser)
                match parse_assignment_expression(p) {
                  Ok((expr, p2)) => (Some(expr), p2)
                  Err(p2) => return Err(p2)
                }
              }
              _ => (None, parser)
            }
            parser = parser2
            properties.push(BindingElement::{
              property_name: prop_name,
              name,
              initializer,
              location: str_loc,
            })

            // Optional comma
            match current_token(parser) {
              Comma(_) => parser = advance_parser(parser)
              _ => ()
            }
          }
          _ =>
            return Err(
              add_error_with_code(
                parser,
                "':' expected.",
                current_token(parser).location(),
                ParserErrorCode::ExpectedColon,
              ),
            )
        }
      }
      // Handle computed property: { [expr]: x }
      OpenBracket(bracket_loc) => {
        parser = advance_parser(parser) // consume '['

        // Parse the computed property name expression
        let (prop_expr, p) = match parse_assignment_expression(parser) {
          Ok((expr, p)) => (expr, p)
          Err(p) => return Err(p)
        }
        let _ = prop_expr // Used for computed property value
        parser = p

        // Expect closing bracket
        match current_token(parser) {
          CloseBracket(_) => parser = advance_parser(parser)
          _ => return Err(add_error(parser, "']' expected", bracket_loc))
        }

        // Must have colon after computed property
        match current_token(parser) {
          Colon(_) => {
            parser = advance_parser(parser)

            // Parse the binding name (identifier, contextual keyword, or nested pattern)
            // Also detect reserved keywords as binding targets - these should error with TS1359
            let (name, p2) = match
              try_get_binding_target_with_reserved(current_token(parser)) {
              Some((bind_name, bind_loc, is_reserved_binding)) =>
                if is_reserved_binding {
                  // TS1359: Reserved word cannot be used as binding target
                  let error_msg = "Identifier expected. '\{bind_name}' is a reserved word that cannot be used here."
                  let p3 = add_error_checked(parser, error_msg, bind_loc, 1359)
                  // Still advance past the reserved keyword to continue parsing
                  (
                    Node::Identifier(Identifier::{
                      name: bind_name,
                      location: bind_loc,
                    }),
                    advance_parser(p3),
                  )
                } else {
                  (
                    Node::Identifier(Identifier::{
                      name: bind_name,
                      location: bind_loc,
                    }),
                    advance_parser(parser),
                  )
                }
              None =>
                match current_token(parser) {
                  OpenBracket(_) =>
                    match parse_array_binding_pattern(parser) {
                      Ok((pattern, p)) => (pattern, p)
                      Err(p) => return Err(p)
                    }
                  OpenBrace(_) =>
                    match parse_object_binding_pattern(parser) {
                      Ok((pattern, p)) => (pattern, p)
                      Err(p) => return Err(p)
                    }
                  _ =>
                    return Err(
                      add_error(parser, "Identifier expected", bracket_loc),
                    )
                }
            }
            parser = p2

            // Check for default value initializer
            let (initializer, parser2) = match current_token(parser) {
              Equals(_) => {
                let p = advance_parser(parser)
                match parse_assignment_expression(p) {
                  Ok((expr, p2)) => (Some(expr), p2)
                  Err(p2) => return Err(p2)
                }
              }
              _ => (None, parser)
            }
            parser = parser2

            // For computed properties, we use a special marker
            properties.push(BindingElement::{
              property_name: "[computed]",
              name,
              initializer,
              location: bracket_loc,
            })

            // Optional comma
            match current_token(parser) {
              Comma(_) => parser = advance_parser(parser)
              _ => ()
            }
          }
          _ => return Err(add_error(parser, "':' expected", bracket_loc))
        }
      }
      // Handle identifier or contextual keyword property: { x } or { x: y } or { as } etc.
      // Also handle reserved keywords as property names (require colon)
      _ =>
        match try_get_property_name_with_reserved(current_token(parser)) {
          Some((prop_name, prop_loc, is_reserved)) => {
            parser = advance_parser(parser)

            // Check for colon (renaming: { x: a })
            let (name, p2) = match current_token(parser) {
              Colon(_) => {
                let p2 = advance_parser(parser)

                // Parse the binding name (identifier, contextual keyword, or nested pattern)
                // Also detect reserved keywords as binding targets - these should error with TS1359
                match try_get_binding_target_with_reserved(current_token(p2)) {
                  Some((bind_name, bind_loc, is_reserved_binding)) =>
                    if is_reserved_binding {
                      // TS1359: Reserved word cannot be used as binding target
                      let error_msg = "Identifier expected. '\{bind_name}' is a reserved word that cannot be used here."
                      let p3 = add_error_checked(p2, error_msg, bind_loc, 1359)
                      // Still advance past the reserved keyword to continue parsing
                      (
                        Node::Identifier(Identifier::{
                          name: bind_name,
                          location: bind_loc,
                        }),
                        advance_parser(p3),
                      )
                    } else {
                      (
                        Node::Identifier(Identifier::{
                          name: bind_name,
                          location: bind_loc,
                        }),
                        advance_parser(p2),
                      )
                    }
                  None =>
                    match current_token(p2) {
                      OpenBracket(_) =>
                        match parse_array_binding_pattern(p2) {
                          Ok((pattern, p)) => (pattern, p)
                          Err(p) => return Err(p)
                        }
                      OpenBrace(_) =>
                        match parse_object_binding_pattern(p2) {
                          Ok((pattern, p)) => (pattern, p)
                          Err(p) => return Err(p)
                        }
                      _ =>
                        return Err(
                          add_error(p2, "Identifier expected", prop_loc),
                        )
                    }
                }
              }
              _ =>
                // Shorthand: { x } means { x: x }
                // But reserved keywords REQUIRE a colon - TS1005
                if is_reserved {
                  return Err(
                    add_error_with_code(
                      parser,
                      "':' expected.",
                      prop_loc,
                      ParserErrorCode::ExpectedColon,
                    ),
                  )
                } else {
                  (
                    Node::Identifier(Identifier::{
                      name: prop_name,
                      location: prop_loc,
                    }),
                    parser,
                  )
                }
            }
            parser = p2

            // Check for default value initializer: { x = 5 } or { x: y = 5 }
            let (initializer, parser2) = match current_token(parser) {
              Equals(_) => {
                let p = advance_parser(parser)
                match parse_assignment_expression(p) {
                  Ok((expr, p2)) => (Some(expr), p2)
                  Err(p2) => return Err(p2)
                }
              }
              _ => (None, parser)
            }
            parser = parser2
            properties.push(BindingElement::{
              property_name: prop_name,
              name,
              initializer,
              location: prop_loc,
            })

            // Optional comma
            match current_token(parser) {
              Comma(_) => parser = advance_parser(parser)
              _ => ()
            }
          }
          None => break // Not a valid property, exit loop
        }
    }
  }
  Ok(
    (
      Node::ObjectBindingPattern(ObjectBindingPattern::{
        properties,
        location: start_loc,
      }),
      parser,
    ),
  )
}

///|
/// Parse return type with type predicate support
/// Handles: regular types, "x is Type", "asserts x", "asserts x is Type"
fn parse_return_type(parser : Parser) -> Result[(Node, Parser), Parser] {
  let start_loc = current_token(parser).location()

  // Check for "asserts" keyword (contextual)
  match current_token(parser) {
    Identifier(name, _) if name == "asserts" => {
      let parser = advance_parser(parser)
      // Expect parameter name
      match current_token(parser) {
        Identifier(param_name, _) => {
          let parser = advance_parser(parser)
          // Check for "is" keyword
          match current_token(parser) {
            Identifier(is_name, _) if is_name == "is" => {
              let parser = advance_parser(parser)
              // Parse the type
              match parse_type(parser) {
                Ok((type_node, p)) =>
                  Ok(
                    (
                      Node::TypePredicate(TypePredicate::{
                        parameter_name: param_name,
                        type_node: Some(type_node),
                        is_asserts: true,
                        location: start_loc,
                      }),
                      p,
                    ),
                  )
                Err(p) => Err(p)
              }
            }
            _ =>
              // Just "asserts x" without type
              Ok(
                (
                  Node::TypePredicate(TypePredicate::{
                    parameter_name: param_name,
                    type_node: None,
                    is_asserts: true,
                    location: start_loc,
                  }),
                  parser,
                ),
              )
          }
        }
        _ =>
          return Err(
            add_error_with_code(
              parser,
              "Identifier expected",
              current_token(parser).location(),
              IdentifierExpected,
            ),
          )
      }
    }
    Identifier(param_name, _) => {
      // Peek ahead to see if this is "x is Type" pattern
      let parser2 = advance_parser(parser)
      match current_token(parser2) {
        Identifier(is_name, _) if is_name == "is" => {
          let parser = advance_parser(parser2)
          // Parse the type
          match parse_type(parser) {
            Ok((type_node, p)) =>
              Ok(
                (
                  Node::TypePredicate(TypePredicate::{
                    parameter_name: param_name,
                    type_node: Some(type_node),
                    is_asserts: false,
                    location: start_loc,
                  }),
                  p,
                ),
              )
            Err(p) => Err(p)
          }
        }
        _ =>
          // Not a type predicate, parse as regular type
          parse_type(parser)
      }
    }
    _ =>
      // Regular type
      parse_type(parser)
  }
}

///|
/// Parse function declaration
fn parse_function_declaration(
  parser : Parser,
  is_async : Bool,
  is_generator : Bool,
) -> Result[(Node, Parser), Parser] {
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // Skip 'function'

  // Optional generator *
  let (is_generator, parser) = match current_token(parser) {
    Star(_) => (true, advance_parser(parser))
    _ => (is_generator, parser)
  }

  // Function name (optional for function expressions and export default)
  // Use try_get_identifier_name to allow all contextual keywords as function names
  let (name, parser) = match try_get_identifier_name(current_token(parser)) {
    Some((id_name, loc)) =>
      (
        Some(Node::Identifier(Identifier::{ name: id_name, location: loc })),
        advance_parser(parser),
      )
    None => (None, parser) // Anonymous function - no error, name is optional
  }

  // Type parameters
  let (type_parameters, parser) = match current_token(parser) {
    LessThan(_) => parse_type_parameters(parser)
    _ => ([], parser)
  }

  // Parameters
  let (parameters, parser) = match
    expect(parser, fn(t) { matches_open_paren(t) }) {
    Ok(p) => {
      let p = advance_parser(p)
      parse_parameter_list(p)
    }
    Err(p) =>
      return Err(
        add_error_with_code(
          p,
          ExpectedOpenParen.to_message(),
          start_loc,
          ExpectedOpenParen,
        ),
      )
  }

  // Return type (with type predicate support)
  let (return_type, parser) = match current_token(parser) {
    Colon(_) => {
      let parser = advance_parser(parser)
      match parse_return_type(parser) {
        Ok((ty, p)) => (Some(ty), p)
        Err(p) => (None, p)
      }
    }
    _ => (None, parser)
  }

  // Body (use parse_function_body to set in_function context)
  let (body, parser) = match current_token(parser) {
    OpenBrace(_) =>
      match parse_function_body(parser) {
        Ok((block, p)) => (Some(block), p)
        Err(p) => (None, p)
      }
    Semicolon(_) =>
      // Function declaration without body (overload signature)
      (None, advance_parser(parser))
    _ => (None, parser)
  }
  Ok(
    (
      Node::FunctionDeclaration(FunctionDeclaration::{
        name,
        type_parameters,
        parameters,
        return_type,
        body,
        is_async,
        is_generator,
        modifiers: [],
        location: start_loc,
      }),
      parser,
    ),
  )
}

///|
/// Parse parameter list
fn parse_parameter_list(parser : Parser) -> (Array[Node], Parser) {
  // Check for empty parameter list
  match current_token(parser) {
    CloseParen(_) => ([], advance_parser(parser))
    _ => parse_parameter_list_aux(parser, [], false, false)
  }
}

///|
/// Tail-recursive helper for parse_parameter_list with accumulator
/// Tracks whether we've seen an optional parameter and a rest parameter for validation
fn parse_parameter_list_aux(
  parser : Parser,
  acc : Array[Node],
  seen_optional : Bool,
  seen_rest : Bool,
) -> (Array[Node], Parser) {
  match parse_parameter(parser) {
    Ok((param, next_parser)) => {
      // Validate parameter order
      let next_parser = validate_parameter_order(
        next_parser, param, seen_optional, seen_rest,
      )

      // Check if this parameter is optional or rest
      let (is_optional, is_rest) = match param {
        Node::Parameter(p) =>
          (p.is_optional || p.initializer is Some(_), p.is_rest)
        _ => (false, false)
      }
      acc.push(param)
      match current_token(next_parser) {
        Comma(_) =>
          parse_parameter_list_aux(
            advance_parser(next_parser),
            acc,
            seen_optional || is_optional,
            seen_rest || is_rest,
          )
        CloseParen(_) => (acc, advance_parser(next_parser))
        _ => (acc, next_parser)
      }
    }
    Err(_) => (acc, parser)
  }
}

///|
/// Validate parameter order constraints
fn validate_parameter_order(
  parser : Parser,
  param : Node,
  seen_optional : Bool,
  seen_rest : Bool,
) -> Parser {
  match param {
    Node::Parameter(p) => {
      let mut parser = parser

      // TS1014: A rest parameter must be last in a parameter list
      // If we've already seen a rest parameter and this is another parameter
      if seen_rest {
        parser = add_error_with_code(
          parser,
          RestParameterMustBeLast.to_message(),
          p.location,
          RestParameterMustBeLast,
        )
      }

      // TS1016: A required parameter cannot follow an optional parameter
      // A parameter is required if it's not optional and has no initializer
      let is_required = not(p.is_optional) &&
        p.initializer.is_empty() &&
        not(p.is_rest)
      if seen_optional && is_required {
        parser = add_error_with_code(
          parser,
          RequiredParamAfterOptional.to_message(),
          p.location,
          RequiredParamAfterOptional,
        )
      }
      parser
    }
    _ => parser
  }
}

///|
/// Parse a parameter
fn parse_parameter(parser : Parser) -> Result[(Node, Parser), Parser] {
  let start_loc = current_token(parser).location()
  let mut parser = parser

  // Parse parameter decorators (@decorator)
  let decorators : Array[Node] = []
  while true {
    match current_token(parser) {
      At(dec_loc) => {
        parser = advance_parser(parser) // consume @
        match parse_expression(parser) {
          Ok((expr, p)) => {
            decorators.push(
              Node::Decorator(Decorator::{ expression: expr, location: dec_loc }),
            )
            parser = p
          }
          Err(_) => break
        }
      }
      _ => break
    }
  }

  // Parse parameter property modifiers (public, private, protected, readonly)
  let modifiers : Array[Modifier] = []
  while true {
    match current_token(parser) {
      KeywordPublic(_) => {
        modifiers.push(Modifier::Public)
        parser = advance_parser(parser)
      }
      KeywordPrivate(_) => {
        modifiers.push(Modifier::Private)
        parser = advance_parser(parser)
      }
      KeywordProtected(_) => {
        modifiers.push(Modifier::Protected)
        parser = advance_parser(parser)
      }
      KeywordReadonly(_) => {
        modifiers.push(Modifier::Readonly)
        parser = advance_parser(parser)
      }
      _ => break
    }
  }

  // Check for rest parameter
  let (is_rest, parser) = match current_token(parser) {
    DotDotDot(_) => (true, advance_parser(parser))
    _ => (false, parser)
  }

  // Check for `this` parameter: function foo(this: SomeType, ...)
  let (is_this_parameter, name, parser) = match current_token(parser) {
    KeywordThis(loc) => {
      let parser = advance_parser(parser)
      (
        true,
        Node::Identifier(Identifier::{ name: "this", location: loc }),
        parser,
      )
    }
    _ =>
      // Check for destructuring patterns: { page } or [ a, b ]
      match current_token(parser) {
        OpenBrace(_) =>
          match parse_object_binding_pattern(parser) {
            Ok((pattern, p)) => (false, pattern, p)
            Err(p) => return Err(p)
          }
        OpenBracket(_) =>
          match parse_array_binding_pattern(parser) {
            Ok((pattern, p)) => (false, pattern, p)
            Err(p) => return Err(p)
          }
        _ =>
          match parse_identifier(parser) {
            Ok((id, p)) => (false, Node::Identifier(id), p)
            Err(p) => return Err(p)
          }
      }
  }

  // Optional parameter
  let (is_optional, parser) = match current_token(parser) {
    Question(_) => (true, advance_parser(parser))
    _ => (false, parser)
  }

  // Type annotation
  let (type_annotation, parser) = match current_token(parser) {
    Colon(_) => {
      let parser = advance_parser(parser)
      match parse_type(parser) {
        Ok((ty, p)) => (Some(ty), p)
        Err(p) => (None, p)
      }
    }
    _ => (None, parser)
  }

  // Default value (not allowed for `this` parameter, but parse anyway for error recovery)
  let (initializer, parser) = match current_token(parser) {
    Equals(_) => {
      let parser = advance_parser(parser)
      match parse_assignment_expression(parser) {
        Ok((expr, p)) => (Some(expr), p)
        Err(p) => (None, p)
      }
    }
    _ => (None, parser)
  }

  // Parameters with default values are effectively optional
  let is_optional = is_optional || initializer is Some(_)

  // Validate rest parameter constraints
  let parser = if is_rest {
    // TS1048: A rest parameter cannot be optional
    let parser = if is_optional {
      add_error_with_code(
        parser,
        RestParameterCannotBeOptional.to_message(),
        start_loc,
        RestParameterCannotBeOptional,
      )
    } else {
      parser
    }
    // TS1049: A rest parameter cannot have an initializer
    match initializer {
      Some(_) =>
        add_error_with_code(
          parser,
          RestParameterCannotHaveInitializer.to_message(),
          start_loc,
          RestParameterCannotHaveInitializer,
        )
      None => parser
    }
  } else {
    parser
  }

  // TS1187: A parameter property may not be declared using a binding pattern
  // Parameter properties (with public, private, protected, or readonly modifiers)
  // can only be declared with a simple identifier, not with destructuring patterns
  let parser = if modifiers.length() > 0 {
    match name {
      ArrayBindingPattern(_) | ObjectBindingPattern(_) =>
        add_error_with_code(
          parser,
          ParameterPropertyBindingPattern.to_message(),
          start_loc,
          ParameterPropertyBindingPattern,
        )
      _ => parser
    }
  } else {
    parser
  }
  Ok(
    (
      Node::Parameter(Parameter::{
        name,
        type_annotation,
        initializer,
        is_optional,
        is_rest,
        is_this_parameter,
        decorators,
        modifiers,
        location: start_loc,
      }),
      parser,
    ),
  )
}

///|
/// Parse block statement
fn parse_block_statement(parser : Parser) -> Result[(Node, Parser), Parser] {
  let start_loc = current_token(parser).location()
  match expect(parser, fn(t) { matches_open_brace(t) }) {
    Ok(parser) => {
      let parser = advance_parser(parser)
      let statements : Array[Node] = []
      let mut parser = parser
      while !matches_close_brace(current_token(parser)) && !is_at_end(parser) {
        match parse_statement(parser) {
          Ok((stmt, next_parser)) => {
            statements.push(stmt)
            parser = next_parser
          }
          Err(next_parser) => parser = skip_to_next_statement(next_parser)
        }
      }
      match expect(parser, fn(t) { matches_close_brace(t) }) {
        Ok(parser) => {
          let parser = advance_parser(parser)
          Ok(
            (
              Node::BlockStatement(BlockStatement::{
                statements,
                location: start_loc,
              }),
              parser,
            ),
          )
        }
        Err(parser) =>
          Err(
            add_error_with_code(
              parser,
              ExpectedCloseBrace.to_message(),
              start_loc,
              ExpectedCloseBrace,
            ),
          )
      }
    }
    Err(parser) =>
      Err(
        add_error_with_code(
          parser,
          ExpectedOpenBrace.to_message(),
          start_loc,
          ExpectedOpenBrace,
        ),
      )
  }
}

///|
/// Parse function body (block statement with in_function context)
/// Sets in_function: true to allow return statements
fn parse_function_body(parser : Parser) -> Result[(Node, Parser), Parser] {
  // Set in_function context
  let old_context = parser.context
  let new_context = { ..old_context, in_function: true }
  let parser = { ..parser, context: new_context }

  // Parse the block
  match parse_block_statement(parser) {
    Ok((block, parser)) => {
      // Restore old context
      let parser = { ..parser, context: old_context }
      Ok((block, parser))
    }
    Err(parser) => {
      // Restore old context even on error
      let parser = { ..parser, context: old_context }
      Err(parser)
    }
  }
}

///|
/// Parse if statement
fn parse_if_statement(parser : Parser) -> Result[(Node, Parser), Parser] {
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // Skip 'if'

  // Expect '('
  let parser = match expect(parser, fn(t) { matches_open_paren(t) }) {
    Ok(p) => advance_parser(p)
    Err(p) =>
      return Err(
        add_error_with_code(
          p,
          ExpectedOpenParen.to_message(),
          start_loc,
          ExpectedOpenParen,
        ),
      )
  }

  // Parse condition
  let (condition, parser) = match parse_expression(parser) {
    Ok((expr, p)) => (expr, p)
    Err(p) => return Err(p)
  }

  // Expect ')'
  let parser = match expect(parser, fn(t) { matches_close_paren(t) }) {
    Ok(p) => advance_parser(p)
    Err(p) =>
      return Err(
        add_error_with_code(
          p,
          ExpectedCloseParen.to_message(),
          start_loc,
          ExpectedCloseParen,
        ),
      )
  }

  // Parse then statement
  let (then_statement, parser) = match parse_statement(parser) {
    Ok((stmt, p)) => (stmt, p)
    Err(p) => return Err(p)
  }

  // Optional else clause
  let (else_statement, parser) = match current_token(parser) {
    KeywordElse(_) => {
      let parser = advance_parser(parser)
      match parse_statement(parser) {
        Ok((stmt, p)) => (Some(stmt), p)
        Err(p) => (None, p)
      }
    }
    _ => (None, parser)
  }
  Ok(
    (
      Node::IfStatement(IfStatement::{
        condition,
        then_statement,
        else_statement,
        location: start_loc,
      }),
      parser,
    ),
  )
}

///|
/// Parse return statement
fn parse_return_statement(parser : Parser) -> Result[(Node, Parser), Parser] {
  let start_loc = current_token(parser).location()

  // TS1108: A 'return' statement can only be used within a function body
  let parser = if not(parser.context.in_function) {
    add_error_with_code(
      parser,
      ReturnOutsideFunction.to_message(),
      start_loc,
      ReturnOutsideFunction,
    )
  } else {
    parser
  }
  let parser = advance_parser(parser) // Skip 'return'

  // Check if there's an expression
  let (expression, parser) = match current_token(parser) {
    Semicolon(_) => (None, parser)
    _ =>
      match parse_expression(parser) {
        Ok((expr, p)) => (Some(expr), p)
        Err(p) => (None, p)
      }
  }
  let parser = expect_semicolon(parser)
  Ok(
    (
      Node::ReturnStatement(ReturnStatement::{ expression, location: start_loc }),
      parser,
    ),
  )
}

///|
/// Parse expression statement
fn parse_expression_statement(
  parser : Parser,
) -> Result[(Node, Parser), Parser] {
  let start_loc = current_token(parser).location()
  match parse_expression(parser) {
    Ok((expr, parser)) => {
      let parser = expect_semicolon(parser)
      Ok(
        (
          Node::ExpressionStatement(ExpressionStatement::{
            expression: expr,
            location: start_loc,
          }),
          parser,
        ),
      )
    }
    Err(parser) => Err(parser)
  }
}

///|
/// Parse type (enhanced with union support)

///|
/// Parse identifier (includes contextual keywords that can be used as identifiers)
fn parse_identifier(parser : Parser) -> Result[(Identifier, Parser), Parser] {
  // Try to get identifier from regular identifiers and contextual keywords
  match try_get_identifier_name(current_token(parser)) {
    Some((name, loc)) =>
      Ok((Identifier::{ name, location: loc }, advance_parser(parser)))
    None => {
      let loc = current_token(parser).location()
      Err(
        add_error_with_code(
          parser,
          "Identifier expected",
          loc,
          IdentifierExpected,
        ),
      )
    }
  }
}

///|
/// Parse an entity name starting from a given identifier token
/// The first_token is the current token that has NOT been consumed yet
fn parse_entity_name_from(
  parser : Parser,
  first_token : Token,
) -> (Node, Parser) {
  match first_token {
    Identifier(name, loc) => {
      let mut parser = advance_parser(parser) // consume the first identifier
      let mut result : Node = Node::Identifier(Identifier::{
        name,
        location: loc,
      })
      // Parse any following .identifier chains
      while true {
        match current_token(parser) {
          Dot(_) => {
            parser = advance_parser(parser) // consume '.'
            match current_token(parser) {
              Identifier(prop_name, prop_loc) => {
                parser = advance_parser(parser)
                let start_loc = get_node_location(result)
                result = Node::PropertyAccessExpression(PropertyAccessExpression::{
                  expression: result,
                  name: prop_name,
                  location: SourceLocation::new(
                    start_loc.file_path,
                    start_loc.start,
                    prop_loc.end,
                  ),
                })
              }
              _ => break
            }
          }
          _ => break
        }
      }
      (result, parser)
    }
    _ => {
      // Return empty identifier as fallback
      let loc = current_token(parser).location()
      (Node::Identifier(Identifier::{ name: "", location: loc }), parser)
    }
  }
}

///|
/// Parse an entity name (qualified name like M, M.N, M.N.O)
/// Used for import equals declarations: import X = M.N
fn parse_entity_name(parser : Parser) -> (Node, Parser) {
  // Start with an identifier
  match current_token(parser) {
    Identifier(name, loc) => {
      let mut parser = advance_parser(parser)
      let mut result : Node = Node::Identifier(Identifier::{
        name,
        location: loc,
      })
      // Parse any following .identifier chains
      while true {
        match current_token(parser) {
          Dot(_) => {
            parser = advance_parser(parser) // consume '.'
            match current_token(parser) {
              Identifier(prop_name, prop_loc) => {
                parser = advance_parser(parser)
                let start_loc = get_node_location(result)
                result = Node::PropertyAccessExpression(PropertyAccessExpression::{
                  expression: result,
                  name: prop_name,
                  location: SourceLocation::new(
                    start_loc.file_path,
                    start_loc.start,
                    prop_loc.end,
                  ),
                })
              }
              _ => break
            }
          }
          _ => break
        }
      }
      (result, parser)
    }
    _ => {
      // Return empty identifier as fallback
      let loc = current_token(parser).location()
      (Node::Identifier(Identifier::{ name: "", location: loc }), parser)
    }
  }
}

// ============================================================================
// Stub implementations for declarations (to be implemented)
// ============================================================================

///|
/// Parse a list of decorators (@decorator)
fn parse_decorators(parser : Parser) -> (Array[Node], Parser) {
  let decorators : Array[Node] = []
  let mut parser = parser
  while true {
    match current_token(parser) {
      At(start_loc) => {
        parser = advance_parser(parser) // consume '@'
        // Parse the decorator expression (can be identifier, property access, or call)
        match parse_expression(parser) {
          Ok((expr, p)) => {
            decorators.push(
              Node::Decorator(Decorator::{
                expression: expr,
                location: start_loc,
              }),
            )
            parser = p
          }
          Err(_) => break
        }
      }
      _ => break
    }
  }
  (decorators, parser)
}

///|
fn parse_class_declaration_with_decorators(
  parser : Parser,
  is_abstract : Bool,
  decorators : Array[Node],
) -> Result[(Node, Parser), Parser] {
  // [abstract] class Name [extends Super] [implements I1, I2] { members }
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'class'

  // Parse class name
  let (name, parser) = match current_token(parser) {
    Identifier(n, loc) =>
      (
        Some(Node::Identifier(Identifier::{ name: n, location: loc })),
        advance_parser(parser),
      )
    _ => (None, parser) // Anonymous class allowed in expressions
  }

  // Parse type parameters if present (e.g., class Box<T>)
  let (type_parameters, parser) = match current_token(parser) {
    LessThan(_) => parse_type_parameters(parser)
    _ => ([], parser)
  }

  // Parse heritage clauses (extends, implements)
  let (heritage_clauses, parser) = parse_heritage_clauses(parser)

  // Parse class body
  match current_token(parser) {
    OpenBrace(_) => {
      let parser = advance_parser(parser)
      let (members, parser) = parse_class_members(parser)
      match current_token(parser) {
        CloseBrace(loc) => {
          let parser = advance_parser(parser)
          Ok(
            (
              Node::ClassDeclaration(ClassDeclaration::{
                name,
                type_parameters,
                heritage_clauses,
                members,
                is_abstract,
                decorators,
                modifiers: [],
                location: SourceLocation::new(
                  start_loc.file_path,
                  start_loc.start,
                  loc.end,
                ),
              }),
              parser,
            ),
          )
        }
        _ =>
          Err(
            add_error_with_code(
              parser,
              ExpectedCloseBrace.to_message(),
              current_token(parser).location(),
              ExpectedCloseBrace,
            ),
          )
      }
    }
    _ =>
      Err(
        add_error_with_code(
          parser,
          ExpectedOpenBrace.to_message(),
          current_token(parser).location(),
          ExpectedOpenBrace,
        ),
      )
  }
}

///|
/// Parse heritage clauses (extends, implements)
fn parse_heritage_clauses(parser : Parser) -> (Array[HeritageClause], Parser) {
  parse_heritage_clauses_aux(parser, [])
}

///|
fn parse_heritage_clauses_aux(
  parser : Parser,
  acc : Array[HeritageClause],
) -> (Array[HeritageClause], Parser) {
  match current_token(parser) {
    KeywordExtends(_) => {
      let start_loc = current_token(parser).location()
      let parser = advance_parser(parser)
      let (types, parser) = parse_heritage_types(parser)
      acc.push(HeritageClause::{
        kind: HeritageKind::Extends,
        types,
        location: start_loc,
      })
      parse_heritage_clauses_aux(parser, acc)
    }
    KeywordImplements(_) => {
      let start_loc = current_token(parser).location()
      let parser = advance_parser(parser)
      let (types, parser) = parse_heritage_types(parser)
      acc.push(HeritageClause::{
        kind: HeritageKind::Implements,
        types,
        location: start_loc,
      })
      parse_heritage_clauses_aux(parser, acc)
    }
    _ => (acc, parser)
  }
}

///|
/// Parse comma-separated list of types (for extends/implements)
fn parse_heritage_types(parser : Parser) -> (Array[Node], Parser) {
  parse_heritage_types_aux(parser, [])
}

///|
fn parse_heritage_types_aux(
  parser : Parser,
  acc : Array[Node],
) -> (Array[Node], Parser) {
  match current_token(parser) {
    // Handle 'null' as a base type (e.g., class D extends null {})
    KeywordNull(loc) => {
      let parser = advance_parser(parser)
      acc.push(
        Node::TypeReference(TypeReference::{
          type_name: "null",
          type_arguments: [],
          location: loc,
        }),
      )
      match current_token(parser) {
        Comma(_) => parse_heritage_types_aux(advance_parser(parser), acc)
        _ => (acc, parser)
      }
    }
    // Handle parenthesized expression (e.g., class C extends (foo()).B {})
    OpenParen(_) =>
      match parse_expression(parser) {
        Ok((expr, parser)) => {
          acc.push(expr)
          match current_token(parser) {
            Comma(_) => parse_heritage_types_aux(advance_parser(parser), acc)
            _ => (acc, parser)
          }
        }
        Err(p) => (acc, p)
      }
    Identifier(name, loc) => {
      let parser = advance_parser(parser)
      // Parse property access chain (e.g., cdk.Stack, aws.lambda.Function)
      let (full_name, parser, end_loc) = parse_heritage_type_name(
        parser, name, loc,
      )
      // Parse generic type arguments if present (e.g., Stack<Props>)
      let (type_arguments, parser) = match current_token(parser) {
        LessThan(_) => parse_heritage_type_arguments(parser)
        _ => ([], parser)
      }
      acc.push(
        Node::TypeReference(TypeReference::{
          type_name: full_name,
          type_arguments,
          location: end_loc,
        }),
      )
      match current_token(parser) {
        Comma(_) => parse_heritage_types_aux(advance_parser(parser), acc)
        _ => (acc, parser)
      }
    }
    _ => (acc, parser)
  }
}

///|
/// Parse a heritage type name with property access (e.g., cdk.Stack -> "cdk.Stack")
fn parse_heritage_type_name(
  parser : Parser,
  base_name : String,
  start_loc : SourceLocation,
) -> (String, Parser, SourceLocation) {
  match current_token(parser) {
    Dot(_) => {
      let parser = advance_parser(parser)
      match current_token(parser) {
        Identifier(prop_name, prop_loc) => {
          let parser = advance_parser(parser)
          let combined_name = base_name + "." + prop_name
          parse_heritage_type_name(parser, combined_name, prop_loc)
        }
        _ => (base_name, parser, start_loc)
      }
    }
    _ => (base_name, parser, start_loc)
  }
}

///|
/// Parse type arguments in heritage clause (e.g., <Props, Options>)
fn parse_heritage_type_arguments(parser : Parser) -> (Array[Node], Parser) {
  // Expect <
  let parser = match current_token(parser) {
    LessThan(_) => advance_parser(parser)
    _ => return ([], parser)
  }
  let type_args : Array[Node] = []
  let mut parser = parser
  // Parse comma-separated types until >
  while true {
    match current_token(parser) {
      GreaterThan(_) => {
        parser = advance_parser(parser)
        break
      }
      _ =>
        match parse_type(parser) {
          Ok((ty, p)) => {
            type_args.push(ty)
            parser = p
            match current_token(parser) {
              Comma(_) => parser = advance_parser(parser)
              GreaterThan(_) => {
                parser = advance_parser(parser)
                break
              }
              _ => break // Error recovery
            }
          }
          Err(p) => {
            parser = p
            break
          }
        }
    }
  }
  (type_args, parser)
}

///|
/// Parse class members
fn parse_class_members(parser : Parser) -> (Array[Node], Parser) {
  parse_class_members_aux(parser, [])
}

///|
fn parse_class_members_aux(
  parser : Parser,
  acc : Array[Node],
) -> (Array[Node], Parser) {
  // First check for member decorators
  match current_token(parser) {
    At(_) => {
      let (decorators, parser) = parse_decorators(parser)
      parse_class_member_with_decorators(parser, acc, decorators)
    }
    _ => parse_class_member_with_decorators(parser, acc, [])
  }
}

///|
/// Parse a single class member with optional decorators
fn parse_class_member_with_decorators(
  parser : Parser,
  acc : Array[Node],
  decorators : Array[Node],
) -> (Array[Node], Parser) {
  match current_token(parser) {
    CloseBrace(_) | EOF(_) => (acc, parser)

    // Static modifier or static block
    KeywordStatic(start_loc) => {
      let parser = advance_parser(parser)
      // Check for static block: static { ... }
      match current_token(parser) {
        // Static initialization block
        OpenBrace(_) =>
          match parse_block_statement(parser) {
            Ok((body, parser)) => {
              acc.push(
                Node::StaticBlock(StaticBlock::{ body, location: start_loc }),
              )
              parse_class_members_aux(parser, acc)
            }
            Err(p) => parse_class_members_aux(p, acc)
          }
        // Static getter: static get name() { ... }
        Identifier("get", get_loc) => {
          let parser = advance_parser(parser)
          match current_token(parser) {
            // static get ["computed"]()
            OpenBracket(_) => {
              let parser = advance_parser(parser)
              match parse_expression(parser) {
                Ok((name_expr, parser)) => {
                  let parser = match current_token(parser) {
                    CloseBracket(_) => advance_parser(parser)
                    _ => parser
                  }
                  let computed_name = get_computed_property_name(name_expr)
                  match current_token(parser) {
                    OpenParen(_) => {
                      let parser = advance_parser(parser)
                      let (params, parser) = parse_parameter_list(parser)
                      let parser = if params.length() > 0 {
                        add_error_with_code(
                          parser,
                          GetAccessorCannotHaveParams.to_message(),
                          get_loc,
                          GetAccessorCannotHaveParams,
                        )
                      } else {
                        parser
                      }
                      let (return_type, parser) = match current_token(parser) {
                        Colon(_) => {
                          let parser = advance_parser(parser)
                          match parse_type(parser) {
                            Ok((ty, p)) => (Some(ty), p)
                            Err(p) => (None, p)
                          }
                        }
                        _ => (None, parser)
                      }
                      let (body, parser) = match current_token(parser) {
                        OpenBrace(_) =>
                          match parse_function_body(parser) {
                            Ok((b, p)) => (Some(b), p)
                            Err(p) => (None, p)
                          }
                        _ => (None, parser)
                      }
                      acc.push(
                        Node::GetAccessor(GetAccessor::{
                          name: computed_name,
                          computed_name_expr: Some(name_expr), // Preserve for TS2464 validation
                          return_type,
                          body,
                          decorators,
                          modifiers: [Modifier::Static],
                          location: get_loc,
                        }),
                      )
                      parse_class_members_aux(parser, acc)
                    }
                    _ => parse_class_members_aux(parser, acc)
                  }
                }
                Err(p) => parse_class_members_aux(p, acc)
              }
            }
            // static get name()
            Identifier(name, _) => {
              let parser = advance_parser(parser)
              match current_token(parser) {
                OpenParen(_) => {
                  let parser = advance_parser(parser)
                  let (params, parser) = parse_parameter_list(parser)
                  let parser = if params.length() > 0 {
                    add_error_with_code(
                      parser,
                      GetAccessorCannotHaveParams.to_message(),
                      get_loc,
                      GetAccessorCannotHaveParams,
                    )
                  } else {
                    parser
                  }
                  let (return_type, parser) = match current_token(parser) {
                    Colon(_) => {
                      let parser = advance_parser(parser)
                      match parse_type(parser) {
                        Ok((ty, p)) => (Some(ty), p)
                        Err(p) => (None, p)
                      }
                    }
                    _ => (None, parser)
                  }
                  let (body, parser) = match current_token(parser) {
                    OpenBrace(_) =>
                      match parse_function_body(parser) {
                        Ok((b, p)) => (Some(b), p)
                        Err(p) => (None, p)
                      }
                    _ => (None, parser)
                  }
                  acc.push(
                    Node::GetAccessor(GetAccessor::{
                      name,
                      computed_name_expr: None,
                      return_type,
                      body,
                      decorators,
                      modifiers: [Modifier::Static],
                      location: get_loc,
                    }),
                  )
                  parse_class_members_aux(parser, acc)
                }
                // "get" as property name when not followed by identifier then (
                _ => {
                  let name = "get"
                  let (type_annotation, parser) = match current_token(parser) {
                    Colon(_) => {
                      let parser = advance_parser(parser)
                      match parse_type(parser) {
                        Ok((ty, p)) => (Some(ty), p)
                        Err(p) => (None, p)
                      }
                    }
                    _ => (None, parser)
                  }
                  let (initializer, parser) = match current_token(parser) {
                    Equals(_) => {
                      let parser = advance_parser(parser)
                      match parse_assignment_expression(parser) {
                        Ok((expr, p)) => (Some(expr), p)
                        Err(p) => (None, p)
                      }
                    }
                    _ => (None, parser)
                  }
                  acc.push(
                    Node::PropertyDeclaration(PropertyDeclaration::{
                      name,
                      computed_name_expr: None,
                      type_annotation,
                      initializer,
                      is_optional: false,
                      decorators,
                      modifiers: [Modifier::Static],
                      location: get_loc,
                    }),
                  )
                  let parser = match current_token(parser) {
                    Semicolon(_) => advance_parser(parser)
                    _ => parser
                  }
                  parse_class_members_aux(parser, acc)
                }
              }
            }
            // "get" as property name when followed by something else
            _ => {
              let name = "get"
              let (type_annotation, parser) = match current_token(parser) {
                Colon(_) => {
                  let parser = advance_parser(parser)
                  match parse_type(parser) {
                    Ok((ty, p)) => (Some(ty), p)
                    Err(p) => (None, p)
                  }
                }
                _ => (None, parser)
              }
              let (initializer, parser) = match current_token(parser) {
                Equals(_) => {
                  let parser = advance_parser(parser)
                  match parse_assignment_expression(parser) {
                    Ok((expr, p)) => (Some(expr), p)
                    Err(p) => (None, p)
                  }
                }
                _ => (None, parser)
              }
              acc.push(
                Node::PropertyDeclaration(PropertyDeclaration::{
                  name,
                  computed_name_expr: None,
                  type_annotation,
                  initializer,
                  is_optional: false,
                  decorators,
                  modifiers: [Modifier::Static],
                  location: get_loc,
                }),
              )
              let parser = match current_token(parser) {
                Semicolon(_) => advance_parser(parser)
                _ => parser
              }
              parse_class_members_aux(parser, acc)
            }
          }
        }
        // Static setter: static set name(v) { ... }
        Identifier("set", set_loc) => {
          let parser = advance_parser(parser)
          match current_token(parser) {
            // static set ["computed"](v)
            OpenBracket(_) => {
              let parser = advance_parser(parser)
              match parse_expression(parser) {
                Ok((name_expr, parser)) => {
                  let parser = match current_token(parser) {
                    CloseBracket(_) => advance_parser(parser)
                    _ => parser
                  }
                  let computed_name = get_computed_property_name(name_expr)
                  match current_token(parser) {
                    OpenParen(_) => {
                      let parser = advance_parser(parser)
                      let (params, parser) = parse_parameter_list(parser)
                      let parser = if params.length() != 1 {
                        add_error_with_code(
                          parser,
                          SetAccessorMustHaveOneParam.to_message(),
                          set_loc,
                          SetAccessorMustHaveOneParam,
                        )
                      } else {
                        parser
                      }
                      let parameter = if params.length() > 0 {
                        params[0]
                      } else {
                        Node::Identifier(Identifier::{
                          name: "value",
                          location: set_loc,
                        })
                      }
                      let (has_return_type, parser) = match
                        current_token(parser) {
                        Colon(_) => {
                          let parser = advance_parser(parser)
                          match parse_type(parser) {
                            Ok((_, p)) => (true, p)
                            Err(p) => (true, p)
                          }
                        }
                        _ => (false, parser)
                      }
                      let parser = if has_return_type {
                        add_error_with_code(
                          parser,
                          SetAccessorCannotHaveReturnType.to_message(),
                          set_loc,
                          SetAccessorCannotHaveReturnType,
                        )
                      } else {
                        parser
                      }
                      let (body, parser) = match current_token(parser) {
                        OpenBrace(_) =>
                          match parse_function_body(parser) {
                            Ok((b, p)) => (Some(b), p)
                            Err(p) => (None, p)
                          }
                        _ => (None, parser)
                      }
                      acc.push(
                        Node::SetAccessor(SetAccessor::{
                          name: computed_name,
                          computed_name_expr: Some(name_expr), // Preserve for TS2464 validation
                          parameter,
                          body,
                          decorators,
                          modifiers: [Modifier::Static],
                          location: set_loc,
                        }),
                      )
                      parse_class_members_aux(parser, acc)
                    }
                    _ => parse_class_members_aux(parser, acc)
                  }
                }
                Err(p) => parse_class_members_aux(p, acc)
              }
            }
            // static set name(v)
            Identifier(name, _) => {
              let parser = advance_parser(parser)
              match current_token(parser) {
                OpenParen(_) => {
                  let parser = advance_parser(parser)
                  let (params, parser) = parse_parameter_list(parser)
                  let parser = if params.length() != 1 {
                    add_error_with_code(
                      parser,
                      SetAccessorMustHaveOneParam.to_message(),
                      set_loc,
                      SetAccessorMustHaveOneParam,
                    )
                  } else {
                    parser
                  }
                  let parameter = if params.length() > 0 {
                    params[0]
                  } else {
                    Node::Identifier(Identifier::{
                      name: "value",
                      location: set_loc,
                    })
                  }
                  let (has_return_type, parser) = match current_token(parser) {
                    Colon(_) => {
                      let parser = advance_parser(parser)
                      match parse_type(parser) {
                        Ok((_, p)) => (true, p)
                        Err(p) => (true, p)
                      }
                    }
                    _ => (false, parser)
                  }
                  let parser = if has_return_type {
                    add_error_with_code(
                      parser,
                      SetAccessorCannotHaveReturnType.to_message(),
                      set_loc,
                      SetAccessorCannotHaveReturnType,
                    )
                  } else {
                    parser
                  }
                  let (body, parser) = match current_token(parser) {
                    OpenBrace(_) =>
                      match parse_function_body(parser) {
                        Ok((b, p)) => (Some(b), p)
                        Err(p) => (None, p)
                      }
                    _ => (None, parser)
                  }
                  acc.push(
                    Node::SetAccessor(SetAccessor::{
                      name,
                      computed_name_expr: None,
                      parameter,
                      body,
                      decorators,
                      modifiers: [Modifier::Static],
                      location: set_loc,
                    }),
                  )
                  parse_class_members_aux(parser, acc)
                }
                // "set" as property name when not followed by identifier then (
                _ => {
                  let name = "set"
                  let (type_annotation, parser) = match current_token(parser) {
                    Colon(_) => {
                      let parser = advance_parser(parser)
                      match parse_type(parser) {
                        Ok((ty, p)) => (Some(ty), p)
                        Err(p) => (None, p)
                      }
                    }
                    _ => (None, parser)
                  }
                  let (initializer, parser) = match current_token(parser) {
                    Equals(_) => {
                      let parser = advance_parser(parser)
                      match parse_assignment_expression(parser) {
                        Ok((expr, p)) => (Some(expr), p)
                        Err(p) => (None, p)
                      }
                    }
                    _ => (None, parser)
                  }
                  acc.push(
                    Node::PropertyDeclaration(PropertyDeclaration::{
                      name,
                      computed_name_expr: None,
                      type_annotation,
                      initializer,
                      is_optional: false,
                      decorators,
                      modifiers: [Modifier::Static],
                      location: set_loc,
                    }),
                  )
                  let parser = match current_token(parser) {
                    Semicolon(_) => advance_parser(parser)
                    _ => parser
                  }
                  parse_class_members_aux(parser, acc)
                }
              }
            }
            // "set" as property name when followed by something else
            _ => {
              let name = "set"
              let (type_annotation, parser) = match current_token(parser) {
                Colon(_) => {
                  let parser = advance_parser(parser)
                  match parse_type(parser) {
                    Ok((ty, p)) => (Some(ty), p)
                    Err(p) => (None, p)
                  }
                }
                _ => (None, parser)
              }
              let (initializer, parser) = match current_token(parser) {
                Equals(_) => {
                  let parser = advance_parser(parser)
                  match parse_assignment_expression(parser) {
                    Ok((expr, p)) => (Some(expr), p)
                    Err(p) => (None, p)
                  }
                }
                _ => (None, parser)
              }
              acc.push(
                Node::PropertyDeclaration(PropertyDeclaration::{
                  name,
                  computed_name_expr: None,
                  type_annotation,
                  initializer,
                  is_optional: false,
                  decorators,
                  modifiers: [Modifier::Static],
                  location: set_loc,
                }),
              )
              let parser = match current_token(parser) {
                Semicolon(_) => advance_parser(parser)
                _ => parser
              }
              parse_class_members_aux(parser, acc)
            }
          }
        }
        // Static member with identifier (not get/set)
        Identifier(name, loc) => {
          let parser = advance_parser(parser)
          match current_token(parser) {
            // Static method
            OpenParen(_) => {
              let parser = advance_parser(parser)
              let (parameters, parser) = parse_parameter_list(parser)
              let (return_type, parser) = match current_token(parser) {
                Colon(_) => {
                  let parser = advance_parser(parser)
                  match parse_type(parser) {
                    Ok((ty, p)) => (Some(ty), p)
                    Err(p) => (None, p)
                  }
                }
                _ => (None, parser)
              }
              let (body, parser) = match current_token(parser) {
                OpenBrace(_) =>
                  match parse_function_body(parser) {
                    Ok((b, p)) => (Some(b), p)
                    Err(p) => (None, p)
                  }
                _ => (None, parser)
              }
              acc.push(
                Node::MethodDeclaration(MethodDeclaration::{
                  name,
                  computed_name_expr: None,
                  type_parameters: [],
                  parameters,
                  return_type,
                  body,
                  decorators,
                  modifiers: [Modifier::Static],
                  is_async: false,
                  is_generator: false,
                  is_optional: false,
                  location: loc,
                }),
              )
              parse_class_members_aux(parser, acc)
            }
            // Static generic method: static foo<T>(x: T) { }
            LessThan(_) => {
              let (type_parameters, parser) = parse_type_parameters(parser)
              // After type parameters, expect (
              let parser = match current_token(parser) {
                OpenParen(_) => advance_parser(parser)
                _ => parser
              }
              let (parameters, parser) = parse_parameter_list(parser)
              let (return_type, parser) = match current_token(parser) {
                Colon(_) => {
                  let parser = advance_parser(parser)
                  match parse_type(parser) {
                    Ok((ty, p)) => (Some(ty), p)
                    Err(p) => (None, p)
                  }
                }
                _ => (None, parser)
              }
              let (body, parser) = match current_token(parser) {
                OpenBrace(_) =>
                  match parse_function_body(parser) {
                    Ok((b, p)) => (Some(b), p)
                    Err(p) => (None, p)
                  }
                _ => (None, parser)
              }
              acc.push(
                Node::MethodDeclaration(MethodDeclaration::{
                  name,
                  computed_name_expr: None,
                  type_parameters,
                  parameters,
                  return_type,
                  body,
                  decorators,
                  modifiers: [Modifier::Static],
                  is_async: false,
                  is_generator: false,
                  is_optional: false,
                  location: loc,
                }),
              )
              parse_class_members_aux(parser, acc)
            }
            // Static property
            _ => {
              let (type_annotation, parser) = match current_token(parser) {
                Colon(_) => {
                  let parser = advance_parser(parser)
                  match parse_type(parser) {
                    Ok((ty, p)) => (Some(ty), p)
                    Err(p) => (None, p)
                  }
                }
                _ => (None, parser)
              }
              let (initializer, parser) = match current_token(parser) {
                Equals(_) => {
                  let parser = advance_parser(parser)
                  match parse_assignment_expression(parser) {
                    Ok((expr, p)) => (Some(expr), p)
                    Err(p) => (None, p)
                  }
                }
                _ => (None, parser)
              }
              acc.push(
                Node::PropertyDeclaration(PropertyDeclaration::{
                  name,
                  computed_name_expr: None,
                  type_annotation,
                  initializer,
                  is_optional: false,
                  decorators,
                  modifiers: [Modifier::Static],
                  location: loc,
                }),
              )
              let parser = match current_token(parser) {
                Semicolon(_) => advance_parser(parser)
                _ => parser
              }
              parse_class_members_aux(parser, acc)
            }
          }
        }
        // Static accessor: static accessor name = value;
        KeywordAccessor(accessor_loc) => {
          let parser = advance_parser(parser)
          match current_token(parser) {
            Identifier(name, _) => {
              let parser = advance_parser(parser)
              // Optional type annotation
              let (type_annotation, parser) = match current_token(parser) {
                Colon(_) => {
                  let parser = advance_parser(parser)
                  match parse_type(parser) {
                    Ok((ty, p)) => (Some(ty), p)
                    Err(p) => (None, p)
                  }
                }
                _ => (None, parser)
              }
              // Optional initializer
              let (initializer, parser) = match current_token(parser) {
                Equals(_) => {
                  let parser = advance_parser(parser)
                  match parse_assignment_expression(parser) {
                    Ok((expr, p)) => (Some(expr), p)
                    Err(p) => (None, p)
                  }
                }
                _ => (None, parser)
              }
              acc.push(
                Node::AutoAccessor(AutoAccessor::{
                  name,
                  type_annotation,
                  initializer,
                  decorators,
                  modifiers: [Modifier::Static],
                  location: accessor_loc,
                }),
              )
              let parser = match current_token(parser) {
                Semicolon(_) => advance_parser(parser)
                _ => parser
              }
              parse_class_members_aux(parser, acc)
            }
            _ => parse_class_members_aux(parser, acc)
          }
        }
        // Static reserved word 'return' used as property/method name
        KeywordReturn(loc) => {
          let name = "return"
          let parser = advance_parser(parser)
          match current_token(parser) {
            // Static method using reserved word as name
            OpenParen(_) => {
              let parser = advance_parser(parser)
              let (parameters, parser) = parse_parameter_list(parser)
              let (return_type, parser) = match current_token(parser) {
                Colon(_) => {
                  let parser = advance_parser(parser)
                  match parse_type(parser) {
                    Ok((ty, p)) => (Some(ty), p)
                    Err(p) => (None, p)
                  }
                }
                _ => (None, parser)
              }
              let (body, parser) = match current_token(parser) {
                OpenBrace(_) =>
                  match parse_function_body(parser) {
                    Ok((b, p)) => (Some(b), p)
                    Err(p) => (None, p)
                  }
                _ => (None, parser)
              }
              acc.push(
                Node::MethodDeclaration(MethodDeclaration::{
                  name,
                  computed_name_expr: None,
                  type_parameters: [],
                  parameters,
                  return_type,
                  body,
                  decorators,
                  modifiers: [Modifier::Static],
                  is_async: false,
                  is_generator: false,
                  is_optional: false,
                  location: loc,
                }),
              )
              parse_class_members_aux(parser, acc)
            }
            // Static property using reserved word as name
            _ => {
              let (type_annotation, parser) = match current_token(parser) {
                Colon(_) => {
                  let parser = advance_parser(parser)
                  match parse_type(parser) {
                    Ok((ty, p)) => (Some(ty), p)
                    Err(p) => (None, p)
                  }
                }
                _ => (None, parser)
              }
              let (initializer, parser) = match current_token(parser) {
                Equals(_) => {
                  let parser = advance_parser(parser)
                  match parse_assignment_expression(parser) {
                    Ok((expr, p)) => (Some(expr), p)
                    Err(p) => (None, p)
                  }
                }
                _ => (None, parser)
              }
              acc.push(
                Node::PropertyDeclaration(PropertyDeclaration::{
                  name,
                  computed_name_expr: None,
                  type_annotation,
                  initializer,
                  is_optional: false,
                  decorators,
                  modifiers: [Modifier::Static],
                  location: loc,
                }),
              )
              let parser = match current_token(parser) {
                Semicolon(_) => advance_parser(parser)
                _ => parser
              }
              parse_class_members_aux(parser, acc)
            }
          }
        }
        // Static computed property: static ["computed"]() or static ["computed"]: type
        OpenBracket(bracket_loc) => {
          let parser = advance_parser(parser)
          match parse_expression(parser) {
            Ok((name_expr, parser)) => {
              let parser = match current_token(parser) {
                CloseBracket(_) => advance_parser(parser)
                _ => parser
              }
              let computed_name = get_computed_property_name(name_expr)
              match current_token(parser) {
                // Static computed method: static ["computed"]()
                OpenParen(_) => {
                  let parser = advance_parser(parser)
                  let (parameters, parser) = parse_parameter_list(parser)
                  let (return_type, parser) = match current_token(parser) {
                    Colon(_) => {
                      let parser = advance_parser(parser)
                      match parse_type(parser) {
                        Ok((ty, p)) => (Some(ty), p)
                        Err(p) => (None, p)
                      }
                    }
                    _ => (None, parser)
                  }
                  let (body, parser) = match current_token(parser) {
                    OpenBrace(_) =>
                      match parse_function_body(parser) {
                        Ok((b, p)) => (Some(b), p)
                        Err(p) => (None, p)
                      }
                    _ => (None, parser)
                  }
                  acc.push(
                    Node::MethodDeclaration(MethodDeclaration::{
                      name: computed_name,
                      computed_name_expr: Some(name_expr),
                      type_parameters: [],
                      parameters,
                      return_type,
                      body,
                      decorators,
                      modifiers: [Modifier::Static],
                      is_async: false,
                      is_generator: false,
                      is_optional: false,
                      location: bracket_loc,
                    }),
                  )
                  parse_class_members_aux(parser, acc)
                }
                // Static computed property: static ["computed"]: type
                _ => {
                  let (type_annotation, parser) = match current_token(parser) {
                    Colon(_) => {
                      let parser = advance_parser(parser)
                      match parse_type(parser) {
                        Ok((ty, p)) => (Some(ty), p)
                        Err(p) => (None, p)
                      }
                    }
                    _ => (None, parser)
                  }
                  let (initializer, parser) = match current_token(parser) {
                    Equals(_) => {
                      let parser = advance_parser(parser)
                      match parse_assignment_expression(parser) {
                        Ok((expr, p)) => (Some(expr), p)
                        Err(p) => (None, p)
                      }
                    }
                    _ => (None, parser)
                  }
                  let parser = match current_token(parser) {
                    Semicolon(_) => advance_parser(parser)
                    _ => parser
                  }
                  acc.push(
                    Node::PropertyDeclaration(PropertyDeclaration::{
                      name: computed_name,
                      computed_name_expr: None,
                      type_annotation,
                      initializer,
                      is_optional: false,
                      decorators,
                      modifiers: [Modifier::Static],
                      location: bracket_loc,
                    }),
                  )
                  parse_class_members_aux(parser, acc)
                }
              }
            }
            Err(p) => parse_class_members_aux(p, acc)
          }
        }
        _ => parse_class_members_aux(parser, acc)
      }
    }

    // Constructor
    Identifier("constructor", loc) => {
      let parser = advance_parser(parser)
      // TS1092: Type parameters cannot appear on a constructor declaration
      let parser = match current_token(parser) {
        LessThan(_) => {
          let parser = add_error_with_code(
            parser,
            TypeParamsOnConstructor.to_message(),
            loc,
            TypeParamsOnConstructor,
          )
          // Parse and discard the type parameters for error recovery
          match parse_type_parameters(parser) {
            (_, p) => p
          }
        }
        _ => parser
      }
      match current_token(parser) {
        OpenParen(_) => {
          // Consume the OpenParen, then parse parameters
          let parser = advance_parser(parser)
          let (parameters, parser) = parse_parameter_list(parser)
          // Parse body (use parse_function_body for return statement validation)
          let (body, parser) = match current_token(parser) {
            OpenBrace(_) =>
              match parse_function_body(parser) {
                Ok((b, p)) => (Some(b), p)
                Err(p) => (None, p)
              }
            _ => (None, parser)
          }
          acc.push(
            Node::ConstructorDeclaration(ConstructorDeclaration::{
              parameters,
              body,
              decorators,
              location: loc,
            }),
          )
          parse_class_members_aux(parser, acc)
        }
        _ => parse_class_members_aux(parser, acc)
      }
    }

    // Getter: get name() { ... } or get ["computedName"]() { ... }
    Identifier("get", start_loc) => {
      let parser = advance_parser(parser)
      match current_token(parser) {
        // Computed getter: get ["computedName"]() { ... }
        OpenBracket(_) => {
          let parser = advance_parser(parser)
          match parse_expression(parser) {
            Ok((name_expr, parser)) => {
              let parser = match current_token(parser) {
                CloseBracket(_) => advance_parser(parser)
                _ => parser
              }
              let computed_name = get_computed_property_name(name_expr)
              match current_token(parser) {
                OpenParen(_) => {
                  let parser = advance_parser(parser)
                  let (params, parser) = parse_parameter_list(parser)
                  let parser = if params.length() > 0 {
                    add_error_with_code(
                      parser,
                      GetAccessorCannotHaveParams.to_message(),
                      start_loc,
                      GetAccessorCannotHaveParams,
                    )
                  } else {
                    parser
                  }
                  let (return_type, parser) = match current_token(parser) {
                    Colon(_) => {
                      let parser = advance_parser(parser)
                      match parse_type(parser) {
                        Ok((ty, p)) => (Some(ty), p)
                        Err(p) => (None, p)
                      }
                    }
                    _ => (None, parser)
                  }
                  let (body, parser) = match current_token(parser) {
                    OpenBrace(_) =>
                      match parse_function_body(parser) {
                        Ok((b, p)) => (Some(b), p)
                        Err(p) => (None, p)
                      }
                    _ => (None, parser)
                  }
                  acc.push(
                    Node::GetAccessor(GetAccessor::{
                      name: computed_name,
                      computed_name_expr: Some(name_expr), // Preserve for TS2464 validation
                      return_type,
                      body,
                      decorators,
                      modifiers: [],
                      location: start_loc,
                    }),
                  )
                  parse_class_members_aux(parser, acc)
                }
                _ => parse_class_members_aux(parser, acc)
              }
            }
            Err(p) => parse_class_members_aux(p, acc)
          }
        }
        Identifier(name, _) => {
          let parser = advance_parser(parser)
          match current_token(parser) {
            OpenParen(_) => {
              let parser = advance_parser(parser)
              // Parse any parameters (should be none for getter)
              let (params, parser) = parse_parameter_list(parser)
              // TS1094: A 'get' accessor cannot have parameters
              let parser = if params.length() > 0 {
                add_error_with_code(
                  parser,
                  GetAccessorCannotHaveParams.to_message(),
                  start_loc,
                  GetAccessorCannotHaveParams,
                )
              } else {
                parser
              }
              // Optional return type
              let (return_type, parser) = match current_token(parser) {
                Colon(_) => {
                  let parser = advance_parser(parser)
                  match parse_type(parser) {
                    Ok((ty, p)) => (Some(ty), p)
                    Err(p) => (None, p)
                  }
                }
                _ => (None, parser)
              }
              // Body
              let (body, parser) = match current_token(parser) {
                OpenBrace(_) =>
                  match parse_function_body(parser) {
                    Ok((b, p)) => (Some(b), p)
                    Err(p) => (None, p)
                  }
                _ => (None, parser)
              }
              acc.push(
                Node::GetAccessor(GetAccessor::{
                  name,
                  computed_name_expr: None,
                  return_type,
                  body,
                  decorators,
                  modifiers: [],
                  location: start_loc,
                }),
              )
              parse_class_members_aux(parser, acc)
            }
            // Not a getter, treat "get" as property/method name
            _ => {
              // Backtrack - treat "get" as the name
              let name = "get"
              let loc = start_loc
              match current_token(parser) {
                OpenParen(_) => {
                  let parser = advance_parser(parser)
                  let (parameters, parser) = parse_parameter_list(parser)
                  let (return_type, parser) = match current_token(parser) {
                    Colon(_) => {
                      let parser = advance_parser(parser)
                      match parse_type(parser) {
                        Ok((ty, p)) => (Some(ty), p)
                        Err(p) => (None, p)
                      }
                    }
                    _ => (None, parser)
                  }
                  let (body, parser) = match current_token(parser) {
                    OpenBrace(_) =>
                      match parse_function_body(parser) {
                        Ok((b, p)) => (Some(b), p)
                        Err(p) => (None, p)
                      }
                    _ => (None, parser)
                  }
                  acc.push(
                    Node::MethodDeclaration(MethodDeclaration::{
                      name,
                      computed_name_expr: None,
                      type_parameters: [],
                      parameters,
                      return_type,
                      body,
                      decorators,
                      modifiers: [],
                      is_async: false,
                      is_generator: false,
                      is_optional: false,
                      location: loc,
                    }),
                  )
                  parse_class_members_aux(parser, acc)
                }
                _ => parse_class_members_aux(parser, acc)
              }
            }
          }
        }
        // "get" followed by non-identifier - treat as property/method named "get"
        _ => parse_class_members_aux(parser, acc)
      }
    }

    // Setter: set name(value) { ... } or set ["computedName"](value) { ... }
    Identifier("set", start_loc) => {
      let parser = advance_parser(parser)
      match current_token(parser) {
        // Computed setter: set ["computedName"](value) { ... }
        OpenBracket(_) => {
          let parser = advance_parser(parser)
          match parse_expression(parser) {
            Ok((name_expr, parser)) => {
              let parser = match current_token(parser) {
                CloseBracket(_) => advance_parser(parser)
                _ => parser
              }
              let computed_name = get_computed_property_name(name_expr)
              match current_token(parser) {
                OpenParen(_) => {
                  let parser = advance_parser(parser)
                  let (params, parser) = parse_parameter_list(parser)
                  let parser = if params.length() != 1 {
                    add_error_with_code(
                      parser,
                      SetAccessorMustHaveOneParam.to_message(),
                      start_loc,
                      SetAccessorMustHaveOneParam,
                    )
                  } else {
                    parser
                  }
                  let parameter = if params.length() > 0 {
                    params[0]
                  } else {
                    Node::Identifier(Identifier::{
                      name: "value",
                      location: start_loc,
                    })
                  }
                  let (has_return_type, parser) = match current_token(parser) {
                    Colon(_) => {
                      let parser = advance_parser(parser)
                      match parse_type(parser) {
                        Ok((_, p)) => (true, p)
                        Err(p) => (true, p)
                      }
                    }
                    _ => (false, parser)
                  }
                  let parser = if has_return_type {
                    add_error_with_code(
                      parser,
                      SetAccessorCannotHaveReturnType.to_message(),
                      start_loc,
                      SetAccessorCannotHaveReturnType,
                    )
                  } else {
                    parser
                  }
                  let (body, parser) = match current_token(parser) {
                    OpenBrace(_) =>
                      match parse_function_body(parser) {
                        Ok((b, p)) => (Some(b), p)
                        Err(p) => (None, p)
                      }
                    _ => (None, parser)
                  }
                  acc.push(
                    Node::SetAccessor(SetAccessor::{
                      name: computed_name,
                      computed_name_expr: Some(name_expr), // Preserve for TS2464 validation
                      parameter,
                      body,
                      decorators,
                      modifiers: [],
                      location: start_loc,
                    }),
                  )
                  parse_class_members_aux(parser, acc)
                }
                _ => parse_class_members_aux(parser, acc)
              }
            }
            Err(p) => parse_class_members_aux(p, acc)
          }
        }
        Identifier(name, _) => {
          let parser = advance_parser(parser)
          match current_token(parser) {
            OpenParen(_) => {
              let parser = advance_parser(parser)
              // Parse parameters (should be exactly one for setter)
              let (params, parser) = parse_parameter_list(parser)
              // TS1095: A 'set' accessor must have exactly one parameter
              let parser = if params.length() != 1 {
                add_error_with_code(
                  parser,
                  SetAccessorMustHaveOneParam.to_message(),
                  start_loc,
                  SetAccessorMustHaveOneParam,
                )
              } else {
                parser
              }
              // Get the parameter (or create a dummy one)
              let parameter = if params.length() > 0 {
                params[0]
              } else {
                Node::Identifier(Identifier::{
                  name: "value",
                  location: start_loc,
                })
              }
              // Optional return type (usually void) - but should not be specified
              let (has_return_type, parser) = match current_token(parser) {
                Colon(_) => {
                  let parser = advance_parser(parser)
                  match parse_type(parser) {
                    Ok((_, p)) => (true, p)
                    Err(p) => (true, p)
                  }
                }
                _ => (false, parser)
              }
              // TS1093: A 'set' accessor cannot have a return type annotation
              let parser = if has_return_type {
                add_error_with_code(
                  parser,
                  SetAccessorCannotHaveReturnType.to_message(),
                  start_loc,
                  SetAccessorCannotHaveReturnType,
                )
              } else {
                parser
              }
              // Body
              let (body, parser) = match current_token(parser) {
                OpenBrace(_) =>
                  match parse_function_body(parser) {
                    Ok((b, p)) => (Some(b), p)
                    Err(p) => (None, p)
                  }
                _ => (None, parser)
              }
              acc.push(
                Node::SetAccessor(SetAccessor::{
                  name,
                  computed_name_expr: None,
                  parameter,
                  body,
                  decorators,
                  modifiers: [],
                  location: start_loc,
                }),
              )
              parse_class_members_aux(parser, acc)
            }
            _ => parse_class_members_aux(parser, acc)
          }
        }
        _ => parse_class_members_aux(parser, acc)
      }
    }

    // Auto-accessor: accessor name = value;
    KeywordAccessor(start_loc) => {
      let parser = advance_parser(parser)
      match current_token(parser) {
        Identifier(name, _) => {
          let parser = advance_parser(parser)
          // Optional type annotation
          let (type_annotation, parser) = match current_token(parser) {
            Colon(_) => {
              let parser = advance_parser(parser)
              match parse_type(parser) {
                Ok((ty, p)) => (Some(ty), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }
          // Optional initializer
          let (initializer, parser) = match current_token(parser) {
            Equals(_) => {
              let parser = advance_parser(parser)
              match parse_assignment_expression(parser) {
                Ok((expr, p)) => (Some(expr), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }
          acc.push(
            Node::AutoAccessor(AutoAccessor::{
              name,
              type_annotation,
              initializer,
              decorators,
              modifiers: [],
              location: start_loc,
            }),
          )
          let parser = match current_token(parser) {
            Semicolon(_) => advance_parser(parser)
            _ => parser
          }
          parse_class_members_aux(parser, acc)
        }
        _ => parse_class_members_aux(parser, acc)
      }
    }

    // Private modifier
    KeywordPrivate(_) => {
      let parser = advance_parser(parser)
      parse_class_member_with_modifiers(parser, acc, decorators, [
        Modifier::Private,
      ])
    }

    // Protected modifier
    KeywordProtected(_) => {
      let parser = advance_parser(parser)
      parse_class_member_with_modifiers(parser, acc, decorators, [
        Modifier::Protected,
      ])
    }

    // Public modifier
    KeywordPublic(_) => {
      let parser = advance_parser(parser)
      parse_class_member_with_modifiers(parser, acc, decorators, [
        Modifier::Public,
      ])
    }

    // Static modifier
    KeywordStatic(_) => {
      let parser = advance_parser(parser)
      parse_class_member_with_modifiers(parser, acc, decorators, [
        Modifier::Static,
      ])
    }

    // Readonly modifier
    KeywordReadonly(_) => {
      let parser = advance_parser(parser)
      parse_class_member_with_modifiers(parser, acc, decorators, [
        Modifier::Readonly,
      ])
    }

    // Abstract modifier
    KeywordAbstract(_) => {
      let parser = advance_parser(parser)
      parse_class_member_with_modifiers(parser, acc, decorators, [
        Modifier::Abstract,
      ])
    }

    // Async modifier
    KeywordAsync(_) => {
      let parser = advance_parser(parser)
      parse_class_member_with_modifiers(parser, acc, decorators, [
        Modifier::Async,
      ])
    }

    // TS1248: A class member cannot have the 'const' keyword
    KeywordConst(loc) => {
      let parser = add_error_with_code(
        parser,
        ClassMemberCannotHaveConst.to_message(),
        loc,
        ClassMemberCannotHaveConst,
      )
      let parser = advance_parser(parser)
      // Skip to next member
      parse_class_members_aux(parser, acc)
    }

    // Reserved word 'interface' used as property/method name (e.g., interface() { })
    KeywordInterface(loc) => {
      let name = "interface"
      let parser = advance_parser(parser)
      match current_token(parser) {
        // Method using reserved word as name
        OpenParen(_) => {
          let parser = advance_parser(parser)
          let (parameters, parser) = parse_parameter_list(parser)
          let (return_type, parser) = match current_token(parser) {
            Colon(_) => {
              let parser = advance_parser(parser)
              match parse_type(parser) {
                Ok((ty, p)) => (Some(ty), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }
          let (body, parser) = match current_token(parser) {
            OpenBrace(_) =>
              match parse_function_body(parser) {
                Ok((b, p)) => (Some(b), p)
                Err(p) => (None, p)
              }
            _ => (None, parser)
          }
          acc.push(
            Node::MethodDeclaration(MethodDeclaration::{
              name,
              computed_name_expr: None,
              type_parameters: [],
              parameters,
              return_type,
              body,
              decorators,
              modifiers: [],
              is_async: false,
              is_generator: false,
              is_optional: false,
              location: loc,
            }),
          )
          parse_class_members_aux(parser, acc)
        }
        // Property using reserved word as name
        _ => {
          let (type_annotation, parser) = match current_token(parser) {
            Colon(_) => {
              let parser = advance_parser(parser)
              match parse_type(parser) {
                Ok((ty, p)) => (Some(ty), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }
          let (initializer, parser) = match current_token(parser) {
            Equals(_) => {
              let parser = advance_parser(parser)
              match parse_assignment_expression(parser) {
                Ok((expr, p)) => (Some(expr), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }
          let parser = match current_token(parser) {
            Semicolon(_) => advance_parser(parser)
            _ => parser
          }
          acc.push(
            Node::PropertyDeclaration(PropertyDeclaration::{
              name,
              computed_name_expr: None,
              type_annotation,
              initializer,
              is_optional: false,
              decorators,
              modifiers: [],
              location: loc,
            }),
          )
          parse_class_members_aux(parser, acc)
        }
      }
    }

    // Reserved word 'return' used as property/method name (e.g., return() { } or return = 0)
    KeywordReturn(loc) => {
      let name = "return"
      let parser = advance_parser(parser)
      match current_token(parser) {
        // Method using reserved word as name
        OpenParen(_) => {
          let parser = advance_parser(parser)
          let (parameters, parser) = parse_parameter_list(parser)
          let (return_type, parser) = match current_token(parser) {
            Colon(_) => {
              let parser = advance_parser(parser)
              match parse_type(parser) {
                Ok((ty, p)) => (Some(ty), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }
          let (body, parser) = match current_token(parser) {
            OpenBrace(_) =>
              match parse_function_body(parser) {
                Ok((b, p)) => (Some(b), p)
                Err(p) => (None, p)
              }
            _ => (None, parser)
          }
          acc.push(
            Node::MethodDeclaration(MethodDeclaration::{
              name,
              computed_name_expr: None,
              type_parameters: [],
              parameters,
              return_type,
              body,
              decorators,
              modifiers: [],
              is_async: false,
              is_generator: false,
              is_optional: false,
              location: loc,
            }),
          )
          parse_class_members_aux(parser, acc)
        }
        // Property using reserved word as name
        _ => {
          let (type_annotation, parser) = match current_token(parser) {
            Colon(_) => {
              let parser = advance_parser(parser)
              match parse_type(parser) {
                Ok((ty, p)) => (Some(ty), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }
          let (initializer, parser) = match current_token(parser) {
            Equals(_) => {
              let parser = advance_parser(parser)
              match parse_assignment_expression(parser) {
                Ok((expr, p)) => (Some(expr), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }
          let parser = match current_token(parser) {
            Semicolon(_) => advance_parser(parser)
            _ => parser
          }
          acc.push(
            Node::PropertyDeclaration(PropertyDeclaration::{
              name,
              computed_name_expr: None,
              type_annotation,
              initializer,
              is_optional: false,
              decorators,
              modifiers: [],
              location: loc,
            }),
          )
          parse_class_members_aux(parser, acc)
        }
      }
    }

    // Numeric literal as property/method name (e.g., 11() { } or 0b110 = "world")
    NumericLiteral(value, loc) => {
      let name = value
      let parser = advance_parser(parser)
      match current_token(parser) {
        // Method using numeric literal as name
        OpenParen(_) => {
          let parser = advance_parser(parser)
          let (parameters, parser) = parse_parameter_list(parser)
          let (return_type, parser) = match current_token(parser) {
            Colon(_) => {
              let parser = advance_parser(parser)
              match parse_type(parser) {
                Ok((ty, p)) => (Some(ty), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }
          let (body, parser) = match current_token(parser) {
            OpenBrace(_) =>
              match parse_function_body(parser) {
                Ok((b, p)) => (Some(b), p)
                Err(p) => (None, p)
              }
            _ => (None, parser)
          }
          acc.push(
            Node::MethodDeclaration(MethodDeclaration::{
              name,
              computed_name_expr: None,
              type_parameters: [],
              parameters,
              return_type,
              body,
              decorators,
              modifiers: [],
              is_async: false,
              is_generator: false,
              is_optional: false,
              location: loc,
            }),
          )
          parse_class_members_aux(parser, acc)
        }
        // Property using numeric literal as name
        _ => {
          let (type_annotation, parser) = match current_token(parser) {
            Colon(_) => {
              let parser = advance_parser(parser)
              match parse_type(parser) {
                Ok((ty, p)) => (Some(ty), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }
          let (initializer, parser) = match current_token(parser) {
            Equals(_) => {
              let parser = advance_parser(parser)
              match parse_assignment_expression(parser) {
                Ok((expr, p)) => (Some(expr), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }
          let parser = match current_token(parser) {
            Semicolon(_) => advance_parser(parser)
            _ => parser
          }
          acc.push(
            Node::PropertyDeclaration(PropertyDeclaration::{
              name,
              computed_name_expr: None,
              type_annotation,
              initializer,
              is_optional: false,
              decorators,
              modifiers: [],
              location: loc,
            }),
          )
          parse_class_members_aux(parser, acc)
        }
      }
    }

    // String literal as property/method name (e.g., "foo"() { } or "hello" = 10)
    StringLiteral(value, loc) => {
      let name = value
      let parser = advance_parser(parser)
      match current_token(parser) {
        // Method using string literal as name
        OpenParen(_) => {
          let parser = advance_parser(parser)
          let (parameters, parser) = parse_parameter_list(parser)
          let (return_type, parser) = match current_token(parser) {
            Colon(_) => {
              let parser = advance_parser(parser)
              match parse_type(parser) {
                Ok((ty, p)) => (Some(ty), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }
          let (body, parser) = match current_token(parser) {
            OpenBrace(_) =>
              match parse_function_body(parser) {
                Ok((b, p)) => (Some(b), p)
                Err(p) => (None, p)
              }
            _ => (None, parser)
          }
          acc.push(
            Node::MethodDeclaration(MethodDeclaration::{
              name,
              computed_name_expr: None,
              type_parameters: [],
              parameters,
              return_type,
              body,
              decorators,
              modifiers: [],
              is_async: false,
              is_generator: false,
              is_optional: false,
              location: loc,
            }),
          )
          parse_class_members_aux(parser, acc)
        }
        // Property using string literal as name
        _ => {
          let (type_annotation, parser) = match current_token(parser) {
            Colon(_) => {
              let parser = advance_parser(parser)
              match parse_type(parser) {
                Ok((ty, p)) => (Some(ty), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }
          let (initializer, parser) = match current_token(parser) {
            Equals(_) => {
              let parser = advance_parser(parser)
              match parse_assignment_expression(parser) {
                Ok((expr, p)) => (Some(expr), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }
          let parser = match current_token(parser) {
            Semicolon(_) => advance_parser(parser)
            _ => parser
          }
          acc.push(
            Node::PropertyDeclaration(PropertyDeclaration::{
              name,
              computed_name_expr: None,
              type_annotation,
              initializer,
              is_optional: false,
              decorators,
              modifiers: [],
              location: loc,
            }),
          )
          parse_class_members_aux(parser, acc)
        }
      }
    }

    // Generator method: *method() { }
    Star(star_loc) => {
      let parser = advance_parser(parser)
      match current_token(parser) {
        Identifier(name, _) => {
          let parser = advance_parser(parser)
          // Type parameters
          let (type_parameters, parser) = match current_token(parser) {
            LessThan(_) => parse_type_parameters(parser)
            _ => ([], parser)
          }
          // Parameters
          let parser = match current_token(parser) {
            OpenParen(_) => advance_parser(parser)
            _ => parser
          }
          let (parameters, parser) = parse_parameter_list(parser)
          // Return type
          let (return_type, parser) = match current_token(parser) {
            Colon(_) => {
              let parser = advance_parser(parser)
              match parse_type(parser) {
                Ok((ty, p)) => (Some(ty), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }
          // Body
          let (body, parser) = match current_token(parser) {
            OpenBrace(_) =>
              match parse_function_body(parser) {
                Ok((b, p)) => (Some(b), p)
                Err(p) => (None, p)
              }
            Semicolon(_) => (None, advance_parser(parser))
            _ => (None, parser)
          }
          acc.push(
            Node::MethodDeclaration(MethodDeclaration::{
              name,
              computed_name_expr: None,
              type_parameters,
              parameters,
              return_type,
              body,
              decorators,
              modifiers: [],
              is_async: false,
              is_generator: true,
              is_optional: false,
              location: star_loc,
            }),
          )
          parse_class_members_aux(parser, acc)
        }
        _ => parse_class_members_aux(parser, acc)
      }
    }

    // Property or method
    Identifier(name, loc) => {
      let parser = advance_parser(parser)
      match current_token(parser) {
        // Method
        OpenParen(_) => {
          let parser = advance_parser(parser)
          let (parameters, parser) = parse_parameter_list(parser)

          // Parse optional return type
          let (return_type, parser) = match current_token(parser) {
            Colon(_) => {
              let parser = advance_parser(parser)
              match parse_type(parser) {
                Ok((ty, p)) => (Some(ty), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }
          let (body, parser) = match current_token(parser) {
            OpenBrace(_) =>
              match parse_function_body(parser) {
                Ok((b, p)) => (Some(b), p)
                Err(p) => (None, p)
              }
            _ => (None, parser)
          }
          acc.push(
            Node::MethodDeclaration(MethodDeclaration::{
              name,
              computed_name_expr: None,
              type_parameters: [],
              parameters,
              return_type,
              body,
              decorators,
              modifiers: [],
              is_async: false,
              is_generator: false,
              is_optional: false,
              location: loc,
            }),
          )
          parse_class_members_aux(parser, acc)
        }

        // Generic method: foo<T>(x: T) { }
        LessThan(_) => {
          let (type_parameters, parser) = parse_type_parameters(parser)
          // After type parameters, expect (
          let parser = match current_token(parser) {
            OpenParen(_) => advance_parser(parser)
            _ => parser
          }
          let (parameters, parser) = parse_parameter_list(parser)
          let (return_type, parser) = match current_token(parser) {
            Colon(_) => {
              let parser = advance_parser(parser)
              match parse_type(parser) {
                Ok((ty, p)) => (Some(ty), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }
          let (body, parser) = match current_token(parser) {
            OpenBrace(_) =>
              match parse_function_body(parser) {
                Ok((b, p)) => (Some(b), p)
                Err(p) => (None, p)
              }
            _ => (None, parser)
          }
          acc.push(
            Node::MethodDeclaration(MethodDeclaration::{
              name,
              computed_name_expr: None,
              type_parameters,
              parameters,
              return_type,
              body,
              decorators,
              modifiers: [],
              is_async: false,
              is_generator: false,
              is_optional: false,
              location: loc,
            }),
          )
          parse_class_members_aux(parser, acc)
        }

        // Property with initializer or type annotation
        _ => {
          // Parse optional type annotation
          let (type_annotation, parser) = match current_token(parser) {
            Colon(_) => {
              let parser = advance_parser(parser)
              match parse_type(parser) {
                Ok((ty, p)) => (Some(ty), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }

          // Parse optional initializer
          let (initializer, parser) = match current_token(parser) {
            Equals(_) => {
              let parser = advance_parser(parser)
              match parse_assignment_expression(parser) {
                Ok((expr, p)) => (Some(expr), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }

          // Consume optional semicolon
          let parser = match current_token(parser) {
            Semicolon(_) => advance_parser(parser)
            _ => parser
          }
          acc.push(
            Node::PropertyDeclaration(PropertyDeclaration::{
              name,
              computed_name_expr: None,
              type_annotation,
              initializer,
              is_optional: false,
              decorators,
              modifiers: [],
              location: loc,
            }),
          )
          parse_class_members_aux(parser, acc)
        }
      }
    }

    // Computed property name: ["computedName"]() or ["computedName"]: type
    // OR Index signature: [key: type]: valueType
    OpenBracket(start_loc) => {
      let parser = advance_parser(parser)
      // Check if this is an index signature: [identifier: type]: valueType
      // Index signatures have pattern: Identifier ":" Type "]" ":"
      let is_index_signature = match current_token(parser) {
        Identifier(_, _) =>
          match peek_token(parser) {
            Colon(_) => true
            _ => false
          }
        _ => false
      }
      if is_index_signature {
        // Parse as index signature
        let index_name = match current_token(parser) {
          Identifier(n, _) => n
          _ => ""
        }
        let parser = advance_parser(parser) // consume identifier
        let parser = advance_parser(parser) // consume ':'
        // Parse index type (string or number)
        let (index_type, parser) = match parse_type(parser) {
          Ok((t, p)) => (t, p)
          Err(p) => return (acc, p)
        }
        // Expect closing bracket
        let parser = match current_token(parser) {
          CloseBracket(_) => advance_parser(parser)
          _ => parser
        }
        // Expect colon for value type
        let parser = match current_token(parser) {
          Colon(_) => advance_parser(parser)
          _ => parser
        }
        // Parse value type
        let (value_type, parser) = match parse_type(parser) {
          Ok((t, p)) => (t, p)
          Err(p) => return (acc, p)
        }
        // Optional semicolon
        let parser = match current_token(parser) {
          Semicolon(_) => advance_parser(parser)
          _ => parser
        }
        // Create index signature
        acc.push(
          Node::IndexSignatureDeclaration(IndexSignatureDeclaration::{
            parameter_name: index_name,
            parameter_type: index_type,
            return_type: value_type,
            is_readonly: false,
            location: start_loc,
          }),
        )
        return parse_class_members_aux(parser, acc)
      }
      // Not an index signature - parse as computed property
      // Parse the expression inside brackets
      match parse_expression(parser) {
        Ok((name_expr, parser)) => {
          // Expect closing bracket
          let parser = match current_token(parser) {
            CloseBracket(_) => advance_parser(parser)
            _ => parser
          }
          // Get the computed name as string
          // Handle special cases like Symbol.iterator
          let computed_name = get_computed_property_name(name_expr)
          match current_token(parser) {
            // Computed method: ["name"]() { }
            OpenParen(_) => {
              let parser = advance_parser(parser)
              let (parameters, parser) = parse_parameter_list(parser)
              // Parse optional return type
              let (return_type, parser) = match current_token(parser) {
                Colon(_) => {
                  let parser = advance_parser(parser)
                  match parse_type(parser) {
                    Ok((ty, p)) => (Some(ty), p)
                    Err(p) => (None, p)
                  }
                }
                _ => (None, parser)
              }
              let (body, parser) = match current_token(parser) {
                OpenBrace(_) =>
                  match parse_function_body(parser) {
                    Ok((b, p)) => (Some(b), p)
                    Err(p) => (None, p)
                  }
                _ => (None, parser)
              }
              acc.push(
                Node::MethodDeclaration(MethodDeclaration::{
                  name: computed_name,
                  computed_name_expr: Some(name_expr), // Preserve for TS2464 validation
                  type_parameters: [],
                  parameters,
                  return_type,
                  body,
                  decorators,
                  modifiers: [],
                  is_async: false,
                  is_generator: false,
                  is_optional: false,
                  location: start_loc,
                }),
              )
              parse_class_members_aux(parser, acc)
            }
            // Computed property: ["name"]: type = value
            _ => {
              // Parse optional type annotation
              let (type_annotation, parser) = match current_token(parser) {
                Colon(_) => {
                  let parser = advance_parser(parser)
                  match parse_type(parser) {
                    Ok((ty, p)) => (Some(ty), p)
                    Err(p) => (None, p)
                  }
                }
                _ => (None, parser)
              }
              // Parse optional initializer
              let (initializer, parser) = match current_token(parser) {
                Equals(_) => {
                  let parser = advance_parser(parser)
                  match parse_assignment_expression(parser) {
                    Ok((expr, p)) => (Some(expr), p)
                    Err(p) => (None, p)
                  }
                }
                _ => (None, parser)
              }
              // Consume optional semicolon
              let parser = match current_token(parser) {
                Semicolon(_) => advance_parser(parser)
                _ => parser
              }
              acc.push(
                Node::PropertyDeclaration(PropertyDeclaration::{
                  name: computed_name,
                  computed_name_expr: Some(name_expr), // Preserve for TS1166 validation
                  type_annotation,
                  initializer,
                  is_optional: false,
                  decorators,
                  modifiers: [],
                  location: start_loc,
                }),
              )
              parse_class_members_aux(parser, acc)
            }
          }
        }
        Err(p) => parse_class_members_aux(p, acc)
      }
    }

    // Private class field with # syntax (ES2022)
    PrivateIdentifier(name, loc) => {
      let parser = advance_parser(parser)
      match current_token(parser) {
        // Private method
        OpenParen(_) => {
          let parser = advance_parser(parser)
          let (parameters, parser) = parse_parameter_list(parser)

          // Parse optional return type
          let (return_type, parser) = match current_token(parser) {
            Colon(_) => {
              let parser = advance_parser(parser)
              match parse_type(parser) {
                Ok((ty, p)) => (Some(ty), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }
          let (body, parser) = match current_token(parser) {
            OpenBrace(_) =>
              match parse_function_body(parser) {
                Ok((b, p)) => (Some(b), p)
                Err(p) => (None, p)
              }
            _ => (None, parser)
          }
          acc.push(
            Node::MethodDeclaration(MethodDeclaration::{
              name,
              computed_name_expr: None,
              type_parameters: [],
              parameters,
              return_type,
              body,
              decorators,
              modifiers: [],
              is_async: false,
              is_generator: false,
              is_optional: false,
              location: loc,
            }),
          )
          parse_class_members_aux(parser, acc)
        }

        // Private property with initializer or type annotation
        _ => {
          // Parse optional type annotation
          let (type_annotation, parser) = match current_token(parser) {
            Colon(_) => {
              let parser = advance_parser(parser)
              match parse_type(parser) {
                Ok((ty, p)) => (Some(ty), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }

          // Parse optional initializer
          let (initializer, parser) = match current_token(parser) {
            Equals(_) => {
              let parser = advance_parser(parser)
              match parse_assignment_expression(parser) {
                Ok((expr, p)) => (Some(expr), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }

          // Consume optional semicolon
          let parser = match current_token(parser) {
            Semicolon(_) => advance_parser(parser)
            _ => parser
          }
          acc.push(
            Node::PropertyDeclaration(PropertyDeclaration::{
              name,
              computed_name_expr: None,
              type_annotation,
              initializer,
              is_optional: false,
              decorators,
              modifiers: [],
              location: loc,
            }),
          )
          parse_class_members_aux(parser, acc)
        }
      }
    }

    // Skip other tokens
    _ => parse_class_members_aux(advance_parser(parser), acc)
  }
}

///|
/// Parse class member with modifiers (private/protected/public/static/readonly/abstract/async)
fn parse_class_member_with_modifiers(
  parser : Parser,
  acc : Array[Node],
  decorators : Array[Node],
  modifiers : Array[Modifier],
) -> (Array[Node], Parser) {
  match current_token(parser) {
    // Handle chained modifiers
    KeywordPublic(_) => {
      let parser = advance_parser(parser)
      modifiers.push(Modifier::Public)
      parse_class_member_with_modifiers(parser, acc, decorators, modifiers)
    }
    KeywordPrivate(_) => {
      let parser = advance_parser(parser)
      modifiers.push(Modifier::Private)
      parse_class_member_with_modifiers(parser, acc, decorators, modifiers)
    }
    KeywordProtected(_) => {
      let parser = advance_parser(parser)
      modifiers.push(Modifier::Protected)
      parse_class_member_with_modifiers(parser, acc, decorators, modifiers)
    }
    KeywordStatic(_) => {
      let parser = advance_parser(parser)
      modifiers.push(Modifier::Static)
      parse_class_member_with_modifiers(parser, acc, decorators, modifiers)
    }
    KeywordReadonly(_) => {
      let parser = advance_parser(parser)
      modifiers.push(Modifier::Readonly)
      parse_class_member_with_modifiers(parser, acc, decorators, modifiers)
    }
    KeywordAbstract(_) => {
      let parser = advance_parser(parser)
      modifiers.push(Modifier::Abstract)
      parse_class_member_with_modifiers(parser, acc, decorators, modifiers)
    }
    KeywordAsync(_) => {
      let parser = advance_parser(parser)
      modifiers.push(Modifier::Async)
      parse_class_member_with_modifiers(parser, acc, decorators, modifiers)
    }
    // Auto-accessor with modifiers: static accessor name = value;
    KeywordAccessor(start_loc) => {
      let parser = advance_parser(parser)
      match current_token(parser) {
        Identifier(name, _) => {
          let parser = advance_parser(parser)
          // Optional type annotation
          let (type_annotation, parser) = match current_token(parser) {
            Colon(_) => {
              let parser = advance_parser(parser)
              match parse_type(parser) {
                Ok((ty, p)) => (Some(ty), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }
          // Optional initializer
          let (initializer, parser) = match current_token(parser) {
            Equals(_) => {
              let parser = advance_parser(parser)
              match parse_assignment_expression(parser) {
                Ok((expr, p)) => (Some(expr), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }
          acc.push(
            Node::AutoAccessor(AutoAccessor::{
              name,
              type_annotation,
              initializer,
              decorators,
              modifiers,
              location: start_loc,
            }),
          )
          let parser = match current_token(parser) {
            Semicolon(_) => advance_parser(parser)
            _ => parser
          }
          parse_class_members_aux(parser, acc)
        }
        _ => parse_class_members_aux(parser, acc)
      }
    }
    // Handle get/set with modifiers: static get name() or static get ["computed"]()
    Identifier("get", start_loc) => {
      let parser = advance_parser(parser)
      match current_token(parser) {
        // Computed getter with modifiers: static get ["computed"]()
        OpenBracket(_) => {
          let parser = advance_parser(parser)
          match parse_expression(parser) {
            Ok((name_expr, parser)) => {
              let parser = match current_token(parser) {
                CloseBracket(_) => advance_parser(parser)
                _ => parser
              }
              let computed_name = get_computed_property_name(name_expr)
              match current_token(parser) {
                OpenParen(_) => {
                  let parser = advance_parser(parser)
                  let (params, parser) = parse_parameter_list(parser)
                  let parser = if params.length() > 0 {
                    add_error_with_code(
                      parser,
                      GetAccessorCannotHaveParams.to_message(),
                      start_loc,
                      GetAccessorCannotHaveParams,
                    )
                  } else {
                    parser
                  }
                  let (return_type, parser) = match current_token(parser) {
                    Colon(_) => {
                      let parser = advance_parser(parser)
                      match parse_type(parser) {
                        Ok((ty, p)) => (Some(ty), p)
                        Err(p) => (None, p)
                      }
                    }
                    _ => (None, parser)
                  }
                  let (body, parser) = match current_token(parser) {
                    OpenBrace(_) =>
                      match parse_function_body(parser) {
                        Ok((b, p)) => (Some(b), p)
                        Err(p) => (None, p)
                      }
                    _ => (None, parser)
                  }
                  acc.push(
                    Node::GetAccessor(GetAccessor::{
                      name: computed_name,
                      computed_name_expr: Some(name_expr), // Preserve for TS2464 validation
                      return_type,
                      body,
                      decorators,
                      modifiers,
                      location: start_loc,
                    }),
                  )
                  parse_class_members_aux(parser, acc)
                }
                _ => parse_class_members_aux(parser, acc)
              }
            }
            Err(p) => parse_class_members_aux(p, acc)
          }
        }
        // Regular getter with modifiers: static get name()
        Identifier(name, _) => {
          let parser = advance_parser(parser)
          match current_token(parser) {
            OpenParen(_) => {
              let parser = advance_parser(parser)
              let (params, parser) = parse_parameter_list(parser)
              let parser = if params.length() > 0 {
                add_error_with_code(
                  parser,
                  GetAccessorCannotHaveParams.to_message(),
                  start_loc,
                  GetAccessorCannotHaveParams,
                )
              } else {
                parser
              }
              let (return_type, parser) = match current_token(parser) {
                Colon(_) => {
                  let parser = advance_parser(parser)
                  match parse_type(parser) {
                    Ok((ty, p)) => (Some(ty), p)
                    Err(p) => (None, p)
                  }
                }
                _ => (None, parser)
              }
              let (body, parser) = match current_token(parser) {
                OpenBrace(_) =>
                  match parse_function_body(parser) {
                    Ok((b, p)) => (Some(b), p)
                    Err(p) => (None, p)
                  }
                _ => (None, parser)
              }
              acc.push(
                Node::GetAccessor(GetAccessor::{
                  name,
                  computed_name_expr: None,
                  return_type,
                  body,
                  decorators,
                  modifiers,
                  location: start_loc,
                }),
              )
              parse_class_members_aux(parser, acc)
            }
            _ => parse_class_members_aux(parser, acc)
          }
        }
        _ => parse_class_members_aux(parser, acc)
      }
    }
    // Handle set with modifiers: static set name(v) or static set ["computed"](v)
    Identifier("set", start_loc) => {
      let parser = advance_parser(parser)
      match current_token(parser) {
        // Computed setter with modifiers
        OpenBracket(_) => {
          let parser = advance_parser(parser)
          match parse_expression(parser) {
            Ok((name_expr, parser)) => {
              let parser = match current_token(parser) {
                CloseBracket(_) => advance_parser(parser)
                _ => parser
              }
              let computed_name = get_computed_property_name(name_expr)
              match current_token(parser) {
                OpenParen(_) => {
                  let parser = advance_parser(parser)
                  let (params, parser) = parse_parameter_list(parser)
                  let parser = if params.length() != 1 {
                    add_error_with_code(
                      parser,
                      SetAccessorMustHaveOneParam.to_message(),
                      start_loc,
                      SetAccessorMustHaveOneParam,
                    )
                  } else {
                    parser
                  }
                  let parameter = if params.length() > 0 {
                    params[0]
                  } else {
                    Node::Identifier(Identifier::{
                      name: "value",
                      location: start_loc,
                    })
                  }
                  let (has_return_type, parser) = match current_token(parser) {
                    Colon(_) => {
                      let parser = advance_parser(parser)
                      match parse_type(parser) {
                        Ok((_, p)) => (true, p)
                        Err(p) => (true, p)
                      }
                    }
                    _ => (false, parser)
                  }
                  let parser = if has_return_type {
                    add_error_with_code(
                      parser,
                      SetAccessorCannotHaveReturnType.to_message(),
                      start_loc,
                      SetAccessorCannotHaveReturnType,
                    )
                  } else {
                    parser
                  }
                  let (body, parser) = match current_token(parser) {
                    OpenBrace(_) =>
                      match parse_function_body(parser) {
                        Ok((b, p)) => (Some(b), p)
                        Err(p) => (None, p)
                      }
                    _ => (None, parser)
                  }
                  acc.push(
                    Node::SetAccessor(SetAccessor::{
                      name: computed_name,
                      computed_name_expr: Some(name_expr), // Preserve for TS2464 validation
                      parameter,
                      body,
                      decorators,
                      modifiers,
                      location: start_loc,
                    }),
                  )
                  parse_class_members_aux(parser, acc)
                }
                _ => parse_class_members_aux(parser, acc)
              }
            }
            Err(p) => parse_class_members_aux(p, acc)
          }
        }
        // Regular setter with modifiers
        Identifier(name, _) => {
          let parser = advance_parser(parser)
          match current_token(parser) {
            OpenParen(_) => {
              let parser = advance_parser(parser)
              let (params, parser) = parse_parameter_list(parser)
              let parser = if params.length() != 1 {
                add_error_with_code(
                  parser,
                  SetAccessorMustHaveOneParam.to_message(),
                  start_loc,
                  SetAccessorMustHaveOneParam,
                )
              } else {
                parser
              }
              let parameter = if params.length() > 0 {
                params[0]
              } else {
                Node::Identifier(Identifier::{
                  name: "value",
                  location: start_loc,
                })
              }
              let (has_return_type, parser) = match current_token(parser) {
                Colon(_) => {
                  let parser = advance_parser(parser)
                  match parse_type(parser) {
                    Ok((_, p)) => (true, p)
                    Err(p) => (true, p)
                  }
                }
                _ => (false, parser)
              }
              let parser = if has_return_type {
                add_error_with_code(
                  parser,
                  SetAccessorCannotHaveReturnType.to_message(),
                  start_loc,
                  SetAccessorCannotHaveReturnType,
                )
              } else {
                parser
              }
              let (body, parser) = match current_token(parser) {
                OpenBrace(_) =>
                  match parse_function_body(parser) {
                    Ok((b, p)) => (Some(b), p)
                    Err(p) => (None, p)
                  }
                _ => (None, parser)
              }
              acc.push(
                Node::SetAccessor(SetAccessor::{
                  name,
                  computed_name_expr: None,
                  parameter,
                  body,
                  decorators,
                  modifiers,
                  location: start_loc,
                }),
              )
              parse_class_members_aux(parser, acc)
            }
            _ => parse_class_members_aux(parser, acc)
          }
        }
        _ => parse_class_members_aux(parser, acc)
      }
    }
    // Computed property with modifiers: static ["computed"]() or static ["computed"]: type
    OpenBracket(start_loc) => {
      let parser = advance_parser(parser)
      match parse_expression(parser) {
        Ok((name_expr, parser)) => {
          let parser = match current_token(parser) {
            CloseBracket(_) => advance_parser(parser)
            _ => parser
          }
          let computed_name = get_computed_property_name(name_expr)
          match current_token(parser) {
            // Computed method with modifiers
            OpenParen(_) => {
              let parser = advance_parser(parser)
              let (parameters, parser) = parse_parameter_list(parser)
              let (return_type, parser) = match current_token(parser) {
                Colon(_) => {
                  let parser = advance_parser(parser)
                  match parse_type(parser) {
                    Ok((ty, p)) => (Some(ty), p)
                    Err(p) => (None, p)
                  }
                }
                _ => (None, parser)
              }
              let (body, parser) = match current_token(parser) {
                OpenBrace(_) =>
                  match parse_function_body(parser) {
                    Ok((b, p)) => (Some(b), p)
                    Err(p) => (None, p)
                  }
                _ => (None, parser)
              }
              let mut is_async = false
              for modifier in modifiers {
                if modifier == Modifier::Async {
                  is_async = true
                  break
                }
              }
              acc.push(
                Node::MethodDeclaration(MethodDeclaration::{
                  name: computed_name,
                  computed_name_expr: Some(name_expr), // Preserve for TS2464 validation
                  type_parameters: [],
                  parameters,
                  return_type,
                  body,
                  decorators,
                  modifiers,
                  is_async,
                  is_generator: false,
                  is_optional: false,
                  location: start_loc,
                }),
              )
              parse_class_members_aux(parser, acc)
            }
            // Computed property with modifiers
            _ => {
              let (type_annotation, parser) = match current_token(parser) {
                Colon(_) => {
                  let parser = advance_parser(parser)
                  match parse_type(parser) {
                    Ok((ty, p)) => (Some(ty), p)
                    Err(p) => (None, p)
                  }
                }
                _ => (None, parser)
              }
              let (initializer, parser) = match current_token(parser) {
                Equals(_) => {
                  let parser = advance_parser(parser)
                  match parse_assignment_expression(parser) {
                    Ok((expr, p)) => (Some(expr), p)
                    Err(p) => (None, p)
                  }
                }
                _ => (None, parser)
              }
              let parser = match current_token(parser) {
                Semicolon(_) => advance_parser(parser)
                _ => parser
              }
              acc.push(
                Node::PropertyDeclaration(PropertyDeclaration::{
                  name: computed_name,
                  computed_name_expr: None,
                  type_annotation,
                  initializer,
                  is_optional: false,
                  decorators,
                  modifiers,
                  location: start_loc,
                }),
              )
              parse_class_members_aux(parser, acc)
            }
          }
        }
        Err(p) => parse_class_members_aux(p, acc)
      }
    }
    Identifier(name, loc) => {
      let parser = advance_parser(parser)
      match current_token(parser) {
        // Generic method: foo<T>(x: T) { }
        LessThan(_) => {
          let (type_parameters, parser) = parse_type_parameters(parser)
          // After type parameters, expect (
          let parser = match current_token(parser) {
            OpenParen(_) => advance_parser(parser)
            _ => parser
          }
          let (parameters, parser) = parse_parameter_list(parser)
          let (return_type, parser) = match current_token(parser) {
            Colon(_) => {
              let parser = advance_parser(parser)
              match parse_type(parser) {
                Ok((ty, p)) => (Some(ty), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }
          let (body, parser) = match current_token(parser) {
            OpenBrace(_) =>
              match parse_function_body(parser) {
                Ok((b, p)) => (Some(b), p)
                Err(p) => (None, p)
              }
            _ => (None, parser)
          }
          // Check if Async modifier is present
          let mut is_async = false
          for modifier in modifiers {
            if modifier == Modifier::Async {
              is_async = true
              break
            }
          }
          acc.push(
            Node::MethodDeclaration(MethodDeclaration::{
              name,
              computed_name_expr: None,
              type_parameters,
              parameters,
              return_type,
              body,
              decorators,
              modifiers,
              is_async,
              is_generator: false,
              is_optional: false,
              location: loc,
            }),
          )
          parse_class_members_aux(parser, acc)
        }
        // Method without type parameters
        OpenParen(_) => {
          let parser = advance_parser(parser)
          let (parameters, parser) = parse_parameter_list(parser)
          let (return_type, parser) = match current_token(parser) {
            Colon(_) => {
              let parser = advance_parser(parser)
              match parse_type(parser) {
                Ok((ty, p)) => (Some(ty), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }
          let (body, parser) = match current_token(parser) {
            OpenBrace(_) =>
              match parse_function_body(parser) {
                Ok((b, p)) => (Some(b), p)
                Err(p) => (None, p)
              }
            _ => (None, parser)
          }
          // Check if Async modifier is present
          let mut is_async = false
          for modifier in modifiers {
            if modifier == Modifier::Async {
              is_async = true
              break
            }
          }
          acc.push(
            Node::MethodDeclaration(MethodDeclaration::{
              name,
              computed_name_expr: None,
              type_parameters: [],
              parameters,
              return_type,
              body,
              decorators,
              modifiers,
              is_async,
              is_generator: false,
              is_optional: false,
              location: loc,
            }),
          )
          parse_class_members_aux(parser, acc)
        }
        // Property
        _ => {
          let (type_annotation, parser) = match current_token(parser) {
            Colon(_) => {
              let parser = advance_parser(parser)
              match parse_type(parser) {
                Ok((ty, p)) => (Some(ty), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }
          let (initializer, parser) = match current_token(parser) {
            Equals(_) => {
              let parser = advance_parser(parser)
              match parse_assignment_expression(parser) {
                Ok((expr, p)) => (Some(expr), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }
          let parser = match current_token(parser) {
            Semicolon(_) => advance_parser(parser)
            _ => parser
          }
          acc.push(
            Node::PropertyDeclaration(PropertyDeclaration::{
              name,
              computed_name_expr: None,
              type_annotation,
              initializer,
              is_optional: false,
              decorators,
              modifiers,
              location: loc,
            }),
          )
          parse_class_members_aux(parser, acc)
        }
      }
    }
    _ => parse_class_members_aux(parser, acc)
  }
}

///|
/// Helper: Skip tokens until predicate is true
fn skip_until_token(parser : Parser, predicate : (Token) -> Bool) -> Parser {
  if is_at_end(parser) || predicate(current_token(parser)) {
    parser
  } else {
    skip_until_token(advance_parser(parser), predicate)
  }
}

///|
fn parse_interface_declaration(
  parser : Parser,
) -> Result[(Node, Parser), Parser] {
  // interface Name [extends I1, I2] { members }
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'interface'

  // Parse interface name
  let (name, parser) = match current_token(parser) {
    Identifier(n, _) => (n, advance_parser(parser))
    _ =>
      return Err(
        add_error_with_code(
          parser,
          "Identifier expected",
          current_token(parser).location(),
          IdentifierExpected,
        ),
      )
  }

  // Parse type parameters if present
  let (type_parameters, parser) = match current_token(parser) {
    LessThan(_) => parse_type_parameters(parser)
    _ => ([], parser)
  }

  // Parse heritage clauses (extends only for interfaces)
  let (heritage_clauses, parser) = parse_heritage_clauses(parser)

  // Parse interface body
  match current_token(parser) {
    OpenBrace(_) => {
      let parser = advance_parser(parser)
      let members = []
      let mut parser = parser

      // Parse property signatures
      while true {
        match current_token(parser) {
          CloseBrace(loc) => {
            parser = advance_parser(parser)
            return Ok(
              (
                Node::InterfaceDeclaration(InterfaceDeclaration::{
                  name,
                  type_parameters,
                  heritage_clauses,
                  members,
                  modifiers: [],
                  location: SourceLocation::new(
                    start_loc.file_path,
                    start_loc.start,
                    loc.end,
                  ),
                }),
                parser,
              ),
            )
          }
          // Index signature or computed property: [key: string]: value OR [expr]: value
          OpenBracket(_) => {
            let bracket_loc = current_token(parser).location()
            parser = advance_parser(parser)

            // Check if this is an index signature or computed property
            // Index signature: [identifier: Type]: ValueType
            // Computed property: [expression]: Type or [expression](): ReturnType
            let is_index_signature = match current_token(parser) {
              Identifier(_, _) => {
                // Peek ahead to see if there's a colon after the identifier
                let next_parser = advance_parser(parser)
                match current_token(next_parser) {
                  Colon(_) => true // [id: Type] pattern - index signature
                  _ => false // [id] pattern - computed property with identifier
                }
              }
              _ => false // [other expression] - computed property
            }
            if is_index_signature {
              // Traditional index signature: [key: string]: value
              let index_name = match current_token(parser) {
                Identifier(n, _) => {
                  parser = advance_parser(parser)
                  n
                }
                _ =>
                  return Err(
                    add_error_with_code(
                      parser,
                      "Identifier expected",
                      current_token(parser).location(),
                      IdentifierExpected,
                    ),
                  )
              }
              // Expect colon
              match current_token(parser) {
                Colon(_) => parser = advance_parser(parser)
                _ =>
                  return Err(
                    add_error_with_code(
                      parser,
                      ExpectedColon.to_message(),
                      current_token(parser).location(),
                      ExpectedColon,
                    ),
                  )
              }
              // Parse index type (string or number)
              let index_type = match parse_type(parser) {
                Ok((t, p)) => {
                  parser = p
                  t
                }
                Err(p) => return Err(p)
              }
              // Expect closing bracket
              match current_token(parser) {
                CloseBracket(_) => parser = advance_parser(parser)
                _ =>
                  return Err(
                    add_error_with_code(
                      parser,
                      ExpectedCloseBracket.to_message(),
                      current_token(parser).location(),
                      ExpectedCloseBracket,
                    ),
                  )
              }
              // Expect colon for value type
              match current_token(parser) {
                Colon(_) => parser = advance_parser(parser)
                _ =>
                  return Err(
                    add_error_with_code(
                      parser,
                      ExpectedColon.to_message(),
                      current_token(parser).location(),
                      ExpectedColon,
                    ),
                  )
              }
              // Parse value type
              let value_type = match parse_type(parser) {
                Ok((t, p)) => {
                  parser = p
                  t
                }
                Err(p) => return Err(p)
              }
              // Create index signature
              members.push(
                Node::IndexSignatureDeclaration(IndexSignatureDeclaration::{
                  parameter_name: index_name,
                  parameter_type: index_type,
                  return_type: value_type,
                  is_readonly: false,
                  location: bracket_loc,
                }),
              )
              // Optional semicolon or comma
              match current_token(parser) {
                Semicolon(_) | Comma(_) => parser = advance_parser(parser)
                _ => ()
              }
            } else {
              // Computed property: [expression]: Type or [expression](): ReturnType
              // Parse the computed property name expression
              let (computed_name_expr, p) = match
                parse_assignment_expression(parser) {
                Ok((expr, p)) => (expr, p)
                Err(p) => return Err(p)
              }
              parser = p

              // Expect closing bracket
              match current_token(parser) {
                CloseBracket(_) => parser = advance_parser(parser)
                _ =>
                  return Err(
                    add_error_with_code(
                      parser,
                      ExpectedCloseBracket.to_message(),
                      current_token(parser).location(),
                      ExpectedCloseBracket,
                    ),
                  )
              }

              // Check for optional marker (?)
              let is_optional = match current_token(parser) {
                Question(_) => {
                  parser = advance_parser(parser)
                  true
                }
                _ => false
              }

              // Check if it's a method (has parentheses) or property (has colon)
              match current_token(parser) {
                OpenParen(_) => {
                  // Computed method signature: [expr](params): returnType
                  parser = advance_parser(parser)

                  // Parse parameters
                  let (params, p) = parse_parameter_list(parser)
                  parser = p

                  // Parse return type
                  let return_type = match current_token(parser) {
                    Colon(_) => {
                      parser = advance_parser(parser)
                      match parse_type(parser) {
                        Ok((t, p)) => {
                          parser = p
                          Some(t)
                        }
                        Err(_) => None
                      }
                    }
                    _ => None
                  }

                  // Create method declaration with computed name
                  // We'll use a special marker for computed names
                  let method_name = "[computed]"
                  members.push(
                    Node::MethodDeclaration(MethodDeclaration::{
                      name: method_name,
                      computed_name_expr: Some(computed_name_expr), // Preserve for TS2464 validation
                      type_parameters: [],
                      parameters: params,
                      return_type,
                      body: None,
                      decorators: [],
                      modifiers: [],
                      is_async: false,
                      is_generator: false,
                      is_optional,
                      location: bracket_loc,
                    }),
                  )

                  // Optional semicolon or comma
                  match current_token(parser) {
                    Semicolon(_) | Comma(_) => parser = advance_parser(parser)
                    _ => ()
                  }
                }
                Colon(_) => {
                  // Computed property signature: [expr]: type
                  parser = advance_parser(parser)

                  // Parse property type
                  match parse_type(parser) {
                    Ok((prop_type, p)) => {
                      parser = p

                      // Create property declaration with computed name
                      let prop_name = "[computed]"
                      members.push(
                        Node::PropertyDeclaration(PropertyDeclaration::{
                          name: prop_name,
                          computed_name_expr: Some(computed_name_expr), // Preserve for TS2464 validation
                          type_annotation: Some(prop_type),
                          initializer: None,
                          is_optional,
                          decorators: [],
                          modifiers: [],
                          location: bracket_loc,
                        }),
                      )

                      // Optional semicolon or comma
                      match current_token(parser) {
                        Semicolon(_) | Comma(_) =>
                          parser = advance_parser(parser)
                        _ => ()
                      }
                    }
                    Err(p) => return Err(p)
                  }
                }
                _ =>
                  return Err(
                    add_error_with_code(
                      parser,
                      ExpectedColon.to_message(),
                      current_token(parser).location(),
                      ExpectedColon,
                    ),
                  )
              }
            }
          }
          // Readonly modifier
          KeywordReadonly(_) => {
            let readonly_loc = current_token(parser).location()
            parser = advance_parser(parser)
            // Check for readonly index signature: readonly [key: type]: type
            match current_token(parser) {
              OpenBracket(_) => {
                parser = advance_parser(parser)
                // Parse index parameter name
                let index_name = match current_token(parser) {
                  Identifier(n, _) => {
                    parser = advance_parser(parser)
                    n
                  }
                  _ =>
                    return Err(
                      add_error_with_code(
                        parser,
                        "Identifier expected",
                        current_token(parser).location(),
                        IdentifierExpected,
                      ),
                    )
                }
                // Expect colon
                match current_token(parser) {
                  Colon(_) => parser = advance_parser(parser)
                  _ =>
                    return Err(
                      add_error_with_code(
                        parser,
                        ExpectedColon.to_message(),
                        current_token(parser).location(),
                        ExpectedColon,
                      ),
                    )
                }
                // Parse index type (string or number)
                let index_type = match parse_type(parser) {
                  Ok((t, p)) => {
                    parser = p
                    t
                  }
                  Err(p) => return Err(p)
                }
                // Expect closing bracket
                match current_token(parser) {
                  CloseBracket(_) => parser = advance_parser(parser)
                  _ =>
                    return Err(
                      add_error_with_code(
                        parser,
                        ExpectedCloseBracket.to_message(),
                        current_token(parser).location(),
                        ExpectedCloseBracket,
                      ),
                    )
                }
                // Expect colon for value type
                match current_token(parser) {
                  Colon(_) => parser = advance_parser(parser)
                  _ =>
                    return Err(
                      add_error_with_code(
                        parser,
                        ExpectedColon.to_message(),
                        current_token(parser).location(),
                        ExpectedColon,
                      ),
                    )
                }
                // Parse value type
                let value_type = match parse_type(parser) {
                  Ok((t, p)) => {
                    parser = p
                    t
                  }
                  Err(p) => return Err(p)
                }
                // Create readonly index signature
                members.push(
                  Node::IndexSignatureDeclaration(IndexSignatureDeclaration::{
                    parameter_name: index_name,
                    parameter_type: index_type,
                    return_type: value_type,
                    is_readonly: true,
                    location: readonly_loc,
                  }),
                )
                // Optional semicolon or comma
                match current_token(parser) {
                  Semicolon(_) | Comma(_) => parser = advance_parser(parser)
                  _ => ()
                }
              }
              Identifier(n, loc) => {
                // Readonly property
                parser = advance_parser(parser)
                let prop_name = n
                let prop_loc = loc
                // Check for optional marker (?)
                let is_optional = match current_token(parser) {
                  Question(_) => {
                    parser = advance_parser(parser)
                    true
                  }
                  _ => false
                }
                // Must be followed by colon (readonly properties, not methods)
                match current_token(parser) {
                  Colon(_) => {
                    parser = advance_parser(parser)
                    match parse_type(parser) {
                      Ok((prop_type, p)) => {
                        parser = p
                        members.push(
                          Node::PropertyDeclaration(PropertyDeclaration::{
                            name: prop_name,
                            computed_name_expr: None,
                            type_annotation: Some(prop_type),
                            initializer: None,
                            is_optional,
                            decorators: [],
                            modifiers: [Modifier::Readonly],
                            location: prop_loc,
                          }),
                        )
                        match current_token(parser) {
                          Semicolon(_) | Comma(_) =>
                            parser = advance_parser(parser)
                          _ => ()
                        }
                      }
                      Err(p) => return Err(p)
                    }
                  }
                  _ =>
                    return Err(
                      add_error_with_code(
                        parser,
                        ExpectedColon.to_message(),
                        current_token(parser).location(),
                        ExpectedColon,
                      ),
                    )
                }
              }
              _ =>
                return Err(
                  add_error_with_code(
                    parser,
                    "Identifier expected",
                    current_token(parser).location(),
                    IdentifierExpected,
                  ),
                )
            }
          }
          // Call signature: (): returnType
          OpenParen(_) => {
            let call_loc = current_token(parser).location()
            parser = advance_parser(parser) // consume '('

            // Parse parameters
            let (params, p) = parse_parameter_list(parser)
            parser = p

            // Parse return type
            let return_type = match current_token(parser) {
              Colon(_) => {
                parser = advance_parser(parser)
                match parse_type(parser) {
                  Ok((t, p)) => {
                    parser = p
                    Some(t)
                  }
                  Err(_) => None
                }
              }
              _ => None
            }

            // Create call signature as a method with empty name (call signature)
            members.push(
              Node::MethodDeclaration(MethodDeclaration::{
                name: "",
                computed_name_expr: None,
                type_parameters: [],
                parameters: params,
                return_type,
                body: None,
                decorators: [],
                modifiers: [],
                is_async: false,
                is_generator: false,
                is_optional: false,
                location: call_loc,
              }),
            )

            // Optional semicolon or comma
            match current_token(parser) {
              Semicolon(_) | Comma(_) => parser = advance_parser(parser)
              _ => ()
            }
          }
          // Construct signature: new(): returnType or new <T>(): returnType
          KeywordNew(_) => {
            let new_loc = current_token(parser).location()
            parser = advance_parser(parser) // consume 'new'
            // Check for optional type parameters: new <T>()
            let (type_params, parser2) = match current_token(parser) {
              LessThan(_) => parse_type_parameters(parser)
              _ => ([], parser)
            }
            parser = parser2
            match current_token(parser) {
              OpenParen(_) => {
                parser = advance_parser(parser)
                let (params, p) = parse_parameter_list(parser)
                parser = p

                // Parse return type
                let return_type = match current_token(parser) {
                  Colon(_) => {
                    parser = advance_parser(parser)
                    match parse_type(parser) {
                      Ok((t, p)) => {
                        parser = p
                        Some(t)
                      }
                      Err(_) => None
                    }
                  }
                  _ => None
                }

                // Create construct signature as a method with "new" name
                members.push(
                  Node::MethodDeclaration(MethodDeclaration::{
                    name: "new",
                    computed_name_expr: None,
                    type_parameters: type_params,
                    parameters: params,
                    return_type,
                    body: None,
                    decorators: [],
                    modifiers: [],
                    is_async: false,
                    is_generator: false,
                    is_optional: false,
                    location: new_loc,
                  }),
                )

                // Optional semicolon or comma
                match current_token(parser) {
                  Semicolon(_) | Comma(_) => parser = advance_parser(parser)
                  _ => ()
                }
              }
              _ =>
                return Err(
                  add_error_with_code(
                    parser,
                    ExpectedOpenParen.to_message(),
                    current_token(parser).location(),
                    ExpectedOpenParen,
                  ),
                )
            }
          }
          Identifier(prop_name, prop_loc) => {
            parser = advance_parser(parser)

            // Check for optional marker (?)
            let is_optional = match current_token(parser) {
              Question(_) => {
                parser = advance_parser(parser)
                true
              }
              _ => false
            }

            // Check if it's a method (has parentheses) or property (has colon)
            match current_token(parser) {
              OpenParen(_) => {
                // Method signature: name(params): returnType
                parser = advance_parser(parser) // consume '('

                // Parse parameters properly
                let (params, p) = parse_parameter_list(parser)
                parser = p

                // Parse return type
                let return_type = match current_token(parser) {
                  Colon(_) => {
                    parser = advance_parser(parser)
                    match parse_type(parser) {
                      Ok((t, p)) => {
                        parser = p
                        Some(t)
                      }
                      Err(_) => None
                    }
                  }
                  _ => None
                }

                // Create method declaration
                members.push(
                  Node::MethodDeclaration(MethodDeclaration::{
                    name: prop_name,
                    computed_name_expr: None,
                    type_parameters: [],
                    parameters: params,
                    return_type,
                    body: None,
                    decorators: [],
                    modifiers: [],
                    is_async: false,
                    is_generator: false,
                    is_optional,
                    location: prop_loc,
                  }),
                )

                // Optional semicolon or comma
                match current_token(parser) {
                  Semicolon(_) | Comma(_) => parser = advance_parser(parser)
                  _ => ()
                }
              }
              Colon(_) => {
                // Property signature: name: type
                parser = advance_parser(parser)

                // Parse property type
                match parse_type(parser) {
                  Ok((prop_type, p)) => {
                    parser = p

                    // Create property declaration
                    members.push(
                      Node::PropertyDeclaration(PropertyDeclaration::{
                        name: prop_name,
                        computed_name_expr: None,
                        type_annotation: Some(prop_type),
                        initializer: None,
                        is_optional,
                        decorators: [],
                        modifiers: [],
                        location: prop_loc,
                      }),
                    )

                    // Optional semicolon or comma
                    match current_token(parser) {
                      Semicolon(_) | Comma(_) => parser = advance_parser(parser)
                      _ => ()
                    }
                  }
                  Err(p) => return Err(p)
                }
              }
              LessThan(_) => {
                // Generic method signature: name<T>(params): returnType
                let (type_params, p) = parse_type_parameters(parser)
                parser = p

                // Must have '(' after type parameters
                match current_token(parser) {
                  OpenParen(_) => {
                    parser = advance_parser(parser)
                    let (params, p) = parse_parameter_list(parser)
                    parser = p

                    // Parse return type
                    let return_type = match current_token(parser) {
                      Colon(_) => {
                        parser = advance_parser(parser)
                        match parse_type(parser) {
                          Ok((t, p)) => {
                            parser = p
                            Some(t)
                          }
                          Err(_) => None
                        }
                      }
                      _ => None
                    }

                    // Create generic method declaration
                    members.push(
                      Node::MethodDeclaration(MethodDeclaration::{
                        name: prop_name,
                        computed_name_expr: None,
                        type_parameters: type_params,
                        parameters: params,
                        return_type,
                        body: None,
                        decorators: [],
                        modifiers: [],
                        is_async: false,
                        is_generator: false,
                        is_optional,
                        location: prop_loc,
                      }),
                    )

                    // Optional semicolon or comma
                    match current_token(parser) {
                      Semicolon(_) | Comma(_) => parser = advance_parser(parser)
                      _ => ()
                    }
                  }
                  _ =>
                    return Err(
                      add_error_with_code(
                        parser,
                        ExpectedOpenParen.to_message(),
                        current_token(parser).location(),
                        ExpectedOpenParen,
                      ),
                    )
                }
              }
              // Shorthand property signature: { a } means { a: a }
              // The property type is a type reference with the same name
              CloseBrace(_) | Semicolon(_) | Comma(_) => {
                // Create property declaration with type reference to the same name
                members.push(
                  Node::PropertyDeclaration(PropertyDeclaration::{
                    name: prop_name,
                    computed_name_expr: None,
                    type_annotation: Some(
                      Node::TypeReference(TypeReference::{
                        type_name: prop_name,
                        type_arguments: [],
                        location: prop_loc,
                      }),
                    ),
                    initializer: None,
                    is_optional,
                    decorators: [],
                    modifiers: [],
                    location: prop_loc,
                  }),
                )

                // Optional semicolon or comma
                match current_token(parser) {
                  Semicolon(_) | Comma(_) => parser = advance_parser(parser)
                  _ => ()
                }
              }
              _ =>
                return Err(
                  add_error_with_code(
                    parser,
                    ExpectedColon.to_message(),
                    prop_loc,
                    ExpectedColon,
                  ),
                )
            }
          }
          // Generic call signature: <T>(x: T): void
          LessThan(_) => {
            let call_loc = current_token(parser).location()
            let (type_params, p) = parse_type_parameters(parser)
            parser = p

            // Must have '(' after type parameters
            match current_token(parser) {
              OpenParen(_) => {
                parser = advance_parser(parser)
                let (params, p) = parse_parameter_list(parser)
                parser = p

                // Parse return type
                let return_type = match current_token(parser) {
                  Colon(_) => {
                    parser = advance_parser(parser)
                    match parse_type(parser) {
                      Ok((t, p)) => {
                        parser = p
                        Some(t)
                      }
                      Err(_) => None
                    }
                  }
                  _ => None
                }

                // Create generic call signature as a method with empty name
                members.push(
                  Node::MethodDeclaration(MethodDeclaration::{
                    name: "",
                    computed_name_expr: None,
                    type_parameters: type_params,
                    parameters: params,
                    return_type,
                    body: None,
                    decorators: [],
                    modifiers: [],
                    is_async: false,
                    is_generator: false,
                    is_optional: false,
                    location: call_loc,
                  }),
                )

                // Optional semicolon or comma
                match current_token(parser) {
                  Semicolon(_) | Comma(_) => parser = advance_parser(parser)
                  _ => ()
                }
              }
              _ =>
                return Err(
                  add_error_with_code(
                    parser,
                    ExpectedOpenParen.to_message(),
                    current_token(parser).location(),
                    ExpectedOpenParen,
                  ),
                )
            }
          }
          // Spread type: ...Type or ...name?: Type (TS2702 error)
          DotDotDot(spread_loc) => {
            parser = advance_parser(parser)
            // Check if next token is an identifier followed by ? or :
            // If so, it's a named rest element which is TS2702 error
            match current_token(parser) {
              Identifier(name, id_loc) => {
                // Check if followed by ?: or :
                let lookahead = peek_token(parser)
                match lookahead {
                  Question(_) | Colon(_) =>
                    // TS2702: A rest element cannot have a property name
                    return Err(
                      add_error_checked(
                        parser, "A rest element cannot have a property name.", spread_loc,
                        2702,
                      ),
                    )
                  _ => {
                    // It's a spread type with type reference: ...SomeType
                    // Create a property with spread marker
                    members.push(
                      Node::PropertyDeclaration(PropertyDeclaration::{
                        name: "...",
                        computed_name_expr: None,
                        type_annotation: Some(
                          Node::TypeReference(TypeReference::{
                            type_name: name,
                            type_arguments: [],
                            location: id_loc,
                          }),
                        ),
                        initializer: None,
                        is_optional: false,
                        decorators: [],
                        modifiers: [],
                        location: spread_loc,
                      }),
                    )
                    parser = advance_parser(parser)
                    // Optional semicolon or comma
                    match current_token(parser) {
                      Semicolon(_) | Comma(_) => parser = advance_parser(parser)
                      _ => ()
                    }
                  }
                }
              }
              _ =>
                // It's just a spread type without identifier, parse the type
                match parse_type(parser) {
                  Ok((spread_type, p)) => {
                    parser = p
                    members.push(
                      Node::PropertyDeclaration(PropertyDeclaration::{
                        name: "...",
                        computed_name_expr: None,
                        type_annotation: Some(spread_type),
                        initializer: None,
                        is_optional: false,
                        decorators: [],
                        modifiers: [],
                        location: spread_loc,
                      }),
                    )
                    // Optional semicolon or comma
                    match current_token(parser) {
                      Semicolon(_) | Comma(_) => parser = advance_parser(parser)
                      _ => ()
                    }
                  }
                  Err(p) => return Err(p)
                }
            }
          }
          _ => break
        }
      }
      Err(
        add_error_with_code(
          parser,
          ExpectedCloseBrace.to_message(),
          current_token(parser).location(),
          ExpectedCloseBrace,
        ),
      )
    }
    _ =>
      Err(
        add_error_with_code(
          parser,
          ExpectedOpenBrace.to_message(),
          current_token(parser).location(),
          ExpectedOpenBrace,
        ),
      )
  }
}

///|
fn parse_type_alias_declaration(
  parser : Parser,
) -> Result[(Node, Parser), Parser] {
  // type Name = Type
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'type'

  // Parse type name
  let (name, parser) = match current_token(parser) {
    Identifier(n, _) => (n, advance_parser(parser))
    _ =>
      return Err(
        add_error_with_code(
          parser,
          "Identifier expected",
          current_token(parser).location(),
          IdentifierExpected,
        ),
      )
  }

  // Optional type parameters
  let (type_parameters, parser) = match current_token(parser) {
    LessThan(_) => parse_type_parameters(parser)
    _ => ([], parser)
  }

  // Expect '='
  let parser = match current_token(parser) {
    Equals(_) => advance_parser(parser)
    _ =>
      return Err(
        add_error_with_code(
          parser,
          ExpectedEquals.to_message(),
          current_token(parser).location(),
          ExpectedEquals,
        ),
      )
  }

  // Parse type
  let (type_node, parser) = match parse_type(parser) {
    Ok((t, p)) => (t, p)
    Err(p) => return Err(p)
  }
  let end_loc = get_location(type_node)

  // Consume optional semicolon
  let parser = match current_token(parser) {
    Semicolon(_) => advance_parser(parser)
    _ => parser
  }
  Ok(
    (
      Node::TypeAliasDeclaration(TypeAliasDeclaration::{
        name,
        type_parameters,
        type_node,
        modifiers: [],
        location: SourceLocation::new(
          start_loc.file_path,
          start_loc.start,
          end_loc.end,
        ),
      }),
      parser,
    ),
  )
}

///|
fn parse_enum_declaration(
  parser : Parser,
  is_const : Bool,
) -> Result[(Node, Parser), Parser] {
  // enum Name { A, B = 1, C } or const enum Name { A, B }
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'enum'

  // Parse enum name
  // TypeScript allows reserved type names as enum names (reports TS2431 in checker)
  let (name, name_loc, parser) = match current_token(parser) {
    Identifier(n, loc) => (n, loc, advance_parser(parser))
    // Allow reserved type names as enum names (will be caught by checker as TS2431)
    KeywordAny(loc) => ("any", loc, advance_parser(parser))
    KeywordNumber(loc) => ("number", loc, advance_parser(parser))
    KeywordString(loc) => ("string", loc, advance_parser(parser))
    KeywordBoolean(loc) => ("boolean", loc, advance_parser(parser))
    KeywordSymbol(loc) => ("symbol", loc, advance_parser(parser))
    KeywordNever(loc) => ("never", loc, advance_parser(parser))
    KeywordUnknown(loc) => ("unknown", loc, advance_parser(parser))
    KeywordObject(loc) => ("object", loc, advance_parser(parser))
    KeywordUndefined(loc) => ("undefined", loc, advance_parser(parser))
    _ =>
      return Err(
        add_error_with_code(
          parser,
          "Identifier expected",
          current_token(parser).location(),
          IdentifierExpected,
        ),
      )
  }

  // Parse enum body
  match current_token(parser) {
    OpenBrace(_) => {
      let parser = advance_parser(parser)
      let (members, parser) = parse_enum_members(parser)
      match current_token(parser) {
        CloseBrace(loc) => {
          let parser = advance_parser(parser)
          let modifiers : Array[Modifier] = if is_const {
            [Modifier::Const]
          } else {
            []
          }
          Ok(
            (
              Node::EnumDeclaration(EnumDeclaration::{
                name,
                name_location: name_loc,
                members,
                is_const,
                modifiers,
                location: SourceLocation::new(
                  start_loc.file_path,
                  start_loc.start,
                  loc.end,
                ),
              }),
              parser,
            ),
          )
        }
        _ =>
          Err(
            add_error_with_code(
              parser,
              ExpectedCloseBrace.to_message(),
              current_token(parser).location(),
              ExpectedCloseBrace,
            ),
          )
      }
    }
    _ =>
      Err(
        add_error_with_code(
          parser,
          ExpectedOpenBrace.to_message(),
          current_token(parser).location(),
          ExpectedOpenBrace,
        ),
      )
  }
}

///|
/// Parse enum members
fn parse_enum_members(parser : Parser) -> (Array[EnumMember], Parser) {
  parse_enum_members_aux(parser, [])
}

///|
/// Helper to parse an enum member when we already know the name
fn parse_enum_member_with_name(
  parser : Parser,
  name : String,
  loc : SourceLocation,
  acc : Array[EnumMember],
) -> (Array[EnumMember], Parser) {
  let parser = advance_parser(parser)
  // Check for initializer or error recovery
  let (initializer, parser) = match current_token(parser) {
    Equals(_) => {
      let parser = advance_parser(parser)
      match parse_assignment_expression(parser) {
        Ok((expr, p)) => (Some(expr), p)
        Err(p) => (None, p)
      }
    }
    Comma(_) | CloseBrace(_) => (None, parser)
    // Error recovery: unexpected token after member name - report TS1357
    tok => {
      let err_loc = tok.location()
      let parser = add_error_with_code(
        parser,
        EnumMemberExpectedCommaOrEquals.to_message(),
        err_loc,
        EnumMemberExpectedCommaOrEquals,
      )
      // Skip tokens until we find comma, close brace, or another valid member start
      let parser = skip_until_enum_member_recovery(parser)
      (None, parser)
    }
  }
  acc.push(EnumMember::{ name, initializer, location: loc })
  // Check for comma
  match current_token(parser) {
    Comma(_) => parse_enum_members_aux(advance_parser(parser), acc)
    CloseBrace(_) | EOF(_) => (acc, parser)
    // Error recovery: continue to next member if we can identify one
    Identifier(_, _) | NumericLiteral(_, _) | StringLiteral(_, _) =>
      parse_enum_members_aux(parser, acc)
    // Handle type keywords as potential next members
    KeywordAny(_)
    | KeywordNumber(_)
    | KeywordString(_)
    | KeywordBoolean(_)
    | KeywordSymbol(_)
    | KeywordBigInt(_)
    | KeywordObject(_)
    | KeywordNever(_)
    | KeywordUnknown(_)
    | KeywordUndefined(_)
    | KeywordVoid(_) => parse_enum_members_aux(parser, acc)
    _ => (acc, parser)
  }
}

///|
fn parse_enum_members_aux(
  parser : Parser,
  acc : Array[EnumMember],
) -> (Array[EnumMember], Parser) {
  match current_token(parser) {
    CloseBrace(_) | EOF(_) => (acc, parser)
    Identifier(name, loc) => {
      let parser = advance_parser(parser)
      // Check for initializer or error recovery
      let (initializer, parser) = match current_token(parser) {
        Equals(_) => {
          let parser = advance_parser(parser)
          match parse_assignment_expression(parser) {
            Ok((expr, p)) => (Some(expr), p)
            Err(p) => (None, p)
          }
        }
        Comma(_) | CloseBrace(_) => (None, parser)
        // Error recovery: unexpected token after member name
        Semicolon(err_loc) => {
          // TS1357: An enum member name must be followed by a ',', '=', or '}'
          let parser = add_error_with_code(
            parser,
            EnumMemberExpectedCommaOrEquals.to_message(),
            err_loc,
            EnumMemberExpectedCommaOrEquals,
          )
          // Skip the semicolon and continue
          (None, advance_parser(parser))
        }
        Colon(err_loc) => {
          // TS1357: An enum member name must be followed by a ',', '=', or '}'
          let parser = add_error_with_code(
            parser,
            EnumMemberExpectedCommaOrEquals.to_message(),
            err_loc,
            EnumMemberExpectedCommaOrEquals,
          )
          // Skip tokens until we find comma, close brace, or another valid member start
          let parser = skip_until_enum_member_recovery(advance_parser(parser))
          (None, parser)
        }
        _ => (None, parser)
      }
      acc.push(EnumMember::{ name, initializer, location: loc })
      // Check for comma
      match current_token(parser) {
        Comma(_) => parse_enum_members_aux(advance_parser(parser), acc)
        CloseBrace(_) | EOF(_) => (acc, parser)
        // Error recovery: continue to next member if we can identify one
        Identifier(_, _) => parse_enum_members_aux(parser, acc)
        // Also handle numeric literals in recovery (to report TS2452)
        NumericLiteral(_, _) => parse_enum_members_aux(parser, acc)
        // Also handle string literals in recovery
        StringLiteral(_, _) => parse_enum_members_aux(parser, acc)
        // Handle type keywords as potential next members
        KeywordAny(_)
        | KeywordNumber(_)
        | KeywordString(_)
        | KeywordBoolean(_)
        | KeywordSymbol(_)
        | KeywordBigInt(_)
        | KeywordObject(_)
        | KeywordNever(_)
        | KeywordUnknown(_)
        | KeywordUndefined(_)
        | KeywordVoid(_) => parse_enum_members_aux(parser, acc)
        _ => (acc, parser)
      }
    }
    // Handle numeric literals as enum member names (TS2452)
    NumericLiteral(_, loc) => {
      // Add TS2452 error: An enum member cannot have a numeric name
      let parser = add_error_with_code(
        parser,
        "An enum member cannot have a numeric name.",
        loc,
        NumericEnumMemberName,
      )
      let parser = advance_parser(parser)
      // Check for comma after the numeric name
      match current_token(parser) {
        Comma(_) => parse_enum_members_aux(advance_parser(parser), acc)
        Semicolon(err_loc) => {
          // Also report TS1357 for semicolon
          let parser = add_error_with_code(
            parser,
            EnumMemberExpectedCommaOrEquals.to_message(),
            err_loc,
            EnumMemberExpectedCommaOrEquals,
          )
          parse_enum_members_aux(advance_parser(parser), acc)
        }
        CloseBrace(_) | EOF(_) => (acc, parser)
        _ => parse_enum_members_aux(parser, acc)
      }
    }
    // Handle string literals as enum member names
    StringLiteral(name, loc) => {
      let parser = advance_parser(parser)
      // Check for initializer or error recovery
      let (initializer, parser) = match current_token(parser) {
        Equals(_) => {
          let parser = advance_parser(parser)
          match parse_assignment_expression(parser) {
            Ok((expr, p)) => (Some(expr), p)
            Err(p) => (None, p)
          }
        }
        Comma(_) | CloseBrace(_) => (None, parser)
        // Error recovery: unexpected token after member name - report TS1357
        tok => {
          let err_loc = tok.location()
          let parser = add_error_with_code(
            parser,
            EnumMemberExpectedCommaOrEquals.to_message(),
            err_loc,
            EnumMemberExpectedCommaOrEquals,
          )
          // Skip tokens until we find comma, close brace, or another valid member start
          let parser = skip_until_enum_member_recovery(parser)
          (None, parser)
        }
      }
      acc.push(EnumMember::{ name, initializer, location: loc })
      // Check for comma
      match current_token(parser) {
        Comma(_) => parse_enum_members_aux(advance_parser(parser), acc)
        CloseBrace(_) | EOF(_) => (acc, parser)
        // Continue recovery for next member
        Identifier(_, _) | NumericLiteral(_, _) | StringLiteral(_, _) =>
          parse_enum_members_aux(parser, acc)
        // Handle type keywords as potential next members
        KeywordAny(_)
        | KeywordNumber(_)
        | KeywordString(_)
        | KeywordBoolean(_)
        | KeywordSymbol(_)
        | KeywordBigInt(_)
        | KeywordObject(_)
        | KeywordNever(_)
        | KeywordUnknown(_)
        | KeywordUndefined(_)
        | KeywordVoid(_) => parse_enum_members_aux(parser, acc)
        _ => (acc, parser)
      }
    }
    // Handle type keywords as enum member names (they're valid identifiers in this context)
    KeywordAny(loc) => parse_enum_member_with_name(parser, "any", loc, acc)
    KeywordNumber(loc) =>
      parse_enum_member_with_name(parser, "number", loc, acc)
    KeywordString(loc) =>
      parse_enum_member_with_name(parser, "string", loc, acc)
    KeywordBoolean(loc) =>
      parse_enum_member_with_name(parser, "boolean", loc, acc)
    KeywordSymbol(loc) =>
      parse_enum_member_with_name(parser, "symbol", loc, acc)
    KeywordBigInt(loc) =>
      parse_enum_member_with_name(parser, "bigint", loc, acc)
    KeywordObject(loc) =>
      parse_enum_member_with_name(parser, "object", loc, acc)
    KeywordNever(loc) => parse_enum_member_with_name(parser, "never", loc, acc)
    KeywordUnknown(loc) =>
      parse_enum_member_with_name(parser, "unknown", loc, acc)
    KeywordUndefined(loc) =>
      parse_enum_member_with_name(parser, "undefined", loc, acc)
    KeywordVoid(loc) => parse_enum_member_with_name(parser, "void", loc, acc)
    // Error recovery for other unexpected tokens
    _ => {
      // Skip unexpected token and try to continue
      let parser = advance_parser(parser)
      parse_enum_members_aux(parser, acc)
    }
  }
}

///|
/// Skip tokens until we find a valid enum member recovery point
fn skip_until_enum_member_recovery(parser : Parser) -> Parser {
  match current_token(parser) {
    Comma(_) | CloseBrace(_) | EOF(_) => parser
    Identifier(_, _) => parser // Found next member name
    // Stop at type keywords (they can be used as enum member names)
    KeywordAny(_)
    | KeywordNumber(_)
    | KeywordString(_)
    | KeywordBoolean(_)
    | KeywordSymbol(_)
    | KeywordBigInt(_)
    | KeywordObject(_)
    | KeywordNever(_)
    | KeywordUnknown(_)
    | KeywordUndefined(_)
    | KeywordVoid(_) => parser
    // Stop at numeric literals to report TS2452
    NumericLiteral(_, _) => parser // Let main loop handle it
    // Stop at string literals to report TS1357
    StringLiteral(_, _) => parser // Let main loop handle it
    _ => skip_until_enum_member_recovery(advance_parser(parser))
  }
}

///|
/// Parse namespace or module declaration
fn parse_module_declaration(parser : Parser) -> Result[(Node, Parser), Parser] {
  // namespace Name { statements }
  // module Name { statements }
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'namespace' or 'module'
  parse_module_declaration_body(parser, start_loc)
}

///|
/// Parse the body of a module declaration (after the keyword)
/// This handles dotted names like A.B.C
fn parse_module_declaration_body(
  parser : Parser,
  start_loc : SourceLocation,
) -> Result[(Node, Parser), Parser] {
  // Parse namespace/module name
  let (name, is_ambient, parser) = match current_token(parser) {
    Identifier(n, _) => (n, false, advance_parser(parser))
    StringLiteral(s, _) => (s, true, advance_parser(parser)) // For ambient modules like declare module "fs"
    _ =>
      return Err(
        add_error_with_code(
          parser,
          "Identifier expected",
          current_token(parser).location(),
          IdentifierExpected,
        ),
      )
  }

  // Parse body
  match current_token(parser) {
    OpenBrace(_) =>
      // Parse block body
      match parse_block_statement(parser) {
        Ok((body, parser)) => {
          let end_loc = get_location(body)
          Ok(
            (
              Node::ModuleDeclaration(ModuleDeclaration::{
                name,
                body: Some(body),
                is_ambient,
                is_global_augmentation: false,
                modifiers: [],
                location: SourceLocation::new(
                  start_loc.file_path,
                  start_loc.start,
                  end_loc.end,
                ),
              }),
              parser,
            ),
          )
        }
        Err(p) => Err(p)
      }
    Dot(_) => {
      // Dotted name like namespace A.B.C - recurse to parse B.C
      let parser = advance_parser(parser)
      let nested_start_loc = current_token(parser).location()
      match parse_module_declaration_body(parser, nested_start_loc) {
        Ok((nested, parser)) => {
          let end_loc = get_location(nested)
          Ok(
            (
              Node::ModuleDeclaration(ModuleDeclaration::{
                name,
                body: Some(nested),
                is_ambient: false, // Dotted names are not ambient
                is_global_augmentation: false,
                modifiers: [],
                location: SourceLocation::new(
                  start_loc.file_path,
                  start_loc.start,
                  end_loc.end,
                ),
              }),
              parser,
            ),
          )
        }
        Err(p) => Err(p)
      }
    }
    _ => {
      // Empty module/namespace (declaration only)
      let parser = expect_semicolon(parser)
      Ok(
        (
          Node::ModuleDeclaration(ModuleDeclaration::{
            name,
            body: None,
            is_ambient,
            is_global_augmentation: false,
            modifiers: [],
            location: start_loc,
          }),
          parser,
        ),
      )
    }
  }
}

///|
fn parse_import_declaration(parser : Parser) -> Result[(Node, Parser), Parser] {
  // import [importClause] from 'module'
  // import 'module'
  // import type { ... } from 'module'  (type-only import)
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'import'

  // Check for type-only import: import type ...
  let (is_type_only, parser) = match current_token(parser) {
    KeywordType(_) => {
      // Peek ahead to see if this is "import type X" or just "import type" as a name
      // If the next token is an identifier, '{', or '*', it's a type-only import
      let next = peek_token(parser)
      match next {
        Identifier(_, _) | OpenBrace(_) | Star(_) =>
          (true, advance_parser(parser))
        _ => (false, parser) // Not a type-only import, 'type' might be a binding name
      }
    }
    _ => (false, parser)
  }

  // Check for side-effect only import: import 'module'
  match current_token(parser) {
    StringLiteral(module_specifier, _) => {
      let parser = advance_parser(parser)
      // Consume optional semicolon
      let parser = match current_token(parser) {
        Semicolon(_) => advance_parser(parser)
        _ => parser
      }
      let end_loc = current_token(parser).location()
      return Ok(
        (
          Node::ImportDeclaration(ImportDeclaration::{
            import_clause: None,
            module_specifier,
            is_type_only,
            location: SourceLocation::new(
              start_loc.file_path,
              start_loc.start,
              end_loc.end,
            ),
          }),
          parser,
        ),
      )
    }
    _ => ()
  }

  // Parse import clause (default and/or named imports)
  // First, check for import equals declaration: import X = M.N
  let (default_import, parser) = match current_token(parser) {
    Identifier(name, _) => {
      let parser = advance_parser(parser)
      // Check for import equals declaration: import X = M.N or import X = require("module")
      match current_token(parser) {
        Equals(_) => {
          // This is an import equals declaration
          let parser = advance_parser(parser) // consume '='
          // Check for require("module") syntax
          let (module_reference, parser) = match current_token(parser) {
            Identifier(id_name, req_loc) =>
              if id_name == "require" {
                // Parse require("module")
                let parser = advance_parser(parser) // consume 'require'
                match current_token(parser) {
                  OpenParen(_) => {
                    let parser = advance_parser(parser) // consume '('
                    match current_token(parser) {
                      StringLiteral(module_path, str_loc) => {
                        let parser = advance_parser(parser) // consume string
                        match current_token(parser) {
                          CloseParen(_) => {
                            let parser = advance_parser(parser) // consume ')'
                            (
                              ModuleReference::ExternalModuleReference(
                                module_path, str_loc,
                              ),
                              parser,
                            )
                          }
                          _ => {
                            // Fall back to entity name parsing
                            let (entity, parser) = parse_entity_name_from(
                              parser,
                              Identifier(id_name, req_loc),
                            )
                            (ModuleReference::EntityName(entity), parser)
                          }
                        }
                      }
                      _ => {
                        // Fall back to entity name parsing
                        let (entity, parser) = parse_entity_name_from(
                          parser,
                          Identifier(id_name, req_loc),
                        )
                        (ModuleReference::EntityName(entity), parser)
                      }
                    }
                  }
                  _ => {
                    // Not require(), parse as entity name
                    let (entity, parser) = parse_entity_name_from(
                      parser,
                      Identifier(id_name, req_loc),
                    )
                    (ModuleReference::EntityName(entity), parser)
                  }
                }
              } else {
                // Regular entity name
                let (entity, parser) = parse_entity_name_from(
                  parser,
                  Identifier(id_name, req_loc),
                )
                (ModuleReference::EntityName(entity), parser)
              }
            _ => {
              let (entity, parser) = parse_entity_name(parser)
              (ModuleReference::EntityName(entity), parser)
            }
          }
          // Consume optional semicolon
          let parser = match current_token(parser) {
            Semicolon(_) => advance_parser(parser)
            _ => parser
          }
          let end_loc = current_token(parser).location()
          return Ok(
            (
              Node::ImportEqualsDeclaration(ImportEqualsDeclaration::{
                name,
                module_reference,
                is_export: false,
                is_type_only: false,
                location: SourceLocation::new(
                  start_loc.file_path,
                  start_loc.start,
                  end_loc.end,
                ),
              }),
              parser,
            ),
          )
        }
        Comma(_) => {
          // Mixed import: import foo, { bar } from 'mod'
          let parser = advance_parser(parser)
          (Some(name), parser)
        }
        _ => (Some(name), parser)
      }
    }
    _ => (None, parser)
  }

  // Parse named bindings (namespace or named imports)
  let (named_bindings, parser) = match current_token(parser) {
    Star(_) => {
      // Namespace import: * as name
      let parser = advance_parser(parser)
      match current_token(parser) {
        KeywordAs(_) => {
          let parser = advance_parser(parser)
          // Try to get identifier or contextual keyword for namespace binding
          match try_get_identifier_name(current_token(parser)) {
            Some((name, loc)) => {
              let parser = advance_parser(parser)
              (Some(NamedImports::NamespaceImport(name, loc)), parser)
            }
            None =>
              return Err(
                add_error_with_code(
                  parser,
                  "Identifier expected",
                  current_token(parser).location(),
                  IdentifierExpected,
                ),
              )
          }
        }
        _ =>
          return Err(
            add_error(
              parser,
              "Unexpected token",
              current_token(parser).location(),
            ),
          )
      }
    }
    OpenBrace(_) => {
      // Named imports: { a, b, c as d }
      let parser = advance_parser(parser)
      let (specifiers, parser) = parse_import_specifiers(parser)
      match current_token(parser) {
        CloseBrace(loc) => {
          let parser = advance_parser(parser)
          (Some(NamedImports::NamedImports(specifiers, loc)), parser)
        }
        _ =>
          return Err(
            add_error_with_code(
              parser,
              ExpectedCloseBrace.to_message(),
              current_token(parser).location(),
              ExpectedCloseBrace,
            ),
          )
      }
    }
    _ => (None, parser)
  }

  // Expect 'from' keyword
  let parser = match current_token(parser) {
    KeywordFrom(_) => advance_parser(parser)
    _ => return Err(add_unexpected_token_error(parser))
  }

  // Parse module specifier (string literal)
  // TS1440: The 'import' path must be a string literal
  let (module_specifier, parser) = match current_token(parser) {
    StringLiteral(spec, _) => (spec, advance_parser(parser))
    _ =>
      return Err(
        add_error_with_code(
          parser,
          ImportPathNotStringLiteral.to_message(),
          current_token(parser).location(),
          ImportPathNotStringLiteral,
        ),
      )
  }
  let end_loc = current_token(parser).location()

  // Build import clause if we have default or named imports
  let import_clause = if default_import is None && named_bindings is None {
    None
  } else {
    Some(ImportClause::{
      name: default_import,
      named_bindings,
      location: SourceLocation::new(
        start_loc.file_path,
        start_loc.start,
        end_loc.end,
      ),
    })
  }

  // Consume optional semicolon
  let parser = match current_token(parser) {
    Semicolon(_) => advance_parser(parser)
    _ => parser
  }
  Ok(
    (
      Node::ImportDeclaration(ImportDeclaration::{
        import_clause,
        module_specifier,
        is_type_only,
        location: SourceLocation::new(
          start_loc.file_path,
          start_loc.start,
          end_loc.end,
        ),
      }),
      parser,
    ),
  )
}

///|
/// Helper: Parse import specifiers { a, b as c, d }
fn parse_import_specifiers(parser : Parser) -> (Array[ImportSpecifier], Parser) {
  parse_import_specifiers_aux(parser, [])
}

///|
/// Tail-recursive helper for parsing import specifiers
fn parse_import_specifiers_aux(
  parser : Parser,
  acc : Array[ImportSpecifier],
) -> (Array[ImportSpecifier], Parser) {
  match current_token(parser) {
    CloseBrace(_) | EOF(_) => (acc, parser)
    // Check for inline type import: { type Foo }
    KeywordType(_) => {
      let parser = advance_parser(parser) // consume 'type'
      // Try to get identifier or contextual keyword for type import
      match try_get_identifier_name(current_token(parser)) {
        Some((name, loc)) => {
          let parser = advance_parser(parser)
          parse_import_specifier_with_name(parser, name, loc, true, acc)
        }
        None => (acc, parser) // Error, but continue
      }
    }
    Identifier(name, loc) => {
      let parser = advance_parser(parser)
      parse_import_specifier_with_name(parser, name, loc, false, acc)
    }
    // Handle 'default' keyword as property name (e.g., import { default as d })
    KeywordDefault(loc) => {
      let parser = advance_parser(parser)
      parse_import_specifier_with_name(parser, "default", loc, false, acc)
    }
    // Handle contextual keywords as property names (e.g., import { as })
    _ =>
      match try_get_identifier_name(current_token(parser)) {
        Some((name, loc)) => {
          let parser = advance_parser(parser)
          parse_import_specifier_with_name(parser, name, loc, false, acc)
        }
        None => (acc, parser) // Not a valid token, return
      }
  }
}

///|
/// Parse export declaration with decorators: @decorator export class ...
fn parse_export_declaration_with_decorators(
  parser : Parser,
  decorators : Array[Node],
) -> Result[(Node, Parser), Parser] {
  let parser = advance_parser(parser) // consume 'export'
  match current_token(parser) {
    // @decorator export default class ...
    KeywordDefault(_) => {
      let parser = advance_parser(parser)
      match current_token(parser) {
        KeywordClass(_) =>
          match
            parse_class_declaration_with_decorators(parser, false, decorators) {
            Ok((decl, parser)) => {
              let decl_with_modifiers = add_export_default_modifiers(decl)
              Ok((decl_with_modifiers, parser))
            }
            Err(p) => Err(p)
          }
        KeywordAbstract(_) => {
          let parser = advance_parser(parser)
          match
            parse_class_declaration_with_decorators(parser, true, decorators) {
            Ok((decl, parser)) => {
              let decl_with_modifiers = add_export_default_modifiers(decl)
              Ok((decl_with_modifiers, parser))
            }
            Err(p) => Err(p)
          }
        }
        _ => {
          let loc = current_token(parser).location()
          Err(
            add_error_with_code(
              parser,
              DecoratorsNotValidHere.to_message(),
              loc,
              DecoratorsNotValidHere,
            ),
          )
        }
      }
    }
    // @decorator export class ...
    KeywordClass(_) =>
      match parse_class_declaration_with_decorators(parser, false, decorators) {
        Ok((decl, parser)) => {
          let decl_with_export = add_export_modifier(decl)
          Ok((decl_with_export, parser))
        }
        Err(p) => Err(p)
      }
    // @decorator export abstract class ...
    KeywordAbstract(_) => {
      let parser = advance_parser(parser)
      match parse_class_declaration_with_decorators(parser, true, decorators) {
        Ok((decl, parser)) => {
          let decl_with_export = add_export_modifier(decl)
          Ok((decl_with_export, parser))
        }
        Err(p) => Err(p)
      }
    }
    _ => {
      let loc = get_location(decorators[0])
      Err(
        add_error_with_code(
          parser,
          DecoratorsNotValidHere.to_message(),
          loc,
          DecoratorsNotValidHere,
        ),
      )
    }
  }
}

///|
fn parse_export_declaration(parser : Parser) -> Result[(Node, Parser), Parser] {
  // export { a, b }
  // export { a, b } from 'module'
  // export * from 'module'
  // export default expression
  // export const/let/var/function/class ...
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'export'

  // TS1432: Check if decorator appears after 'export' - add error but continue
  let (decorators_after_export, parser) = match current_token(parser) {
    At(loc) => {
      let parser = add_error_with_code(
        parser,
        DecoratorsNotAfterExport.to_message(),
        loc,
        DecoratorsNotAfterExport,
      )
      // Parse the decorators so we can continue
      let (decorators, parser) = parse_decorators(parser)
      (decorators, parser)
    }
    _ => ([], parser)
  }
  match current_token(parser) {
    // export default expression/declaration
    KeywordDefault(_) => {
      let parser = advance_parser(parser)
      // Check if it's a declaration (function or class)
      match current_token(parser) {
        KeywordFunction(_) | KeywordClass(_) =>
          // Parse as declaration and add Export + Default modifiers
          match parse_statement(parser) {
            Ok((declaration, parser)) => {
              let decl_with_modifiers = add_export_default_modifiers(
                declaration,
              )
              Ok((decl_with_modifiers, parser))
            }
            Err(p) => Err(p)
          }
        _ =>
          // Parse as expression - use ExportAssignment
          match parse_expression(parser) {
            Ok((expression, parser)) => {
              let end_loc = get_location(expression)
              // Consume optional semicolon
              let parser = match current_token(parser) {
                Semicolon(_) => advance_parser(parser)
                _ => parser
              }
              Ok(
                (
                  Node::ExportAssignment(ExportAssignment::{
                    expression,
                    is_export_equals: false,
                    location: SourceLocation::new(
                      start_loc.file_path,
                      start_loc.start,
                      end_loc.end,
                    ),
                  }),
                  parser,
                ),
              )
            }
            Err(p) => Err(p)
          }
      }
    }

    // export * from 'module' OR export * as ns from 'module'
    Star(_) => {
      let star_loc = current_token(parser).location()
      let parser = advance_parser(parser)
      match current_token(parser) {
        // export * as ns from 'module'
        KeywordAs(_) => {
          let parser = advance_parser(parser) // consume 'as'
          match current_token(parser) {
            Identifier(ns_name, _) => {
              let parser = advance_parser(parser) // consume namespace name
              match current_token(parser) {
                KeywordFrom(_) => {
                  let parser = advance_parser(parser) // consume 'from'
                  match current_token(parser) {
                    StringLiteral(module_specifier, _) => {
                      let parser = advance_parser(parser)
                      // Consume optional semicolon
                      let parser = match current_token(parser) {
                        Semicolon(_) => advance_parser(parser)
                        _ => parser
                      }
                      let end_loc = current_token(parser).location()
                      Ok(
                        (
                          Node::ExportDeclaration(ExportDeclaration::{
                            export_clause: Some(
                              NamedExports::NamespaceExport(ns_name, star_loc),
                            ),
                            module_specifier: Some(module_specifier),
                            is_type_only: false,
                            location: SourceLocation::new(
                              start_loc.file_path,
                              start_loc.start,
                              end_loc.end,
                            ),
                          }),
                          parser,
                        ),
                      )
                    }
                    _ =>
                      Err(
                        add_error(
                          parser,
                          "Unexpected token",
                          current_token(parser).location(),
                        ),
                      )
                  }
                }
                _ =>
                  Err(
                    add_error(
                      parser,
                      "Unexpected token",
                      current_token(parser).location(),
                    ),
                  )
              }
            }
            _ =>
              Err(
                add_error_with_code(
                  parser,
                  "Identifier expected",
                  current_token(parser).location(),
                  IdentifierExpected,
                ),
              )
          }
        }
        // export * from 'module'
        KeywordFrom(_) => {
          let parser = advance_parser(parser)
          match current_token(parser) {
            StringLiteral(module_specifier, _) => {
              let parser = advance_parser(parser)
              // Consume optional semicolon
              let parser = match current_token(parser) {
                Semicolon(_) => advance_parser(parser)
                _ => parser
              }
              let end_loc = current_token(parser).location()
              Ok(
                (
                  Node::ExportDeclaration(ExportDeclaration::{
                    export_clause: None,
                    module_specifier: Some(module_specifier),
                    is_type_only: false,
                    location: SourceLocation::new(
                      start_loc.file_path,
                      start_loc.start,
                      end_loc.end,
                    ),
                  }),
                  parser,
                ),
              )
            }
            _ =>
              Err(
                add_error(
                  parser,
                  "Unexpected token",
                  current_token(parser).location(),
                ),
              )
          }
        }
        _ =>
          Err(
            add_error(
              parser,
              "Unexpected token",
              current_token(parser).location(),
            ),
          )
      }
    }

    // export type { a, b } [from 'module'] OR export type Foo = ...
    KeywordType(_) => {
      // Look ahead to determine if this is `export type { ... }` or `export type Foo = ...`
      let parser_after_type = advance_parser(parser) // consume 'type'
      match current_token(parser_after_type) {
        // export type { a, b } [from 'module']
        OpenBrace(_) => {
          let parser = advance_parser(parser_after_type)
          let (specifiers, parser) = parse_export_specifiers(parser)
          match current_token(parser) {
            CloseBrace(loc) => {
              let parser = advance_parser(parser)
              // Check for 'from' clause
              let (module_specifier, parser) = match current_token(parser) {
                KeywordFrom(_) => {
                  let parser = advance_parser(parser)
                  match current_token(parser) {
                    StringLiteral(spec, _) =>
                      (Some(spec), advance_parser(parser))
                    _ =>
                      return Err(
                        add_error(
                          parser,
                          "Unexpected token",
                          current_token(parser).location(),
                        ),
                      )
                  }
                }
                _ => (None, parser)
              }
              // Consume optional semicolon
              let parser = match current_token(parser) {
                Semicolon(_) => advance_parser(parser)
                _ => parser
              }
              let end_loc = current_token(parser).location()
              Ok(
                (
                  Node::ExportDeclaration(ExportDeclaration::{
                    export_clause: Some(
                      NamedExports::NamedExports(specifiers, loc),
                    ),
                    module_specifier,
                    is_type_only: true,
                    location: SourceLocation::new(
                      start_loc.file_path,
                      start_loc.start,
                      end_loc.end,
                    ),
                  }),
                  parser,
                ),
              )
            }
            _ =>
              Err(
                add_error_with_code(
                  parser,
                  ExpectedCloseBrace.to_message(),
                  current_token(parser).location(),
                  ExpectedCloseBrace,
                ),
              )
          }
        }
        // export type Foo = ... (type alias declaration with export)
        _ =>
          // Parse as type alias declaration (parser is still at 'type' keyword) and add Export modifier
          match parse_type_alias_declaration(parser) {
            Ok((type_alias, parser)) => {
              let type_alias_with_export = add_export_modifier(type_alias)
              Ok((type_alias_with_export, parser))
            }
            Err(p) => Err(p)
          }
      }
    }

    // export { a, b } [from 'module']
    OpenBrace(_) => {
      let parser = advance_parser(parser)
      let (specifiers, parser) = parse_export_specifiers(parser)
      match current_token(parser) {
        CloseBrace(loc) => {
          let parser = advance_parser(parser)
          // Check for 'from' clause
          let (module_specifier, parser) = match current_token(parser) {
            KeywordFrom(_) => {
              let parser = advance_parser(parser)
              match current_token(parser) {
                StringLiteral(spec, _) => (Some(spec), advance_parser(parser))
                _ =>
                  return Err(
                    add_error(
                      parser,
                      "Unexpected token",
                      current_token(parser).location(),
                    ),
                  )
              }
            }
            _ => (None, parser)
          }
          // Consume optional semicolon
          let parser = match current_token(parser) {
            Semicolon(_) => advance_parser(parser)
            _ => parser
          }
          let end_loc = current_token(parser).location()
          Ok(
            (
              Node::ExportDeclaration(ExportDeclaration::{
                export_clause: Some(NamedExports::NamedExports(specifiers, loc)),
                module_specifier,
                is_type_only: false,
                location: SourceLocation::new(
                  start_loc.file_path,
                  start_loc.start,
                  end_loc.end,
                ),
              }),
              parser,
            ),
          )
        }
        _ =>
          Err(
            add_error_with_code(
              parser,
              ExpectedCloseBrace.to_message(),
              current_token(parser).location(),
              ExpectedCloseBrace,
            ),
          )
      }
    }

    // export declaration (const, let, var, function, class, etc.)
    _ =>
      // If we parsed decorators after export (TS1432), use them
      if decorators_after_export.length() > 0 {
        match current_token(parser) {
          KeywordClass(_) =>
            match
              parse_class_declaration_with_decorators(
                parser, false, decorators_after_export,
              ) {
              Ok((decl, parser)) => {
                let decl_with_export = add_export_modifier(decl)
                Ok((decl_with_export, parser))
              }
              Err(p) => Err(p)
            }
          KeywordAbstract(_) => {
            let parser = advance_parser(parser)
            match
              parse_class_declaration_with_decorators(
                parser, true, decorators_after_export,
              ) {
              Ok((decl, parser)) => {
                let decl_with_export = add_export_modifier(decl)
                Ok((decl_with_export, parser))
              }
              Err(p) => Err(p)
            }
          }
          _ =>
            // Parse normally, decorators will be lost
            match parse_statement(parser) {
              Ok((stmt, parser)) => {
                let stmt_with_export = add_export_modifier(stmt)
                Ok((stmt_with_export, parser))
              }
              Err(p) => Err(p)
            }
        }
      } else {
        // Normal case - no decorators after export
        match parse_statement(parser) {
          Ok((stmt, parser)) => {
            // Add Export modifier to the declaration
            let stmt_with_export = add_export_modifier(stmt)
            Ok((stmt_with_export, parser))
          }
          Err(p) => Err(p)
        }
      }
  }
}

///|
/// Helper: Add Export modifier to a declaration
fn add_export_modifier(node : Node) -> Node {
  match node {
    VariableStatement(vs) => {
      let new_modifiers : Array[Modifier] = [Modifier::Export]
      for m in vs.modifiers {
        new_modifiers.push(m)
      }
      Node::VariableStatement(VariableStatement::{
        declarations: vs.declarations,
        is_const: vs.is_const,
        is_let: vs.is_let,
        modifiers: new_modifiers,
        location: vs.location,
      })
    }
    FunctionDeclaration(fd) => {
      let new_modifiers : Array[Modifier] = [Modifier::Export]
      for m in fd.modifiers {
        new_modifiers.push(m)
      }
      Node::FunctionDeclaration(FunctionDeclaration::{
        name: fd.name,
        type_parameters: fd.type_parameters,
        parameters: fd.parameters,
        return_type: fd.return_type,
        body: fd.body,
        is_async: fd.is_async,
        is_generator: fd.is_generator,
        modifiers: new_modifiers,
        location: fd.location,
      })
    }
    ClassDeclaration(cd) => {
      let new_modifiers : Array[Modifier] = [Modifier::Export]
      for m in cd.modifiers {
        new_modifiers.push(m)
      }
      Node::ClassDeclaration(ClassDeclaration::{
        name: cd.name,
        type_parameters: cd.type_parameters,
        heritage_clauses: cd.heritage_clauses,
        members: cd.members,
        is_abstract: cd.is_abstract,
        decorators: cd.decorators,
        modifiers: new_modifiers,
        location: cd.location,
      })
    }
    InterfaceDeclaration(id) => {
      let new_modifiers : Array[Modifier] = [Modifier::Export]
      for m in id.modifiers {
        new_modifiers.push(m)
      }
      Node::InterfaceDeclaration(InterfaceDeclaration::{
        name: id.name,
        type_parameters: id.type_parameters,
        heritage_clauses: id.heritage_clauses,
        members: id.members,
        modifiers: new_modifiers,
        location: id.location,
      })
    }
    TypeAliasDeclaration(ta) => {
      let new_modifiers : Array[Modifier] = [Modifier::Export]
      for m in ta.modifiers {
        new_modifiers.push(m)
      }
      Node::TypeAliasDeclaration(TypeAliasDeclaration::{
        name: ta.name,
        type_parameters: ta.type_parameters,
        type_node: ta.type_node,
        modifiers: new_modifiers,
        location: ta.location,
      })
    }
    EnumDeclaration(ed) => {
      let new_modifiers : Array[Modifier] = [Modifier::Export]
      for m in ed.modifiers {
        new_modifiers.push(m)
      }
      Node::EnumDeclaration(EnumDeclaration::{
        name: ed.name,
        name_location: ed.name_location,
        members: ed.members,
        is_const: ed.is_const,
        modifiers: new_modifiers,
        location: ed.location,
      })
    }
    ImportEqualsDeclaration(ied) =>
      Node::ImportEqualsDeclaration(ImportEqualsDeclaration::{
        name: ied.name,
        module_reference: ied.module_reference,
        is_export: true,
        is_type_only: ied.is_type_only,
        location: ied.location,
      })
    ModuleDeclaration(md) => {
      let new_modifiers : Array[Modifier] = [Modifier::Export]
      for m in md.modifiers {
        new_modifiers.push(m)
      }
      Node::ModuleDeclaration(ModuleDeclaration::{
        name: md.name,
        body: md.body,
        is_ambient: md.is_ambient,
        is_global_augmentation: md.is_global_augmentation,
        modifiers: new_modifiers,
        location: md.location,
      })
    }
    _ => node // For other nodes, return as-is
  }
}

///|
/// Helper: Add Export and Default modifiers to a declaration
fn add_export_default_modifiers(node : Node) -> Node {
  match node {
    FunctionDeclaration(fd) => {
      let new_modifiers : Array[Modifier] = [
        Modifier::Export,
        Modifier::Default,
      ]
      for m in fd.modifiers {
        new_modifiers.push(m)
      }
      Node::FunctionDeclaration(FunctionDeclaration::{
        name: fd.name,
        type_parameters: fd.type_parameters,
        parameters: fd.parameters,
        return_type: fd.return_type,
        body: fd.body,
        is_async: fd.is_async,
        is_generator: fd.is_generator,
        modifiers: new_modifiers,
        location: fd.location,
      })
    }
    ClassDeclaration(cd) => {
      let new_modifiers : Array[Modifier] = [
        Modifier::Export,
        Modifier::Default,
      ]
      for m in cd.modifiers {
        new_modifiers.push(m)
      }
      Node::ClassDeclaration(ClassDeclaration::{
        name: cd.name,
        type_parameters: cd.type_parameters,
        heritage_clauses: cd.heritage_clauses,
        members: cd.members,
        is_abstract: cd.is_abstract,
        decorators: cd.decorators,
        modifiers: new_modifiers,
        location: cd.location,
      })
    }
    _ => node // For other nodes, return as-is
  }
}

///|
/// Parse declare (ambient) declaration
fn parse_declare_declaration(parser : Parser) -> Result[(Node, Parser), Parser] {
  // declare const/let/var/function/class/enum/module/namespace/global
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'declare'

  // Check for 'declare global { }' - global augmentation
  match current_token(parser) {
    Identifier(name, _) if name == "global" => {
      let parser = advance_parser(parser) // consume 'global'
      // Parse block statement { ... }
      match parse_block_statement(parser) {
        Ok((body, parser)) => {
          let end_loc = get_location(body)
          let location = SourceLocation::new(
            start_loc.file_path,
            start_loc.start,
            end_loc.end,
          )
          // Create ModuleDeclaration with is_global_augmentation=true
          Ok(
            (
              Node::ModuleDeclaration(ModuleDeclaration::{
                name: "global",
                body: Some(body),
                is_ambient: false,
                is_global_augmentation: true,
                modifiers: [],
                location,
              }),
              parser,
            ),
          )
        }
        Err(p) => Err(p)
      }
    }
    _ =>
      match parse_statement(parser) {
        Ok((stmt, parser)) => {
          // Add Declare modifier to the declaration
          let stmt_with_declare = add_declare_modifier(stmt)
          Ok((stmt_with_declare, parser))
        }
        Err(p) => Err(p)
      }
  }
}

///|
/// Helper: Add Declare modifier to a declaration
fn add_declare_modifier(node : Node) -> Node {
  match node {
    VariableStatement(vs) => {
      let new_modifiers : Array[Modifier] = [Modifier::Declare]
      for m in vs.modifiers {
        new_modifiers.push(m)
      }
      Node::VariableStatement(VariableStatement::{
        declarations: vs.declarations,
        is_const: vs.is_const,
        is_let: vs.is_let,
        modifiers: new_modifiers,
        location: vs.location,
      })
    }
    FunctionDeclaration(fd) => {
      let new_modifiers : Array[Modifier] = [Modifier::Declare]
      for m in fd.modifiers {
        new_modifiers.push(m)
      }
      Node::FunctionDeclaration(FunctionDeclaration::{
        name: fd.name,
        type_parameters: fd.type_parameters,
        parameters: fd.parameters,
        return_type: fd.return_type,
        body: fd.body,
        is_async: fd.is_async,
        is_generator: fd.is_generator,
        modifiers: new_modifiers,
        location: fd.location,
      })
    }
    ClassDeclaration(cd) => {
      let new_modifiers : Array[Modifier] = [Modifier::Declare]
      for m in cd.modifiers {
        new_modifiers.push(m)
      }
      Node::ClassDeclaration(ClassDeclaration::{
        name: cd.name,
        type_parameters: cd.type_parameters,
        heritage_clauses: cd.heritage_clauses,
        members: cd.members,
        is_abstract: cd.is_abstract,
        decorators: cd.decorators,
        modifiers: new_modifiers,
        location: cd.location,
      })
    }
    InterfaceDeclaration(id) => {
      let new_modifiers : Array[Modifier] = [Modifier::Declare]
      for m in id.modifiers {
        new_modifiers.push(m)
      }
      Node::InterfaceDeclaration(InterfaceDeclaration::{
        name: id.name,
        type_parameters: id.type_parameters,
        heritage_clauses: id.heritage_clauses,
        members: id.members,
        modifiers: new_modifiers,
        location: id.location,
      })
    }
    TypeAliasDeclaration(ta) => {
      let new_modifiers : Array[Modifier] = [Modifier::Declare]
      for m in ta.modifiers {
        new_modifiers.push(m)
      }
      Node::TypeAliasDeclaration(TypeAliasDeclaration::{
        name: ta.name,
        type_parameters: ta.type_parameters,
        type_node: ta.type_node,
        modifiers: new_modifiers,
        location: ta.location,
      })
    }
    EnumDeclaration(ed) => {
      let new_modifiers : Array[Modifier] = [Modifier::Declare]
      for m in ed.modifiers {
        new_modifiers.push(m)
      }
      Node::EnumDeclaration(EnumDeclaration::{
        name: ed.name,
        name_location: ed.name_location,
        members: ed.members,
        is_const: ed.is_const,
        modifiers: new_modifiers,
        location: ed.location,
      })
    }
    _ => node // For other nodes, return as-is
  }
}

///|
/// Try to get an export name from current token (identifier, contextual keyword, or reserved keyword)
fn try_get_export_name(token : Token) -> (String, SourceLocation)? {
  match try_get_identifier_name(token) {
    Some(result) => Some(result)
    None => try_get_reserved_keyword(token)
  }
}

///|
/// Helper: Parse an export specifier with given property name and location
fn parse_export_specifier_with_name(
  parser : Parser,
  name : String,
  loc : SourceLocation,
  is_type_only : Bool,
  acc : Array[ExportSpecifier]
) -> (Array[ExportSpecifier], Parser) {
  // Check for 'as' renaming
  match current_token(parser) {
    KeywordAs(_) => {
      let parser = advance_parser(parser)
      // Try to get identifier, contextual keyword, or reserved keyword for export alias
      match try_get_export_name(current_token(parser)) {
        Some((export_name, _)) => {
          let parser = advance_parser(parser)
          acc.push(ExportSpecifier::{
            property_name: Some(name),
            name: export_name,
            is_type_only,
            location: loc,
          })
          // Check for comma
          match current_token(parser) {
            Comma(_) => parse_export_specifiers_aux(advance_parser(parser), acc)
            _ => (acc, parser)
          }
        }
        None => (acc, parser) // Error, but continue
      }
    }
    _ => {
      // No renaming
      acc.push(ExportSpecifier::{
        property_name: None,
        name,
        is_type_only,
        location: loc,
      })
      // Check for comma
      match current_token(parser) {
        Comma(_) => parse_export_specifiers_aux(advance_parser(parser), acc)
        _ => (acc, parser)
      }
    }
  }
}

///|
/// Helper: Parse an import specifier with given property name and location
fn parse_import_specifier_with_name(
  parser : Parser,
  name : String,
  loc : SourceLocation,
  is_type_only : Bool,
  acc : Array[ImportSpecifier]
) -> (Array[ImportSpecifier], Parser) {
  // Check for 'as' renaming
  match current_token(parser) {
    KeywordAs(_) => {
      let parser = advance_parser(parser)
      // Try to get identifier or contextual keyword for local binding
      match try_get_identifier_name(current_token(parser)) {
        Some((local_name, _)) => {
          let parser = advance_parser(parser)
          acc.push(ImportSpecifier::{
            property_name: Some(name),
            name: local_name,
            is_type_only,
            location: loc,
          })
          // Check for comma
          match current_token(parser) {
            Comma(_) => parse_import_specifiers_aux(advance_parser(parser), acc)
            _ => (acc, parser)
          }
        }
        None => (acc, parser) // Error, but continue
      }
    }
    _ => {
      // No renaming
      acc.push(ImportSpecifier::{
        property_name: None,
        name,
        is_type_only,
        location: loc,
      })
      // Check for comma
      match current_token(parser) {
        Comma(_) => parse_import_specifiers_aux(advance_parser(parser), acc)
        _ => (acc, parser)
      }
    }
  }
}

///|
/// Helper: Parse export specifiers { a, b as c, d }
fn parse_export_specifiers(parser : Parser) -> (Array[ExportSpecifier], Parser) {
  parse_export_specifiers_aux(parser, [])
}

///|
/// Tail-recursive helper for parsing export specifiers
fn parse_export_specifiers_aux(
  parser : Parser,
  acc : Array[ExportSpecifier],
) -> (Array[ExportSpecifier], Parser) {
  match current_token(parser) {
    CloseBrace(_) | EOF(_) => (acc, parser)
    // Check for inline type export: { type Foo }
    KeywordType(_) => {
      let parser = advance_parser(parser) // consume 'type'
      // Try to get identifier or contextual keyword for type export
      match try_get_identifier_name(current_token(parser)) {
        Some((name, loc)) => {
          let parser = advance_parser(parser)
          parse_export_specifier_with_name(parser, name, loc, true, acc)
        }
        None => (acc, parser) // Error, but continue
      }
    }
    Identifier(name, loc) => {
      let parser = advance_parser(parser)
      parse_export_specifier_with_name(parser, name, loc, false, acc)
    }
    // Handle 'default' keyword as property name (e.g., export { default })
    KeywordDefault(loc) => {
      let parser = advance_parser(parser)
      parse_export_specifier_with_name(parser, "default", loc, false, acc)
    }
    // Handle contextual keywords as property names (e.g., export { as })
    _ =>
      match try_get_identifier_name(current_token(parser)) {
        Some((name, loc)) => {
          let parser = advance_parser(parser)
          parse_export_specifier_with_name(parser, name, loc, false, acc)
        }
        None => (acc, parser) // Not a valid token, return
      }
  }
}

///|
fn parse_switch_statement(parser : Parser) -> Result[(Node, Parser), Parser] {
  // switch (expression) { case value: statements; default: statements; }
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'switch'

  // Expect '('
  let parser = match current_token(parser) {
    OpenParen(_) => advance_parser(parser)
    _ =>
      return Err(
        add_error_with_code(
          parser,
          ExpectedOpenParen.to_message(),
          current_token(parser).location(),
          ExpectedOpenParen,
        ),
      )
  }

  // Parse expression
  let (expression, parser) = match parse_expression(parser) {
    Ok((expr, p)) => (expr, p)
    Err(p) => return Err(p)
  }

  // Expect ')'
  let parser = match current_token(parser) {
    CloseParen(_) => advance_parser(parser)
    _ =>
      return Err(
        add_error_with_code(
          parser,
          ExpectedCloseParen.to_message(),
          current_token(parser).location(),
          ExpectedCloseParen,
        ),
      )
  }

  // Expect '{'
  let parser = match current_token(parser) {
    OpenBrace(_) => advance_parser(parser)
    _ =>
      return Err(
        add_error_with_code(
          parser,
          ExpectedOpenBrace.to_message(),
          current_token(parser).location(),
          ExpectedOpenBrace,
        ),
      )
  }

  // Parse case clauses
  let (cases, parser) = parse_case_clauses(parser)

  // Expect '}'
  let end_loc = match current_token(parser) {
    CloseBrace(loc) => loc
    _ =>
      return Err(
        add_error_with_code(
          parser,
          ExpectedCloseBrace.to_message(),
          current_token(parser).location(),
          ExpectedCloseBrace,
        ),
      )
  }
  let parser = advance_parser(parser)
  Ok(
    (
      Node::SwitchStatement(SwitchStatement::{
        expression,
        cases,
        location: SourceLocation::new(
          start_loc.file_path,
          start_loc.start,
          end_loc.end,
        ),
      }),
      parser,
    ),
  )
}

///|
/// Parse case clauses
fn parse_case_clauses(parser : Parser) -> (Array[CaseClause], Parser) {
  parse_case_clauses_aux(parser, [])
}

///|
fn parse_case_clauses_aux(
  parser : Parser,
  acc : Array[CaseClause],
) -> (Array[CaseClause], Parser) {
  match current_token(parser) {
    CloseBrace(_) | EOF(_) => (acc, parser)

    // case expression:
    KeywordCase(loc) => {
      let parser = advance_parser(parser)
      let (expression, parser) = match parse_expression(parser) {
        Ok((expr, p)) => (Some(expr), p)
        Err(p) => (None, p)
      }
      // Expect ':'
      let parser = match current_token(parser) {
        Colon(_) => advance_parser(parser)
        _ => parser // Continue anyway
      }
      // Parse statements until next case/default or close brace
      let (statements, parser) = parse_case_statements(parser)
      acc.push(CaseClause::{ expression, statements, location: loc })
      parse_case_clauses_aux(parser, acc)
    }

    // default:
    KeywordDefault(loc) => {
      let parser = advance_parser(parser)
      // Expect ':'
      let parser = match current_token(parser) {
        Colon(_) => advance_parser(parser)
        _ => parser // Continue anyway
      }
      // Parse statements until next case or close brace
      let (statements, parser) = parse_case_statements(parser)
      acc.push(CaseClause::{ expression: None, statements, location: loc })
      parse_case_clauses_aux(parser, acc)
    }
    _ => (acc, parser)
  }
}

///|
/// Parse statements within a case clause
fn parse_case_statements(parser : Parser) -> (Array[Node], Parser) {
  parse_case_statements_aux(parser, [])
}

///|
fn parse_case_statements_aux(
  parser : Parser,
  acc : Array[Node],
) -> (Array[Node], Parser) {
  match current_token(parser) {
    KeywordCase(_) | KeywordDefault(_) | CloseBrace(_) | EOF(_) => (acc, parser)
    _ =>
      match parse_statement(parser) {
        Ok((stmt, p)) => {
          acc.push(stmt)
          parse_case_statements_aux(p, acc)
        }
        Err(p) => (acc, p)
      }
  }
}

///|
fn parse_for_statement(parser : Parser) -> Result[(Node, Parser), Parser] {
  // for ([init]; [condition]; [incrementor]) statement
  // for (variable in object) statement
  // for (variable of iterable) statement
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'for'

  // Expect '('
  let parser = match current_token(parser) {
    OpenParen(_) => advance_parser(parser)
    _ =>
      return Err(
        add_error_with_code(
          parser,
          ExpectedOpenParen.to_message(),
          current_token(parser).location(),
          ExpectedOpenParen,
        ),
      )
  }

  // Parse initializer (or for-in/for-of variable)
  let (initializer, parser) = match current_token(parser) {
    Semicolon(_) => (None, parser)
    KeywordLet(_) | KeywordConst(_) | KeywordVar(_) =>
      // Use parse_variable_declaration_list to avoid consuming the semicolon
      // The semicolon belongs to the for-loop syntax, not the variable declaration
      match parse_variable_declaration_list(parser, true) {
        Ok((declarations, is_const, is_let, location, p)) => {
          let stmt = Node::VariableStatement(VariableStatement::{
            declarations,
            is_const,
            is_let,
            modifiers: [],
            location,
          })
          (Some(stmt), p)
        }
        Err(p) => (None, p)
      }
    _ =>
      match parse_expression(parser) {
        Ok((expr, p)) => (Some(expr), p)
        Err(p) => (None, p)
      }
  }

  // Check for for-in or for-of
  match current_token(parser) {
    KeywordIn(_) => {
      // for-in loop
      let parser = advance_parser(parser)
      let (expression, parser) = match parse_expression(parser) {
        Ok((expr, p)) => (expr, p)
        Err(p) =>
          return Err(
            add_error_with_code(
              p,
              ExpressionExpected.to_message(),
              current_token(p).location(),
              ExpressionExpected,
            ),
          )
      }
      let parser = match current_token(parser) {
        CloseParen(_) => advance_parser(parser)
        _ =>
          return Err(
            add_error_with_code(
              parser,
              ExpectedCloseParen.to_message(),
              current_token(parser).location(),
              ExpectedCloseParen,
            ),
          )
      }
      let (statement, parser) = match parse_statement(parser) {
        Ok((stmt, p)) => (stmt, p)
        Err(p) => return Err(p)
      }
      let end_loc = get_location(statement)
      return Ok(
        (
          Node::ForInStatement(ForInStatement::{
            initializer: initializer.unwrap_or(
              Node::EmptyStatement(EmptyStatement::{ location: start_loc }),
            ),
            expression,
            statement,
            location: SourceLocation::new(
              start_loc.file_path,
              start_loc.start,
              end_loc.end,
            ),
          }),
          parser,
        ),
      )
    }
    KeywordOf(_) => {
      // for-of loop
      let parser = advance_parser(parser)

      // TS1188: Validate that only a single variable declaration is allowed
      let parser = match initializer {
        Some(Node::VariableStatement(var_stmt)) => {
          if var_stmt.declarations.length() > 1 {
            let diagnostics = parser.diagnostics
            diagnostics.push(Diagnostic::{
              message: "Only a single variable declaration is allowed in a 'for...of' statement.",
              location: var_stmt.location,
              category: DiagnosticCategory::Error,
              code: 1188,
            })
            Parser::{ ..parser, diagnostics }
          } else {
            parser
          }
        }
        _ => parser
      }

      // TS2480: Validate that 'let' is not used as variable name in let/const declarations
      let parser = match initializer {
        Some(Node::VariableStatement(var_stmt)) => {
          if (var_stmt.is_let || var_stmt.is_const) && var_stmt.declarations.length() > 0 {
            match var_stmt.declarations[0].name {
              Node::Identifier(id) => {
                if id.name == "let" {
                  let diagnostics = parser.diagnostics
                  diagnostics.push(Diagnostic::{
                    message: "'let' is not allowed to be used as a name in 'let' or 'const' declarations.",
                    location: id.location,
                    category: DiagnosticCategory::Error,
                    code: 2480,
                  })
                  Parser::{ ..parser, diagnostics }
                } else {
                  parser
                }
              }
              _ => parser
            }
          } else {
            parser
          }
        }
        _ => parser
      }

      let (expression, parser) = match parse_expression(parser) {
        Ok((expr, p)) => (expr, p)
        Err(p) =>
          return Err(
            add_error_with_code(
              p,
              ExpressionExpected.to_message(),
              current_token(p).location(),
              ExpressionExpected,
            ),
          )
      }
      let parser = match current_token(parser) {
        CloseParen(_) => advance_parser(parser)
        _ =>
          return Err(
            add_error_with_code(
              parser,
              ExpectedCloseParen.to_message(),
              current_token(parser).location(),
              ExpectedCloseParen,
            ),
          )
      }
      let (statement, parser) = match parse_statement(parser) {
        Ok((stmt, p)) => (stmt, p)
        Err(p) => return Err(p)
      }
      let end_loc = get_location(statement)
      return Ok(
        (
          Node::ForOfStatement(ForOfStatement::{
            initializer: initializer.unwrap_or(
              Node::EmptyStatement(EmptyStatement::{ location: start_loc }),
            ),
            expression,
            statement,
            await_modifier: false,
            location: SourceLocation::new(
              start_loc.file_path,
              start_loc.start,
              end_loc.end,
            ),
          }),
          parser,
        ),
      )
    }
    _ => ()
  }

  // Regular for loop: for (init; condition; incrementor) statement
  // Expect semicolon after initializer
  let parser = match current_token(parser) {
    Semicolon(_) => advance_parser(parser)
    _ =>
      return Err(
        add_error_with_code(
          parser,
          ExpectedSemicolon.to_message(),
          current_token(parser).location(),
          ExpectedSemicolon,
        ),
      )
  }

  // Parse condition
  let (condition, parser) = match current_token(parser) {
    Semicolon(_) => (None, parser)
    _ =>
      match parse_expression(parser) {
        Ok((expr, p)) => (Some(expr), p)
        Err(p) => (None, p)
      }
  }

  // Expect semicolon after condition
  let parser = match current_token(parser) {
    Semicolon(_) => advance_parser(parser)
    _ =>
      return Err(
        add_error_with_code(
          parser,
          ExpectedSemicolon.to_message(),
          current_token(parser).location(),
          ExpectedSemicolon,
        ),
      )
  }

  // Parse incrementor
  let (incrementor, parser) = match current_token(parser) {
    CloseParen(_) => (None, parser)
    _ =>
      match parse_expression(parser) {
        Ok((expr, p)) => (Some(expr), p)
        Err(p) => (None, p)
      }
  }

  // Expect ')'
  let parser = match current_token(parser) {
    CloseParen(_) => advance_parser(parser)
    _ =>
      return Err(
        add_error_with_code(
          parser,
          ExpectedCloseParen.to_message(),
          current_token(parser).location(),
          ExpectedCloseParen,
        ),
      )
  }

  // Parse statement
  let (statement, parser) = match parse_statement(parser) {
    Ok((stmt, p)) => (stmt, p)
    Err(p) => return Err(p)
  }
  let end_loc = get_location(statement)
  Ok(
    (
      Node::ForStatement(ForStatement::{
        initializer,
        condition,
        incrementor,
        statement,
        location: SourceLocation::new(
          start_loc.file_path,
          start_loc.start,
          end_loc.end,
        ),
      }),
      parser,
    ),
  )
}

///|
fn parse_while_statement(parser : Parser) -> Result[(Node, Parser), Parser] {
  // while (condition) statement
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'while'

  // Expect '('
  let parser = match current_token(parser) {
    OpenParen(_) => advance_parser(parser)
    _ =>
      return Err(
        add_error_with_code(
          parser,
          ExpectedOpenParen.to_message(),
          current_token(parser).location(),
          ExpectedOpenParen,
        ),
      )
  }

  // Parse condition
  let (condition, parser) = match parse_expression(parser) {
    Ok((expr, p)) => (expr, p)
    Err(p) => return Err(p)
  }

  // Expect ')'
  let parser = match current_token(parser) {
    CloseParen(_) => advance_parser(parser)
    _ =>
      return Err(
        add_error_with_code(
          parser,
          ExpectedCloseParen.to_message(),
          current_token(parser).location(),
          ExpectedCloseParen,
        ),
      )
  }

  // Parse statement
  let (statement, parser) = match parse_statement(parser) {
    Ok((stmt, p)) => (stmt, p)
    Err(p) => return Err(p)
  }
  let end_loc = get_location(statement)
  Ok(
    (
      Node::WhileStatement(WhileStatement::{
        condition,
        statement,
        location: SourceLocation::new(
          start_loc.file_path,
          start_loc.start,
          end_loc.end,
        ),
      }),
      parser,
    ),
  )
}

///|
fn parse_do_while_statement(parser : Parser) -> Result[(Node, Parser), Parser] {
  // do statement while (condition);
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'do'

  // Parse statement
  let (statement, parser) = match parse_statement(parser) {
    Ok((stmt, p)) => (stmt, p)
    Err(p) => return Err(p)
  }

  // Expect 'while'
  let parser = match current_token(parser) {
    KeywordWhile(_) => advance_parser(parser)
    _ => return Err(add_unexpected_token_error(parser))
  }

  // Expect '('
  let parser = match current_token(parser) {
    OpenParen(_) => advance_parser(parser)
    _ =>
      return Err(
        add_error_with_code(
          parser,
          ExpectedOpenParen.to_message(),
          current_token(parser).location(),
          ExpectedOpenParen,
        ),
      )
  }

  // Parse condition
  let (condition, parser) = match parse_expression(parser) {
    Ok((expr, p)) => (expr, p)
    Err(p) => return Err(p)
  }

  // Expect ')'
  let parser = match current_token(parser) {
    CloseParen(_) => advance_parser(parser)
    _ =>
      return Err(
        add_error_with_code(
          parser,
          ExpectedCloseParen.to_message(),
          current_token(parser).location(),
          ExpectedCloseParen,
        ),
      )
  }

  // Expect ';'
  let end_loc = current_token(parser).location()
  let parser = match current_token(parser) {
    Semicolon(_) => advance_parser(parser)
    _ => parser // Semicolon is optional in some contexts
  }
  Ok(
    (
      Node::DoWhileStatement(DoWhileStatement::{
        statement,
        condition,
        location: SourceLocation::new(
          start_loc.file_path,
          start_loc.start,
          end_loc.end,
        ),
      }),
      parser,
    ),
  )
}

///|
fn parse_break_statement(parser : Parser) -> Result[(Node, Parser), Parser] {
  // break [label];
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'break'

  // Optional label
  let (label, parser) = match current_token(parser) {
    Identifier(name, _loc) => (Some(name), advance_parser(parser))
    _ => (None, parser)
  }

  // Expect semicolon (optional due to ASI)
  let end_loc = current_token(parser).location()
  let parser = match current_token(parser) {
    Semicolon(_) => advance_parser(parser)
    _ => parser
  }
  Ok(
    (
      Node::BreakStatement(BreakStatement::{
        label,
        location: SourceLocation::new(
          start_loc.file_path,
          start_loc.start,
          end_loc.end,
        ),
      }),
      parser,
    ),
  )
}

///|
fn parse_continue_statement(parser : Parser) -> Result[(Node, Parser), Parser] {
  // continue [label];
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'continue'

  // Optional label
  let (label, parser) = match current_token(parser) {
    Identifier(name, _loc) => (Some(name), advance_parser(parser))
    _ => (None, parser)
  }

  // Expect semicolon (optional due to ASI)
  let end_loc = current_token(parser).location()
  let parser = match current_token(parser) {
    Semicolon(_) => advance_parser(parser)
    _ => parser
  }
  Ok(
    (
      Node::ContinueStatement(ContinueStatement::{
        label,
        location: SourceLocation::new(
          start_loc.file_path,
          start_loc.start,
          end_loc.end,
        ),
      }),
      parser,
    ),
  )
}

///|
fn parse_throw_statement(parser : Parser) -> Result[(Node, Parser), Parser] {
  // throw expression;
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'throw'

  // Parse expression
  let (expression, parser) = match parse_expression(parser) {
    Ok((expr, p)) => (expr, p)
    Err(p) =>
      return Err(
        add_error_with_code(
          p,
          ExpressionExpected.to_message(),
          current_token(p).location(),
          ExpressionExpected,
        ),
      )
  }

  // Expect semicolon (optional due to ASI)
  let end_loc = get_location(expression)
  let parser = match current_token(parser) {
    Semicolon(_) => advance_parser(parser)
    _ => parser
  }
  Ok(
    (
      Node::ThrowStatement(ThrowStatement::{
        expression,
        location: SourceLocation::new(
          start_loc.file_path,
          start_loc.start,
          end_loc.end,
        ),
      }),
      parser,
    ),
  )
}

///|
fn parse_try_statement(parser : Parser) -> Result[(Node, Parser), Parser] {
  // try block catch (variable) block finally block
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'try'

  // Parse try block
  let (try_block, parser) = match parse_block_statement(parser) {
    Ok((block, p)) => (block, p)
    Err(p) =>
      return Err(
        add_error_with_code(
          p,
          ExpectedOpenBrace.to_message(),
          current_token(p).location(),
          ExpectedOpenBrace,
        ),
      )
  }

  // Parse optional catch clause
  let (catch_clause, parser) = match current_token(parser) {
    KeywordCatch(_) => {
      let catch_start = current_token(parser).location()
      let parser = advance_parser(parser) // consume 'catch'

      // Optional parameter (can be identifier, array pattern, or object pattern)
      let (parameter, type_annotation, parser) = match current_token(parser) {
        OpenParen(_) => {
          let parser = advance_parser(parser)
          // Parse catch parameter: identifier, array pattern, or object pattern
          let (param, parser) = match current_token(parser) {
            OpenBracket(_) =>
              // Array destructuring pattern: catch ([a, b])
              match parse_array_binding_pattern(parser) {
                Ok((pattern, p)) => (Some(pattern), p)
                Err(p) => (None, p)
              }
            OpenBrace(_) =>
              // Object destructuring pattern: catch ({ message, name })
              match parse_object_binding_pattern(parser) {
                Ok((pattern, p)) => (Some(pattern), p)
                Err(p) => (None, p)
              }
            CloseParen(_) =>
              // Empty catch: catch ()
              (None, parser)
            _ =>
              // Regular identifier: catch (e)
              match parse_identifier(parser) {
                Ok((id, p)) => (Some(Node::Identifier(id)), p)
                Err(p) => (None, p)
              }
          }
          // Optional type annotation: catch (e: unknown)
          let (param, type_annotation, parser) = match
            (param, current_token(parser)) {
            (Some(p), Colon(_)) => {
              let parser = advance_parser(parser)
              // Parse the type annotation
              match parse_type(parser) {
                Ok((type_node, parser)) => (Some(p), Some(type_node), parser)
                Err(parser) => (Some(p), None, parser)
              }
            }
            (p, _) => (p, None, parser)
          }
          let parser = match current_token(parser) {
            CloseParen(_) => advance_parser(parser)
            _ =>
              return Err(
                add_error_with_code(
                  parser,
                  ExpectedCloseParen.to_message(),
                  current_token(parser).location(),
                  ExpectedCloseParen,
                ),
              )
          }
          (param, type_annotation, parser)
        }
        _ => (None, None, parser)
      }

      // Parse catch block
      let (catch_block, parser) = match parse_block_statement(parser) {
        Ok((block, p)) => (block, p)
        Err(p) =>
          return Err(
            add_error_with_code(
              p,
              ExpectedOpenBrace.to_message(),
              current_token(p).location(),
              ExpectedOpenBrace,
            ),
          )
      }
      let catch_end = get_location(catch_block)
      let clause = CatchClause::{
        variable_declaration: parameter,
        type_annotation,
        block: catch_block,
        location: SourceLocation::new(
          catch_start.file_path,
          catch_start.start,
          catch_end.end,
        ),
      }
      (Some(clause), parser)
    }
    _ => (None, parser)
  }

  // Parse optional finally clause
  let (finally_block, parser) = match current_token(parser) {
    KeywordFinally(_) => {
      let parser = advance_parser(parser) // consume 'finally'
      match parse_block_statement(parser) {
        Ok((block, p)) => (Some(block), p)
        Err(p) =>
          return Err(
            add_error_with_code(
              p,
              ExpectedOpenBrace.to_message(),
              current_token(p).location(),
              ExpectedOpenBrace,
            ),
          )
      }
    }
    _ => (None, parser)
  }

  // Must have either catch or finally
  if catch_clause is None && finally_block is None {
    return Err(add_unexpected_token_error(parser))
  }
  let end_loc = match finally_block {
    Some(block) => get_location(block)
    None =>
      match catch_clause {
        Some(clause) => clause.location
        None => get_location(try_block)
      }
  }
  Ok(
    (
      Node::TryStatement(TryStatement::{
        try_block,
        catch_clause,
        finally_block,
        location: SourceLocation::new(
          start_loc.file_path,
          start_loc.start,
          end_loc.end,
        ),
      }),
      parser,
    ),
  )
}

///|
/// Helper to parse constraint and default for type parameters
fn parse_type_param_constraint_and_default(
  parser : Parser,
) -> (Node?, Node?, Parser) {
  let mut parser = parser

  // Optional constraint (extends)
  let constraint = match current_token(parser) {
    KeywordExtends(_) => {
      parser = advance_parser(parser)
      match parse_type(parser) {
        Ok((ty, p)) => {
          parser = p
          Some(ty)
        }
        Err(p) => {
          parser = p
          None
        }
      }
    }
    _ => None
  }

  // Optional default
  let default_type = match current_token(parser) {
    Equals(_) => {
      parser = advance_parser(parser)
      match parse_type(parser) {
        Ok((ty, p)) => {
          parser = p
          Some(ty)
        }
        Err(p) => {
          parser = p
          None
        }
      }
    }
    _ => None
  }
  (constraint, default_type, parser)
}

///|
fn parse_type_parameters(parser : Parser) -> (Array[TypeParameter], Parser) {
  // Expect <
  let parser = match current_token(parser) {
    LessThan(_) => advance_parser(parser)
    _ => return ([], parser)
  }
  let type_params = []
  let mut parser = parser

  // Parse type parameter list
  while true {
    match current_token(parser) {
      GreaterThan(_) => {
        parser = advance_parser(parser)
        break
      }
      // Check for `const` type parameter modifier (TS 5.0+)
      KeywordConst(_) => {
        parser = advance_parser(parser)
        match current_token(parser) {
          Identifier(name, loc) => {
            parser = advance_parser(parser)
            let (constraint, default_type, p) = parse_type_param_constraint_and_default(
              parser,
            )
            parser = p
            type_params.push(TypeParameter::{
              name,
              constraint,
              default: default_type,
              is_const: true,
              location: loc,
            })
            match current_token(parser) {
              Comma(_) => {
                parser = advance_parser(parser)
                continue
              }
              GreaterThan(_) => continue
              _ => break
            }
          }
          _ => break
        }
      }
      Identifier(name, loc) => {
        // Parse type parameter name
        parser = advance_parser(parser)
        let (constraint, default_type, p) = parse_type_param_constraint_and_default(
          parser,
        )
        parser = p
        type_params.push(TypeParameter::{
          name,
          constraint,
          default: default_type,
          is_const: false,
          location: loc,
        })

        // Check for comma
        match current_token(parser) {
          Comma(_) => {
            parser = advance_parser(parser)
            continue
          }
          GreaterThan(_) => continue
          _ => break
        }
      }
      _ => break
    }
  }
  (type_params, parser)
}

///|
/// Check if current token is a greater-than (or starts with one) in type context
/// Returns true if token is >, >>, or >>>
fn is_greater_than_in_type_context(parser : Parser) -> Bool {
  match current_token(parser) {
    GreaterThan(_) => true
    GreaterThanGreaterThan(_) => true
    GreaterThanGreaterThanGreaterThan(_) => true
    _ => false
  }
}

///|
/// Consume a single > in type context, handling >> and >>> tokens
/// For >>: replaces token with single > and doesn't advance (leaves one > for outer context)
/// For >>>: replaces token with >> and doesn't advance
fn consume_greater_than_in_type_context(parser : Parser) -> Parser {
  match current_token(parser) {
    GreaterThan(_) => advance_parser(parser)
    GreaterThanGreaterThan(loc) => {
      // Replace >> with > at current position (consume one >)
      parser.tokens[parser.position] = GreaterThan(loc)
      parser
    }
    GreaterThanGreaterThanGreaterThan(loc) => {
      // Replace >>> with >> at current position (consume one >)
      parser.tokens[parser.position] = GreaterThanGreaterThan(loc)
      parser
    }
    _ => parser
  }
}

///|
/// Parse type argument list (for generic function/type usage)
fn parse_type_argument_list(
  parser : Parser,
) -> Result[(Array[Node], Parser), Parser] {
  // Save diagnostics length for backtracking
  let initial_diag_length = parser.diagnostics.length()

  // Expect <
  let parser = match current_token(parser) {
    LessThan(_) => advance_parser(parser)
    _ => return Err(parser)
  }
  let type_args = []
  let mut parser = parser

  // Parse type argument list
  while true {
    // Check for closing > (also handles >> and >>> for nested generics)
    if is_greater_than_in_type_context(parser) {
      parser = consume_greater_than_in_type_context(parser)
      break
    }
    match parse_type(parser) {
      Ok((ty, p)) => {
        type_args.push(ty)
        parser = p

        // Check for comma or closing >
        match current_token(parser) {
          Comma(_) => {
            parser = advance_parser(parser)
            continue
          }
          _ => {
            // Check for > or >> or >>> (closing bracket)
            if is_greater_than_in_type_context(parser) {
              continue
            }
            // Failed to parse - restore diagnostics and return error
            while parser.diagnostics.length() > initial_diag_length {
              let _ = parser.diagnostics.pop()

            }
            return Err(parser)
          }
        }
      }
      Err(p) => {
        // Failed to parse type - restore diagnostics and return error
        while p.diagnostics.length() > initial_diag_length {
          let _ = p.diagnostics.pop()

        }
        return Err(p)
      }
    }
  }
  Ok((type_args, parser))
}

// ============================================================================
// Helper Functions
// ============================================================================

///|
/// Get current token
fn current_token(parser : Parser) -> Token {
  if parser.position < parser.tokens.length() {
    match parser.tokens.get(parser.position) {
      Some(token) => token
      None =>
        EOF(
          SourceLocation::new(
            "",
            Position::new(0, 0, 0),
            Position::new(0, 0, 0),
          ),
        )
    }
  } else {
    EOF(SourceLocation::new("", Position::new(0, 0, 0), Position::new(0, 0, 0)))
  }
}

///|
/// Advance parser position
fn advance_parser(parser : Parser) -> Parser {
  if parser.position < parser.tokens.length() {
    { ..parser, position: parser.position + 1 }
  } else {
    parser
  }
}

///|
/// Peek at the next token without advancing the parser
fn peek_token(parser : Parser) -> Token {
  let next_pos = parser.position + 1
  if next_pos < parser.tokens.length() {
    match parser.tokens.get(next_pos) {
      Some(token) => token
      None =>
        EOF(
          SourceLocation::new(
            "",
            Position::new(0, 0, 0),
            Position::new(0, 0, 0),
          ),
        )
    }
  } else {
    EOF(SourceLocation::new("", Position::new(0, 0, 0), Position::new(0, 0, 0)))
  }
}

///|
/// Try to extract an identifier name from a token
/// Returns Some((name, location)) for identifiers and contextual keywords
/// that can be used as identifiers in binding patterns
fn try_get_identifier_name(token : Token) -> (String, SourceLocation)? {
  match token {
    Identifier(name, loc) => Some((name, loc))
    // Contextual keywords that can be used as identifiers in binding patterns
    KeywordAs(loc) => Some(("as", loc))
    KeywordFrom(loc) => Some(("from", loc))
    KeywordOf(loc) => Some(("of", loc))
    KeywordType(loc) => Some(("type", loc))
    KeywordDeclare(loc) => Some(("declare", loc))
    KeywordAsync(loc) => Some(("async", loc))
    KeywordAwait(loc) => Some(("await", loc))
    KeywordReadonly(loc) => Some(("readonly", loc))
    KeywordAbstract(loc) => Some(("abstract", loc))
    KeywordStatic(loc) => Some(("static", loc))
    KeywordPublic(loc) => Some(("public", loc))
    KeywordPrivate(loc) => Some(("private", loc))
    KeywordProtected(loc) => Some(("protected", loc))
    KeywordNamespace(loc) => Some(("namespace", loc))
    KeywordModule(loc) => Some(("module", loc))
    KeywordImplements(loc) => Some(("implements", loc))
    KeywordSatisfies(loc) => Some(("satisfies", loc))
    KeywordUsing(loc) => Some(("using", loc))
    KeywordAccessor(loc) => Some(("accessor", loc))
    KeywordAny(loc) => Some(("any", loc))
    KeywordBoolean(loc) => Some(("boolean", loc))
    KeywordNumber(loc) => Some(("number", loc))
    KeywordString(loc) => Some(("string", loc))
    KeywordSymbol(loc) => Some(("symbol", loc))
    KeywordBigInt(loc) => Some(("bigint", loc))
    KeywordObject(loc) => Some(("object", loc))
    KeywordNever(loc) => Some(("never", loc))
    KeywordUnknown(loc) => Some(("unknown", loc))
    KeywordUndefined(loc) => Some(("undefined", loc))
    // yield can be an identifier outside of generators and strict mode
    KeywordYield(loc) => Some(("yield", loc))
    // let can be used as an identifier in var declarations (e.g., var let = 5)
    // This is valid in non-strict mode and even in strict mode for var declarations
    KeywordLet(loc) => Some(("let", loc))
    _ => None
  }
}

///|
/// Try to get property name from token including reserved keywords
/// Used in object binding patterns where reserved keywords can be property names
/// but require a colon (no shorthand allowed)
/// Returns (name, location, is_reserved_keyword)

///|
/// Try to get reserved keyword as a name (for error messages)
/// Returns (name, location) if the token is a reserved keyword
fn try_get_reserved_keyword(token : Token) -> (String, SourceLocation)? {
  match token {
    KeywordWhile(loc) => Some(("while", loc))
    KeywordFor(loc) => Some(("for", loc))
    KeywordIf(loc) => Some(("if", loc))
    KeywordElse(loc) => Some(("else", loc))
    KeywordDo(loc) => Some(("do", loc))
    KeywordSwitch(loc) => Some(("switch", loc))
    KeywordCase(loc) => Some(("case", loc))
    KeywordDefault(loc) => Some(("default", loc))
    KeywordBreak(loc) => Some(("break", loc))
    KeywordContinue(loc) => Some(("continue", loc))
    KeywordReturn(loc) => Some(("return", loc))
    KeywordThrow(loc) => Some(("throw", loc))
    KeywordTry(loc) => Some(("try", loc))
    KeywordCatch(loc) => Some(("catch", loc))
    KeywordFinally(loc) => Some(("finally", loc))
    KeywordNew(loc) => Some(("new", loc))
    KeywordDelete(loc) => Some(("delete", loc))
    KeywordTypeOf(loc) => Some(("typeof", loc))
    KeywordVoid(loc) => Some(("void", loc))
    KeywordIn(loc) => Some(("in", loc))
    KeywordInstanceOf(loc) => Some(("instanceof", loc))
    KeywordThis(loc) => Some(("this", loc))
    KeywordSuper(loc) => Some(("super", loc))
    KeywordClass(loc) => Some(("class", loc))
    KeywordExtends(loc) => Some(("extends", loc))
    KeywordFunction(loc) => Some(("function", loc))
    KeywordVar(loc) => Some(("var", loc))
    KeywordLet(loc) => Some(("let", loc))
    KeywordConst(loc) => Some(("const", loc))
    KeywordImport(loc) => Some(("import", loc))
    KeywordExport(loc) => Some(("export", loc))
    KeywordDebugger(loc) => Some(("debugger", loc))
    KeywordYield(loc) => Some(("yield", loc))
    KeywordNull(loc) => Some(("null", loc))
    KeywordEnum(loc) => Some(("enum", loc))
    KeywordInterface(loc) => Some(("interface", loc))
    _ => None
  }
}

///|
fn try_get_property_name_with_reserved(
  token : Token,
) -> (String, SourceLocation, Bool)? {
  // First try normal identifiers and contextual keywords
  match try_get_identifier_name(token) {
    Some((name, loc)) => Some((name, loc, false))
    None =>
      // Handle reserved keywords as property names (require colon after)
      match try_get_reserved_keyword(token) {
        Some((name, loc)) => Some((name, loc, true))
        None => None
      }
  }
}

///|
/// Try to get binding target name (identifier, contextual keyword, or reserved keyword with error)
/// Returns (name, location, is_reserved) - if is_reserved is true, should report TS1359
fn try_get_binding_target_with_reserved(
  token : Token,
) -> (String, SourceLocation, Bool)? {
  // First try normal identifiers and contextual keywords
  match try_get_identifier_name(token) {
    Some((name, loc)) => Some((name, loc, false))
    None =>
      // Handle reserved keywords - these should report TS1359
      match try_get_reserved_keyword(token) {
        Some((name, loc)) => Some((name, loc, true))
        None => None
      }
  }
}

///|
/// Get computed property name from expression
/// Handles Symbol.iterator -> "__@iterator", Symbol.asyncIterator -> "__@asyncIterator", etc.
fn get_computed_property_name(name_expr : Node) -> String {
  match name_expr {
    Node::StringLiteral(lit) => lit.value
    Node::NumericLiteral(lit) => lit.value
    Node::PropertyAccessExpression(pae) =>
      // Handle Symbol.iterator, Symbol.asyncIterator, etc.
      match pae.expression {
        Node::Identifier(obj_id) if obj_id.name == "Symbol" =>
          if pae.name == "iterator" {
            "__@iterator"
          } else if pae.name == "asyncIterator" {
            "__@asyncIterator"
          } else {
            "[computed]"
          }
        _ => "[computed]"
      }
    _ => "[computed]"
  }
}

///|
/// Increment parser depth (for expression parsing)
fn increment_depth(parser : Parser) -> Parser {
  { ..parser, depth: parser.depth + 1 }
}

///|
/// Decrement parser depth (for expression parsing)
fn decrement_depth(parser : Parser) -> Parser {
  { ..parser, depth: parser.depth - 1 }
}

///|
/// Check if recursion depth exceeds limit
fn check_depth(parser : Parser) -> Result[Parser, Parser] {
  if parser.depth > max_expression_depth {
    let loc = current_token(parser).location()
    Err(
      add_error(
        parser, "Expression too deeply nested (stack overflow prevention)", loc,
      ),
    )
  } else {
    Ok(parser)
  }
}

///|
/// Check if at end of tokens
fn is_at_end(parser : Parser) -> Bool {
  match current_token(parser) {
    EOF(_) => true
    _ => false
  }
}

///|
/// Expect a specific token
fn expect(
  parser : Parser,
  predicate : (Token) -> Bool,
) -> Result[Parser, Parser] {
  if predicate(current_token(parser)) {
    Ok(parser)
  } else {
    Err(parser)
  }
}

///|
/// Expect semicolon (with ASI)
fn expect_semicolon(parser : Parser) -> Parser {
  match current_token(parser) {
    Semicolon(_) => advance_parser(parser)
    _ => parser // Automatic semicolon insertion
  }
}

///|
/// Add error to diagnostics
fn add_error(
  parser : Parser,
  message : String,
  location : SourceLocation,
) -> Parser {
  let diagnostic = Diagnostic::error(message, location, 1000)
  let diagnostics = parser.diagnostics
  diagnostics.push(diagnostic)
  { ..parser, diagnostics, }
}

///|
/// Skip to next statement (error recovery)
fn skip_to_next_statement(parser : Parser) -> Parser {
  let mut parser = parser
  while !is_at_end(parser) {
    match current_token(parser) {
      Semicolon(_) => return advance_parser(parser)
      CloseBrace(_) => return parser
      _ => parser = advance_parser(parser)
    }
  }
  parser
}

///|
/// Get binary operator from token
fn get_binary_operator(token : Token) -> BinaryOperator? {
  match token {
    Plus(_) => Some(BinaryOperator::Add)
    Minus(_) => Some(BinaryOperator::Subtract)
    Star(_) => Some(BinaryOperator::Multiply)
    Slash(_) => Some(BinaryOperator::Divide)
    Percent(_) => Some(BinaryOperator::Remainder)
    StarStar(_) => Some(BinaryOperator::Exponentiate)
    LessThan(_) => Some(BinaryOperator::LessThan)
    GreaterThan(_) => Some(BinaryOperator::GreaterThan)
    LessThanEquals(_) => Some(BinaryOperator::LessThanEquals)
    GreaterThanEquals(_) => Some(BinaryOperator::GreaterThanEquals)
    EqualsEquals(_) => Some(BinaryOperator::Equals)
    ExclamationEquals(_) => Some(BinaryOperator::NotEquals)
    EqualsEqualsEquals(_) => Some(BinaryOperator::StrictEquals)
    ExclamationEqualsEquals(_) => Some(BinaryOperator::StrictNotEquals)
    AmpersandAmpersand(_) => Some(BinaryOperator::LogicalAnd)
    BarBar(_) => Some(BinaryOperator::LogicalOr)
    QuestionQuestion(_) => Some(BinaryOperator::NullishCoalescing)
    Ampersand(_) => Some(BinaryOperator::BitwiseAnd)
    Bar(_) => Some(BinaryOperator::BitwiseOr)
    Caret(_) => Some(BinaryOperator::BitwiseXor)
    LessThanLessThan(_) => Some(BinaryOperator::LeftShift)
    GreaterThanGreaterThan(_) => Some(BinaryOperator::RightShift)
    GreaterThanGreaterThanGreaterThan(_) =>
      Some(BinaryOperator::UnsignedRightShift)
    KeywordIn(_) => Some(BinaryOperator::In)
    KeywordInstanceOf(_) => Some(BinaryOperator::InstanceOf)
    // Compound assignment operators
    PlusEquals(_) => Some(BinaryOperator::AddAssign)
    MinusEquals(_) => Some(BinaryOperator::SubtractAssign)
    StarEquals(_) => Some(BinaryOperator::MultiplyAssign)
    SlashEquals(_) => Some(BinaryOperator::DivideAssign)
    PercentEquals(_) => Some(BinaryOperator::RemainderAssign)
    AmpersandEquals(_) => Some(BinaryOperator::BitwiseAndAssign)
    BarEquals(_) => Some(BinaryOperator::BitwiseOrAssign)
    CaretEquals(_) => Some(BinaryOperator::BitwiseXorAssign)
    StarStarEquals(_) => Some(BinaryOperator::ExponentiateAssign)
    LessThanLessThanEquals(_) => Some(BinaryOperator::LeftShiftAssign)
    GreaterThanGreaterThanEquals(_) => Some(BinaryOperator::RightShiftAssign)
    GreaterThanGreaterThanGreaterThanEquals(_) =>
      Some(BinaryOperator::UnsignedRightShiftAssign)
    AmpersandAmpersandEquals(_) => Some(BinaryOperator::LogicalAndAssign)
    BarBarEquals(_) => Some(BinaryOperator::LogicalOrAssign)
    QuestionQuestionEquals(_) => Some(BinaryOperator::NullishCoalescingAssign)
    // Note: Comma operator is context-sensitive and handled separately in parenthesized expressions
    _ => None
  }
}

///|
/// Get unary operator from token
fn get_unary_operator(token : Token) -> UnaryOperator? {
  match token {
    Plus(_) => Some(UnaryOperator::Plus)
    Minus(_) => Some(UnaryOperator::Minus)
    Exclamation(_) => Some(UnaryOperator::LogicalNot)
    Tilde(_) => Some(UnaryOperator::BitwiseNot)
    PlusPlus(_) => Some(UnaryOperator::Increment)
    MinusMinus(_) => Some(UnaryOperator::Decrement)
    KeywordTypeOf(_) => Some(UnaryOperator::TypeOf)
    KeywordVoid(_) => Some(UnaryOperator::Void)
    KeywordDelete(_) => Some(UnaryOperator::Delete)
    _ => None
  }
}

///|
/// Get operator precedence
fn get_precedence(op : BinaryOperator) -> Int {
  match op {
    BinaryOperator::Comma => 1
    BinaryOperator::LogicalOr => 3
    BinaryOperator::LogicalAnd => 4
    BinaryOperator::BitwiseOr => 5
    BinaryOperator::BitwiseXor => 6
    BinaryOperator::BitwiseAnd => 7
    BinaryOperator::Equals
    | BinaryOperator::NotEquals
    | BinaryOperator::StrictEquals
    | BinaryOperator::StrictNotEquals => 8
    BinaryOperator::LessThan
    | BinaryOperator::GreaterThan
    | BinaryOperator::LessThanEquals
    | BinaryOperator::GreaterThanEquals
    | BinaryOperator::In
    | BinaryOperator::InstanceOf => 9
    BinaryOperator::LeftShift
    | BinaryOperator::RightShift
    | BinaryOperator::UnsignedRightShift => 10
    BinaryOperator::Add | BinaryOperator::Subtract => 11
    BinaryOperator::Multiply
    | BinaryOperator::Divide
    | BinaryOperator::Remainder => 12
    BinaryOperator::Exponentiate => 13
    BinaryOperator::NullishCoalescing => 2
    _ => 0
  }
}

// Token matching helpers

///|
fn matches_open_paren(token : Token) -> Bool {
  match token {
    OpenParen(_) => true
    _ => false
  }
}

///|
fn matches_close_paren(token : Token) -> Bool {
  match token {
    CloseParen(_) => true
    _ => false
  }
}

///|
fn matches_open_brace(token : Token) -> Bool {
  match token {
    OpenBrace(_) => true
    _ => false
  }
}

///|
fn matches_close_brace(token : Token) -> Bool {
  match token {
    CloseBrace(_) => true
    _ => false
  }
}

///|
fn matches_close_bracket(token : Token) -> Bool {
  match token {
    CloseBracket(_) => true
    _ => false
  }
}

///|
fn matches_colon(token : Token) -> Bool {
  match token {
    Colon(_) => true
    _ => false
  }
}

///|
fn matches_arrow(token : Token) -> Bool {
  match token {
    Arrow(_) => true
    _ => false
  }
}
