// JSDoc Parsing - Split from parser.mbt for better organization
// Contains all JSDoc-related parsing functions

///|
/// Result of parsing JSDoc content (public API for tests)
pub struct JSDocParseResult {
  description : String
  tags : Array[JSDocTag]
}

///|
/// Public API to parse JSDoc content string
pub fn parse_jsdoc(content : String) -> JSDocParseResult {
  let dummy_pos = Position::{ line: 0, column: 0, offset: 0 }
  let dummy_loc = SourceLocation::{
    file_path: "",
    start: dummy_pos,
    end: dummy_pos,
  }
  let tags : Array[JSDocTag] = []
  let lines = split_jsdoc_lines(content)
  let description_lines : Array[String] = []
  let mut in_tags = false
  let mut i = 0
  while i < lines.length() {
    let trimmed = trim_jsdoc_line(lines[i])

    // Check for tag at start
    if trimmed.has_prefix("@") {
      in_tags = true
      // Check if this is a multi-line tag like @example
      let tag_end = find_whitespace_or_end(trimmed, 1)
      let tag_name = @utils.substr(trimmed, start=1, end=tag_end)
      if tag_name == "example" {
        // Collect all lines until next tag or end
        let rest = if tag_end < trimmed.length() {
          trim_leading_whitespace(
            @utils.substr(trimmed, start=tag_end, end=trimmed.length()),
          )
        } else {
          ""
        }
        let example_lines : Array[String] = []
        if rest.length() > 0 {
          example_lines.push(rest)
        }
        // Collect continuation lines
        i = i + 1
        while i < lines.length() {
          let next_trimmed = trim_jsdoc_line(lines[i])
          if next_trimmed.has_prefix("@") {
            // Don't increment i here - let the outer loop handle this tag
            break
          }
          if next_trimmed.length() > 0 {
            example_lines.push(next_trimmed)
          }
          i = i + 1
        }
        let example_content = example_lines
          .iter()
          .fold(init="", fn(acc, line) {
            if acc.length() == 0 {
              line
            } else {
              acc + "\n" + line
            }
          })
        tags.push(
          JSDocTag::Example(JSDocExample::{
            content: example_content,
            location: dummy_loc,
          }),
        )
        continue // Skip the i increment at the end since we already moved forward
      } else {
        match parse_jsdoc_tag(trimmed, dummy_loc) {
          Some(tag) => tags.push(tag)
          None => ()
        }
      }
    } else if not(in_tags) && trimmed.length() > 0 {
      // Collect description lines (before any tags)
      description_lines.push(trimmed)
    }
    i = i + 1
  }
  let description = description_lines
    .iter()
    .fold(init="", fn(acc, line) {
      if acc.length() == 0 {
        line
      } else {
        acc + "\n" + line
      }
    })
  JSDocParseResult::{ description, tags }
}

///|
/// Parse a JSDoc comment into structured tags
fn parse_jsdoc_comment(content : String, loc : SourceLocation) -> JSDocComment {
  let tags : Array[JSDocTag] = []
  let lines = split_jsdoc_lines(content)
  let mut i = 0
  while i < lines.length() {
    let line = lines[i]
    let trimmed = trim_jsdoc_line(line)

    // Check for tag at start
    if trimmed.has_prefix("@") {
      match parse_jsdoc_tag(trimmed, loc) {
        Some(tag) => tags.push(tag)
        None => ()
      }
    }
    i = i + 1
  }
  JSDocComment::{ comment: content, tags, location: loc }
}

///|
/// Split JSDoc content into lines
fn split_jsdoc_lines(content : String) -> Array[String] {
  let lines : Array[String] = []
  let mut current = ""
  let mut i = 0
  while i < content.length() {
    match content.get(i) {
      Some(ch) => {
        let c = @utils.int_to_char(ch)
        if c == '\n' {
          lines.push(current)
          current = ""
        } else {
          current = current + Char::to_string(c)
        }
      }
      None => ()
    }
    i = i + 1
  }
  if current.length() > 0 {
    lines.push(current)
  }
  lines
}

