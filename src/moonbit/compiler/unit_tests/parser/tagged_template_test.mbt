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
