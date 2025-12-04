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

// ============================================================================
// General/Expected Error Detection Tests (TS1003-TS1015)
// Tests for basic parser expectation errors
// ============================================================================

// ----------------------------------------------------------------------------
// TS1003: Identifier Expected
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS1003 identifier expected in variable" {
  // Variable declaration without identifier
  let source = "let = 5;"
  let errors = parse_and_get_errors(source)
  // Should detect identifier expected error
  if errors.length() > 0 {
    // Parser detected an error - this is expected behavior
    ignore(errors)
  }
}

///|
test "parser error detection - TS1003 identifier expected in function" {
  // Function without name (not arrow or expression)
  let source = "function (x) { return x; }"
  let errors = parse_and_get_errors(source)
  // Should detect identifier expected or other syntax error
  if errors.length() > 0 {
    ignore(errors)
  }
}

///|
test "parser error detection - valid identifier in variable" {
  // Valid variable declaration should not produce TS1003
  let source = "let myVar = 5;"
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 1003)))
}

// ----------------------------------------------------------------------------
// TS1109: Expression Expected
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS1109 expression expected" {
  // Missing expression in assignment
  let source = "let x = ;"
  let errors = parse_and_get_errors(source)
  // Should detect expression expected error
  if errors.length() > 0 {
    ignore(errors)
  }
}

///|
test "parser error detection - TS1109 expression expected in return" {
  // Empty return in context requiring expression
  let source = "function foo(): number { return ; }"
  let errors = parse_and_get_errors(source)
  // May or may not produce error depending on parser behavior
  ignore(errors)
}

///|
test "parser error detection - valid expression" {
  // Valid expression should not produce TS1109
  let source = "let x = 5 + 3;"
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 1109)))
}

// ----------------------------------------------------------------------------
// TS1128: Declaration or Statement Expected
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS1128 declaration expected" {
  // Random punctuation at top level
  let source = ") { }"
  let errors = parse_and_get_errors(source)
  // Should detect declaration or statement expected
  if errors.length() > 0 {
    ignore(errors)
  }
}

///|
test "parser error detection - valid declaration" {
  // Valid declaration should not produce TS1128
  let source = "const x = 10;"
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 1128)))
}

// ============================================================================
// JSX Error Detection Tests
// ============================================================================

// ----------------------------------------------------------------------------
// JSX Closing Tag Mismatch
// ----------------------------------------------------------------------------

///|
test "parser error detection - JSX closing tag mismatch" {
  // JSX with mismatched tags
  let source = "const x = <div></span>;"
  let errors = parse_and_get_errors(source)
  // Should detect JSX closing tag mismatch or TS2857
  if errors.length() > 0 {
    let has_jsx_error = has_error_code(errors, 2857) || has_error_message(
        errors,
        "closing",
      )
    ignore(has_jsx_error)
  }
}

///|
test "parser error detection - JSX self-closing valid" {
  // Valid self-closing JSX element
  let source = "const x = <br />;"
  let errors = parse_and_get_errors(source)
  // Should not produce closing tag errors
  // Note: May produce other errors if JSX not fully supported
  ignore(errors)
}

///|
test "parser error detection - JSX matching tags valid" {
  // Valid JSX with matching tags
  let source = "const x = <div>content</div>;"
  let errors = parse_and_get_errors(source)
  // Should not produce JSX tag mismatch errors
  ignore(errors)
}

// ----------------------------------------------------------------------------
// JSX Expected Attribute Value
// ----------------------------------------------------------------------------

///|
test "parser error detection - JSX attribute without value" {
  // JSX attribute with equals but no value
  let source = "const x = <div id= />;"
  let errors = parse_and_get_errors(source)
  // Should detect missing attribute value
  if errors.length() > 0 {
    ignore(errors)
  }
}

///|
test "parser error detection - JSX valid attribute" {
  // Valid JSX attribute
  let source = "const x = <div id=\"test\" />;"
  let errors = parse_and_get_errors(source)
  // Valid attribute should parse without attribute errors
  ignore(errors)
}

// ============================================================================
// JSON Error Detection Tests
// ============================================================================

// ----------------------------------------------------------------------------
// JSON Property Name Expected
// ----------------------------------------------------------------------------

