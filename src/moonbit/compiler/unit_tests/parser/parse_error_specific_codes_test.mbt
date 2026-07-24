// Specific Parse Error Code Tests
// Verifies that parse errors carry the same TSxxxx diagnostic codes that tsc
// emits, instead of the legacy generic TS1000 code.
//
// Codes covered:
//   TS1005 '{0}' expected.            (ExpectedToken and friends)
//   TS1109 Expression expected.       (primary-expression fallback)
//   TS1110 Type expected.
//   TS1128 Declaration or statement expected.  (statement-list recovery)
//   TS1135 Argument expression expected.       (argument-list recovery)
//   TS1141 String literal expected.   (module specifiers)
//   TS1472 'catch' or 'finally' expected.

///|
/// Parse source and collect all diagnostics (both fatal and recoverable)
fn parse_diags(source : String) -> Array[@compiler.Diagnostic] {
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) => source_file.parse_diagnostics
    Err(diagnostics) => diagnostics
  }
}

///|
fn has_code(diagnostics : Array[@compiler.Diagnostic], code : Int) -> Bool {
  for diag in diagnostics {
    if diag.code == code {
      return true
    }
  }
  false
}

///|
fn count_code(diagnostics : Array[@compiler.Diagnostic], code : Int) -> Int {
  let mut n = 0
  for diag in diagnostics {
    if diag.code == code {
      n += 1
    }
  }
  n
}

// ============================================================================
// TS1128: Declaration or statement expected
// ============================================================================

///|
test "TS1128 - stray close brace at top level" {
  let errors = parse_diags("class C {\n}\n}\nclass D {\n}")
  assert_true(has_code(errors, 1128))
  // The legacy generic code must not appear
  assert_false(has_code(errors, 1000))
}

///|
test "TS1128 - parsing continues after the stray token" {
  // Statements after the stray '}' must still be parsed (single error only)
  let errors = parse_diags("var a = 1;\n}\nvar b: string = 2;")
  assert_eq(count_code(errors, 1128), 1)
}

///|
test "TS1128 - stray close paren inside a block" {
  let errors = parse_diags("function f() {\n)\nvar x = 1;\n}")
  assert_true(has_code(errors, 1128))
  assert_false(has_code(errors, 1000))
}

// ============================================================================
// TS1109: Expression expected
// ============================================================================

///|
test "TS1109 - missing initializer expression" {
  let errors = parse_diags("var v = ;")
  assert_true(has_code(errors, 1109))
  assert_false(has_code(errors, 1000))
}

///|
test "TS1109 - missing binary operand" {
  let errors = parse_diags("a / finally")
  assert_true(has_code(errors, 1109))
  assert_false(has_code(errors, 1000))
}

///|
test "TS1109 - empty parenthesized expression" {
  let errors = parse_diags("var v = ()({});")
  assert_true(has_code(errors, 1109))
}

// ============================================================================
// TS1005: '{0}' expected
// ============================================================================

///|
test "TS1005 - 'while' expected after do body" {
  let errors = parse_diags("do { } 5;")
  assert_true(has_code(errors, 1005))
}

///|
test "TS1005 - 'from' expected in import declaration" {
  let errors = parse_diags("import { a } \"m\";")
  assert_true(has_code(errors, 1005))
  assert_false(has_code(errors, 1000))
}

///|
test "TS1005 - ',' expected between call arguments" {
  let errors = parse_diags("function f() { bar(a b); }")
  assert_true(has_code(errors, 1005))
}

///|
test "TS1005 - ')' expected when argument list hits semicolon" {
  let errors = parse_diags("function f() {\n   bar(;\n}")
  assert_true(has_code(errors, 1005))
  assert_false(has_code(errors, 1000))
}

// ============================================================================
// TS1110: Type expected
// ============================================================================

///|
test "TS1110 - missing type after colon" {
  let errors = parse_diags("let x: = 5;")
  assert_true(has_code(errors, 1110))
  assert_false(has_code(errors, 1000))
}

// ============================================================================
// TS1135: Argument expression expected
// ============================================================================

///|
test "TS1135 - statement keyword in argument position" {
  let errors = parse_diags("function foo() {\n   bar(\n   return x;\n}")
  assert_true(has_code(errors, 1135))
  assert_false(has_code(errors, 1000))
}

