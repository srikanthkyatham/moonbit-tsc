// End-to-end integration tests for TypeScript compilation
// Tests complete compilation pipeline from source to JavaScript

///|
/// Helper to compile TypeScript source and get JavaScript output
/// Uses the same approach as emitter_integration_test.mbt
fn e2e_compile_to_js(source : String) -> String {
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let transform_ctx = TransformerContext::default()
      let emit_ctx = EmitterContext::default()

      // Transform and emit each statement
      let mut result = ""
      for i = 0; i < source_file.statements.length(); i = i + 1 {
        let stmt = source_file.statements[i]
        let transformed_stmt = transform(stmt, transform_ctx)
        let emitted = emit(transformed_stmt, emit_ctx)
        result = result + emitted
        if i < source_file.statements.length() - 1 {
          result = result + "\n"
        }
      }
      result
    }
    Err(_) => ""
  }
}

///|
/// Helper to check if parsing succeeds
fn e2e_parse_succeeds(source : String) -> Bool {
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(_) => true
    Err(_) => false
  }
}

// ============================================================================
// Basic Variable Declarations
// ============================================================================

///|
test "e2e: const declaration" {
  let js = e2e_compile_to_js("const x = 42;")
  assert_true(js.contains("const x = 42"))
}

///|
test "e2e: let declaration" {
  let js = e2e_compile_to_js("let y = 'hello';")
  assert_true(js.contains("let y"))
}

///|
test "e2e: var declaration" {
  let js = e2e_compile_to_js("var z = true;")
  assert_true(js.contains("var z = true"))
}

// ============================================================================
// Functions
// ============================================================================

///|
test "e2e: simple function" {
  let js = e2e_compile_to_js("function greet(name) { return 'Hello ' + name; }")
  assert_true(js.contains("function greet"))
}

///|
test "e2e: arrow function" {
  let js = e2e_compile_to_js("const add = (a, b) => a + b;")
  assert_true(js.contains("=>"))
}

// ============================================================================
// Classes
// ============================================================================

///|
test "e2e: class declaration" {
  let js = e2e_compile_to_js("class Person { constructor(name) { this.name = name; } }")
  assert_true(js.contains("class Person"))
}

// ============================================================================
// Control Flow
// ============================================================================

///|
test "e2e: if statement" {
  let js = e2e_compile_to_js("if (x > 0) { console.log('positive'); }")
  assert_true(js.contains("if"))
}

///|
test "e2e: for loop" {
  let js = e2e_compile_to_js("for (let i = 0; i < 10; i++) { sum += i; }")
  assert_true(js.contains("for"))
}

///|
test "e2e: while loop" {
  let js = e2e_compile_to_js("while (condition) { doSomething(); }")
  assert_true(js.contains("while"))
}

// ============================================================================
// Operators and Expressions
// ============================================================================

///|
test "e2e: binary operators" {
  let js = e2e_compile_to_js("const result = a + b * c;")
  assert_true(js.contains("+"))
}

///|
test "e2e: ternary operator" {
  let js = e2e_compile_to_js("const max = a > b ? a : b;")
  assert_true(js.contains("?"))
}

// ============================================================================
// Modules
// ============================================================================

///|
test "e2e: import statement" {
  let js = e2e_compile_to_js("import { foo } from './module';")
  assert_true(js.contains("import"))
}

///|
test "e2e: export statement" {
  let js = e2e_compile_to_js("export const PI = 3.14159;")
  assert_true(js.contains("export"))
}

// ============================================================================
// Literals
// ============================================================================

///|
test "e2e: integer literal" {
  let js = e2e_compile_to_js("const n = 42;")
  assert_true(js.contains("42"))
}

///|
test "e2e: boolean literal" {
  let js = e2e_compile_to_js("const b = true;")
  assert_true(js.contains("true"))
}

///|
test "e2e: null literal" {
  let js = e2e_compile_to_js("const n = null;")
  assert_true(js.contains("null"))
}

