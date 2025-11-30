// Parser Error Detection Tests
// Tests that the parser correctly detects and reports TypeScript errors
// by parsing actual code that triggers specific error conditions

///|
/// Helper function to parse source code and return diagnostics
fn parse_and_get_errors(source : String) -> Array[@compiler.Diagnostic] {
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(_) => [] // No errors - parsing succeeded
    Err(diagnostics) => diagnostics
  }
}

///|
/// Helper to check if any diagnostic has a specific error code
fn has_error_code(diagnostics : Array[@compiler.Diagnostic], code : Int) -> Bool {
  for diag in diagnostics {
    if diag.code == code {
      return true
    }
  }
  false
}

///|
/// Helper to check if any diagnostic contains a specific message substring
fn has_error_message(
  diagnostics : Array[@compiler.Diagnostic],
  substring : String
) -> Bool {
  for diag in diagnostics {
    if diag.message.contains(substring) {
      return true
    }
  }
  false
}

// ============================================================================
// Rest Parameter Error Detection Tests
// ============================================================================

///|
test "parser error detection - TS1048 rest parameter cannot be optional" {
  // Rest parameter with optional marker should trigger TS1048
  let source = "function foo(...args?) { }"
  let errors = parse_and_get_errors(source)
  assert_true(has_error_code(errors, 1048))
  assert_true(has_error_message(errors, "rest parameter cannot be optional"))
}

///|
test "parser error detection - TS1049 rest parameter cannot have initializer" {
  // Rest parameter with default value should trigger TS1049
  let source = "function foo(...args = []) { }"
  let errors = parse_and_get_errors(source)
  assert_true(has_error_code(errors, 1049))
  assert_true(has_error_message(errors, "rest parameter cannot have an initializer"))
}

///|
test "parser error detection - TS1014 rest parameter must be last" {
  // Rest parameter followed by another parameter should trigger TS1014
  let source = "function foo(...args, last) { }"
  let errors = parse_and_get_errors(source)
  assert_true(has_error_code(errors, 1014))
  assert_true(has_error_message(errors, "rest parameter must be last"))
}

///|
test "parser error detection - TS1016 required param after optional" {
  // Required parameter after optional should trigger TS1016
  let source = "function foo(a?, b) { }"
  let errors = parse_and_get_errors(source)
  assert_true(has_error_code(errors, 1016))
  assert_true(has_error_message(errors, "required parameter cannot follow"))
}

///|
test "parser error detection - TS1016 required param after param with default" {
  // Required parameter after param with default should trigger TS1016
  let source = "function foo(a = 1, b) { }"
  let errors = parse_and_get_errors(source)
  assert_true(has_error_code(errors, 1016))
  assert_true(has_error_message(errors, "required parameter cannot follow"))
}

// ============================================================================
// Accessor Error Detection Tests
// ============================================================================

///|
test "parser error detection - TS1094 get accessor cannot have parameters" {
  // Getter with parameters should trigger TS1094
  let source =
    #|class Foo {
    #|  get value(x: number) { return this._value; }
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(has_error_code(errors, 1094))
  assert_true(has_error_message(errors, "accessor cannot have parameters"))
}

///|
test "parser error detection - TS1095 set accessor must have one parameter" {
  // Setter without parameters should trigger TS1095
  let source =
    #|class Foo {
    #|  set value() { }
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(has_error_code(errors, 1095))
  assert_true(has_error_message(errors, "set' accessor must have exactly one parameter"))
}

///|
test "parser error detection - TS1095 set accessor too many parameters" {
  // Setter with multiple parameters should trigger TS1095
  let source =
    #|class Foo {
    #|  set value(a, b) { }
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(has_error_code(errors, 1095))
  assert_true(has_error_message(errors, "set' accessor must have exactly one parameter"))
}

///|
test "parser error detection - TS1093 set accessor cannot have return type" {
  // Setter with return type should trigger TS1093
  let source =
    #|class Foo {
    #|  set value(v): void { }
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(has_error_code(errors, 1093))
  assert_true(has_error_message(errors, "set' accessor cannot have a return type"))
}

// ============================================================================
// Valid Code Should Not Produce Errors
// ============================================================================

