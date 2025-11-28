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
pub enum ParserErrorCode {
  // General
  UnexpectedToken
  UnexpectedEOF

  // Declarations
  ExpectedIdentifier
  ExpectedTypeAnnotation
  ExpectedExpression
  ExpectedStatement

  // Punctuation
  ExpectedSemicolon
  ExpectedComma
  ExpectedColon
  ExpectedOpenParen
  ExpectedCloseParen
  ExpectedOpenBrace
  ExpectedCloseBrace
  ExpectedOpenBracket
  ExpectedCloseBracket

  // Keywords
  ExpectedFunctionKeyword
  ExpectedClassKeyword

  // JSX
  JSXClosingTagMismatch
  JSXExpectedClosingTag
  JSXExpectedAttributeValue

  // JSON
  JSONExpectedPropertyName
  JSONExpectedValue
  JSONTrailingComma

  // JSDoc
  JSDocInvalidTag
  JSDocInvalidType
} derive(Show, Eq)

///|
/// Get numeric code for error
pub fn ParserErrorCode::to_int(self : ParserErrorCode) -> Int {
  match self {
    UnexpectedToken => 1001
    UnexpectedEOF => 1002
    ExpectedIdentifier => 1003
    ExpectedTypeAnnotation => 1004
    ExpectedExpression => 1005
    ExpectedStatement => 1006
    ExpectedSemicolon => 1007
    ExpectedComma => 1008
    ExpectedColon => 1009
    ExpectedOpenParen => 1010
    ExpectedCloseParen => 1011
    ExpectedOpenBrace => 1012
    ExpectedCloseBrace => 1013
    ExpectedOpenBracket => 1014
    ExpectedCloseBracket => 1015
    ExpectedFunctionKeyword => 1016
    ExpectedClassKeyword => 1017
    JSXClosingTagMismatch => 1100
    JSXExpectedClosingTag => 1101
    JSXExpectedAttributeValue => 1102
    JSONExpectedPropertyName => 1200
    JSONExpectedValue => 1201
    JSONTrailingComma => 1202
    JSDocInvalidTag => 1300
    JSDocInvalidType => 1301
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
/// Parse a complete source file
pub fn parse_source_file(
  tokens : Array[Token],
  file_path : String,
) -> ParseResult[SourceFile] {
  // Extract triple-slash directive tokens and filter out comment tokens
  let directive_tokens : Array[(String, SourceLocation)] = []
  let filtered_tokens : Array[Token] = []
  for i = 0; i < tokens.length(); i = i + 1 {
    match tokens[i] {
      CommentDirective(TripleSlashRef, content, loc) => {
        directive_tokens.push((content, loc))
        // Don't add to filtered_tokens - skip directive tokens during parsing
      }
      CommentDirective(_, _, _) => ()  // Skip other comment directives
      JSDocComment(_, _) => ()  // Skip JSDoc comments - handled separately
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
  if parser.diagnostics.length() > 0 {
    Err(parser.diagnostics)
  } else {
    Ok(SourceFile::{
      file_path,
      statements,
      end_of_file_token: eof_token,
      has_no_default_lib: false,
      directive_tokens,
    })
  }
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
              Err(add_error(parser, "Expected 'class' after 'abstract'", loc))
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
                add_error(
                  parser, "Expected 'function' after decorators and 'async'", loc,
                ),
              )
            }
          }
        }
        _ => {
          let loc = current_token(parser).location()
          Err(
            add_error(
              parser, "Expected class or function declaration after decorators",
              loc,
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
          Err(add_error(parser, "Expected 'class' after 'abstract'", loc))
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

    // Namespace/module declaration
    KeywordNamespace(_) | KeywordModule(_) => parse_module_declaration(parser)

    // Import declaration or dynamic import expression
    KeywordImport(_) => {
      // Check if this is a dynamic import (import followed by open paren)
      if parser.position + 1 < parser.tokens.length() {
        match parser.tokens[parser.position + 1] {
          OpenParen(_) => parse_expression_statement(parser) // Dynamic import
          _ => parse_import_declaration(parser)
        }
      } else {
        parse_import_declaration(parser)
      }
    }

    // Export declaration
    KeywordExport(_) => parse_export_declaration(parser)

    // Declare (ambient) declaration
    KeywordDeclare(_) => parse_declare_declaration(parser)

    // Using statement (TS 5.2+): using x = expr;
    KeywordUsing(start_loc) => parse_using_statement(parser, start_loc, false)

    // Await using statement (TS 5.2+): await using x = expr;
    KeywordAwait(_) => {
      let parser = advance_parser(parser)
      match current_token(parser) {
        KeywordUsing(loc) => parse_using_statement(parser, loc, true)
        _ => parse_expression_statement(parser)
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
/// Parse variable statement (let/const/var)
fn parse_variable_statement(parser : Parser) -> Result[(Node, Parser), Parser] {
  match parse_variable_declaration_list(parser, true) {
    Ok((declarations, is_const, is_let, location, parser)) => {
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
        Err(p) =>
          return Err(
            add_error(
              p, "Expected identifier in variable declaration", start_loc,
            ),
          )
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
      Identifier(name, loc) => {
        elements.push(
          Some(Node::Identifier(Identifier::{ name, location: loc })),
        )
        parser = advance_parser(parser)

        // Optional comma
        match current_token(parser) {
          Comma(_) => parser = advance_parser(parser)
          _ => ()
        }
      }
      OpenBracket(_) =>
        // Nested array pattern
        match parse_array_binding_pattern(parser) {
          Ok((pattern, p)) => {
            elements.push(Some(pattern))
            parser = p
            match current_token(parser) {
              Comma(_) => parser = advance_parser(parser)
              _ => ()
            }
          }
          Err(p) => return Err(p)
        }
      OpenBrace(_) =>
        // Nested object pattern
        match parse_object_binding_pattern(parser) {
          Ok((pattern, p)) => {
            elements.push(Some(pattern))
            parser = p
            match current_token(parser) {
              Comma(_) => parser = advance_parser(parser)
              _ => ()
            }
          }
          Err(p) => return Err(p)
        }
      _ => break
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
      Identifier(prop_name, prop_loc) => {
        parser = advance_parser(parser)

        // Check for colon (renaming: { x: a })
        let (name, p2) = match current_token(parser) {
          Colon(_) => {
            let p2 = advance_parser(parser)

            // Parse the binding name (can be identifier or nested pattern)
            match current_token(p2) {
              Identifier(bind_name, bind_loc) =>
                (
                  Node::Identifier(Identifier::{
                    name: bind_name,
                    location: bind_loc,
                  }),
                  advance_parser(p2),
                )
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
                  add_error(p2, "Expected identifier after colon", prop_loc),
                )
            }
          }
          _ =>
            // Shorthand: { x } means { x: x }
            (
              Node::Identifier(Identifier::{
                name: prop_name,
                location: prop_loc,
              }),
              parser,
            )
        }
        parser = p2
        properties.push(BindingElement::{
          property_name: prop_name,
          name,
          location: prop_loc,
        })

        // Optional comma
        match current_token(parser) {
          Comma(_) => parser = advance_parser(parser)
          _ => ()
        }
      }
      _ => break
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
            add_error(
              parser,
              "Expected parameter name after 'asserts'",
              current_token(parser).location(),
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
  let (name, parser) = match current_token(parser) {
    Identifier(id_name, loc) =>
      (
        Some(Node::Identifier(Identifier::{ name: id_name, location: loc })),
        advance_parser(parser),
      )
    _ => (None, parser) // Anonymous function - no error, name is optional
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
      return Err(add_error(p, "Expected '(' after function name", start_loc))
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

  // Body
  let (body, parser) = match current_token(parser) {
    OpenBrace(_) =>
      match parse_block_statement(parser) {
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
    _ => parse_parameter_list_aux(parser, [])
  }
}

///|
/// Tail-recursive helper for parse_parameter_list with accumulator
fn parse_parameter_list_aux(
  parser : Parser,
  acc : Array[Node],
) -> (Array[Node], Parser) {
  match parse_parameter(parser) {
    Ok((param, next_parser)) => {
      acc.push(param)
      match current_token(next_parser) {
        Comma(_) => parse_parameter_list_aux(advance_parser(next_parser), acc)
        CloseParen(_) => (acc, advance_parser(next_parser))
        _ => (acc, next_parser)
      }
    }
    Err(_) => (acc, parser)
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
      match parse_identifier(parser) {
        Ok((id, p)) => (false, Node::Identifier(id), p)
        Err(p) => return Err(p)
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
        Err(parser) => Err(add_error(parser, "Expected '}'", start_loc))
      }
    }
    Err(parser) => Err(add_error(parser, "Expected '{'", start_loc))
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
    Err(p) => return Err(add_error(p, "Expected '(' after 'if'", start_loc))
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
      return Err(add_error(p, "Expected ')' after condition", start_loc))
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
/// Parse identifier
fn parse_identifier(parser : Parser) -> Result[(Identifier, Parser), Parser] {
  match current_token(parser) {
    Identifier(name, loc) =>
      Ok((Identifier::{ name, location: loc }, advance_parser(parser)))
    _ => {
      let loc = current_token(parser).location()
      Err(add_error(parser, "Expected identifier", loc))
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
            add_error(
              parser,
              "Expected '}' after class body",
              current_token(parser).location(),
            ),
          )
      }
    }
    _ =>
      Err(
        add_error(
          parser,
          "Expected '{' after class name",
          current_token(parser).location(),
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
    Identifier(name, loc) => {
      // Create TypeReference instead of Identifier for heritage types
      acc.push(
        Node::TypeReference(TypeReference::{
          type_name: name,
          type_arguments: [],
          location: loc,
        }),
      )
      let parser = advance_parser(parser)
      match current_token(parser) {
        Comma(_) => parse_heritage_types_aux(advance_parser(parser), acc)
        _ => (acc, parser)
      }
    }
    _ => (acc, parser)
  }
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
        OpenBrace(_) => {
          match parse_block_statement(parser) {
            Ok((body, parser)) => {
              acc.push(
                Node::StaticBlock(StaticBlock::{
                  body,
                  location: start_loc,
                }),
              )
              parse_class_members_aux(parser, acc)
            }
            Err(p) => parse_class_members_aux(p, acc)
          }
        }
        // Static member with identifier
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
                  match parse_block_statement(parser) {
                    Ok((b, p)) => (Some(b), p)
                    Err(p) => (None, p)
                  }
                _ => (None, parser)
              }
              acc.push(
                Node::MethodDeclaration(MethodDeclaration::{
                  name,
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
        _ => parse_class_members_aux(parser, acc)
      }
    }

    // Constructor
    Identifier("constructor", loc) => {
      let parser = advance_parser(parser)
      match current_token(parser) {
        OpenParen(_) => {
          // Consume the OpenParen, then parse parameters
          let parser = advance_parser(parser)
          let (parameters, parser) = parse_parameter_list(parser)
          // Parse body
          let (body, parser) = match current_token(parser) {
            OpenBrace(_) =>
              match parse_block_statement(parser) {
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

    // Getter: get name() { ... }
    Identifier("get", start_loc) => {
      let parser = advance_parser(parser)
      match current_token(parser) {
        Identifier(name, _) => {
          let parser = advance_parser(parser)
          match current_token(parser) {
            OpenParen(_) => {
              let parser = advance_parser(parser)
              // Getter has no parameters, just close paren
              let parser = match current_token(parser) {
                CloseParen(_) => advance_parser(parser)
                _ => parser
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
                  match parse_block_statement(parser) {
                    Ok((b, p)) => (Some(b), p)
                    Err(p) => (None, p)
                  }
                _ => (None, parser)
              }
              acc.push(
                Node::GetAccessor(GetAccessor::{
                  name,
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
                      match parse_block_statement(parser) {
                        Ok((b, p)) => (Some(b), p)
                        Err(p) => (None, p)
                      }
                    _ => (None, parser)
                  }
                  acc.push(
                    Node::MethodDeclaration(MethodDeclaration::{
                      name,
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

    // Setter: set name(value) { ... }
    Identifier("set", start_loc) => {
      let parser = advance_parser(parser)
      match current_token(parser) {
        Identifier(name, _) => {
          let parser = advance_parser(parser)
          match current_token(parser) {
            OpenParen(_) => {
              let parser = advance_parser(parser)
              // Parse single parameter
              let (parameter, parser) = match parse_parameter(parser) {
                Ok((param, p)) => (param, p)
                Err(p) =>
                  (
                    Node::Identifier(Identifier::{
                      name: "value",
                      location: start_loc,
                    }),
                    p,
                  )
              }
              // Consume closing paren
              let parser = match current_token(parser) {
                CloseParen(_) => advance_parser(parser)
                _ => parser
              }
              // Optional return type (usually void)
              let (_, parser) = match current_token(parser) {
                Colon(_) => {
                  let parser = advance_parser(parser)
                  match parse_type(parser) {
                    Ok((_, p)) => ((), p)
                    Err(p) => ((), p)
                  }
                }
                _ => ((), parser)
              }
              // Body
              let (body, parser) = match current_token(parser) {
                OpenBrace(_) =>
                  match parse_block_statement(parser) {
                    Ok((b, p)) => (Some(b), p)
                    Err(p) => (None, p)
                  }
                _ => (None, parser)
              }
              acc.push(
                Node::SetAccessor(SetAccessor::{
                  name,
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
      parse_class_member_with_modifiers(parser, acc, decorators, [Modifier::Private])
    }

    // Protected modifier
    KeywordProtected(_) => {
      let parser = advance_parser(parser)
      parse_class_member_with_modifiers(parser, acc, decorators, [Modifier::Protected])
    }

    // Public modifier
    KeywordPublic(_) => {
      let parser = advance_parser(parser)
      parse_class_member_with_modifiers(parser, acc, decorators, [Modifier::Public])
    }

    // Static modifier
    KeywordStatic(_) => {
      let parser = advance_parser(parser)
      parse_class_member_with_modifiers(parser, acc, decorators, [Modifier::Static])
    }

    // Readonly modifier
    KeywordReadonly(_) => {
      let parser = advance_parser(parser)
      parse_class_member_with_modifiers(parser, acc, decorators, [Modifier::Readonly])
    }

    // Abstract modifier
    KeywordAbstract(_) => {
      let parser = advance_parser(parser)
      parse_class_member_with_modifiers(parser, acc, decorators, [Modifier::Abstract])
    }

    // Async modifier
    KeywordAsync(_) => {
      let parser = advance_parser(parser)
      parse_class_member_with_modifiers(parser, acc, decorators, [Modifier::Async])
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
              match parse_block_statement(parser) {
                Ok((b, p)) => (Some(b), p)
                Err(p) => (None, p)
              }
            _ => (None, parser)
          }
          acc.push(
            Node::MethodDeclaration(MethodDeclaration::{
              name,
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
              match parse_block_statement(parser) {
                Ok((b, p)) => (Some(b), p)
                Err(p) => (None, p)
              }
            _ => (None, parser)
          }
          acc.push(
            Node::MethodDeclaration(MethodDeclaration::{
              name,
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
    Identifier(name, loc) => {
      let parser = advance_parser(parser)
      match current_token(parser) {
        // Method
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
              match parse_block_statement(parser) {
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
        add_error(
          parser,
          "Expected interface name",
          current_token(parser).location(),
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
          // Index signature: [key: string]: value
          OpenBracket(_) => {
            let bracket_loc = current_token(parser).location()
            parser = advance_parser(parser)
            // Parse index parameter name
            let index_name = match current_token(parser) {
              Identifier(n, _) => {
                parser = advance_parser(parser)
                n
              }
              _ =>
                return Err(
                  add_error(
                    parser,
                    "Expected index parameter name",
                    current_token(parser).location(),
                  ),
                )
            }
            // Expect colon
            match current_token(parser) {
              Colon(_) => parser = advance_parser(parser)
              _ =>
                return Err(
                  add_error(
                    parser,
                    "Expected ':' after index parameter",
                    current_token(parser).location(),
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
                  add_error(
                    parser,
                    "Expected ']' after index signature",
                    current_token(parser).location(),
                  ),
                )
            }
            // Expect colon for value type
            match current_token(parser) {
              Colon(_) => parser = advance_parser(parser)
              _ =>
                return Err(
                  add_error(
                    parser,
                    "Expected ':' after index signature",
                    current_token(parser).location(),
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
                      add_error(
                        parser,
                        "Expected index parameter name",
                        current_token(parser).location(),
                      ),
                    )
                }
                // Expect colon
                match current_token(parser) {
                  Colon(_) => parser = advance_parser(parser)
                  _ =>
                    return Err(
                      add_error(
                        parser,
                        "Expected ':' after index parameter",
                        current_token(parser).location(),
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
                      add_error(
                        parser,
                        "Expected ']' after index signature",
                        current_token(parser).location(),
                      ),
                    )
                }
                // Expect colon for value type
                match current_token(parser) {
                  Colon(_) => parser = advance_parser(parser)
                  _ =>
                    return Err(
                      add_error(
                        parser,
                        "Expected ':' after index signature",
                        current_token(parser).location(),
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
                      add_error(
                        parser,
                        "Expected ':' after readonly property name",
                        current_token(parser).location(),
                      ),
                    )
                }
              }
              _ =>
                return Err(
                  add_error(
                    parser,
                    "Expected property name or '[' after readonly",
                    current_token(parser).location(),
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
          // Construct signature: new(): returnType
          KeywordNew(_) => {
            let new_loc = current_token(parser).location()
            parser = advance_parser(parser) // consume 'new'
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
                    type_parameters: [],
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
                  add_error(
                    parser,
                    "Expected '(' after 'new'",
                    current_token(parser).location(),
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
              _ =>
                return Err(
                  add_error(
                    parser, "Expected ':' or '(' after property name", prop_loc,
                  ),
                )
            }
          }
          _ => break
        }
      }
      Err(
        add_error(
          parser,
          "Expected '}' after interface body",
          current_token(parser).location(),
        ),
      )
    }
    _ =>
      Err(
        add_error(
          parser,
          "Expected '{' after interface name",
          current_token(parser).location(),
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
        add_error(
          parser,
          "Expected type name",
          current_token(parser).location(),
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
        add_error(
          parser,
          "Expected '=' in type alias",
          current_token(parser).location(),
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
  let (name, parser) = match current_token(parser) {
    Identifier(n, _) => (n, advance_parser(parser))
    _ =>
      return Err(
        add_error(
          parser,
          "Expected enum name",
          current_token(parser).location(),
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
            add_error(
              parser,
              "Expected '}' after enum body",
              current_token(parser).location(),
            ),
          )
      }
    }
    _ =>
      Err(
        add_error(
          parser,
          "Expected '{' after enum name",
          current_token(parser).location(),
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
fn parse_enum_members_aux(
  parser : Parser,
  acc : Array[EnumMember],
) -> (Array[EnumMember], Parser) {
  match current_token(parser) {
    CloseBrace(_) | EOF(_) => (acc, parser)
    Identifier(name, loc) => {
      let parser = advance_parser(parser)
      // Check for initializer (use parse_assignment_expression to not consume commas)
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
      acc.push(EnumMember::{ name, initializer, location: loc })
      // Check for comma
      match current_token(parser) {
        Comma(_) => parse_enum_members_aux(advance_parser(parser), acc)
        _ => (acc, parser)
      }
    }
    _ => (acc, parser)
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
        add_error(
          parser,
          "Expected namespace/module name",
          current_token(parser).location(),
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
        Identifier(_, _) | OpenBrace(_) | Star(_) => (true, advance_parser(parser))
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
  let (default_import, parser) = match current_token(parser) {
    Identifier(name, _) => {
      let parser = advance_parser(parser)
      // Check if there's a comma for mixed import
      match current_token(parser) {
        Comma(_) => {
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
          match current_token(parser) {
            Identifier(name, loc) => {
              let parser = advance_parser(parser)
              (Some(NamedImports::NamespaceImport(name, loc)), parser)
            }
            _ =>
              return Err(
                add_error(
                  parser,
                  "Expected identifier after 'as'",
                  current_token(parser).location(),
                ),
              )
          }
        }
        _ =>
          return Err(
            add_error(
              parser,
              "Expected 'as' after '*'",
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
            add_error(
              parser,
              "Expected '}' after import specifiers",
              current_token(parser).location(),
            ),
          )
      }
    }
    _ => (None, parser)
  }

  // Expect 'from' keyword
  let parser = match current_token(parser) {
    KeywordFrom(_) => advance_parser(parser)
    _ =>
      return Err(
        add_error(
          parser,
          "Expected 'from' after import clause",
          current_token(parser).location(),
        ),
      )
  }

  // Parse module specifier (string literal)
  let (module_specifier, parser) = match current_token(parser) {
    StringLiteral(spec, _) => (spec, advance_parser(parser))
    _ =>
      return Err(
        add_error(
          parser,
          "Expected module specifier string",
          current_token(parser).location(),
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
      match current_token(parser) {
        Identifier(name, loc) => {
          let parser = advance_parser(parser)
          // Check for 'as' renaming
          match current_token(parser) {
            KeywordAs(_) => {
              let parser = advance_parser(parser)
              match current_token(parser) {
                Identifier(local_name, _) => {
                  let parser = advance_parser(parser)
                  acc.push(ImportSpecifier::{
                    property_name: Some(name),
                    name: local_name,
                    is_type_only: true, // inline type import
                    location: loc,
                  })
                  // Check for comma
                  match current_token(parser) {
                    Comma(_) =>
                      parse_import_specifiers_aux(advance_parser(parser), acc)
                    _ => (acc, parser)
                  }
                }
                _ => (acc, parser) // Error, but continue
              }
            }
            _ => {
              // No renaming
              acc.push(ImportSpecifier::{
                property_name: None,
                name,
                is_type_only: true, // inline type import
                location: loc,
              })
              // Check for comma
              match current_token(parser) {
                Comma(_) =>
                  parse_import_specifiers_aux(advance_parser(parser), acc)
                _ => (acc, parser)
              }
            }
          }
        }
        _ => (acc, parser) // Error, but continue
      }
    }
    Identifier(name, loc) => {
      let parser = advance_parser(parser)
      // Check for 'as' renaming
      match current_token(parser) {
        KeywordAs(_) => {
          let parser = advance_parser(parser)
          match current_token(parser) {
            Identifier(local_name, _) => {
              let parser = advance_parser(parser)
              acc.push(ImportSpecifier::{
                property_name: Some(name),
                name: local_name,
                is_type_only: false,
                location: loc,
              })
              // Check for comma
              match current_token(parser) {
                Comma(_) =>
                  parse_import_specifiers_aux(advance_parser(parser), acc)
                _ => (acc, parser)
              }
            }
            _ => (acc, parser) // Error, but continue
          }
        }
        _ => {
          // No renaming
          acc.push(ImportSpecifier::{
            property_name: None,
            name,
            is_type_only: false,
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
    _ => (acc, parser)
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
                          "Expected module specifier after 'from'",
                          current_token(parser).location(),
                        ),
                      )
                  }
                }
                _ =>
                  Err(
                    add_error(
                      parser,
                      "Expected 'from' after namespace export",
                      current_token(parser).location(),
                    ),
                  )
              }
            }
            _ =>
              Err(
                add_error(
                  parser,
                  "Expected namespace name after 'as'",
                  current_token(parser).location(),
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
                  "Expected module specifier after 'from'",
                  current_token(parser).location(),
                ),
              )
          }
        }
        _ =>
          Err(
            add_error(
              parser,
              "Expected 'from' or 'as' after 'export *'",
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
                          "Expected module specifier after 'from'",
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
                add_error(
                  parser,
                  "Expected '}' after export specifiers",
                  current_token(parser).location(),
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
                      "Expected module specifier after 'from'",
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
            add_error(
              parser,
              "Expected '}' after export specifiers",
              current_token(parser).location(),
            ),
          )
      }
    }

    // export declaration (const, let, var, function, class, etc.)
    _ =>
      // Parse the declaration and add Export modifier
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
          let location = SourceLocation::new(start_loc.file_path, start_loc.start, end_loc.end)
          // Create ModuleDeclaration with is_global_augmentation=true
          Ok((Node::ModuleDeclaration(ModuleDeclaration::{
            name: "global",
            body: Some(body),
            is_ambient: false,
            is_global_augmentation: true,
            location,
          }), parser))
        }
        Err(p) => Err(p)
      }
    }
    _ => {
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
      match current_token(parser) {
        Identifier(name, loc) => {
          let parser = advance_parser(parser)
          // Check for 'as' renaming
          match current_token(parser) {
            KeywordAs(_) => {
              let parser = advance_parser(parser)
              match current_token(parser) {
                Identifier(export_name, _) => {
                  let parser = advance_parser(parser)
                  acc.push(ExportSpecifier::{
                    property_name: Some(name),
                    name: export_name,
                    is_type_only: true, // inline type export
                    location: loc,
                  })
                  // Check for comma
                  match current_token(parser) {
                    Comma(_) =>
                      parse_export_specifiers_aux(advance_parser(parser), acc)
                    _ => (acc, parser)
                  }
                }
                _ => (acc, parser) // Error, but continue
              }
            }
            _ => {
              // No renaming
              acc.push(ExportSpecifier::{
                property_name: None,
                name,
                is_type_only: true, // inline type export
                location: loc,
              })
              // Check for comma
              match current_token(parser) {
                Comma(_) =>
                  parse_export_specifiers_aux(advance_parser(parser), acc)
                _ => (acc, parser)
              }
            }
          }
        }
        _ => (acc, parser) // Error, but continue
      }
    }
    Identifier(name, loc) => {
      let parser = advance_parser(parser)
      // Check for 'as' renaming
      match current_token(parser) {
        KeywordAs(_) => {
          let parser = advance_parser(parser)
          match current_token(parser) {
            Identifier(export_name, _) => {
              let parser = advance_parser(parser)
              acc.push(ExportSpecifier::{
                property_name: Some(name),
                name: export_name,
                is_type_only: false,
                location: loc,
              })
              // Check for comma
              match current_token(parser) {
                Comma(_) =>
                  parse_export_specifiers_aux(advance_parser(parser), acc)
                _ => (acc, parser)
              }
            }
            _ => (acc, parser) // Error, but continue
          }
        }
        _ => {
          // No renaming
          acc.push(ExportSpecifier::{
            property_name: None,
            name,
            is_type_only: false,
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
    _ => (acc, parser)
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
        add_error(
          parser,
          "Expected '(' after 'switch'",
          current_token(parser).location(),
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
        add_error(
          parser,
          "Expected ')' after switch expression",
          current_token(parser).location(),
        ),
      )
  }

  // Expect '{'
  let parser = match current_token(parser) {
    OpenBrace(_) => advance_parser(parser)
    _ =>
      return Err(
        add_error(
          parser,
          "Expected '{' after switch header",
          current_token(parser).location(),
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
        add_error(
          parser,
          "Expected '}' after switch body",
          current_token(parser).location(),
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
        add_error(
          parser,
          "Expected '(' after 'for'",
          current_token(parser).location(),
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
            add_error(
              p,
              "Expected expression in for-in",
              current_token(p).location(),
            ),
          )
      }
      let parser = match current_token(parser) {
        CloseParen(_) => advance_parser(parser)
        _ =>
          return Err(
            add_error(
              parser,
              "Expected ')' in for-in",
              current_token(parser).location(),
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
      let (expression, parser) = match parse_expression(parser) {
        Ok((expr, p)) => (expr, p)
        Err(p) =>
          return Err(
            add_error(
              p,
              "Expected expression in for-of",
              current_token(p).location(),
            ),
          )
      }
      let parser = match current_token(parser) {
        CloseParen(_) => advance_parser(parser)
        _ =>
          return Err(
            add_error(
              parser,
              "Expected ')' in for-of",
              current_token(parser).location(),
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
        add_error(
          parser,
          "Expected ';' after for loop initializer",
          current_token(parser).location(),
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
        add_error(
          parser,
          "Expected ';' after for loop condition",
          current_token(parser).location(),
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
        add_error(
          parser,
          "Expected ')' after for loop header",
          current_token(parser).location(),
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
        add_error(
          parser,
          "Expected '(' after 'while'",
          current_token(parser).location(),
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
        add_error(
          parser,
          "Expected ')' after while condition",
          current_token(parser).location(),
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
    _ =>
      return Err(
        add_error(
          parser,
          "Expected 'while' after do statement",
          current_token(parser).location(),
        ),
      )
  }

  // Expect '('
  let parser = match current_token(parser) {
    OpenParen(_) => advance_parser(parser)
    _ =>
      return Err(
        add_error(
          parser,
          "Expected '(' after 'while'",
          current_token(parser).location(),
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
        add_error(
          parser,
          "Expected ')' after while condition",
          current_token(parser).location(),
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
        add_error(
          p,
          "Expected expression after 'throw'",
          current_token(p).location(),
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
        add_error(p, "Expected block after 'try'", current_token(p).location()),
      )
  }

  // Parse optional catch clause
  let (catch_clause, parser) = match current_token(parser) {
    KeywordCatch(_) => {
      let catch_start = current_token(parser).location()
      let parser = advance_parser(parser) // consume 'catch'

      // Optional parameter (can be identifier, array pattern, or object pattern)
      let (parameter, parser) = match current_token(parser) {
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
          let (param, parser) = match (param, current_token(parser)) {
            (Some(p), Colon(_)) => {
              let parser = advance_parser(parser)
              // Parse the type but we don't store it in catch clause yet
              // The type annotation is parsed but the catch variable binding
              // will still work with the identifier/pattern
              match parse_type(parser) {
                Ok((_, parser)) => (Some(p), parser)
                Err(parser) => (Some(p), parser)
              }
            }
            (p, _) => (p, parser)
          }
          let parser = match current_token(parser) {
            CloseParen(_) => advance_parser(parser)
            _ =>
              return Err(
                add_error(
                  parser,
                  "Expected ')' after catch parameter",
                  current_token(parser).location(),
                ),
              )
          }
          (param, parser)
        }
        _ => (None, parser)
      }

      // Parse catch block
      let (catch_block, parser) = match parse_block_statement(parser) {
        Ok((block, p)) => (block, p)
        Err(p) =>
          return Err(
            add_error(
              p,
              "Expected block in catch clause",
              current_token(p).location(),
            ),
          )
      }
      let catch_end = get_location(catch_block)
      let clause = CatchClause::{
        variable_declaration: parameter,
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
            add_error(
              p,
              "Expected block after 'finally'",
              current_token(p).location(),
            ),
          )
      }
    }
    _ => (None, parser)
  }

  // Must have either catch or finally
  if catch_clause is None && finally_block is None {
    return Err(
      add_error(
        parser,
        "Missing catch or finally clause",
        current_token(parser).location(),
      ),
    )
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
            type_params.push(
              TypeParameter::{
                name,
                constraint,
                default: default_type,
                is_const: true,
                location: loc,
              },
            )
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
        type_params.push(
          TypeParameter::{
            name,
            constraint,
            default: default_type,
            is_const: false,
            location: loc,
          },
        )

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
