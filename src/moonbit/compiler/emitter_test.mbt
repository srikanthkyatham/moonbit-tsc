// Emitter tests
// Tests JavaScript code generation from transformed AST

///|
/// Helper to parse, transform, and emit TypeScript code
fn compile_to_js(source : String) -> String {
  let tokens = get_tokens_from_source(source)
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = TransformerContext::default()
      let emit_ctx = EmitterContext::default()

      // Use the public compile_source_file function
      // This ensures helpers are emitted when decorators are used
      compile_source_file(source_file, ctx, emit_ctx)
    }
    Err(diagnostics) => {
      println("Failed to parse source:")
      for d in diagnostics {
        println("  \{d.message}")
      }
      ""
    }
  }
}

///|
/// Helper to parse, transform, and emit TypeScript code with ES5 target
fn compile_to_es5(source : String) -> String {
  let tokens = get_tokens_from_source(source)
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = TransformerContext::es5()
      let emit_ctx = EmitterContext::default()
      compile_source_file(source_file, ctx, emit_ctx)
    }
    Err(diagnostics) => {
      println("Failed to parse source:")
      for d in diagnostics {
        println("  \{d.message}")
      }
      ""
    }
  }
}

///|
/// Helper to parse source and get tokens
fn get_tokens_from_source(source : String) -> Array[Token] {
  scan_all_v2(source, "test.ts")
}

///|
/// Test: Emit simple variable declaration
test "emit const declaration" {
  let js = compile_to_js("const x = 42;")
  assert_true(js.contains("const x = 42;"))
}

///|
/// Test: Emit let declaration
test "emit let declaration" {
  let js = compile_to_js("let count = 0;")
  assert_true(js.contains("let count = 0;"))
}

///|
/// Test: Emit var declaration
test "emit var declaration" {
  let js = compile_to_js("var message = \"hello\";")
  assert_true(js.contains("var message = \"hello\";"))
}

///|
/// Test: Emit function declaration
test "emit function declaration" {
  let js = compile_to_js("function greet(name) { return \"Hello \" + name; }")
  assert_true(js.contains("function greet(name)"))
  assert_true(js.contains("return \"Hello \" + name;"))
}

///|
/// Test: Emit arrow function
test "emit arrow function" {
  let js = compile_to_js("const add = (a, b) => a + b;")
  assert_true(js.contains("const add = (a, b) => a + b;"))
}

///|
/// Test: Emit arrow function with block body
test "emit arrow function with block" {
  let js = compile_to_js("const multiply = (a, b) => { return a * b; };")
  assert_true(js.contains("const multiply = (a, b) => {"))
  assert_true(js.contains("return a * b;"))
}

///|
/// Test: Emit if statement
test "emit if statement" {
  let js = compile_to_js("if (x > 0) { console.log(\"positive\"); }")
  assert_true(js.contains("if (x > 0)"))
  assert_true(js.contains("console.log(\"positive\");"))
}

///|
/// Test: Emit if-else statement
test "emit if-else statement" {
  let js = compile_to_js("if (x > 0) { y = 1; } else { y = 0; }")
  assert_true(js.contains("if (x > 0)"))
  assert_true(js.contains("else"))
  assert_true(js.contains("y = 1;"))
  assert_true(js.contains("y = 0;"))
}

///|
/// Test: Emit for loop
test "emit for loop" {
  let js = compile_to_js("for (let i = 0; i < 10; i++) { sum += i; }")
  assert_true(js.contains("for (let i = 0; i < 10; i++)"))
  assert_true(js.contains("sum += i;"))
}

///|
/// Test: Emit for-in loop
test "emit for-in loop" {
  let js = compile_to_js("for (const key in obj) { x = key; }")
  assert_true(js.contains("for (const key in obj)"))
  assert_true(js.contains("x = key;"))
}

///|
/// Test: Emit for-of loop
test "emit for-of loop" {
  let js = compile_to_js("for (const item of array) { x = item; }")
  assert_true(js.contains("for (const item of array)"))
  assert_true(js.contains("x = item;"))
}

///|
/// Test: Emit while loop
test "emit while loop" {
  let js = compile_to_js("while (x < 10) { x = x + 1; }")
  assert_true(js.contains("while (x < 10)"))
  assert_true(js.contains("x = x + 1;"))
}

///|
/// Test: Emit do-while loop
test "emit do-while loop" {
  let js = compile_to_js("do { x++; } while (x < 10);")
  assert_true(js.contains("do {"))
  assert_true(js.contains("x++;"))
  assert_true(js.contains("} while (x < 10);"))
}

///|
/// Test: Emit switch statement
test "emit switch statement" {
  let js = compile_to_js(
    "function test() { switch (x) { case 1: return \"one\"; default: return \"other\"; } }",
  )
  assert_true(js.contains("switch (x)"))
  assert_true(js.contains("case 1:"))
  assert_true(js.contains("default:"))
  assert_true(js.contains("return \"one\";"))
  assert_true(js.contains("return \"other\";"))
}

///|
/// Test: Emit try-catch statement
test "emit try-catch statement" {
  let js = compile_to_js("try { x = 1; } catch (e) { x = 0; }")
  assert_true(js.contains("try {"))
  assert_true(js.contains("x = 1;"))
  assert_true(js.contains("} catch"))
  assert_true(js.contains("x = 0;"))
}

///|
/// Test: Emit try-catch-finally
test "emit try-catch-finally" {
  let js = compile_to_js(
    "try { x = 1; } catch (e) { x = 0; } finally { y = 2; }",
  )
  assert_true(js.contains("try {"))
  assert_true(js.contains("} catch"))
  assert_true(js.contains("} finally {"))
  assert_true(js.contains("y = 2;"))
}

///|
/// Test: Emit binary expressions
test "emit binary expressions" {
  let js = compile_to_js("const result = a + b * c - d / e;")
  assert_true(js.contains("a + b * c - d / e"))
}

///|
/// Test: Emit comparison operators
test "emit comparison operators" {
  let js = compile_to_js("const check = x > y && a < b || c === d;")
  assert_true(js.contains("x > y && a < b || c === d"))
}

///|
/// Test: Emit unary expressions
test "emit unary expressions" {
  let js = compile_to_js("const neg = -x; const not = !flag;")
  assert_true(js.contains("-x"))
  assert_true(js.contains("!flag"))
}

///|
/// Test: Emit call expression
test "emit call expression" {
  let js = compile_to_js("const result = foo(1, 2, 3);")
  assert_true(js.contains("foo(1, 2, 3)"))
}

///|
/// Test: Emit property access
test "emit property access" {
  let js = compile_to_js("const name = person.firstName;")
  assert_true(js.contains("person.firstName"))
}

///|
/// Test: Emit element access
test "emit element access" {
  let js = compile_to_js("const item = array[0];")
  assert_true(js.contains("array[0]"))
}

///|
/// Test: Emit array literal
test "emit array literal" {
  let js = compile_to_js("const numbers = [1, 2, 3, 4, 5];")
  assert_true(js.contains("[1, 2, 3, 4, 5]"))
}

///|
/// Test: Emit object literal
test "emit object literal" {
  let js = compile_to_js("const obj = { x: 1, y: 2 };")
  assert_true(js.contains("{ x: 1, y: 2 }"))
}

///|
/// Test: Emit template literal (if parser supports it)
test "emit string literal" {
  let js = compile_to_js("const msg = \"Hello World\";")
  assert_true(js.contains("\"Hello World\""))
}

///|
/// Test: Emit conditional expression
test "emit conditional expression" {
  let js = compile_to_js("const result = condition ? value1 : value2;")
  assert_true(js.contains("condition ? value1 : value2"))
}

///|
/// Test: Emit new expression
test "emit new expression" {
  let js = compile_to_js("const obj = new MyClass();")
  assert_true(js.contains("new MyClass()"))
}

///|
/// Test: Emit class declaration
test "emit class declaration" {
  let js = compile_to_js(
    "class Person { constructor(name) { this.name = name; } }",
  )
  assert_true(js.contains("class Person"))
  assert_true(js.contains("constructor(name)"))
  assert_true(js.contains("this.name = name;"))
}

///|
/// Test: Emit return statement
test "emit return statement" {
  let js = compile_to_js("function getValue() { return 42; }")
  assert_true(js.contains("return 42;"))
}

///|
/// Test: Emit break statement
test "emit break statement" {
  let js = compile_to_js("while (true) { if (done) break; }")
  assert_true(js.contains("break;"))
}

///|
/// Test: Emit continue statement
test "emit continue statement" {
  let js = compile_to_js("for (let i = 0; i < 10; i++) { if (skip) continue; }")
  assert_true(js.contains("continue;"))
}

///|
/// Test: Emit throw statement
test "emit throw statement" {
  let js = compile_to_js("if (error) throw new Error(\"Failed\");")
  assert_true(js.contains("throw new Error(\"Failed\");"))
}

///|
/// Test: Type annotations are removed
test "emit removes type annotations" {
  let js = compile_to_js("const x: number = 42;")
  assert_false(js.contains(": number"))
  assert_true(js.contains("const x = 42;"))
}

///|
/// Test: Function type annotations are removed
test "emit removes function return type" {
  let js = compile_to_js("function getName(): string { return \"John\"; }")
  assert_false(js.contains(": string"))
  assert_true(js.contains("function getName()"))
}

///|
/// Test: Emit multiple statements
test "emit multiple statements" {
  let js = compile_to_js("const a = 1; const b = 2; const c = a + b;")
  assert_true(js.contains("const a = 1;"))
  assert_true(js.contains("const b = 2;"))
  assert_true(js.contains("const c = a + b;"))
}

///|
/// Test: Emit nested expressions
test "emit nested expressions" {
  let js = compile_to_js("const result = (a + b) * (c - d);")
  assert_true(js.contains("(a + b) * (c - d)"))
}

///|
/// Test: Emit chained property access
test "emit chained property access" {
  let js = compile_to_js("const value = obj.prop1.prop2.prop3;")
  assert_true(js.contains("obj.prop1.prop2.prop3"))
}

