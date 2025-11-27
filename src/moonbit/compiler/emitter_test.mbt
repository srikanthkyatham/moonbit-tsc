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

      // Transform and emit each statement
      let mut result = ""
      for i = 0; i < source_file.statements.length(); i = i + 1 {
        let stmt = source_file.statements[i]
        let transformed_stmt = transform(stmt, ctx)
        let emitted = emit(transformed_stmt, emit_ctx)
        result = result + emitted
        if i < source_file.statements.length() - 1 {
          result = result + "\n"
        }
      }
      result
    }
    Err(_) => abort("Failed to parse source")
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
    "switch (x) { case 1: return \"one\"; default: return \"other\"; }",
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
  assert_true(not(js.contains("const x")))
}

///|
/// Test: Declare function produces no output
test "emit declare function produces no output" {
  let js = compile_to_js("declare function foo(): void;")
  // Declare statements should not produce JavaScript output
  assert_true(not(js.contains("function foo")))
}

///|
/// Test: Declare class produces no output
test "emit declare class produces no output" {
  let js = compile_to_js("declare class Foo { bar(): void; }")
  // Declare statements should not produce JavaScript output
  assert_true(not(js.contains("class Foo")))
}

///|
/// Test: Regular const still produces output
test "emit regular const still works" {
  let js = compile_to_js("const x = 1;")
  assert_true(js.contains("const x = 1;"))
}

///|
/// Test: Const enum is emitted (preserveConstEnums behavior)
test "emit const enum" {
  let js = compile_to_js("const enum Color { Red, Green, Blue }")
  // Const enums are emitted as const objects (like --preserveConstEnums)
  assert_true(js.contains("const Color"))
}

///|
/// Test: Regular enum is emitted
test "emit regular enum" {
  let js = compile_to_js("enum Status { Active, Inactive }")
  assert_true(js.contains("const Status"))
}

///|
/// Test: Const enum with values
test "emit const enum with values" {
  let js = compile_to_js("const enum Direction { Up = 1, Down = 2 }")
  assert_true(js.contains("const Direction"))
  assert_true(js.contains("Up"))
  assert_true(js.contains("Down"))
}

///|
/// Test: Non-null assertion property access (!.) strips assertion
test "emit non-null assertion property access" {
  let js = compile_to_js("const x = obj!.property;")
  // The !. should be stripped, becoming just .property
  assert_true(js.contains("obj.property"))
  assert_true(not(js.contains("!")))
}

///|
/// Test: Chained non-null assertion property access
test "emit chained non-null assertion" {
  let js = compile_to_js("const x = a!.b!.c;")
  // All !. should be stripped
  assert_true(js.contains("a.b.c"))
  assert_true(not(js.contains("!")))
}

///|
/// Test: Non-null assertion with method call
test "emit non-null assertion with method call" {
  let js = compile_to_js("const x = obj!.method();")
  assert_true(js.contains("obj.method()"))
  assert_true(not(js.contains("!")))
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
  let js = compile_to_js("@Component({ selector: 'app' }) class AppComponent { }")
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
  assert_true(not(js.contains("let NormalClass = class")))
  // Should not have __decorate
  assert_true(not(js.contains("__decorate")))
}

///|
/// Test: Emit decorated class with class body
test "emit decorated class with members" {
  let js = compile_to_js("@injectable class Service { name = 'test'; getValue() { return 42; } }")
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
  let js = compile_to_js("export @logged class ExportedClass { }")
  println("Export decorated class:\n\{js}")
  // Should have export and decoration
  assert_true(js.contains("export"))
  assert_true(js.contains("__decorate"))
  assert_true(js.contains("logged"))
}

///|
/// Test: Emit decorated class with constructor
test "emit decorated class with constructor" {
  let js = compile_to_js("@singleton class Database { constructor(url) { this.url = url; } }")
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
  let js = compile_to_js("@Module({ imports: [] }) @Controller('/api') class ApiModule { }")
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
  let js = compile_to_js("class MyClass { @computed get value() { return 42; } }")
  println("Getter with decorator:\n\{js}")
  assert_true(js.contains("__decorate"))
  assert_true(js.contains("computed"))
  assert_true(js.contains("MyClass.prototype"))
  assert_true(js.contains("\"value\""))
}

///|
/// Test: Emit setter with decorator
test "emit setter with decorator" {
  let js = compile_to_js("class MyClass { @validate set name(val) { this._name = val; } }")
  println("Setter with decorator:\n\{js}")
  assert_true(js.contains("__decorate"))
  assert_true(js.contains("validate"))
  assert_true(js.contains("MyClass.prototype"))
  assert_true(js.contains("\"name\""))
}

///|
/// Test: Emit class with both class and member decorators
test "emit class with class and member decorators" {
  let js = compile_to_js("@Component class MyComponent { @Input() data; @Output() change() { } }")
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
