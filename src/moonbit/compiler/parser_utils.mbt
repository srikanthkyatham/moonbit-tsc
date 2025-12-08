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