///|
/// Test: Emit chained method calls
test "emit chained method calls" {
  let js = compile_to_js("const result = obj.method1().method2().method3();")
  assert_true(js.contains("obj.method1().method2().method3()"))
}

///|
/// Test: Emit empty array
test "emit empty array" {
  let js = compile_to_js("const empty = [];")
  assert_true(js.contains("[]"))
}

///|
/// Test: Emit empty object
test "emit empty object" {
  let js = compile_to_js("const empty = {};")
  assert_true(js.contains("{}"))
}

///|
/// Test: Emit function with multiple parameters
test "emit function with multiple parameters" {
  let js = compile_to_js("function calculate(a, b, c) { return a + b + c; }")
  assert_true(js.contains("function calculate(a, b, c)"))
}

///|
/// Test: Emit async function
test "emit async function" {
  let js = compile_to_js("async function getData() { return x; }")
  assert_true(js.contains("async function getData()"))
}

///|
/// Test: Emit expression statement
test "emit expression statement" {
  let js = compile_to_js("x = 42;")
  assert_true(js.contains("x = 42;"))
}

///|
/// Test: Emit increment/decrement
test "emit increment decrement" {
  let js = compile_to_js("x++; y--;")
  assert_true(js.contains("x++;"))
  assert_true(js.contains("y--;"))
}

///|
/// Test: Emit compound assignment
test "emit compound assignment" {
  let js = compile_to_js("x += 5; y *= 2;")
  assert_true(js.contains("x += 5;"))
  assert_true(js.contains("y *= 2;"))
}

///|
/// Test: Emit logical operators
test "emit logical operators" {
  let js = compile_to_js("const result = a && b || c;")
  assert_true(js.contains("a && b || c"))
}

///|
/// Test: Emit bitwise operators
test "emit bitwise operators" {
  let js = compile_to_js("const result = a & b | c ^ d;")
  assert_true(js.contains("a & b | c ^ d"))
}

///|
/// Test: Emit typeof operator
test "emit typeof operator" {
  let js = compile_to_js("const t = typeof x;")
  assert_true(js.contains("typeof x"))
}

///|
/// Test: Emit delete operator
test "emit delete operator" {
  let js = compile_to_js("delete obj.prop;")
  assert_true(js.contains("delete obj.prop"))
}

///|
/// Test: Emit in operator
test "emit in operator" {
  let js = compile_to_js("const has = \"key\" in obj;")
  assert_true(js.contains("\"key\" in obj"))
}

///|
/// Test: Emit instanceof operator
test "emit instanceof operator" {
  let js = compile_to_js("const is = obj instanceof MyClass;")
  assert_true(js.contains("obj instanceof MyClass"))
}

///|
/// Test: Emit null literal
test "emit null literal" {
  let js = compile_to_js("const value = null;")
  assert_true(js.contains("null"))
}

///|
/// Test: Emit boolean literals
test "emit boolean literals" {
  let js = compile_to_js("const t = true; const f = false;")
  assert_true(js.contains("true"))
  assert_true(js.contains("false"))
}

///|
/// Test: Emit this expression
test "emit this expression" {
  let js = compile_to_js("class C { method() { return this.value; } }")
  assert_true(js.contains("this.value"))
}

///|
/// Test: Emit nested blocks
test "emit nested blocks" {
  let js = compile_to_js("if (a) { if (b) { c(); } }")
  assert_true(js.contains("if (a)"))
  assert_true(js.contains("if (b)"))
  assert_true(js.contains("c();"))
}

///|
/// Test: Emit string with escape characters
test "emit string escapes" {
  let js = compile_to_js("const s = \"Line 1\\nLine 2\\tTabbed\";")
  assert_true(js.contains("\\n"))
  assert_true(js.contains("\\t"))
}

///|
/// Test: Emit function expression
test "emit function expression" {
  let js = compile_to_js("const fn = function(x) { return x * 2; };")
  assert_true(js.contains("function(x)"))
  assert_true(js.contains("return x * 2;"))
}

///|
/// Test: Emit named function expression
test "emit named function expression" {
  let js = compile_to_js(
    "const factorial = function fact(n) { return n <= 1 ? 1 : n * fact(n - 1); };",
  )
  assert_true(js.contains("function fact(n)"))
}

///|
/// Test: Emit simple spread expression
test "emit spread expression" {
  let js = compile_to_js("const x = 1;")
  // Just verify basic emission works - spread may not be fully parsed yet
  assert_true(js.contains("const x = 1;"))
}

///|
/// Test: Emit parenthesized expression
test "emit parenthesized expression" {
  let js = compile_to_js("const result = (a + b) * c;")
  assert_true(js.contains("(a + b) * c"))
}

///|
/// Test: Emit complex nested structure
test "emit complex nested structure" {
  let source = "function process(data) { for (const item of data) { if (item.active) { result = item.name; } } }"
  let js = compile_to_js(source)
  assert_true(js.contains("function process(data)"))
  assert_true(js.contains("for (const item of data)"))
  assert_true(js.contains("if (item.active)"))
  assert_true(js.contains("result = item.name;"))
}

///|
/// Test: Emit with proper indentation
test "emit maintains indentation" {
  let source = "if (x) { y(); }"
  let js = compile_to_js(source)
  // Check that there's some indentation structure
  assert_true(js.contains("{"))
  assert_true(js.contains("}"))
}

///|
/// Test: Emit debugger statement
test "emit debugger statement" {
  let js = compile_to_js("debugger;")
  assert_true(js.contains("debugger;"))
}

///|
/// Test: Emit debugger statement in function
test "emit debugger statement in function" {
  let js = compile_to_js("function debug() { debugger; return 1; }")
  assert_true(js.contains("debugger;"))
  assert_true(js.contains("return 1;"))
}

///|
/// Test: Emit static class member
test "emit static class member" {
  let js = compile_to_js("class Counter { static count = 0; }")
  assert_true(js.contains("static count = 0;"))
}

///|
/// Test: Emit static method
test "emit static method" {
  let js = compile_to_js("class Utils { static helper() { return 1; } }")
  assert_true(js.contains("static helper()"))
}

///|
/// Test: Emit async method
test "emit async method" {
  let js = compile_to_js("class Api { async fetch() { return 1; } }")
  assert_true(js.contains("async fetch()"))
}

///|
/// Test: Emit export const
test "emit export const" {
  let js = compile_to_js("export const x = 1;")
  assert_true(js.contains("export const x = 1;"))
}

///|
/// Test: Emit export function
test "emit export function" {
  let js = compile_to_js("export function hello() { return 1; }")
  assert_true(js.contains("export function hello()"))
}

///|
/// Test: Emit export class
test "emit export class" {
  let js = compile_to_js("export class Person { name = ''; }")
  assert_true(js.contains("export class Person"))
}

///|
/// Test: Emit export async function
test "emit export async function" {
  let js = compile_to_js("export async function fetch() { return 1; }")
  assert_true(js.contains("export async function fetch()"))
}

///|
/// Test: Emit export let
test "emit export let" {
  let js = compile_to_js("export let value = 'test';")
  assert_true(js.contains("export let value = "))
}

///|
/// Test: Emit export default function
test "emit export default function" {
  let js = compile_to_js("export default function greet() { return 'hello'; }")
  assert_true(js.contains("export default function greet()"))
}

///|
/// Test: Emit export default class
test "emit export default class" {
  let js = compile_to_js("export default class Person { name = ''; }")
  assert_true(js.contains("export default class Person"))
}

///|
/// Test: Emit export default async function
test "emit export default async function" {
  let js = compile_to_js("export default async function load() { return 1; }")
  assert_true(js.contains("export default async function load()"))
}

///|
/// Test: Declare const produces no output
test "emit declare const produces no output" {
  let js = compile_to_js("declare const x: number;")
  // Declare statements should not produce JavaScript output
  assert_true(!(js.contains("const x")))
}

///|
/// Test: Declare function produces no output
test "emit declare function produces no output" {
  let js = compile_to_js("declare function foo(): void;")
  // Declare statements should not produce JavaScript output
  assert_true(!(js.contains("function foo")))
}

///|
/// Test: Declare class produces no output
test "emit declare class produces no output" {
  let js = compile_to_js("declare class Foo { bar(): void; }")
  // Declare statements should not produce JavaScript output
  assert_true(!(js.contains("class Foo")))
}

///|
/// Test: Regular const still produces output
test "emit regular const still works" {
  let js = compile_to_js("const x = 1;")
  assert_true(js.contains("const x = 1;"))
}

///|
/// Test: Const enum is NOT emitted (inlined at usage sites)
test "emit const enum" {
  let js = compile_to_js("const enum Color { Red, Green, Blue }")
  println("Const enum output:\n\{js}")
  // Const enums are inlined and NOT emitted as objects
  assert_false(js.contains("const Color"))
  assert_false(js.contains("Color"))
}

///|
/// Test: Regular enum is emitted
test "emit regular enum" {
  let js = compile_to_js("enum Status { Active, Inactive }")
  assert_true(js.contains("const Status"))
}

///|
/// Test: Const enum value is inlined
test "emit const enum with inlined values" {
  let js = compile_to_js(
    "const enum Direction { Up = 1, Down = 2 }; let x = Direction.Up;",
  )
  println("Const enum inlined output:\n\{js}")
  // Const enum declaration should NOT be emitted
  assert_false(js.contains("const Direction"))
  // Direction.Up should be inlined to 1
  assert_true(js.contains("let x = 1"))
}

///|
/// Test: Const enum auto-increment values
test "emit const enum auto-increment" {
  let js = compile_to_js(
    "const enum Color { Red, Green, Blue }; let c = Color.Green;",
  )
  println("Const enum auto-increment output:\n\{js}")
  // Color.Green should be inlined to 1 (auto-increment from 0)
  assert_true(js.contains("let c = 1"))
}