///|
test "parser error detection - valid rest parameter" {
  // Valid rest parameter should not produce parameter errors
  let source = "function foo(a, b, ...args) { }"
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 1014)))
  assert_true(not(has_error_code(errors, 1048)))
  assert_true(not(has_error_code(errors, 1049)))
}

///|
test "parser error detection - valid optional parameters" {
  // Optional parameters at end should not produce errors
  let source = "function foo(a, b?, c?) { }"
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 1016)))
}

///|
test "parser error detection - valid default parameters" {
  // Default parameters at end should not produce errors
  let source = "function foo(a, b = 1, c = 2) { }"
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 1016)))
}

///|
test "parser error detection - valid getter" {
  // Getter without parameters should not produce errors
  let source =
    #|class Foo {
    #|  get value() { return this._value; }
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 1094)))
}

///|
test "parser error detection - valid setter" {
  // Setter with exactly one parameter should not produce errors
  let source =
    #|class Foo {
    #|  set value(v) { this._value = v; }
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 1093)))
  assert_true(not(has_error_code(errors, 1095)))
}

// ============================================================================
// Arrow Function Parameter Errors
// ============================================================================

///|
test "parser error detection - arrow function rest optional" {
  // Arrow function with optional rest parameter should trigger TS1048
  let source = "const foo = (...args?) => args;"
  let errors = parse_and_get_errors(source)
  assert_true(has_error_code(errors, 1048))
}

///|
test "parser error detection - arrow function required after optional" {
  // Arrow function with required after optional should trigger TS1016
  let source = "const foo = (a?, b) => a + b;"
  let errors = parse_and_get_errors(source)
  assert_true(has_error_code(errors, 1016))
}

// ============================================================================
// Method Parameter Errors
// ============================================================================

///|
test "parser error detection - method rest not last" {
  // Method with rest not last should trigger TS1014
  let source =
    #|class Foo {
    #|  bar(...args, last) { }
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(has_error_code(errors, 1014))
}

///|
test "parser error detection - method required after optional" {
  // Method with required after optional should trigger TS1016
  let source =
    #|class Foo {
    #|  bar(a?, b) { }
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(has_error_code(errors, 1016))
}

// ============================================================================
// Multiple Errors in Same Code
// ============================================================================

///|
test "parser error detection - multiple parameter errors" {
  // Code with multiple parameter errors
  let source = "function foo(a?, b, ...rest?) { }"
  let errors = parse_and_get_errors(source)
  // Should have TS1016 (required after optional)
  assert_true(has_error_code(errors, 1016))
  // Should have TS1048 (rest cannot be optional)
  assert_true(has_error_code(errors, 1048))
}

// ============================================================================
// Decorator Error Detection Tests
// ============================================================================

///|
test "parser error detection - TS1206 decorator on interface" {
  // Decorators are not valid on interfaces
  let source =
    #|@decorator
    #|interface Foo { }
  let errors = parse_and_get_errors(source)
  assert_true(has_error_code(errors, 1206))
  assert_true(has_error_message(errors, "Decorators are not valid here"))
}

///|
test "parser error detection - TS1206 decorator on type alias" {
  // Decorators are not valid on type aliases
  let source =
    #|@decorator
    #|type Foo = string;
  let errors = parse_and_get_errors(source)
  assert_true(has_error_code(errors, 1206))
  assert_true(has_error_message(errors, "Decorators are not valid here"))
}

///|
test "parser error detection - TS1206 decorator on enum" {
  // Decorators are not valid on enums
  let source =
    #|@decorator
    #|enum Color { Red, Green, Blue }
  let errors = parse_and_get_errors(source)
  assert_true(has_error_code(errors, 1206))
  assert_true(has_error_message(errors, "Decorators are not valid here"))
}

///|
test "parser error detection - TS1206 decorator on variable" {
  // Decorators are not valid on variable declarations
  let source =
    #|@decorator
    #|const x = 1;
  let errors = parse_and_get_errors(source)
  assert_true(has_error_code(errors, 1206))
  assert_true(has_error_message(errors, "Decorators are not valid here"))
}

///|
test "parser error detection - TS1206 decorator on let" {
  // Decorators are not valid on let declarations
  let source =
    #|@decorator
    #|let y = 2;
  let errors = parse_and_get_errors(source)
  assert_true(has_error_code(errors, 1206))
  assert_true(has_error_message(errors, "Decorators are not valid here"))
}

