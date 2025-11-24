// Type Checker Tests
// Tests for the TypeScript type checker

///|
/// Helper to parse, bind, and check source code
fn parse_bind_and_check(source : String) -> CheckResult {
  let tokens = tokens_from_source(source)
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      match bind_source_file(source_file) {
        Ok(bound) => check_source_file(bound)
        Err(diagnostics) => Err(diagnostics)
      }
    }
    Err(diagnostics) => Err(diagnostics)
  }
}

// ============================================================================
// Basic Type Inference Tests
// ============================================================================

///|
test "check number literal type" {
  let result = parse_bind_and_check("const x = 42;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check string literal type" {
  let result = parse_bind_and_check("const x = \"hello\";")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check boolean literal type" {
  let result = parse_bind_and_check("const x = true;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check null literal type" {
  let result = parse_bind_and_check("const x = null;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Binary Expression Type Tests
// ============================================================================

///|
test "check number addition" {
  let result = parse_bind_and_check("const x = 1 + 2;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check string concatenation" {
  let result = parse_bind_and_check("const x = \"hello\" + \"world\";")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(diagnostics) => {
      println("String concat test failed with \{diagnostics.length()} errors:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  \{diagnostics[i].message}")
      }
      assert_true(false)
    }
  }
}

///|
test "check comparison expression" {
  let result = parse_bind_and_check("const x = 1 < 2;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check logical and expression" {
  let result = parse_bind_and_check("const x = true && false;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Type Annotation Tests
// ============================================================================

///|
test "check variable with number type annotation" {
  let result = parse_bind_and_check("const x: number = 42;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check variable with string type annotation" {
  let result = parse_bind_and_check("const x: string = \"hello\";")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check type mismatch error" {
  let result = parse_bind_and_check("const x: number = \"hello\";")
  match result {
    Ok(_) => {
      println("Type mismatch test PASSED but should have FAILED - no error was reported")
      assert_true(false) // Should have error
    }
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      // Check that diagnostic mentions type mismatch
      match diagnostics[0] {
        diag => assert_true(diag.message.contains("mismatch"))
      }
    }
  }
}

// ============================================================================
// Function Type Tests
// ============================================================================

///|
test "check function declaration" {
  let result = parse_bind_and_check("function add(a, b) { return a + b; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check arrow function" {
  let result = parse_bind_and_check("const add = (a, b) => a + b;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(diagnostics) => {
      println("Arrow function test failed with \{diagnostics.length()} errors:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  \{diagnostics[i].message}")
      }
      assert_true(false)
    }
  }
}

///|
test "check function with type annotations" {
  let result = parse_bind_and_check(
    "function add(a: number, b: number): number { return a + b; }",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Array Type Tests
// ============================================================================

///|
test "check array literal" {
  let result = parse_bind_and_check("const arr = [1, 2, 3];")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check mixed array literal" {
  let result = parse_bind_and_check("const arr = [1, \"two\", true];")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check empty array" {
  let result = parse_bind_and_check("const arr = [];")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Object Type Tests
// ============================================================================

///|
test "check object literal" {
  let result = parse_bind_and_check("const obj = { x: 1, y: 2 };")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check empty object" {
  let result = parse_bind_and_check("const obj = {};")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check nested object" {
  let result = parse_bind_and_check("const obj = { a: { b: { c: 1 } } };")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Control Flow Tests
// ============================================================================

///|
test "check if statement" {
  let result = parse_bind_and_check("if (true) { const x = 1; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check if else statement" {
  let result = parse_bind_and_check(
    "if (true) { const x = 1; } else { const y = 2; }",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check while loop" {
  let result = parse_bind_and_check("while (true) { const x = 1; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check for loop" {
  let result = parse_bind_and_check("for (let i = 0; i < 10; i++) { const x = i; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Unary Expression Tests
// ============================================================================

///|
test "check unary minus" {
  let result = parse_bind_and_check("const x = -42;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check logical not" {
  let result = parse_bind_and_check("const x = !true;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check typeof operator" {
  let result = parse_bind_and_check("const x = typeof 42;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Conditional Expression Tests
// ============================================================================

///|
test "check ternary expression" {
  let result = parse_bind_and_check("const x = true ? 1 : 2;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check nested ternary" {
  let result = parse_bind_and_check("const x = true ? (false ? 1 : 2) : 3;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Complex Expression Tests
// ============================================================================

///|
test "check complex arithmetic" {
  let result = parse_bind_and_check("const x = (1 + 2) * 3 - 4 / 2;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(diagnostics) => {
      println("Complex arithmetic test failed with \{diagnostics.length()} errors:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  \{diagnostics[i].message}")
      }
      assert_true(false)
    }
  }
}

///|
test "check mixed expressions" {
  let result = parse_bind_and_check("const x = (1 + 2) > 3 && true || false;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Multiple Declaration Tests
// ============================================================================

///|
test "check multiple declarations" {
  let result = parse_bind_and_check("const x = 1; const y = 2; const z = x + y;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check variable reference" {
  let result = parse_bind_and_check("const x = 1; const y = x;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Class Type Tests
// ============================================================================

///|
test "check class declaration" {
  let result = parse_bind_and_check("class Foo {}")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check class with method" {
  let result = parse_bind_and_check("class Foo { bar() {} }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Empty Source Tests
// ============================================================================

///|
test "check empty source" {
  let result = parse_bind_and_check("")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Union Type Tests
// ============================================================================

///|
test "check union type declaration" {
  let result = parse_bind_and_check("const x: number | string = 42;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check union type with string" {
  let result = parse_bind_and_check("const x: number | string = \"hello\";")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check multi-type union" {
  let result = parse_bind_and_check("const x: number | string | boolean = true;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check union type mismatch" {
  let result = parse_bind_and_check("const x: number | string = true;")
  match result {
    Ok(_) => {
      println("Union type mismatch test should have failed but passed")
      assert_true(false) // Should have error
    }
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
    }
  }
}

// ============================================================================
// Any Type Tests
// ============================================================================

///|
test "check any type declaration" {
  let result = parse_bind_and_check("const x: any = 42;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check any assignable to number" {
  let result = parse_bind_and_check("const a: any = 42; const b: number = a;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check any assignable to string" {
  let result = parse_bind_and_check("const a: any = \"test\"; const b: string = a;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check any assignable to boolean" {
  let result = parse_bind_and_check("const a: any = true; const b: boolean = a;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Undefined Type Tests
// ============================================================================

///|
test "check undefined literal" {
  let result = parse_bind_and_check("const x = undefined;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check undefined type annotation" {
  let result = parse_bind_and_check("const x: undefined = undefined;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check undefined assignable to number" {
  let result = parse_bind_and_check("const x: number = undefined;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check undefined assignable to string" {
  let result = parse_bind_and_check("const x: string = undefined;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Void Type Tests
// ============================================================================

///|
test "check void return type" {
  let result = parse_bind_and_check("function test(): void { console.log(\"test\"); }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check void type annotation" {
  let result = parse_bind_and_check("const x: void = undefined;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Type Narrowing Tests (typeof guards)
// ============================================================================

///|
test "check typeof string guard" {
  let result = parse_bind_and_check(
    "const x: string | number = \"test\"; if (typeof x === \"string\") { const y: string = x; }",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check typeof number guard" {
  let result = parse_bind_and_check(
    "const x: string | number = 42; if (typeof x === \"number\") { const y: number = x; }",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check typeof boolean guard" {
  let result = parse_bind_and_check(
    "const x: string | boolean = true; if (typeof x === \"boolean\") { const y: boolean = x; }",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check typeof undefined guard" {
  let result = parse_bind_and_check(
    "const x: string | undefined = undefined; if (typeof x === \"undefined\") { const y: undefined = x; }",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Interface Tests
// ============================================================================

///|
test "check interface declaration" {
  let result = parse_bind_and_check("interface Person { name: string; age: number; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check interface with object literal" {
  let result = parse_bind_and_check(
    "interface Person { name: string; age: number; } const p: Person = { name: \"John\", age: 30 };",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check interface property mismatch" {
  let result = parse_bind_and_check(
    "interface Person { name: string; age: number; } const p: Person = { name: \"John\", age: \"thirty\" };",
  )
  match result {
    Ok(_) => {
      println("Interface property mismatch test should have failed but passed")
      assert_true(false) // Should have error
    }
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
    }
  }
}

///|
test "check empty interface" {
  let result = parse_bind_and_check("interface Empty {}")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check interface with method" {
  let result = parse_bind_and_check("interface Greeter { greet(): void; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Enum Tests
// ============================================================================

///|
test "check enum declaration" {
  let result = parse_bind_and_check("enum Color { Red, Green, Blue }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check enum with explicit values" {
  let result = parse_bind_and_check("enum Status { Active = 1, Inactive = 0 }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check enum member access" {
  let result = parse_bind_and_check("enum Color { Red, Green, Blue } const c = Color.Red;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check enum type annotation" {
  let result = parse_bind_and_check(
    "enum Color { Red, Green, Blue } const c: Color = Color.Red;",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Generic Function Tests
// ============================================================================

///|
test "check generic function declaration" {
  let result = parse_bind_and_check("function identity<T>(x: T): T { return x; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check generic function call" {
  let result = parse_bind_and_check(
    "function identity<T>(x: T): T { return x; } const result = identity(42);",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check generic function with explicit type" {
  let result = parse_bind_and_check(
    "function identity<T>(x: T): T { return x; } const result = identity<number>(42);",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check generic function with multiple parameters" {
  let result = parse_bind_and_check(
    "function pair<T, U>(first: T, second: U) { return { first, second }; }",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Optional Parameter Tests
// ============================================================================

///|
test "check function with optional parameter" {
  let result = parse_bind_and_check("function greet(name?: string) { return name; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check function with multiple optional parameters" {
  let result = parse_bind_and_check(
    "function build(first?: string, second?: number) { return { first, second }; }",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check optional parameter with default value" {
  let result = parse_bind_and_check("function greet(name: string = \"World\") { return name; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Rest Parameter Tests
// ============================================================================

///|
test "check function with rest parameter" {
  let result = parse_bind_and_check("function sum(...numbers: number[]) { return 0; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check function with mixed and rest parameters" {
  let result = parse_bind_and_check(
    "function concat(separator: string, ...strings: string[]) { return \"\"; }",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Property Access Tests
// ============================================================================

///|
test "check property access" {
  let result = parse_bind_and_check("const obj = { x: 1 }; const y = obj.x;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check nested property access" {
  let result = parse_bind_and_check("const obj = { a: { b: { c: 1 } } }; const val = obj.a.b.c;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check bracket property access" {
  let result = parse_bind_and_check("const obj = { x: 1 }; const y = obj[\"x\"];")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check array element access" {
  let result = parse_bind_and_check("const arr = [1, 2, 3]; const x = arr[0];")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Method Call Tests
// ============================================================================

///|
test "check method call" {
  let result = parse_bind_and_check(
    "const obj = { greet() { return \"hello\"; } }; const msg = obj.greet();",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check method call with arguments" {
  let result = parse_bind_and_check(
    "const obj = { add(a: number, b: number) { return a + b; } }; const result = obj.add(1, 2);",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Additional Operator Tests
// ============================================================================

///|
test "check logical or operator" {
  let result = parse_bind_and_check("const x = false || true;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check bitwise and operator" {
  let result = parse_bind_and_check("const x = 5 & 3;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check bitwise or operator" {
  let result = parse_bind_and_check("const x = 5 | 3;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check bitwise xor operator" {
  let result = parse_bind_and_check("const x = 5 ^ 3;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check bitwise not operator" {
  let result = parse_bind_and_check("const x = ~5;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check left shift operator" {
  let result = parse_bind_and_check("const x = 5 << 2;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check right shift operator" {
  let result = parse_bind_and_check("const x = 20 >> 2;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check unsigned right shift operator" {
  let result = parse_bind_and_check("const x = -1 >>> 1;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check modulo operator" {
  let result = parse_bind_and_check("const x = 10 % 3;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check exponentiation operator" {
  let result = parse_bind_and_check("const x = 2 ** 3;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check instanceof operator" {
  let result = parse_bind_and_check("class Foo {} const obj = new Foo(); const result = obj instanceof Foo;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check in operator" {
  let result = parse_bind_and_check("const obj = { x: 1 }; const result = \"x\" in obj;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check delete operator" {
  let result = parse_bind_and_check("const obj = { x: 1 }; delete obj.x;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check void operator" {
  let result = parse_bind_and_check("const x = void 0;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Increment/Decrement Operator Tests
// ============================================================================

///|
test "check postfix increment" {
  let result = parse_bind_and_check("let x = 1; const y = x++;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check postfix decrement" {
  let result = parse_bind_and_check("let x = 1; const y = x--;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check prefix increment" {
  let result = parse_bind_and_check("let x = 1; const y = ++x;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check prefix decrement" {
  let result = parse_bind_and_check("let x = 1; const y = --x;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// New Operator Tests
// ============================================================================

///|
test "check new operator with class" {
  let result = parse_bind_and_check("class Foo {} const obj = new Foo();")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check new operator with arguments" {
  let result = parse_bind_and_check(
    "class Point { constructor(x: number, y: number) {} } const p = new Point(1, 2);",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// This Keyword Tests
// ============================================================================

///|
test "check this in method" {
  let result = parse_bind_and_check(
    "class Foo { x = 1; getX() { return this.x; } }",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check this in arrow function" {
  let result = parse_bind_and_check(
    "class Foo { x = 1; getX = () => this.x; }",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Spread Operator Tests
// ============================================================================

///|
test "check array spread" {
  let result = parse_bind_and_check("const arr1 = [1, 2]; const arr2 = [...arr1, 3, 4];")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check object spread" {
  let result = parse_bind_and_check("const obj1 = { x: 1 }; const obj2 = { ...obj1, y: 2 };")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Destructuring Tests
// ============================================================================

///|
test "check array destructuring" {
  let result = parse_bind_and_check("const [a, b] = [1, 2];")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check object destructuring" {
  let result = parse_bind_and_check("const { x, y } = { x: 1, y: 2 };")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check nested destructuring" {
  let result = parse_bind_and_check("const { a: { b } } = { a: { b: 1 } };")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Additional Control Flow Tests
// ============================================================================

///|
test "check do while loop" {
  let result = parse_bind_and_check("do { const x = 1; } while (false);")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check for in loop" {
  let result = parse_bind_and_check("const obj = { x: 1, y: 2 }; for (const key in obj) { const v = key; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check for of loop" {
  let result = parse_bind_and_check("const arr = [1, 2, 3]; for (const item of arr) { const v = item; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check switch statement" {
  let result = parse_bind_and_check(
    "const x = 1; switch (x) { case 1: const y = \"one\"; break; default: const z = \"other\"; }",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check try catch" {
  let result = parse_bind_and_check("try { const x = 1; } catch (e) { const y = e; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check try finally" {
  let result = parse_bind_and_check("try { const x = 1; } finally { const y = 2; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check try catch finally" {
  let result = parse_bind_and_check(
    "try { const x = 1; } catch (e) { const y = e; } finally { const z = 3; }",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Template Literal Tests
// ============================================================================

///|
test "check template literal" {
  let result = parse_bind_and_check("const name = \"World\"; const msg = `Hello, ${name}!`;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check template literal with expression" {
  let result = parse_bind_and_check("const x = 1; const y = 2; const result = `Sum: ${x + y}`;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Let and Var Declaration Tests
// ============================================================================

///|
test "check let declaration" {
  let result = parse_bind_and_check("let x = 42;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check var declaration" {
  let result = parse_bind_and_check("var x = 42;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check let reassignment" {
  let result = parse_bind_and_check("let x = 1; x = 2;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check const reassignment error" {
  let result = parse_bind_and_check("const x = 1; x = 2;")
  match result {
    Ok(_) => {
      println("Const reassignment test should have failed but passed")
      assert_true(false) // Should have error
    }
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
    }
  }
}

// ============================================================================
// Type Alias Tests
// ============================================================================

///|
test "check type alias declaration" {
  let result = parse_bind_and_check("type StringOrNumber = string | number;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check type alias usage" {
  let result = parse_bind_and_check("type StringOrNumber = string | number; const x: StringOrNumber = 42;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check generic type alias" {
  let result = parse_bind_and_check("type Box<T> = { value: T };")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Class Property and Constructor Tests
// ============================================================================

///|
test "check class with properties" {
  let result = parse_bind_and_check("class Point { x: number; y: number; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check class with constructor" {
  let result = parse_bind_and_check(
    "class Point { constructor(x: number, y: number) { this.x = x; this.y = y; } }",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check class with property initializers" {
  let result = parse_bind_and_check("class Point { x = 0; y = 0; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check class inheritance" {
  let result = parse_bind_and_check("class Animal {} class Dog extends Animal {}")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check class with static method" {
  let result = parse_bind_and_check("class Math { static abs(x: number) { return x < 0 ? -x : x; } }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check class with private property" {
  let result = parse_bind_and_check("class Person { private age: number; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check class with public property" {
  let result = parse_bind_and_check("class Person { public name: string; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check class with protected property" {
  let result = parse_bind_and_check("class Person { protected id: number; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}