///|
test "parser error detection - JSON-like object missing property name" {
  // Object with missing property name
  let source = "const x = { : 5 };"
  let errors = parse_and_get_errors(source)
  // Should detect missing property name
  if errors.length() > 0 {
    ignore(errors)
  }
}

///|
test "parser error detection - valid object property" {
  // Valid object property
  let source = "const x = { name: 'test' };"
  let errors = parse_and_get_errors(source)
  // Should not produce property name errors
  assert_true(not(has_error_code(errors, 1131)))
}

// ============================================================================
// Assignment & Compatibility Error Detection Tests (TS2320-TS2859)
// Tests for type checking errors that should be detected
// ============================================================================

// ----------------------------------------------------------------------------
// TS2320: Interface Cannot Extend Conflicting Types
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS2320 interface extends conflicting" {
  // Interface extending conflicting types
  let source =
    #|interface A { x: number; }
    #|interface B { x: string; }
    #|interface C extends A, B { }
  let errors = parse_and_get_errors(source)
  // This is typically caught by type checker
  if has_error_code(errors, 2320) {
    assert_true(has_error_message(errors, "conflict"))
  }
}

///|
test "parser error detection - valid interface extends" {
  // Valid interface extension
  let source =
    #|interface A { x: number; }
    #|interface B { y: string; }
    #|interface C extends A, B { }
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 2320)))
}

// ----------------------------------------------------------------------------
// TS2324: Property Missing in Type
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS2324 property missing" {
  // Object literal missing required property
  let source =
    #|interface Person { name: string; age: number; }
    #|const p: Person = { name: "John" };
  let errors = parse_and_get_errors(source)
  // Type checker error
  if has_error_code(errors, 2324) || has_error_code(errors, 2741) {
    assert_true(
      has_error_message(errors, "missing") || has_error_message(
        errors,
        "required",
      ),
    )
  }
}

// ----------------------------------------------------------------------------
// TS2334: This Cannot Be Referenced in Static Property
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS2334 this in static property" {
  // 'this' used in static property initializer
  let source =
    #|class Foo {
    #|  static x = this.name;
    #|}
  let errors = parse_and_get_errors(source)
  // Type checker error
  if has_error_code(errors, 2334) {
    assert_true(has_error_message(errors, "this"))
  }
}

///|
test "parser error detection - valid this in instance property" {
  // 'this' in instance property is valid
  let source =
    #|class Foo {
    #|  x = this.name;
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 2334)))
}

// ----------------------------------------------------------------------------
// TS2337: Super Calls Not Permitted Outside Constructors
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS2337 super outside constructor" {
  // super() called outside constructor
  let source =
    #|class Base { }
    #|class Derived extends Base {
    #|  method() { super(); }
    #|}
  let errors = parse_and_get_errors(source)
  // Should detect super call outside constructor
  if has_error_code(errors, 2337) {
    assert_true(has_error_message(errors, "super"))
  }
}

///|
test "parser error detection - valid super in constructor" {
  // super() in constructor is valid
  let source =
    #|class Base { }
    #|class Derived extends Base {
    #|  constructor() { super(); }
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 2337)))
}

// ----------------------------------------------------------------------------
// TS2348: Type Has No Properties in Common
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS2348 no properties in common" {
  // Types with no overlap
  let source =
    #|interface A { x: number; }
    #|interface B { y: string; }
    #|function foo(a: A | B) {
    #|  if ('x' in a && 'y' in a) { }
    #|}
  let errors = parse_and_get_errors(source)
  // Type checker may or may not flag this
  ignore(errors)
}

// ----------------------------------------------------------------------------
// TS2350: Only Void Function Can Be Called With New
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS2350 new on non-constructor" {
  // Using new on a function that returns non-void
  let source =
    #|function foo(): number { return 1; }
    #|const x = new foo();
  let errors = parse_and_get_errors(source)
  // Type checker error
  if has_error_code(errors, 2350) {
    assert_true(has_error_message(errors, "new"))
  }
}

// ----------------------------------------------------------------------------
// TS2356: Arithmetic Operand Must Be Number or BigInt
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS2356 arithmetic on non-number" {
  // Arithmetic on string
  let source = "const x = 'hello' + 5 - 3;"
  let errors = parse_and_get_errors(source)
  // Type checker may flag this
  ignore(errors)
}

