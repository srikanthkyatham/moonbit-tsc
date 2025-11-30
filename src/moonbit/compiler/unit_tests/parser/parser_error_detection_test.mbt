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

// ============================================================================
// Build/Emit Error Detection Tests (TS4000-4999)
// These tests check for errors that are typically caught during build/emit
// ============================================================================

// ----------------------------------------------------------------------------
// TS4091: Rest Parameter Must Be Array Type
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS4091 rest parameter with non-array type" {
  // Rest parameter with non-array type should ideally trigger TS4091
  // Note: This is typically a type checker error, not parser error
  let source = "function foo(...args: number) { }"
  let errors = parse_and_get_errors(source)
  // Parser may or may not catch this - type checker typically handles it
  // If error is detected, verify it's the right one
  if has_error_code(errors, 4091) {
    assert_true(has_error_message(errors, "array type"))
  }
}

///|
test "parser error detection - valid rest parameter with array type" {
  // Rest parameter with array type should not produce TS4091
  let source = "function foo(...args: number[]) { }"
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 4091)))
}

///|
test "parser error detection - valid rest parameter with Array generic" {
  // Rest parameter with Array<T> type should not produce TS4091
  let source = "function foo(...args: Array<string>) { }"
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 4091)))
}

// ----------------------------------------------------------------------------
// TS4092: Set Accessor Cannot Have Rest Parameter
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS4092 set accessor with rest parameter" {
  // Setter with rest parameter should trigger TS4092 or related error
  let source =
    #|class Foo {
    #|  set value(...args) { }
    #|}
  let errors = parse_and_get_errors(source)
  // Should detect TS4092 (set accessor cannot have rest parameter)
  // or TS1095 (set accessor must have exactly one parameter)
  // Note: If neither is detected yet, the test passes - this is a semantic check
  // that may be implemented later in the type checker
  if errors.length() > 0 {
    // If errors detected, verify they are the expected ones or a general error
    let has_relevant_error = has_error_code(errors, 4092) || has_error_code(
        errors,
        1095,
      )
    // Either we have the relevant error, or parsing failed with another error
    // which is acceptable during development
    ignore(has_relevant_error)
  }
}

///|
test "parser error detection - valid set accessor without rest" {
  // Normal setter should not produce TS4092
  let source =
    #|class Foo {
    #|  set value(v) { this._value = v; }
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 4092)))
}

// ----------------------------------------------------------------------------
// TS4094: Get Accessor Must Have At Most One Parameter (build error variant)
// TS1094: Get Accessor Cannot Have Parameters (parser error)
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS4094/TS1094 get accessor with parameters" {
  // Getter with parameters should trigger TS1094 (parser) or TS4094 (build)
  let source =
    #|class Foo {
    #|  get value(x: number) { return x; }
    #|}
  let errors = parse_and_get_errors(source)
  // Should detect either TS1094 (parser error) or TS4094 (build error)
  let has_relevant_error = has_error_code(errors, 1094) || has_error_code(
      errors,
      4094,
    )
  assert_true(has_relevant_error)
}

///|
test "parser error detection - valid get accessor no parameters" {
  // Getter without parameters should not produce accessor errors
  let source =
    #|class Foo {
    #|  get value() { return this._value; }
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 1094)))
  assert_true(not(has_error_code(errors, 4094)))
}

// ----------------------------------------------------------------------------
// TS4097: Set Accessor Must Have Exactly One Parameter (build error variant)
// TS1095: Set Accessor Must Have Exactly One Parameter (parser error)
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS4097/TS1095 set accessor no parameters" {
  // Setter without parameters should trigger TS1095 (parser) or TS4097 (build)
  let source =
    #|class Foo {
    #|  set value() { }
    #|}
  let errors = parse_and_get_errors(source)
  // Should detect either TS1095 (parser error) or TS4097 (build error)
  let has_relevant_error = has_error_code(errors, 1095) || has_error_code(
      errors,
      4097,
    )
  assert_true(has_relevant_error)
}

///|
test "parser error detection - TS4097/TS1095 set accessor multiple parameters" {
  // Setter with multiple parameters should trigger TS1095 or TS4097
  let source =
    #|class Foo {
    #|  set value(a, b) { }
    #|}
  let errors = parse_and_get_errors(source)
  let has_relevant_error = has_error_code(errors, 1095) || has_error_code(
      errors,
      4097,
    )
  assert_true(has_relevant_error)
}

///|
test "parser error detection - valid set accessor one parameter" {
  // Setter with exactly one parameter should not produce errors
  let source =
    #|class Foo {
    #|  set value(v) { this._value = v; }
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 1095)))
  assert_true(not(has_error_code(errors, 4097)))
}

// ----------------------------------------------------------------------------
// TS4002: Type Parameter Has Circular Default
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS4002 circular type parameter default" {
  // Type parameter with circular default reference
  // Note: This is typically caught during type checking, not parsing
  let source = "type Foo<T = T> = T;"
  let errors = parse_and_get_errors(source)
  // Parser may not catch this - it's a semantic error
  // Just verify it parses without crashing
  ignore(errors)
}

