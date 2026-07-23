// Directive Parser for E2E Tests
// Parses // @directive: value comments from test files

///|
/// Parse all directives from test file content
pub fn parse_directives(content : String) -> TestDirectives {
  let directives = TestDirectives::default()
  let lines = content.split("\n")
  for line in lines {
    let trimmed = line.trim_start(chars=" \t").to_owned()
    // Match // @directive: value pattern
    if trimmed.has_prefix("// @") {
      match parse_directive_line(trimmed) {
        Some((name, value)) => {
          let lower_name = name.to_lower()
          if lower_name == "target" {
            directives.target = parse_comma_separated(value)
          } else if lower_name == "module" {
            directives.module_kind = parse_comma_separated(value)
          } else if lower_name == "declaration" {
            directives.declaration = parse_bool(value)
          } else if lower_name == "declarationmap" {
            directives.declaration_map = parse_bool_array(value)
          } else if lower_name == "sourcemap" {
            directives.source_map = parse_bool(value)
          } else if lower_name == "inlinesourcemap" {
            directives.inline_source_map = parse_bool(value)
          } else if lower_name == "inlinesources" {
            directives.inline_sources = parse_bool(value)
          } else if lower_name == "strict" {
            directives.strict = parse_bool(value)
          } else if lower_name == "noemit" {
            directives.no_emit = parse_bool(value)
          } else if lower_name == "jsx" {
            directives.jsx = value
          } else if lower_name == "filename" {
            directives.filenames.push(value)
          } else if lower_name == "esmoduleinterop" {
            directives.es_module_interop = parse_bool(value)
          } else if lower_name == "alwaysstrict" {
            directives.always_strict = parse_bool(value)
          } else if lower_name == "noimplicitany" {
            directives.no_implicit_any = parse_bool(value)
          } else if lower_name == "strictnullchecks" {
            directives.strict_null_checks = parse_bool(value)
          } else if lower_name == "verbatimmodulesyntax" {
            directives.verbatim_module_syntax = parse_bool(value)
          } else if lower_name == "isolatedmodules" {
            directives.isolated_modules = parse_bool(value)
          }
          // Ignore unrecognized directives
        }
        None => ()
      }
    }
  }
  directives
}

///|
/// Parse a single directive line: "// @name: value" -> Some((name, value))
fn parse_directive_line(line : String) -> (String, String)? {
  // Skip "// @" prefix (4 characters)
  if line.length() <= 4 {
    return None
  }
  let after_at = line[4:].to_owned()
  // Find the colon
  match find_char(after_at, ':') {
    Some(colon_pos) => {
      let name = after_at[:colon_pos].trim(chars=" \t").to_owned()
      let value = after_at[colon_pos + 1:].trim(chars=" \t").to_owned()
      Some((name, value))
    }
    None => None
  }
}

///|
/// Find the first occurrence of a character in a string
fn find_char(s : String, c : Char) -> Int? {
  let chars = s.to_array()
  for i = 0; i < chars.length(); i = i + 1 {
    if chars[i] == c {
      return Some(i)
    }
  }
  None
}

///|
/// Parse comma-separated values
fn parse_comma_separated(value : String) -> Array[String] {
  let parts = value.split(",")
  let result : Array[String] = []
  for part in parts {
    let trimmed = part.trim(chars=" \t").to_owned()
    if trimmed.length() > 0 {
      result.push(trimmed)
    }
  }
  result
}

///|
/// Parse boolean value
fn parse_bool(value : String) -> Bool {
  value.to_lower() == "true"
}

///|
/// Parse comma-separated boolean values
fn parse_bool_array(value : String) -> Array[Bool] {
  let parts = parse_comma_separated(value)
  let result : Array[Bool] = []
  for part in parts {
    result.push(parse_bool(part))
  }
  result
}

///|
/// Generate all variants from directives
pub fn generate_variants(directives : TestDirectives) -> Array[TestVariant] {
  // Get target values (default to es2015)
  let targets = if directives.target.length() > 0 {
    directives.target
  } else {
    ["es2015"]
  }

  // Get module values (default to esnext for transpile tests)
  let modules = if directives.module_kind.length() > 0 {
    directives.module_kind
  } else {
    ["esnext"]
  }

  // Get declarationMap values
  let decl_maps : Array[Bool?] = if directives.declaration_map.length() > 0 {
    directives.declaration_map.map(fn(b) { Some(b) })
  } else {
    [None]
  }

  // Generate cartesian product of all variants
  let variants : Array[TestVariant] = []
  for target in targets {
    for module_kind in modules {
      for decl_map in decl_maps {
        variants.push({ target, module_kind, declaration_map: decl_map })
      }
    }
  }
  variants
}

// Tests

///|
test "parse simple directive" {
  let content = "// @declaration: true\nexport const x = 1;"
  let directives = parse_directives(content)
  assert_true(directives.declaration)
}

///|
test "parse target with multiple values" {
  let content = "// @target: es2015,esnext\nexport const x = 1;"
  let directives = parse_directives(content)
  assert_eq(directives.target.length(), 2)
  assert_eq(directives.target[0], "es2015")
  assert_eq(directives.target[1], "esnext")
}

///|
test "parse multiple directives" {
  let content =
    #|// @declaration: true
    #|// @target: es6
    #|// @module: commonjs
    #|export const x = 1;
  let directives = parse_directives(content)
  assert_true(directives.declaration)
  assert_eq(directives.target.length(), 1)
  assert_eq(directives.target[0], "es6")
  assert_eq(directives.module_kind.length(), 1)
  assert_eq(directives.module_kind[0], "commonjs")
}

///|
test "parse declarationMap with boolean array" {
  let content = "// @declarationMap: true,false\nexport const x = 1;"
  let directives = parse_directives(content)
  assert_eq(directives.declaration_map.length(), 2)
  assert_true(directives.declaration_map[0])
  assert_false(directives.declaration_map[1])
}

///|
test "generate variants" {
  let directives = TestDirectives::{
    ..TestDirectives::default(),
    target: ["es2015", "esnext"],
    declaration_map: [true, false],
  }
  let variants = generate_variants(directives)
  // 2 targets * 1 module * 2 declarationMap = 4 variants
  assert_eq(variants.length(), 4)
}