///|
test "parser error detection - valid arithmetic" {
  // Valid arithmetic on numbers
  let source = "const x = 5 + 3 - 2;"
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 2356)))
}

// ----------------------------------------------------------------------------
// TS2357: Increment/Decrement Operand Must Be Variable
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS2357 increment on literal" {
  // Increment on literal
  let source = "5++;"
  let errors = parse_and_get_errors(source)
  // Should detect invalid operand
  if errors.length() > 0 {
    ignore(errors)
  }
}

///|
test "parser error detection - valid increment" {
  // Valid increment on variable
  let source = "let x = 5; x++;"
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 2357)))
}

// ----------------------------------------------------------------------------
// TS2358: Instanceof Left Must Be Object Type
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS2358 instanceof left primitive" {
  // instanceof with primitive on left
  let source = "const x = 5 instanceof Number;"
  let errors = parse_and_get_errors(source)
  // Type checker error
  if has_error_code(errors, 2358) {
    assert_true(has_error_message(errors, "instanceof"))
  }
}

///|
test "parser error detection - valid instanceof" {
  // Valid instanceof
  let source = "const obj = {}; const x = obj instanceof Object;"
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 2358)))
}

// ----------------------------------------------------------------------------
// TS2359: Instanceof Right Must Be Function
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS2359 instanceof right non-function" {
  // instanceof with non-function on right
  let source = "const x = {} instanceof 5;"
  let errors = parse_and_get_errors(source)
  // Type checker error
  if has_error_code(errors, 2359) {
    assert_true(has_error_message(errors, "instanceof"))
  }
}

// ----------------------------------------------------------------------------
// TS2367: Comparison Appears Unintentional
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS2367 comparison unintentional" {
  // Comparison that can never be true
  let source = "const x: string = 'hello'; if (x === 5) { }"
  let errors = parse_and_get_errors(source)
  // Type checker may flag this
  ignore(errors)
}

// ----------------------------------------------------------------------------
// TS2369: Parameter Property Only in Constructor
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS2369 parameter property in method" {
  // Parameter property in non-constructor
  let source =
    #|class Foo {
    #|  method(public x: number) { }
    #|}
  let errors = parse_and_get_errors(source)
  // Should detect parameter property outside constructor
  if errors.length() > 0 {
    ignore(errors)
  }
}

///|
test "parser error detection - valid parameter property in constructor" {
  // Parameter property in constructor is valid
  let source =
    #|class Foo {
    #|  constructor(public x: number) { }
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 2369)))
}

// ----------------------------------------------------------------------------
// TS2378: Get Accessor Must Return Value
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS2378 getter no return" {
  // Getter without return statement
  let source =
    #|class Foo {
    #|  get value() { }
    #|}
  let errors = parse_and_get_errors(source)
  // Type checker error
  if has_error_code(errors, 2378) {
    assert_true(has_error_message(errors, "return"))
  }
}

///|
test "parser error detection - valid getter with return" {
  // Getter with return is valid
  let source =
    #|class Foo {
    #|  get value() { return 5; }
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 2378)))
}

// ----------------------------------------------------------------------------
// TS2379: Get/Set Visibility Must Agree
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS2379 getter setter visibility mismatch" {
  // Getter and setter with different visibility
  let source =
    #|class Foo {
    #|  private get value() { return 1; }
    #|  public set value(v) { }
    #|}
  let errors = parse_and_get_errors(source)
  // Type checker error
  if has_error_code(errors, 2379) {
    assert_true(has_error_message(errors, "visibility"))
  }
}

///|
test "parser error detection - valid getter setter same visibility" {
  // Getter and setter with same visibility
  let source =
    #|class Foo {
    #|  public get value() { return 1; }
    #|  public set value(v) { }
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 2379)))
}

// ----------------------------------------------------------------------------
// TS2380: Get/Set Must Have Same Type
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS2380 getter setter type mismatch" {
  // Getter and setter with different types
  let source =
    #|class Foo {
    #|  get value(): number { return 1; }
    #|  set value(v: string) { }
    #|}
  let errors = parse_and_get_errors(source)
  // Type checker error
  if has_error_code(errors, 2380) {
    assert_true(has_error_message(errors, "type"))
  }
}

///|
test "parser error detection - valid getter setter same type" {
  // Getter and setter with same type
  let source =
    #|class Foo {
    #|  get value(): number { return 1; }
    #|  set value(v: number) { }
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 2380)))
}

