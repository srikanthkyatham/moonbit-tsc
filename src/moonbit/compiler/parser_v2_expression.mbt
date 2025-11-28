// Expression Parsing v2 - Rewritten for cleaner code
// Replaces parser_expression.mbt with refactored implementation

///|
/// Get assignment operator from token (returns None if not an assignment operator)
fn get_assignment_operator(token : Token) -> BinaryOperator? {
  match token {
    Equals(_) => Some(BinaryOperator::Assign)
    PlusEquals(_) => Some(BinaryOperator::AddAssign)
    MinusEquals(_) => Some(BinaryOperator::SubtractAssign)
    StarEquals(_) => Some(BinaryOperator::MultiplyAssign)
    SlashEquals(_) => Some(BinaryOperator::DivideAssign)
    PercentEquals(_) => Some(BinaryOperator::RemainderAssign)
    StarStarEquals(_) => Some(BinaryOperator::ExponentiateAssign)
    AmpersandEquals(_) => Some(BinaryOperator::BitwiseAndAssign)
    BarEquals(_) => Some(BinaryOperator::BitwiseOrAssign)
    CaretEquals(_) => Some(BinaryOperator::BitwiseXorAssign)
    LessThanLessThanEquals(_) => Some(BinaryOperator::LeftShiftAssign)
    GreaterThanGreaterThanEquals(_) => Some(BinaryOperator::RightShiftAssign)
    GreaterThanGreaterThanGreaterThanEquals(_) =>
      Some(BinaryOperator::UnsignedRightShiftAssign)
    AmpersandAmpersandEquals(_) => Some(BinaryOperator::LogicalAndAssign)
    BarBarEquals(_) => Some(BinaryOperator::LogicalOrAssign)
    QuestionQuestionEquals(_) => Some(BinaryOperator::NullishCoalescingAssign)
    _ => None
  }
}

///|
/// Parse expression (handles comma operator which is the lowest precedence)
fn parse_expression_v2(parser : Parser) -> Result[(Node, Parser), Parser] {
  let (first_expr, first_parser) = match
    parse_assignment_expression_v2(parser) {
    Ok(result) => result
    Err(p) => return Err(p)
  }

  // Handle comma operator (lowest precedence)
  let mut left = first_expr
  let mut parser = first_parser
  while true {
    match current_token(parser) {
      Comma(_) => {
        let start_loc = get_location(left)
        parser = advance_parser(parser)
        match parse_assignment_expression_v2(parser) {
          Ok((right, next_parser)) => {
            left = Node::BinaryExpression(BinaryExpression::{
              operator: BinaryOperator::Comma,
              left,
              right,
              location: start_loc,
            })
            parser = next_parser
          }
          Err(p) => return Err(p)
        }
      }
      _ => break
    }
  }
  Ok((left, parser))
}

///|
/// Check if we have an arrow function ahead by looking for =>
fn is_arrow_function_ahead_v2(parser : Parser) -> Bool {
  match current_token(parser) {
    // Case 1: (a, b) => expr
    OpenParen(_) => {
      // Scan ahead to find matching closing paren
      let mut depth = 1
      let mut index = parser.position + 1
      while index < parser.tokens.length() && depth > 0 {
        match parser.tokens[index] {
          OpenParen(_) => depth = depth + 1
          CloseParen(_) => depth = depth - 1
          _ => ()
        }
        index = index + 1
      }
      // Check if token after closing paren is Arrow or Colon (for return type)
      if index < parser.tokens.length() {
        match parser.tokens[index] {
          Arrow(_) => true
          Colon(_) => has_arrow_after_type(parser.tokens, index + 1)
          _ => false
        }
      } else {
        false
      }
    }
    // Case 2: a => expr (single identifier)
    Identifier(_) =>
      if parser.position + 1 < parser.tokens.length() {
        match parser.tokens[parser.position + 1] {
          Arrow(_) => true
          _ => false
        }
      } else {
        false
      }
    _ => false
  }
}

///|
/// Helper: scan tokens to find Arrow after type annotation
fn has_arrow_after_type(tokens : Array[Token], start_index : Int) -> Bool {
  let mut index = start_index
  while index < tokens.length() {
    match tokens[index] {
      Arrow(_) => return true
      Semicolon(_) | OpenBrace(_) | CloseBrace(_) | EOF(_) => return false
      _ => index = index + 1
    }
  }
  false
}

