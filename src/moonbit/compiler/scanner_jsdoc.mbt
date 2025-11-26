// JSDoc Tag Parsing
// Extracted from scanner.mbt to improve code organization
//
// This module contains all JSDoc parsing logic:
// - ParsedJSDocTag: Tag types enum
// - ParsedJSDoc: Parsed comment structure
// - parse_jsdoc: Main parsing function
// - Various helper functions for parsing specific tags

///|
/// Parsed JSDoc tag types (scanner-level, distinct from AST types)
pub enum ParsedJSDocTag {
  Param(ParsedJSDocParam) // @param {type} name description
  Returns(ParsedJSDocType) // @returns {type} description
  Type(ParsedJSDocType) // @type {type}
  TypeDef(ParsedJSDocTypeDef) // @typedef {type} name
  Template(Array[String]) // @template T, U
  Deprecated(String?) // @deprecated [reason]
  Example(String) // @example
  See(String) // @see reference
  Author(String) // @author name
  Since(String) // @since version
  Throws(ParsedJSDocType) // @throws {type} description
  Private // @private
  Public // @public
  Protected // @protected
  Readonly // @readonly
  Override // @override
  Abstract // @abstract
  Other(String, String) // Unknown tag
} derive(Show, Eq)

///|
/// Parsed JSDoc param tag
pub struct ParsedJSDocParam {
  name : String
  type_annotation : String?
  description : String
  is_optional : Bool
} derive(Show, Eq)

///|
/// Parsed JSDoc type tag (for @returns, @type, @throws)
pub struct ParsedJSDocType {
  type_annotation : String?
  description : String
} derive(Show, Eq)

///|
/// Parsed JSDoc typedef tag
pub struct ParsedJSDocTypeDef {
  name : String
  type_annotation : String?
  description : String
} derive(Show, Eq)

///|
/// Parsed JSDoc comment
pub struct ParsedJSDoc {
  description : String
  tags : Array[ParsedJSDocTag]
} derive(Show, Eq)

///|
/// Parse a JSDoc comment content into structured form
pub fn parse_jsdoc(content : String) -> ParsedJSDoc {
  let lines = split_lines(content)
  let mut description = ""
  let tags : Array[ParsedJSDocTag] = []
  let mut in_description = true
  let mut current_tag_lines : Array[String] = []
  let mut current_tag_name = ""
  for line in lines {
    let trimmed = trim_jsdoc_line_scanner(line)

    // Check if line starts a new tag
    if trimmed.length() > 0 && starts_with_char(trimmed, '@') {
      // Process previous tag if any
      if current_tag_name.length() > 0 {
        let tag = parse_jsdoc_tag_scanner(
          current_tag_name,
          join_lines(current_tag_lines),
        )
        tags.push(tag)
      }

      // Start new tag
      in_description = false
      let (tag_name, rest) = extract_tag_name_scanner(trimmed)
      current_tag_name = tag_name
      current_tag_lines = [rest]
    } else if in_description {
      if description.length() > 0 {
        description = description + "\n" + trimmed
      } else {
        description = trimmed
      }
    } else {
      // Continuation of current tag
      current_tag_lines.push(trimmed)
    }
  }

  // Process last tag if any
  if current_tag_name.length() > 0 {
    let tag = parse_jsdoc_tag_scanner(
      current_tag_name,
      join_lines(current_tag_lines),
    )
    tags.push(tag)
  }
  { description: description.trim_space(), tags }
}

///|
/// Split content into lines
fn split_lines(content : String) -> Array[String] {
  let lines : Array[String] = []
  let mut current = ""
  for i = 0; i < content.length(); i = i + 1 {
    match content.get(i) {
      Some(code) => {
        let ch = code.unsafe_to_char()
        if ch == '\n' {
          lines.push(current)
          current = ""
        } else {
          current = current + Char::to_string(ch)
        }
      }
      None => ()
    }
  }
  if current.length() > 0 {
    lines.push(current)
  }
  lines
}

