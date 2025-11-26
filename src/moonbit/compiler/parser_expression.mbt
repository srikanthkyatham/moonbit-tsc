// Expression Parsing - Split from parser.mbt for better organization
// Contains all expression-related parsing functions
// NOTE: Core expression logic moved to parser_v2_expression.mbt

///|
/// Parse expression (delegates to v2 implementation)
fn parse_expression(parser : Parser) -> Result[(Node, Parser), Parser] {
  parse_expression_v2(parser)
}

///|
/// Parse assignment expression (delegates to v2 implementation)
fn parse_assignment_expression(
  parser : Parser,
) -> Result[(Node, Parser), Parser] {
  parse_assignment_expression_v2(parser)
}

///|
fn try_parse_arrow_function(parser : Parser) -> Result[(Node, Parser), Parser] {
  let start_loc = current_token(parser).location()
  let original_parser = parser // Save original state

  // Consume opening paren
  let parser = match current_token(parser) {
    OpenParen(_) => advance_parser(parser)
    _ => return Err(original_parser)
  }

  // Parse parameters
  let (params, parser) = parse_parameter_list(parser)
  let mut parser = parser

  // Parse optional return type annotation
  let (return_type, p) = match current_token(parser) {
    Colon(_) => {
      parser = advance_parser(parser)
      match parse_type(parser) {
        Ok((ty, p)) => (Some(ty), p)
        Err(_) => return Err(original_parser)
      }
    }
    _ => (None, parser)
  }
  parser = p

  // Expect arrow =>
  parser = match current_token(parser) {
    Arrow(_) => advance_parser(parser)
    _ => return Err(original_parser)
  }

  // Parse body (expression or block)
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
  Ok(
    (
      Node::ArrowFunction(ArrowFunction::{
        type_parameters: [],
        parameters: params,
        return_type,
        body,
        is_async: false,
        location: start_loc,
      }),
      parser,
    ),
  )
}