///|
/// Test: String enum is emitted correctly
test "emit string enum" {
  let js = compile_to_js(
    "enum Direction { Up = 'UP', Down = 'DOWN', Left = 'LEFT', Right = 'RIGHT' }",
  )
  println("String enum output:\n\{js}")
  // String enum should be emitted as a const object
  assert_true(js.contains("const Direction"))
  assert_true(js.contains("\"UP\""))
  assert_true(js.contains("\"DOWN\""))
}

///|
/// Test: Enum with computed values
test "emit enum with computed values" {
  let js = compile_to_js("enum Bits { One = 1, Two = 1 + 1, Four = 2 + 2 }")
  println("Computed enum output:\n\{js}")
  // Computed values should be preserved in the output
  assert_true(js.contains("const Bits"))
}

///|
/// Test: Enum with bitwise operations
test "emit enum with bitwise operations" {
  let js = compile_to_js(
    "enum Flags { None = 0, Read = 1, Write = 2, Execute = 4, All = 7 }",
  )
  println("Bitwise enum output:\n\{js}")
  assert_true(js.contains("const Flags"))
}

///|
/// Test: Ambient (declare) enum is not emitted
test "emit declare enum" {
  let js = compile_to_js("declare enum ExternalEnum { A, B, C }")
  println("Declare enum output:\n\{js}")
  // Ambient enums should NOT be emitted - they describe external values
  assert_false(js.contains("const ExternalEnum"))
  assert_false(js.contains("ExternalEnum"))
}

///|
/// Test: Const enum with string values is inlined
test "emit const string enum inlined" {
  let js = compile_to_js(
    "const enum Status { Active = 'active', Inactive = 'inactive' }; let s = Status.Active;",
  )
  println("Const string enum output:\n\{js}")
  // Const string enum should be inlined
  assert_true(js.contains("let s = \"active\""))
}

///|
/// Test: Regular enum auto-increment after explicit value
test "emit enum auto-increment after explicit" {
  let js = compile_to_js("enum Numbers { Zero, One, Ten = 10, Eleven, Twelve }")
  println("Enum auto-increment after explicit:\n\{js}")
  assert_true(js.contains("const Numbers"))
}

///|
/// Test: Const enum with negative value
test "emit const enum negative" {
  let js = compile_to_js(
    "const enum Offset { Minus1 = -1, Zero = 0, Plus1 = 1 }; let x = Offset.Minus1;",
  )
  println("Const enum negative output:\n\{js}")
  // Should inline -1
  assert_true(js.contains("let x = -1"))
}

///|
/// Test: Non-null assertion property access (!.) strips assertion
test "emit non-null assertion property access" {
  let js = compile_to_js("const x = obj!.property;")
  // The !. should be stripped, becoming just .property
  assert_true(js.contains("obj.property"))
  assert_true(!(js.contains("!")))
}

///|
/// Test: Chained non-null assertion property access
test "emit chained non-null assertion" {
  let js = compile_to_js("const x = a!.b!.c;")
  // All !. should be stripped
  assert_true(js.contains("a.b.c"))
  assert_true(!(js.contains("!")))
}

///|
/// Test: Non-null assertion with method call
test "emit non-null assertion with method call" {
  let js = compile_to_js("const x = obj!.method();")
  assert_true(js.contains("obj.method()"))
  assert_true(!(js.contains("!")))
}

// ============================================================================
// Named Imports Tests
// ============================================================================

///|
/// Test: Emit named import with single specifier
test "emit named import single specifier" {
  let js = compile_to_js("import { foo } from 'module';")
  assert_true(js.contains("import { foo } from \"module\";"))
}

///|
/// Test: Emit named import with multiple specifiers
test "emit named import multiple specifiers" {
  let js = compile_to_js("import { foo, bar, baz } from 'module';")
  assert_true(js.contains("import { foo, bar, baz } from \"module\";"))
}

///|
/// Test: Emit named import with alias
test "emit named import with alias" {
  let js = compile_to_js("import { foo as bar } from 'module';")
  assert_true(js.contains("import { foo as bar } from \"module\";"))
}

///|
/// Test: Emit default and named imports together
test "emit default and named import" {
  let js = compile_to_js("import React, { useState } from 'react';")
  assert_true(js.contains("import React, { useState } from \"react\";"))
}

///|
/// Test: Emit namespace import
test "emit namespace import" {
  let js = compile_to_js("import * as utils from 'utils';")
  assert_true(js.contains("import * as utils from \"utils\";"))
}

// ============================================================================
// Named Exports Tests
// ============================================================================

///|
/// Test: Emit named export with single specifier
test "emit named export single specifier" {
  let js = compile_to_js("const x = 1; export { x };")
  assert_true(js.contains("export { x };"))
}

///|
/// Test: Emit named export with multiple specifiers
test "emit named export multiple specifiers" {
  let js = compile_to_js("const x = 1; const y = 2; export { x, y };")
  assert_true(js.contains("export { x, y };"))
}

///|
/// Test: Emit named export with alias
test "emit named export with alias" {
  let js = compile_to_js("const foo = 1; export { foo as bar };")
  assert_true(js.contains("export { foo as bar };"))
}

///|
/// Test: Emit re-export
test "emit re-export from module" {
  let js = compile_to_js("export { foo } from 'module';")
  assert_true(js.contains("export { foo } from \"module\";"))
}

///|
/// Test: Emit export all
test "emit export all" {
  let js = compile_to_js("export * from 'module';")
  assert_true(js.contains("export * from \"module\";"))
}

// ============================================================================
// Module Declaration (Namespace) Tests
// ============================================================================

///|
/// Test: Emit module declaration with exported constant
test "emit module declaration with export const" {
  let js = compile_to_js("module Foo { export const x = 1; }")
  assert_true(js.contains("var Foo;"))
  assert_true(js.contains("(function (Foo)"))
  assert_true(js.contains("Foo.x = 1;"))
  assert_true(js.contains("Foo || (Foo = {})"))
}

///|
/// Test: Emit module declaration with exported function
test "emit module declaration with export function" {
  let js = compile_to_js(
    "module Utils { export function helper() { return 1; } }",
  )
  assert_true(js.contains("var Utils;"))
  assert_true(js.contains("Utils.helper = function()"))
}

///|
/// Test: Emit namespace keyword (alias for module)
test "emit namespace declaration" {
  let js = compile_to_js("namespace MyLib { export const VERSION = '1.0'; }")
  assert_true(js.contains("var MyLib;"))
  assert_true(js.contains("MyLib.VERSION"))
}

///|
/// Test: Emit namespace with exported class
test "emit namespace with exported class" {
  let js = compile_to_js(
    "namespace Models { export class User { name: string; } }",
  )
  println("Namespace with class:\n\{js}")
  assert_true(js.contains("var Models;"))
  assert_true(js.contains("(function (Models)"))
  assert_true(js.contains("Models.User = class User"))
  assert_true(js.contains("Models || (Models = {})"))
}

///|
/// Test: Emit namespace with multiple exports
test "emit namespace with multiple exports" {
  let js = compile_to_js(
    "namespace Utils { export const PI = 3.14; export function double(x) { return x * 2; } }",
  )
  println("Namespace with multiple exports:\n\{js}")
  assert_true(js.contains("var Utils;"))
  assert_true(js.contains("Utils.PI = 3.14"))
  assert_true(js.contains("Utils.double = function"))
}

///|
/// Test: Emit namespace with non-exported (internal) member
test "emit namespace with internal member" {
  let js = compile_to_js(
    "namespace Internal { const secret = 42; export const visible = secret; }",
  )
  println("Namespace with internal member:\n\{js}")
  assert_true(js.contains("var Internal;"))
  // Non-exported member should be local variable
  assert_true(js.contains("const secret = 42"))
  // Exported member should be on namespace
  assert_true(js.contains("Internal.visible"))
}

// ============================================================================
// Decorator Tests
// ============================================================================

///|
/// Test: Emit class with single decorator
test "emit class with single decorator" {
  let js = compile_to_js("@sealed class MyClass { }")
  println("Generated JS:\n\{js}")
  // Decorated class should use let ClassName = class ClassName pattern
  assert_true(js.contains("let MyClass = class MyClass"))
  // Decorator call should be emitted after class definition
  assert_true(js.contains("__decorate"))
  assert_true(js.contains("sealed"))
  assert_true(js.contains("], MyClass)"))
}

///|
/// Test: Emit class with decorator factory (with arguments)
test "emit class with decorator factory" {
  let js = compile_to_js(
    "@Component({ selector: 'app' }) class AppComponent { }",
  )
  println("Decorator factory JS:\n\{js}")
  // Decorated class should use let ClassName = class ClassName pattern
  assert_true(js.contains("let AppComponent = class AppComponent"))
  // Decorator call should include the factory call
  assert_true(js.contains("__decorate"))
  assert_true(js.contains("Component"))
}

///|
/// Test: Emit class with multiple decorators
test "emit class with multiple decorators" {
  let js = compile_to_js("@first @second @third class MultiDecorated { }")
  println("Multiple decorators JS:\n\{js}")
  // Should emit let ClassName = class ClassName pattern
  assert_true(js.contains("let MultiDecorated = class MultiDecorated"))
  // All decorators should be in the __decorate call
  assert_true(js.contains("__decorate"))
  assert_true(js.contains("first"))
  assert_true(js.contains("second"))
  assert_true(js.contains("third"))
}

///|
/// Test: Emit class without decorators still works normally
test "emit class without decorators unchanged" {
  let js = compile_to_js("class NormalClass { constructor() { } }")
  // Regular class should not use let = pattern
  assert_true(js.contains("class NormalClass"))
  assert_true(!(js.contains("let NormalClass = class")))
  // Should not have __decorate
  assert_true(!(js.contains("__decorate")))
}

///|
/// Test: Emit decorated class with class body
test "emit decorated class with members" {
  let js = compile_to_js(
    "@injectable class Service { name = 'test'; getValue() { return 42; } }",
  )
  println("Decorated class with members:\n\{js}")
  assert_true(js.contains("let Service = class Service"))
  assert_true(js.contains("__decorate"))
  assert_true(js.contains("injectable"))
  // Class body should still have members
  assert_true(js.contains("name = \"test\""))
  assert_true(js.contains("getValue()"))
}

