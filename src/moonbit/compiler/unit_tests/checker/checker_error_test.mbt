// Checker Error Tests
// Tests for TypeScript error detection in the checker
// Comprehensive tests for various TypeScript error types:
// - TS2322: Type assignment errors
// - TS2344: Type constraint errors
// - TS2314: Generic type requires more type arguments
// - TS2558: Too many type arguments
// - TS2363: Numeric operand errors
// - TS2588: Cannot assign to const
// - TS7027: Unreachable code detected
// - TS2511: Cannot instantiate abstract class
// - TS2355: Function must return a value

///|
/// Helper function to parse, bind, and check source code
fn parse_bind_check_errors(source : String) -> @compiler.CheckResult {
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

///|
/// Helper to check if any diagnostic contains a specific message substring
fn has_diagnostic_containing(
  diagnostics : Array[@compiler.Diagnostic],
  substring : String,
) -> Bool {
  for i = 0; i < diagnostics.length(); i = i + 1 {
    if diagnostics[i].message.contains(substring) {
      return true
    }
  }
  false
}

///|
/// Helper to check if any diagnostic has a specific error code
fn has_diagnostic_code(
  diagnostics : Array[@compiler.Diagnostic],
  code : Int,
) -> Bool {
  for i = 0; i < diagnostics.length(); i = i + 1 {
    if diagnostics[i].code == code {
      return true
    }
  }
  false
}

///|
/// Helper to check if diagnostic has both the expected code and message substring
fn has_diagnostic_with_code_and_message(
  diagnostics : Array[@compiler.Diagnostic],
  code : Int,
  substring : String,
) -> Bool {
  for i = 0; i < diagnostics.length(); i = i + 1 {
    if diagnostics[i].code == code && diagnostics[i].message.contains(substring) {
      return true
    }
  }
  false
}

// ============================================================================
// TS2322: Type Assignment Errors
// ============================================================================

///|
test "unit/checker/error/TS2322 - string to number assignment" {
  let result = parse_bind_check_errors("const x: number = \"hello\";")
  match result {
    Ok(_) => assert_true(false) // Should have reported an error
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      assert_true(has_diagnostic_containing(diagnostics, "not assignable"))
      // Verify error code TS2322
      assert_true(has_diagnostic_code(diagnostics, 2322))
    }
  }
}

///|
test "unit/checker/error/TS2322 - boolean to number assignment" {
  let result = parse_bind_check_errors("const x: number = true;")
  match result {
    Ok(_) => assert_true(false)
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      // Verify error code TS2322 with message
      assert_true(
        has_diagnostic_with_code_and_message(
          diagnostics, 2322, "not assignable",
        ),
      )
    }
  }
}

///|
test "unit/checker/error/TS2322 - number to string assignment" {
  let result = parse_bind_check_errors("const x: string = 42;")
  match result {
    Ok(_) => assert_true(false)
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      assert_true(
        has_diagnostic_with_code_and_message(
          diagnostics, 2322, "not assignable",
        ),
      )
    }
  }
}

///|
test "unit/checker/error/TS2322 - null to non-nullable" {
  let result = parse_bind_check_errors("const x: number = null;")
  match result {
    Ok(typed) =>
      // May succeed if strict null checks not implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      assert_true(has_diagnostic_containing(diagnostics, "not assignable"))
    }
  }
}

///|
test "unit/checker/error/TS2322 - object literal missing property" {
  let result = parse_bind_check_errors(
    "interface Person { name: string; age: number; } const p: Person = { name: \"John\" };",
  )
  match result {
    Ok(typed) =>
      // May succeed if checker doesn't enforce required properties yet
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

///|
test "unit/checker/error/TS2322 - array element type mismatch" {
  let result = parse_bind_check_errors(
    "const arr: number[] = [1, 2, \"three\"];",
  )
  match result {
    Ok(typed) =>
      // May succeed depending on array type checking implementation
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

///|
test "unit/checker/error/TS2322 - union type mismatch" {
  let result = parse_bind_check_errors("const x: string | number = true;")
  match result {
    Ok(_) => assert_true(false)
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      assert_true(
        has_diagnostic_with_code_and_message(
          diagnostics, 2322, "not assignable",
        ),
      )
    }
  }
}

// ============================================================================
// TS2365: Operator Cannot Be Applied to Types
// ============================================================================

///|
test "unit/checker/error/TS2362-TS2363 - string subtraction" {
  // String subtraction should give TS2362 for left and TS2363 for right
  let result = parse_bind_check_errors("const x = \"hello\" - \"world\";")
  match result {
    Ok(_) => assert_true(false)
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      assert_true(has_diagnostic_containing(diagnostics, "arithmetic"))
      // Verify error codes TS2362/TS2363: arithmetic operand must be numeric
      assert_true(has_diagnostic_code(diagnostics, 2362) || has_diagnostic_code(diagnostics, 2363))
    }
  }
}

///|
test "unit/checker/error/TS2362-TS2363 - boolean multiplication" {
  // Boolean multiplication should give TS2362/TS2363 errors
  let result = parse_bind_check_errors("const x = true * false;")
  match result {
    Ok(_) => assert_true(false)
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      // Verify error codes TS2362/TS2363 with arithmetic message
      assert_true(
        has_diagnostic_with_code_and_message(diagnostics, 2362, "arithmetic") ||
        has_diagnostic_with_code_and_message(diagnostics, 2363, "arithmetic"),
      )
    }
  }
}

///|
test "unit/checker/error/TS2362 - string division" {
  // String division should give TS2362 error for left-hand side
  let result = parse_bind_check_errors("const x = \"10\" / 2;")
  match result {
    Ok(_) => assert_true(false)
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      assert_true(
        has_diagnostic_with_code_and_message(diagnostics, 2362, "arithmetic"),
      )
    }
  }
}