///|
test "TS1135 - missing argument before comma" {
  let errors = parse_diags("Foo(,")
  assert_true(has_code(errors, 1135))
  // and the unterminated list also reports ')' expected
  assert_true(has_code(errors, 1005))
}

// ============================================================================
// TS1141: String literal expected
// ============================================================================

///|
test "TS1141 - export from non-string module specifier" {
  let errors = parse_diags("export * from 123;")
  assert_true(has_code(errors, 1141))
  assert_false(has_code(errors, 1000))
}

// ============================================================================
// TS1472: 'catch' or 'finally' expected
// ============================================================================

///|
test "TS1472 - try without catch or finally" {
  let errors = parse_diags("try { }")
  assert_true(has_code(errors, 1472))
  assert_false(has_code(errors, 1000))
}

// ============================================================================
// Trailing commas in call argument lists are legal (no TS1109 regression)
// ============================================================================

///|
test "no error for trailing comma in argument list" {
  let errors = parse_diags("function f(a: number) { }\nf(1,);")
  assert_false(has_code(errors, 1109))
  assert_false(has_code(errors, 1005))
}

// ============================================================================
// Modifier keywords as class member names (parse_named_class_member routing)
// ============================================================================

///|
test "modifier keyword as static method name parses cleanly" {
  // tsc accepts `static public() {}` as a static method named 'public'
  let errors = parse_diags("class Outer\n{\nstatic public() {}\n}")
  assert_eq(errors.length(), 0)
}

///|
test "modifier keyword as property name parses cleanly" {
  let errors = parse_diags("class C {\n  public = 1;\n  private: string;\n}")
  assert_eq(errors.length(), 0)
}

// ============================================================================
// Definite assignment assertion: var t!: T (no spurious parse errors)
// ============================================================================

///|
test "definite assignment assertion parses cleanly" {
  let errors = parse_diags("function f<T>() {\n  var t!: T;\n}")
  assert_eq(errors.length(), 0)
}

///|
test "exclamation without type annotation still errors" {
  // `var t!;` is not a definite assignment assertion (no annotation);
  // tsc reports an error here too
  let errors = parse_diags("var t!;")
  assert_true(errors.length() > 0)
}

// ============================================================================
// ParserErrorCode name mappings for the new variants
// ============================================================================

///|
test "ExpectedToken maps to TS1005 with quoted token message" {
  assert_eq(
    @compiler.get_parser_error_int_with_arg("ExpectedToken", Some("=>")),
    1005,
  )
  assert_eq(
    @compiler.get_parser_error_message_with_arg("ExpectedToken", Some("=>")),
    "'=>' expected.",
  )
}

///|
test "CatchOrFinallyExpected maps to TS1472" {
  assert_eq(@compiler.get_parser_error_int("CatchOrFinallyExpected"), 1472)
  assert_eq(
    @compiler.get_parser_error_message("CatchOrFinallyExpected"),
    "'catch' or 'finally' expected.",
  )
}

// ============================================================================
// Decorators on non-decoratable declarations: TS1206 without a cascading
// TS1128. The parser must record "Decorators are not valid here." and keep
// parsing the declaration (dropping the decorators) instead of aborting and
// mis-parsing the body. (Conformance: decoratorOnEnum / decoratorOnInterface
// / decoratorOnInternalModule.)
// ============================================================================

///|
test "decorator on enum reports only TS1206 (no cascading TS1128)" {
  let diags = parse_diags("@dec\nenum E {}")
  assert_eq(count_code(diags, 1206), 1)
  assert_eq(count_code(diags, 1128), 0)
  assert_eq(count_code(diags, 1109), 0)
}

///|
test "decorator on interface reports only TS1206 (no cascading TS1128)" {
  let diags = parse_diags("@dec\ninterface I {}")
  assert_eq(count_code(diags, 1206), 1)
  assert_eq(count_code(diags, 1128), 0)
}

///|
test "decorator on namespace reports only TS1206 (no cascading TS1128)" {
  let diags = parse_diags("@dec\nnamespace N {}")
  assert_eq(count_code(diags, 1206), 1)
  assert_eq(count_code(diags, 1128), 0)
}

///|
test "decorator on type alias reports only TS1206 (no cascading TS1128)" {
  let diags = parse_diags("@dec\ntype T = number;")
  assert_eq(count_code(diags, 1206), 1)
  assert_eq(count_code(diags, 1128), 0)
}
