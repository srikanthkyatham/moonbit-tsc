// Baseline Parser for E2E Tests
// Parses baseline files with //// [filename] //// sections

///|
/// Sections parsed from a baseline file
pub(all) struct BaselineSections {
  sections : Map[String, String]
} derive(Show)

///|
/// Parse a baseline file into sections
pub fn parse_baseline_file(content : String) -> BaselineSections {
  let sections : Map[String, String] = Map::new()
  let lines = content.split("\n")
  let mut current_filename = ""
  let mut current_lines : Array[String] = []

  for line in lines {
    let line_str = line.to_string()
    match parse_section_header(line_str) {
      Some(filename) => {
        // Save previous section if exists
        if current_filename.length() > 0 {
          let section_content = current_lines.iter().collect().join("\n")
          sections.set(current_filename, section_content)
          current_lines = []
        }
        current_filename = filename
      }
      None => {
        // Add line to current section
        if current_filename.length() > 0 {
          current_lines.push(line_str)
        }
      }
    }
  }

  // Save last section
  if current_filename.length() > 0 {
    let section_content = current_lines.iter().collect().join("\n")
    sections.set(current_filename, section_content)
  }

  { sections }
}

///|
/// Parse a section header line: "//// [filename] ////" -> Some(filename)
fn parse_section_header(line : String) -> String? {
  let trimmed = line.trim(chars=" \t").to_string()
  if not(trimmed.has_prefix("//// [")) {
    return None
  }

  // Find "] ////"
  let start = 6 // length of "//// ["
  match find_substring(trimmed, "] ////") {
    Some(end_pos) => {
      if end_pos > start {
        Some(trimmed.substring(start=start, end=end_pos))
      } else {
        None
      }
    }
    None => {
      // Try to find just "]" for older format
      match find_char_bp(trimmed, ']') {
        Some(end_pos) => {
          if end_pos > start {
            Some(trimmed.substring(start=start, end=end_pos))
          } else {
            None
          }
        }
        None => None
      }
    }
  }
}

///|
/// Find a substring in a string
fn find_substring(s : String, pattern : String) -> Int? {
  let pattern_len = pattern.length()
  if pattern_len == 0 || s.length() < pattern_len {
    return None
  }
  for i = 0; i <= s.length() - pattern_len; i = i + 1 {
    let mut matches = true
    for j = 0; j < pattern_len; j = j + 1 {
      if s[i + j] != pattern[j] {
        matches = false
        break
      }
    }
    if matches {
      return Some(i)
    }
  }
  None
}

///|
/// Find the first occurrence of a character in a string
fn find_char_bp(s : String, c : Char) -> Int? {
  let chars = s.to_array()
  for i = 0; i < chars.length(); i = i + 1 {
    if chars[i] == c {
      return Some(i)
    }
  }
  None
}

///|
/// Generate baseline filename from test name and variant
pub fn generate_baseline_filename(
  test_name : String,
  variant : TestVariant,
  extension : String
) -> String {
  let param_string = variant.to_param_string()
  if param_string.length() > 0 {
    test_name + param_string + extension
  } else {
    test_name + extension
  }
}

// Tests
test "parse section header" {
  let result = parse_section_header("//// [test.ts] ////")
  assert_eq(result, Some("test.ts"))
}

test "parse section header with js extension" {
  let result = parse_section_header("//// [test.js] ////")
  assert_eq(result, Some("test.js"))
}

test "parse baseline file" {
  let content =
    #|//// [source.ts] ////
    #|export const x = 1;
    #|//// [output.js] ////
    #|exports.x = 1;
  let sections = parse_baseline_file(content)
  assert_true(sections.sections.get("source.ts").is_some())
  assert_true(sections.sections.get("output.js").is_some())
}

test "generate baseline filename without params" {
  let variant = TestVariant::default()
  let filename = generate_baseline_filename("mytest", variant, ".js")
  assert_eq(filename, "mytest.js")
}

test "generate baseline filename with params" {
  let variant = TestVariant::{ target: "es5", module_kind: "commonjs", declaration_map: None }
  let filename = generate_baseline_filename("mytest", variant, ".js")
  assert_eq(filename, "mytest(target=es5,module=commonjs).js")
}
