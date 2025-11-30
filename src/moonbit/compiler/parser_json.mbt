// JSON Parsing - Split from parser.mbt for better organization
// Contains all JSON-related parsing functions

///|
/// Parsing mode for different file types
pub enum ParserMode {
  TypeScript // Full TypeScript/JavaScript
  JSON // JSON only (strict)
  JSONC // JSON with comments
} derive(Show, Eq)

///|
/// Parse a JSON file
pub fn parse_json(
  tokens : Array[Token],
  file_path : String,
) -> ParseResult[Node] {
  let parser = Parser::new(tokens)
  match parse_json_value(parser) {
    Ok((node, parser)) =>
      // Check for trailing content
      if not(is_at_end(parser)) {
        let loc = current_token(parser).location()
        let parser = add_error_with_code(
          parser,
          UnexpectedToken.to_message(),
          loc,
          UnexpectedToken,
        )
        Err(parser.diagnostics)
      } else if parser.diagnostics.length() > 0 {
        Err(parser.diagnostics)
      } else {
        Ok(node)
      }
    Err(parser) => Err(parser.diagnostics)
  }
}

///|
/// Parse a JSONC file (JSON with comments)
pub fn parse_jsonc(
  tokens : Array[Token],
  file_path : String,
) -> ParseResult[Node] {
  // JSONC is the same as JSON but the scanner should have already stripped comments
  parse_json(tokens, file_path)
}

///|
/// Parse a JSON value (object, array, string, number, boolean, null)
fn parse_json_value(parser : Parser) -> Result[(Node, Parser), Parser] {
  let token = current_token(parser)
  let loc = token.location()
  match token {
    // Object: { }
    OpenBrace(_) => parse_json_object(parser)

    // Array: [ ]
    OpenBracket(_) => parse_json_array(parser)

    // String
    StringLiteral(value, _) => {
      let parser = advance_parser(parser)
      Ok((Node::StringLiteral(StringLiteral::{ value, location: loc }), parser))
    }

    // Number
    NumericLiteral(value, _) => {
      let parser = advance_parser(parser)
      Ok(
        (Node::NumericLiteral(NumericLiteral::{ value, location: loc }), parser),
      )
    }

    // Negative number
    Minus(_) => {
      let parser = advance_parser(parser)
      match current_token(parser) {
        NumericLiteral(value, _) => {
          let parser = advance_parser(parser)
          // Store as negative number by prepending "-" to the string value
          Ok(
            (
              Node::NumericLiteral(NumericLiteral::{
                value: "-" + value,
                location: loc,
              }),
              parser,
            ),
          )
        }
        _ =>
          Err(
            add_error_with_code(
              parser,
              JSONExpectedValue.to_message(),
              loc,
              JSONExpectedValue,
            ),
          )
      }
    }

    // Null
    KeywordNull(_) => {
      let parser = advance_parser(parser)
      Ok((Node::NullLiteral(NullLiteral::{ location: loc }), parser))
    }

    // Boolean and null as identifiers (true, false, null)
    Identifier(name, _) =>
      match name {
        "true" => {
          let parser = advance_parser(parser)
          Ok(
            (
              Node::BooleanLiteral(BooleanLiteral::{
                value: true,
                location: loc,
              }),
              parser,
            ),
          )
        }
        "false" => {
          let parser = advance_parser(parser)
          Ok(
            (
              Node::BooleanLiteral(BooleanLiteral::{
                value: false,
                location: loc,
              }),
              parser,
            ),
          )
        }
        "null" => {
          let parser = advance_parser(parser)
          Ok((Node::NullLiteral(NullLiteral::{ location: loc }), parser))
        }
        _ =>
          Err(
            add_error_with_code(
              parser,
              JSONExpectedValue.to_message(),
              loc,
              JSONExpectedValue,
            ),
          )
      }
    EOF(_) =>
      Err(
        add_error_with_code(
          parser,
          UnexpectedEOF.to_message(),
          loc,
          UnexpectedEOF,
        ),
      )
    _ =>
      Err(
        add_error_with_code(
          parser,
          JSONExpectedValue.to_message(),
          loc,
          JSONExpectedValue,
        ),
      )
  }
}

