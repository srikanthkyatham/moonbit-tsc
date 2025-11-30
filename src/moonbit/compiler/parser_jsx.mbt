// JSX Parsing - Split from parser.mbt for better organization
// Contains all JSX-related parsing functions

///|
/// Extract identifier name from a token that can be used as JSX attribute name.
/// In JSX, keywords like `type`, `for`, `class` can be used as attribute names.
fn get_jsx_attribute_name_from_token(token : Token) -> (String, SourceLocation)? {
  match token {
    Identifier(name, loc) => Some((name, loc))
    // Type Keywords that can be JSX attribute names
    KeywordAny(loc) => Some(("any", loc))
    KeywordBoolean(loc) => Some(("boolean", loc))
    KeywordNumber(loc) => Some(("number", loc))
    KeywordString(loc) => Some(("string", loc))
    KeywordSymbol(loc) => Some(("symbol", loc))
    KeywordObject(loc) => Some(("object", loc))
    KeywordVoid(loc) => Some(("void", loc))
    KeywordUnknown(loc) => Some(("unknown", loc))
    KeywordNever(loc) => Some(("never", loc))
    KeywordUndefined(loc) => Some(("undefined", loc))
    KeywordNull(loc) => Some(("null", loc))
    // Declaration Keywords
    KeywordLet(loc) => Some(("let", loc))
    KeywordConst(loc) => Some(("const", loc))
    KeywordVar(loc) => Some(("var", loc))
    KeywordFunction(loc) => Some(("function", loc))
    KeywordClass(loc) => Some(("class", loc))
    KeywordInterface(loc) => Some(("interface", loc))
    KeywordEnum(loc) => Some(("enum", loc))
    KeywordType(loc) => Some(("type", loc))
    KeywordNamespace(loc) => Some(("namespace", loc))
    KeywordModule(loc) => Some(("module", loc))
    // Control Flow Keywords
    KeywordIf(loc) => Some(("if", loc))
    KeywordElse(loc) => Some(("else", loc))
    KeywordSwitch(loc) => Some(("switch", loc))
    KeywordCase(loc) => Some(("case", loc))
    KeywordDefault(loc) => Some(("default", loc))
    KeywordFor(loc) => Some(("for", loc))
    KeywordWhile(loc) => Some(("while", loc))
    KeywordDo(loc) => Some(("do", loc))
    KeywordBreak(loc) => Some(("break", loc))
    KeywordContinue(loc) => Some(("continue", loc))
    KeywordReturn(loc) => Some(("return", loc))
    KeywordThrow(loc) => Some(("throw", loc))
    KeywordTry(loc) => Some(("try", loc))
    KeywordCatch(loc) => Some(("catch", loc))
    KeywordFinally(loc) => Some(("finally", loc))
    // Modifier Keywords
    KeywordPublic(loc) => Some(("public", loc))
    KeywordPrivate(loc) => Some(("private", loc))
    KeywordProtected(loc) => Some(("protected", loc))
    KeywordStatic(loc) => Some(("static", loc))
    KeywordReadonly(loc) => Some(("readonly", loc))
    KeywordAbstract(loc) => Some(("abstract", loc))
    KeywordAsync(loc) => Some(("async", loc))
    KeywordAwait(loc) => Some(("await", loc))
    KeywordDeclare(loc) => Some(("declare", loc))
    KeywordAccessor(loc) => Some(("accessor", loc))
    KeywordUsing(loc) => Some(("using", loc))
    // Other Keywords
    KeywordNew(loc) => Some(("new", loc))
    KeywordThis(loc) => Some(("this", loc))
    KeywordSuper(loc) => Some(("super", loc))
    KeywordImport(loc) => Some(("import", loc))
    KeywordExport(loc) => Some(("export", loc))
    KeywordFrom(loc) => Some(("from", loc))
    KeywordAs(loc) => Some(("as", loc))
    KeywordSatisfies(loc) => Some(("satisfies", loc))
    KeywordExtends(loc) => Some(("extends", loc))
    KeywordImplements(loc) => Some(("implements", loc))
    KeywordYield(loc) => Some(("yield", loc))
    KeywordIn(loc) => Some(("in", loc))
    KeywordOf(loc) => Some(("of", loc))
    KeywordInstanceOf(loc) => Some(("instanceof", loc))
    KeywordTypeOf(loc) => Some(("typeof", loc))
    KeywordDelete(loc) => Some(("delete", loc))
    KeywordDebugger(loc) => Some(("debugger", loc))
    _ => None
  }
}