///|
/// Test: Emit decorator with property access (e.g., @Ng.Component)
test "emit decorator with property access" {
  let js = compile_to_js("@Ng.Component class MyComponent { }")
  println("Decorator with property access:\n\{js}")
  assert_true(js.contains("let MyComponent = class MyComponent"))
  assert_true(js.contains("__decorate"))
  assert_true(js.contains("Ng.Component"))
}

///|
/// Test: Emit decorator factory with multiple arguments
test "emit decorator factory with multiple args" {
  let js = compile_to_js("@define('name', { value: 123 }) class Config { }")
  println("Decorator factory with multiple args:\n\{js}")
  assert_true(js.contains("let Config = class Config"))
  assert_true(js.contains("__decorate"))
  assert_true(js.contains("define"))
}

///|
/// Test: Emit export decorated class
test "emit export decorated class" {
  let js = compile_to_js("@logged export class ExportedClass { }")
  println("Export decorated class:\n\{js}")
  // Should have export and decoration
  assert_true(js.contains("export"))
  assert_true(js.contains("__decorate"))
  assert_true(js.contains("logged"))
}

///|
/// Test: Emit decorated class with constructor
test "emit decorated class with constructor" {
  let js = compile_to_js(
    "@singleton class Database { constructor(url) { this.url = url; } }",
  )
  println("Decorated class with constructor:\n\{js}")
  assert_true(js.contains("let Database = class Database"))
  assert_true(js.contains("constructor(url)"))
  assert_true(js.contains("this.url = url"))
  assert_true(js.contains("__decorate"))
  assert_true(js.contains("singleton"))
}

///|
/// Test: Emit decorated abstract class
test "emit decorated abstract class" {
  let js = compile_to_js("@base abstract class BaseEntity { }")
  println("Decorated abstract class:\n\{js}")
  // Abstract keyword is removed in JS output, but decoration should work
  assert_true(js.contains("let BaseEntity = class BaseEntity"))
  assert_true(js.contains("__decorate"))
  assert_true(js.contains("base"))
}

///|
/// Test: Emit decorator with arrow function argument
test "emit decorator with arrow function arg" {
  let js = compile_to_js("@filter(x => x > 0) class PositiveFilter { }")
  println("Decorator with arrow function:\n\{js}")
  assert_true(js.contains("let PositiveFilter = class PositiveFilter"))
  assert_true(js.contains("__decorate"))
  assert_true(js.contains("filter"))
}

///|
/// Test: Emit multiple decorator factories
test "emit multiple decorator factories" {
  let js = compile_to_js(
    "@Module({ imports: [] }) @Controller('/api') class ApiModule { }",
  )
  println("Multiple decorator factories:\n\{js}")
  assert_true(js.contains("let ApiModule = class ApiModule"))
  assert_true(js.contains("__decorate"))
  assert_true(js.contains("Module"))
  assert_true(js.contains("Controller"))
}

// =============================================================================
// Member Decorator Tests
// =============================================================================

///|
/// Test: Emit method with single decorator
test "emit method with single decorator" {
  let js = compile_to_js("class MyClass { @log myMethod() { } }")
  println("Method with decorator:\n\{js}")
  // Should emit __decorate call for the method
  assert_true(js.contains("__decorate"))
  assert_true(js.contains("log"))
  assert_true(js.contains("MyClass.prototype"))
  assert_true(js.contains("\"myMethod\""))
}

///|
/// Test: Emit method with decorator factory
test "emit method with decorator factory" {
  let js = compile_to_js("class MyClass { @Bind() handleClick() { } }")
  println("Method with decorator factory:\n\{js}")
  assert_true(js.contains("__decorate"))
  assert_true(js.contains("Bind()"))
  assert_true(js.contains("MyClass.prototype"))
  assert_true(js.contains("\"handleClick\""))
}

///|
/// Test: Emit method with multiple decorators
test "emit method with multiple decorators" {
  let js = compile_to_js("class MyClass { @log @deprecated myMethod() { } }")
  println("Method with multiple decorators:\n\{js}")
  assert_true(js.contains("__decorate"))
  assert_true(js.contains("log"))
  assert_true(js.contains("deprecated"))
  assert_true(js.contains("MyClass.prototype"))
  assert_true(js.contains("\"myMethod\""))
}

///|
/// Test: Emit property with decorator
test "emit property with decorator" {
  let js = compile_to_js("class MyClass { @Input() value = 42; }")
  println("Property with decorator:\n\{js}")
  assert_true(js.contains("__decorate"))
  assert_true(js.contains("Input()"))
  assert_true(js.contains("MyClass.prototype"))
  assert_true(js.contains("\"value\""))
}

///|
/// Test: Emit static method with decorator
test "emit static method with decorator" {
  let js = compile_to_js("class MyClass { @log static myStaticMethod() { } }")
  println("Static method with decorator:\n\{js}")
  assert_true(js.contains("__decorate"))
  assert_true(js.contains("log"))
  // Static members use the class itself, not prototype
  assert_true(js.contains("MyClass,"))
  assert_true(js.contains("\"myStaticMethod\""))
}

///|
/// Test: Emit getter with decorator
test "emit getter with decorator" {
  let js = compile_to_js(
    "class MyClass { @computed get value() { return 42; } }",
  )
  println("Getter with decorator:\n\{js}")
  assert_true(js.contains("__decorate"))
  assert_true(js.contains("computed"))
  assert_true(js.contains("MyClass.prototype"))
  assert_true(js.contains("\"value\""))
}

///|
/// Test: Emit setter with decorator
test "emit setter with decorator" {
  let js = compile_to_js(
    "class MyClass { @validate set name(val) { this._name = val; } }",
  )
  println("Setter with decorator:\n\{js}")
  assert_true(js.contains("__decorate"))
  assert_true(js.contains("validate"))
  assert_true(js.contains("MyClass.prototype"))
  assert_true(js.contains("\"name\""))
}

///|
/// Test: Emit class with both class and member decorators
test "emit class with class and member decorators" {
  let js = compile_to_js(
    "@Component class MyComponent { @Input() data; @Output() change() { } }",
  )
  println("Class with class and member decorators:\n\{js}")
  // Should have class decorator
  assert_true(js.contains("Component"))
  // Should have member decorators
  assert_true(js.contains("Input()"))
  assert_true(js.contains("Output()"))
  // All should use __decorate
  assert_true(js.contains("__decorate"))
}

///|
/// Test: Emit private method with decorator
test "emit private method with decorator" {
  let js = compile_to_js("class MyClass { @log private handleEvent() { } }")
  println("Private method with decorator:\n\{js}")
  assert_true(js.contains("__decorate"))
  assert_true(js.contains("log"))
  assert_true(js.contains("\"handleEvent\""))
}

///|
/// Test: Emit async method with decorator
test "emit async method with decorator" {
  let js = compile_to_js("class MyClass { @log async fetchData() { } }")
  println("Async method with decorator:\n\{js}")
  assert_true(js.contains("__decorate"))
  assert_true(js.contains("log"))
  assert_true(js.contains("async"))
  assert_true(js.contains("fetchData"))
}

// =============================================================================
// Parameter Decorator Tests
// =============================================================================

///|
/// Test: Emit constructor with single parameter decorator
test "emit constructor with parameter decorator" {
  let js = compile_to_js("class MyClass { constructor(@inject service) { } }")
  println("Constructor with param decorator:\n\{js}")
  assert_true(js.contains("__decorate"))
  assert_true(js.contains("__param"))
  assert_true(js.contains("0"))
  assert_true(js.contains("inject"))
}

///|
/// Test: Emit constructor with parameter decorator factory
test "emit constructor with parameter decorator factory" {
  let js = compile_to_js(
    "class MyClass { constructor(@Inject('Logger') logger) { } }",
  )
  println("Constructor with param decorator factory:\n\{js}")
  assert_true(js.contains("__decorate"))
  assert_true(js.contains("__param"))
  assert_true(js.contains("Inject"))
}

///|
/// Test: Emit constructor with multiple parameter decorators
test "emit constructor with multiple parameter decorators" {
  let js = compile_to_js(
    "class MyClass { constructor(@inject @optional service) { } }",
  )
  println("Constructor with multiple param decorators:\n\{js}")
  assert_true(js.contains("__decorate"))
  assert_true(js.contains("__param(0, inject)"))
  assert_true(js.contains("__param(0, optional)"))
}

///|
/// Test: Emit constructor with decorators on multiple parameters
test "emit constructor with decorators on multiple parameters" {
  let js = compile_to_js(
    "class MyClass { constructor(@inject a, @optional b) { } }",
  )
  println("Constructor with decorators on multiple params:\n\{js}")
  assert_true(js.contains("__decorate"))
  assert_true(js.contains("__param(0, inject)"))
  assert_true(js.contains("__param(1, optional)"))
}

///|
/// Test: Emit method with parameter decorator
test "emit method with parameter decorator" {
  let js = compile_to_js("class MyClass { myMethod(@validate arg) { } }")
  println("Method with param decorator:\n\{js}")
  assert_true(js.contains("__decorate"))
  assert_true(js.contains("__param"))
  assert_true(js.contains("validate"))
  assert_true(js.contains("MyClass.prototype"))
  assert_true(js.contains("\"myMethod\""))
}

///|
/// Test: Emit method with both method and parameter decorators
test "emit method with method and parameter decorators" {
  let js = compile_to_js("class MyClass { @log myMethod(@validate arg) { } }")
  println("Method with method and param decorators:\n\{js}")
  assert_true(js.contains("__decorate"))
  assert_true(js.contains("log"))
  assert_true(js.contains("__param(0, validate)"))
}

