// Incremental Parsing - Split from parser.mbt for better organization
// Contains incremental parsing functions for efficient reparsing

///|
/// Helper function to parse source string to AST
fn parse_from_source(source : String, file_path : String) -> Node? {
  let tokens = scan_all_v2(source, file_path)
  match parse_source_file(tokens, file_path) {
    Ok(sf) => Some(Node::SourceFile(sf))
    Err(_) => None
  }
}

///|
/// Parse source file with incremental update support
/// If old_source_file is provided, attempts to reuse unchanged portions
pub fn parse_incremental(
  new_source : String,
  file_path : String,
  change_range : TextChangeRange?,
  old_source_file : Node?,
) -> IncrementalParseResult {
  // If no change range or no old source file, do a full parse
  match (change_range, old_source_file) {
    (None, _) | (_, None) => {
      let result = parse_from_source(new_source, file_path)
      match result {
        Some(sf) =>
          IncrementalParseResult::{ source_file: sf, affected_range: None }
        None => {
          // Create empty source file on parse error
          let eof_loc = SourceLocation::new(
            file_path,
            Position::new(1, 0, 0),
            Position::new(1, 0, 0),
          )
          let empty_sf = SourceFile::{
            statements: [],
            file_path,
            end_of_file_token: EOF(eof_loc),
            has_no_default_lib: false,
            directive_tokens: [],
            hashbang: None,
            ts_expect_error_directives: [],
            compiler_directives: CompilerDirectives::default(),
            parse_diagnostics: [],
          }
          IncrementalParseResult::{
            source_file: Node::SourceFile(empty_sf),
            affected_range: None,
          }
        }
      }
    }
    (Some(change), Some(_old_sf)) =>
      // Try incremental parsing
      try_incremental_parse(new_source, file_path, change)
  }
}

///|
/// Attempt incremental parsing based on change range
fn try_incremental_parse(
  new_source : String,
  file_path : String,
  change_range : TextChangeRange,
) -> IncrementalParseResult {
  // Calculate the affected range - expand to statement boundaries
  let affected_start = find_statement_start(new_source, change_range.span.start)
  let change_end = change_range.span.start + change_range.new_length
  let affected_end = find_statement_end(new_source, change_end)
  let affected_span = TextSpan::new(
    affected_start,
    affected_end - affected_start,
  )

  // For simplicity in this implementation, if the change is large (>20% of file),
  // just do a full reparse
  if affected_span.length > new_source.length() / 5 {
    let result = parse_from_source(new_source, file_path)
    return match result {
      Some(sf) =>
        IncrementalParseResult::{ source_file: sf, affected_range: None }
      None => {
        let eof_loc = SourceLocation::new(
          file_path,
          Position::new(1, 0, 0),
          Position::new(1, 0, 0),
        )
        let empty_sf = SourceFile::{
          statements: [],
          file_path,
          end_of_file_token: EOF(eof_loc),
          has_no_default_lib: false,
          directive_tokens: [],
          hashbang: None,
          ts_expect_error_directives: [],
          compiler_directives: CompilerDirectives::default(),
          parse_diagnostics: [],
        }
        IncrementalParseResult::{
          source_file: Node::SourceFile(empty_sf),
          affected_range: None,
        }
      }
    }
  }

  // Otherwise, parse the full file but record the affected range
  // A more sophisticated implementation would actually reuse unchanged nodes
  let result = parse_from_source(new_source, file_path)
  match result {
    Some(sf) =>
      IncrementalParseResult::{
        source_file: sf,
        affected_range: Some(affected_span),
      }
    None => {
      let eof_loc = SourceLocation::new(
        file_path,
        Position::new(1, 0, 0),
        Position::new(1, 0, 0),
      )
      let empty_sf = SourceFile::{
        statements: [],
        file_path,
        end_of_file_token: EOF(eof_loc),
        has_no_default_lib: false,
        directive_tokens: [],
        hashbang: None,
        ts_expect_error_directives: [],
        compiler_directives: CompilerDirectives::default(),
        parse_diagnostics: [],
      }
      IncrementalParseResult::{
        source_file: Node::SourceFile(empty_sf),
        affected_range: Some(affected_span),
      }
    }
  }
}