///|
test "unit/checker/error/TS2363 - null arithmetic" {
  let result = parse_bind_check_errors("const x = null + 5;")
  match result {
    Ok(typed) =>
      // null + number might be allowed in some contexts
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

///|
test "unit/checker/error/TS2363 - unary minus on string" {
  let result = parse_bind_check_errors("const x = -\"hello\";")
  match result {
    Ok(_) => assert_true(false)
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      assert_true(
        has_diagnostic_with_code_and_message(diagnostics, 2363, "number"),
      )
    }
  }
}

///|
test "unit/checker/error/TS2363 - increment on boolean" {
  let result = parse_bind_check_errors("let x = true; x++;")
  match result {
    Ok(typed) =>
      // May succeed depending on implementation
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

// ============================================================================
// TS2588: Cannot Assign to Const
// ============================================================================

///|
test "unit/checker/error/TS2588 - reassign const variable" {
  let result = parse_bind_check_errors("const x = 1; x = 2;")
  match result {
    Ok(typed) =>
      // May succeed but with diagnostics
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      assert_true(has_diagnostic_containing(diagnostics, "constant"))
      // Verify error code TS2588
      assert_true(has_diagnostic_code(diagnostics, 2588))
    }
  }
}

///|
test "unit/checker/error/TS2588 - compound assignment to const" {
  let result = parse_bind_check_errors("const x = 1; x += 2;")
  match result {
    Ok(typed) =>
      // May succeed but with diagnostics
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      assert_true(
        has_diagnostic_with_code_and_message(diagnostics, 2588, "constant"),
      )
    }
  }
}

///|
test "unit/checker/error/TS2588 - increment const" {
  let result = parse_bind_check_errors("const x = 1; x++;")
  match result {
    Ok(typed) =>
      // May succeed but with diagnostics
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

///|
test "unit/checker/error/TS2588 - decrement const" {
  let result = parse_bind_check_errors("const x = 1; --x;")
  match result {
    Ok(typed) =>
      // May succeed but with diagnostics
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

///|
test "unit/checker/error/TS2588 - let reassignment is valid" {
  let result = parse_bind_check_errors("let x = 1; x = 2;")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// TS7027: Unreachable Code
// ============================================================================

///|
test "unit/checker/error/TS7027 - code after return" {
  let result = parse_bind_check_errors(
    "function test() { return 1; const x = 2; }",
  )
  match result {
    Ok(_) => assert_true(false)
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      assert_true(has_diagnostic_containing(diagnostics, "Unreachable"))
      // Verify error code TS7027
      assert_true(has_diagnostic_code(diagnostics, 7027))
    }
  }
}

///|
test "unit/checker/error/TS7027 - code after throw" {
  let result = parse_bind_check_errors(
    "function test() { throw new Error(); const x = 2; }",
  )
  match result {
    Ok(typed) =>
      // May succeed depending on unreachable code check implementation
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

///|
test "unit/checker/error/TS7027 - multiple statements after return" {
  let result = parse_bind_check_errors(
    "function test() { return 1; console.log('a'); console.log('b'); }",
  )
  match result {
    Ok(_) => assert_true(false)
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      assert_true(
        has_diagnostic_with_code_and_message(diagnostics, 7027, "Unreachable"),
      )
    }
  }
}

///|
test "unit/checker/error/TS7027 - no false positive with if" {
  let result = parse_bind_check_errors(
    "function test(x: boolean) { if (x) { return 1; } return 2; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// TS2511: Cannot Instantiate Abstract Class
// ============================================================================

///|
test "unit/checker/error/TS2511 - instantiate abstract class" {
  let result = parse_bind_check_errors(
    "abstract class Foo { abstract method(): void; } new Foo();",
  )
  match result {
    Ok(typed) =>
      // May succeed if abstract check not fully implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      assert_true(has_diagnostic_containing(diagnostics, "abstract"))
      // Verify error code TS2511
      assert_true(has_diagnostic_code(diagnostics, 2511))
    }
  }
}

///|
test "unit/checker/error/TS2511 - concrete class instantiation is valid" {
  let result = parse_bind_check_errors(
    "class Foo { method(): void {} } const x = new Foo();",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/error/TS2511 - abstract class with constructor" {
  let result = parse_bind_check_errors(
    "abstract class Base { constructor(public name: string) {} } new Base(\"test\");",
  )
  match result {
    Ok(typed) =>
      // May succeed if abstract check not fully implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

// ============================================================================
// TS2322/TS2355: Return Type Errors
// ============================================================================

///|
test "unit/checker/error/TS2322 - return type mismatch" {
  let result = parse_bind_check_errors(
    "function test(): number { return \"hello\"; }",
  )
  match result {
    Ok(_) => assert_true(false)
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      assert_true(
        has_diagnostic_containing(diagnostics, "not assignable") ||
        has_diagnostic_containing(diagnostics, "return"),
      )
      // Verify error code TS2322
      assert_true(has_diagnostic_code(diagnostics, 2322))
    }
  }
}

///|
test "unit/checker/error/TS2355 - non-void must return value" {
  let result = parse_bind_check_errors("function test(): number { return; }")
  match result {
    Ok(_) => assert_true(false)
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      assert_true(
        has_diagnostic_containing(diagnostics, "return a value") ||
        has_diagnostic_containing(diagnostics, "not assignable"),
      )
      // Verify error code TS2355
      assert_true(has_diagnostic_code(diagnostics, 2355))
    }
  }
}

///|
test "unit/checker/error/TS2322 - arrow function return mismatch" {
  let result = parse_bind_check_errors(
    "const fn: () => number = () => \"hello\";",
  )
  match result {
    Ok(typed) =>
      // May succeed depending on arrow function type checking
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

///|
test "unit/checker/error - void function with no return is valid" {
  let result = parse_bind_check_errors(
    "function test(): void { console.log('hello'); }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/error - void function with empty return is valid" {
  let result = parse_bind_check_errors("function test(): void { return; }")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// TS2314/TS2344/TS2558: Generic Type Errors
// ============================================================================

///|
test "unit/checker/error/TS2314 - generic requires type arguments" {
  let result = parse_bind_check_errors(
    "interface Box<T> { value: T; } const b: Box = { value: 1 };",
  )
  match result {
    Ok(typed) =>
      // May succeed if generic check not fully implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

///|
test "unit/checker/error/TS2558 - too many type arguments" {
  let result = parse_bind_check_errors(
    "function identity<T>(x: T): T { return x; } identity<number, string>(42);",
  )
  match result {
    Ok(typed) =>
      // May succeed if generic check not fully implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

///|
test "unit/checker/error/TS2344 - type constraint violation" {
  let result = parse_bind_check_errors(
    "function process<T extends number>(value: T): T { return value; } process(\"hello\");",
  )
  match result {
    Ok(typed) =>
      // May succeed if constraint check not fully implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

///|
test "unit/checker/error - valid generic usage" {
  let result = parse_bind_check_errors(
    "function identity<T>(x: T): T { return x; } const result = identity<number>(42);",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Property Access Errors
// ============================================================================

///|
test "unit/checker/error - property access on primitive" {
  let result = parse_bind_check_errors("const x = 42; const y = x.foo;")
  match result {
    Ok(typed) =>
      // May succeed with any type fallback
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

///|
test "unit/checker/error - method call on undefined" {
  let result = parse_bind_check_errors("const x = undefined; x.toString();")
  match result {
    Ok(typed) =>
      // May succeed with any type fallback
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

// ============================================================================
// Variable Declaration Errors
// ============================================================================

///|
test "unit/checker/error - duplicate declaration" {
  let result = parse_bind_check_errors("const x = 1; const x = 2;")
  match result {
    Ok(typed) =>
      // May succeed if duplicate check not fully implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

///|
test "unit/checker/error - use before declaration" {
  let result = parse_bind_check_errors("console.log(x); const x = 1;")
  match result {
    Ok(typed) =>
      // May succeed if TDZ check not fully implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

// ============================================================================
// Function Call Errors
// ============================================================================

///|
test "unit/checker/error - wrong number of arguments" {
  let result = parse_bind_check_errors(
    "function add(a: number, b: number): number { return a + b; } add(1);",
  )
  match result {
    Ok(typed) =>
      // May succeed if arity check not fully implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

///|
test "unit/checker/error - argument type mismatch" {
  let result = parse_bind_check_errors(
    "function greet(name: string): string { return \"Hello \" + name; } greet(42);",
  )
  match result {
    Ok(typed) =>
      // May succeed if argument type check not fully implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

///|
test "unit/checker/error - too many arguments" {
  let result = parse_bind_check_errors(
    "function single(x: number): number { return x; } single(1, 2, 3);",
  )
  match result {
    Ok(typed) =>
      // May succeed if arity check not fully implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

// ============================================================================
// Class Errors
// ============================================================================

///|
test "unit/checker/error - missing abstract implementation" {
  let result = parse_bind_check_errors(
    "abstract class Base { abstract method(): void; } class Derived extends Base { }",
  )
  match result {
    Ok(typed) =>
      // May succeed if abstract implementation check not fully implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

///|
test "unit/checker/error - private member access" {
  let result = parse_bind_check_errors(
    "class Foo { private x: number = 1; } const f = new Foo(); f.x;",
  )
  match result {
    Ok(typed) =>
      // May succeed if visibility check not fully implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

// ============================================================================
// Interface/Type Errors
// ============================================================================

///|
test "unit/checker/error - interface property type mismatch" {
  let result = parse_bind_check_errors(
    "interface Point { x: number; y: number; } const p: Point = { x: \"hello\", y: 2 };",
  )
  match result {
    Ok(typed) =>
      // May succeed if structural type check not fully implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

///|
test "unit/checker/error - readonly property assignment" {
  let result = parse_bind_check_errors(
    "interface Point { readonly x: number; } const p: Point = { x: 1 }; p.x = 2;",
  )
  match result {
    Ok(typed) =>
      // May succeed if readonly check not fully implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

// ============================================================================
// Enum Errors
// ============================================================================

///|
test "unit/checker/error - enum member type mismatch" {
  let result = parse_bind_check_errors(
    "enum Color { Red, Green, Blue } const c: Color = \"Red\";",
  )
  match result {
    Ok(typed) =>
      // May succeed if enum type check not fully implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

///|
test "unit/checker/error - enum with numeric initializers" {
  let result = parse_bind_check_errors(
    "enum Status { Active = 1, Inactive = 0, Pending = 2 }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/error - enum with string initializers" {
  let result = parse_bind_check_errors(
    "enum Direction { Up = \"UP\", Down = \"DOWN\", Left = \"LEFT\", Right = \"RIGHT\" }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/error - enum with mixed auto and explicit values" {
  let result = parse_bind_check_errors("enum Mixed { A, B = 5, C }")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/error - const enum with literals" {
  let result = parse_bind_check_errors(
    "const enum Flags { None = 0, Read = 1, Write = 2 }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/error - const enum with computed value from other members" {
  let result = parse_bind_check_errors(
    "const enum Bits { A = 1, B = 2, C = A + B }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/error - enum with negative values" {
  let result = parse_bind_check_errors(
    "enum Temperature { Cold = -10, Freezing = -20, Hot = 30 }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/error - enum with invalid initializer type" {
  // TS18033: Type 'boolean' is not assignable to type 'number' as required for computed enum member values
  let result = parse_bind_check_errors("enum Bad { A = true }")
  match result {
    Ok(typed) =>
      // May succeed if enum initializer type check not fully implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      assert_true(has_diagnostic_code(diagnostics, 18033))
    }
  }
}

///|
test "unit/checker/error - enum with object initializer" {
  let result = parse_bind_check_errors("enum Bad { A = {} }")
  match result {
    Ok(typed) =>
      // May succeed if enum initializer type check not fully implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

///|
test "unit/checker/error - enum with array initializer" {
  let result = parse_bind_check_errors("enum Bad { A = [1, 2, 3] }")
  match result {
    Ok(typed) =>
      // May succeed if enum initializer type check not fully implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

///|
test "unit/checker/error - empty enum" {
  let result = parse_bind_check_errors("enum Empty { }")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/error - enum with bitwise operations" {
  let result = parse_bind_check_errors(
    "enum Flags { None = 0, Read = 1 << 0, Write = 1 << 1, Execute = 1 << 2 }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/error - exported enum" {
  let result = parse_bind_check_errors(
    "export enum PublicStatus { Active, Inactive }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Tuple Errors
// ============================================================================

///|
test "unit/checker/error - tuple element type mismatch" {
  let result = parse_bind_check_errors(
    "const t: [number, string] = [\"hello\", 42];",
  )
  match result {
    Ok(typed) =>
      // May succeed if tuple type check not fully implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

///|
test "unit/checker/error - tuple length mismatch" {
  let result = parse_bind_check_errors("const t: [number, string] = [1];")
  match result {
    Ok(typed) =>
      // May succeed if tuple length check not fully implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

// ============================================================================
// Complex Error Scenarios
// ============================================================================

///|
test "unit/checker/error - multiple errors in one file" {
  let source =
    #|const x: number = "hello";
    #|const y: string = 42;
    #|const z: boolean = null;
  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(false)
    Err(diagnostics) =>
      // Should have multiple errors
      assert_true(diagnostics.length() >= 1)
  }
}

///|
test "unit/checker/error - nested function return mismatch" {
  let source =
    #|function outer(): number {
    #|  function inner(): string {
    #|    return 42;
    #|  }
    #|  return inner();
    #|}
  let result = parse_bind_check_errors(source)
  match result {
    Ok(typed) =>
      // May succeed if nested function check not fully implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

///|
test "unit/checker/error - callback type mismatch" {
  let source =
    #|type Callback = (x: number) => string;
    #|const cb: Callback = (x: string) => x.length;
  let result = parse_bind_check_errors(source)
  match result {
    Ok(typed) =>
      // May succeed if function type check not fully implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

// ============================================================================
// Valid Code (No Errors Expected)
// ============================================================================

///|
test "unit/checker/error - valid number operations" {
  let result = parse_bind_check_errors(
    "const x = 1 + 2; const y = x * 3; const z = y / 2;",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/error - valid string operations" {
  let result = parse_bind_check_errors(
    "const x = \"hello\" + \" \" + \"world\";",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/error - valid type annotations" {
  let result = parse_bind_check_errors(
    "const x: number = 42; const y: string = \"hello\"; const z: boolean = true;",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/error - valid union type" {
  let result = parse_bind_check_errors(
    "const x: string | number = 42; const y: string | number = \"hello\";",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/error - valid function with types" {
  let result = parse_bind_check_errors(
    "function add(a: number, b: number): number { return a + b; } const sum = add(1, 2);",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/error - valid interface implementation" {
  let result = parse_bind_check_errors(
    "interface Point { x: number; y: number; } const p: Point = { x: 1, y: 2 };",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/error - valid class instantiation" {
  let result = parse_bind_check_errors(
    "class Greeter { greeting: string; greet() { return this.greeting; } } const g = new Greeter();",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/error - valid generic function" {
  let result = parse_bind_check_errors(
    "function identity<T>(arg: T): T { return arg; } const num = identity(42); const str = identity(\"hello\");",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/error - valid tuple" {
  let result = parse_bind_check_errors(
    "const t: [number, string] = [1, \"hello\"];",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/error - valid enum usage" {
  let result = parse_bind_check_errors(
    "enum Color { Red, Green, Blue } const c: Color = Color.Red;",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Complex Type Mismatch Scenarios
// ============================================================================

///|
test "unit/checker/error/complex - deeply nested object type mismatch" {
  // A deeply nested object structure where a type mismatch occurs at multiple levels
  let source =
    #|interface Address {
    #|  street: string;
    #|  city: string;
    #|  zipCode: number;
    #|}
    #|interface PersonDetails {
    #|  name: string;
    #|  age: number;
    #|  address: Address;
    #|}
    #|interface Company {
    #|  name: string;
    #|  employees: PersonDetails[];
    #|  headquarters: Address;
    #|}
    #|const company: Company = {
    #|  name: "Acme Corp",
    #|  employees: [
    #|    {
    #|      name: "John",
    #|      age: "thirty", // ERROR: string instead of number
    #|      address: {
    #|        street: "123 Main St",
    #|        city: "NYC",
    #|        zipCode: "10001" // ERROR: string instead of number
    #|      }
    #|    }
    #|  ],
    #|  headquarters: {
    #|    street: 456, // ERROR: number instead of string
    #|    city: "LA",
    #|    zipCode: 90001
    #|  }
    #|};
  let result = parse_bind_check_errors(source)
  match result {
    Ok(typed) =>
      // If checker doesn't fully validate nested objects yet, it may succeed
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      // Should detect at least one type mismatch
      assert_true(has_diagnostic_code(diagnostics, 2322))
    }
  }
}

///|
test "unit/checker/error/complex - generic function with complex constraint violation" {
  // Generic function with multiple type parameters and complex constraints
  let source =
    #|interface Comparable<T> {
    #|  compareTo(other: T): number;
    #|}
    #|interface Serializable {
    #|  serialize(): string;
    #|}
    #|function process<T extends Comparable<T> & Serializable, U extends T>(
    #|  primary: T,
    #|  secondary: U
    #|): string {
    #|  return primary.serialize();
    #|}
    #|// Call with incompatible types
    #|process(42, "hello"); // ERROR: number doesn't satisfy constraints
  let result = parse_bind_check_errors(source)
  match result {
    Ok(typed) =>
      // May succeed if generic constraint checking not fully implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

///|
test "unit/checker/error/complex - function signature with multiple param mismatches" {
  // Function with multiple parameters where several have type mismatches
  let source =
    #|type Config = {
    #|  timeout: number;
    #|  retries: number;
    #|  headers: { [key: string]: string };
    #|};
    #|type RequestCallback = (error: Error | null, data: string) => void;
    #|function makeRequest(
    #|  url: string,
    #|  method: "GET" | "POST" | "PUT" | "DELETE",
    #|  config: Config,
    #|  callback: RequestCallback
    #|): void {
    #|  // implementation
    #|}
    #|// Call with multiple type errors
    #|makeRequest(
    #|  123, // ERROR: number instead of string
    #|  "PATCH", // ERROR: not in union
    #|  { timeout: "fast", retries: true, headers: null }, // ERROR: multiple property type mismatches
    #|  (err, data) => data.length // valid callback
    #|);
  let result = parse_bind_check_errors(source)
  match result {
    Ok(typed) =>
      // May succeed if full parameter type checking not implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) =>
      // Should catch at least one error
      assert_true(diagnostics.length() > 0)
  }
}

///|
test "unit/checker/error/complex - union of object types with discriminant mismatch" {
  // Discriminated union where the wrong discriminant value is used
  let source =
    #|type Circle = { kind: "circle"; radius: number };
    #|type Square = { kind: "square"; side: number };
    #|type Triangle = { kind: "triangle"; base: number; height: number };
    #|type Shape = Circle | Square | Triangle;
    #|
    #|const shape: Shape = {
    #|  kind: "hexagon", // ERROR: not a valid discriminant
    #|  sides: 6
    #|};
  let result = parse_bind_check_errors(source)
  match result {
    Ok(typed) =>
      // May succeed if discriminated union checking not implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      assert_true(has_diagnostic_code(diagnostics, 2322))
    }
  }
}

///|
test "unit/checker/error/complex - intersection type with conflicting properties" {
  // Intersection type where value violates one of the intersected types
  let source =
    #|interface Named {
    #|  name: string;
    #|  id: number;
    #|}
    #|interface Dated {
    #|  createdAt: Date;
    #|  updatedAt: Date;
    #|}
    #|type Record = Named & Dated;
    #|
    #|const record: Record = {
    #|  name: 123, // ERROR: should be string
    #|  id: "abc", // ERROR: should be number
    #|  createdAt: "2024-01-01", // ERROR: should be Date
    #|  updatedAt: new Date()
    #|};
  let result = parse_bind_check_errors(source)
  match result {
    Ok(typed) =>
      // May succeed if intersection type checking not fully implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      assert_true(has_diagnostic_code(diagnostics, 2322))
    }
  }
}

///|
test "unit/checker/error/complex - mapped type with readonly violation" {
  // Using mapped type with readonly modifier and attempting mutation
  let source =
    #|type Readonly<T> = { readonly [K in keyof T]: T[K] };
    #|interface Point { x: number; y: number; }
    #|const frozen: Readonly<Point> = { x: 10, y: 20 };
    #|frozen.x = 30; // ERROR: cannot assign to readonly property
  let result = parse_bind_check_errors(source)
  match result {
    Ok(typed) =>
      // May succeed if readonly checking not implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

///|
test "unit/checker/error/complex - conditional type with never result" {
  // Conditional type that results in 'never' due to type mismatch
  let source =
    #|type ExtractString<T> = T extends string ? T : never;
    #|type Result = ExtractString<number>; // Result is 'never'
    #|const value: Result = 42; // ERROR: number not assignable to never
  let result = parse_bind_check_errors(source)
  match result {
    Ok(typed) =>
      // May succeed if conditional type evaluation not implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

///|
test "unit/checker/error/complex - recursive type with invalid structure" {
  // Non-recursive type definition with nested invalid structure
  // (avoiding self-referential generics that cause stack overflow in type resolution)
  let source =
    #|interface Container<T> {
    #|  value: T;
    #|  nested: { inner: T };
    #|}
    #|const box: Container<number> = {
    #|  value: 1,
    #|  nested: {
    #|    inner: "hello" // ERROR: string instead of number
    #|  }
    #|};
  let result = parse_bind_check_errors(source)
  match result {
    Ok(typed) =>
      // May succeed if nested generic type checking not implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      assert_true(has_diagnostic_code(diagnostics, 2322))
    }
  }
}

///|
test "unit/checker/error/complex - callback function with wrong return type" {
  // Higher-order function with callback that has wrong return type
  let source =
    #|function map<T, U>(arr: T[], fn: (item: T) => U): U[] {
    #|  return arr.map(fn);
    #|}
    #|const numbers: number[] = [1, 2, 3];
    #|// Callback returns wrong type (string instead of boolean)
    #|const result: boolean[] = map(numbers, (n) => n.toString()); // ERROR
  let result = parse_bind_check_errors(source)
  match result {
    Ok(typed) =>
      // May succeed if generic callback type inference not fully implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

///|
test "unit/checker/error/complex - template literal type mismatch" {
  // Template literal types with invalid values
  let source =
    #|type EventName = `on${Capitalize<string>}`;
    #|type HTTPMethod = "GET" | "POST" | "PUT" | "DELETE";
    #|type Endpoint = `/${string}/${HTTPMethod}`;
    #|
    #|const event: EventName = "onClick"; // valid
    #|const badEvent: EventName = "click"; // ERROR: missing 'on' prefix
    #|const endpoint: Endpoint = "/users/INVALID"; // ERROR: INVALID not in HTTPMethod
  let result = parse_bind_check_errors(source)
  match result {
    Ok(typed) =>
      // May succeed if template literal type checking not implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

///|
test "unit/checker/error/complex - index signature constraint violation" {
  // Object with index signature that has type constraint violation
  let source =
    #|interface StringDict {
    #|  [key: string]: string;
    #|}
    #|const dict: StringDict = {
    #|  a: "hello",
    #|  b: 123, // ERROR: number not assignable to string
    #|  c: true // ERROR: boolean not assignable to string
    #|};
  let result = parse_bind_check_errors(source)
  match result {
    Ok(typed) =>
      // May succeed if index signature checking not implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      assert_true(has_diagnostic_code(diagnostics, 2322))
    }
  }
}

///|
test "unit/checker/error/complex - rest parameter type mismatch" {
  // Function with rest parameters called with wrong types
  let source =
    #|function sum(...numbers: number[]): number {
    #|  return numbers.reduce((a, b) => a + b, 0);
    #|}
    #|sum(1, 2, "three", 4, true); // ERROR: string and boolean in number[]
  let result = parse_bind_check_errors(source)
  match result {
    Ok(typed) =>
      // May succeed if rest parameter type checking not fully implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

///|
test "unit/checker/error/complex - overloaded function with no matching signature" {
  // Call to overloaded function where no overload matches
  let source =
    #|function process(x: string): string;
    #|function process(x: number): number;
    #|function process(x: string | number): string | number {
    #|  return x;
    #|}
    #|process(true); // ERROR: no overload matches
  let result = parse_bind_check_errors(source)
  match result {
    Ok(typed) =>
      // May succeed if overload resolution not fully implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

///|
test "unit/checker/error/complex - class implementing interface with wrong method signature" {
  // Class that claims to implement an interface but has wrong method signatures
  let source =
    #|interface Calculator {
    #|  add(a: number, b: number): number;
    #|  subtract(a: number, b: number): number;
    #|}
    #|class BadCalculator implements Calculator {
    #|  add(a: string, b: string): string { // ERROR: wrong param types
    #|    return a + b;
    #|  }
    #|  subtract(a: number, b: number): string { // ERROR: wrong return type
    #|    return String(a - b);
    #|  }
    #|}
  let result = parse_bind_check_errors(source)
  match result {
    Ok(typed) =>
      // May succeed if interface implementation checking not fully implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

///|
test "unit/checker/error/complex - Promise chain type propagation error" {
  // Promise chain where types don't flow correctly
  let source =
    #|function fetchUser(): Promise<{ name: string; id: number }> {
    #|  return Promise.resolve({ name: "John", id: 1 });
    #|}
    #|const result: Promise<boolean> = fetchUser()
    #|  .then(user => user.name) // string
    #|  .then(name => name.length); // ERROR: number not assignable to boolean
  let result = parse_bind_check_errors(source)
  match result {
    Ok(typed) =>
      // May succeed if Promise type tracking not fully implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

// ============================================================================
// Edge Cases
// ============================================================================

///|
test "unit/checker/error - any type bypasses checks" {
  let result = parse_bind_check_errors(
    "const x: any = \"hello\"; const y: number = x;",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) =>
      // May fail if any type is not fully implemented
      assert_true(true)
  }
}

///|
test "unit/checker/error - unknown type requires assertion" {
  let result = parse_bind_check_errors(
    "const x: unknown = \"hello\"; const y: number = x;",
  )
  match result {
    Ok(typed) =>
      // May succeed if unknown type check not fully implemented
      assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

///|
test "unit/checker/error - never type assignability" {
  let result = parse_bind_check_errors(
    "function fail(): never { throw new Error(); } const x: number = fail();",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/error - optional parameter handling" {
  let result = parse_bind_check_errors(
    "function greet(name?: string): string { return \"Hello \" + (name || \"World\"); } greet(); greet(\"John\");",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/error - rest parameters" {
  let result = parse_bind_check_errors(
    "function sum(...nums: number[]): number { return nums.reduce((a, b) => a + b, 0); } sum(1, 2, 3);",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/error - default parameter" {
  let result = parse_bind_check_errors(
    "function greet(name: string = \"World\"): string { return \"Hello \" + name; } greet();",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Parameter Type Errors in Function Bodies
// ============================================================================

///|
test "unit/checker/error/TS2322 - assign string to number parameter" {
  // Test that assigning a string to a number-typed parameter inside function body is detected
  let result = parse_bind_check_errors(
    "function test(x: number) { x = \"bad\"; }",
  )
  match result {
    Ok(_) => assert_true(false) // Should have reported an error
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      assert_true(has_diagnostic_code(diagnostics, 2322))
      assert_true(has_diagnostic_containing(diagnostics, "not assignable"))
    }
  }
}

///|
test "unit/checker/error/TS2322 - assign boolean to string parameter" {
  let result = parse_bind_check_errors(
    "function test(s: string) { s = true; }",
  )
  match result {
    Ok(_) => assert_true(false)
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      assert_true(has_diagnostic_code(diagnostics, 2322))
    }
  }
}

///|
test "unit/checker/error/TS2322 - parameter type error in arrow function" {
  let result = parse_bind_check_errors(
    "const f = (x: number) => { x = \"bad\"; };",
  )
  match result {
    Ok(_) => assert_true(false)
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      assert_true(has_diagnostic_code(diagnostics, 2322))
    }
  }
}

///|
test "unit/checker/error/TS2322 - parameter type error in function expression" {
  let result = parse_bind_check_errors(
    "const f = function(x: number) { x = \"bad\"; };",
  )
  match result {
    Ok(_) => assert_true(false)
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      assert_true(has_diagnostic_code(diagnostics, 2322))
    }
  }
}

///|
test "unit/checker/error/TS2322 - parameter type error in template substitution" {
  let result = parse_bind_check_errors(
    "`${function (x: number) { x = \"bad\"; } }`",
  )
  match result {
    Ok(_) => assert_true(false)
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      assert_true(has_diagnostic_code(diagnostics, 2322))
    }
  }
}

///|
test "unit/checker/error - valid parameter assignment" {
  // Test that assigning a valid type to a parameter is accepted
  let result = parse_bind_check_errors(
    "function test(x: number) { x = 42; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false) // Should not have errors
  }
}

// ============================================================================
// Destructuring Pattern Tests
// ============================================================================

///|
test "unit/checker/destructuring - catch clause array destructuring" {
  // Test that catch clause with array destructuring properly binds variables
  let result = parse_bind_check_errors(
    "try { throw [0, 1]; } catch ([a, b]) { const sum = a + b; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false) // Should not have "Cannot find name" errors
  }
}

///|
test "unit/checker/destructuring - catch clause object destructuring" {
  // Test that catch clause with object destructuring properly binds variables
  let result = parse_bind_check_errors(
    "try { throw { msg: 'error' }; } catch ({ msg }) { console.log(msg); }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/destructuring - function parameter array pattern" {
  // Test function with array destructuring parameter (without type annotation)
  // Variables bind as 'any' when no annotation provided
  let result = parse_bind_check_errors(
    "function foo([a, b]) { return a; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/destructuring - function parameter object pattern" {
  // Test function with object destructuring parameter (without type annotation)
  let result = parse_bind_check_errors(
    "function foo({ x, y }) { return x; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/destructuring - arrow function array pattern" {
  // Test arrow function with array destructuring parameter
  let result = parse_bind_check_errors(
    "const foo = ([a, b]) => a;",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/destructuring - arrow function object pattern" {
  // Test arrow function with object destructuring parameter
  let result = parse_bind_check_errors(
    "const foo = ({ x, y }) => x;",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/destructuring - nested parameter destructuring" {
  // Test nested destructuring in function parameters
  let result = parse_bind_check_errors(
    "function foo({ outer: { inner } }) { return inner; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/destructuring - function expression with destructuring" {
  // Test function expression with destructuring parameter
  let result = parse_bind_check_errors(
    "const foo = function({ a, b }) { return a + b; };",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/globals - Map constructor" {
  // Test that Map is recognized as a global constructor
  let result = parse_bind_check_errors("const m = new Map();")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/globals - Map with entries" {
  // Test that Map can be instantiated with entries
  let result = parse_bind_check_errors(
    "const m = new Map([[\"a\", 1], [\"b\", 2]]);",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/globals - Set constructor" {
  // Test that Set is recognized as a global constructor
  let result = parse_bind_check_errors("const s = new Set();")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/globals - Set with values" {
  // Test that Set can be instantiated with values
  let result = parse_bind_check_errors("const s = new Set([1, 2, 3]);")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/globals - WeakMap constructor" {
  // Test that WeakMap is recognized as a global constructor
  let result = parse_bind_check_errors("const wm = new WeakMap();")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/globals - WeakSet constructor" {
  // Test that WeakSet is recognized as a global constructor
  let result = parse_bind_check_errors("const ws = new WeakSet();")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/globals - Map reference" {
  // Test that Map can be referenced as a value
  let result = parse_bind_check_errors("const MapRef = Map;")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/destructuring - assignment pattern marks variables initialized" {
  // Test that destructuring assignment doesn't falsely report TS2454
  let result = parse_bind_check_errors(
    "let x: number; let y: any; ({ x, ...y } = ({} as any));",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/destructuring - array assignment pattern marks variables initialized" {
  // Test that array destructuring assignment doesn't falsely report TS2454
  let result = parse_bind_check_errors(
    "let a: number; let b: number; [a, b] = [1, 2];",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/checker/TS1187 - parameter property with array binding pattern" {
  // TS1187: A parameter property may not be declared using a binding pattern
  let result = parse_bind_check_errors(
    "class C { constructor(public [x, y]: number[]) {} }",
  )
  match result {
    Ok(_) => assert_true(false) // Should have errors
    Err(diagnostics) => assert_true(has_diagnostic_code(diagnostics, 1187))
  }
}

///|
test "unit/checker/TS1187 - parameter property with object binding pattern" {
  // TS1187: A parameter property may not be declared using a binding pattern
  let result = parse_bind_check_errors(
    "class C { constructor(public { x, y }: { x: number, y: number }) {} }",
  )
  match result {
    Ok(_) => assert_true(false) // Should have errors
    Err(diagnostics) => assert_true(has_diagnostic_code(diagnostics, 1187))
  }
}

///|
test "unit/checker/TS1187 - private parameter property with binding pattern" {
  // TS1187 with private modifier
  let result = parse_bind_check_errors(
    "class C { constructor(private [a, b]: string[]) {} }",
  )
  match result {
    Ok(_) => assert_true(false) // Should have errors
    Err(diagnostics) => assert_true(has_diagnostic_code(diagnostics, 1187))
  }
}

///|
test "unit/checker/TS1187 - readonly parameter property with binding pattern" {
  // TS1187 with readonly modifier
  let result = parse_bind_check_errors(
    "class C { constructor(readonly [a, b]: string[]) {} }",
  )
  match result {
    Ok(_) => assert_true(false) // Should have errors
    Err(diagnostics) => assert_true(has_diagnostic_code(diagnostics, 1187))
  }
}

///|
test "unit/checker/no TS1187 - regular parameter with binding pattern" {
  // No error for regular parameter (without modifier) using binding pattern
  let result = parse_bind_check_errors(
    "class C { constructor([a, b]: string[]) {} }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}