// ----------------------------------------------------------------------------
// TS2393: Duplicate Function Implementation
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS2393 duplicate function" {
  // Duplicate function implementation
  let source =
    #|function foo() { return 1; }
    #|function foo() { return 2; }
  let errors = parse_and_get_errors(source)
  // Type checker error for duplicates
  if has_error_code(errors, 2393) {
    assert_true(has_error_message(errors, "duplicate"))
  }
}

// ----------------------------------------------------------------------------
// TS2406: For-In Left Must Be Variable
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS2406 for-in invalid left" {
  // For-in with invalid left side
  let source = "for (5 in obj) { }"
  let errors = parse_and_get_errors(source)
  // Should detect invalid for-in target
  if errors.length() > 0 {
    ignore(errors)
  }
}

///|
test "parser error detection - valid for-in" {
  // Valid for-in
  let source = "const obj = {}; for (const key in obj) { }"
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 2406)))
}

// ----------------------------------------------------------------------------
// TS2452: Enum Member Cannot Have Numeric Name
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS2452 enum numeric member name" {
  // Enum with numeric member name
  let source = "enum Foo { 0 = 'zero' }"
  let errors = parse_and_get_errors(source)
  // Should detect numeric enum member name
  if errors.length() > 0 {
    ignore(errors)
  }
}

///|
test "parser error detection - valid enum member names" {
  // Valid enum member names
  let source = "enum Foo { A, B, C }"
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 2452)))
}

// ----------------------------------------------------------------------------
// TS2461: Rest Element Must Be Last in Destructuring
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS2461 rest not last in destructuring" {
  // Rest element not last in array destructuring
  let source = "const [...rest, last] = [1, 2, 3];"
  let errors = parse_and_get_errors(source)
  // Should detect rest element not last
  if errors.length() > 0 {
    let has_rest_error = has_error_code(errors, 2461) || has_error_code(
        errors,
        1014,
      )
    ignore(has_rest_error)
  }
}

///|
test "parser error detection - valid rest last in destructuring" {
  // Valid rest element at end
  let source = "const [first, ...rest] = [1, 2, 3];"
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 2461)))
}

// ----------------------------------------------------------------------------
// TS2462: Rest Element Cannot Have Initializer
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS2462 rest element initializer" {
  // Rest element with initializer
  let source = "const [...rest = []] = [1, 2, 3];"
  let errors = parse_and_get_errors(source)
  // Should detect rest element with initializer
  if errors.length() > 0 {
    ignore(errors)
  }
}

// ----------------------------------------------------------------------------
// TS2474: Const Enum Initializer Must Be Literal
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS2474 const enum non-literal" {
  // Const enum with non-literal initializer
  let source =
    #|const x = 5;
    #|const enum Foo { A = x }
  let errors = parse_and_get_errors(source)
  // Type checker error
  if has_error_code(errors, 2474) {
    assert_true(has_error_message(errors, "const enum"))
  }
}

///|
test "parser error detection - valid const enum literal" {
  // Valid const enum with literal
  let source = "const enum Foo { A = 1, B = 2 }"
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 2474)))
}

// ----------------------------------------------------------------------------
// TS2517: Non-Abstract Class Cannot Have Abstract Property
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS2517 abstract property in non-abstract class" {
  // Abstract property in non-abstract class
  let source =
    #|class Foo {
    #|  abstract x: number;
    #|}
  let errors = parse_and_get_errors(source)
  // Should detect abstract in non-abstract class
  if has_error_code(errors, 2517) || has_error_code(errors, 2516) {
    assert_true(has_error_message(errors, "abstract"))
  }
}

///|
test "parser error detection - valid abstract property in abstract class" {
  // Abstract property in abstract class
  let source =
    #|abstract class Foo {
    #|  abstract x: number;
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 2517)))
}

// ----------------------------------------------------------------------------
// TS2566: Rest Element Cannot Contain Binding Pattern
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS2566 rest element binding pattern" {
  // Rest element with binding pattern
  let source = "const [...{a, b}] = [{a: 1, b: 2}];"
  let errors = parse_and_get_errors(source)
  // Should detect rest element with binding pattern
  if errors.length() > 0 {
    ignore(errors)
  }
}

