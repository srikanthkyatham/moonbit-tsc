// Unit tests for contextual keywords in export/import statements
// Tests that "as", "from", "of", "type", etc. can be used as identifiers
// Uses helper functions from diagnostic_code_test.mbt:
// - check_source(source: String) -> CheckResult
// - get_diagnostics(result: CheckResult) -> Array[Diagnostic]

test "export { as } - contextual keyword as property name" {
  let source =
    #|let as = 100;
    #|export { as };

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should parse without errors (no TS1005 '}' expected)
  let has_parse_error = diagnostics.iter().any(fn(d) { d.code == 1005 })
  assert_false(has_parse_error)
}

test "export { as as return } - contextual keyword with reserved word alias" {
  let source =
    #|let as = 100;
    #|export { as as return };

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should parse without errors
  let has_parse_error = diagnostics.iter().any(fn(d) { d.code == 1005 || d.code == 1000 })
  assert_false(has_parse_error)
}

test "export { as as return, as } - multiple contextual keywords" {
  let source =
    #|let as = 100;
    #|export { as as return, as };

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should parse without errors
  let has_parse_error = diagnostics.iter().any(fn(d) { d.code == 1005 || d.code == 1000 })
  assert_false(has_parse_error)
}

test "import { as } - contextual keyword as binding" {
  let source =
    #|import { as } from "./module";

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should parse without errors
  let has_parse_error = diagnostics.iter().any(fn(d) { d.code == 1005 || d.code == 1000 })
  assert_false(has_parse_error)
}

test "import { as as as } - contextual keyword renamed to contextual keyword" {
  let source =
    #|import { as as as } from "./module";

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should parse without errors
  let has_parse_error = diagnostics.iter().any(fn(d) { d.code == 1005 || d.code == 1000 })
  assert_false(has_parse_error)
}

test "import * as as - namespace import with contextual keyword" {
  let source =
    #|import * as as from "./module";

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should parse without errors (no TS1003 Identifier expected)
  let has_parse_error = diagnostics.iter().any(fn(d) { d.code == 1003 })
  assert_false(has_parse_error)
}

test "export { from, of, type } - multiple contextual keywords" {
  let source =
    #|let from = 1, of = 2, type = 3;
    #|export { from, of, type };

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should parse without errors
  let has_parse_error = diagnostics.iter().any(fn(d) { d.code == 1005 })
  assert_false(has_parse_error)
}

test "import { from as to, of as type } - contextual keywords with aliases" {
  let source =
    #|import { from as to, of as type } from "./module";

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should parse without errors
  let has_parse_error = diagnostics.iter().any(fn(d) { d.code == 1005 || d.code == 1000 })
  assert_false(has_parse_error)
}

test "export { type type } - type keyword as both keyword and identifier" {
  let source =
    #|let type = 100;
    #|export { type type };

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should parse without errors
  let has_parse_error = diagnostics.iter().any(fn(d) { d.code == 1005 })
  assert_false(has_parse_error)
}

test "import { type as } - type import with contextual keyword name" {
  let source =
    #|import { type as } from "./module";

  let result = check_source(source)
  let diagnostics = get_diagnostics(result)

  // Should parse without errors
  let has_parse_error = diagnostics.iter().any(fn(d) { d.code == 1005 })
  assert_false(has_parse_error)
}
