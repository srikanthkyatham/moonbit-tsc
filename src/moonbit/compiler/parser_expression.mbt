// Expression Parsing - Split from parser.mbt for better organization
// Contains all expression-related parsing functions
// NOTE: Core expression logic moved to parser_v2_expression.mbt

///|
/// Parse an identifier or keyword as a property name for member access expressions.
/// This is necessary because in JavaScript/TypeScript, keywords can be used as property names.
/// For example: `field.type`, `field.string`, `obj.class` are all valid.
fn parse_identifier_or_keyword_name(
  parser : Parser,
) -> Result[(String, Parser), Parser] {
  let token = current_token(parser)
  let loc = token.location()
  match token {
    Identifier(name, _) => Ok((name, advance_parser(parser)))
    // Type keywords
    KeywordAny(_) => Ok(("any", advance_parser(parser)))
    KeywordBoolean(_) => Ok(("boolean", advance_parser(parser)))
    KeywordNumber(_) => Ok(("number", advance_parser(parser)))
    KeywordString(_) => Ok(("string", advance_parser(parser)))
    KeywordSymbol(_) => Ok(("symbol", advance_parser(parser)))
    KeywordObject(_) => Ok(("object", advance_parser(parser)))
    KeywordVoid(_) => Ok(("void", advance_parser(parser)))
    KeywordUnknown(_) => Ok(("unknown", advance_parser(parser)))
    KeywordNever(_) => Ok(("never", advance_parser(parser)))
    KeywordUndefined(_) => Ok(("undefined", advance_parser(parser)))
    KeywordNull(_) => Ok(("null", advance_parser(parser)))
    // Declaration keywords
    KeywordLet(_) => Ok(("let", advance_parser(parser)))
    KeywordConst(_) => Ok(("const", advance_parser(parser)))
    KeywordVar(_) => Ok(("var", advance_parser(parser)))
    KeywordFunction(_) => Ok(("function", advance_parser(parser)))
    KeywordClass(_) => Ok(("class", advance_parser(parser)))
    KeywordInterface(_) => Ok(("interface", advance_parser(parser)))
    KeywordEnum(_) => Ok(("enum", advance_parser(parser)))
    KeywordType(_) => Ok(("type", advance_parser(parser)))
    KeywordNamespace(_) => Ok(("namespace", advance_parser(parser)))
    KeywordModule(_) => Ok(("module", advance_parser(parser)))
    // Control flow keywords
    KeywordIf(_) => Ok(("if", advance_parser(parser)))
    KeywordElse(_) => Ok(("else", advance_parser(parser)))
    KeywordSwitch(_) => Ok(("switch", advance_parser(parser)))
    KeywordCase(_) => Ok(("case", advance_parser(parser)))
    KeywordDefault(_) => Ok(("default", advance_parser(parser)))
    KeywordFor(_) => Ok(("for", advance_parser(parser)))
    KeywordWhile(_) => Ok(("while", advance_parser(parser)))
    KeywordDo(_) => Ok(("do", advance_parser(parser)))
    KeywordBreak(_) => Ok(("break", advance_parser(parser)))
    KeywordContinue(_) => Ok(("continue", advance_parser(parser)))
    KeywordReturn(_) => Ok(("return", advance_parser(parser)))
    KeywordThrow(_) => Ok(("throw", advance_parser(parser)))
    KeywordTry(_) => Ok(("try", advance_parser(parser)))
    KeywordCatch(_) => Ok(("catch", advance_parser(parser)))
    KeywordFinally(_) => Ok(("finally", advance_parser(parser)))
    // Modifier keywords
    KeywordPublic(_) => Ok(("public", advance_parser(parser)))
    KeywordPrivate(_) => Ok(("private", advance_parser(parser)))
    KeywordProtected(_) => Ok(("protected", advance_parser(parser)))
    KeywordStatic(_) => Ok(("static", advance_parser(parser)))
    KeywordReadonly(_) => Ok(("readonly", advance_parser(parser)))
    KeywordAbstract(_) => Ok(("abstract", advance_parser(parser)))
    KeywordAsync(_) => Ok(("async", advance_parser(parser)))
    KeywordAwait(_) => Ok(("await", advance_parser(parser)))
    KeywordDeclare(_) => Ok(("declare", advance_parser(parser)))
    KeywordAccessor(_) => Ok(("accessor", advance_parser(parser)))
    KeywordUsing(_) => Ok(("using", advance_parser(parser)))
    // Other keywords
    KeywordNew(_) => Ok(("new", advance_parser(parser)))
    KeywordThis(_) => Ok(("this", advance_parser(parser)))
    KeywordSuper(_) => Ok(("super", advance_parser(parser)))
    KeywordImport(_) => Ok(("import", advance_parser(parser)))
    KeywordExport(_) => Ok(("export", advance_parser(parser)))
    KeywordFrom(_) => Ok(("from", advance_parser(parser)))
    KeywordAs(_) => Ok(("as", advance_parser(parser)))
    KeywordSatisfies(_) => Ok(("satisfies", advance_parser(parser)))
    KeywordExtends(_) => Ok(("extends", advance_parser(parser)))
    KeywordImplements(_) => Ok(("implements", advance_parser(parser)))
    KeywordYield(_) => Ok(("yield", advance_parser(parser)))
    KeywordIn(_) => Ok(("in", advance_parser(parser)))
    KeywordOf(_) => Ok(("of", advance_parser(parser)))
    KeywordInstanceOf(_) => Ok(("instanceof", advance_parser(parser)))
    KeywordTypeOf(_) => Ok(("typeof", advance_parser(parser)))
    KeywordDelete(_) => Ok(("delete", advance_parser(parser)))
    KeywordDebugger(_) => Ok(("debugger", advance_parser(parser)))
    // Private identifiers (ES2022 private class fields: #fieldName)
    PrivateIdentifier(name, _) => Ok((name, advance_parser(parser)))
    _ =>
      Err(
        add_error_with_code(
          parser,
          IdentifierExpected.to_message(),
          loc,
          IdentifierExpected,
        ),
      )
  }
}

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

  // Parse optional return type annotation (with backtrack on error)
  let (return_type, parser) = match current_token(parser) {
    Colon(_) => {
      let p = advance_parser(parser)
      match parse_type(p) {
        Ok((ty, p)) => (Some(ty), p)
        Err(_) => return Err(original_parser)
      }
    }
    _ => (None, parser)
  }

  // Expect arrow =>
  let parser = match current_token(parser) {
    Arrow(_) => advance_parser(parser)
    _ => return Err(original_parser)
  }

  // Parse body and create arrow function node
  match parse_arrow_body(parser) {
    Ok((body, parser)) =>
      Ok(
        (
          make_arrow_function(params, return_type, body, false, start_loc),
          parser,
        ),
      )
    Err(p) => Err(p)
  }
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

  // Create parameter and parse body
  match parse_arrow_body(parser) {
    Ok((body, parser)) =>
      Ok(
        (
          make_arrow_function(
            [make_simple_parameter(id)],
            None,
            body,
            false,
            start_loc,
          ),
          parser,
        ),
      )
    Err(p) => Err(p)
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
        // TS1227: A type assertion expression is not allowed in the
        // left-hand side of an exponentiation expression
        let next_parser = match (op, left) {
          (Exponentiate, Node::TypeAssertionExpression(t)) =>
            add_error_with_code(
              next_parser,
              TypeAssertionNotAllowedInExponentiation.to_message(),
              t.location,
              TypeAssertionNotAllowedInExponentiation,
            )
          (Exponentiate, Node::AsExpression(a)) =>
            add_error_with_code(
              next_parser,
              TypeAssertionNotAllowedInExponentiation.to_message(),
              a.location,
              TypeAssertionNotAllowedInExponentiation,
            )
          _ => next_parser
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
            (make_yield_expression(None, is_delegate, start_loc), parser),
          )
        }
        _ =>
          // Use parse_assignment_expression instead of parse_expression
          // to avoid consuming commas that belong to the enclosing context
          // (e.g., enum member lists, function arguments)
          match parse_assignment_expression(parser) {
            Ok((expr, parser)) => {
              let parser = decrement_depth(parser)
              return Ok(
                (
                  make_yield_expression(Some(expr), is_delegate, start_loc),
                  parser,
                ),
              )
            }
            Err(_) => {
              // No expression, that's okay for yield
              let parser = decrement_depth(parser)
              return Ok(
                (make_yield_expression(None, is_delegate, start_loc), parser),
              )
            }
          }
      }
    }
    _ => ()
  }

  // Check for "new" expression or new.target
  match token {
    KeywordNew(start_loc) => {
      let parser = advance_parser(parser)
      // Check for new.target meta property
      match current_token(parser) {
        Dot(_) => {
          let parser = advance_parser(parser) // consume '.'
          match current_token(parser) {
            Identifier(name, end_loc) if name == "target" => {
              let parser = advance_parser(parser) // consume 'target'
              Ok(
                (
                  Node::MetaProperty(MetaProperty::{
                    keyword_kind: NewTarget,
                    name: "target",
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
        _ => {
          // Regular new expression
          let parser = increment_depth(parser)
          // Parse the constructor expression (property/element access, but NOT calls)
          match parse_member_expression_for_new(parser) {
            Ok((expr, parser)) => {
              let parser = decrement_depth(parser)
              // Check if there are explicit call arguments
              let (new_expr, parser) = match current_token(parser) {
                OpenParen(_) => {
                  // Has explicit arguments
                  let parser = advance_parser(parser)
                  let (arguments, parser) = parse_argument_list(parser)
                  (make_new_expression(expr, Some(arguments), start_loc), parser)
                }
                _ =>
                  // No arguments (e.g., new Date)
                  (make_new_expression(expr, None, start_loc), parser)
              }
              // Continue parsing postfix operations (e.g., new Builder().append())
              continue_postfix_expression(parser, new_expr)
            }
            Err(parser) => {
              let parser = decrement_depth(parser)
              Err(parser)
            }
          }
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
              // TS1243: 'delete' cannot be called on an identifier in strict mode
              let parser = match (op, operand) {
                (Delete, Node::Identifier(ident)) =>
                  add_error_with_code(
                    parser,
                    DeleteCannotBeCalledOnIdentifier.to_message(),
                    ident.location,
                    DeleteCannotBeCalledOnIdentifier,
                  )
                _ => parser
              }
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
/// Parse template spans (the interpolated parts of a template literal)
/// This is used for templates like `head${expr1}middle${expr2}tail`
fn parse_template_spans(parser : Parser) -> Result[(Array[TemplateSpan], Parser), Parser] {
  let template_spans : Array[TemplateSpan] = []
  let mut current_parser = parser
  while true {
    // Parse the interpolated expression
    match parse_expression(current_parser) {
      Ok((expr, p)) => {
        current_parser = p
        // Expect CloseBrace
        match current_token(current_parser) {
          CloseBrace(_) => {
            current_parser = advance_parser(current_parser)
            // Check for TemplateTail or TemplateMiddle
            match current_token(current_parser) {
              TemplateTail(tail_text, span_loc) => {
                template_spans.push(TemplateSpan::{
                  expression: expr,
                  literal: tail_text,
                  location: span_loc,
                })
                current_parser = advance_parser(current_parser)
                break
              }
              TemplateMiddle(middle_text, span_loc) => {
                template_spans.push(TemplateSpan::{
                  expression: expr,
                  literal: middle_text,
                  location: span_loc,
                })
                current_parser = advance_parser(current_parser)
                // Continue loop to parse next expression
              }
              _ => return Err(add_error(current_parser, "Unexpected token", current_token(current_parser).location()))
            }
          }
          _ => return Err(add_error_with_code(current_parser, ExpectedCloseBrace.to_message(), current_token(current_parser).location(), ExpectedCloseBrace))
        }
      }
      Err(p) => return Err(p)
    }
  }
  Ok((template_spans, current_parser))
}

///|
/// Create a tagged template expression from a simple template literal (no interpolation)
fn make_simple_tagged_template(
  tag : Node,
  value : String,
  loc : SourceLocation,
  type_arguments : Array[Node],
  start_loc : SourceLocation,
) -> Node {
  let template = Node::TemplateExpression(TemplateExpression::{
    head: value,
    template_spans: [],
    location: loc,
  })
  Node::TaggedTemplateExpression(TaggedTemplateExpression::{
    tag,
    template,
    type_arguments,
    location: start_loc,
  })
}

///|
/// Create a tagged template expression from a template with interpolations
fn make_interpolated_tagged_template(
  tag : Node,
  head : String,
  template_spans : Array[TemplateSpan],
  loc : SourceLocation,
  type_arguments : Array[Node],
  start_loc : SourceLocation,
) -> Node {
  let template = Node::TemplateExpression(TemplateExpression::{
    head,
    template_spans,
    location: loc,
  })
  Node::TaggedTemplateExpression(TaggedTemplateExpression::{
    tag,
    template,
    type_arguments,
    location: start_loc,
  })
}

///|
/// Continue parsing postfix operations on an already-parsed expression
/// This handles method calls, property access, etc. starting from a given expression
fn continue_postfix_expression(
  parser : Parser,
  initial_expr : Node,
) -> Result[(Node, Parser), Parser] {
  let mut left = initial_expr
  let mut parser = parser
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
                left = make_call_expression(left, type_args, arguments, start_loc)
              }
              _ => {
                // Not a generic call, backtrack
                parser = saved_parser
                should_continue = false
              }
            }
          Err(_) => {
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
        left = make_call_expression(left, [], arguments, start_loc)
      }
      // Property access
      Dot(_) => {
        let start_loc = get_location(left)
        parser = advance_parser(parser)
        match parse_identifier_or_keyword_name(parser) {
          Ok((name, next_parser)) => {
            left = make_property_access(left, name, start_loc)
            parser = next_parser
          }
          Err(p) => return Err(p)
        }
      }
      // Element access
      OpenBracket(_) => {
        let start_loc = get_location(left)
        match parse_bracketed_expression(parser) {
          Ok((index, next_parser)) => {
            parser = next_parser
            left = make_element_access(left, index, start_loc)
          }
          Err(p) => return Err(p)
        }
      }
      // Optional chaining
      QuestionDot(_) => {
        let start_loc = get_location(left)
        parser = advance_parser(parser)
        match current_token(parser) {
          OpenBracket(_) =>
            match parse_bracketed_expression(parser) {
              Ok((index, next_parser)) => {
                parser = next_parser
                left = Node::OptionalChain(OptionalChain::{
                  expression: left,
                  chain: OptionalChainKind::Element(index),
                  location: start_loc,
                })
              }
              Err(p) => return Err(p)
            }
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
          _ =>
            match parse_identifier_or_keyword_name(parser) {
              Ok((name, next_parser)) => {
                left = Node::OptionalChain(OptionalChain::{
                  expression: left,
                  chain: OptionalChainKind::Property(name),
                  location: start_loc,
                })
                parser = next_parser
              }
              Err(p) => return Err(p)
            }
        }
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
      // Type assertion with 'as' keyword
      KeywordAs(_) => {
        let start_loc = get_location(left)
        parser = advance_parser(parser)
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
      _ => should_continue = false
    }
  }
  Ok((left, parser))
}

///|
/// Parse member expression for new expression target (property access, element access, but NOT calls)
/// This is used for parsing the target of `new` expressions
fn parse_member_expression_for_new(parser : Parser) -> Result[(Node, Parser), Parser] {
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
      // Property access
      Dot(_) => {
        let start_loc = get_location(left)
        parser = advance_parser(parser)
        match parse_identifier_or_keyword_name(parser) {
          Ok((name, next_parser)) => {
            left = make_property_access(left, name, start_loc)
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
        match parse_identifier_or_keyword_name(parser) {
          Ok((name, next_parser)) => {
            left = make_property_access(non_null_expr, name, start_loc)
            parser = next_parser
          }
          Err(p) => return Err(p)
        }
      }

      // Element access
      OpenBracket(_) => {
        let start_loc = get_location(left)
        match parse_bracketed_expression(parser) {
          Ok((index, next_parser)) => {
            parser = next_parser
            left = make_element_access(left, index, start_loc)
          }
          Err(p) => return Err(p)
        }
      }

      // Type arguments for generic tagged templates (e.g., tag<T>`template`)
      LessThan(_) => {
        // Try to parse type arguments - if successful and followed by template, it's a generic tagged template
        let saved_parser = parser
        match parse_type_argument_list(parser) {
          Ok((type_args, next_parser)) =>
            match current_token(next_parser) {
              // Tagged template with type arguments: tag<T>`template`
              TemplateLiteral(value, loc) => {
                let start_loc = get_location(left)
                parser = advance_parser(next_parser)
                left = make_simple_tagged_template(left, value, loc, type_args, start_loc)
              }
              // Tagged template with interpolation and type arguments: tag<T>`head${expr}...`
              TemplateHead(head, loc) => {
                let start_loc = get_location(left)
                parser = advance_parser(next_parser)
                match parse_template_spans(parser) {
                  Ok((template_spans, p)) => {
                    parser = p
                    left = make_interpolated_tagged_template(left, head, template_spans, loc, type_args, start_loc)
                  }
                  Err(p) => return Err(p)
                }
              }
              _ => {
                // Not a generic tagged template, backtrack
                parser = saved_parser
                should_continue = false
              }
            }
          Err(_) => {
            parser = saved_parser
            should_continue = false
          }
        }
      }

      // Tagged template literal: tag`template` (simple, no interpolation)
      TemplateLiteral(value, loc) => {
        let start_loc = get_location(left)
        parser = advance_parser(parser)
        left = make_simple_tagged_template(left, value, loc, [], start_loc)
      }

      // Tagged template with interpolation: tag`head${expr}...`
      TemplateHead(head, loc) => {
        let start_loc = get_location(left)
        parser = advance_parser(parser)
        match parse_template_spans(parser) {
          Ok((template_spans, p)) => {
            parser = p
            left = make_interpolated_tagged_template(left, head, template_spans, loc, [], start_loc)
          }
          Err(p) => return Err(p)
        }
      }

      // Stop at OpenParen (call arguments will be handled by new expression parser)
      // Stop at anything else
      _ => should_continue = false
    }
  }
  Ok((left, parser))
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
      // Type arguments for generic calls (e.g., func<T>(...)) or tagged templates (e.g., func<T>`...`)
      LessThan(_) => {
        // Try to parse type arguments - if successful and followed by OpenParen or template, it's a generic call
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
                left = make_call_expression(
                  left, type_args, arguments, start_loc,
                )
              }
              // Tagged template with type arguments: tag<T>`template`
              TemplateLiteral(value, loc) => {
                let start_loc = get_location(left)
                parser = advance_parser(next_parser)
                left = make_simple_tagged_template(left, value, loc, type_args, start_loc)
              }
              // Tagged template with interpolation and type arguments: tag<T>`head${expr}...`
              TemplateHead(head, loc) => {
                let start_loc = get_location(left)
                parser = advance_parser(next_parser)
                match parse_template_spans(parser) {
                  Ok((template_spans, p)) => {
                    parser = p
                    left = make_interpolated_tagged_template(left, head, template_spans, loc, type_args, start_loc)
                  }
                  Err(p) => return Err(p)
                }
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
        left = make_call_expression(left, [], arguments, start_loc)
      }

      // Property access
      Dot(_) => {
        let start_loc = get_location(left)
        parser = advance_parser(parser)
        match parse_identifier_or_keyword_name(parser) {
          Ok((name, next_parser)) => {
            left = make_property_access(left, name, start_loc)
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
        match parse_identifier_or_keyword_name(parser) {
          Ok((name, next_parser)) => {
            left = make_property_access(non_null_expr, name, start_loc)
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
          OpenBracket(_) =>
            match parse_bracketed_expression(parser) {
              Ok((index, next_parser)) => {
                parser = next_parser
                left = Node::OptionalChain(OptionalChain::{
                  expression: left,
                  chain: OptionalChainKind::Element(index),
                  location: start_loc,
                })
              }
              Err(p) => return Err(p)
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
            match parse_identifier_or_keyword_name(parser) {
              Ok((name, next_parser)) => {
                left = Node::OptionalChain(OptionalChain::{
                  expression: left,
                  chain: OptionalChainKind::Property(name),
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
        match parse_bracketed_expression(parser) {
          Ok((index, next_parser)) => {
            parser = next_parser
            left = make_element_access(left, index, start_loc)
          }
          Err(p) => return Err(p)
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

      // Tagged template literal: tag`template` or tag`head${expr}tail`
      TemplateLiteral(value, loc) => {
        let start_loc = get_location(left)
        parser = advance_parser(parser)
        left = make_simple_tagged_template(left, value, loc, [], start_loc)
      }

      // Tagged template with interpolation: tag`head${expr}...`
      TemplateHead(head, loc) => {
        let start_loc = get_location(left)
        parser = advance_parser(parser)
        match parse_template_spans(parser) {
          Ok((template_spans, p)) => {
            parser = p
            left = make_interpolated_tagged_template(left, head, template_spans, loc, [], start_loc)
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
    // Check for spread operator in argument
    let arg_result = match current_token(parser) {
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
    match arg_result {
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
      let parser = advance_parser(parser)
      match parse_template_spans(parser) {
        Ok((template_spans, p)) =>
          Ok(
            (
              Node::TemplateExpression(TemplateExpression::{
                head,
                template_spans,
                location: loc,
              }),
              p,
            ),
          )
        Err(p) => Err(p)
      }
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

    // new expression or new.target
    KeywordNew(start_loc) => {
      let parser = advance_parser(parser) // consume 'new'

      // Check for new.target
      match current_token(parser) {
        Dot(_) => {
          let parser = advance_parser(parser) // consume '.'
          match current_token(parser) {
            Identifier(name, end_loc) if name == "target" => {
              let parser = advance_parser(parser) // consume 'target'
              Ok(
                (
                  Node::MetaProperty(MetaProperty::{
                    keyword_kind: NewTarget,
                    name: "target",
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
        // Handle any valid expression for new target
        // This includes: Identifier, nested new, property access, templates, etc.
        _ =>
          // Use parse_member_expression_for_new to handle the full range of targets
          match parse_member_expression_for_new(parser) {
            Ok((expr, parser)) =>
              // Check for optional arguments
              match current_token(parser) {
                OpenParen(_) => {
                  let parser = advance_parser(parser) // consume '('
                  let parser = increment_depth(parser)
                  let (args, parser) = parse_argument_list(parser)
                  let parser = decrement_depth(parser)
                  // Note: parse_argument_list already consumes the closing ')'
                  Ok((make_new_expression(expr, Some(args), start_loc), parser))
                }
                _ =>
                  // No arguments
                  Ok((make_new_expression(expr, None, start_loc), parser))
              }
            Err(p) => Err(p)
          }
      }
    }

    // Parenthesized expression
    OpenParen(_) => {
      let start_loc = token.location()
      match parse_parenthesized_expression(parser) {
        Ok((expr, parser)) =>
          Ok(
            (
              Node::ParenthesizedExpression(ParenthesizedExpression::{
                expression: expr,
                location: start_loc,
              }),
              parser,
            ),
          )
        Err(p) => Err(p)
      }
    }

    // Array literal
    OpenBracket(_) => parse_array_literal(parser)

    // Object literal
    OpenBrace(_) => parse_object_literal(parser)

    // Function expression (e.g., function() {} or function foo() {})
    KeywordFunction(start_loc) => {
      let parser = advance_parser(parser) // consume 'function'
      let (name, parser) = parse_optional_function_name(parser)
      parse_function_expression_body(parser, name, false, start_loc)
    }

    // Class expression (e.g., class {} or class Foo {})
    KeywordClass(start_loc) => parse_class_expression(parser, start_loc)

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
          let (name, parser) = parse_optional_function_name(parser)
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
              "Unexpected token",
              current_token(parser).location(),
            ),
          )
      }
    }

    // Dynamic import expression: import('./module') or import.meta
    KeywordImport(start_loc) => {
      let parser = advance_parser(parser) // consume 'import'

      match current_token(parser) {
        // import.meta
        Dot(_) => {
          let parser = advance_parser(parser) // consume '.'
          match current_token(parser) {
            Identifier(name, end_loc) if name == "meta" => {
              let parser = advance_parser(parser) // consume 'meta'
              Ok(
                (
                  Node::MetaProperty(MetaProperty::{
                    keyword_kind: ImportMeta,
                    name: "meta",
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
        // Dynamic import: import('./module')
        OpenParen(_) => {
          let parser = advance_parser(parser) // consume '('

          // Parse the source expression (usually a string literal)
          match parse_assignment_expression(parser) {
            Ok((source, parser)) =>
              // Expect closing parenthesis
              match current_token(parser) {
                CloseParen(_) =>
                  Ok(
                    (
                      Node::ImportExpression(ImportExpression::{
                        source,
                        location: start_loc,
                      }),
                      advance_parser(parser),
                    ),
                  )
                _ =>
                  Err(
                    add_error_with_code(
                      parser,
                      ExpectedCloseParen.to_message(),
                      current_token(parser).location(),
                      ExpectedCloseParen,
                    ),
                  )
              }
            Err(p) => Err(p)
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

    // Module keyword used as identifier (e.g., module.exports in CommonJS)
    KeywordModule(loc) =>
      Ok(
        (
          Node::Identifier(Identifier::{ name: "module", location: loc }),
          advance_parser(parser),
        ),
      )

    // Declare keyword used as identifier (e.g., declare`template`)
    // This happens when declare is used as a function name with tagged template
    KeywordDeclare(loc) =>
      Ok(
        (
          Node::Identifier(Identifier::{ name: "declare", location: loc }),
          advance_parser(parser),
        ),
      )

    _ =>
      Err(
        add_error(
          parser,
          "Unexpected token",
          token.location(),
        ),
      )
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
              Err(
                add_error_with_code(
                  parser,
                  ExpectedCloseBracket.to_message(),
                  current_token(parser).location(),
                  ExpectedCloseBracket,
                ),
              )
          }
        Err(parser) => Err(parser)
      }
    }
    StringLiteral(name, _) => {
      // String literal property name: "name": value or 'name': value
      let parser = advance_parser(parser) // consume string literal
      parse_colon_property_value(
        parser, name, start_loc, "string property name",
      )
    }
    NumericLiteral(name, _) => {
      // Numeric literal property name: 0: value, 1: value
      let parser = advance_parser(parser) // consume numeric literal
      parse_colon_property_value(
        parser, name, start_loc, "numeric property name",
      )
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
              let (return_type, parser) = parse_optional_return_type(parser)

              // Parse method body (with in_function context for return statements)
              match parse_function_body(parser) {
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
  let (id, parser) = match parse_identifier(parser) {
    Ok((i, p)) => (i, p)
    Err(p) => return Err(p)
  }

  // Expect =>
  match expect(parser, fn(t) { matches_arrow(t) }) {
    Ok(parser) => {
      let parser = advance_parser(parser)
      match parse_arrow_body(parser) {
        Ok((body, parser)) =>
          Ok(
            (
              make_arrow_function(
                [make_simple_parameter(id)],
                None,
                body,
                false,
                start_loc,
              ),
              parser,
            ),
          )
        Err(p) => Err(p)
      }
    }
    Err(parser) => Err(parser)
  }
}

///|
/// Parse class expression (e.g., class {} or class Foo {})
fn parse_class_expression(
  parser : Parser,
  start_loc : SourceLocation,
) -> Result[(Node, Parser), Parser] {
  let parser = advance_parser(parser) // consume 'class'

  // Parse optional class name
  let (name, parser) = match current_token(parser) {
    Identifier(n, loc) =>
      (
        Some(Node::Identifier(Identifier::{ name: n, location: loc })),
        advance_parser(parser),
      )
    _ => (None, parser)
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
              Node::ClassExpression(ClassDeclaration::{
                name,
                type_parameters,
                heritage_clauses,
                members,
                is_abstract: false,
                decorators: [],
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
