// Tagged Template Parsing Tests
// Tests for advanced tagged template features including:
// - Nested new expressions with tagged templates
// - Type arguments on tagged templates
// - Using 'declare' as a function name with tagged templates

///|
/// Helper function to parse source code and check if it succeeds
fn parse_succeeds(source : String) -> Bool {
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(_) => true
    Err(_) => false
  }
}

///|
test "parse nested new with tagged template - new new f`template`" {
  let code = "new new f `hello`;"
  assert_true(parse_succeeds(code))
}

///|
test "parse triple nested new with tagged template - new new new f`template`" {
  let code = "new new new f `hello`;"
  assert_true(parse_succeeds(code))
}

///|
test "parse new with tagged template and member access" {
  let code = "var f: any; new f `abc`.member;"
  assert_true(parse_succeeds(code))
}

///|
test "parse tagged template with type arguments - simple" {
  let code = "function f<T>(): void {} f<string> `hello`;"
  assert_true(parse_succeeds(code))
}

///|
test "parse tagged template with type arguments - declared function" {
  let code = "declare function f<T>(strs: TemplateStringsArray): void; f<string> `hello`;"
  assert_true(parse_succeeds(code))
}

///|
test "parse tagged template with type arguments - multiple type params" {
  let code = "function f<T, U>(): void {} f<string, number> `hello`;"
  assert_true(parse_succeeds(code))
}

///|
test "parse tagged template with type arguments and interpolation" {
  let code = "function f<T>(): void {} f<string> `hello ${42} world`;"
  assert_true(parse_succeeds(code))
}

///|
test "parse declare as function name" {
  let code = "function declare(x: any) {}"
  assert_true(parse_succeeds(code))
}

///|
test "parse declare as function name with tagged template" {
  let code = "function declare(x: any) {} declare `Hello`;"
  assert_true(parse_succeeds(code))
}

///|
test "parse declare as function name with template interpolation" {
  let code = "function declare(...x: any[]) {} declare `Hello ${0} world!`;"
  assert_true(parse_succeeds(code))
}

///|
test "parse declare statement still works" {
  let code = "declare const x: number;"
  assert_true(parse_succeeds(code))
}

///|
test "parse declare function still works" {
  let code = "declare function foo(): void;"
  assert_true(parse_succeeds(code))
}

///|
test "parse async as function name" {
  let code = "function async() {}"
  assert_true(parse_succeeds(code))
}

///|
test "parse using as function name" {
  let code = "function using() {}"
  assert_true(parse_succeeds(code))
}

///|
test "parse simple tagged template" {
  let code = "function tag(strs: TemplateStringsArray) {} tag `hello`;"
  assert_true(parse_succeeds(code))
}

///|
test "parse tagged template with interpolation" {
  let code = "function tag(strs: TemplateStringsArray, ...values: any[]) {} tag `hello ${42} world`;"
  assert_true(parse_succeeds(code))
}

///|
test "parse tagged template with multiple interpolations" {
  let code = "function tag(strs: TemplateStringsArray, ...values: any[]) {} tag `${1}${2}${3}`;"
  assert_true(parse_succeeds(code))
}

///|
test "parse chained tagged template" {
  let code = "function tag(strs: TemplateStringsArray): typeof tag { return tag; } tag `a` `b`;"
  assert_true(parse_succeeds(code))
}

// ============================================================================
// Embedded Expressions Tests - Object Literals and Functions in Templates
// ============================================================================

///|
test "parse template with embedded object literal" {
  let code = "var x = `abc${ { x: 10, y: 20 } }def`;"
  assert_true(parse_succeeds(code))
}

///|
test "parse template with embedded empty object" {
  let code = "var x = `abc${ {} }def`;"
  assert_true(parse_succeeds(code))
}

///|
test "parse template with embedded nested object" {
  let code = "var x = `abc${ { a: { b: 1 } } }def`;"
  assert_true(parse_succeeds(code))
}

///|
test "parse template with embedded function expression" {
  let code = "var x = `abc${ function y() { return y; } }def`;"
  assert_true(parse_succeeds(code))
}

///|
test "parse template with embedded arrow function" {
  let code = "var x = `abc${ () => { return 1; } }def`;"
  assert_true(parse_succeeds(code))
}