///|
/// Parse assignment expression - refactored to use helper function
fn parse_assignment_expression_v2(
  parser : Parser,
) -> Result[(Node, Parser), Parser] {
  // Check if this is an arrow function
  if is_arrow_function_ahead_v2(parser) {
    match current_token(parser) {
      OpenParen(_) =>
        match try_parse_arrow_function(parser) {
          Ok(result) => return Ok(result)
          Err(_) => ()
        }
      Identifier(_) =>
        match try_parse_single_param_arrow_function(parser) {
          Ok(result) => return Ok(result)
          Err(_) => ()
        }
      _ => ()
    }
  }

  // Parse left-hand side (conditional expression)
  let (left, parser) = match parse_conditional_expression_v2(parser) {
    Ok(result) => result
    Err(p) => return Err(p)
  }

  // Check for assignment operators using helper function
  match get_assignment_operator(current_token(parser)) {
    Some(op) => {
      let start_loc = get_location(left)
      let parser = advance_parser(parser)
      let (right, parser) = match parse_assignment_expression_v2(parser) {
        Ok(result) => result
        Err(p) => return Err(p)
      }
      Ok(
        (
          Node::BinaryExpression(BinaryExpression::{
            left,
            operator: op,
            right,
            location: start_loc,
          }),
          parser,
        ),
      )
    }
    None => Ok((left, parser))
  }
}