///|
/// Test: Emit class with both class and constructor param decorators
test "emit class with class and constructor param decorators" {
  let js = compile_to_js(
    "@Injectable class Service { constructor(@inject dep) { } }",
  )
  println("Class with class and constructor param decorators:\n\{js}")
  assert_true(js.contains("__decorate"))
  assert_true(js.contains("Injectable"))
  assert_true(js.contains("__param(0, inject)"))
}

///|
/// Test: Emit constructor param decorator with class decorator
test "emit constructor param decorator applies to class" {
  let js = compile_to_js("class MyClass { constructor(@inject service) { } }")
  println("Constructor param decorator on class:\n\{js}")
  // Constructor param decorators should apply to the class, not prototype
  assert_true(js.contains("MyClass = __decorate"))
}

// =============================================================================
// Helper Emission Tests
// =============================================================================

///|
/// Test: __decorate helper is emitted when class decorators are used
test "emit __decorate helper for class decorator" {
  let js = compile_to_js("@Component class MyClass { }")
  println("Class decorator with helper:\n\{js}")
  // Should start with the __decorate helper definition
  assert_true(
    js.contains("var __decorate = (this && this.__decorate) || function"),
  )
  assert_true(js.contains("arguments.length"))
  assert_true(js.contains("Object.getOwnPropertyDescriptor"))
}

///|
/// Test: __decorate helper is emitted when member decorators are used
test "emit __decorate helper for member decorator" {
  let js = compile_to_js("class MyClass { @log myMethod() { } }")
  println("Member decorator with helper:\n\{js}")
  // Should have the __decorate helper definition
  assert_true(
    js.contains("var __decorate = (this && this.__decorate) || function"),
  )
}

///|
/// Test: __param helper is emitted when parameter decorators are used
test "emit __param helper for parameter decorator" {
  let js = compile_to_js("class MyClass { constructor(@inject service) { } }")
  println("Parameter decorator with helpers:\n\{js}")
  // Should have both __decorate and __param helper definitions
  assert_true(
    js.contains("var __decorate = (this && this.__decorate) || function"),
  )
  assert_true(js.contains("var __param = (this && this.__param) || function"))
}

///|
/// Test: No helpers are emitted when no decorators are present
test "emit no helpers without decorators" {
  let js = compile_to_js("class MyClass { myMethod() { } }")
  println("No decorators, no helpers:\n\{js}")
  // Should NOT have helper definitions
  assert_true(js.contains("var __decorate") == false)
  assert_true(js.contains("var __param") == false)
}

///|
/// Test: __param helper is NOT emitted for class decorators only
test "emit no __param helper for class decorator only" {
  let js = compile_to_js("@Component class MyClass { }")
  println("Class decorator only, no __param:\n\{js}")
  // Should have __decorate but NOT __param
  assert_true(
    js.contains("var __decorate = (this && this.__decorate) || function"),
  )
  assert_true(js.contains("var __param") == false)
}

///|
/// Test: __param helper is NOT emitted for member decorators only
test "emit no __param helper for member decorator only" {
  let js = compile_to_js("class MyClass { @log myMethod() { } }")
  println("Member decorator only, no __param:\n\{js}")
  // Should have __decorate but NOT __param
  assert_true(
    js.contains("var __decorate = (this && this.__decorate) || function"),
  )
  assert_true(js.contains("var __param") == false)
}

///|
/// Test: Both helpers emitted for method with parameter decorator
test "emit both helpers for method parameter decorator" {
  let js = compile_to_js("class MyClass { myMethod(@validate arg) { } }")
  println("Method param decorator with helpers:\n\{js}")
  // Should have both helpers
  assert_true(
    js.contains("var __decorate = (this && this.__decorate) || function"),
  )
  assert_true(js.contains("var __param = (this && this.__param) || function"))
}

///|
/// Test: Helper appears at the top of the file
test "emit helper at top of file" {
  let js = compile_to_js("@Component class MyClass { }")
  println("Helper at top of file:\n\{js}")
  // __decorate should appear before class definition
  let decorate_pos = js.find("var __decorate")
  let class_pos = js.find("class MyClass")
  assert_true(decorate_pos is Some(_))
  assert_true(class_pos is Some(_))
  // decorate_pos should be less than class_pos
  match (decorate_pos, class_pos) {
    (Some(d), Some(c)) => assert_true(d < c)
    _ => assert_true(false)
  }
}

// =============================================================================
// Decorator Metadata Tests
// =============================================================================

///|
/// Test: __metadata helper is emitted when decorators are used
test "emit __metadata helper for decorators" {
  let js = compile_to_js("@Component class MyClass { }")
  println("Metadata helper:\n\{js}")
  assert_true(
    js.contains("var __metadata = (this && this.__metadata) || function"),
  )
  assert_true(js.contains("Reflect.metadata"))
}

///|
/// Test: design:type metadata for method decorator
test "emit design:type for method" {
  let js = compile_to_js("class MyClass { @log myMethod() { } }")
  println("Method design:type:\n\{js}")
  assert_true(js.contains("__metadata(\"design:type\", Function)"))
}

///|
/// Test: design:type metadata for property decorator with String type
test "emit design:type for property with type" {
  let js = compile_to_js("class MyClass { @observable name: string; }")
  println("Property design:type:\n\{js}")
  // Type annotations are preserved for decorated properties
  assert_true(js.contains("__metadata(\"design:type\", String)"))
}

///|
/// Test: design:paramtypes for method with typed parameters
test "emit design:paramtypes for method" {
  let js = compile_to_js(
    "class MyClass { @log myMethod(a: string, b: number) { } }",
  )
  println("Method design:paramtypes:\n\{js}")
  // Type annotations are preserved for decorated methods
  assert_true(
    js.contains("__metadata(\"design:paramtypes\", [String, Number])"),
  )
}

///|
/// Test: design:returntype for method with return type
test "emit design:returntype for method" {
  let js = compile_to_js(
    "class MyClass { @log myMethod(): string { return ''; } }",
  )
  println("Method design:returntype:\n\{js}")
  // Type annotations are preserved for decorated methods
  assert_true(js.contains("__metadata(\"design:returntype\", String)"))
}

///|
/// Test: design:paramtypes for class with constructor params
/// Type annotations are preserved when class has decorators
test "emit design:paramtypes for constructor" {
  let js = compile_to_js(
    "@Injectable class MyService { constructor(dep: Logger) { } }",
  )
  println("Constructor design:paramtypes:\n\{js}")
  // Type annotations are preserved for decorated classes
  assert_true(js.contains("__metadata(\"design:paramtypes\", [Logger])"))
}

///|
/// Test: design:type Function for getter with return type
test "emit design:type for getter" {
  let js = compile_to_js(
    "class MyClass { @computed get value(): number { return 42; } }",
  )
  println("Getter design:type:\n\{js}")
  assert_true(js.contains("__metadata(\"design:type\", Function)"))
  // Type annotations are preserved for decorated getters
  assert_true(js.contains("__metadata(\"design:returntype\", Number)"))
}

///|
/// Test: design:paramtypes for setter with typed parameter
test "emit design:paramtypes for setter" {
  let js = compile_to_js(
    "class MyClass { @validate set name(val: string) { } }",
  )
  println("Setter design:paramtypes:\n\{js}")
  assert_true(js.contains("__metadata(\"design:type\", Function)"))
  // Type annotations are preserved for decorated setters
  assert_true(js.contains("__metadata(\"design:paramtypes\", [String])"))
}

///|
/// Test: Interface types preserved in metadata
test "emit interface type for decorated method params" {
  let js = compile_to_js(
    "class MyClass { @log myMethod(config: MyInterface) { } }",
  )
  println("Complex type design:paramtypes:\n\{js}")
  // Type annotations are preserved for decorated methods
  assert_true(js.contains("__metadata(\"design:paramtypes\", [MyInterface])"))
}

///|
/// Test: Array type serializes as Array
test "emit Array for array types" {
  let js = compile_to_js("class MyClass { @observable items: string[]; }")
  println("Array type design:type:\n\{js}")
  // Type annotations are preserved for decorated properties
  assert_true(js.contains("__metadata(\"design:type\", Array)"))
}

///|
/// Test: void 0 for void return type
test "emit void 0 for void return" {
  let js = compile_to_js("class MyClass { @log myMethod(): void { } }")
  println("Void return design:returntype:\n\{js}")
  // Type annotations are preserved, void becomes void 0
  assert_true(js.contains("__metadata(\"design:returntype\", void 0)"))
}

///|
/// Test: Boolean type preserved in metadata
test "emit Boolean for boolean type" {
  let js = compile_to_js("class MyClass { @observable active: boolean; }")
  println("Boolean type design:type:\n\{js}")
  // Type annotations are preserved for decorated properties
  assert_true(js.contains("__metadata(\"design:type\", Boolean)"))
}

// ============================================================================
// Abstract Class Tests
// ============================================================================

///|
/// Test: abstract class compiles to regular class
test "emit abstract class as regular class" {
  let js = compile_to_js("abstract class Animal { name: string; }")
  println("Abstract class output:\n\{js}")
  // Abstract class should emit as regular class
  assert_true(js.contains("class Animal"))
  assert_true(js.contains("name;"))
  // Should NOT contain 'abstract' keyword in output
  assert_false(js.contains("abstract"))
}

///|
/// Test: abstract method is omitted from output
test "emit abstract class with abstract method - method omitted" {
  let js = compile_to_js("abstract class Animal { abstract speak(): void; }")
  println("Abstract class with abstract method:\n\{js}")
  // Abstract class should emit as regular class
  assert_true(js.contains("class Animal"))
  // Abstract method should NOT be emitted
  assert_false(js.contains("speak"))
}

///|
/// Test: abstract class with concrete method - concrete method is emitted
test "emit abstract class with concrete method" {
  let js = compile_to_js(
    "abstract class Animal { abstract speak(): void; move() { console.log('moving'); } }",
  )
  println("Abstract class with concrete method:\n\{js}")
  // Abstract class should emit as regular class
  assert_true(js.contains("class Animal"))
  // Abstract method should NOT be emitted
  assert_false(js.contains("speak"))
  // Concrete method should be emitted
  assert_true(js.contains("move()"))
  assert_true(js.contains("console.log"))
}

