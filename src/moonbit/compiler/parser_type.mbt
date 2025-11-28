// Type Parsing - Split from parser.mbt for better organization
// Contains all type-related parsing functions

///|
/// Parse type (enhanced with union support)
fn parse_type(parser : Parser) -> Result[(Node, Parser), Parser] {
  // Check for readonly modifier (readonly number[], readonly [T, U])
  let (is_readonly, parser) = match current_token(parser) {
    KeywordReadonly(_) => (true, advance_parser(parser))
    _ => (false, parser)
  }

  // Parse primary type with readonly context
  let result = parse_primary_type_with_readonly(parser, is_readonly)
  match result {
    Ok((type_node, parser)) => {
      // Check for array type syntax (type[]) and indexed access (type[K])
      let (type_node, parser) = parse_array_type_suffix_with_readonly(
        parser, type_node, is_readonly,
      )
      // Check for conditional type (T extends U ? X : Y)
      let result = parse_conditional_type(parser, type_node)
      match result {
        Ok((type_node, parser)) =>
          // Check for union/intersection type (|, &)
          parse_union_or_intersection_type(parser, type_node)
        Err(p) => Err(p)
      }
    }
    Err(p) => Err(p)
  }
}

///|
/// Parse array type suffix and indexed access type (handles type[], Type[K], etc.)
fn parse_array_type_suffix(parser : Parser, base_type : Node) -> (Node, Parser) {
  parse_array_type_suffix_with_readonly(parser, base_type, false)
}

///|
/// Parse array type suffix with readonly flag
fn parse_array_type_suffix_with_readonly(
  parser : Parser,
  base_type : Node,
  is_readonly : Bool,
) -> (Node, Parser) {
  let mut type_node = base_type
  let mut parser = parser
  let mut first_array = true
  while true {
    match current_token(parser) {
      OpenBracket(_) => {
        let start_loc = get_location(type_node)
        parser = advance_parser(parser)
        match current_token(parser) {
          CloseBracket(_) => {
            // Array type: Type[]
            parser = advance_parser(parser)
            // Only first array inherits readonly, nested arrays are not readonly by default
            let array_readonly = if first_array { is_readonly } else { false }
            first_array = false
            type_node = Node::ArrayType(ArrayType::{
              element_type: type_node,
              is_readonly: array_readonly,
              location: start_loc,
            })
          }
          _ =>
            // Indexed access type: Type[IndexType]
            match parse_type(parser) {
              Ok((index_type, p)) => {
                parser = p
                match current_token(parser) {
                  CloseBracket(_) => {
                    parser = advance_parser(parser)
                    type_node = Node::IndexedAccessType(IndexedAccessType::{
                      object_type: type_node,
                      index_type,
                      location: start_loc,
                    })
                  }
                  _ =>
                    // Not a valid indexed access, break
                    break
                }
              }
              Err(_) => break
            }
        }
      }
      _ => break
    }
  }
  (type_node, parser)
}

///|
/// Parse conditional type (T extends U ? X : Y)
fn parse_conditional_type(
  parser : Parser,
  check_type : Node,
) -> Result[(Node, Parser), Parser] {
  match current_token(parser) {
    KeywordExtends(_) => {
      let start_loc = get_location(check_type)
      let parser = advance_parser(parser) // consume 'extends'

      // Parse extends type
      match parse_primary_type(parser) {
        Ok((extends_type, parser)) => {
          let (extends_type, parser) = parse_array_type_suffix(
            parser, extends_type,
          )

          // Expect '?'
          match current_token(parser) {
            Question(_) => {
              let parser = advance_parser(parser)

              // Parse true type
              match parse_type(parser) {
                Ok((true_type, parser)) =>
                  // Expect ':'
                  match current_token(parser) {
                    Colon(_) => {
                      let parser = advance_parser(parser)

                      // Parse false type
                      match parse_type(parser) {
                        Ok((false_type, parser)) =>
                          Ok(
                            (
                              Node::ConditionalType(ConditionalType::{
                                check_type,
                                extends_type,
                                true_type,
                                false_type,
                                location: start_loc,
                              }),
                              parser,
                            ),
                          )
                        Err(p) => Err(p)
                      }
                    }
                    _ =>
                      // Not a conditional type, return check_type as-is
                      Ok((check_type, parser))
                  }
                Err(p) => Err(p)
              }
            }
            _ =>
              // No '?' after extends, not a conditional type
              // This might be a constraint in a generic type parameter context
              // Return the check_type as-is
              Ok((check_type, parser))
          }
        }
        Err(p) => Err(p)
      }
    }
    _ => Ok((check_type, parser))
  }
}