///|
/// Try to parse single parameter arrow function: a => expr
fn try_parse_single_param_arrow_function(
  parser : Parser,
) -> Result[(Node, Parser), Parser] {
  let start_loc = current_token(parser).location()
  let original_parser = parser // Save original state

  // Parse single parameter (identifier only)
  let (id, parser) = match parse_identifier(parser) {
    Ok((i, p)) => (i, p)
    Err(_) => return Err(original_parser)
  }

  // Expect arrow =>
  let parser = match current_token(parser) {
    Arrow(_) => advance_parser(parser)
    _ => return Err(original_parser)
  }

  // Parse body (expression or block)
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
  let params = [
    Node::Parameter(Parameter::{
      name: Node::Identifier(id),
      type_annotation: None,
      initializer: None,
      is_optional: false,
      is_rest: false,
      modifiers: [],
      location: id.location,
    }),
  ]
  Ok(
    (
      Node::ArrowFunction(ArrowFunction::{
        type_parameters: [],
        parameters: params,
        return_type: None,
        body,
        is_async: false,
        location: start_loc,
      }),
      parser,
    ),
  )
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

  // Check for "await" expression
  match token {
    KeywordAwait(start_loc) => {
      let parser = advance_parser(parser)
      let parser = increment_depth(parser)
      match parse_unary_expression(parser) {
        Ok((expr, parser)) => {
          let parser = decrement_depth(parser)
          return Ok(
            (
              Node::AwaitExpression(AwaitExpression::{
                expression: expr,
                location: start_loc,
              }),
              parser,
            ),
          )
        }
        Err(parser) => {
          let parser = decrement_depth(parser)
          return Err(parser)
        }
      }
    }
    _ => ()
  }

  // Check for "yield" expression
  match token {
    KeywordYield(start_loc) => {
      let parser = advance_parser(parser)
      // Check for yield* (delegate)
      let (is_delegate, parser) = match current_token(parser) {
        Star(_) => (true, advance_parser(parser))
        _ => (false, parser)
      }
      // Yield can have an optional expression
      let parser = increment_depth(parser)
      // Try to parse expression, but it's optional for yield
      match current_token(parser) {
        // These tokens indicate end of yield expression (no argument)
        Semicolon(_)
        | CloseParen(_)
        | CloseBracket(_)
        | CloseBrace(_)
        | Comma(_)
        | Colon(_) => {
          let parser = decrement_depth(parser)
          return Ok(
            (
              Node::YieldExpression(YieldExpression::{
                expression: None,
                is_delegate,
                location: start_loc,
              }),
              parser,
            ),
          )
        }
        _ =>
          match parse_expression(parser) {
            Ok((expr, parser)) => {
              let parser = decrement_depth(parser)
              return Ok(
                (
                  Node::YieldExpression(YieldExpression::{
                    expression: Some(expr),
                    is_delegate,
                    location: start_loc,
                  }),
                  parser,
                ),
              )
            }
            Err(_) => {
              // No expression, that's okay for yield
              let parser = decrement_depth(parser)
              return Ok(
                (
                  Node::YieldExpression(YieldExpression::{
                    expression: None,
                    is_delegate,
                    location: start_loc,
                  }),
                  parser,
                ),
              )
            }
          }
      }
    }
    _ => ()
  }

  // Check for "new" expression
  match token {
    KeywordNew(start_loc) => {
      let parser = advance_parser(parser)
      let parser = increment_depth(parser)
      // Parse the constructor expression (which might have property/element access)
      match parse_postfix_expression(parser) {
        Ok((expr, parser)) => {
          let parser = decrement_depth(parser)
          // Check if there are explicit call arguments
          match current_token(parser) {
            OpenParen(_) => {
              // Has explicit arguments
              let parser = advance_parser(parser)
              let (arguments, parser) = parse_argument_list(parser)
              Ok(
                (
                  Node::NewExpression(NewExpression::{
                    expression: expr,
                    type_arguments: [],
                    arguments: Some(arguments),
                    location: start_loc,
                  }),
                  parser,
                ),
              )
            }
            _ =>
              // No arguments (e.g., new Date)
              Ok(
                (
                  Node::NewExpression(NewExpression::{
                    expression: expr,
                    type_arguments: [],
                    arguments: None,
                    location: start_loc,
                  }),
                  parser,
                ),
              )
          }
        }
        Err(parser) => {
          let parser = decrement_depth(parser)
          Err(parser)
        }
      }
    }
    _ =>
      // Not a new expression, check for other unary operators
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
      // Type arguments for generic calls (e.g., func<T>(...))
      LessThan(_) => {
        // Try to parse type arguments - if successful and followed by OpenParen, it's a generic call
        let saved_parser = parser
        match parse_type_argument_list(parser) {
          Ok((type_args, next_parser)) =>
            match current_token(next_parser) {
              OpenParen(_) => {
                // It's a generic function call
                let start_loc = get_location(left)
                parser = advance_parser(next_parser)
                let (arguments, next_parser) = parse_argument_list(parser)
                parser = next_parser
                left = Node::CallExpression(CallExpression::{
                  expression: left,
                  type_arguments: type_args,
                  arguments,
                  location: start_loc,
                })
              }
              _ => {
                // Not a generic call, backtrack - treat < as comparison
                parser = saved_parser
                should_continue = false
              }
            }
          Err(_) => {
            // Failed to parse type arguments, treat < as comparison
            parser = saved_parser
            should_continue = false
          }
        }
      }

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

      // Non-null assertion property access (obj!.property)
      ExclamationDot(_) => {
        let start_loc = get_location(left)
        parser = advance_parser(parser)
        // First wrap left in NonNullExpression
        let non_null_expr = Node::NonNullExpression(NonNullExpression::{
          expression: left,
          location: start_loc,
        })
        // Then parse the property access
        match parse_identifier(parser) {
          Ok((id, next_parser)) => {
            left = Node::PropertyAccessExpression(PropertyAccessExpression::{
              expression: non_null_expr,
              name: id.name,
              location: start_loc,
            })
            parser = next_parser
          }
          Err(p) => return Err(p)
        }
      }

      // Optional chaining - property access, call, or element access
      QuestionDot(_) => {
        let start_loc = get_location(left)
        parser = advance_parser(parser)
        match current_token(parser) {
          // Optional element access: obj?.[index]
          OpenBracket(_) => {
            parser = advance_parser(parser)
            parser = increment_depth(parser)
            match parse_expression(parser) {
              Ok((index, next_parser)) => {
                parser = decrement_depth(next_parser)
                match expect(parser, fn(t) { matches_close_bracket(t) }) {
                  Ok(p) => {
                    parser = advance_parser(p)
                    left = Node::OptionalChain(OptionalChain::{
                      expression: left,
                      chain: OptionalChainKind::Element(index),
                      location: start_loc,
                    })
                  }
                  Err(p) => return Err(p)
                }
              }
              Err(p) => return Err(decrement_depth(p))
            }
          }
          // Optional call: func?.()
          OpenParen(_) => {
            parser = advance_parser(parser)
            let (arguments, next_parser) = parse_argument_list(parser)
            parser = next_parser
            left = Node::OptionalChain(OptionalChain::{
              expression: left,
              chain: OptionalChainKind::Call(arguments),
              location: start_loc,
            })
          }
          // Optional property access: obj?.prop
          _ =>
            match parse_identifier(parser) {
              Ok((id, next_parser)) => {
                left = Node::OptionalChain(OptionalChain::{
                  expression: left,
                  chain: OptionalChainKind::Property(id.name),
                  location: start_loc,
                })
                parser = next_parser
              }
              Err(p) => return Err(p)
            }
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

      // Non-null assertion (!)
      Exclamation(_) => {
        let start_loc = get_location(left)
        parser = advance_parser(parser)
        left = Node::NonNullExpression(NonNullExpression::{
          expression: left,
          location: start_loc,
        })
      }

      // Type assertion with 'as' keyword (expr as Type) or (expr as const)
      KeywordAs(_) => {
        let start_loc = get_location(left)
        parser = advance_parser(parser)
        // Check for "as const" assertion
        match current_token(parser) {
          KeywordConst(loc) => {
            parser = advance_parser(parser)
            let type_node = Node::KeywordType(KeywordType::{
              kind: TypeKeyword::Const,
              location: loc,
            })
            left = Node::AsExpression(AsExpression::{
              expression: left,
              type_node,
              location: start_loc,
            })
          }
          _ =>
            match parse_type(parser) {
              Ok((type_node, next_parser)) => {
                left = Node::AsExpression(AsExpression::{
                  expression: left,
                  type_node,
                  location: start_loc,
                })
                parser = next_parser
              }
              Err(p) => return Err(p)
            }
        }
      }

      // Satisfies expression (expr satisfies Type)
      KeywordSatisfies(_) => {
        let start_loc = get_location(left)
        parser = advance_parser(parser)
        match parse_type(parser) {
          Ok((type_node, next_parser)) => {
            left = Node::SatisfiesExpression(SatisfiesExpression::{
              expression: left,
              type_node,
              location: start_loc,
            })
            parser = next_parser
          }
          Err(p) => return Err(p)
        }
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
              (
                Node::Identifier(Identifier::{ name, location: loc }),
                advance_parser(parser),
              ),
            )
        }
      } else {
        // Regular identifier (at end of tokens)
        Ok(
          (
            Node::Identifier(Identifier::{ name, location: loc }),
            advance_parser(parser),
          ),
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

    // BigInt literal
    BigIntLiteral(value, loc) =>
      Ok(
        (
          Node::BigIntLiteral(BigIntLiteral::{ value, location: loc }),
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

    // Template literal (simple - no interpolation)
    TemplateLiteral(value, loc) =>
      Ok(
        (
          Node::TemplateExpression(TemplateExpression::{
            head: value,
            template_spans: [],
            location: loc,
          }),
          advance_parser(parser),
        ),
      )

    // Template literal with interpolation
    TemplateHead(head, loc) => {
      let mut parser = advance_parser(parser)
      let template_spans : Array[TemplateSpan] = []
      while true {
        // Parse the interpolated expression
        let expr_start = current_token(parser).location()
        match parse_expression(parser) {
          Ok((expr, p)) => {
            parser = p
            // Expect CloseBrace
            match current_token(parser) {
              CloseBrace(_) => {
                parser = advance_parser(parser)
                // Check for TemplateTail or TemplateMiddle
                match current_token(parser) {
                  TemplateTail(tail_text, span_loc) => {
                    template_spans.push(TemplateSpan::{
                      expression: expr,
                      literal: tail_text,
                      location: span_loc,
                    })
                    parser = advance_parser(parser)
                    break
                  }
                  TemplateMiddle(middle_text, span_loc) => {
                    template_spans.push(TemplateSpan::{
                      expression: expr,
                      literal: middle_text,
                      location: span_loc,
                    })
                    parser = advance_parser(parser)
                    // Continue loop to parse next expression
                  }
                  _ =>
                    return Err(
                      add_error(
                        parser,
                        "Expected template continuation after }",
                        current_token(parser).location(),
                      ),
                    )
                }
              }
              _ =>
                return Err(
                  add_error(
                    parser,
                    "Expected '}' after expression in template literal",
                    current_token(parser).location(),
                  ),
                )
            }
          }
          Err(p) => return Err(p)
        }
      }
      Ok(
        (
          Node::TemplateExpression(TemplateExpression::{
            head,
            template_spans,
            location: loc,
          }),
          parser,
        ),
      )
    }

    // null
    KeywordNull(loc) =>
      Ok(
        (
          Node::NullLiteral(NullLiteral::{ location: loc }),
          advance_parser(parser),
        ),
      )

    // regex literal
    RegExpLiteral(pattern, loc) =>
      Ok(
        (
          Node::RegExpLiteral(RegExpLiteral::{ pattern, location: loc }),
          advance_parser(parser),
        ),
      )

    // undefined (as expression literal)
    KeywordUndefined(loc) =>
      Ok(
        (
          Node::Identifier(Identifier::{ name: "undefined", location: loc }),
          advance_parser(parser),
        ),
      )

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

    // new expression
    KeywordNew(start_loc) => {
      let parser = advance_parser(parser) // consume 'new'

      // Parse the constructor identifier (e.g., Foo)
      match current_token(parser) {
        Identifier(name, loc) => {
          let expr = Node::Identifier(Identifier::{ name, location: loc })
          let parser = advance_parser(parser) // consume identifier

          // Check for optional arguments
          match current_token(parser) {
            OpenParen(_) => {
              let parser = advance_parser(parser) // consume '('
              let parser = increment_depth(parser)

              // Parse arguments
              let (args, parser) = parse_argument_list(parser)
              let parser = decrement_depth(parser)
              match expect(parser, fn(t) { matches_close_paren(t) }) {
                Ok(parser) =>
                  Ok(
                    (
                      Node::NewExpression(NewExpression::{
                        expression: expr,
                        type_arguments: [],
                        arguments: Some(args),
                        location: start_loc,
                      }),
                      advance_parser(parser),
                    ),
                  )
                Err(parser) => Err(parser)
              }
            }
            _ =>
              // No arguments
              Ok(
                (
                  Node::NewExpression(NewExpression::{
                    expression: expr,
                    type_arguments: [],
                    arguments: None,
                    location: start_loc,
                  }),
                  parser,
                ),
              )
          }
        }
        _ =>
          Err(add_error(parser, "Expected identifier after 'new'", start_loc))
      }
    }

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

    // Function expression (e.g., function() {} or function foo() {})
    KeywordFunction(start_loc) => {
      let parser = advance_parser(parser) // consume 'function'

      // Optional function name
      let (name, parser) = match current_token(parser) {
        Identifier(fname, _) => (Some(fname), advance_parser(parser))
        _ => (None, parser)
      }
      parse_function_expression_body(parser, name, false, start_loc)
    }

    // JSX element or Type assertion with angle brackets (<Type>expr)
    LessThan(_) => {
      let start_loc = token.location()
      let saved_parser = parser

      // First check if it's a JSX element
      if is_jsx_start(parser) {
        return parse_jsx_element_or_fragment(parser)
      }

      // Otherwise try to parse as type assertion
      let mut parser = advance_parser(parser) // consume '<'
      match parse_type(parser) {
        Ok((type_node, next_parser)) =>
          match current_token(next_parser) {
            GreaterThan(_) => {
              parser = advance_parser(next_parser) // consume '>'

              // Parse the expression being asserted
              match parse_unary_expression(parser) {
                Ok((expr, next_parser)) =>
                  Ok(
                    (
                      Node::TypeAssertionExpression(TypeAssertionExpression::{
                        type_node,
                        expression: expr,
                        location: start_loc,
                      }),
                      next_parser,
                    ),
                  )
                Err(_) =>
                  // Failed to parse expression, backtrack
                  Err(saved_parser)
              }
            }
            _ =>
              // No closing >, not a type assertion, backtrack
              Err(saved_parser)
          }
        Err(_) =>
          // Failed to parse type, not a type assertion, backtrack
          Err(saved_parser)
      }
    }

    // Async function expression or async arrow function
    KeywordAsync(start_loc) => {
      let parser = advance_parser(parser) // consume 'async'
      match current_token(parser) {
        // async function expression
        KeywordFunction(_) => {
          let parser = advance_parser(parser) // consume 'function'
          // Optional function name
          let (name, parser) = match current_token(parser) {
            Identifier(fname, _) => (Some(fname), advance_parser(parser))
            _ => (None, parser)
          }
          parse_function_expression_body(parser, name, true, start_loc)
        }
        // async arrow function: async () => ... or async (params) => ...
        OpenParen(_) => parse_async_arrow_with_params(parser, start_loc)
        // async identifier => ... (single param arrow function)
        Identifier(name, loc) => {
          let parser = advance_parser(parser) // consume identifier
          parse_async_arrow_single_param(parser, name, loc, start_loc)
        }
        _ =>
          Err(
            add_error(
              parser,
              "Expected function or arrow function after 'async'",
              current_token(parser).location(),
            ),
          )
      }
    }
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

    // Check for spread operator
    let expr_result = match current_token(parser) {
      DotDotDot(loc) => {
        parser = advance_parser(parser) // consume ...
        match parse_assignment_expression(parser) {
          Ok((expr, p)) => {
            let spread_expr = Node::SpreadExpression(SpreadExpression::{
              expression: expr,
              location: loc,
            })
            Ok((spread_expr, p))
          }
          Err(p) => Err(p)
        }
      }
      _ => parse_assignment_expression(parser)
    }
    match expr_result {
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

  // Check for spread property or computed property
  match current_token(parser) {
    DotDotDot(_) => {
      let parser = advance_parser(parser) // consume ...
      match parse_assignment_expression(parser) {
        Ok((expr, parser)) =>
          Ok((ObjectProperty::SpreadAssignment(expr, start_loc), parser))
        Err(parser) => Err(parser)
      }
    }
    OpenBracket(_) => {
      // Computed property: [expression]: value
      let parser = advance_parser(parser) // consume [
      match parse_assignment_expression(parser) {
        Ok((name_expr, parser)) =>
          match current_token(parser) {
            CloseBracket(_) => {
              let parser = advance_parser(parser) // consume ]
              match current_token(parser) {
                Colon(_) => {
                  let parser = advance_parser(parser) // consume :
                  match parse_assignment_expression(parser) {
                    Ok((value, parser)) =>
                      Ok(
                        (
                          ObjectProperty::ComputedPropertyAssignment(
                            name_expr, value, start_loc,
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
                      "Expected ':' after computed property name",
                      current_token(parser).location(),
                    ),
                  )
              }
            }
            _ =>
              Err(
                add_error(
                  parser,
                  "Expected ']' after computed property name",
                  current_token(parser).location(),
                ),
              )
          }
        Err(parser) => Err(parser)
      }
    }
    StringLiteral(name, _) => {
      // String literal property name: "name": value or 'name': value
      let parser = advance_parser(parser) // consume string literal
      match current_token(parser) {
        Colon(_) => {
          let parser = advance_parser(parser) // consume :
          match parse_assignment_expression(parser) {
            Ok((value, parser)) =>
              Ok(
                (
                  ObjectProperty::PropertyAssignment(name, value, start_loc),
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
              "Expected ':' after string property name",
              current_token(parser).location(),
            ),
          )
      }
    }
    NumericLiteral(name, _) => {
      // Numeric literal property name: 0: value, 1: value
      let parser = advance_parser(parser) // consume numeric literal
      match current_token(parser) {
        Colon(_) => {
          let parser = advance_parser(parser) // consume :
          match parse_assignment_expression(parser) {
            Ok((value, parser)) =>
              Ok(
                (
                  ObjectProperty::PropertyAssignment(name, value, start_loc),
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
              "Expected ':' after numeric property name",
              current_token(parser).location(),
            ),
          )
      }
    }
    _ =>
      // Parse property name as identifier
      match parse_identifier(parser) {
        Ok((id, next_parser)) => {
          let parser = next_parser

          // Check for method, shorthand, or full property
          match current_token(parser) {
            OpenParen(_) => {
              // Method declaration: greet() { ... }
              let parser = advance_parser(parser) // consume (
              let (parameters, parser) = parse_parameter_list(parser)

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

              // Parse method body
              match parse_block_statement(parser) {
                Ok((body, parser)) => {
                  let func_expr = FunctionExpression::{
                    name: None,
                    type_parameters: [],
                    parameters,
                    return_type,
                    body,
                    is_async: false,
                    is_generator: false,
                    location: start_loc,
                  }
                  Ok(
                    (
                      ObjectProperty::MethodDeclaration(
                        id.name,
                        func_expr,
                        start_loc,
                      ),
                      parser,
                    ),
                  )
                }
                Err(parser) => Err(parser)
              }
            }
            Colon(_) => {
              let parser = advance_parser(parser)
              match parse_assignment_expression(parser) {
                Ok((value, parser)) =>
                  Ok(
                    (
                      ObjectProperty::PropertyAssignment(
                        id.name,
                        value,
                        start_loc,
                      ),
                      parser,
                    ),
                  )
                Err(parser) => Err(parser)
              }
            }
            _ =>
              // Shorthand property
              Ok(
                (ObjectProperty::ShorthandProperty(id.name, start_loc), parser),
              )
          }
        }
        Err(parser) => Err(parser)
      }
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
        modifiers: [],
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