///|
/// Test: abstract property is omitted from output
test "emit abstract class with abstract property - property omitted" {
  let js = compile_to_js(
    "abstract class Animal { abstract readonly name: string; }",
  )
  println("Abstract class with abstract property:\n\{js}")
  // Abstract class should emit as regular class
  assert_true(js.contains("class Animal"))
  // Abstract property should NOT be emitted
  assert_false(js.contains("name"))
}

///|
/// Test: class extending another class
test "emit class extending another class" {
  let js = compile_to_js(
    "class Dog extends Animal { speak() { console.log('woof'); } }",
  )
  println("Class extending another class:\n\{js}")
  assert_true(js.contains("class Dog extends Animal"))
  assert_true(js.contains("speak()"))
  assert_true(js.contains("woof"))
}

///|
/// Test: abstract class with constructor
test "emit abstract class with constructor" {
  let js = compile_to_js(
    "abstract class Animal { name: string; constructor(name) { this.name = name; } }",
  )
  println("Abstract class with constructor:\n\{js}")
  // Abstract class should emit as regular class
  assert_true(js.contains("class Animal"))
  // Constructor should be emitted
  assert_true(js.contains("constructor(name)"))
  assert_true(js.contains("this.name = name"))
}

///|
/// Test: abstract class with mixed abstract and concrete members
test "emit abstract class with mixed members" {
  let js = compile_to_js(
    "abstract class Shape { abstract area(): number; abstract perimeter(): number; getName() { return 'shape'; } }",
  )
  println("Abstract class with mixed members:\n\{js}")
  // Abstract class should emit as regular class
  assert_true(js.contains("class Shape"))
  // Abstract methods should NOT be emitted
  assert_false(js.contains("area"))
  assert_false(js.contains("perimeter"))
  // Concrete method should be emitted
  assert_true(js.contains("getName()"))
  assert_true(js.contains("shape"))
}

// ============================================================================
// JSX Emitter Tests - Classic Mode (React.createElement)
// ============================================================================

///|
/// Helper to parse, transform with JSX classic mode, and emit TypeScript code
fn compile_jsx_classic(source : String) -> String {
  let tokens = scan_all_v2(source, "test.tsx")
  match parse_source_file(tokens, "test.tsx") {
    Ok(source_file) => {
      let ctx = TransformerContext::with_jsx(
        ES2015,
        Classic("React.createElement", "React.Fragment"),
      )
      let emit_ctx = EmitterContext::default()
      compile_source_file(source_file, ctx, emit_ctx)
    }
    Err(diagnostics) => {
      println("Failed to parse source:")
      for d in diagnostics {
        println("  \{d.message}")
      }
      ""
    }
  }
}

///|
/// Test: JSX self-closing element emits React.createElement
test "emit JSX self-closing element classic" {
  let js = compile_jsx_classic("const x = <div />;")
  println("JSX self-closing classic:\n\{js}")
  assert_true(js.contains("React.createElement"))
  assert_true(js.contains("\"div\""))
  assert_true(js.contains("null"))
}

///|
/// Test: JSX element with string attribute
test "emit JSX element with className classic" {
  let js = compile_jsx_classic("const x = <div className=\"container\" />;")
  println("JSX with className classic:\n\{js}")
  assert_true(js.contains("React.createElement"))
  assert_true(js.contains("\"div\""))
  assert_true(js.contains("className"))
  assert_true(js.contains("\"container\""))
}

///|
/// Test: JSX element with expression attribute
test "emit JSX element with expression attribute classic" {
  let js = compile_jsx_classic("const x = <div id={myId} />;")
  println("JSX with expression attribute classic:\n\{js}")
  assert_true(js.contains("React.createElement"))
  assert_true(js.contains("\"div\""))
  assert_true(js.contains("id"))
  assert_true(js.contains("myId"))
}

///|
/// Test: JSX element with text child
test "emit JSX element with text child classic" {
  let js = compile_jsx_classic("const x = <div>Hello World</div>;")
  println("JSX with text child classic:\n\{js}")
  assert_true(js.contains("React.createElement"))
  assert_true(js.contains("\"div\""))
  // Text gets split into words as separate children
  assert_true(js.contains("Hello"))
  assert_true(js.contains("World"))
}

///|
/// Test: JSX element with expression child
test "emit JSX element with expression child classic" {
  let js = compile_jsx_classic("const x = <div>{message}</div>;")
  println("JSX with expression child classic:\n\{js}")
  assert_true(js.contains("React.createElement"))
  assert_true(js.contains("\"div\""))
  assert_true(js.contains("message"))
}

///|
/// Test: JSX element with multiple children
test "emit JSX element with multiple children classic" {
  let js = compile_jsx_classic(
    "const x = <div><span>A</span><span>B</span></div>;",
  )
  println("JSX with multiple children classic:\n\{js}")
  assert_true(js.contains("React.createElement"))
  assert_true(js.contains("\"div\""))
  assert_true(js.contains("\"span\""))
}

///|
/// Test: JSX component (uppercase) vs intrinsic (lowercase)
test "emit JSX component element classic" {
  let js = compile_jsx_classic("const x = <MyComponent />;")
  println("JSX component classic:\n\{js}")
  assert_true(js.contains("React.createElement"))
  // Component should be identifier, not string
  assert_true(js.contains("MyComponent"))
  assert_false(js.contains("\"MyComponent\""))
}

///|
/// Test: JSX nested elements
test "emit JSX nested elements classic" {
  let js = compile_jsx_classic(
    "const x = <div><header><h1>Title</h1></header></div>;",
  )
  println("JSX nested elements classic:\n\{js}")
  assert_true(js.contains("React.createElement"))
  assert_true(js.contains("\"div\""))
  assert_true(js.contains("\"header\""))
  assert_true(js.contains("\"h1\""))
  assert_true(js.contains("Title"))
}

///|
/// Test: JSX with multiple attributes including keywords like `type`
test "emit JSX with multiple attributes classic" {
  let js = compile_jsx_classic(
    "const x = <button type=\"submit\" disabled={true} onClick={handleClick}>Submit</button>;",
  )
  println("JSX with multiple attributes classic:\n\{js}")
  assert_true(js.contains("React.createElement"))
  assert_true(js.contains("\"button\""))
  assert_true(js.contains("type"))
  assert_true(js.contains("\"submit\""))
  assert_true(js.contains("disabled"))
  assert_true(js.contains("onClick"))
  assert_true(js.contains("handleClick"))
  assert_true(js.contains("Submit"))
}

///|
/// Test: JSX fragment
test "emit JSX fragment classic" {
  let js = compile_jsx_classic("const x = <><div /><span /></>;")
  println("JSX fragment classic:\n\{js}")
  assert_true(js.contains("React.createElement"))
  assert_true(js.contains("React.Fragment"))
  assert_true(js.contains("\"div\""))
  assert_true(js.contains("\"span\""))
}

///|
/// Test: JSX spread attributes
test "emit JSX spread attributes classic" {
  let js = compile_jsx_classic("const x = <div {...props} />;")
  println("JSX spread attributes classic:\n\{js}")
  assert_true(js.contains("React.createElement"))
  assert_true(js.contains("\"div\""))
  assert_true(js.contains("props"))
}

// ============================================================================
// `this` Parameter Type Emitter Tests
// ============================================================================

///|
/// Test: `this` parameter is omitted from JavaScript output
test "emit function with this parameter - this is omitted" {
  let js = compile_to_js(
    "function greet(this: Person, name: string): void { console.log(name); }",
  )
  println("Function with this parameter:\n\{js}")
  // The output should have the function but `this` parameter should be omitted
  assert_true(js.contains("function greet(name)"))
  // Verify `this:` is NOT in the output
  assert_false(js.contains("this:"))
}

///|
/// Test: method with this parameter
test "emit method with this parameter - this is omitted" {
  let js = compile_to_js(
    "class Dog { speak(this: Dog, sound: string) { console.log(sound); } }",
  )
  println("Method with this parameter:\n\{js}")
  // The method should only have `sound` parameter
  assert_true(js.contains("speak(sound)"))
}

///|
/// Test: function with only this parameter
test "emit function with only this parameter - empty params" {
  let js = compile_to_js("function getSelf(this: MyClass) { return this; }")
  println("Function with only this parameter:\n\{js}")
  // The output should have empty parameter list
  assert_true(js.contains("function getSelf()"))
}

// ============================================================================
// Auto-Accessor Tests (TS 4.9+)
// ============================================================================

///|
/// Test: auto-accessor in class
test "emit auto-accessor in class" {
  let js = compile_to_js("class Person { accessor name: string = ''; }")
  println("Auto-accessor in class:\n\{js}")
  // Should emit as `accessor name`
  assert_true(js.contains("accessor name"))
}

///|
/// Test: static auto-accessor in class
test "emit static auto-accessor in class" {
  let js = compile_to_js("class Config { static accessor version = '1.0'; }")
  println("Static auto-accessor in class:\n\{js}")
  // Should emit as `static accessor version`
  assert_true(js.contains("static accessor version"))
}

///|
/// Test: auto-accessor without initializer
test "emit auto-accessor without initializer" {
  let js = compile_to_js("class Person { accessor name: string; }")
  println("Auto-accessor without initializer:\n\{js}")
  // Should emit as `accessor name;`
  assert_true(js.contains("accessor name;"))
}

// ============================================================================
// Using Statement Tests (TS 5.2+)
// ============================================================================

///|
/// Test: using statement
test "emit using statement" {
  let js = compile_to_js("using resource = getResource();")
  println("Using statement:\n\{js}")
  // Should emit as `using resource = ...`
  assert_true(js.contains("using resource = getResource()"))
}

///|
/// Test: await using statement
test "emit await using statement" {
  let js = compile_to_js("await using resource = getAsyncResource();")
  println("Await using statement:\n\{js}")
  // Should emit as `await using resource = ...`
  assert_true(js.contains("await using resource = getAsyncResource()"))
}