///|
/// Check if current position starts JSX element
/// Only returns true if JSX mode is enabled (for .tsx files)
fn is_jsx_start(parser : Parser) -> Bool {
  // Only parse JSX if explicitly in JSX mode
  if not(parser.context.in_jsx) {
    return false
  }
  match current_token(parser) {
    LessThan(_) => {
      // Check if it's JSX or less-than operator
      // JSX: <identifier, <>, </
      let next = peek_token(parser)
      match next {
        Identifier(_, _) => true
        GreaterThan(_) => true // Fragment <>
        Slash(_) => false // Not JSX (< /)
        LessThan(_) => false // Not JSX (<<)
        _ => false
      }
    }
    _ => false
  }
}

///|
/// Parse JSX element or fragment
fn parse_jsx_element_or_fragment(
  parser : Parser,
) -> Result[(Node, Parser), Parser] {
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume <
  match current_token(parser) {
    GreaterThan(_) =>
      // Fragment: <>...</>
      parse_jsx_fragment(parser, start_loc)
    Identifier(_, _) =>
      // Element: <tag>...</tag> or <tag />
      parse_jsx_element(parser, start_loc)
    _ =>
      Err(
        add_error_with_code(
          parser,
          UnexpectedToken.to_message(),
          start_loc,
          UnexpectedToken,
        ),
      )
  }
}

///|
/// Parse JSX element (after initial <)
fn parse_jsx_element(
  parser : Parser,
  start_loc : SourceLocation,
) -> Result[(Node, Parser), Parser] {
  // Parse tag name
  let (tag_name, parser) = match parse_jsx_tag_name(parser) {
    Ok((name, p)) => (name, p)
    Err(p) => return Err(p)
  }

  // Parse attributes
  let (attributes, parser) = parse_jsx_attributes(parser)
  match current_token(parser) {
    SlashGreaterThan(_) => {
      // Self-closing: <tag ... />
      let parser = advance_parser(parser)
      let end_loc = current_token(parser).location()
      Ok(
        (
          Node::JsxSelfClosingElement(JsxSelfClosingElement::{
            tag_name,
            type_arguments: [],
            attributes,
            location: SourceLocation::span(start_loc, end_loc),
          }),
          parser,
        ),
      )
    }
    GreaterThan(_) => {
      // Opening tag: <tag ...>
      let parser = advance_parser(parser)
      let opening = Node::JsxOpeningElement(JsxOpeningElement::{
        tag_name,
        type_arguments: [],
        attributes,
        location: start_loc,
      })

      // Parse children
      let (children, parser) = parse_jsx_children(parser)

      // Parse closing tag
      match parse_jsx_closing_element(parser, tag_name) {
        Ok((closing, parser)) => {
          let end_loc = get_location(closing)
          Ok(
            (
              Node::JsxElement(JsxElement::{
                opening_element: opening,
                children,
                closing_element: Some(closing),
                location: SourceLocation::span(start_loc, end_loc),
              }),
              parser,
            ),
          )
        }
        Err(p) => Err(p)
      }
    }
    _ =>
      Err(
        add_error_with_code(
          parser,
          UnexpectedToken.to_message(),
          start_loc,
          UnexpectedToken,
        ),
      )
  }
}