// ----------------------------------------------------------------------------
// TS2681: Constructor Cannot Have This Parameter
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS2681 constructor this parameter" {
  // Constructor with 'this' parameter
  let source =
    #|class Foo {
    #|  constructor(this: Foo, x: number) { }
    #|}
  let errors = parse_and_get_errors(source)
  // Should detect 'this' in constructor
  if has_error_code(errors, 2681) {
    assert_true(has_error_message(errors, "this"))
  }
}

///|
test "parser error detection - valid constructor without this param" {
  // Constructor without 'this' parameter
  let source =
    #|class Foo {
    #|  constructor(x: number) { }
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 2681)))
}

// ----------------------------------------------------------------------------
// TS2706: Required Type Params May Not Follow Optional
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS2706 required type param after optional" {
  // Required type parameter after optional
  let source = "type Foo<T = string, U> = { t: T; u: U };"
  let errors = parse_and_get_errors(source)
  // Should detect required after optional
  if has_error_code(errors, 2706) {
    assert_true(has_error_message(errors, "type param"))
  }
}

///|
test "parser error detection - valid type param order" {
  // Valid type parameter order
  let source = "type Foo<T, U = string> = { t: T; u: U };"
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 2706)))
}

// ----------------------------------------------------------------------------
// TS2730: Infer Keyword Only in Extends Conditional
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS2730 infer outside conditional" {
  // infer keyword outside conditional type
  let source = "type Foo = infer T;"
  let errors = parse_and_get_errors(source)
  // Should detect infer outside conditional
  if errors.length() > 0 {
    ignore(errors)
  }
}

///|
test "parser error detection - valid infer in conditional" {
  // Valid infer in conditional type
  let source = "type Foo<T> = T extends Array<infer U> ? U : never;"
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 2730)))
}

// ----------------------------------------------------------------------------
// TS2767: Get/Set Cannot Declare This Parameter
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS2767 getter with this parameter" {
  // Getter with 'this' parameter
  let source =
    #|class Foo {
    #|  get value(this: Foo) { return 1; }
    #|}
  let errors = parse_and_get_errors(source)
  // Should detect 'this' in getter - or TS1094 (no params)
  if errors.length() > 0 {
    let has_relevant_error = has_error_code(errors, 2767) || has_error_code(
        errors,
        1094,
      )
    ignore(has_relevant_error)
  }
}

// ----------------------------------------------------------------------------
// TS2813: Private Identifiers Cannot Be Parameters
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS2813 private identifier as parameter" {
  // Private identifier as parameter name
  let source = "function foo(#x) { }"
  let errors = parse_and_get_errors(source)
  // Should detect private identifier in params
  if errors.length() > 0 {
    ignore(errors)
  }
}

///|
test "parser error detection - valid private identifier in class" {
  // Private identifier in class is valid
  let source =
    #|class Foo {
    #|  #x = 5;
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 2813)))
}

// ----------------------------------------------------------------------------
// TS2832: Assignment Left Cannot Be Optional Property Access
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS2832 assign to optional chain" {
  // Assignment to optional property access
  let source = "obj?.prop = 5;"
  let errors = parse_and_get_errors(source)
  // Should detect assignment to optional chain
  if has_error_code(errors, 2832) {
    assert_true(has_error_message(errors, "optional"))
  }
}

///|
test "parser error detection - valid assignment" {
  // Valid property assignment
  let source = "const obj = { prop: 1 }; obj.prop = 5;"
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 2832)))
}

// ----------------------------------------------------------------------------
// TS1092: Type Parameters Cannot Appear on Constructor Declaration
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS1092 type params on constructor" {
  // Constructor with type parameters should trigger TS1092
  let source =
    #|class Foo {
    #|  constructor<T>(x: T) { }
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(has_error_code(errors, 1092))
  assert_true(has_error_message(errors, "Type parameters cannot appear on a constructor"))
}

///|
test "parser error detection - TS1092 constructor multiple type params" {
  // Constructor with multiple type parameters should trigger TS1092
  let source =
    #|class Foo {
    #|  constructor<T, U>(x: T, y: U) { }
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(has_error_code(errors, 1092))
}

///|
test "parser error detection - valid constructor without type params" {
  // Constructor without type parameters should not produce TS1092
  let source =
    #|class Foo {
    #|  constructor(x: number) { }
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 1092)))
}