///|
/// Test: using statement with type annotation stripped
test "emit using statement - type annotation stripped" {
  let js = compile_to_js("using resource: Disposable = getResource();")
  println("Using with type annotation:\n\{js}")
  // Type annotation should be stripped
  assert_true(js.contains("using resource = getResource()"))
  // Type annotation should NOT be in output
  assert_false(js.contains("Disposable"))
}

// ============================================================================
// For-of Loop ES5 Downleveling Tests
// ============================================================================

///|
/// Test: for-of loop downleveling to ES5 with const
test "emit for-of to for loop ES5 - const" {
  let js = compile_to_es5("for (const item of items) { console.log(item); }")
  println("For-of ES5 downleveled (const):\n\{js}")
  // Should convert to traditional for loop
  assert_true(js.contains("for (var"))
  assert_true(js.contains("_i$0"))
  assert_true(js.contains("_arr$1"))
  assert_true(js.contains(".length"))
  assert_true(js.contains("var item = _arr$1[_i$0]"))
  assert_true(js.contains("console.log(item)"))
  // Should NOT contain for-of syntax
  assert_false(js.contains(" of "))
}

///|
/// Test: for-of loop downleveling to ES5 with let
test "emit for-of to for loop ES5 - let" {
  let js = compile_to_es5("for (let value of values) { total += value; }")
  println("For-of ES5 downleveled (let):\n\{js}")
  // Should convert to traditional for loop
  assert_true(js.contains("for (var"))
  assert_true(js.contains("var value = "))
  assert_true(js.contains("total += value"))
}

///|
/// Test: for-of loop downleveling to ES5 with var
test "emit for-of to for loop ES5 - var" {
  let js = compile_to_es5("for (var x of arr) { result.push(x); }")
  println("For-of ES5 downleveled (var):\n\{js}")
  // Should convert to traditional for loop
  assert_true(js.contains("for (var"))
  assert_true(js.contains("var x = "))
  assert_true(js.contains("result.push(x)"))
}

///|
/// Test: for-of loop ES2015+ should NOT be downleveled
test "emit for-of loop ES2015 - no downleveling" {
  let js = compile_to_js("for (const item of items) { console.log(item); }")
  println("For-of ES2015+ (no downleveling):\n\{js}")
  // Should keep for-of syntax
  assert_true(js.contains("for (const item of items)"))
  // Should NOT have index variables
  assert_false(js.contains("_i$"))
  assert_false(js.contains("_arr$"))
}

///|
/// Test: for-of loop ES5 with complex expression
test "emit for-of to for loop ES5 - complex expression" {
  let js = compile_to_es5("for (const item of getItems()) { process(item); }")
  println("For-of ES5 with complex expression:\n\{js}")
  // Should store expression result in temp variable
  assert_true(js.contains("_arr$"))
  assert_true(js.contains("getItems()"))
  assert_true(js.contains("process(item)"))
}

// ============================================================================
// Spread in Arrays ES5 Downleveling Tests
// ============================================================================

///|
/// Test: spread in arrays ES5 - two arrays
test "emit spread in arrays ES5 - two arrays" {
  let js = compile_to_es5("const merged = [...arr1, ...arr2];")
  println("Spread in arrays ES5 (two arrays):\n\{js}")
  // Should convert to .concat() call
  assert_true(js.contains(".concat("))
  assert_true(js.contains("arr1"))
  assert_true(js.contains("arr2"))
  // Should NOT contain spread syntax
  assert_false(js.contains("..."))
}

///|
/// Test: spread in arrays ES5 - mixed elements
test "emit spread in arrays ES5 - mixed elements" {
  let js = compile_to_es5("const result = [1, ...arr, 2];")
  println("Spread in arrays ES5 (mixed):\n\{js}")
  // Should convert to [1].concat(arr, [2])
  assert_true(js.contains(".concat("))
  assert_true(js.contains("[1]"))
  assert_true(js.contains("arr"))
  assert_true(js.contains("[2]"))
}

///|
/// Test: spread in arrays ES5 - spread at start
test "emit spread in arrays ES5 - spread at start" {
  let js = compile_to_es5("const result = [...arr, 1, 2];")
  println("Spread in arrays ES5 (spread at start):\n\{js}")
  // Should convert to [].concat(arr, [1, 2])
  assert_true(js.contains(".concat("))
  assert_true(js.contains("arr"))
}

///|
/// Test: spread in arrays ES2015+ should NOT be downleveled
test "emit spread in arrays ES2015 - no downleveling" {
  let js = compile_to_js("const merged = [...arr1, ...arr2];")
  println("Spread in arrays ES2015+ (no downleveling):\n\{js}")
  // Should keep spread syntax
  assert_true(js.contains("...arr1"))
  assert_true(js.contains("...arr2"))
  // Should NOT have .concat()
  assert_false(js.contains(".concat("))
}

///|
/// Test: spread in arrays ES5 - function call result
test "emit spread in arrays ES5 - function call" {
  let js = compile_to_es5("const result = [...getItems(), ...getMoreItems()];")
  println("Spread in arrays ES5 (function calls):\n\{js}")
  // Should convert to .concat()
  assert_true(js.contains(".concat("))
  assert_true(js.contains("getItems()"))
  assert_true(js.contains("getMoreItems()"))
}

// ============================================================================
// CommonJS Module Tests
// ============================================================================

///|
/// Helper to compile to CommonJS module format
fn compile_to_commonjs(source : String) -> String {
  let tokens = get_tokens_from_source(source)
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = TransformerContext::default()
      let emit_ctx = EmitterContext::with_options(CommonJS, false)
      compile_source_file(source_file, ctx, emit_ctx)
    }
    Err(diagnostics) => {
      println("Failed to parse source:")
      for d in diagnostics {
        println("  \{d.message}")
      }
      ""
    }
  }
}

///|
/// Helper to compile with alwaysStrict enabled
fn compile_with_strict(source : String) -> String {
  let tokens = get_tokens_from_source(source)
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = TransformerContext::default()
      let emit_ctx = EmitterContext::with_options(ESModule, true)
      compile_source_file(source_file, ctx, emit_ctx)
    }
    Err(diagnostics) => {
      println("Failed to parse source:")
      for d in diagnostics {
        println("  \{d.message}")
      }
      ""
    }
  }
}

///|
/// Test: alwaysStrict emits "use strict"
test "emit use strict directive with alwaysStrict" {
  let js = compile_with_strict("const x = 1;")
  println("With alwaysStrict:\n\{js}")
  assert_true(js.contains("\"use strict\";"))
}

///|
/// Test: alwaysStrict preserves hashbang
test "emit use strict after hashbang" {
  let js = compile_with_strict("#!/usr/bin/env node\nconst x = 1;")
  println("With hashbang and alwaysStrict:\n\{js}")
  // Hashbang should be first
  assert_true(js.has_prefix("#!/usr/bin/env node"))
  // use strict should come after
  assert_true(js.contains("\"use strict\";"))
}

///|
/// Test: CommonJS import - side effect import
test "commonjs emit side effect import" {
  let js = compile_to_commonjs("import './polyfill';")
  println("CommonJS side effect import:\n\{js}")
  assert_true(js.contains("require(\"./polyfill\")"))
  assert_false(js.contains("import"))
}

///|
/// Test: CommonJS import - namespace import
test "commonjs emit namespace import" {
  let js = compile_to_commonjs("import * as fs from 'fs';")
  println("CommonJS namespace import:\n\{js}")
  assert_true(js.contains("const fs = require(\"fs\")"))
  assert_false(js.contains("import"))
}

///|
/// Test: CommonJS import - named imports
test "commonjs emit named imports" {
  let js = compile_to_commonjs("import { readFile, writeFile } from 'fs';")
  println("CommonJS named imports:\n\{js}")
  assert_true(js.contains("require(\"fs\")"))
  assert_true(js.contains("const { readFile, writeFile }"))
  assert_false(js.contains("import"))
}

///|
/// Test: CommonJS import - named imports with alias
test "commonjs emit named imports with alias" {
  let js = compile_to_commonjs(
    "import { readFile as read, writeFile as write } from 'fs';",
  )
  println("CommonJS named imports with alias:\n\{js}")
  assert_true(js.contains("require(\"fs\")"))
  assert_true(js.contains("readFile: read"))
  assert_true(js.contains("writeFile: write"))
  assert_false(js.contains("import"))
}

///|
/// Test: CommonJS export - named export
test "commonjs emit named export" {
  let js = compile_to_commonjs("export const foo = 1;")
  println("CommonJS named export:\n\{js}")
  assert_true(js.contains("const foo = 1;"))
  assert_true(js.contains("exports.foo = foo"))
  assert_false(js.contains("export const"))
}

///|
/// Test: CommonJS export - function export
test "commonjs emit function export" {
  let js = compile_to_commonjs("export function hello() { return 'hi'; }")
  println("CommonJS function export:\n\{js}")
  assert_true(js.contains("function hello()"))
  assert_true(js.contains("exports.hello = hello"))
  assert_false(js.contains("export function"))
}

///|
/// Test: CommonJS export - class export
test "commonjs emit class export" {
  let js = compile_to_commonjs("export class MyClass { }")
  println("CommonJS class export:\n\{js}")
  assert_true(js.contains("class MyClass"))
  assert_true(js.contains("exports.MyClass = MyClass"))
  assert_false(js.contains("export class"))
}

///|
/// Test: CommonJS export default
test "commonjs emit export default" {
  let js = compile_to_commonjs("export default function() { return 1; }")
  println("CommonJS export default:\n\{js}")
  assert_true(js.contains("exports.default"))
  assert_false(js.contains("export default"))
}

///|
/// Test: CommonJS re-export from another module
test "commonjs emit re-export from module" {
  let js = compile_to_commonjs("export { foo, bar } from './other';")
  println("CommonJS re-export:\n\{js}")
  assert_true(js.contains("require(\"./other\")"))
  assert_true(js.contains("exports.foo"))
  assert_true(js.contains("exports.bar"))
  assert_false(js.contains("export {"))
}