///|
/// Parse JSX tag name (identifier or member expression)
fn parse_jsx_tag_name(parser : Parser) -> Result[(JsxTagName, Parser), Parser] {
  let start_loc = current_token(parser).location()
  match current_token(parser) {
    Identifier(name, loc) => {
      let parser = advance_parser(parser)

      // Check for namespaced name: svg:rect
      match current_token(parser) {
        Colon(_) => {
          let parser = advance_parser(parser)
          match current_token(parser) {
            Identifier(local_name, _) => {
              let parser = advance_parser(parser)
              Ok((JsxTagName::NamespacedName(name, local_name, loc), parser))
            }
            _ =>
              Err(
                add_error_with_code(
                  parser,
                  ExpectedIdentifier.to_message(),
                  loc,
                  ExpectedIdentifier,
                ),
              )
          }
        }
        // Check for member expression: Module.Component
        Dot(_) => {
          let mut parser = parser
          let mut current_expr = Node::Identifier(Identifier::{
            name,
            location: loc,
          })
          while true {
            match current_token(parser) {
              Dot(_) => {
                parser = advance_parser(parser)
                match current_token(parser) {
                  Identifier(member_name, member_loc) => {
                    parser = advance_parser(parser)
                    current_expr = Node::PropertyAccessExpression(PropertyAccessExpression::{
                      expression: current_expr,
                      name: member_name,
                      location: member_loc,
                    })
                  }
                  _ =>
                    return Err(
                      add_error_with_code(
                        parser,
                        ExpectedIdentifier.to_message(),
                        loc,
                        ExpectedIdentifier,
                      ),
                    )
                }
              }
              _ => break
            }
          }
          Ok((JsxTagName::PropertyAccess(current_expr, "", loc), parser))
        }
        _ => Ok((JsxTagName::Identifier(name, loc), parser))
      }
    }
    _ =>
      Err(
        add_error_with_code(
          parser,
          ExpectedIdentifier.to_message(),
          start_loc,
          ExpectedIdentifier,
        ),
      )
  }
}

///|
/// Parse JSX attributes
fn parse_jsx_attributes(parser : Parser) -> (Array[JsxAttribute], Parser) {
  let attributes : Array[JsxAttribute] = []
  let mut parser = parser
  while !is_jsx_attribute_end(parser) {
    match current_token(parser) {
      // Spread attribute: {...props}
      OpenBrace(_) => {
        let loc = current_token(parser).location()
        parser = advance_parser(parser)
        match current_token(parser) {
          DotDotDot(_) => {
            parser = advance_parser(parser)
            match parse_expression(parser) {
              Ok((expr, p)) => {
                parser = p
                match current_token(parser) {
                  CloseBrace(_) => {
                    parser = advance_parser(parser)
                    attributes.push(JsxAttribute::SpreadAttribute(expr, loc))
                  }
                  _ => break
                }
              }
              Err(_) => break
            }
          }
          _ => break
        }
      }
      // Regular attribute: name="value" or name={expr}
      // Use helper to handle keywords as attribute names (e.g., type, for, class)
      _ =>
        match get_jsx_attribute_name_from_token(current_token(parser)) {
          Some((name, loc)) => {
            parser = advance_parser(parser)

            // Check for namespaced attribute: xlink:href
            let attr_name = match current_token(parser) {
              Colon(_) => {
                parser = advance_parser(parser)
                match get_jsx_attribute_name_from_token(current_token(parser)) {
                  Some((local_name, _)) => {
                    parser = advance_parser(parser)
                    JsxAttributeName::NamespacedName(name, local_name, loc)
                  }
                  None => JsxAttributeName::Identifier(name, loc)
                }
              }
              _ => JsxAttributeName::Identifier(name, loc)
            }

            // Check for value
            let initializer = match current_token(parser) {
              Equals(_) => {
                parser = advance_parser(parser)
                match parse_jsx_attribute_value(parser) {
                  Ok((value, p)) => {
                    parser = p
                    Some(value)
                  }
                  Err(_) => None
                }
              }
              _ => None // Boolean attribute like "disabled"
            }
            attributes.push(
              JsxAttribute::Attribute(JsxAttributeNode::{
                name: attr_name,
                initializer,
                location: loc,
              }),
            )
          }
          None => break
        }
    }
  }
  (attributes, parser)
}

///|
/// Check if we're at end of JSX attributes
fn is_jsx_attribute_end(parser : Parser) -> Bool {
  match current_token(parser) {
    GreaterThan(_) | SlashGreaterThan(_) | EOF(_) => true
    _ => false
  }
}