///|
test "parser error detection - valid decorator on class" {
  // Decorators ARE valid on classes - should not produce TS1206
  let source =
    #|@decorator
    #|class Foo { }
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 1206)))
}

///|
test "parser error detection - valid decorator on class method" {
  // Decorators ARE valid on class methods - should not produce TS1206
  let source =
    #|class Foo {
    #|  @decorator
    #|  bar() { }
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 1206)))
}

///|
test "parser error detection - valid decorator on class property" {
  // Decorators ARE valid on class properties - should not produce TS1206
  let source =
    #|class Foo {
    #|  @decorator
    #|  value: number;
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 1206)))
}

///|
test "parser error detection - valid decorator on class accessor" {
  // Decorators ARE valid on accessors - should not produce TS1206
  let source =
    #|class Foo {
    #|  @decorator
    #|  get value() { return 1; }
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 1206)))
}

// ============================================================================
// Module/Import Error Detection Tests
// ============================================================================

///|
test "parser error detection - TS1248 class member const" {
  // A class member cannot have the 'const' keyword
  let source =
    #|class Foo {
    #|  const x = 1;
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(has_error_code(errors, 1248))
  assert_true(has_error_message(errors, "const"))
}

///|
test "parser error detection - TS1440 import path not string literal" {
  // Import path must be a string literal
  let source =
    #|const path = "./module";
    #|import x from path;
  let errors = parse_and_get_errors(source)
  assert_true(has_error_code(errors, 1440))
  assert_true(has_error_message(errors, "import"))
}

///|
test "parser error detection - valid class method" {
  // Regular class methods should not trigger const error
  let source =
    #|class Foo {
    #|  bar() { return 1; }
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 1248)))
}

///|
test "parser error detection - valid import string literal" {
  // Import with string literal path is valid
  let source = "import x from './module';"
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 1440)))
}

// ============================================================================
// TS1432 Decorator After Export Error Detection Tests
// ============================================================================

///|
test "parser error detection - TS1432 decorator after export" {
  // Decorator after export keyword should trigger TS1432
  let source = "export @decorator class Foo { }"
  let errors = parse_and_get_errors(source)
  assert_true(has_error_code(errors, 1432))
  assert_true(has_error_message(errors, "Decorators must precede the name and all keywords"))
}

///|
test "parser error detection - valid decorator before export" {
  // Decorator before export is valid - should not produce TS1432
  let source = "@decorator export class Foo { }"
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 1432)))
}

// ============================================================================
// TS1243 Delete on Identifier Error Detection Tests
// ============================================================================

///|
test "parser error detection - TS1243 delete on identifier" {
  // delete on a plain identifier should trigger TS1243
  let source = "delete x;"
  let errors = parse_and_get_errors(source)
  assert_true(has_error_code(errors, 1243))
  assert_true(has_error_message(errors, "delete"))
}

///|
test "parser error detection - valid delete on property access" {
  // delete on property access is valid - should not produce TS1243
  let source = "delete obj.prop;"
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 1243)))
}

///|
test "parser error detection - valid delete on element access" {
  // delete on element access is valid - should not produce TS1243
  let source = "delete arr[0];"
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 1243)))
}

// ============================================================================
// TS1227 Type Assertion in Exponentiation Error Detection Tests
// ============================================================================

///|
test "parser error detection - TS1227 type assertion in exponentiation" {
  // Type assertion on left side of ** should trigger TS1227
  let source = "<number>x ** 2;"
  let errors = parse_and_get_errors(source)
  assert_true(has_error_code(errors, 1227))
  assert_true(has_error_message(errors, "type assertion"))
}

///|
test "parser error detection - TS1227 as expression in exponentiation" {
  // as expression on left side of ** should trigger TS1227
  let source = "(x as number) ** 2;"
  let errors = parse_and_get_errors(source)
  // Note: (x as number) is parenthesized, so it should not trigger TS1227
  assert_true(not(has_error_code(errors, 1227)))
}

///|
test "parser error detection - valid exponentiation without type assertion" {
  // Regular exponentiation should not produce TS1227
  let source = "x ** 2;"
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 1227)))
}