///|
test "parse template with embedded IIFE" {
  let code = "var x = `abc${ (function() { return 42; })() }def`;"
  assert_true(parse_succeeds(code))
}

///|
test "parse template with multiple embedded objects" {
  let code = "var x = `${ {a: 1} } middle ${ {b: 2} }`;"
  assert_true(parse_succeeds(code))
}

///|
test "parse template with object and function mixed" {
  let code = "var x = `${ {a: 1} } ${ function f() { return {b: 2}; } }`;"
  assert_true(parse_succeeds(code))
}

// ============================================================================
// Interface Method + Index Signature Tests (ASI fix)
// ============================================================================

///|
test "parse interface with method and index signature - no semicolon" {
  // Method without semicolon followed by index signature on new line
  // The [ should NOT be parsed as array suffix of void
  let code =
    #|interface I {
    #|    foo(): void
    #|    [x: number]: I;
    #|}
  assert_true(parse_succeeds(code))
}

///|
test "parse interface with method semicolon and index signature" {
  // Method with semicolon followed by index signature
  let code =
    #|interface I {
    #|    foo(): void;
    #|    [x: number]: I;
    #|}
  assert_true(parse_succeeds(code))
}

///|
test "parse interface with multiple methods and index signature" {
  // Multiple methods followed by index signature
  let code =
    #|interface I {
    #|    foo(): void
    #|    bar(): string
    #|    [x: string]: any;
    #|}
  assert_true(parse_succeeds(code))
}

///|
test "parse interface with property and index signature - no semicolon" {
  // Property without semicolon followed by index signature
  let code =
    #|interface I {
    #|    prop: number
    #|    [x: string]: number;
    #|}
  assert_true(parse_succeeds(code))
}

///|
test "parse type literal with property and index signature" {
  // Type literal version - using arrow function syntax for methods
  let code =
    #|type T = {
    #|    foo: () => void;
    #|    [x: number]: T;
    #|}
  assert_true(parse_succeeds(code))
}

///|
test "parse interface with generic method and index signature" {
  // Generic method followed by index signature
  let code =
    #|interface I {
    #|    foo<T>(): T
    #|    [x: number]: any;
    #|}
  assert_true(parse_succeeds(code))
}

///|
test "parse array type on same line is still valid" {
  // Array type suffix on same line should work
  let code =
    #|interface I {
    #|    foo(): void[];
    #|}
  assert_true(parse_succeeds(code))
}

///|
test "parse readonly index signature after method" {
  // Readonly index signature after method
  let code =
    #|interface I {
    #|    foo(): void
    #|    readonly [x: string]: number;
    #|}
  assert_true(parse_succeeds(code))
}

// ============================================================================
// Generic Function Type Tests - <T>(...) => T syntax
// ============================================================================

///|
test "parse generic function type - simple" {
  // Generic function type: <T>(x: T) => T
  let code = "type F = <T>(x: T) => T;"
  assert_true(parse_succeeds(code))
}

///|
test "parse generic function type - multiple type params" {
  // Generic function type: <T, U>(x: T, y: U) => [T, U]
  let code = "type F = <T, U>(x: T, y: U) => [T, U];"
  assert_true(parse_succeeds(code))
}

///|
test "parse generic function type - with constraints" {
  // Generic function type with constraint: <T extends object>(x: T) => T
  let code = "type F = <T extends object>(x: T) => T;"
  assert_true(parse_succeeds(code))
}

///|
test "parse generic function type - in object property" {
  // Generic function type as object property
  let code =
    #|declare let obj: {
    #|    prop: <T>(x: T) => T
    #|}
  assert_true(parse_succeeds(code))
}

///|
test "parse generic function type - with callback parameter" {
  // Generic function type with callback: <T>(strs: string[], x: (input: T) => T) => T
  let code = "type F = <T>(strs: string[], x: (input: T) => T) => { result: T };"
  assert_true(parse_succeeds(code))
}

///|
test "parse generic function type - nested in interface" {
  // Generic function type in interface
  let code =
    #|interface I {
    #|    method: <T>(x: T) => T;
    #|}
  assert_true(parse_succeeds(code))
}

///|
test "parse generic function type - default type parameter" {
  // Generic function type with default: <T = string>(x: T) => T
  let code = "type F = <T = string>(x: T) => T;"
  assert_true(parse_succeeds(code))
}