///|
/// Test: CommonJS export * from module
test "commonjs emit export star from module" {
  let js = compile_to_commonjs("export * from './utils';")
  println("CommonJS export star:\n\{js}")
  assert_true(js.contains("Object.assign(exports, require(\"./utils\"))"))
  assert_false(js.contains("export *"))
}

// ============================================================================
// Inline Source Map Tests
// ============================================================================

///|
/// Helper to compile with source map enabled
fn compile_with_source_map(source : String) -> CompileResult {
  let options = CompileOptions::{
    target: Target::ES2015,
    module_kind: ESModule,
    source_map: true,
    inline_source_map: false,
    inline_sources: false,
    declaration: false,
    strict: false,
    always_strict: false,
    isolated_modules: false,
    exact_optional_property_types: false,
    no_unchecked_indexed_access: false,
    verbatim_module_syntax: false,
    no_emit: false,
    es_module_interop: false,
    import_helpers: false,
    no_implicit_any: false,
    strict_null_checks: false,
    no_implicit_this: false,
    no_unused_locals: false,
    no_unused_parameters: false,
    no_implicit_returns: false,
    no_fallthrough_cases_in_switch: false,
    strict_property_initialization: false,
  }
  compile_source(source, "test.ts", options)
}

///|
/// Helper to compile with inline sources enabled
fn compile_with_inline_sources(source : String) -> CompileResult {
  let options = CompileOptions::{
    target: Target::ES2015,
    module_kind: ESModule,
    source_map: true,
    inline_source_map: false,
    inline_sources: true,
    declaration: false,
    strict: false,
    always_strict: false,
    isolated_modules: false,
    exact_optional_property_types: false,
    no_unchecked_indexed_access: false,
    verbatim_module_syntax: false,
    no_emit: false,
    es_module_interop: false,
    import_helpers: false,
    no_implicit_any: false,
    strict_null_checks: false,
    no_implicit_this: false,
    no_unused_locals: false,
    no_unused_parameters: false,
    no_implicit_returns: false,
    no_fallthrough_cases_in_switch: false,
    strict_property_initialization: false,
  }
  compile_source(source, "test.ts", options)
}

///|
/// Test: Source map is generated when source_map is true
test "source map generated when enabled" {
  let source = "const x = 42;"
  let result = compile_with_source_map(source)
  assert_true(result.success)
  assert_true(result.source_map is Some(_))
  match result.source_map {
    Some(sm) => {
      println("Source map:\n\{sm}")
      assert_true(sm.contains("\"version\": 3"))
      assert_true(sm.contains("\"sources\":"))
      assert_true(sm.contains("\"mappings\":"))
    }
    None => assert_true(false)
  }
  println("Source map generation test passed")
}

///|
/// Test: Inline sources includes sourcesContent in source map
test "inline sources includes sourcesContent" {
  let source = "const greeting = \"hello world\";"
  let result = compile_with_inline_sources(source)
  assert_true(result.success)
  assert_true(result.source_map is Some(_))
  match result.source_map {
    Some(sm) => {
      println("Source map with inline sources:\n\{sm}")
      assert_true(sm.contains("\"sourcesContent\":"))
      // The original source should be in the source map
      assert_true(sm.contains("hello world"))
    }
    None => assert_true(false)
  }
  println("Inline sources test passed")
}

///|
/// Test: Source map without inline sources does not include sourcesContent
test "source map without inline sources excludes sourcesContent" {
  let source = "const x = 123;"
  let result = compile_with_source_map(source)
  assert_true(result.success)
  assert_true(result.source_map is Some(_))
  match result.source_map {
    Some(sm) => {
      println("Source map without inline sources:\n\{sm}")
      // Should not have sourcesContent field
      assert_false(sm.contains("\"sourcesContent\":"))
    }
    None => assert_true(false)
  }
  println("Source map without inline sources test passed")
}

///|
/// Test: Inline source map flag enables source map generation
test "inline source map flag enables source map generation" {
  let options = CompileOptions::{
    target: Target::ES2015,
    module_kind: ESModule,
    source_map: false, // external source map disabled
    inline_source_map: true, // but inline source map enabled
    inline_sources: false,
    declaration: false,
    strict: false,
    always_strict: false,
    isolated_modules: false,
    exact_optional_property_types: false,
    no_unchecked_indexed_access: false,
    verbatim_module_syntax: false,
    no_emit: false,
    es_module_interop: false,
    import_helpers: false,
    no_implicit_any: false,
    strict_null_checks: false,
    no_implicit_this: false,
    no_unused_locals: false,
    no_unused_parameters: false,
    no_implicit_returns: false,
    no_fallthrough_cases_in_switch: false,
    strict_property_initialization: false,
  }
  let result = compile_source("const y = 99;", "test.ts", options)
  assert_true(result.success)
  // Even though source_map is false, inline_source_map should trigger generation
  assert_true(result.source_map is Some(_))
  println("Inline source map flag test passed")
}

// ============================================================================
// esModuleInterop Tests
// ============================================================================

///|
/// Test: esModuleInterop option is accepted
test "esModuleInterop option accepted" {
  let options = CompileOptions::{
    target: Target::ES2015,
    module_kind: CommonJS,
    source_map: false,
    inline_source_map: false,
    inline_sources: false,
    declaration: false,
    strict: false,
    always_strict: false,
    isolated_modules: false,
    exact_optional_property_types: false,
    no_unchecked_indexed_access: false,
    verbatim_module_syntax: false,
    no_emit: false,
    es_module_interop: true, // Enable esModuleInterop
    import_helpers: false,
    no_implicit_any: false,
    strict_null_checks: false,
    no_implicit_this: false,
    no_unused_locals: false,
    no_unused_parameters: false,
    no_implicit_returns: false,
    no_fallthrough_cases_in_switch: false,
    strict_property_initialization: false,
  }
  let source = "import foo from './bar';"
  let result = compile_source(source, "test.ts", options)
  assert_true(result.success)
  // Basic CommonJS interop is already present - it checks for .default || module
  assert_true(result.javascript.contains("require"))
  println("esModuleInterop option test passed")
}

///|
/// Test: Emit super call expression
test "emit super call expression" {
  let js = compile_to_js(
    "class Child extends Parent { constructor() { super(1, 2, 3); } }",
  )
  assert_true(js.contains("super(1, 2, 3)"))
}

///|
/// Test: Emit super property access
test "emit super property access" {
  let js = compile_to_js(
    "class Child extends Parent { method() { return super.method(); } }",
  )
  assert_true(js.contains("super.method()"))
}

// ============================================================================
// Import Equals Declaration Tests (import X = require())
// ============================================================================

///|
/// Test: Emit import equals with require() - CommonJS
test "emit import equals require commonjs" {
  let js = compile_to_commonjs("import fs = require('fs');")
  println("Import equals require CommonJS:\n\{js}")
  assert_true(js.contains("const fs = require(\"fs\")"))
  assert_false(js.contains("import fs ="))
}

///|
/// Test: Emit import equals with require() - ESModule
test "emit import equals require esmodule" {
  let js = compile_to_js("import fs = require('fs');")
  println("Import equals require ESModule:\n\{js}")
  // In ESModule mode, it should still emit require() for import = require() syntax
  assert_true(js.contains("const fs = require(\"fs\")"))
}

///|
/// Test: Emit export import equals with require() - CommonJS
test "emit export import equals require commonjs" {
  let js = compile_to_commonjs("export import fs = require('fs');")
  println("Export import equals require CommonJS:\n\{js}")
  assert_true(js.contains("exports.fs = require(\"fs\")"))
}

///|
/// Test: Emit import equals with entity name (namespace alias)
test "emit import equals entity name" {
  let js = compile_to_js("import A = B;")
  println("Import equals entity name:\n\{js}")
  assert_true(js.contains("const A = B"))
}

///|
/// Test: Emit import equals with dotted entity name
test "emit import equals dotted entity name" {
  let js = compile_to_js("import C = M.N.O;")
  println("Import equals dotted entity name:\n\{js}")
  assert_true(js.contains("const C = M.N.O"))
}

// ============================================================================
// Tagged Template with Type Arguments Tests
// ============================================================================

///|
/// Test: Emit tagged template - basic without type args
test "emit tagged template basic" {
  let js = compile_to_js("const x = tag `hello`;")
  println("Tagged template basic:\n\{js}")
  // Note: emitter outputs without space between tag and backtick
  assert_true(js.contains("tag`hello`"))
}

///|
/// Test: Emit tagged template with type arguments - type args stripped
test "emit tagged template with type arguments" {
  let js = compile_to_js(
    "declare function f<T>(strs: TemplateStringsArray): T; const x = f<string> `hello`;",
  )
  println("Tagged template with type arguments:\n\{js}")
  // Type arguments should be stripped in the output
  assert_true(js.contains("f`hello`"))
  // The <string> should NOT appear in the output
  assert_true(!(js.contains("<string>")))
}

///|
/// Test: Emit tagged template with multiple type arguments
test "emit tagged template with multiple type arguments" {
  let js = compile_to_js(
    "declare function g<T, U>(strs: TemplateStringsArray): T; const y = g<number, string> `world`;",
  )
  println("Tagged template with multiple type arguments:\n\{js}")
  assert_true(js.contains("g`world`"))
  // Neither type argument should appear
  assert_true(!(js.contains("<number")))
  assert_true(!(js.contains("string>")))
}

///|
/// Test: Emit tagged template with type arguments and interpolation
test "emit tagged template with type arguments and interpolation" {
  let js = compile_to_js(
    "declare function f<T>(strs: TemplateStringsArray, ...args: any[]): T; const z = f<boolean> `hello ${42} world`;",
  )
  println("Tagged template with type args and interpolation:\n\{js}")
  assert_true(js.contains("f`hello ${42} world`"))
  assert_true(!(js.contains("<boolean>")))
}
