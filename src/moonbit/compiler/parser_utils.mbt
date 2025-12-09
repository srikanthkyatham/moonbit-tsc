// Parser Utility Functions - Shared helpers for reducing duplication
// Contains reusable parsing patterns extracted from parser modules

///|
/// Configuration for how to handle trailing commas in delimited lists
pub enum TrailingCommaMode {
  Allow // Allow trailing commas without error (TypeScript style)
  Error(ParserErrorCode) // Report error but continue (JSON style)
  Forbid // Hard error and stop parsing
} derive(Show, Eq)

///|
/// Check for and handle trailing comma after consuming a comma token.
/// Returns Ok(true) if trailing comma detected (caller should return early),
/// Ok(false) if no trailing comma (continue parsing),
/// or Err(parser) if hard error occurred.
///
/// Usage:
/// ```moonbit
/// match current_token(parser) {
///   Comma(_) => {
///     parser = advance_parser(parser)
///     match handle_trailing_comma(parser, matches_close_bracket, TrailingCommaMode::Error(ParserErrorCode::JSONTrailingComma)) {
///       Ok((true, p)) => return Ok((result_node, p))
///       Ok((false, p)) => parser = p  // Continue loop
///       Err(p) => return Err(p)
///     }
///   }
///   ...
/// }
/// ```
pub fn handle_trailing_comma(
  parser : Parser,
  close_delimiter_check : (Token) -> Bool,
  mode : TrailingCommaMode,
) -> Result[(Bool, Parser), Parser] {
  if close_delimiter_check(current_token(parser)) {
    let loc = current_token(parser).location()
    match mode {
      TrailingCommaMode::Allow => {
        // Allow trailing comma without error
        Ok((true, parser))
      }
      TrailingCommaMode::Error(code) => {
        // Report error but continue
        let parser = add_error_with_code(parser, code.to_message(), loc, code)
        Ok((true, parser))
      }
      TrailingCommaMode::Forbid => {
        // Hard error
        Err(add_error(parser, "Trailing comma not allowed", loc))
      }
    }
  } else {
    // No trailing comma, continue parsing
    Ok((false, parser))
  }
}

// Note: A generic parse_comma_separated_items helper would be useful here,
// but MoonBit doesn't support higher-kinded types in the way needed for this pattern.
// The pattern is documented above in handle_trailing_comma() for manual implementation.

///|
/// Add an "Unexpected token" error at the current position.
/// This is the most common error pattern across all parsers.
///
/// Usage:
/// ```moonbit
/// _ => Err(add_unexpected_token_error(parser))
/// ```
pub fn add_unexpected_token_error(parser : Parser) -> Parser {
  let loc = current_token(parser).location()
  add_error(parser, "Unexpected token", loc)
}

///|
/// Add an "Unexpected token" error at a specific location.
/// Use this when you've already moved past the unexpected token.
///
/// Usage:
/// ```moonbit
/// let token_loc = current_token(parser).location()
/// let parser = advance_parser(parser)
/// return Err(add_unexpected_token_error_at(parser, token_loc))
/// ```
pub fn add_unexpected_token_error_at(
  parser : Parser,
  location : SourceLocation,
) -> Parser {
  add_error(parser, "Unexpected token", location)
}

///|
/// Add an "Expression expected" error at the current position.
/// Common in contexts where an expression is required but missing.
///
/// Usage:
/// ```moonbit
/// Semicolon(loc) => {
///   let parser = add_expression_expected_error(parser)
///   return Ok((make_empty_expression(loc), parser))
/// }
/// ```
pub fn add_expression_expected_error(parser : Parser) -> Parser {
  let loc = current_token(parser).location()
  add_error(parser, "Expression expected.", loc)
}

///|
/// Expect and consume a closing delimiter, returning an error with proper code if missing.
/// This standardizes the common pattern of expecting }, ], or ) at the end of constructs.
///
/// Usage:
/// ```moonbit
/// match expect_closing_delimiter(parser, matches_close_brace, ExpectedCloseBrace) {
///   Ok(p) => Ok((node, advance_parser(p)))
///   Err(p) => Err(p)
/// }
/// ```
pub fn expect_closing_delimiter(
  parser : Parser,
  delimiter_check : (Token) -> Bool,
  error_code : ParserErrorCode,
) -> Result[Parser, Parser] {
  match expect(parser, delimiter_check) {
    Ok(p) => Ok(p)
    Err(p) => {
      let loc = current_token(p).location()
      Err(add_error_with_code(p, error_code.to_message(), loc, error_code))
    }
  }
}