///|
/// Parse primary type
fn parse_primary_type(parser : Parser) -> Result[(Node, Parser), Parser] {
  parse_primary_type_with_readonly(parser, false)
}

///|
/// Parse primary type with readonly context for tuples
fn parse_primary_type_with_readonly(
  parser : Parser,
  is_readonly : Bool,
) -> Result[(Node, Parser), Parser] {
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
    KeywordVoid(_) =>
      Ok(
        (
          Node::KeywordType(KeywordType::{
            kind: TypeKeyword::Void,
            location: loc,
          }),
          advance_parser(parser),
        ),
      )
    KeywordUndefined(_) =>
      Ok(
        (
          Node::KeywordType(KeywordType::{
            kind: TypeKeyword::Undefined,
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
    KeywordNull(_) =>
      Ok(
        (
          Node::KeywordType(KeywordType::{
            kind: TypeKeyword::Null,
            location: loc,
          }),
          advance_parser(parser),
        ),
      )
    KeywordUnknown(_) =>
      Ok(
        (
          Node::KeywordType(KeywordType::{
            kind: TypeKeyword::Unknown,
            location: loc,
          }),
          advance_parser(parser),
        ),
      )
    KeywordNever(_) =>
      Ok(
        (
          Node::KeywordType(KeywordType::{
            kind: TypeKeyword::Never,
            location: loc,
          }),
          advance_parser(parser),
        ),
      )
    KeywordSymbol(_) =>
      Ok(
        (
          Node::KeywordType(KeywordType::{
            kind: TypeKeyword::Symbol,
            location: loc,
          }),
          advance_parser(parser),
        ),
      )
    KeywordObject(_) =>
      Ok(
        (
          Node::KeywordType(KeywordType::{
            kind: TypeKeyword::Object,
            location: loc,
          }),
          advance_parser(parser),
        ),
      )
    // typeof in type position: typeof variable
    KeywordTypeOf(_) => {
      let parser = advance_parser(parser)
      match current_token(parser) {
        Identifier(id_name, id_loc) => {
          let parser = advance_parser(parser)
          Ok(
            (
              Node::TypeOperator(TypeOperator::{
                operator: TypeOperatorKind::TypeOf,
                type_node: Node::Identifier(Identifier::{
                  name: id_name,
                  location: id_loc,
                }),
                location: loc,
              }),
              parser,
            ),
          )
        }
        _ =>
          Err(
            add_error(
              parser,
              "Expected identifier after 'typeof' in type position",
              current_token(parser).location(),
            ),
          )
      }
    }
    // readonly in type position: readonly T[]
    KeywordReadonly(_) => {
      let parser = advance_parser(parser)
      match parse_primary_type(parser) {
        Ok((operand_type, p)) =>
          Ok(
            (
              Node::TypeOperator(TypeOperator::{
                operator: TypeOperatorKind::Readonly,
                type_node: operand_type,
                location: loc,
              }),
              p,
            ),
          )
        Err(p) => Err(p)
      }
    }
    Identifier(name, _) if name == "true" || name == "false" => {
      // Boolean literal types
      let value = name == "true"
      Ok(
        (
          Node::LiteralType(LiteralType::{
            literal: Node::BooleanLiteral(BooleanLiteral::{
              value,
              location: loc,
            }),
            location: loc,
          }),
          advance_parser(parser),
        ),
      )
    }
    Identifier(name, _) =>
      // Check for type operators: keyof, unique, infer
      if name == "infer" {
        let parser = advance_parser(parser)
        // Parse type parameter name
        match current_token(parser) {
          Identifier(param_name, _) => {
            let parser = advance_parser(parser)
            Ok(
              (
                Node::InferType(InferType::{
                  type_parameter: param_name,
                  location: loc,
                }),
                parser,
              ),
            )
          }
          _ =>
            Err(
              add_error(
                parser,
                "Expected type parameter name after 'infer'",
                current_token(parser).location(),
              ),
            )
        }
      } else if name == "keyof" {
        let parser = advance_parser(parser)
        // Parse operand type
        match parse_primary_type(parser) {
          Ok((operand_type, p)) =>
            Ok(
              (
                Node::TypeOperator(TypeOperator::{
                  operator: TypeOperatorKind::KeyOf,
                  type_node: operand_type,
                  location: loc,
                }),
                p,
              ),
            )
          Err(p) => Err(p)
        }
      } else if name == "unique" {
        // unique symbol
        let parser = advance_parser(parser)
        // Expect symbol keyword or identifier "symbol"
        match current_token(parser) {
          KeywordSymbol(sym_loc) => {
            let parser = advance_parser(parser)
            Ok(
              (
                Node::TypeOperator(TypeOperator::{
                  operator: TypeOperatorKind::Unique,
                  type_node: Node::KeywordType(KeywordType::{
                    kind: TypeKeyword::Symbol,
                    location: sym_loc,
                  }),
                  location: loc,
                }),
                parser,
              ),
            )
          }
          Identifier(sym_name, sym_loc) if sym_name == "symbol" => {
            let parser = advance_parser(parser)
            Ok(
              (
                Node::TypeOperator(TypeOperator::{
                  operator: TypeOperatorKind::Unique,
                  type_node: Node::KeywordType(KeywordType::{
                    kind: TypeKeyword::Symbol,
                    location: sym_loc,
                  }),
                  location: loc,
                }),
                parser,
              ),
            )
          }
          _ =>
            // Just "unique" as a type reference
            Ok(
              (
                Node::TypeReference(TypeReference::{
                  type_name: name,
                  type_arguments: [],
                  location: loc,
                }),
                parser,
              ),
            )
        }
      } else if name == "typeof" {
        // typeof in type position: typeof variable
        let parser = advance_parser(parser)
        // Parse the expression/identifier being typeof'd
        match current_token(parser) {
          Identifier(id_name, id_loc) => {
            let parser = advance_parser(parser)
            Ok(
              (
                Node::TypeOperator(TypeOperator::{
                  operator: TypeOperatorKind::TypeOf,
                  type_node: Node::Identifier(Identifier::{
                    name: id_name,
                    location: id_loc,
                  }),
                  location: loc,
                }),
                parser,
              ),
            )
          }
          _ =>
            Err(
              add_error(
                parser,
                "Expected identifier after 'typeof' in type position",
                current_token(parser).location(),
              ),
            )
        }
      } else if name == "readonly" {
        // readonly type operator: readonly T[]
        let parser = advance_parser(parser)
        match parse_primary_type(parser) {
          Ok((operand_type, p)) =>
            Ok(
              (
                Node::TypeOperator(TypeOperator::{
                  operator: TypeOperatorKind::Readonly,
                  type_node: operand_type,
                  location: loc,
                }),
                p,
              ),
            )
          Err(p) => Err(p)
        }
      } else {
        let parser = advance_parser(parser)
        // Check for generic type arguments
        let (type_arguments, parser) = match current_token(parser) {
          LessThan(_) =>
            match parse_type_argument_list(parser) {
              Ok((args, p)) => (args, p)
              Err(p) => ([], p)
            }
          _ => ([], parser)
        }
        Ok(
          (
            Node::TypeReference(TypeReference::{
              type_name: name,
              type_arguments,
              location: loc,
            }),
            parser,
          ),
        )
      }
    StringLiteral(value, _) =>
      Ok(
        (
          Node::LiteralType(LiteralType::{
            literal: Node::StringLiteral(StringLiteral::{ value, location: loc }),
            location: loc,
          }),
          advance_parser(parser),
        ),
      )
    NumericLiteral(value, _) =>
      Ok(
        (
          Node::LiteralType(LiteralType::{
            literal: Node::NumericLiteral(NumericLiteral::{
              value,
              location: loc,
            }),
            location: loc,
          }),
          advance_parser(parser),
        ),
      )
    BigIntLiteral(value, _) =>
      Ok(
        (
          Node::LiteralType(LiteralType::{
            literal: Node::BigIntLiteral(BigIntLiteral::{ value, location: loc }),
            location: loc,
          }),
          advance_parser(parser),
        ),
      )
    // Template literal type without interpolation: `hello`
    TemplateLiteral(text, _) =>
      Ok(
        (
          Node::TemplateLiteralType(TemplateLiteralType::{
            head: text,
            spans: [],
            location: loc,
          }),
          advance_parser(parser),
        ),
      )
    // Template literal type with interpolation: `on${string}`
    TemplateHead(head, _) => {
      let mut parser = advance_parser(parser)
      let spans : Array[TemplateLiteralTypeSpan] = []
      while true {
        // Parse the type in the interpolation
        match parse_type(parser) {
          Ok((type_node, p)) => {
            parser = p
            // Expect CloseBrace
            match current_token(parser) {
              CloseBrace(_) => {
                parser = advance_parser(parser)
                // Check for TemplateTail or TemplateMiddle
                match current_token(parser) {
                  TemplateTail(tail_text, _) => {
                    spans.push(TemplateLiteralTypeSpan::{
                      type_node,
                      literal: tail_text,
                    })
                    parser = advance_parser(parser)
                    break
                  }
                  TemplateMiddle(middle_text, _) => {
                    spans.push(TemplateLiteralTypeSpan::{
                      type_node,
                      literal: middle_text,
                    })
                    parser = advance_parser(parser)
                    // Continue loop to parse next type
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
                    "Expected '}' after type in template literal type",
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
          Node::TemplateLiteralType(TemplateLiteralType::{
            head,
            spans,
            location: loc,
          }),
          parser,
        ),
      )
    }
    OpenBrace(_) => {
      let parser = advance_parser(parser) // consume {

      // Try to parse as mapped type: { [P in KeyType]: ValueType }
      // Also handles: { readonly [P in K]: V }, { [P in K]?: V }, { [P in K]-?: V }
      let mut parser = parser
      let saved_parser_start = parser

      // Check for readonly modifier: +readonly, -readonly, or readonly
      let readonly_modifier : MappedTypeModifier = match current_token(parser) {
        Plus(_) => {
          parser = advance_parser(parser)
          match current_token(parser) {
            KeywordReadonly(_) => {
              parser = advance_parser(parser)
              MappedTypeModifier::Plus
            }
            _ => MappedTypeModifier::Unchanged // Just a + without readonly, reset handled later
          }
        }
        Minus(_) => {
          parser = advance_parser(parser)
          match current_token(parser) {
            KeywordReadonly(_) => {
              parser = advance_parser(parser)
              MappedTypeModifier::Minus
            }
            _ => MappedTypeModifier::Unchanged // Just a - without readonly
          }
        }
        KeywordReadonly(_) => {
          parser = advance_parser(parser)
          MappedTypeModifier::Plus // readonly without +/- means add
        }
        _ => MappedTypeModifier::Unchanged
      }
      match current_token(parser) {
        OpenBracket(_) => {
          let saved_parser = parser
          parser = advance_parser(parser) // consume [

          // Check for mapped type pattern: identifier followed by 'in'
          match current_token(parser) {
            Identifier(param_name, param_loc) => {
              parser = advance_parser(parser)
              match current_token(parser) {
                KeywordIn(_) => {
                  // This is a mapped type!
                  parser = advance_parser(parser) // consume 'in'

                  // Parse the constraint type (e.g., keyof T)
                  match parse_type(parser) {
                    Ok((constraint_type, p)) => {
                      parser = p
                      // Expect ]
                      match current_token(parser) {
                        CloseBracket(_) => {
                          parser = advance_parser(parser)

                          // Check for optional modifier: ?, -?, +?
                          let optional_modifier : MappedTypeModifier = match
                            current_token(parser) {
                            Question(_) => {
                              parser = advance_parser(parser)
                              MappedTypeModifier::Plus // ? means add optional
                            }
                            Plus(_) => {
                              parser = advance_parser(parser)
                              // Expect ? after +
                              match current_token(parser) {
                                Question(_) => {
                                  parser = advance_parser(parser)
                                  MappedTypeModifier::Plus // +? adds optional
                                }
                                _ => MappedTypeModifier::Unchanged
                              }
                            }
                            Minus(_) => {
                              parser = advance_parser(parser)
                              // Expect ? after -
                              match current_token(parser) {
                                Question(_) => {
                                  parser = advance_parser(parser)
                                  MappedTypeModifier::Minus // -? removes optional
                                }
                                _ => MappedTypeModifier::Unchanged
                              }
                            }
                            _ => MappedTypeModifier::Unchanged
                          }

                          // Expect :
                          match current_token(parser) {
                            Colon(_) => {
                              parser = advance_parser(parser)
                              match parse_type(parser) {
                                Ok((value_type, p)) => {
                                  let final_parser = p
                                  // Optional semicolon
                                  let final_parser = match
                                    current_token(final_parser) {
                                    Semicolon(_) => advance_parser(final_parser)
                                    _ => final_parser
                                  }
                                  // Expect }
                                  match current_token(final_parser) {
                                    CloseBrace(_) => {
                                      let final_parser = advance_parser(
                                        final_parser,
                                      )
                                      return Ok(
                                        (
                                          Node::MappedType(MappedType::{
                                            type_parameter: TypeParameter::{
                                              name: param_name,
                                              constraint: Some(constraint_type),
                                              default: None,
                                              is_const: false,
                                              location: param_loc,
                                            },
                                            type_node: Some(value_type),
                                            readonly_modifier,
                                            optional_modifier,
                                            location: loc,
                                          }),
                                          final_parser,
                                        ),
                                      )
                                    }
                                    _ =>
                                      // Failed, reset
                                      parser = saved_parser_start
                                  }
                                }
                                Err(_) => parser = saved_parser_start
                              }
                            }
                            _ => parser = saved_parser_start
                          }
                        }
                        _ => parser = saved_parser
                      }
                    }
                    Err(_) => parser = saved_parser_start
                  }
                }
                _ => parser = saved_parser_start
              }
            }
            _ => parser = saved_parser_start
          }
        }
        _ => parser = saved_parser_start
      }

      // Parse as regular object type literal: { prop: type, ... }
      let properties = []
      let mut parser = parser
      while true {
        match current_token(parser) {
          CloseBrace(_) => {
            parser = advance_parser(parser)
            break
          }
          Identifier(name, _) => {
            parser = advance_parser(parser)
            // Check for optional property marker (?)
            match current_token(parser) {
              Question(_) =>
                // Optional property - consume ?
                parser = advance_parser(parser)
              _ => ()
            }
            // Expect :
            match current_token(parser) {
              Colon(_) => {
                parser = advance_parser(parser)
                match parse_type(parser) {
                  Ok((prop_type, p)) => {
                    properties.push((name, prop_type))
                    parser = p
                    // Optional comma or semicolon
                    match current_token(parser) {
                      Comma(_) | Semicolon(_) => parser = advance_parser(parser)
                      _ => ()
                    }
                  }
                  Err(p) => return Err(p)
                }
              }
              _ => break
            }
          }
          // Handle call signature: (): type
          OpenParen(_) => {
            let call_start = current_token(parser).location()
            parser = advance_parser(parser)
            let (params, p) = parse_parameter_list(parser)
            parser = p
            // Expect :
            match current_token(parser) {
              Colon(_) => {
                parser = advance_parser(parser)
                match parse_type(parser) {
                  Ok((return_type, p)) => {
                    let _ = params
                    let _ = return_type
                    let _ = call_start
                    // For now, just skip call signatures
                    parser = p
                    // Optional semicolon
                    match current_token(parser) {
                      Semicolon(_) => parser = advance_parser(parser)
                      _ => ()
                    }
                  }
                  Err(p) => return Err(p)
                }
              }
              _ => break
            }
          }
          // Handle construct signature: new(): type
          KeywordNew(_) => {
            parser = advance_parser(parser)
            match current_token(parser) {
              OpenParen(_) => {
                parser = advance_parser(parser)
                let (params, p) = parse_parameter_list(parser)
                parser = p
                // Expect :
                match current_token(parser) {
                  Colon(_) => {
                    parser = advance_parser(parser)
                    match parse_type(parser) {
                      Ok((return_type, p)) => {
                        let _ = params
                        let _ = return_type
                        // For now, just skip construct signatures
                        parser = p
                        // Optional semicolon
                        match current_token(parser) {
                          Semicolon(_) => parser = advance_parser(parser)
                          _ => ()
                        }
                      }
                      Err(p) => return Err(p)
                    }
                  }
                  _ => break
                }
              }
              _ => break
            }
          }
          _ => break
        }
      }

      // For now, return a simple type reference representing the object type
      // A full implementation would create a proper ObjectType node
      Ok(
        (
          Node::TypeReference(TypeReference::{
            type_name: "object",
            type_arguments: [],
            location: loc,
          }),
          parser,
        ),
      )
    }
    OpenParen(_) => {
      // Function type: (param: type, ...) => returnType
      let parser = advance_parser(parser) // consume '('
      let (parameters, parser) = parse_parameter_list(parser)

      // Expect =>
      match current_token(parser) {
        Arrow(_) => {
          let parser = advance_parser(parser)
          match parse_type(parser) {
            Ok((return_type, parser)) =>
              Ok(
                (
                  Node::FunctionType(FunctionType::{
                    type_parameters: [],
                    parameters,
                    return_type,
                    location: loc,
                  }),
                  parser,
                ),
              )
            Err(p) => Err(p)
          }
        }
        _ =>
          Err(
            add_error(
              parser,
              "Expected '=>' in function type",
              current_token(parser).location(),
            ),
          )
      }
    }
    OpenBracket(_) => {
      // Tuple type: [type1, type2, ...] or [name: type1, name2: type2, ...]
      // Also supports optional elements (type?) and rest elements (...type[])
      let parser = advance_parser(parser) // consume '['
      let element_types = []
      let mut parser = parser
      while true {
        match current_token(parser) {
          CloseBracket(_) => {
            parser = advance_parser(parser)
            break
          }
          _ => {
            // Check for rest element: ...type
            let is_rest = match current_token(parser) {
              DotDotDot(_) => {
                parser = advance_parser(parser)
                true
              }
              _ => false
            }

            // Parse type (ignoring optional name: prefix for now)
            let (elem_type, new_parser) = match current_token(parser) {
              Identifier(_, _) => {
                // Could be "name: type" or just a type reference
                let saved_parser = parser
                parser = advance_parser(parser)
                match current_token(parser) {
                  Colon(_) => {
                    // It's a named tuple element, skip the name and parse the type
                    parser = advance_parser(parser)
                    match parse_type(parser) {
                      Ok((t, p)) => (t, p)
                      Err(p) => return Err(p)
                    }
                  }
                  Question(_) => {
                    // named?: type - named optional element
                    parser = advance_parser(parser) // consume ?
                    match current_token(parser) {
                      Colon(_) => {
                        parser = advance_parser(parser)
                        match parse_type(parser) {
                          Ok((t, p)) => {
                            let opt_type = Node::OptionalType(OptionalType::{
                              element_type: t,
                              location: get_location(t),
                            })
                            (opt_type, p)
                          }
                          Err(p) => return Err(p)
                        }
                      }
                      _ => {
                        // Backtrack - just identifier followed by ?
                        parser = saved_parser
                        match parse_type(parser) {
                          Ok((t, p)) => (t, p)
                          Err(p) => return Err(p)
                        }
                      }
                    }
                  }
                  _ => {
                    // It's just a type reference, backtrack
                    parser = saved_parser
                    match parse_type(parser) {
                      Ok((t, p)) => (t, p)
                      Err(p) => return Err(p)
                    }
                  }
                }
              }
              _ =>
                match parse_type(parser) {
                  Ok((t, p)) => (t, p)
                  Err(p) => return Err(p)
                }
            }
            parser = new_parser

            // Check for optional element: type?
            let elem_type = match current_token(parser) {
              Question(_) => {
                parser = advance_parser(parser)
                Node::OptionalType(OptionalType::{
                  element_type: elem_type,
                  location: get_location(elem_type),
                })
              }
              _ => elem_type
            }

            // Wrap in RestType if is_rest
            let elem_type = if is_rest {
              Node::RestType(RestType::{
                element_type: elem_type,
                location: get_location(elem_type),
              })
            } else {
              elem_type
            }
            element_types.push(elem_type)

            // Optional comma
            match current_token(parser) {
              Comma(_) => parser = advance_parser(parser)
              CloseBracket(_) => () // Will be handled in next iteration
              _ => ()
            }
          }
        }
      }
      Ok(
        (
          Node::TupleType(TupleType::{
            element_types,
            is_readonly,
            location: loc,
          }),
          parser,
        ),
      )
    }
    _ => Err(add_error(parser, "Expected type", loc))
  }
}

///|
/// Parse union or intersection type
fn parse_union_or_intersection_type(
  parser : Parser,
  first_type : Node,
) -> Result[(Node, Parser), Parser] {
  let token = current_token(parser)
  match token {
    Bar(_) => {
      // Union type: type1 | type2 | type3
      let types = [first_type]
      let mut parser = parser
      while true {
        match current_token(parser) {
          Bar(_) => {
            parser = advance_parser(parser) // consume |
            match parse_primary_type(parser) {
              Ok((type_node, p)) => {
                types.push(type_node)
                parser = p
              }
              Err(p) => return Err(p)
            }
          }
          _ => break
        }
      }
      let loc = match first_type {
        Node::KeywordType(kt) => kt.location
        Node::TypeReference(tr) => tr.location
        _ =>
          {
            start: { line: 0, column: 0, offset: 0 },
            end: { line: 0, column: 0, offset: 0 },
            file_path: "",
          }
      }
      Ok((Node::UnionType(UnionType::{ types, location: loc }), parser))
    }
    Ampersand(_) => {
      // Intersection type: type1 & type2 & type3
      let types = [first_type]
      let mut parser = parser
      while true {
        match current_token(parser) {
          Ampersand(_) => {
            parser = advance_parser(parser) // consume &
            match parse_primary_type(parser) {
              Ok((type_node, p)) => {
                types.push(type_node)
                parser = p
              }
              Err(p) => return Err(p)
            }
          }
          _ => break
        }
      }
      let loc = match first_type {
        Node::KeywordType(kt) => kt.location
        Node::TypeReference(tr) => tr.location
        _ =>
          {
            start: { line: 0, column: 0, offset: 0 },
            end: { line: 0, column: 0, offset: 0 },
            file_path: "",
          }
      }
      Ok(
        (
          Node::IntersectionType(IntersectionType::{ types, location: loc }),
          parser,
        ),
      )
    }
    _ => Ok((first_type, parser)) // Not a union or intersection, return original type
  }
}