///|
/// Trim leading/trailing whitespace and leading * from JSDoc line
fn trim_jsdoc_line(line : String) -> String {
  let mut result = ""
  let mut started = false
  let mut past_star = false
  let mut i = 0
  while i < line.length() {
    match line.get(i) {
      Some(ch) => {
        let c = @utils.int_to_char(ch)
        if not(started) {
          if c == ' ' || c == '\t' || c == '\r' {
            // skip leading whitespace
            ()
          } else if c == '*' && not(past_star) {
            past_star = true
          } else {
            started = true
            result = result + Char::to_string(c)
          }
        } else {
          result = result + Char::to_string(c)
        }
      }
      None => ()
    }
    i = i + 1
  }

  // Trim trailing whitespace
  trim_trailing_whitespace(result)
}

///|
/// Trim trailing whitespace from string
fn trim_trailing_whitespace(s : String) -> String {
  let mut end = s.length()
  while end > 0 {
    match s.get(end - 1) {
      Some(ch) => {
        let c = @utils.int_to_char(ch)
        if c == ' ' || c == '\t' || c == '\r' {
          end = end - 1
        } else {
          break
        }
      }
      None => break
    }
  }
  @utils.substr(s, start=0, end~)
}

///|
/// Parse a single JSDoc tag
fn parse_jsdoc_tag(line : String, loc : SourceLocation) -> JSDocTag? {
  // Extract tag name (after @)
  let tag_end = find_whitespace_or_end(line, 1)
  let tag_name = @utils.substr(line, start=1, end=tag_end)
  let rest = if tag_end < line.length() {
    trim_leading_whitespace(
      @utils.substr(line, start=tag_end, end=line.length()),
    )
  } else {
    ""
  }
  match tag_name {
    "param" | "arg" | "argument" => Some(parse_jsdoc_param_tag(rest, loc))
    "returns" | "return" => Some(parse_jsdoc_returns_tag(rest, loc))
    "type" => Some(parse_jsdoc_type_tag(rest, loc))
    "typedef" => Some(parse_jsdoc_typedef_tag(rest, loc))
    "property" | "prop" => Some(parse_jsdoc_property_tag(rest, loc))
    "template" => Some(parse_jsdoc_template_tag(rest, loc))
    "deprecated" =>
      Some(
        JSDocTag::Deprecated(JSDocDeprecated::{
          description: rest,
          location: loc,
        }),
      )
    "example" =>
      Some(JSDocTag::Example(JSDocExample::{ content: rest, location: loc }))
    "see" => Some(JSDocTag::See(JSDocSee::{ reference: rest, location: loc }))
    "throws" | "exception" => Some(parse_jsdoc_throws_tag(rest, loc))
    "author" =>
      Some(JSDocTag::Author(JSDocAuthor::{ name: rest, location: loc }))
    "since" | "version" =>
      Some(JSDocTag::Since(JSDocSince::{ version: rest, location: loc }))
    "default" | "defaultvalue" =>
      Some(JSDocTag::Default(JSDocDefault::{ value: rest, location: loc }))
    "readonly" => Some(JSDocTag::Readonly(loc))
    "override" => Some(JSDocTag::Override(loc))
    "public" => Some(JSDocTag::Public(loc))
    "private" => Some(JSDocTag::Private(loc))
    "protected" => Some(JSDocTag::Protected(loc))
    "abstract" => Some(JSDocTag::Abstract(loc))
    "virtual" => Some(JSDocTag::Virtual(loc))
    _ => Some(JSDocTag::Unknown(tag_name, rest, loc))
  }
}

