// Parser for TypeScript
// Converts token stream into Abstract Syntax Tree (AST)
// Uses recursive descent parsing strategy

///|
/// Maximum recursion depth for expression parsing
/// Prevents stack overflow on deeply nested expressions
let max_expression_depth : Int = 1000

///|
/// Parser state
pub struct Parser {
  tokens : Array[Token]
  position : Int
  diagnostics : Array[Diagnostic]
  depth : Int  // Current recursion depth for expression parsing
} derive(Show)

///|
/// Parser result type
pub type ParseResult[T] = Result[T, Array[Diagnostic]]

///|
/// Create a new parser
pub fn Parser::new(tokens : Array[Token]) -> Parser {
  { tokens, position: 0, diagnostics: [], depth: 0 }
}

///|
/// Parse a complete source file
pub fn parse_source_file(
  tokens : Array[Token],
  file_path : String,
) -> ParseResult[SourceFile] {
  let parser = Parser::new(tokens)
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
fn parse_statements_aux(parser : Parser, acc : Array[Node]) -> (Array[Node], Parser) {
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
    KeywordLet(_) | KeywordConst(_) | KeywordVar(_) =>
      parse_variable_statement(parser)

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

    // Class declaration
    KeywordClass(_) => parse_class_declaration(parser)

    // Interface declaration
    KeywordInterface(_) => parse_interface_declaration(parser)

    // Type alias
    KeywordType(_) => parse_type_alias_declaration(parser)

    // Enum declaration
    KeywordEnum(_) => parse_enum_declaration(parser)

    // Import declaration
    KeywordImport(_) => parse_import_declaration(parser)

    // Export declaration
    KeywordExport(_) => parse_export_declaration(parser)

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
) -> Result[(Array[VariableDeclaration], Bool, Bool, SourceLocation, Parser), Parser] {
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
/// Parse a single variable declaration
fn parse_variable_declaration(
  parser : Parser,
) -> Result[(VariableDeclaration, Parser), Parser] {
  let start_loc = current_token(parser).location()

  // Parse name (identifier or binding pattern)
  let (name, parser) = match parse_identifier(parser) {
    Ok((id, p)) => (Node::Identifier(id), p)
    Err(p) =>
      return Err(
        add_error(p, "Expected identifier in variable declaration", start_loc),
      )
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

  // Function name (optional for function expressions)
  let (name, parser) = match parse_identifier(parser) {
    Ok((id, p)) => (Some(Node::Identifier(id)), p)
    Err(p) => (None, p)
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
      match parse_block_statement(parser) {
        Ok((block, p)) => (Some(block), p)
        Err(p) => (None, p)
      }
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
fn parse_parameter_list_aux(parser : Parser, acc : Array[Node]) -> (Array[Node], Parser) {
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

  // Check for rest parameter
  let (is_rest, parser) = match current_token(parser) {
    DotDotDot(_) => (true, advance_parser(parser))
    _ => (false, parser)
  }

  // Parameter name
  let (name, parser) = match parse_identifier(parser) {
    Ok((id, p)) => (Node::Identifier(id), p)
    Err(p) => return Err(p)
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

  // Default value
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
/// Parse expression
fn parse_expression(parser : Parser) -> Result[(Node, Parser), Parser] {
  parse_assignment_expression(parser)
}

///|
/// Parse assignment expression
fn parse_assignment_expression(
  parser : Parser,
) -> Result[(Node, Parser), Parser] {
  parse_conditional_expression(parser)
}

///|
/// Parse conditional (ternary) expression
fn parse_conditional_expression(
  parser : Parser,
) -> Result[(Node, Parser), Parser] {
  let (left, parser) = match parse_binary_expression(parser, 0) {
    Ok((expr, p)) => (expr, p)
    Err(p) => return Err(p)
  }

  // Check for ternary operator
  match current_token(parser) {
    Question(_) => {
      let start_loc = get_location(left)
      let parser = advance_parser(parser)
      let (when_true, parser) = match parse_assignment_expression(parser) {
        Ok((expr, p)) => (expr, p)
        Err(p) => return Err(p)
      }
      match expect(parser, fn(t) { matches_colon(t) }) {
        Ok(parser) => {
          let parser = advance_parser(parser)
          let (when_false, parser) = match parse_assignment_expression(parser) {
            Ok((expr, p)) => (expr, p)
            Err(p) => return Err(p)
          }
          Ok(
            (
              Node::ConditionalExpression(ConditionalExpression::{
                condition: left,
                when_true,
                when_false,
                location: start_loc,
              }),
              parser,
            ),
          )
        }
        Err(parser) => Err(parser)
      }
    }
    _ => Ok((left, parser))
  }
}

///|
/// Parse binary expression with precedence climbing
fn parse_binary_expression(
  parser : Parser,
  min_precedence : Int,
) -> Result[(Node, Parser), Parser] {
  // Check recursion depth to prevent stack overflow
  let parser = match check_depth(parser) {
    Ok(p) => p
    Err(p) => return Err(p)
  }

  let (left_val, parser_val) = match parse_unary_expression(parser) {
    Ok((expr, p)) => (expr, p)
    Err(p) => return Err(p)
  }
  let mut left = left_val
  let mut parser = parser_val
  let mut should_continue = true
  while should_continue {
    let token = current_token(parser)
    let op = match get_binary_operator(token) {
      Some(op) => op
      None => {
        should_continue = false
        BinaryOperator::Add // Dummy value, won't be used
      }
    }
    if should_continue {
      let precedence = get_precedence(op)
      if precedence < min_precedence {
        should_continue = false
      } else {
        let start_loc = get_location(left)
        parser = advance_parser(parser)
        parser = increment_depth(parser)
        let (right, next_parser) = match
          parse_binary_expression(parser, precedence + 1) {
          Ok((expr, p)) => (expr, decrement_depth(p))
          Err(p) => return Err(decrement_depth(p))
        }
        left = Node::BinaryExpression(BinaryExpression::{
          left,
          operator: op,
          right,
          location: start_loc,
        })
        parser = next_parser
      }
    }
  }
  Ok((left, parser))
}

///|
/// Parse unary expression
fn parse_unary_expression(parser : Parser) -> Result[(Node, Parser), Parser] {
  // Check recursion depth to prevent stack overflow
  let parser = match check_depth(parser) {
    Ok(p) => p
    Err(p) => return Err(p)
  }

  let token = current_token(parser)
  match get_unary_operator(token) {
    Some(op) => {
      let start_loc = token.location()
      let parser = advance_parser(parser)
      let parser = increment_depth(parser)
      match parse_unary_expression(parser) {
        Ok((operand, parser)) => {
          let parser = decrement_depth(parser)
          Ok(
            (
              Node::UnaryExpression(UnaryExpression::{
                operator: op,
                operand,
                is_prefix: true,
                location: start_loc,
              }),
              parser,
            ),
          )
        }
        Err(parser) => {
          let parser = decrement_depth(parser)
          Err(parser)
        }
      }
    }
    None => parse_postfix_expression(parser)
  }
}

///|
/// Parse postfix expression (calls, property access, etc.)
fn parse_postfix_expression(parser : Parser) -> Result[(Node, Parser), Parser] {
  let (left_val, parser_val) = match parse_primary_expression(parser) {
    Ok((expr, p)) => (expr, p)
    Err(p) => return Err(p)
  }
  let mut left = left_val
  let mut parser = parser_val
  let mut should_continue = true
  while should_continue {
    let token = current_token(parser)
    match token {
      // Function call
      OpenParen(_) => {
        let start_loc = get_location(left)
        parser = advance_parser(parser)
        let (arguments, next_parser) = parse_argument_list(parser)
        parser = next_parser
        left = Node::CallExpression(CallExpression::{
          expression: left,
          type_arguments: [],
          arguments,
          location: start_loc,
        })
      }

      // Property access
      Dot(_) => {
        let start_loc = get_location(left)
        parser = advance_parser(parser)
        match parse_identifier(parser) {
          Ok((id, next_parser)) => {
            left = Node::PropertyAccessExpression(PropertyAccessExpression::{
              expression: left,
              name: id.name,
              location: start_loc,
            })
            parser = next_parser
          }
          Err(p) => return Err(p)
        }
      }

      // Element access
      OpenBracket(_) => {
        let start_loc = get_location(left)
        parser = advance_parser(parser)
        parser = increment_depth(parser)
        match parse_expression(parser) {
          Ok((index, next_parser)) => {
            parser = decrement_depth(next_parser)
            match expect(parser, fn(t) { matches_close_bracket(t) }) {
              Ok(p) => {
                parser = advance_parser(p)
                left = Node::ElementAccessExpression(ElementAccessExpression::{
                  expression: left,
                  argument_expression: index,
                  location: start_loc,
                })
              }
              Err(p) => return Err(p)
            }
          }
          Err(p) => return Err(decrement_depth(p))
        }
      }

      // Postfix increment/decrement
      PlusPlus(_) | MinusMinus(_) => {
        let start_loc = get_location(left)
        let operator = match token {
          PlusPlus(_) => UnaryOperator::Increment
          MinusMinus(_) => UnaryOperator::Decrement
          _ => UnaryOperator::Plus // Should never happen
        }
        parser = advance_parser(parser)
        left = Node::UnaryExpression(UnaryExpression::{
          operator,
          operand: left,
          is_prefix: false,
          location: start_loc,
        })
      }

      _ => should_continue = false
    }
  }
  Ok((left, parser))
}

///|
/// Parse argument list
fn parse_argument_list(parser : Parser) -> (Array[Node], Parser) {
  let arguments : Array[Node] = []
  let mut parser = parser

  // Check for empty argument list
  match current_token(parser) {
    CloseParen(_) => return (arguments, advance_parser(parser))
    _ =>
      // Empty - continue to argument parsing
      ignore(())
  }
  let mut should_continue = true
  while should_continue {
    match parse_assignment_expression(parser) {
      Ok((arg, next_parser)) => {
        arguments.push(arg)
        parser = next_parser
        match current_token(parser) {
          Comma(_) => parser = advance_parser(parser)
          // Continue loop
          CloseParen(_) => {
            parser = advance_parser(parser)
            should_continue = false
          }
          _ => should_continue = false
        }
      }
      Err(_) => should_continue = false
    }
  }
  (arguments, parser)
}

///|
/// Parse primary expression
fn parse_primary_expression(parser : Parser) -> Result[(Node, Parser), Parser] {
  let token = current_token(parser)
  match token {
    // Boolean literals (must come before general Identifier)
    Identifier(name, loc) if name == "true" || name == "false" => {
      let value = name == "true"
      Ok(
        (
          Node::BooleanLiteral(BooleanLiteral::{ value, location: loc }),
          advance_parser(parser),
        ),
      )
    }

    // Arrow function (with single parameter, no parens)
    // Must check before general Identifier to look ahead for =>
    Identifier(name, loc) =>
      // Look ahead for =>
      if parser.position + 1 < parser.tokens.length() {
        match parser.tokens.get(parser.position + 1) {
          Some(Arrow(_)) => parse_arrow_function_single_param(parser)
          _ =>
            // Regular identifier
            Ok(
              (Node::Identifier(Identifier::{ name, location: loc }), advance_parser(parser)),
            )
        }
      } else {
        // Regular identifier (at end of tokens)
        Ok(
          (Node::Identifier(Identifier::{ name, location: loc }), advance_parser(parser)),
        )
      }

    // Numeric literal
    NumericLiteral(value, loc) =>
      Ok(
        (
          Node::NumericLiteral(NumericLiteral::{ value, location: loc }),
          advance_parser(parser),
        ),
      )

    // String literal
    StringLiteral(value, loc) =>
      Ok(
        (
          Node::StringLiteral(StringLiteral::{ value, location: loc }),
          advance_parser(parser),
        ),
      )

    // null
    KeywordNull(loc) =>
      Ok((Node::NullLiteral(NullLiteral::{ location: loc }), advance_parser(parser)))

    // this
    KeywordThis(loc) =>
      Ok(
        (
          Node::ThisExpression(ThisExpression::{ location: loc }),
          advance_parser(parser),
        ),
      )

    // super
    KeywordSuper(loc) =>
      Ok(
        (
          Node::SuperExpression(SuperExpression::{ location: loc }),
          advance_parser(parser),
        ),
      )

    // Parenthesized expression
    OpenParen(_) => {
      let start_loc = token.location()
      let parser = advance_parser(parser)
      let parser = increment_depth(parser)
      match parse_expression(parser) {
        Ok((expr, parser)) => {
          let parser = decrement_depth(parser)
          match expect(parser, fn(t) { matches_close_paren(t) }) {
            Ok(parser) =>
              Ok(
                (
                  Node::ParenthesizedExpression(ParenthesizedExpression::{
                    expression: expr,
                    location: start_loc,
                  }),
                  advance_parser(parser),
                ),
              )
            Err(parser) => Err(parser)
          }
        }
        Err(parser) => {
          let parser = decrement_depth(parser)
          Err(parser)
        }
      }
    }

    // Array literal
    OpenBracket(_) => parse_array_literal(parser)

    // Object literal
    OpenBrace(_) => parse_object_literal(parser)

    _ =>
      Err(add_error(parser, "Unexpected token in expression", token.location()))
  }
}

///|
/// Parse array literal
fn parse_array_literal(parser : Parser) -> Result[(Node, Parser), Parser] {
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // Skip '['
  let elements : Array[Node?] = []
  let mut parser = parser
  while !matches_close_bracket(current_token(parser)) && !is_at_end(parser) {
    // Check for hole (elision)
    match current_token(parser) {
      Comma(_) => {
        elements.push(None)
        parser = advance_parser(parser)
        continue
      }
      _ => ignore(())
    }
    match parse_assignment_expression(parser) {
      Ok((expr, next_parser)) => {
        elements.push(Some(expr))
        parser = next_parser
        match current_token(parser) {
          Comma(_) => parser = advance_parser(parser)
          CloseBracket(_) => break
          _ => break
        }
      }
      Err(p) => return Err(p)
    }
  }
  match expect(parser, fn(t) { matches_close_bracket(t) }) {
    Ok(parser) =>
      Ok(
        (
          Node::ArrayLiteralExpression(ArrayLiteralExpression::{
            elements,
            location: start_loc,
          }),
          advance_parser(parser),
        ),
      )
    Err(parser) => Err(parser)
  }
}

///|
/// Parse object literal
fn parse_object_literal(parser : Parser) -> Result[(Node, Parser), Parser] {
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // Skip '{'
  let properties : Array[ObjectProperty] = []
  let mut parser = parser
  while !matches_close_brace(current_token(parser)) && !is_at_end(parser) {
    match parse_object_property(parser) {
      Ok((prop, next_parser)) => {
        properties.push(prop)
        parser = next_parser
        match current_token(parser) {
          Comma(_) => parser = advance_parser(parser)
          CloseBrace(_) => break
          _ => break
        }
      }
      Err(p) => return Err(p)
    }
  }
  match expect(parser, fn(t) { matches_close_brace(t) }) {
    Ok(parser) =>
      Ok(
        (
          Node::ObjectLiteralExpression(ObjectLiteralExpression::{
            properties,
            location: start_loc,
          }),
          advance_parser(parser),
        ),
      )
    Err(parser) => Err(parser)
  }
}

///|
/// Parse object property
fn parse_object_property(
  parser : Parser,
) -> Result[(ObjectProperty, Parser), Parser] {
  let start_loc = current_token(parser).location()

  // Parse property name
  match parse_identifier(parser) {
    Ok((id, next_parser)) => {
      let parser = next_parser

      // Check for shorthand or full property
      match current_token(parser) {
        Colon(_) => {
          let parser = advance_parser(parser)
          match parse_assignment_expression(parser) {
            Ok((value, parser)) =>
              Ok(
                (
                  ObjectProperty::PropertyAssignment(id.name, value, start_loc),
                  parser,
                ),
              )
            Err(parser) => Err(parser)
          }
        }
        _ =>
          // Shorthand property
          Ok((ObjectProperty::ShorthandProperty(id.name, start_loc), parser))
      }
    }
    Err(parser) => Err(parser)
  }
}

///|
/// Parse arrow function with single parameter (no parens)
fn parse_arrow_function_single_param(
  parser : Parser,
) -> Result[(Node, Parser), Parser] {
  let start_loc = current_token(parser).location()

  // Parse parameter
  let (param, parser) = match parse_identifier(parser) {
    Ok((id, p)) => (id, p)
    Err(p) => return Err(p)
  }

  // Expect =>
  match expect(parser, fn(t) { matches_arrow(t) }) {
    Ok(parser) => {
      let parser = advance_parser(parser)

      // Parse body
      let (body, parser) = match current_token(parser) {
        OpenBrace(_) =>
          // Block body
          match parse_block_statement(parser) {
            Ok((block, p)) => (block, p)
            Err(p) => return Err(p)
          }
        _ =>
          // Expression body
          match parse_assignment_expression(parser) {
            Ok((expr, p)) => (expr, p)
            Err(p) => return Err(p)
          }
      }
      let param_node = Node::Parameter(Parameter::{
        name: Node::Identifier(param),
        type_annotation: None,
        initializer: None,
        is_optional: false,
        is_rest: false,
        location: start_loc,
      })
      Ok(
        (
          Node::ArrowFunction(ArrowFunction::{
            type_parameters: [],
            parameters: [param_node],
            return_type: None,
            body,
            is_async: false,
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
/// Parse type (placeholder)
fn parse_type(parser : Parser) -> Result[(Node, Parser), Parser] {
  // TODO: Implement full type parsing
  let token = current_token(parser)
  let loc = token.location()
  match token {
    KeywordString(_) =>
      Ok(
        (
          Node::KeywordType(KeywordType::{
            kind: TypeKeyword::String,
            location: loc,
          }),
          advance_parser(parser),
        ),
      )
    KeywordNumber(_) =>
      Ok(
        (
          Node::KeywordType(KeywordType::{
            kind: TypeKeyword::Number,
            location: loc,
          }),
          advance_parser(parser),
        ),
      )
    KeywordBoolean(_) =>
      Ok(
        (
          Node::KeywordType(KeywordType::{
            kind: TypeKeyword::Boolean,
            location: loc,
          }),
          advance_parser(parser),
        ),
      )
    KeywordAny(_) =>
      Ok(
        (
          Node::KeywordType(KeywordType::{
            kind: TypeKeyword::Any,
            location: loc,
          }),
          advance_parser(parser),
        ),
      )
    Identifier(name, _) =>
      Ok(
        (
          Node::TypeReference(TypeReference::{
            type_name: name,
            type_arguments: [],
            location: loc,
          }),
          advance_parser(parser),
        ),
      )
    _ => Err(add_error(parser, "Expected type", loc))
  }
}

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
fn parse_class_declaration(parser : Parser) -> Result[(Node, Parser), Parser] {
  // [abstract] class Name [extends Super] [implements I1, I2] { members }
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'class'

  // Parse class name
  let (name, parser) = match current_token(parser) {
    Identifier(n, loc) => (Some(Node::Identifier(Identifier::{ name: n, location: loc })), advance_parser(parser))
    _ => (None, parser) // Anonymous class allowed in expressions
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
          Ok((
            Node::ClassDeclaration(ClassDeclaration::{
              name,
              type_parameters: [],
              heritage_clauses,
              members,
              is_abstract: false,
              location: SourceLocation::new(start_loc.file_path, start_loc.start, loc.end)
            }),
            parser
          ))
        }
        _ => Err(add_error(parser, "Expected '}' after class body", current_token(parser).location()))
      }
    }
    _ => Err(add_error(parser, "Expected '{' after class name", current_token(parser).location()))
  }
}

///|
/// Parse heritage clauses (extends, implements)
fn parse_heritage_clauses(parser : Parser) -> (Array[HeritageClause], Parser) {
  parse_heritage_clauses_aux(parser, [])
}

///|
fn parse_heritage_clauses_aux(parser : Parser, acc : Array[HeritageClause]) -> (Array[HeritageClause], Parser) {
  match current_token(parser) {
    KeywordExtends(_) => {
      let start_loc = current_token(parser).location()
      let parser = advance_parser(parser)
      let (types, parser) = parse_heritage_types(parser)
      acc.push(HeritageClause::{
        kind: HeritageKind::Extends,
        types,
        location: start_loc
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
        location: start_loc
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
fn parse_heritage_types_aux(parser : Parser, acc : Array[Node]) -> (Array[Node], Parser) {
  match current_token(parser) {
    Identifier(name, loc) => {
      acc.push(Node::Identifier(Identifier::{ name, location: loc }))
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
fn parse_class_members_aux(parser : Parser, acc : Array[Node]) -> (Array[Node], Parser) {
  match current_token(parser) {
    CloseBrace(_) | EOF(_) => (acc, parser)

    // Constructor
    Identifier("constructor", loc) => {
      let parser = advance_parser(parser)
      match current_token(parser) {
        OpenParen(_) => {
          let parser = advance_parser(parser)
          // Skip parameters for now - just find closing paren
          let parser = skip_until_token(parser, fn (t) {
            match t {
              CloseParen(_) => true
              _ => false
            }
          })
          let parser = advance_parser(parser) // consume ')'
          // Parse body
          let (body, parser) = match current_token(parser) {
            OpenBrace(_) => {
              match parse_block_statement(parser) {
                Ok((b, p)) => (Some(b), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }
          acc.push(Node::ConstructorDeclaration(ConstructorDeclaration::{
            parameters: [],
            body,
            location: loc
          }))
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
          let parser = skip_until_token(parser, fn (t) {
            match t {
              CloseParen(_) => true
              _ => false
            }
          })
          let parser = advance_parser(parser) // consume ')'
          let (body, parser) = match current_token(parser) {
            OpenBrace(_) => {
              match parse_block_statement(parser) {
                Ok((b, p)) => (Some(b), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }
          acc.push(Node::MethodDeclaration(MethodDeclaration::{
            name,
            type_parameters: [],
            parameters: [],
            return_type: None,
            body,
            modifiers: [],
            is_async: false,
            is_generator: false,
            location: loc
          }))
          parse_class_members_aux(parser, acc)
        }

        // Property with initializer or type annotation
        _ => {
          // Skip until semicolon or next member
          let parser = skip_until_token(parser, fn (t) {
            match t {
              Semicolon(_) | Identifier(_, _) | CloseBrace(_) => true
              _ => false
            }
          })
          let parser = match current_token(parser) {
            Semicolon(_) => advance_parser(parser)
            _ => parser
          }
          acc.push(Node::PropertyDeclaration(PropertyDeclaration::{
            name,
            type_annotation: None,
            initializer: None,
            modifiers: [],
            location: loc
          }))
          parse_class_members_aux(parser, acc)
        }
      }
    }

    // Skip other tokens
    _ => parse_class_members_aux(advance_parser(parser), acc)
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
    _ => return Err(add_error(parser, "Expected interface name", current_token(parser).location()))
  }

  // Parse heritage clauses (extends only for interfaces)
  let (heritage_clauses, parser) = parse_heritage_clauses(parser)

  // Parse interface body
  match current_token(parser) {
    OpenBrace(_) => {
      let parser = advance_parser(parser)
      // For now, skip interface members - just find closing brace
      let parser = skip_until_token(parser, fn (t) {
        match t {
          CloseBrace(_) => true
          _ => false
        }
      })
      match current_token(parser) {
        CloseBrace(loc) => {
          let parser = advance_parser(parser)
          Ok((
            Node::InterfaceDeclaration(InterfaceDeclaration::{
              name,
              type_parameters: [],
              heritage_clauses,
              members: [],
              location: SourceLocation::new(start_loc.file_path, start_loc.start, loc.end)
            }),
            parser
          ))
        }
        _ => Err(add_error(parser, "Expected '}' after interface body", current_token(parser).location()))
      }
    }
    _ => Err(add_error(parser, "Expected '{' after interface name", current_token(parser).location()))
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
    _ => return Err(add_error(parser, "Expected type name", current_token(parser).location()))
  }

  // Expect '='
  let parser = match current_token(parser) {
    Equals(_) => advance_parser(parser)
    _ => return Err(add_error(parser, "Expected '=' in type alias", current_token(parser).location()))
  }

  // Parse type (for now, just use a placeholder)
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

  Ok((
    Node::TypeAliasDeclaration(TypeAliasDeclaration::{
      name,
      type_parameters: [],
      type_node,
      location: SourceLocation::new(start_loc.file_path, start_loc.start, end_loc.end)
    }),
    parser
  ))
}

///|
fn parse_enum_declaration(parser : Parser) -> Result[(Node, Parser), Parser] {
  // enum Name { A, B = 1, C }
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'enum'

  // Parse enum name
  let (name, parser) = match current_token(parser) {
    Identifier(n, _) => (n, advance_parser(parser))
    _ => return Err(add_error(parser, "Expected enum name", current_token(parser).location()))
  }

  // Parse enum body
  match current_token(parser) {
    OpenBrace(_) => {
      let parser = advance_parser(parser)
      let (members, parser) = parse_enum_members(parser)
      match current_token(parser) {
        CloseBrace(loc) => {
          let parser = advance_parser(parser)
          Ok((
            Node::EnumDeclaration(EnumDeclaration::{
              name,
              members,
              is_const: false,
              location: SourceLocation::new(start_loc.file_path, start_loc.start, loc.end)
            }),
            parser
          ))
        }
        _ => Err(add_error(parser, "Expected '}' after enum body", current_token(parser).location()))
      }
    }
    _ => Err(add_error(parser, "Expected '{' after enum name", current_token(parser).location()))
  }
}

///|
/// Parse enum members
fn parse_enum_members(parser : Parser) -> (Array[EnumMember], Parser) {
  parse_enum_members_aux(parser, [])
}

///|
fn parse_enum_members_aux(parser : Parser, acc : Array[EnumMember]) -> (Array[EnumMember], Parser) {
  match current_token(parser) {
    CloseBrace(_) | EOF(_) => (acc, parser)
    Identifier(name, loc) => {
      let parser = advance_parser(parser)
      // Check for initializer
      let (initializer, parser) = match current_token(parser) {
        Equals(_) => {
          let parser = advance_parser(parser)
          match parse_expression(parser) {
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
fn parse_import_declaration(parser : Parser) -> Result[(Node, Parser), Parser] {
  // import [importClause] from 'module'
  // import 'module'
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'import'

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
      return Ok((
        Node::ImportDeclaration(ImportDeclaration::{
          import_clause: None,
          module_specifier,
          location: SourceLocation::new(start_loc.file_path, start_loc.start, end_loc.end)
        }),
        parser
      ))
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
            _ => return Err(add_error(parser, "Expected identifier after 'as'", current_token(parser).location()))
          }
        }
        _ => return Err(add_error(parser, "Expected 'as' after '*'", current_token(parser).location()))
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
        _ => return Err(add_error(parser, "Expected '}' after import specifiers", current_token(parser).location()))
      }
    }
    _ => (None, parser)
  }

  // Expect 'from' keyword
  let parser = match current_token(parser) {
    KeywordFrom(_) => advance_parser(parser)
    _ => return Err(add_error(parser, "Expected 'from' after import clause", current_token(parser).location()))
  }

  // Parse module specifier (string literal)
  let (module_specifier, parser) = match current_token(parser) {
    StringLiteral(spec, _) => (spec, advance_parser(parser))
    _ => return Err(add_error(parser, "Expected module specifier string", current_token(parser).location()))
  }

  let end_loc = current_token(parser).location()

  // Build import clause if we have default or named imports
  let import_clause = if default_import is None && named_bindings is None {
    None
  } else {
    Some(ImportClause::{
      name: default_import,
      named_bindings,
      location: SourceLocation::new(start_loc.file_path, start_loc.start, end_loc.end)
    })
  }

  // Consume optional semicolon
  let parser = match current_token(parser) {
    Semicolon(_) => advance_parser(parser)
    _ => parser
  }

  Ok((
    Node::ImportDeclaration(ImportDeclaration::{
      import_clause,
      module_specifier,
      location: SourceLocation::new(start_loc.file_path, start_loc.start, end_loc.end)
    }),
    parser
  ))
}

///|
/// Helper: Parse import specifiers { a, b as c, d }
fn parse_import_specifiers(parser : Parser) -> (Array[ImportSpecifier], Parser) {
  parse_import_specifiers_aux(parser, [])
}

///|
/// Tail-recursive helper for parsing import specifiers
fn parse_import_specifiers_aux(parser : Parser, acc : Array[ImportSpecifier]) -> (Array[ImportSpecifier], Parser) {
  match current_token(parser) {
    CloseBrace(_) | EOF(_) => (acc, parser)
    Identifier(name, loc) => {
      let parser = advance_parser(parser)
      // Check for 'as' renaming
      match current_token(parser) {
        KeywordAs(_) => {
          let parser = advance_parser(parser)
          match current_token(parser) {
            Identifier(local_name, _) => {
              let parser = advance_parser(parser)
              acc.push(ImportSpecifier::{ property_name: Some(name), name: local_name, location: loc })
              // Check for comma
              match current_token(parser) {
                Comma(_) => parse_import_specifiers_aux(advance_parser(parser), acc)
                _ => (acc, parser)
              }
            }
            _ => (acc, parser) // Error, but continue
          }
        }
        _ => {
          // No renaming
          acc.push(ImportSpecifier::{ property_name: None, name, location: loc })
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
    // export default expression
    KeywordDefault(_) => {
      let parser = advance_parser(parser)
      match parse_expression(parser) {
        Ok((expression, parser)) => {
          let end_loc = get_location(expression)
          // Consume optional semicolon
          let parser = match current_token(parser) {
            Semicolon(_) => advance_parser(parser)
            _ => parser
          }
          Ok((
            Node::ExportAssignment(ExportAssignment::{
              expression,
              is_export_equals: false,
              location: SourceLocation::new(start_loc.file_path, start_loc.start, end_loc.end)
            }),
            parser
          ))
        }
        Err(p) => Err(p)
      }
    }

    // export * from 'module'
    Star(_) => {
      let parser = advance_parser(parser)
      match current_token(parser) {
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
              Ok((
                Node::ExportDeclaration(ExportDeclaration::{
                  export_clause: None,
                  module_specifier: Some(module_specifier),
                  location: SourceLocation::new(start_loc.file_path, start_loc.start, end_loc.end)
                }),
                parser
              ))
            }
            _ => Err(add_error(parser, "Expected module specifier after 'from'", current_token(parser).location()))
          }
        }
        _ => Err(add_error(parser, "Expected 'from' after 'export *'", current_token(parser).location()))
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
                _ => return Err(add_error(parser, "Expected module specifier after 'from'", current_token(parser).location()))
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
          Ok((
            Node::ExportDeclaration(ExportDeclaration::{
              export_clause: Some(NamedExports::NamedExports(specifiers, loc)),
              module_specifier,
              location: SourceLocation::new(start_loc.file_path, start_loc.start, end_loc.end)
            }),
            parser
          ))
        }
        _ => Err(add_error(parser, "Expected '}' after export specifiers", current_token(parser).location()))
      }
    }

    // export declaration (const, let, var, function, class, etc.)
    _ => {
      // Parse the declaration and wrap it
      match parse_statement(parser) {
        Ok((stmt, parser)) => {
          // For now, just return the statement itself
          // In a full implementation, we'd wrap this in an ExportDeclaration node
          Ok((stmt, parser))
        }
        Err(p) => Err(p)
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
fn parse_export_specifiers_aux(parser : Parser, acc : Array[ExportSpecifier]) -> (Array[ExportSpecifier], Parser) {
  match current_token(parser) {
    CloseBrace(_) | EOF(_) => (acc, parser)
    Identifier(name, loc) => {
      let parser = advance_parser(parser)
      // Check for 'as' renaming
      match current_token(parser) {
        KeywordAs(_) => {
          let parser = advance_parser(parser)
          match current_token(parser) {
            Identifier(export_name, _) => {
              let parser = advance_parser(parser)
              acc.push(ExportSpecifier::{ property_name: Some(name), name: export_name, location: loc })
              // Check for comma
              match current_token(parser) {
                Comma(_) => parse_export_specifiers_aux(advance_parser(parser), acc)
                _ => (acc, parser)
              }
            }
            _ => (acc, parser) // Error, but continue
          }
        }
        _ => {
          // No renaming
          acc.push(ExportSpecifier::{ property_name: None, name, location: loc })
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
    _ => return Err(add_error(parser, "Expected '(' after 'switch'", current_token(parser).location()))
  }

  // Parse expression
  let (expression, parser) = match parse_expression(parser) {
    Ok((expr, p)) => (expr, p)
    Err(p) => return Err(p)
  }

  // Expect ')'
  let parser = match current_token(parser) {
    CloseParen(_) => advance_parser(parser)
    _ => return Err(add_error(parser, "Expected ')' after switch expression", current_token(parser).location()))
  }

  // Expect '{'
  let parser = match current_token(parser) {
    OpenBrace(_) => advance_parser(parser)
    _ => return Err(add_error(parser, "Expected '{' after switch header", current_token(parser).location()))
  }

  // Parse case clauses
  let (cases, parser) = parse_case_clauses(parser)

  // Expect '}'
  let end_loc = match current_token(parser) {
    CloseBrace(loc) => loc
    _ => return Err(add_error(parser, "Expected '}' after switch body", current_token(parser).location()))
  }
  let parser = advance_parser(parser)

  Ok((
    Node::SwitchStatement(SwitchStatement::{
      expression,
      cases,
      location: SourceLocation::new(start_loc.file_path, start_loc.start, end_loc.end)
    }),
    parser
  ))
}

///|
/// Parse case clauses
fn parse_case_clauses(parser : Parser) -> (Array[CaseClause], Parser) {
  parse_case_clauses_aux(parser, [])
}

///|
fn parse_case_clauses_aux(parser : Parser, acc : Array[CaseClause]) -> (Array[CaseClause], Parser) {
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
fn parse_case_statements_aux(parser : Parser, acc : Array[Node]) -> (Array[Node], Parser) {
  match current_token(parser) {
    KeywordCase(_) | KeywordDefault(_) | CloseBrace(_) | EOF(_) => (acc, parser)
    _ => {
      match parse_statement(parser) {
        Ok((stmt, p)) => {
          acc.push(stmt)
          parse_case_statements_aux(p, acc)
        }
        Err(p) => (acc, p)
      }
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
    _ => return Err(add_error(parser, "Expected '(' after 'for'", current_token(parser).location()))
  }

  // Parse initializer (or for-in/for-of variable)
  let (initializer, parser) = match current_token(parser) {
    Semicolon(_) => (None, parser)
    KeywordLet(_) | KeywordConst(_) | KeywordVar(_) => {
      // Use parse_variable_declaration_list to avoid consuming the semicolon
      // The semicolon belongs to the for-loop syntax, not the variable declaration
      match parse_variable_declaration_list(parser, true) {
        Ok((declarations, is_const, is_let, location, p)) => {
          let stmt = Node::VariableStatement(VariableStatement::{
            declarations,
            is_const,
            is_let,
            location,
          })
          (Some(stmt), p)
        }
        Err(p) => (None, p)
      }
    }
    _ => {
      match parse_expression(parser) {
        Ok((expr, p)) => (Some(expr), p)
        Err(p) => (None, p)
      }
    }
  }

  // Check for for-in or for-of
  match current_token(parser) {
    KeywordIn(_) => {
      // for-in loop
      let parser = advance_parser(parser)
      let (expression, parser) = match parse_expression(parser) {
        Ok((expr, p)) => (expr, p)
        Err(p) => return Err(add_error(p, "Expected expression in for-in", current_token(p).location()))
      }
      let parser = match current_token(parser) {
        CloseParen(_) => advance_parser(parser)
        _ => return Err(add_error(parser, "Expected ')' in for-in", current_token(parser).location()))
      }
      let (statement, parser) = match parse_statement(parser) {
        Ok((stmt, p)) => (stmt, p)
        Err(p) => return Err(p)
      }
      let end_loc = get_location(statement)
      return Ok((
        Node::ForInStatement(ForInStatement::{
          initializer: initializer.unwrap_or(Node::EmptyStatement(EmptyStatement::{ location: start_loc })),
          expression,
          statement,
          location: SourceLocation::new(start_loc.file_path, start_loc.start, end_loc.end)
        }),
        parser
      ))
    }
    KeywordOf(_) => {
      // for-of loop
      let parser = advance_parser(parser)
      let (expression, parser) = match parse_expression(parser) {
        Ok((expr, p)) => (expr, p)
        Err(p) => return Err(add_error(p, "Expected expression in for-of", current_token(p).location()))
      }
      let parser = match current_token(parser) {
        CloseParen(_) => advance_parser(parser)
        _ => return Err(add_error(parser, "Expected ')' in for-of", current_token(parser).location()))
      }
      let (statement, parser) = match parse_statement(parser) {
        Ok((stmt, p)) => (stmt, p)
        Err(p) => return Err(p)
      }
      let end_loc = get_location(statement)
      return Ok((
        Node::ForOfStatement(ForOfStatement::{
          initializer: initializer.unwrap_or(Node::EmptyStatement(EmptyStatement::{ location: start_loc })),
          expression,
          statement,
          await_modifier: false,
          location: SourceLocation::new(start_loc.file_path, start_loc.start, end_loc.end)
        }),
        parser
      ))
    }
    _ => ()
  }

  // Regular for loop: for (init; condition; incrementor) statement
  // Expect semicolon after initializer
  let parser = match current_token(parser) {
    Semicolon(_) => advance_parser(parser)
    _ => return Err(add_error(parser, "Expected ';' after for loop initializer", current_token(parser).location()))
  }

  // Parse condition
  let (condition, parser) = match current_token(parser) {
    Semicolon(_) => (None, parser)
    _ => match parse_expression(parser) {
      Ok((expr, p)) => (Some(expr), p)
      Err(p) => (None, p)
    }
  }

  // Expect semicolon after condition
  let parser = match current_token(parser) {
    Semicolon(_) => advance_parser(parser)
    _ => return Err(add_error(parser, "Expected ';' after for loop condition", current_token(parser).location()))
  }

  // Parse incrementor
  let (incrementor, parser) = match current_token(parser) {
    CloseParen(_) => (None, parser)
    _ => match parse_expression(parser) {
      Ok((expr, p)) => (Some(expr), p)
      Err(p) => (None, p)
    }
  }

  // Expect ')'
  let parser = match current_token(parser) {
    CloseParen(_) => advance_parser(parser)
    _ => return Err(add_error(parser, "Expected ')' after for loop header", current_token(parser).location()))
  }

  // Parse statement
  let (statement, parser) = match parse_statement(parser) {
    Ok((stmt, p)) => (stmt, p)
    Err(p) => return Err(p)
  }

  let end_loc = get_location(statement)

  Ok((
    Node::ForStatement(ForStatement::{
      initializer,
      condition,
      incrementor,
      statement,
      location: SourceLocation::new(start_loc.file_path, start_loc.start, end_loc.end)
    }),
    parser
  ))
}

///|
fn parse_while_statement(parser : Parser) -> Result[(Node, Parser), Parser] {
  // while (condition) statement
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'while'

  // Expect '('
  let parser = match current_token(parser) {
    OpenParen(_) => advance_parser(parser)
    _ => return Err(add_error(parser, "Expected '(' after 'while'", current_token(parser).location()))
  }

  // Parse condition
  let (condition, parser) = match parse_expression(parser) {
    Ok((expr, p)) => (expr, p)
    Err(p) => return Err(p)
  }

  // Expect ')'
  let parser = match current_token(parser) {
    CloseParen(_) => advance_parser(parser)
    _ => return Err(add_error(parser, "Expected ')' after while condition", current_token(parser).location()))
  }

  // Parse statement
  let (statement, parser) = match parse_statement(parser) {
    Ok((stmt, p)) => (stmt, p)
    Err(p) => return Err(p)
  }

  let end_loc = get_location(statement)

  Ok((
    Node::WhileStatement(WhileStatement::{
      condition,
      statement,
      location: SourceLocation::new(start_loc.file_path, start_loc.start, end_loc.end)
    }),
    parser
  ))
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
    _ => return Err(add_error(parser, "Expected 'while' after do statement", current_token(parser).location()))
  }

  // Expect '('
  let parser = match current_token(parser) {
    OpenParen(_) => advance_parser(parser)
    _ => return Err(add_error(parser, "Expected '(' after 'while'", current_token(parser).location()))
  }

  // Parse condition
  let (condition, parser) = match parse_expression(parser) {
    Ok((expr, p)) => (expr, p)
    Err(p) => return Err(p)
  }

  // Expect ')'
  let parser = match current_token(parser) {
    CloseParen(_) => advance_parser(parser)
    _ => return Err(add_error(parser, "Expected ')' after while condition", current_token(parser).location()))
  }

  // Expect ';'
  let end_loc = current_token(parser).location()
  let parser = match current_token(parser) {
    Semicolon(_) => advance_parser(parser)
    _ => parser // Semicolon is optional in some contexts
  }

  Ok((
    Node::DoWhileStatement(DoWhileStatement::{
      statement,
      condition,
      location: SourceLocation::new(start_loc.file_path, start_loc.start, end_loc.end)
    }),
    parser
  ))
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

  Ok((
    Node::BreakStatement(BreakStatement::{
      label,
      location: SourceLocation::new(start_loc.file_path, start_loc.start, end_loc.end)
    }),
    parser
  ))
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

  Ok((
    Node::ContinueStatement(ContinueStatement::{
      label,
      location: SourceLocation::new(start_loc.file_path, start_loc.start, end_loc.end)
    }),
    parser
  ))
}

///|
fn parse_throw_statement(parser : Parser) -> Result[(Node, Parser), Parser] {
  // throw expression;
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'throw'

  // Parse expression
  let (expression, parser) = match parse_expression(parser) {
    Ok((expr, p)) => (expr, p)
    Err(p) => return Err(add_error(p, "Expected expression after 'throw'", current_token(p).location()))
  }

  // Expect semicolon (optional due to ASI)
  let end_loc = get_location(expression)
  let parser = match current_token(parser) {
    Semicolon(_) => advance_parser(parser)
    _ => parser
  }

  Ok((
    Node::ThrowStatement(ThrowStatement::{
      expression,
      location: SourceLocation::new(start_loc.file_path, start_loc.start, end_loc.end)
    }),
    parser
  ))
}

///|
fn parse_try_statement(parser : Parser) -> Result[(Node, Parser), Parser] {
  // try block catch (variable) block finally block
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'try'

  // Parse try block
  let (try_block, parser) = match parse_block_statement(parser) {
    Ok((block, p)) => (block, p)
    Err(p) => return Err(add_error(p, "Expected block after 'try'", current_token(p).location()))
  }

  // Parse optional catch clause
  let (catch_clause, parser) = match current_token(parser) {
    KeywordCatch(_) => {
      let catch_start = current_token(parser).location()
      let parser = advance_parser(parser) // consume 'catch'

      // Optional parameter
      let (parameter, parser) = match current_token(parser) {
        OpenParen(_) => {
          let parser = advance_parser(parser)
          let (param, parser) = match parse_identifier(parser) {
            Ok((id, p)) => (Some(id), p)
            Err(p) => (None, p)
          }
          let parser = match current_token(parser) {
            CloseParen(_) => advance_parser(parser)
            _ => return Err(add_error(parser, "Expected ')' after catch parameter", current_token(parser).location()))
          }
          (param, parser)
        }
        _ => (None, parser)
      }

      // Parse catch block
      let (catch_block, parser) = match parse_block_statement(parser) {
        Ok((block, p)) => (block, p)
        Err(p) => return Err(add_error(p, "Expected block in catch clause", current_token(p).location()))
      }

      let catch_end = get_location(catch_block)
      let clause = CatchClause::{
        variable_declaration: match parameter {
          Some(id) => Some(Node::Identifier(id))
          None => None
        },
        block: catch_block,
        location: SourceLocation::new(catch_start.file_path, catch_start.start, catch_end.end)
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
        Err(p) => return Err(add_error(p, "Expected block after 'finally'", current_token(p).location()))
      }
    }
    _ => (None, parser)
  }

  // Must have either catch or finally
  if catch_clause is None && finally_block is None {
    return Err(add_error(parser, "Missing catch or finally clause", current_token(parser).location()))
  }

  let end_loc = match finally_block {
    Some(block) => get_location(block)
    None => match catch_clause {
      Some(clause) => clause.location
      None => get_location(try_block)
    }
  }

  Ok((
    Node::TryStatement(TryStatement::{
      try_block,
      catch_clause,
      finally_block,
      location: SourceLocation::new(start_loc.file_path, start_loc.start, end_loc.end)
    }),
    parser
  ))
}

///|
fn parse_type_parameters(parser : Parser) -> (Array[TypeParameter], Parser) {
  // TODO: Implement
  ([], parser)
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
    Err(add_error(parser, "Expression too deeply nested (stack overflow prevention)", loc))
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
    KeywordIn(_) => Some(BinaryOperator::In)
    KeywordInstanceOf(_) => Some(BinaryOperator::InstanceOf)
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