///|
/// Trim JSDoc line (remove leading *, whitespace)
fn trim_jsdoc_line_scanner(line : String) -> String {
  let mut start = 0

  // Skip leading whitespace
  while start < line.length() {
    match line.get(start) {
      Some(code) => {
        let ch = code.unsafe_to_char()
        if ch == ' ' || ch == '\t' {
          start = start + 1
        } else {
          break
        }
      }
      None => break
    }
  }

  // Skip leading *
  if start < line.length() {
    match line.get(start) {
      Some(code) =>
        if code.unsafe_to_char() == '*' {
          start = start + 1
          // Skip whitespace after *
          while start < line.length() {
            match line.get(start) {
              Some(code2) => {
                let ch = code2.unsafe_to_char()
                if ch == ' ' || ch == '\t' {
                  start = start + 1
                } else {
                  break
                }
              }
              None => break
            }
          }
        }
      None => ()
    }
  }
  line.substring(start~, end=line.length())
}

///|
/// Check if string starts with a character
fn starts_with_char(s : String, ch : Char) -> Bool {
  match s.get(0) {
    Some(code) => code.unsafe_to_char() == ch
    None => false
  }
}

///|
/// Extract tag name from line starting with @
fn extract_tag_name_scanner(line : String) -> (String, String) {
  let mut end = 1 // Start after @
  while end < line.length() {
    match line.get(end) {
      Some(code) => {
        let ch = code.unsafe_to_char()
        match ch {
          'a'..='z' | 'A'..='Z' | '0'..='9' | '-' | '_' => end = end + 1
          _ => break
        }
      }
      None => break
    }
  }
  let tag_name = line.substring(start=1, end~) // Skip @
  let rest = if end < line.length() {
    line.substring(start=end, end=line.length()).trim_space()
  } else {
    ""
  }
  (tag_name, rest)
}

///|
/// Join lines with space
fn join_lines(lines : Array[String]) -> String {
  let mut result = ""
  for i = 0; i < lines.length(); i = i + 1 {
    if i > 0 {
      result = result + " "
    }
    result = result + lines[i]
  }
  result
}

///|
/// Parse a single JSDoc tag
fn parse_jsdoc_tag_scanner(
  tag_name : String,
  content : String,
) -> ParsedJSDocTag {
  match tag_name {
    "param" | "arg" | "argument" => parse_param_tag(content)
    "returns" | "return" => parse_type_tag_as_returns(content)
    "type" => parse_type_tag_as_type(content)
    "typedef" => parse_typedef_tag(content)
    "template" => parse_template_tag(content)
    "deprecated" =>
      ParsedJSDocTag::Deprecated(
        if content.length() > 0 {
          Some(content)
        } else {
          None
        },
      )
    "example" => ParsedJSDocTag::Example(content)
    "see" => ParsedJSDocTag::See(content)
    "author" => ParsedJSDocTag::Author(content)
    "since" | "version" => ParsedJSDocTag::Since(content)
    "throws" | "exception" => parse_type_tag_as_throws(content)
    "private" => ParsedJSDocTag::Private
    "public" => ParsedJSDocTag::Public
    "protected" => ParsedJSDocTag::Protected
    "readonly" => ParsedJSDocTag::Readonly
    "override" => ParsedJSDocTag::Override
    "abstract" | "virtual" => ParsedJSDocTag::Abstract
    _ => ParsedJSDocTag::Other(tag_name, content)
  }
}

///|
/// Parse @param tag
fn parse_param_tag(content : String) -> ParsedJSDocTag {
  let (type_annotation, rest) = extract_type_annotation(content)
  let (name, is_optional, description) = extract_param_name(rest)
  ParsedJSDocTag::Param({ name, type_annotation, description, is_optional })
}

///|
/// Parse @returns tag
fn parse_type_tag_as_returns(content : String) -> ParsedJSDocTag {
  let (type_annotation, description) = extract_type_annotation(content)
  ParsedJSDocTag::Returns({ type_annotation, description })
}

///|
/// Parse @type tag
fn parse_type_tag_as_type(content : String) -> ParsedJSDocTag {
  let (type_annotation, description) = extract_type_annotation(content)
  ParsedJSDocTag::Type({ type_annotation, description })
}

///|
/// Parse @throws tag
fn parse_type_tag_as_throws(content : String) -> ParsedJSDocTag {
  let (type_annotation, description) = extract_type_annotation(content)
  ParsedJSDocTag::Throws({ type_annotation, description })
}

///|
/// Parse @typedef tag
fn parse_typedef_tag(content : String) -> ParsedJSDocTag {
  let (type_annotation, rest) = extract_type_annotation(content)
  let (name, description) = extract_first_word(rest)
  ParsedJSDocTag::TypeDef({ name, type_annotation, description })
}