// ============================================================================
// Basic Statements
// ============================================================================

///|
test "e2e: empty source" {
  let success = e2e_parse_succeeds("")
  assert_true(success)
}

///|
test "e2e: comment only" {
  let success = e2e_parse_succeeds("// This is a comment")
  assert_true(success)
}

// ============================================================================
// More Control Flow
// ============================================================================

///|
test "e2e: if-else statement" {
  let js = e2e_compile_to_js("if (x > 0) { y = 1; } else { y = 0; }")
  assert_true(js.contains("else"))
}

///|
test "e2e: do-while loop" {
  let js = e2e_compile_to_js("do { x++; } while (x < 10);")
  assert_true(js.contains("do"))
}

///|
test "e2e: switch statement" {
  let js = e2e_compile_to_js("switch (day) { case 0: break; default: break; }")
  assert_true(js.contains("switch"))
}

///|
test "e2e: try-catch" {
  let js = e2e_compile_to_js("try { riskyOp(); } catch (e) { handle(e); }")
  assert_true(js.contains("try"))
  assert_true(js.contains("catch"))
}

// ============================================================================
// More Operators
// ============================================================================

///|
test "e2e: comparison operators" {
  let js = e2e_compile_to_js("const isEqual = a === b;")
  assert_true(js.contains("==="))
}

///|
test "e2e: logical operators" {
  let js = e2e_compile_to_js("const result = a && b || c;")
  assert_true(js.contains("&&"))
}

///|
test "e2e: unary negation" {
  let js = e2e_compile_to_js("const neg = -x;")
  assert_true(js.contains("-x"))
}

///|
test "e2e: logical not" {
  let js = e2e_compile_to_js("const notX = !x;")
  assert_true(js.contains("!x"))
}

///|
test "e2e: typeof operator" {
  let js = e2e_compile_to_js("const t = typeof x;")
  assert_true(js.contains("typeof"))
}

///|
test "e2e: increment operator" {
  let js = e2e_compile_to_js("x++;")
  assert_true(js.contains("++"))
}

// ============================================================================
// Objects and Arrays
// ============================================================================

///|
test "e2e: object literal" {
  let js = e2e_compile_to_js("const obj = { name: 'test', value: 42 };")
  assert_true(js.contains("name"))
}

///|
test "e2e: array literal" {
  let js = e2e_compile_to_js("const arr = [1, 2, 3, 4, 5];")
  assert_true(js.contains("["))
}

///|
test "e2e: property access" {
  let js = e2e_compile_to_js("const value = obj.prop;")
  assert_true(js.contains("prop"))
}

///|
test "e2e: index access" {
  let js = e2e_compile_to_js("const item = arr[0];")
  assert_true(js.contains("[0]"))
}

// ============================================================================
// Function Calls
// ============================================================================

///|
test "e2e: function call" {
  let js = e2e_compile_to_js("const result = func(arg1, arg2);")
  assert_true(js.contains("func"))
}

///|
test "e2e: method call" {
  let js = e2e_compile_to_js("const result = obj.method(arg);")
  assert_true(js.contains("method"))
}

///|
test "e2e: new expression" {
  let js = e2e_compile_to_js("const instance = new MyClass();")
  assert_true(js.contains("new"))
}

// ============================================================================
// Statement Keywords
// ============================================================================

///|
test "e2e: return statement" {
  let js = e2e_compile_to_js("function f() { return 42; }")
  assert_true(js.contains("return 42"))
}

///|
test "e2e: throw statement" {
  let js = e2e_compile_to_js("throw new Error('message');")
  assert_true(js.contains("throw"))
}

///|
test "e2e: break statement" {
  let js = e2e_compile_to_js("for (let i = 0; i < 10; i++) { if (i === 5) break; }")
  assert_true(js.contains("break"))
}

///|
test "e2e: continue statement" {
  let js = e2e_compile_to_js("for (let i = 0; i < 10; i++) { if (i === 5) continue; sum += i; }")
  assert_true(js.contains("continue"))
}
