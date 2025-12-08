// Type Parsing - Split from parser.mbt for better organization
// Contains all type-related parsing functions

///|
/// Try to extract a property name from a token.
/// This handles identifiers, string literals, and keywords that can be used as property names.
/// Returns None if the token cannot be used as a property name.
fn try_get_property_name(token : Token) -> (String, SourceLocation)? {
  match token {
    Identifier(name, loc) => Some((name, loc))
    StringLiteral(name, loc) => Some((name, loc))
    // Type keywords
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
    // Declaration keywords
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
    // Control flow keywords
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
    // Modifier keywords
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
    // Other keywords
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
      OpenBracket(bracket_loc) => {
        // Check for ASI (Automatic Semicolon Insertion) context:
        // If [ is on a different line than the base type, it might be a new statement/member
        // rather than an array/indexed access suffix
        let type_loc = get_location(type_node)
        if bracket_loc.start.line != type_loc.end.line {
          // [ is on a different line - treat it as a new member, not array suffix
          // This handles cases like:
          //   foo(): void
          //   [x: number]: I;
          // where [x: number] is an index signature, not void[x: number]
          break
        }
        let start_loc = type_loc
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
    KeywordBigInt(_) =>
      Ok(
        (
          Node::KeywordType(KeywordType::{
            kind: TypeKeyword::BigInt,
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
    // typeof in type position: typeof variable or typeof A.B.C
    KeywordTypeOf(_) => {
      let parser = advance_parser(parser)
      // Handle identifiers and contextual keywords like 'yield' that can be variable names
      match try_get_identifier_name(current_token(parser)) {
        Some((id_name, id_loc)) => {
          let mut parser = advance_parser(parser)
          let mut result : Node = Node::Identifier(Identifier::{
            name: id_name,
            location: id_loc,
          })
          // Parse any following .identifier chains (for typeof Symbol.obs)
          while true {
            match current_token(parser) {
              Dot(_) => {
                parser = advance_parser(parser) // consume '.'
                match current_token(parser) {
                  Identifier(prop_name, prop_loc) => {
                    parser = advance_parser(parser)
                    let start_loc = get_node_location(result)
                    result = Node::PropertyAccessExpression(
                      PropertyAccessExpression::{
                        expression: result,
                        name: prop_name,
                        location: SourceLocation::new(
                          start_loc.file_path,
                          start_loc.start,
                          prop_loc.end,
                        ),
                      },
                    )
                  }
                  _ => break
                }
              }
              _ => break
            }
          }
          Ok(
            (
              Node::TypeOperator(TypeOperator::{
                operator: TypeOperatorKind::TypeOf,
                type_node: result,
                location: loc,
              }),
              parser,
            ),
          )
        }
        None =>
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
        // typeof in type position: typeof variable or typeof A.B.C
        let parser = advance_parser(parser)
        // Parse the expression/identifier being typeof'd
        // Handle identifiers and contextual keywords like 'yield' that can be variable names
        match try_get_identifier_name(current_token(parser)) {
          Some((id_name, id_loc)) => {
            let mut parser = advance_parser(parser)
            let mut result : Node = Node::Identifier(Identifier::{
              name: id_name,
              location: id_loc,
            })
            // Parse any following .identifier chains (for typeof Symbol.obs)
            while true {
              match current_token(parser) {
                Dot(_) => {
                  parser = advance_parser(parser) // consume '.'
                  match current_token(parser) {
                    Identifier(prop_name, prop_loc) => {
                      parser = advance_parser(parser)
                      let start_loc = get_node_location(result)
                      result = Node::PropertyAccessExpression(
                        PropertyAccessExpression::{
                          expression: result,
                          name: prop_name,
                          location: SourceLocation::new(
                            start_loc.file_path,
                            start_loc.start,
                            prop_loc.end,
                          ),
                        },
                      )
                    }
                    _ => break
                  }
                }
                _ => break
              }
            }
            Ok(
              (
                Node::TypeOperator(TypeOperator::{
                  operator: TypeOperatorKind::TypeOf,
                  type_node: result,
                  location: loc,
                }),
                parser,
              ),
            )
          }
          None =>
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
        let mut parser = advance_parser(parser)
        let mut qualified_name = name

        // Handle qualified names like Foo.Bar.Baz
        while true {
          match current_token(parser) {
            Dot(_) => {
              // Check if next token is an identifier
              let next_parser = advance_parser(parser)
              match current_token(next_parser) {
                Identifier(next_name, _) => {
                  qualified_name = qualified_name + "." + next_name
                  parser = advance_parser(next_parser)
                }
                _ => break
              }
            }
            _ => break
          }
        }

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
              type_name: qualified_name,
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

                      // Check for 'as' clause (key remapping)
                      // e.g., { [K in keyof T as `get${K}`]: V }
                      let name_type : Node? = match current_token(parser) {
                        KeywordAs(_) => {
                          parser = advance_parser(parser) // consume 'as'
                          match parse_type(parser) {
                            Ok((nt, p2)) => {
                              parser = p2
                              Some(nt)
                            }
                            Err(_) => None
                          }
                        }
                        _ => None
                      }

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
                                            name_type,
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

      // Parse as regular object type literal: { prop: type, [key: string]: type, ... }
      let members : Array[Node] = []
      let mut parser = parser
      while true {
        let member_loc = current_token(parser).location()
        match current_token(parser) {
          CloseBrace(_) => {
            parser = advance_parser(parser)
            break
          }
          // Handle index signature or computed property: [key: string]: type OR [Symbol.iterator]: type
          OpenBracket(_) => {
            parser = advance_parser(parser)

            // Check if this is an index signature or computed property
            // Index signature: [identifier: Type]: ValueType
            // Computed property: [expression]: Type
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
              match current_token(parser) {
                Identifier(param_name, _) => {
                  parser = advance_parser(parser)
                  // Expect :
                  match current_token(parser) {
                    Colon(_) => {
                      parser = advance_parser(parser)
                      // Parse key type (string or number)
                      match parse_type(parser) {
                        Ok((key_type, p)) => {
                          parser = p
                          // Expect ]
                          match current_token(parser) {
                            CloseBracket(_) => {
                              parser = advance_parser(parser)
                              // Expect :
                              match current_token(parser) {
                                Colon(_) => {
                                  parser = advance_parser(parser)
                                  // Parse value type
                                  match parse_type(parser) {
                                    Ok((value_type, p)) => {
                                      members.push(
                                        Node::IndexSignatureDeclaration(IndexSignatureDeclaration::{
                                          parameter_name: param_name,
                                          parameter_type: key_type,
                                          return_type: value_type,
                                          is_readonly: false,
                                          location: member_loc,
                                        }),
                                      )
                                      parser = p
                                      // Optional comma or semicolon
                                      match current_token(parser) {
                                        Comma(_) | Semicolon(_) =>
                                          parser = advance_parser(parser)
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
                        Err(p) => return Err(p)
                      }
                    }
                    _ => break
                  }
                }
                _ => break
              }
            } else {
              // Computed property: [expression]: Type
              // Parse the computed property name expression
              let (_computed_name, p) = match
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

              // Expect colon for computed property type
              match current_token(parser) {
                Colon(_) => {
                  parser = advance_parser(parser)
                  match parse_type(parser) {
                    Ok((prop_type, p)) => {
                      parser = p
                      let prop_name = "[computed]"
                      members.push(
                        Node::TypeLiteralProperty(TypeLiteralProperty::{
                          name: prop_name,
                          type_node: Some(prop_type),
                          is_optional,
                          is_readonly: false,
                          location: member_loc,
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
          // Handle construct signature: new(): type or new <T>(): type
          KeywordNew(_) => {
            parser = advance_parser(parser)
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
                // Expect :
                match current_token(parser) {
                  Colon(_) => {
                    parser = advance_parser(parser)
                    match parse_type(parser) {
                      Ok((return_type, p)) => {
                        // Create a MethodDeclaration with name "new" for construct signature
                        members.push(
                          Node::MethodDeclaration(MethodDeclaration::{
                            name: "new",
                            parameters: params,
                            return_type: Some(return_type),
                            body: None,
                            type_parameters: type_params,
                            decorators: [],
                            modifiers: [],
                            is_optional: false,
                            is_async: false,
                            is_generator: false,
                            location: member_loc,
                          }),
                        )
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
          // Handle readonly modifier
          KeywordReadonly(_) => {
            parser = advance_parser(parser)
            match current_token(parser) {
              // readonly [key: string]: type OR readonly [Symbol.iterator]: type
              OpenBracket(_) => {
                parser = advance_parser(parser)

                // Check if this is an index signature or computed property
                let is_index_signature = match current_token(parser) {
                  Identifier(_, _) => {
                    let next_parser = advance_parser(parser)
                    match current_token(next_parser) {
                      Colon(_) => true
                      _ => false
                    }
                  }
                  _ => false
                }
                if is_index_signature {
                  // readonly index signature
                  match current_token(parser) {
                    Identifier(param_name, _) => {
                      parser = advance_parser(parser)
                      match current_token(parser) {
                        Colon(_) => {
                          parser = advance_parser(parser)
                          match parse_type(parser) {
                            Ok((key_type, p)) => {
                              parser = p
                              match current_token(parser) {
                                CloseBracket(_) => {
                                  parser = advance_parser(parser)
                                  match current_token(parser) {
                                    Colon(_) => {
                                      parser = advance_parser(parser)
                                      match parse_type(parser) {
                                        Ok((value_type, p)) => {
                                          members.push(
                                            Node::IndexSignatureDeclaration(IndexSignatureDeclaration::{
                                              parameter_name: param_name,
                                              parameter_type: key_type,
                                              return_type: value_type,
                                              is_readonly: true,
                                              location: member_loc,
                                            }),
                                          )
                                          parser = p
                                          match current_token(parser) {
                                            Comma(_) | Semicolon(_) =>
                                              parser = advance_parser(parser)
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
                            Err(p) => return Err(p)
                          }
                        }
                        _ => break
                      }
                    }
                    _ => break
                  }
                } else {
                  // readonly computed property
                  let (_computed_name, p) = match
                    parse_assignment_expression(parser) {
                    Ok((expr, p)) => (expr, p)
                    Err(p) => return Err(p)
                  }
                  parser = p
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
                  let is_optional = match current_token(parser) {
                    Question(_) => {
                      parser = advance_parser(parser)
                      true
                    }
                    _ => false
                  }
                  match current_token(parser) {
                    Colon(_) => {
                      parser = advance_parser(parser)
                      match parse_type(parser) {
                        Ok((prop_type, p)) => {
                          parser = p
                          let prop_name = "[computed]"
                          members.push(
                            Node::TypeLiteralProperty(TypeLiteralProperty::{
                              name: prop_name,
                              type_node: Some(prop_type),
                              is_optional,
                              is_readonly: true,
                              location: member_loc,
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
              }
              // readonly prop: type
              Identifier(name, _) => {
                parser = advance_parser(parser)
                let is_optional = match current_token(parser) {
                  Question(_) => {
                    parser = advance_parser(parser)
                    true
                  }
                  _ => false
                }
                match current_token(parser) {
                  Colon(_) => {
                    parser = advance_parser(parser)
                    match parse_type(parser) {
                      Ok((prop_type, p)) => {
                        members.push(
                          Node::TypeLiteralProperty(TypeLiteralProperty::{
                            name,
                            type_node: Some(prop_type),
                            is_optional,
                            is_readonly: true,
                            location: member_loc,
                          }),
                        )
                        parser = p
                        match current_token(parser) {
                          Comma(_) | Semicolon(_) =>
                            parser = advance_parser(parser)
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
          // Handle spread type: { ...T }
          DotDotDot(spread_loc) => {
            parser = advance_parser(parser) // consume '...'
            match parse_type(parser) {
              Ok((spread_type, p)) => {
                parser = p
                // Check if the spread type is a primitive (TS2700)
                let is_primitive = match spread_type {
                  KeywordType(kt) =>
                    match kt.kind {
                      TypeKeyword::Number
                      | TypeKeyword::String
                      | TypeKeyword::Boolean
                      | TypeKeyword::Symbol
                      | TypeKeyword::Void
                      | TypeKeyword::Undefined
                      | TypeKeyword::Null
                      | TypeKeyword::Never
                      | TypeKeyword::Any
                      | TypeKeyword::Unknown => true
                      _ => false
                    }
                  _ => false
                }
                if is_primitive {
                  // TS2700: Rest types may only be created from object types
                  return Err(
                    add_error_checked(
                      parser, "Rest types may only be created from object types.",
                      spread_loc, 2700,
                    ),
                  )
                }
                // Valid spread type - add as a spread member
                // For now, we'll create a TypeLiteralProperty with a special name
                members.push(
                  Node::TypeLiteralProperty(TypeLiteralProperty::{
                    name: "...",
                    type_node: Some(spread_type),
                    is_optional: false,
                    is_readonly: false,
                    location: spread_loc,
                  }),
                )
                // Optional comma or semicolon
                match current_token(parser) {
                  Comma(_) | Semicolon(_) => parser = advance_parser(parser)
                  _ => ()
                }
              }
              Err(p) => return Err(p)
            }
          }
          _ =>
            // Try to parse as identifier or keyword property name
            match try_get_property_name(current_token(parser)) {
              Some((name, _)) => {
                parser = advance_parser(parser)
                // Check for optional property marker (?)
                let is_optional = match current_token(parser) {
                  Question(_) => {
                    parser = advance_parser(parser)
                    true
                  }
                  _ => false
                }
                // Check for method signature, property type, or shorthand property
                match current_token(parser) {
                  // Method signature: name() : Type or name(params) : Type
                  OpenParen(_) => {
                    parser = advance_parser(parser)
                    let (params, p) = parse_parameter_list(parser)
                    parser = p
                    // Expect : for return type
                    match current_token(parser) {
                      Colon(_) => {
                        parser = advance_parser(parser)
                        match parse_type(parser) {
                          Ok((return_type, p)) => {
                            members.push(
                              Node::MethodDeclaration(MethodDeclaration::{
                                name,
                                parameters: params,
                                return_type: Some(return_type),
                                body: None,
                                type_parameters: [],
                                decorators: [],
                                modifiers: [],
                                is_optional,
                                is_async: false,
                                is_generator: false,
                                location: member_loc,
                              }),
                            )
                            parser = p
                            // Optional comma or semicolon
                            match current_token(parser) {
                              Comma(_) | Semicolon(_) =>
                                parser = advance_parser(parser)
                              _ => ()
                            }
                          }
                          Err(p) => return Err(p)
                        }
                      }
                      _ => break
                    }
                  }
                  // Property with type: name : Type
                  Colon(_) => {
                    parser = advance_parser(parser)
                    match parse_type(parser) {
                      Ok((prop_type, p)) => {
                        members.push(
                          Node::TypeLiteralProperty(TypeLiteralProperty::{
                            name,
                            type_node: Some(prop_type),
                            is_optional,
                            is_readonly: false,
                            location: member_loc,
                          }),
                        )
                        parser = p
                        // Optional comma or semicolon
                        match current_token(parser) {
                          Comma(_) | Semicolon(_) =>
                            parser = advance_parser(parser)
                          _ => ()
                        }
                      }
                      Err(p) => return Err(p)
                    }
                  }
                  // Shorthand property: { a } means { a: a }
                  CloseBrace(_) | Semicolon(_) | Comma(_) => {
                    // Create type literal property with type reference to the same name
                    members.push(
                      Node::TypeLiteralProperty(TypeLiteralProperty::{
                        name,
                        type_node: Some(
                          Node::TypeReference(TypeReference::{
                            type_name: name,
                            type_arguments: [],
                            location: member_loc,
                          }),
                        ),
                        is_optional,
                        is_readonly: false,
                        location: member_loc,
                      }),
                    )
                    // Optional comma or semicolon
                    match current_token(parser) {
                      Semicolon(_) | Comma(_) => parser = advance_parser(parser)
                      _ => ()
                    }
                  }
                  _ => break
                }
              }
              None => break
            }
        }
      }

      // Return TypeLiteral node with parsed members
      Ok((Node::TypeLiteral(TypeLiteral::{ members, location: loc }), parser))
    }
    LessThan(_) => {
      // Generic function type: <T>(param: T) => T
      // or generic construct signature: new <T>(param: T) => T
      let (type_params, parser) = parse_type_parameters(parser)

      // Expect '(' for function parameters
      match current_token(parser) {
        OpenParen(_) => {
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
                        type_parameters: type_params,
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
                  "Expected '=>' in generic function type",
                  current_token(parser).location(),
                ),
              )
          }
        }
        _ =>
          Err(
            add_error(
              parser,
              "Expected '(' after type parameters in generic function type",
              current_token(parser).location(),
            ),
          )
      }
    }
    KeywordNew(_) => {
      // Constructor type: new () => Type or new <T>() => Type
      let parser = advance_parser(parser)
      // Check for optional type parameters: new <T>()
      let (type_params, parser) = match current_token(parser) {
        LessThan(_) => parse_type_parameters(parser)
        _ => ([], parser)
      }
      // Expect '(' for constructor parameters
      match current_token(parser) {
        OpenParen(_) => {
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
                      Node::ConstructorType(ConstructorType::{
                        type_parameters: type_params,
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
                  "Expected '=>' in constructor type",
                  current_token(parser).location(),
                ),
              )
          }
        }
        _ =>
          Err(
            add_error(
              parser,
              "Expected '(' after 'new' in constructor type",
              current_token(parser).location(),
            ),
          )
      }
    }
    OpenParen(_) => {
      // Could be:
      // 1. Parenthesized type: (number | string)
      // 2. Function type: (param: type, ...) => returnType
      //
      // We need to look ahead to determine which case this is.
      // If we see a type followed by ')' and no '=>', it's a parenthesized type.
      // If we see '=>' after ')', it's a function type.
      let saved_parser = parser
      let inner_parser = advance_parser(parser) // consume '('

      // Quick check: if it starts with ')', '...', or 'this', it's a function type
      match current_token(inner_parser) {
        CloseParen(_) =>
          // Empty parameter list - definitely a function type
          ()
        DotDotDot(_) =>
          // Rest parameter - definitely a function type
          ()
        KeywordThis(_) =>
          // 'this' parameter - definitely a function type
          ()
        _ =>
          // Try to parse as parenthesized type first
          match parse_type(inner_parser) {
            Ok((inner_type, p)) =>
              match current_token(p) {
                CloseParen(_) => {
                  let after_paren = advance_parser(p)
                  // Check if this is followed by '=>' (function type) or something else (parenthesized type)
                  match current_token(after_paren) {
                    Arrow(_) =>
                      // This is actually a function type with a single parameter
                      // Fall through to function type parsing
                      ()
                    _ =>
                      // This is a parenthesized type - return the inner type wrapped in ParenthesizedType
                      return Ok(
                        (
                          Node::ParenthesizedType(ParenthesizedType::{
                            type_node: inner_type,
                            location: loc,
                          }),
                          after_paren,
                        ),
                      )
                  }
                }
                _ => () // Not a simple parenthesized type, try as function type
              }
            Err(_) => () // Not a simple type, try as function type
          }
      }

      // Parse as function type: (param: type, ...) => returnType
      let parser = advance_parser(saved_parser) // consume '('
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

            // Parse type element - can be "name: type", "name?: type", or just type
            let (elem_type, new_parser) = match current_token(parser) {
              Identifier(name, name_loc) => {
                // Could be "name: type", "name?: type", or just a type reference
                let saved_parser = parser
                parser = advance_parser(parser)
                match current_token(parser) {
                  Colon(_) => {
                    // It's a named tuple element: name: type
                    parser = advance_parser(parser)
                    match parse_type(parser) {
                      Ok((t, p)) => {
                        let named_member = Node::NamedTupleMember(NamedTupleMember::{
                          name,
                          element_type: t,
                          is_optional: false,
                          location: name_loc,
                        })
                        (named_member, p)
                      }
                      Err(p) => return Err(p)
                    }
                  }
                  Question(_) => {
                    // name?: type - named optional element
                    parser = advance_parser(parser) // consume ?
                    match current_token(parser) {
                      Colon(_) => {
                        parser = advance_parser(parser)
                        match parse_type(parser) {
                          Ok((t, p)) => {
                            // Create a NamedTupleMember with is_optional = true
                            let named_member = Node::NamedTupleMember(NamedTupleMember::{
                              name,
                              element_type: t,
                              is_optional: true,
                              location: name_loc,
                            })
                            (named_member, p)
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
                // Parse array type suffix (e.g., string[])
                let (type_node, p) = parse_array_type_suffix(p, type_node)
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
                // Parse array type suffix (e.g., string[])
                let (type_node, p) = parse_array_type_suffix(p, type_node)
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