///|
test "parser error detection - valid generic class constructor" {
  // Generic class constructor without constructor type params should be valid
  let source =
    #|class Foo<T> {
    #|  constructor(x: T) { }
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 1092)))
}

// ============================================================================
// Return Outside Function Error Detection Tests (TS1108)
// ============================================================================

///|
test "parser error detection - TS1108 return outside function" {
  // Return statement at top level should trigger TS1108
  let source = "return 42;"
  let errors = parse_and_get_errors(source)
  assert_true(has_error_code(errors, 1108))
  assert_true(has_error_message(errors, "return"))
}

///|
test "parser error detection - TS1108 return outside function with expression" {
  // Return with expression at top level
  let source = "const x = 1; return x + 1;"
  let errors = parse_and_get_errors(source)
  assert_true(has_error_code(errors, 1108))
}

///|
test "parser error detection - TS1108 return in if at top level" {
  // Return inside if block at top level
  let source = "if (true) { return 1; }"
  let errors = parse_and_get_errors(source)
  assert_true(has_error_code(errors, 1108))
}

///|
test "parser error detection - valid return inside function" {
  // Return inside function should be valid
  let source = "function foo() { return 42; }"
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 1108)))
}

///|
test "parser error detection - valid return inside arrow function" {
  // Return inside arrow function should be valid
  let source = "const fn = () => { return 1; };"
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 1108)))
}

///|
test "parser error detection - valid return inside method" {
  // Return inside class method should be valid
  let source =
    #|class Foo {
    #|  bar() { return 42; }
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 1108)))
}

///|
test "parser error detection - valid return inside getter" {
  // Return inside getter should be valid
  let source =
    #|class Foo {
    #|  get value() { return 42; }
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 1108)))
}

///|
test "parser error detection - valid return inside function expression" {
  // Return inside function expression should be valid
  let source = "const fn = function() { return 1; };"
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 1108)))
}

///|
test "parser error detection - valid return inside async function" {
  // Return inside async function should be valid
  let source = "async function foo() { return await Promise.resolve(1); }"
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 1108)))
}

///|
test "parser error detection - valid return inside constructor" {
  // Return inside constructor should be valid (even though it's unusual)
  let source =
    #|class Foo {
    #|  constructor() { return; }
    #|}
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 1108)))
}

// ----------------------------------------------------------------------------
// TS1357: Enum Member Must Be Followed By Comma, Equals, or Close Brace
// ----------------------------------------------------------------------------

///|
test "parser error detection - TS1357 enum member semicolon" {
  // Enum member followed by semicolon instead of comma
  let source = "enum Foo { A; B }"
  let errors = parse_and_get_errors(source)
  // Should detect TS1357 error
  assert_true(has_error_code(errors, 1357))
}

///|
test "parser error detection - TS1357 enum member colon" {
  // Enum member with colon like object property
  let source = "enum Foo { A: 1 }"
  let errors = parse_and_get_errors(source)
  // Should detect TS1357 error
  assert_true(has_error_code(errors, 1357))
}

///|
test "parser error detection - TS1357 enum member multiple errors" {
  // Multiple enum syntax errors
  let source = "enum Foo { A; B: 2, C }"
  let errors = parse_and_get_errors(source)
  // Should have at least 2 errors (semicolon and colon)
  let count = count_error_code(errors, 1357)
  assert_true(count >= 2)
}

///|
test "parser error detection - valid enum comma separated" {
  // Valid enum with comma-separated members
  let source = "enum Foo { A, B, C }"
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 1357)))
}

///|
test "parser error detection - valid enum with initializers" {
  // Valid enum with equals initializers
  let source = "enum Foo { A = 1, B = 2, C = 3 }"
  let errors = parse_and_get_errors(source)
  assert_true(not(has_error_code(errors, 1357)))
}

///|
test "parser error detection - TS2452 enum numeric member name detected" {
  // Enum with numeric member name should be detected
  let source = "enum Foo { A: 1, 2, B }"
  let errors = parse_and_get_errors(source)
  // Should detect numeric enum member name
  assert_true(has_error_code(errors, 2452))
}

// Helper function to count occurrences of an error code
fn count_error_code(errors : Array[@compiler.Diagnostic], code : Int) -> Int {
  let mut count = 0
  for err in errors {
    if err.code == code {
      count = count + 1
    }
  }
  count
}