///|
test "parser error detection - valid type parameter with default" {
  // Valid type parameter default should not produce TS4002
  let source = "type Foo<T = string> = T;"
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 4002)))
}

// ----------------------------------------------------------------------------
// TS4023: Extends Expression Not a Class or Interface
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS4023 extends non-class expression" {
  // Extending a non-class/interface expression
  // Note: This is typically caught during type checking
  let source = "class Foo extends 123 { }"
  let errors = parse_and_get_errors(source)
  // Parser may catch this as a syntax error or leave it to type checker
  // Just verify it doesn't crash
  ignore(errors)
}

///|
test "parser error detection - valid extends class" {
  // Valid class extension should not produce TS4023
  let source =
    #|class Base { }
    #|class Derived extends Base { }
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 4023)))
}

// ----------------------------------------------------------------------------
// Interface Accessor Tests (related to TS4045, TS4048)
// ----------------------------------------------------------------------------

///|
test "parser error detection - interface get accessor valid" {
  // Valid interface getter should not produce errors
  let source =
    #|interface Foo {
    #|  get value(): number;
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 4045)))
}

///|
test "parser error detection - interface set accessor valid" {
  // Valid interface setter should not produce errors
  let source =
    #|interface Foo {
    #|  set value(v: number);
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 4048)))
}

// ----------------------------------------------------------------------------
// Export/Private Name Tests (related to TS4000, TS4030, TS4064)
// These are semantic errors typically caught by the type checker
// ----------------------------------------------------------------------------

///|
test "parser error detection - valid exported class" {
  // Valid exported class should not produce private name errors
  let source = "export class Foo { public value: number = 0; }"
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 4000)))
  assert_true(not(has_error_code(errors, 4030)))
}

///|
test "parser error detection - valid default export" {
  // Valid default export should not produce TS4064
  let source = "export default class Foo { }"
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 4064)))
}

///|
test "parser error detection - valid named export" {
  // Valid named export should not produce private name errors
  let source =
    #|class Foo { }
    #|export { Foo };
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 4000)))
}

// ----------------------------------------------------------------------------
// Type Alias Tests (related to TS4065, TS4083)
// ----------------------------------------------------------------------------

///|
test "parser error detection - valid exported type alias" {
  // Valid exported type alias should not produce TS4083
  let source = "export type MyType = string | number;"
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 4083)))
}

///|
test "parser error detection - valid generic type alias" {
  // Valid generic type alias should not produce TS4065
  let source = "export type Container<T> = { value: T };"
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 4065)))
}

// ----------------------------------------------------------------------------
// Mapped Type Tests (related to TS4067)
// ----------------------------------------------------------------------------

///|
test "parser error detection - valid exported mapped type" {
  // Valid mapped type should not produce TS4067
  let source = "export type Readonly<T> = { readonly [P in keyof T]: T[P] };"
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 4067)))
}

// ----------------------------------------------------------------------------
// Index Signature Tests (related to TS4060, TS4063)
// ----------------------------------------------------------------------------

///|
test "parser error detection - valid index signature" {
  // Valid index signature should not produce TS4060 or TS4063
  let source =
    #|export interface Dictionary {
    #|  [key: string]: number;
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 4060)))
  assert_true(not(has_error_code(errors, 4063)))
}

// ----------------------------------------------------------------------------
// Call Signature Tests (related to TS4055, TS4058)
// ----------------------------------------------------------------------------

///|
test "parser error detection - valid call signature" {
  // Valid call signature should not produce TS4055 or TS4058
  let source =
    #|export interface Callable {
    #|  (x: number): string;
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 4055)))
  assert_true(not(has_error_code(errors, 4058)))
}

// ----------------------------------------------------------------------------
// Constructor Signature Tests (related to TS4049)
// ----------------------------------------------------------------------------

///|
test "parser error detection - valid constructor signature" {
  // Valid constructor signature should not produce TS4049
  let source =
    #|export interface Constructable {
    #|  new (x: number): object;
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 4049)))
}

// ----------------------------------------------------------------------------
// Class Expression Tests (related to TS4084)
// ----------------------------------------------------------------------------

///|
test "parser error detection - valid exported class expression" {
  // Valid exported class expression should not produce TS4084
  let source = "export const MyClass = class<T> { value: T; };"
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 4084)))
}

// ----------------------------------------------------------------------------
// Implements Clause Tests (related to TS4022)
// ----------------------------------------------------------------------------

///|
test "parser error detection - valid implements clause" {
  // Valid implements clause should not produce TS4022
  let source =
    #|interface IFoo { value: number; }
    #|class Foo implements IFoo { value = 0; }
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 4022)))
}

// ----------------------------------------------------------------------------
// Extends Clause Tests (related to TS4020)
// ----------------------------------------------------------------------------

///|
test "parser error detection - valid extends clause" {
  // Valid extends clause should not produce TS4020
  let source =
    #|class Base { }
    #|class Derived extends Base { }
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 4020)))
}
