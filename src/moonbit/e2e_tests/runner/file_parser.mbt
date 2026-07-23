// Multi-file Test Parser for E2E Tests
// Splits test content by // @filename: directives

///|
/// Parse multi-file test content into separate source units
/// Handles // @filename: directives to split content
pub fn parse_multi_file_test(
  content : String,
  _directives : TestDirectives,
  default_filename : String,
) -> Array[SourceUnit] {
  let source_files : Array[SourceUnit] = []
  let lines = content.split("\n")
  let mut current_filename : String? = None
  let mut current_lines : Array[String] = []
  for line in lines {
    let line_str = line.to_owned()
    let trimmed = line.trim(chars=" \t").to_owned()
    if is_filename_directive(trimmed) {
      // Save current file if exists
      match current_filename {
        Some(filename) =>
          if current_lines.length() > 0 {
            let file_content = current_lines.iter().collect().join("\n")
            source_files.push({ filename, content: file_content })
            current_lines = []
          }
        None => ()
      }
      // Start new file
      current_filename = Some(parse_filename_value(trimmed))
    } else if current_filename is Some(_) {
      // Add line to current file (skip other directives if no content yet)
      if !(is_other_directive(trimmed)) || current_lines.length() > 0 {
        current_lines.push(line_str)
      }
    }
  }

  // Save last file
  match current_filename {
    Some(filename) =>
      if current_lines.length() > 0 {
        let file_content = current_lines.iter().collect().join("\n")
        source_files.push({ filename, content: file_content })
      }
    None => ()
  }

  // If no @filename directives, treat as single file
  if source_files.length() == 0 {
    // Strip directive comments from content for single file
    let stripped = strip_directive_lines(content)
    source_files.push({ filename: default_filename, content: stripped })
  }
  source_files
}

///|
/// Check if a line is a @filename directive
fn is_filename_directive(line : String) -> Bool {
  line.has_prefix("// @filename:")
}

///|
/// Check if a line is some other directive (not @filename, e.g. @declaration, @target)
fn is_other_directive(line : String) -> Bool {
  line.has_prefix("// @") &&
  !(is_filename_directive(line)) &&
  !(line.has_prefix("// @ts-")) // Don't skip @ts-ignore etc.
}

///|
/// Parse the filename value from a @filename directive
fn parse_filename_value(line : String) -> String {
  // Find colon position
  match find_char(line, ':') {
    Some(pos) => {
      let start = pos + 1
      if start < line.length() {
        line[start:].to_owned().trim(chars=" \t").to_owned()
      } else {
        ""
      }
    }
    None => ""
  }
}

///|
/// Strip directive lines from content (for single-file tests)
fn strip_directive_lines(content : String) -> String {
  let lines = content.split("\n")
  let result_lines : Array[String] = []
  for line in lines {
    let line_str = line.to_owned()
    let trimmed = line.trim(chars=" \t").to_owned()
    // Keep if not a directive (except @ts-* directives which are runtime)
    if !(trimmed.has_prefix("// @")) || trimmed.has_prefix("// @ts-") {
      result_lines.push(line_str)
    }
  }
  result_lines.iter().collect().join("\n")
}

// Tests

///|
test "parse single file test" {
  let content = "export const x = 1;\nexport const y = 2;"
  let directives = TestDirectives::default()
  let files = parse_multi_file_test(content, directives, "test.ts")
  assert_eq(files.length(), 1)
  assert_eq(files[0].filename, "test.ts")
  assert_true(files[0].content.contains("export const x = 1;"))
}

///|
test "parse multi-file test" {
  let content =
    #|// @filename: a.ts
    #|export const a = 1;
    #|// @filename: b.ts
    #|export const b = 2;
  let directives = TestDirectives::default()
  directives.filenames = ["a.ts", "b.ts"]
  let files = parse_multi_file_test(content, directives, "test.ts")
  assert_eq(files.length(), 2)
  assert_eq(files[0].filename, "a.ts")
  assert_eq(files[1].filename, "b.ts")
}

///|
test "strip directive lines" {
  let content =
    #|// @declaration: true
    #|// @target: es5
    #|export const x = 1;
    #|export const y = 2;
  let stripped = strip_directive_lines(content)
  assert_false(stripped.contains("// @declaration"))
  assert_false(stripped.contains("// @target"))
  assert_true(stripped.contains("export const x = 1;"))
}