///|
/// Parse conditional (ternary) expression
fn parse_conditional_expression_v2(
  parser : Parser,
) -> Result[(Node, Parser), Parser] {
  let (left, parser) = match parse_binary_expression(parser, 0) {
    Ok(result) => result
    Err(p) => return Err(p)
  }

  // Check for ternary operator
  match current_token(parser) {
    Question(_) => {
      let start_loc = get_location(left)
      let parser = advance_parser(parser)
      let (when_true, parser) = match parse_assignment_expression_v2(parser) {
        Ok(result) => result
        Err(p) => return Err(p)
      }
      match expect(parser, fn(t) { matches_colon(t) }) {
        Ok(parser) => {
          let parser = advance_parser(parser)
          let (when_false, parser) = match
            parse_assignment_expression_v2(parser) {
            Ok(result) => result
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

// ============================================================================
// Helper functions for reducing code duplication
// ============================================================================

///|
/// Parse optional return type annotation (: Type)
fn parse_optional_return_type(parser : Parser) -> (Node?, Parser) {
  match current_token(parser) {
    Colon(_) => {
      let parser = advance_parser(parser)
      match parse_type(parser) {
        Ok((ty, p)) => (Some(ty), p)
        Err(p) => (None, p)
      }
    }
    _ => (None, parser)
  }
}

///|
/// Parse arrow function body (block or expression)
fn parse_arrow_body(parser : Parser) -> Result[(Node, Parser), Parser] {
  match current_token(parser) {
    OpenBrace(_) => parse_block_statement(parser)
    _ => parse_assignment_expression(parser)
  }
}

///|
/// Create an arrow function node
fn make_arrow_function(
  params : Array[Node],
  return_type : Node?,
  body : Node,
  is_async : Bool,
  location : SourceLocation,
) -> Node {
  Node::ArrowFunction(ArrowFunction::{
    type_parameters: [],
    parameters: params,
    return_type,
    body,
    is_async,
    location,
  })
}

///|
/// Create a function expression node
fn make_function_expression(
  name : String?,
  params : Array[Node],
  return_type : Node?,
  body : Node,
  is_async : Bool,
  is_generator : Bool,
  location : SourceLocation,
) -> Node {
  Node::FunctionExpression(FunctionExpression::{
    name,
    type_parameters: [],
    parameters: params,
    return_type,
    body,
    is_async,
    is_generator,
    location,
  })
}

///|
/// Create a simple parameter node from an identifier
fn make_simple_parameter(id : Identifier) -> Node {
  Node::Parameter(Parameter::{
    name: Node::Identifier(id),
    type_annotation: None,
    initializer: None,
    is_optional: false,
    is_rest: false,
    is_this_parameter: false,
    decorators: [],
    modifiers: [],
    location: id.location,
  })
}

///|
/// Parse optional function name (identifier)
fn parse_optional_function_name(parser : Parser) -> (String?, Parser) {
  match current_token(parser) {
    Identifier(fname, _) => (Some(fname), advance_parser(parser))
    _ => (None, parser)
  }
}

///|
/// Create a YieldExpression node
fn make_yield_expression(
  expression : Node?,
  is_delegate : Bool,
  location : SourceLocation,
) -> Node {
  Node::YieldExpression(YieldExpression::{ expression, is_delegate, location })
}

///|
/// Create a NewExpression node
fn make_new_expression(
  expr : Node,
  arguments : Array[Node]?,
  location : SourceLocation,
) -> Node {
  Node::NewExpression(NewExpression::{
    expression: expr,
    type_arguments: [],
    arguments,
    location,
  })
}

///|
/// Parse bracketed expression [expr] with depth management
/// Returns the parsed index expression
fn parse_bracketed_expression(
  parser : Parser,
) -> Result[(Node, Parser), Parser] {
  let parser = advance_parser(parser) // consume [
  let parser = increment_depth(parser)
  match parse_expression(parser) {
    Ok((index, parser)) => {
      let parser = decrement_depth(parser)
      match expect(parser, fn(t) { matches_close_bracket(t) }) {
        Ok(p) => Ok((index, advance_parser(p)))
        Err(p) => Err(p)
      }
    }
    Err(p) => Err(decrement_depth(p))
  }
}

///|
/// Parse property value after colon (expects parser positioned at ':')
/// Returns PropertyAssignment on success
fn parse_colon_property_value(
  parser : Parser,
  name : String,
  start_loc : SourceLocation,
  error_context : String,
) -> Result[(ObjectProperty, Parser), Parser] {
  match current_token(parser) {
    Colon(_) => {
      let parser = advance_parser(parser) // consume :
      match parse_assignment_expression(parser) {
        Ok((value, parser)) =>
          Ok(
            (ObjectProperty::PropertyAssignment(name, value, start_loc), parser),
          )
        Err(parser) => Err(parser)
      }
    }
    _ =>
      Err(
        add_error(
          parser,
          "Expected ':' after " + error_context,
          current_token(parser).location(),
        ),
      )
  }
}

///|
/// Parse function expression body (parameters, optional return type, block)
/// Used for both regular and async function expressions
fn parse_function_expression_body(
  parser : Parser,
  name : String?,
  is_async : Bool,
  start_loc : SourceLocation,
) -> Result[(Node, Parser), Parser] {
  // Expect opening paren
  match expect(parser, fn(t) { matches_open_paren(t) }) {
    Ok(parser) => {
      let parser = advance_parser(parser)
      let (params, parser) = parse_parameter_list(parser)
      let (return_type, parser) = parse_optional_return_type(parser)
      match parse_block_statement(parser) {
        Ok((body, parser)) =>
          Ok(
            (
              make_function_expression(
                name, params, return_type, body, is_async, false, start_loc,
              ),
              parser,
            ),
          )
        Err(parser) => Err(parser)
      }
    }
    Err(parser) => Err(parser)
  }
}

///|
/// Parse async arrow function with parenthesized parameters
fn parse_async_arrow_with_params(
  parser : Parser,
  start_loc : SourceLocation,
) -> Result[(Node, Parser), Parser] {
  let parser = advance_parser(parser) // consume '('
  let (params, parser) = parse_parameter_list(parser)
  let (return_type, parser) = parse_optional_return_type(parser)

  // Expect =>
  match current_token(parser) {
    Arrow(_) => {
      let parser = advance_parser(parser)
      match parse_arrow_body(parser) {
        Ok((body, parser)) =>
          Ok(
            (
              make_arrow_function(params, return_type, body, true, start_loc),
              parser,
            ),
          )
        Err(parser) => Err(parser)
      }
    }
    _ =>
      Err(
        add_error(
          parser,
          "Expected '=>' after async arrow function parameters",
          current_token(parser).location(),
        ),
      )
  }
}

///|
/// Parse async arrow function with single identifier parameter
fn parse_async_arrow_single_param(
  parser : Parser,
  name : String,
  param_loc : SourceLocation,
  start_loc : SourceLocation,
) -> Result[(Node, Parser), Parser] {
  // Expect =>
  match current_token(parser) {
    Arrow(_) => {
      let parser = advance_parser(parser)
      let id = Identifier::{ name, location: param_loc }
      match parse_arrow_body(parser) {
        Ok((body, parser)) =>
          Ok(
            (
              make_arrow_function(
                [make_simple_parameter(id)],
                None,
                body,
                true,
                start_loc,
              ),
              parser,
            ),
          )
        Err(parser) => Err(parser)
      }
    }
    _ =>
      Err(
        add_error(
          parser,
          "Expected '=>' after async identifier",
          current_token(parser).location(),
        ),
      )
  }
}

///|
/// Parse parenthesized expression with depth management
/// Expects parser positioned at '(' - consumes '(' and ')'
/// Returns the parsed expression
fn parse_parenthesized_expression(
  parser : Parser,
) -> Result[(Node, Parser), Parser] {
  let parser = advance_parser(parser) // consume (
  let parser = increment_depth(parser)
  match parse_expression(parser) {
    Ok((expr, parser)) => {
      let parser = decrement_depth(parser)
      match expect(parser, fn(t) { matches_close_paren(t) }) {
        Ok(p) => Ok((expr, advance_parser(p)))
        Err(p) => Err(p)
      }
    }
    Err(p) => Err(decrement_depth(p))
  }
}

///|
/// Create a CallExpression node
fn make_call_expression(
  expression : Node,
  type_arguments : Array[Node],
  arguments : Array[Node],
  location : SourceLocation,
) -> Node {
  Node::CallExpression(CallExpression::{
    expression,
    type_arguments,
    arguments,
    location,
  })
}

///|
/// Create a PropertyAccessExpression node
fn make_property_access(
  expression : Node,
  name : String,
  location : SourceLocation,
) -> Node {
  Node::PropertyAccessExpression(PropertyAccessExpression::{
    expression,
    name,
    location,
  })
}

///|
/// Create an ElementAccessExpression node
fn make_element_access(
  expression : Node,
  argument_expression : Node,
  location : SourceLocation,
) -> Node {
  Node::ElementAccessExpression(ElementAccessExpression::{
    expression,
    argument_expression,
    location,
  })
}