///|
/// Parse a JSON object: { "key": value, ... }
fn parse_json_object(parser : Parser) -> Result[(Node, Parser), Parser] {
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // Skip {
  let properties : Array[ObjectProperty] = []
  let mut parser = parser

  // Handle empty object
  if matches_close_brace(current_token(parser)) {
    let parser = advance_parser(parser)
    return Ok(
      (
        Node::ObjectLiteralExpression(ObjectLiteralExpression::{
          properties,
          location: start_loc,
        }),
        parser,
      ),
    )
  }
  while not(is_at_end(parser)) {
    // Property name must be a string
    match current_token(parser) {
      StringLiteral(name, name_loc) => {
        parser = advance_parser(parser)

        // Expect :
        match current_token(parser) {
          Colon(_) => parser = advance_parser(parser)
          _ => {
            let loc = current_token(parser).location()
            return Err(
              add_error_with_code(
                parser,
                ExpectedColon.to_message(),
                loc,
                ExpectedColon,
              ),
            )
          }
        }

        // Parse value
        match parse_json_value(parser) {
          Ok((value, p)) => {
            parser = p
            properties.push(
              ObjectProperty::PropertyAssignment(name, value, name_loc),
            )
          }
          Err(p) => return Err(p)
        }

        // Check for comma or closing brace
        match current_token(parser) {
          Comma(_) => {
            parser = advance_parser(parser)
            // Check for trailing comma (not allowed in strict JSON)
            if matches_close_brace(current_token(parser)) {
              let loc = current_token(parser).location()
              let parser = add_error_with_code(
                parser,
                JSONTrailingComma.to_message(),
                loc,
                JSONTrailingComma,
              )
              // Continue anyway to be lenient
              let parser = advance_parser(parser)
              return Ok(
                (
                  Node::ObjectLiteralExpression(ObjectLiteralExpression::{
                    properties,
                    location: start_loc,
                  }),
                  parser,
                ),
              )
            }
          }
          CloseBrace(_) => {
            let parser = advance_parser(parser)
            return Ok(
              (
                Node::ObjectLiteralExpression(ObjectLiteralExpression::{
                  properties,
                  location: start_loc,
                }),
                parser,
              ),
            )
          }
          _ => {
            let loc = current_token(parser).location()
            return Err(
              add_error_with_code(
                parser,
                UnexpectedToken.to_message(),
                loc,
                UnexpectedToken,
              ),
            )
          }
        }
      }
      CloseBrace(_) => {
        // Empty object or trailing comma handled
        let parser = advance_parser(parser)
        return Ok(
          (
            Node::ObjectLiteralExpression(ObjectLiteralExpression::{
              properties,
              location: start_loc,
            }),
            parser,
          ),
        )
      }
      _ => {
        let loc = current_token(parser).location()
        return Err(
          add_error_with_code(
            parser,
            JSONExpectedPropertyName.to_message(),
            loc,
            JSONExpectedPropertyName,
          ),
        )
      }
    }
  }
  Err(
    add_error_with_code(
      parser,
      UnexpectedEOF.to_message(),
      start_loc,
      UnexpectedEOF,
    ),
  )
}

///|
/// Parse a JSON array: [ value, ... ]
fn parse_json_array(parser : Parser) -> Result[(Node, Parser), Parser] {
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // Skip [
  let elements : Array[Node?] = []
  let mut parser = parser

  // Handle empty array
  if matches_close_bracket(current_token(parser)) {
    let parser = advance_parser(parser)
    return Ok(
      (
        Node::ArrayLiteralExpression(ArrayLiteralExpression::{
          elements,
          location: start_loc,
        }),
        parser,
      ),
    )
  }
  while not(is_at_end(parser)) {
    // Parse value
    match parse_json_value(parser) {
      Ok((value, p)) => {
        parser = p
        elements.push(Some(value))
      }
      Err(p) => return Err(p)
    }

    // Check for comma or closing bracket
    match current_token(parser) {
      Comma(_) => {
        parser = advance_parser(parser)
        // Check for trailing comma (not allowed in strict JSON)
        if matches_close_bracket(current_token(parser)) {
          let loc = current_token(parser).location()
          let parser = add_error_with_code(
            parser,
            JSONTrailingComma.to_message(),
            loc,
            JSONTrailingComma,
          )
          // Continue anyway to be lenient
          let parser = advance_parser(parser)
          return Ok(
            (
              Node::ArrayLiteralExpression(ArrayLiteralExpression::{
                elements,
                location: start_loc,
              }),
              parser,
            ),
          )
        }
      }
      CloseBracket(_) => {
        let parser = advance_parser(parser)
        return Ok(
          (
            Node::ArrayLiteralExpression(ArrayLiteralExpression::{
              elements,
              location: start_loc,
            }),
            parser,
          ),
        )
      }
      _ => {
        let loc = current_token(parser).location()
        return Err(
          add_error_with_code(
            parser,
            UnexpectedToken.to_message(),
            loc,
            UnexpectedToken,
          ),
        )
      }
    }
  }
  Err(
    add_error_with_code(
      parser,
      UnexpectedEOF.to_message(),
      start_loc,
      UnexpectedEOF,
    ),
  )
}