///|
/// Parse @template tag
fn parse_template_tag(content : String) -> ParsedJSDocTag {
  let params : Array[String] = []
  let mut current = ""
  for i = 0; i < content.length(); i = i + 1 {
    match content.get(i) {
      Some(code) => {
        let ch = code.unsafe_to_char()
        match ch {
          ',' | ' ' =>
            if current.length() > 0 {
              params.push(current.trim_space())
              current = ""
            }
          _ => current = current + Char::to_string(ch)
        }
      }
      None => ()
    }
  }
  if current.length() > 0 {
    params.push(current.trim_space())
  }
  ParsedJSDocTag::Template(params)
}

///|
/// Extract type annotation from {type} prefix
fn extract_type_annotation(content : String) -> (String?, String) {
  let trimmed = content.trim_space()
  if not(starts_with_char(trimmed, '{')) {
    return (None, trimmed)
  }

  // Find matching }
  let mut depth = 0
  let mut end = 0
  for i = 0; i < trimmed.length(); i = i + 1 {
    match trimmed.get(i) {
      Some(code) => {
        let ch = code.unsafe_to_char()
        if ch == '{' {
          depth = depth + 1
        } else if ch == '}' {
          depth = depth - 1
          if depth == 0 {
            end = i
            break
          }
        }
      }
      None => ()
    }
  }
  if end == 0 {
    return (None, trimmed)
  }
  let type_str = trimmed.substring(start=1, end~) // Skip { and }
  let rest = trimmed.substring(start=end + 1, end=trimmed.length()).trim_space()
  (Some(type_str), rest)
}

///|
/// Extract param name (handles [name] for optional)
fn extract_param_name(content : String) -> (String, Bool, String) {
  let trimmed = content.trim_space()

  // Check for [name] optional syntax
  if starts_with_char(trimmed, '[') {
    let mut end = 1
    while end < trimmed.length() {
      match trimmed.get(end) {
        Some(code) => {
          if code.unsafe_to_char() == ']' {
            break
          }
          end = end + 1
        }
        None => break
      }
    }
    let name_part = trimmed.substring(start=1, end~)
    // Handle [name=default]
    let name = extract_before_equals(name_part)
    let description = trimmed
      .substring(start=end + 1, end=trimmed.length())
      .trim_space()
    return (name, true, description)
  }

  // Regular name
  let (name, description) = extract_first_word(trimmed)
  (name, false, description)
}

///|
/// Extract content before = (for optional params with defaults)
fn extract_before_equals(s : String) -> String {
  let mut end = 0
  while end < s.length() {
    match s.get(end) {
      Some(code) => {
        if code.unsafe_to_char() == '=' {
          break
        }
        end = end + 1
      }
      None => break
    }
  }
  s.substring(start=0, end~).trim_space()
}

///|
/// Extract first word from string
fn extract_first_word(s : String) -> (String, String) {
  let trimmed = s.trim_space()
  let mut end = 0
  while end < trimmed.length() {
    match trimmed.get(end) {
      Some(code) => {
        let ch = code.unsafe_to_char()
        if ch == ' ' || ch == '\t' || ch == '\n' || ch == '-' {
          break
        }
        end = end + 1
      }
      None => break
    }
  }
  let word = trimmed.substring(start=0, end~)
  let rest = trimmed.substring(start=end, end=trimmed.length()).trim_space()

  // Remove leading - from description
  let rest = if starts_with_char(rest, '-') {
    rest.substring(start=1, end=rest.length()).trim_space()
  } else {
    rest
  }
  (word, rest)
}

///|
/// Helper to trim whitespace from string
fn String::trim_space(self : String) -> String {
  let mut start = 0
  let mut end = self.length()

  // Find start
  while start < end {
    match self.get(start) {
      Some(code) => {
        let ch = code.unsafe_to_char()
        if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
          start = start + 1
        } else {
          break
        }
      }
      None => break
    }
  }

  // Find end
  while end > start {
    match self.get(end - 1) {
      Some(code) => {
        let ch = code.unsafe_to_char()
        if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
          end = end - 1
        } else {
          break
        }
      }
      None => break
    }
  }
  self.substring(start~, end~)
}