///|
/// Find the start of the statement containing the given position
fn find_statement_start(source : String, position : Int) -> Int {
  // Search backwards for a statement boundary
  let mut pos = position
  let mut brace_depth = 0
  let mut paren_depth = 0
  while pos > 0 {
    match @utils.code_unit(source, pos - 1) {
      Some(ch) => {
        let c = @utils.int_to_char(ch)
        match c {
          '}' => brace_depth = brace_depth + 1
          '{' =>
            if brace_depth > 0 {
              brace_depth = brace_depth - 1
            } else {
              // Found an unmatched { - go back before it
              pos = pos - 1
              break
            }
          ')' => paren_depth = paren_depth + 1
          '(' => if paren_depth > 0 { paren_depth = paren_depth - 1 }
          ';' | '\n' =>
            if brace_depth == 0 && paren_depth == 0 {
              // Found statement boundary
              break
            }
          _ => ()
        }
        pos = pos - 1
      }
      None => break
    }
  }
  pos
}

///|
/// Find the end of the statement containing the given position
fn find_statement_end(source : String, position : Int) -> Int {
  // Search forward for a statement boundary
  let mut pos = position
  let mut brace_depth = 0
  let mut paren_depth = 0
  let len = source.length()
  while pos < len {
    match @utils.code_unit(source, pos) {
      Some(ch) => {
        let c = @utils.int_to_char(ch)
        match c {
          '{' => brace_depth = brace_depth + 1
          '}' =>
            if brace_depth > 0 {
              brace_depth = brace_depth - 1
            } else {
              // Found an unmatched } - include it
              pos = pos + 1
              break
            }
          '(' => paren_depth = paren_depth + 1
          ')' => if paren_depth > 0 { paren_depth = paren_depth - 1 }
          ';' | '\n' =>
            if brace_depth == 0 && paren_depth == 0 {
              // Found statement boundary - include the semicolon/newline
              pos = pos + 1
              break
            }
          _ => ()
        }
        pos = pos + 1
      }
      None => break
    }
  }
  pos
}

///|
/// Apply a text change to source and get the new source
pub fn apply_text_change(
  old_source : String,
  change_range : TextChangeRange,
  new_text : String,
) -> String {
  let span = change_range.span
  let prefix = if span.start > 0 {
    @utils.substr(old_source, start=0, end=span.start)
  } else {
    ""
  }
  let suffix = if span.end() < old_source.length() {
    @utils.substr(old_source, start=span.end(), end=old_source.length())
  } else {
    ""
  }
  prefix + new_text + suffix
}

///|
/// Create a change range for an insertion at a position
pub fn create_insertion_change(position : Int, length : Int) -> TextChangeRange {
  TextChangeRange::new(TextSpan::new(position, 0), length)
}

///|
/// Create a change range for a deletion
pub fn create_deletion_change(start : Int, length : Int) -> TextChangeRange {
  TextChangeRange::new(TextSpan::new(start, length), 0)
}

///|
/// Create a change range for a replacement
pub fn create_replacement_change(
  start : Int,
  old_length : Int,
  new_length : Int,
) -> TextChangeRange {
  TextChangeRange::new(TextSpan::new(start, old_length), new_length)
}

///|
/// Combine multiple change ranges into a single range that covers all changes
pub fn collapse_text_change_ranges(
  changes : Array[TextChangeRange],
) -> TextChangeRange? {
  if changes.length() == 0 {
    return None
  }
  if changes.length() == 1 {
    return Some(changes[0])
  }

  // Find the encompassing range
  let mut start = changes[0].span.start
  let mut end = changes[0].span.end()
  let mut total_delta = 0
  for change in changes {
    // Apply previous deltas to get actual positions
    let adjusted_start = change.span.start + total_delta
    let adjusted_end = change.span.end() + total_delta
    if adjusted_start < start {
      start = adjusted_start
    }
    if adjusted_end > end {
      end = adjusted_end
    }
    total_delta = total_delta + change.delta()
  }
  let final_length = end - start + total_delta
  Some(TextChangeRange::new(TextSpan::new(start, end - start), final_length))
}
