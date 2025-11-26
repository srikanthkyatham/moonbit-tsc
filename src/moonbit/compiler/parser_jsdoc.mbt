// JSDoc Parsing - Split from parser.mbt for better organization
// Contains all JSDoc-related parsing functions

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
        let c = Char::from_int(ch)
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
        let c = Char::from_int(ch)
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
        let c = Char::from_int(ch)
        if c == ' ' || c == '\t' || c == '\r' {
          end = end - 1
        } else {
          break
        }
      }
      None => break
    }
  }
  s.substring(start=0, end~)
}

///|
/// Parse a single JSDoc tag
fn parse_jsdoc_tag(line : String, loc : SourceLocation) -> JSDocTag? {
  // Extract tag name (after @)
  let tag_end = find_whitespace_or_end(line, 1)
  let tag_name = line.substring(start=1, end=tag_end)
  let rest = if tag_end < line.length() {
    trim_leading_whitespace(line.substring(start=tag_end, end=line.length()))
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
    "since" =>
      Some(JSDocTag::Since(JSDocSince::{ version: rest, location: loc }))
    "default" | "defaultvalue" =>
      Some(JSDocTag::Default(JSDocDefault::{ value: rest, location: loc }))
    "readonly" => Some(JSDocTag::Readonly(loc))
    "override" => Some(JSDocTag::Override(loc))
    "public" => Some(JSDocTag::Public(loc))
    "private" => Some(JSDocTag::Private(loc))
    "protected" => Some(JSDocTag::Protected(loc))
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
    type_annotation: type_annotation.or(""),
    location: loc,
  })
}

///|
/// Parse @typedef tag
fn parse_jsdoc_typedef_tag(content : String, loc : SourceLocation) -> JSDocTag {
  let (type_annotation, rest) = extract_jsdoc_type(content)
  let name_end = find_whitespace_or_end(rest, 0)
  let name = rest.substring(start=0, end=name_end)
  let description = if name_end < rest.length() {
    trim_leading_whitespace(rest.substring(start=name_end, end=rest.length()))
  } else {
    ""
  }
  JSDocTag::TypeDef(JSDocTypeDef::{
    name,
    type_annotation: type_annotation.or(""),
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
          let c = Char::from_int(ch)
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
      let type_str = trimmed.substring(start=1, end~)
      let rest = trimmed.substring(start=end + 1, end=trimmed.length())
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
      let name_part = trimmed.substring(start=1, end=bracket_end)
      // Check for default value
      let equals_pos = find_char(name_part, '=', 0)
      let name = if equals_pos > 0 {
        name_part.substring(start=0, end=equals_pos)
      } else {
        name_part
      }
      let rest = trimmed.substring(start=bracket_end + 1, end=trimmed.length())
      return (name, true, trim_leading_whitespace(rest))
    }
  }

  // Regular param name
  let name_end = find_whitespace_or_end(trimmed, 0)
  let name = trimmed.substring(start=0, end=name_end)
  let description = if name_end < trimmed.length() {
    trim_leading_whitespace(
      trimmed.substring(start=name_end, end=trimmed.length()),
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
        let c = Char::from_int(ch)
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
        let c = Char::from_int(ch)
        if c == ' ' || c == '\t' || c == '\r' {
          start = start + 1
        } else {
          break
        }
      }
      None => break
    }
  }
  s.substring(start~, end=s.length())
}

///|
/// Find character in string
fn find_char(s : String, target : Char, start : Int) -> Int {
  let mut i = start
  while i < s.length() {
    match s.get(i) {
      Some(ch) => if Char::from_int(ch) == target { return i }
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
        let c = Char::from_int(ch)
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
