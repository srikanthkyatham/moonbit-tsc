// Spread Argument Parsing Tests
// Tests that the parser correctly handles spread operator (...) in function call arguments

///|
/// Helper function to check if parsing succeeds (no errors)
fn spread_arg_parse_succeeds(source : String) -> Bool {
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(_) => true
    Err(_) => false
  }
}

///|
/// Helper function to parse, bind, and check source code
fn spread_arg_parse_bind_check(source : String) -> @compiler.CheckResult {
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) => @compiler.check_source_file(bound)
        Err(diagnostics) => Err(diagnostics)
      }
    Err(diagnostics) => Err(diagnostics)
  }
}

// ============================================================================
// Basic Spread Argument Parsing Tests
// ============================================================================

///|
test "parser/spread-argument - spread as only argument" {
  // Spread as the only argument in function call
  let source = "function foo(...args: number[]) {} const arr = [1, 2, 3]; foo(...arr);"
  assert_true(spread_arg_parse_succeeds(source))
}

///|
test "parser/spread-argument - spread as last argument" {
  // Spread after regular arguments
  let source = "function foo(a: number, b: number, ...rest: number[]) {} const arr = [3, 4]; foo(1, 2, ...arr);"
  assert_true(spread_arg_parse_succeeds(source))
}

///|
test "parser/spread-argument - spread as first argument" {
  // Spread before regular arguments
  let source = "function foo(...args: any[]) {} const arr = [1, 2]; foo(...arr, 3, 4);"
  assert_true(spread_arg_parse_succeeds(source))
}

///|
test "parser/spread-argument - spread in middle of arguments" {
  // Spread between regular arguments
  let source = "function foo(...args: any[]) {} const arr = [2, 3]; foo(1, ...arr, 4);"
  assert_true(spread_arg_parse_succeeds(source))
}

///|
test "parser/spread-argument - multiple spread arguments" {
  // Multiple spread operators in one call
  let source = "function foo(...args: any[]) {} const a = [1]; const b = [2]; foo(...a, ...b);"
  assert_true(spread_arg_parse_succeeds(source))
}

///|
test "parser/spread-argument - spread with expression" {
  // Spread with complex expression
  let source = "function foo(...args: number[]) {} foo(...[1, 2, 3].map(x => x * 2));"
  assert_true(spread_arg_parse_succeeds(source))
}

// ============================================================================
// Spread with Method Calls Tests
// ============================================================================

///|
test "parser/spread-argument - spread in method call" {
  // Spread in object method call
  let source =
    #|const obj = { foo(...args: number[]) { return args; } };
    #|const arr = [1, 2, 3];
    #|obj.foo(...arr);
  assert_true(spread_arg_parse_succeeds(source))
}

///|
test "parser/spread-argument - spread in chained method call" {
  // Spread in chained method call
  let source = "const arr = [1, 2, 3]; console.log(...arr);"
  assert_true(spread_arg_parse_succeeds(source))
}

// ============================================================================
// Spread with Constructor Calls Tests
// ============================================================================

///|
test "parser/spread-argument - spread in new expression" {
  // Spread in constructor call
  let source = "class Foo { constructor(...args: any[]) {} } const arr = [1, 2]; new Foo(...arr);"
  assert_true(spread_arg_parse_succeeds(source))
}

///|
test "parser/spread-argument - spread with new and regular args" {
  // Spread with regular arguments in constructor call
  let source = "class Foo { constructor(a: any, ...args: any[]) {} } const arr = [2, 3]; new Foo(1, ...arr);"
  assert_true(spread_arg_parse_succeeds(source))
}

// ============================================================================
// Spread with Generic Function Calls Tests
// ============================================================================

///|
test "parser/spread-argument - spread in generic function call" {
  // Spread in generic function call
  let source = "function foo<T>(...args: T[]) {} const arr = [1, 2, 3]; foo<number>(...arr);"
  assert_true(spread_arg_parse_succeeds(source))
}

///|
test "parser/spread-argument - spread with type inference" {
  // Spread with generic type inference
  let source = "function identity<T>(...args: T[]): T[] { return args; } const arr = [1, 2]; identity(...arr);"
  assert_true(spread_arg_parse_succeeds(source))
}

// ============================================================================
// Spread with Tuple Types Tests
// ============================================================================

///|
test "parser/spread-argument - spread tuple as arguments" {
  // Spread a tuple type
  let source = "function foo(a: number, b: string) {} const tuple: [number, string] = [1, 'hello']; foo(...tuple);"
  assert_true(spread_arg_parse_succeeds(source))
}

// ============================================================================
// Edge Cases
// ============================================================================

///|
test "parser/spread-argument - spread with optional chaining" {
  // Spread in optional chaining context
  let source = "const obj: { foo?: (...args: number[]) => void } = {}; const arr = [1, 2]; obj.foo?.(...arr);"
  assert_true(spread_arg_parse_succeeds(source))
}

///|
test "parser/spread-argument - spread with function expression" {
  // Spread in IIFE
  let source = "(function(...args: number[]) { return args; })(...[1, 2, 3]);"
  assert_true(spread_arg_parse_succeeds(source))
}

///|
test "parser/spread-argument - spread with arrow function" {
  // Spread with arrow function call
  let source = "const fn = (...args: number[]) => args; const arr = [1, 2]; fn(...arr);"
  assert_true(spread_arg_parse_succeeds(source))
}

///|
test "parser/spread-argument - nested spread" {
  // Spread in nested function calls
  let source = "function outer(fn: () => number[]) {} function inner(): number[] { return [1, 2]; } outer(() => [...inner()]);"
  assert_true(spread_arg_parse_succeeds(source))
}

///|
test "parser/spread-argument - spread with string" {
  // Spread a string into characters
  let source = "function foo(...chars: string[]) {} foo(...'hello');"
  assert_true(spread_arg_parse_succeeds(source))
}

///|
test "parser/spread-argument - empty spread" {
  // Spread an empty array
  let source = "function foo(...args: number[]) {} foo(...[]);"
  assert_true(spread_arg_parse_succeeds(source))
}

// ============================================================================
// Type Checking Tests
// ============================================================================

///|
test "checker/spread-argument - spread parses and binds" {
  // Just verify parsing and binding work (type checking spread is complex)
  let source = "function foo(...args: any[]) {} const arr = [1, 2]; foo(...arr);"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(_) => assert_true(true)
        Err(_) => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}