///|
/// Parse @param tag
fn parse_jsdoc_param_tag(content : String, loc : SourceLocation) -> JSDocTag {
  let (type_annotation, rest) = extract_jsdoc_type(content)
  let (name, is_optional, description) = extract_jsdoc_param_name(rest)
  JSDocTag::Param(JSDocParam::{
    name,
    type_annotation,
    description,
    is_optional,
    location: loc,
  })
}

///|
/// Parse @returns tag
fn parse_jsdoc_returns_tag(content : String, loc : SourceLocation) -> JSDocTag {
  let (type_annotation, description) = extract_jsdoc_type(content)
  JSDocTag::Returns(JSDocReturns::{
    type_annotation,
    description: trim_leading_whitespace(description),
    location: loc,
  })
}

///|
/// Parse @type tag
fn parse_jsdoc_type_tag(content : String, loc : SourceLocation) -> JSDocTag {
  let (type_annotation, _) = extract_jsdoc_type(content)
  JSDocTag::Type(JSDocTypeTag::{
    type_annotation: type_annotation.unwrap_or(""),
    location: loc,
  })
}

///|
/// Parse @typedef tag
fn parse_jsdoc_typedef_tag(content : String, loc : SourceLocation) -> JSDocTag {
  let (type_annotation, rest) = extract_jsdoc_type(content)
  let name_end = find_whitespace_or_end(rest, 0)
  let name = @utils.substr(rest, start=0, end=name_end)
  let description = if name_end < rest.length() {
    trim_leading_whitespace(
      @utils.substr(rest, start=name_end, end=rest.length()),
    )
  } else {
    ""
  }
  JSDocTag::TypeDef(JSDocTypeDef::{
    name,
    type_annotation: type_annotation.unwrap_or(""),
    description,
    location: loc,
  })
}

///|
/// Parse @property tag
fn parse_jsdoc_property_tag(content : String, loc : SourceLocation) -> JSDocTag {
  let (type_annotation, rest) = extract_jsdoc_type(content)
  let (name, is_optional, description) = extract_jsdoc_param_name(rest)
  JSDocTag::Property(JSDocProperty::{
    name,
    type_annotation,
    description,
    is_optional,
    location: loc,
  })
}

///|
/// Parse @template tag
fn parse_jsdoc_template_tag(content : String, loc : SourceLocation) -> JSDocTag {
  // Parse type params: T, U, V or {constraint} T
  let type_params : Array[String] = []
  let mut constraint : String? = None
  let (maybe_constraint, rest) = extract_jsdoc_type(content)
  constraint = maybe_constraint

  // Split rest by comma
  let params_str = if constraint.is_empty() { content } else { rest }
  let parts = split_by_comma(params_str)
  for part in parts {
    let trimmed = trim_leading_whitespace(part)
    if trimmed.length() > 0 {
      type_params.push(trimmed)
    }
  }
  JSDocTag::Template(JSDocTemplate::{ type_params, constraint, location: loc })
}

///|
/// Parse @throws tag
fn parse_jsdoc_throws_tag(content : String, loc : SourceLocation) -> JSDocTag {
  let (type_annotation, description) = extract_jsdoc_type(content)
  JSDocTag::Throws(JSDocThrows::{
    type_annotation,
    description: trim_leading_whitespace(description),
    location: loc,
  })
}

///|
/// Extract type annotation from JSDoc: {type} rest
fn extract_jsdoc_type(content : String) -> (String?, String) {
  let trimmed = trim_leading_whitespace(content)
  if trimmed.has_prefix("{") {
    // Find matching }
    let mut depth = 0
    let mut end = 0
    let mut i = 0
    while i < trimmed.length() {
      match trimmed.get(i) {
        Some(ch) => {
          let c = @utils.int_to_char(ch)
          if c == '{' {
            depth = depth + 1
          } else if c == '}' {
            depth = depth - 1
            if depth == 0 {
              end = i
              break
            }
          }
        }
        None => ()
      }
      i = i + 1
    }
    if end > 1 {
      let type_str = @utils.substr(trimmed, start=1, end~)
      let rest = @utils.substr(trimmed, start=end + 1, end=trimmed.length())
      (Some(type_str), trim_leading_whitespace(rest))
    } else {
      (None, content)
    }
  } else {
    (None, content)
  }
}