///|
/// Parse JSX attribute value
fn parse_jsx_attribute_value(
  parser : Parser,
) -> Result[(JsxAttributeValue, Parser), Parser] {
  let loc = current_token(parser).location()
  match current_token(parser) {
    // String value: "text"
    StringLiteral(value, _) => {
      let parser = advance_parser(parser)
      Ok((JsxAttributeValue::StringLiteral(value, loc), parser))
    }
    // Expression value: {expr}
    OpenBrace(_) => {
      let parser = advance_parser(parser)
      match parse_expression(parser) {
        Ok((expr, parser)) =>
          match current_token(parser) {
            CloseBrace(_) => {
              let parser = advance_parser(parser)
              Ok((JsxAttributeValue::Expression(expr, loc), parser))
            }
            _ =>
              Err(
                add_error_with_code(
                  parser,
                  ExpectedCloseBrace.to_message(),
                  loc,
                  ExpectedCloseBrace,
                ),
              )
          }
        Err(p) => Err(p)
      }
    }
    // Nested JSX element
    LessThan(_) =>
      match parse_jsx_element_or_fragment(parser) {
        Ok((element, parser)) =>
          Ok((JsxAttributeValue::Element(element, loc), parser))
        Err(p) => Err(p)
      }
    _ =>
      Err(
        add_error_with_code(
          parser,
          JSXExpectedAttributeValue.to_message(),
          loc,
          JSXExpectedAttributeValue,
        ),
      )
  }
}

///|
/// Parse JSX children
fn parse_jsx_children(parser : Parser) -> (Array[JsxChild], Parser) {
  let children : Array[JsxChild] = []
  let mut parser = parser
  while !is_jsx_children_end(parser) {
    let loc = current_token(parser).location()
    match current_token(parser) {
      // Nested element or fragment: <child>...</child> or <>...</>
      LessThan(_) => {
        // Check if it's closing tag
        let next = peek_token(parser)
        match next {
          Slash(_) => break // Closing tag, stop parsing children
          GreaterThan(_) =>
            // Fragment: <>...</>
            match parse_jsx_element_or_fragment(parser) {
              Ok((fragment, p)) => {
                parser = p
                children.push(JsxChild::Fragment(fragment, loc))
              }
              Err(p) => {
                parser = p
                break
              }
            }
          _ =>
            // Regular element: <tag>...</tag>
            match parse_jsx_element_or_fragment(parser) {
              Ok((element, p)) => {
                parser = p
                children.push(JsxChild::Element(element, loc))
              }
              Err(p) => {
                parser = p
                break
              }
            }
        }
      }
      // Expression: {expr}
      OpenBrace(_) => {
        parser = advance_parser(parser)

        // Check for empty expression {}
        match current_token(parser) {
          CloseBrace(_) => {
            parser = advance_parser(parser)
            children.push(
              JsxChild::Expression(JsxExpression::{
                expression: None,
                location: loc,
              }),
            )
          }
          _ =>
            match parse_expression(parser) {
              Ok((expr, p)) => {
                parser = p
                match current_token(parser) {
                  CloseBrace(_) => {
                    parser = advance_parser(parser)
                    children.push(
                      JsxChild::Expression(JsxExpression::{
                        expression: Some(expr),
                        location: loc,
                      }),
                    )
                  }
                  _ => break
                }
              }
              Err(_) => break
            }
        }
      }
      // Text content - handle identifiers and string literals as JSX text
      Identifier(text, _) => {
        children.push(JsxChild::Text(text, loc))
        parser = advance_parser(parser)
      }
      StringLiteral(text, _) => {
        children.push(JsxChild::Text(text, loc))
        parser = advance_parser(parser)
      }
      // Other tokens that could be text content
      _ => {
        // For other tokens, try to extract text representation
        let text = token_to_jsx_text(current_token(parser))
        if text.length() > 0 {
          children.push(JsxChild::Text(text, loc))
        }
        parser = advance_parser(parser)
      }
    }
  }
  (children, parser)
}

///|
/// Check if we're at end of JSX children
fn is_jsx_children_end(parser : Parser) -> Bool {
  match current_token(parser) {
    LessThanSlash(_) | EOF(_) => true
    LessThan(_) =>
      // Check if it's a closing tag
      match peek_token(parser) {
        Slash(_) => true
        _ => false
      }
    _ => false
  }
}