///|
/// Extract param name, checking for [name] optional syntax
fn extract_jsdoc_param_name(content : String) -> (String, Bool, String) {
  let trimmed = trim_leading_whitespace(content)
  if trimmed.has_prefix("[") {
    // Optional param: [name] or [name=default]
    let bracket_end = find_char(trimmed, ']', 1)
    if bracket_end > 1 {
      let name_part = @utils.substr(trimmed, start=1, end=bracket_end)
      // Check for default value
      let equals_pos = find_char(name_part, '=', 0)
      let name = if equals_pos > 0 {
        @utils.substr(name_part, start=0, end=equals_pos)
      } else {
        name_part
      }
      let rest = @utils.substr(
        trimmed,
        start=bracket_end + 1,
        end=trimmed.length(),
      )
      return (name, true, trim_leading_whitespace(rest))
    }
  }

  // Regular param name
  let name_end = find_whitespace_or_end(trimmed, 0)
  let name = @utils.substr(trimmed, start=0, end=name_end)
  let description = if name_end < trimmed.length() {
    trim_leading_whitespace(
      @utils.substr(trimmed, start=name_end, end=trimmed.length()),
    )
  } else {
    ""
  }
  (name, false, description)
}

///|
/// Find first whitespace character or end of string
fn find_whitespace_or_end(s : String, start : Int) -> Int {
  let mut i = start
  while i < s.length() {
    match s.get(i) {
      Some(ch) => {
        let c = @utils.int_to_char(ch)
        if c == ' ' || c == '\t' || c == '\r' || c == '\n' {
          return i
        }
      }
      None => return i
    }
    i = i + 1
  }
  i
}

///|
/// Trim leading whitespace
fn trim_leading_whitespace(s : String) -> String {
  let mut start = 0
  while start < s.length() {
    match s.get(start) {
      Some(ch) => {
        let c = @utils.int_to_char(ch)
        if c == ' ' || c == '\t' || c == '\r' {
          start = start + 1
        } else {
          break
        }
      }
      None => break
    }
  }
  @utils.substr(s, start~, end=s.length())
}

///|
/// Find character in string
fn find_char(s : String, target : Char, start : Int) -> Int {
  let mut i = start
  while i < s.length() {
    match s.get(i) {
      Some(ch) => if @utils.int_to_char(ch) == target { return i }
      None => ()
    }
    i = i + 1
  }
  -1
}

///|
/// Split string by comma
fn split_by_comma(s : String) -> Array[String] {
  let parts : Array[String] = []
  let mut current = ""
  let mut i = 0
  while i < s.length() {
    match s.get(i) {
      Some(ch) => {
        let c = @utils.int_to_char(ch)
        if c == ',' {
          parts.push(current)
          current = ""
        } else {
          current = current + Char::to_string(c)
        }
      }
      None => ()
    }
    i = i + 1
  }
  if current.length() > 0 {
    parts.push(current)
  }
  parts
}

///|
/// Check if optional is empty
fn[T] Option::is_empty(self : T?) -> Bool {
  match self {
    Some(_) => false
    None => true
  }
}

///|
/// Parse JSDoc token into JSDocComment node
pub fn parse_jsdoc_token(parser : Parser) -> (Node, Parser) {
  match current_token(parser) {
    JSDocComment(content, loc) => {
      let jsdoc = parse_jsdoc_comment(content, loc)
      let parser = advance_parser(parser)
      (Node::JSDocComment(jsdoc), parser)
    }
    _ => {
      // Should not happen, but handle gracefully
      let loc = current_token(parser).location()
      let empty_jsdoc = JSDocComment::{ comment: "", tags: [], location: loc }
      (Node::JSDocComment(empty_jsdoc), parser)
    }
  }
}