///|
/// Parse JSX closing element: </tag>
fn parse_jsx_closing_element(
  parser : Parser,
  expected_tag : JsxTagName,
) -> Result[(Node, Parser), Parser] {
  let start_loc = current_token(parser).location()

  // Expect </
  let parser = match current_token(parser) {
    LessThanSlash(_) => advance_parser(parser)
    LessThan(_) => {
      let parser = advance_parser(parser)
      match current_token(parser) {
        Slash(_) => advance_parser(parser)
        _ =>
          return Err(
            add_error_with_code(
              parser,
              JSXExpectedClosingTag.to_message(),
              start_loc,
              JSXExpectedClosingTag,
            ),
          )
      }
    }
    _ =>
      return Err(
        add_error_with_code(
          parser,
          JSXExpectedClosingTag.to_message(),
          start_loc,
          JSXExpectedClosingTag,
        ),
      )
  }

  // Parse tag name
  let (tag_name, parser) = match parse_jsx_tag_name(parser) {
    Ok((name, p)) => (name, p)
    Err(p) => return Err(p)
  }

  // Verify tag name matches
  if !jsx_tag_names_match(expected_tag, tag_name) {
    let parser = add_error_with_code(
      parser,
      JSXClosingTagMismatch.to_message(),
      start_loc,
      JSXClosingTagMismatch,
    )
    // Continue anyway to try to recover
    let _ = parser

  }

  // Expect >
  let parser = match current_token(parser) {
    GreaterThan(_) => advance_parser(parser)
    _ =>
      return Err(
        add_error_with_code(
          parser,
          UnexpectedToken.to_message(),
          start_loc,
          UnexpectedToken,
        ),
      )
  }
  let end_loc = current_token(parser).location()
  Ok(
    (
      Node::JsxClosingElement(JsxClosingElement::{
        tag_name,
        location: SourceLocation::span(start_loc, end_loc),
      }),
      parser,
    ),
  )
}

///|
/// Check if two JSX tag names match
fn jsx_tag_names_match(a : JsxTagName, b : JsxTagName) -> Bool {
  match (a, b) {
    (JsxTagName::Identifier(name_a, _), JsxTagName::Identifier(name_b, _)) =>
      name_a == name_b
    (
      JsxTagName::NamespacedName(ns_a, local_a, _),
      JsxTagName::NamespacedName(ns_b, local_b, _),
    ) => ns_a == ns_b && local_a == local_b
    _ => false // PropertyAccess comparison would need deeper check
  }
}

///|
/// Parse JSX fragment: <>...</>
fn parse_jsx_fragment(
  parser : Parser,
  start_loc : SourceLocation,
) -> Result[(Node, Parser), Parser] {
  // Already consumed <, expect >
  let parser = match current_token(parser) {
    GreaterThan(_) => advance_parser(parser)
    _ =>
      return Err(
        add_error_with_code(
          parser,
          UnexpectedToken.to_message(),
          start_loc,
          UnexpectedToken,
        ),
      )
  }
  let opening_loc = start_loc

  // Parse children
  let (children, parser) = parse_jsx_children(parser)

  // Expect </>
  let parser = match current_token(parser) {
    LessThanSlash(_) => advance_parser(parser)
    _ =>
      return Err(
        add_error_with_code(
          parser,
          JSXExpectedClosingTag.to_message(),
          start_loc,
          JSXExpectedClosingTag,
        ),
      )
  }
  let parser = match current_token(parser) {
    GreaterThan(_) => advance_parser(parser)
    _ =>
      return Err(
        add_error_with_code(
          parser,
          UnexpectedToken.to_message(),
          start_loc,
          UnexpectedToken,
        ),
      )
  }
  let closing_loc = current_token(parser).location()
  Ok(
    (
      Node::JsxFragment(JsxFragment::{
        opening_fragment: opening_loc,
        children,
        closing_fragment: closing_loc,
        location: SourceLocation::span(start_loc, closing_loc),
      }),
      parser,
    ),
  )
}

///|
/// Convert a token to JSX text representation
fn token_to_jsx_text(token : Token) -> String {
  match token {
    Identifier(text, _) => text
    StringLiteral(text, _) => text
    NumericLiteral(text, _) => text
    // Keywords that might appear as text
    KeywordNull(_) => "null"
    // Skip whitespace and punctuation that shouldn't be text
    _ => ""
  }
}
