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
      // Check that diagnostic mentions type assignment error
      match diagnostics[0] {
        diag => assert_true(diag.message.contains("not assignable"))
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

// ============================================================================
// Intersection Type Tests
// ============================================================================

///|
test "check intersection type declaration" {
  let result = parse_bind_and_check(
    "interface A { a: number; } interface B { b: string; } const x: A & B = { a: 1, b: \"test\" };",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check intersection of primitives" {
  let result = parse_bind_and_check("type Never = string & number;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check intersection with function" {
  let result = parse_bind_and_check(
    "interface Named { name: string; } interface Callable { (): void; } type NamedCallable = Named & Callable;",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Never Type Tests
// ============================================================================

///|
test "check never type annotation" {
  let result = parse_bind_and_check("function fail(message: string): never { throw new Error(message); }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check never in exhaustive switch" {
  let result = parse_bind_and_check(
    "type Shape = \"circle\" | \"square\"; function assertNever(x: never): never { throw new Error(); }",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Unknown Type Tests
// ============================================================================

///|
test "check unknown type annotation" {
  let result = parse_bind_and_check("const x: unknown = 42;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check unknown assignable from any" {
  let result = parse_bind_and_check("const a: any = 42; const b: unknown = a;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check unknown type with typeof guard" {
  let result = parse_bind_and_check(
    "function processValue(x: unknown) { if (typeof x === \"string\") { const y: string = x; } }",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Tuple Type Tests
// ============================================================================

///|
test "check tuple type declaration" {
  let result = parse_bind_and_check("const tuple: [number, string] = [1, \"hello\"];")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check tuple with three elements" {
  let result = parse_bind_and_check("const tuple: [number, string, boolean] = [1, \"hello\", true];")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check tuple element access" {
  let result = parse_bind_and_check("const tuple: [number, string] = [1, \"hello\"]; const a = tuple[0]; const b = tuple[1];")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check tuple with optional element" {
  let result = parse_bind_and_check("const tuple: [number, string?] = [1];")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check tuple with rest element" {
  let result = parse_bind_and_check("const tuple: [string, ...number[]] = [\"hello\", 1, 2, 3];")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Type Assertion Tests
// ============================================================================

///|
test "check as type assertion" {
  let result = parse_bind_and_check("const x = \"hello\" as string;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check as const assertion" {
  let result = parse_bind_and_check("const x = \"hello\" as const;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check type assertion with union" {
  let result = parse_bind_and_check("const x: unknown = 42; const y = x as number | string;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check non-null assertion" {
  let result = parse_bind_and_check("const x: string | null = \"hello\"; const y = x!;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Nullish Coalescing Operator Tests
// ============================================================================

///|
test "check nullish coalescing with null" {
  let result = parse_bind_and_check("const x = null ?? \"default\";")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check nullish coalescing with undefined" {
  let result = parse_bind_and_check("const x = undefined ?? \"default\";")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check nullish coalescing with value" {
  let result = parse_bind_and_check("const x = \"value\" ?? \"default\";")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check chained nullish coalescing" {
  let result = parse_bind_and_check("const x = null ?? undefined ?? \"default\";")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Optional Chaining Tests
// ============================================================================

///|
test "check optional chaining property access" {
  let result = parse_bind_and_check("const obj: { x?: { y: number } } = {}; const val = obj.x?.y;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check optional chaining method call" {
  let result = parse_bind_and_check("const obj: { greet?: () => string } = {}; const msg = obj.greet?.();")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check optional chaining element access" {
  let result = parse_bind_and_check("const arr: number[] | null = null; const val = arr?.[0];")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check chained optional access" {
  let result = parse_bind_and_check("const obj: { a?: { b?: { c: number } } } = {}; const val = obj.a?.b?.c;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Async/Await Tests
// ============================================================================

///|
test "check async function declaration" {
  let result = parse_bind_and_check("async function fetchData(): Promise<string> { return \"data\"; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check async arrow function" {
  let result = parse_bind_and_check("const fetchData = async (): Promise<number> => { return 42; };")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check await expression" {
  let result = parse_bind_and_check(
    "async function test() { const promise = Promise.resolve(42); const result = await promise; }",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check async function with try catch" {
  let result = parse_bind_and_check(
    "async function test() { try { await Promise.resolve(); } catch (e) { console.log(e); } }",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Abstract Class Tests
// ============================================================================

///|
test "check abstract class declaration" {
  let result = parse_bind_and_check("abstract class Animal { abstract speak(): void; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check abstract class with concrete method" {
  let result = parse_bind_and_check(
    "abstract class Animal { abstract speak(): void; move() { console.log(\"moving\"); } }",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check class extending abstract class" {
  let result = parse_bind_and_check(
    "abstract class Animal { abstract speak(): void; } class Dog extends Animal { speak() { console.log(\"woof\"); } }",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check abstract class with abstract property" {
  let result = parse_bind_and_check("abstract class Animal { abstract readonly name: string; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Getter/Setter Tests
// ============================================================================

///|
test "check getter" {
  let result = parse_bind_and_check("class Circle { private _radius = 1; get radius() { return this._radius; } }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check setter" {
  let result = parse_bind_and_check(
    "class Circle { private _radius = 1; set radius(value: number) { this._radius = value; } }",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check getter and setter" {
  let result = parse_bind_and_check(
    "class Circle { private _radius = 1; get radius() { return this._radius; } set radius(value: number) { this._radius = value; } }",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check getter with return type" {
  let result = parse_bind_and_check(
    "class Circle { private _radius = 1; get radius(): number { return this._radius; } }",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Generic Class Tests
// ============================================================================

///|
test "check generic class declaration" {
  let result = parse_bind_and_check("class Box<T> { value: T; constructor(value: T) { this.value = value; } }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check generic class instantiation" {
  let result = parse_bind_and_check(
    "class Box<T> { constructor(public value: T) {} } const box = new Box<number>(42);",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check generic class with constraint" {
  let result = parse_bind_and_check(
    "interface HasLength { length: number; } class Container<T extends HasLength> { constructor(public value: T) {} }",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check generic class with multiple type parameters" {
  let result = parse_bind_and_check("class Pair<K, V> { constructor(public key: K, public value: V) {} }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Generic Interface Tests
// ============================================================================

///|
test "check generic interface declaration" {
  let result = parse_bind_and_check("interface Container<T> { value: T; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check generic interface with constraint" {
  let result = parse_bind_and_check("interface Container<T extends object> { value: T; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check generic interface implementation" {
  let result = parse_bind_and_check(
    "interface Container<T> { value: T; } const box: Container<number> = { value: 42 };",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Index Signature Tests
// ============================================================================

///|
test "check string index signature" {
  let result = parse_bind_and_check("interface StringMap { [key: string]: number; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check number index signature" {
  let result = parse_bind_and_check("interface NumberArray { [index: number]: string; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check index signature with known properties" {
  let result = parse_bind_and_check("interface Dict { name: string; [key: string]: string; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check readonly index signature" {
  let result = parse_bind_and_check("interface ReadonlyMap { readonly [key: string]: number; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Computed Property Tests
// ============================================================================

///|
test "check computed property with string literal" {
  let result = parse_bind_and_check("const obj = { [\"key\"]: 42 };")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check computed property with variable" {
  let result = parse_bind_and_check("const key = \"prop\"; const obj = { [key]: 42 };")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check computed property with symbol" {
  let result = parse_bind_and_check("const sym = Symbol(\"key\"); const obj = { [sym]: 42 };")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Readonly Tests
// ============================================================================

///|
test "check readonly property" {
  let result = parse_bind_and_check("interface Point { readonly x: number; readonly y: number; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check readonly array" {
  let result = parse_bind_and_check("const arr: readonly number[] = [1, 2, 3];")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check Readonly utility type" {
  let result = parse_bind_and_check(
    "interface Point { x: number; y: number; } const p: Readonly<Point> = { x: 1, y: 2 };",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check readonly tuple" {
  let result = parse_bind_and_check("const tuple: readonly [number, string] = [1, \"hello\"];")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Const Enum Tests
// ============================================================================

///|
test "check const enum declaration" {
  let result = parse_bind_and_check("const enum Direction { Up, Down, Left, Right }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check const enum with values" {
  let result = parse_bind_and_check("const enum FileAccess { Read = 1, Write = 2, ReadWrite = Read | Write }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check const enum member access" {
  let result = parse_bind_and_check("const enum Direction { Up, Down } const d = Direction.Up;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// String Enum Tests
// ============================================================================

///|
test "check string enum declaration" {
  let result = parse_bind_and_check("enum Direction { Up = \"UP\", Down = \"DOWN\", Left = \"LEFT\", Right = \"RIGHT\" }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check string enum member access" {
  let result = parse_bind_and_check(
    "enum Direction { Up = \"UP\", Down = \"DOWN\" } const d: Direction = Direction.Up;",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Class Implements Interface Tests
// ============================================================================

///|
test "check class implements interface" {
  let result = parse_bind_and_check(
    "interface Runnable { run(): void; } class Car implements Runnable { run() { console.log(\"running\"); } }",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check class implements multiple interfaces" {
  let result = parse_bind_and_check(
    "interface A { a(): void; } interface B { b(): void; } class C implements A, B { a() {} b() {} }",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check class extends and implements" {
  let result = parse_bind_and_check(
    "class Base {} interface Runnable { run(): void; } class Derived extends Base implements Runnable { run() {} }",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Literal Type Tests
// ============================================================================

///|
test "check string literal as type annotation" {
  let result = parse_bind_and_check("const x: \"hello\" = \"hello\";")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check number literal as type annotation" {
  let result = parse_bind_and_check("const x: 42 = 42;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check boolean literal as type annotation" {
  let result = parse_bind_and_check("const x: true = true;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check literal type union" {
  let result = parse_bind_and_check("type Direction = \"up\" | \"down\" | \"left\" | \"right\"; const d: Direction = \"up\";")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Keyof Operator Tests
// ============================================================================

///|
test "check keyof operator" {
  let result = parse_bind_and_check("interface Point { x: number; y: number; } type PointKeys = keyof Point;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check keyof with generic" {
  let result = parse_bind_and_check("function getProperty<T, K extends keyof T>(obj: T, key: K) { return obj[key]; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Index Access Type Tests
// ============================================================================

///|
test "check index access type" {
  let result = parse_bind_and_check("interface Person { name: string; age: number; } type Age = Person[\"age\"];")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check index access with keyof" {
  let result = parse_bind_and_check(
    "interface Person { name: string; age: number; } type PersonValues = Person[keyof Person];",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Conditional Type Tests
// ============================================================================

///|
test "check conditional type" {
  let result = parse_bind_and_check("type IsString<T> = T extends string ? true : false;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check conditional type with infer" {
  let result = parse_bind_and_check("type GetReturnType<T> = T extends (...args: any[]) => infer R ? R : never;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check nested conditional type" {
  let result = parse_bind_and_check(
    "type TypeName<T> = T extends string ? \"string\" : T extends number ? \"number\" : \"object\";",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Mapped Type Tests
// ============================================================================

///|
test "check mapped type" {
  let result = parse_bind_and_check("type Readonly<T> = { readonly [P in keyof T]: T[P] };")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check partial mapped type" {
  let result = parse_bind_and_check("type Partial<T> = { [P in keyof T]?: T[P] };")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check mapped type with modifier removal" {
  let result = parse_bind_and_check("type Required<T> = { [P in keyof T]-?: T[P] };")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Function Overload Tests
// ============================================================================

///|
test "check function overloads" {
  let result = parse_bind_and_check(
    "function greet(name: string): string; function greet(age: number): string; function greet(value: string | number): string { return \"\"; }",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check method overloads" {
  let result = parse_bind_and_check(
    "class Greeter { greet(name: string): string; greet(age: number): string; greet(value: string | number): string { return \"\"; } }",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Symbol Type Tests
// ============================================================================

///|
test "check symbol declaration" {
  let result = parse_bind_and_check("const sym = Symbol(\"description\");")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check symbol type annotation" {
  let result = parse_bind_and_check("const sym: symbol = Symbol(\"description\");")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check unique symbol" {
  let result = parse_bind_and_check("const sym: unique symbol = Symbol(\"unique\");")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// BigInt Type Tests
// ============================================================================

///|
test "check bigint literal" {
  let result = parse_bind_and_check("const x = 9007199254740991n;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check bigint type annotation" {
  let result = parse_bind_and_check("const x: bigint = 9007199254740991n;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Throw Statement Tests
// ============================================================================

///|
test "check throw statement with Error" {
  let result = parse_bind_and_check("function fail() { throw new Error(\"message\"); }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check throw statement with string" {
  let result = parse_bind_and_check("function fail() { throw \"error\"; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Labeled Statement Tests
// ============================================================================

///|
test "check labeled statement" {
  let result = parse_bind_and_check("outer: for (let i = 0; i < 10; i++) { inner: for (let j = 0; j < 10; j++) { break outer; } }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check continue with label" {
  let result = parse_bind_and_check("outer: for (let i = 0; i < 10; i++) { for (let j = 0; j < 10; j++) { continue outer; } }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// With Statement Tests (legacy)
// ============================================================================

///|
test "check with statement" {
  let result = parse_bind_and_check("const obj = { x: 1 }; with (obj) { const y = x; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Empty Statement Tests
// ============================================================================

///|
test "check empty statement" {
  let result = parse_bind_and_check(";")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check multiple empty statements" {
  let result = parse_bind_and_check(";;;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Debugger Statement Tests
// ============================================================================

///|
test "check debugger statement" {
  let result = parse_bind_and_check("debugger;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Regular Expression Tests
// ============================================================================

///|
test "check regex literal" {
  let result = parse_bind_and_check("const pattern = /[a-z]+/g;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check regex type annotation" {
  let result = parse_bind_and_check("const pattern: RegExp = /[a-z]+/;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Comma Expression Tests
// ============================================================================

///|
test "check comma expression" {
  let result = parse_bind_and_check("const x = (1, 2, 3);")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Compound Assignment Operator Tests
// ============================================================================

///|
test "check addition assignment" {
  let result = parse_bind_and_check("let x = 1; x += 2;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check subtraction assignment" {
  let result = parse_bind_and_check("let x = 5; x -= 2;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check multiplication assignment" {
  let result = parse_bind_and_check("let x = 2; x *= 3;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check division assignment" {
  let result = parse_bind_and_check("let x = 6; x /= 2;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check modulo assignment" {
  let result = parse_bind_and_check("let x = 7; x %= 3;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check exponentiation assignment" {
  let result = parse_bind_and_check("let x = 2; x **= 3;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check bitwise and assignment" {
  let result = parse_bind_and_check("let x = 5; x &= 3;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check bitwise or assignment" {
  let result = parse_bind_and_check("let x = 5; x |= 3;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check bitwise xor assignment" {
  let result = parse_bind_and_check("let x = 5; x ^= 3;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check left shift assignment" {
  let result = parse_bind_and_check("let x = 2; x <<= 3;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check right shift assignment" {
  let result = parse_bind_and_check("let x = 16; x >>= 2;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check unsigned right shift assignment" {
  let result = parse_bind_and_check("let x = -8; x >>>= 2;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check logical and assignment" {
  let result = parse_bind_and_check("let x = true; x &&= false;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check logical or assignment" {
  let result = parse_bind_and_check("let x = false; x ||= true;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check nullish coalescing assignment" {
  let result = parse_bind_and_check("let x: string | null = null; x ??= \"default\";")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Strict Equality Tests
// ============================================================================

///|
test "check strict equality" {
  let result = parse_bind_and_check("const x = 1 === 1;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check strict inequality" {
  let result = parse_bind_and_check("const x = 1 !== 2;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check loose equality" {
  let result = parse_bind_and_check("const x = 1 == \"1\";")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check loose inequality" {
  let result = parse_bind_and_check("const x = 1 != \"2\";")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Namespace Tests
// ============================================================================

///|
test "check namespace declaration" {
  let result = parse_bind_and_check("namespace MyNamespace { export const x = 1; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check nested namespace" {
  let result = parse_bind_and_check("namespace Outer { export namespace Inner { export const x = 1; } }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check namespace merge with interface" {
  let result = parse_bind_and_check(
    "interface Box { width: number; } namespace Box { export function create(): Box { return { width: 0 }; } }",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Module Declaration Tests
// ============================================================================

///|
test "check module declaration" {
  let result = parse_bind_and_check("module MyModule { export const x = 1; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Import/Export Tests
// ============================================================================

///|
test "check export declaration" {
  let result = parse_bind_and_check("export const x = 1;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check export function" {
  let result = parse_bind_and_check("export function add(a: number, b: number) { return a + b; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check export class" {
  let result = parse_bind_and_check("export class Foo { x = 1; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check export interface" {
  let result = parse_bind_and_check("export interface Point { x: number; y: number; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check export type alias" {
  let result = parse_bind_and_check("export type StringOrNumber = string | number;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check export default" {
  let result = parse_bind_and_check("export default function() { return 42; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check export default class" {
  let result = parse_bind_and_check("export default class Foo {}")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Decorator Tests
// ============================================================================

///|
test "check class decorator" {
  let result = parse_bind_and_check("@sealed class Greeter { greeting: string; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check method decorator" {
  let result = parse_bind_and_check("class Greeter { @enumerable(false) greet() { return \"Hello\"; } }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check property decorator" {
  let result = parse_bind_and_check("class Person { @required name: string; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check parameter decorator" {
  let result = parse_bind_and_check("class Greeter { greet(@required name: string) { return name; } }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Generator Function Tests
// ============================================================================

///|
test "check generator function" {
  let result = parse_bind_and_check("function* generator() { yield 1; yield 2; yield 3; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check generator with type annotation" {
  let result = parse_bind_and_check("function* generator(): Generator<number> { yield 1; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check async generator" {
  let result = parse_bind_and_check("async function* asyncGenerator() { yield 1; yield 2; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Object Type Literal Tests
// ============================================================================

///|
test "check object type with call signature" {
  let result = parse_bind_and_check("type Func = { (x: number): number; };")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check object type with construct signature" {
  let result = parse_bind_and_check("type Constructor = { new (x: number): object; };")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Type Predicate Tests
// ============================================================================

///|
test "check type predicate" {
  let result = parse_bind_and_check("function isString(x: unknown): x is string { return typeof x === \"string\"; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check assertion function" {
  let result = parse_bind_and_check("function assertString(x: unknown): asserts x is string { if (typeof x !== \"string\") throw new Error(); }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Template Literal Type Tests
// ============================================================================

///|
test "check template literal type" {
  let result = parse_bind_and_check("type EventName = `on${string}`;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check template literal type with union" {
  let result = parse_bind_and_check("type Color = \"red\" | \"blue\"; type ColorId = `color-${Color}`;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Satisfies Operator Tests
// ============================================================================

///|
test "check satisfies operator" {
  let result = parse_bind_and_check("const x = { a: 1, b: 2 } satisfies Record<string, number>;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Using Declaration Tests (ES2022 Explicit Resource Management)
// ============================================================================

///|
test "check using declaration" {
  let result = parse_bind_and_check("using resource = getResource();")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check await using declaration" {
  let result = parse_bind_and_check("async function test() { await using resource = getAsyncResource(); }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Debugger Statement Tests
// ============================================================================

///|
test "check debugger statement" {
  let result = parse_bind_and_check("debugger;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check debugger statement without semicolon" {
  let result = parse_bind_and_check("function test() { debugger }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check debugger statement in if block" {
  let result = parse_bind_and_check("if (true) { debugger; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Class Modifier Tests
// ============================================================================

///|
test "check static class member" {
  let result = parse_bind_and_check("class Counter { static count = 0; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check static method" {
  let result = parse_bind_and_check("class Utils { static helper() { return 1; } }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check readonly property" {
  let result = parse_bind_and_check("class Config { readonly name: string; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check abstract class" {
  let result = parse_bind_and_check("abstract class Animal { abstract speak(): void; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check async method" {
  let result = parse_bind_and_check("class Api { async fetch() { return await data; } }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check public static readonly" {
  let result = parse_bind_and_check("class Constants { public static readonly PI = 3.14; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Object Type Keyword Tests
// ============================================================================

///|
test "check object type annotation" {
  let result = parse_bind_and_check("const obj: object = {};")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check object type in function parameter" {
  let result = parse_bind_and_check("function process(data: object): void {}")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check object type in union" {
  let result = parse_bind_and_check("type Mixed = string | object;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Type Operator Tests (typeof, readonly)
// ============================================================================

///|
test "check typeof type operator" {
  let result = parse_bind_and_check("const x = 42; type T = typeof x;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check typeof with object" {
  let result = parse_bind_and_check("const config = { port: 3000 }; type Config = typeof config;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check readonly type operator" {
  let result = parse_bind_and_check("type ReadonlyArray = readonly number[];")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check readonly tuple" {
  let result = parse_bind_and_check("type Point = readonly [number, number];")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Advanced Intersection Type Tests
// ============================================================================

///|
test "check intersection type alias declaration" {
  let result = parse_bind_and_check("type Named = { name: string }; type Aged = { age: number }; type Person = Named & Aged;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check intersection type with variable annotation" {
  let result = parse_bind_and_check("interface A { a: string; } interface B { b: number; } const x: A & B = { a: \"hello\", b: 42 };")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check intersection of primitive types" {
  let result = parse_bind_and_check("type T = string & number;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check intersection with three types" {
  let result = parse_bind_and_check("interface A { a: string; } interface B { b: number; } interface C { c: boolean; } type ABC = A & B & C;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Advanced Tuple Type Tests
// ============================================================================

///|
test "check tuple type alias" {
  let result = parse_bind_and_check("type Point = [number, number];")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check tuple with value assignment" {
  let result = parse_bind_and_check("const point: [number, number] = [1, 2];")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check heterogeneous tuple" {
  let result = parse_bind_and_check("const tuple: [string, number, boolean] = [\"hello\", 42, true];")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check tuple type with optional" {
  let result = parse_bind_and_check("type OptTuple = [string, number?];")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check tuple type with rest" {
  let result = parse_bind_and_check("type RestTuple = [string, ...number[]];")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check tuple with labels" {
  let result = parse_bind_and_check("type NamedTuple = [first: string, second: number];")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Advanced Conditional Type Tests
// ============================================================================

///|
test "check conditional type with generic" {
  let result = parse_bind_and_check("type IsString<T> = T extends string ? true : false;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check conditional type resolving" {
  let result = parse_bind_and_check("type Test = number extends string ? \"yes\" : \"no\";")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check conditional type chain" {
  let result = parse_bind_and_check("type Nested<T> = T extends string ? \"string\" : T extends number ? \"number\" : \"other\";")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Advanced Mapped Type Tests
// ============================================================================

///|
test "check mapped type from union" {
  let result = parse_bind_and_check("type Keys = \"a\" | \"b\"; type Mapped = { [K in Keys]: number };")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check mapped type with keyof transformation" {
  let result = parse_bind_and_check("interface Person { name: string; age: number; } type ReadonlyPerson = { readonly [K in keyof Person]: Person[K] };")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check mapped type making optional" {
  let result = parse_bind_and_check("interface Person { name: string; age: number; } type PartialPerson = { [K in keyof Person]?: Person[K] };")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Advanced Template Literal Type Tests
// ============================================================================

///|
test "check template literal type with placeholder" {
  let result = parse_bind_and_check("type Greeting = `Hello, ${string}!`;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check template literal type combining union" {
  let result = parse_bind_and_check("type Color = \"red\" | \"blue\"; type ColorId = `${Color}-id`;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check template literal type multiple placeholders" {
  let result = parse_bind_and_check("type Id = `${string}-${number}-${boolean}`;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Advanced Index Access Type Tests
// ============================================================================

///|
test "check index access type lookup" {
  let result = parse_bind_and_check("interface Person { name: string; age: number; } type Name = Person[\"name\"];")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check index access type with keyof union" {
  let result = parse_bind_and_check("interface Person { name: string; age: number; } type PersonValue = Person[keyof Person];")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check chained index access type" {
  let result = parse_bind_and_check("interface Data { user: { name: string; }; } type UserName = Data[\"user\"][\"name\"];")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Advanced Infer Type Tests
// ============================================================================

///|
test "check infer in return type extraction" {
  let result = parse_bind_and_check("type GetReturnType<T> = T extends (...args: any[]) => infer R ? R : never;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check infer for array element" {
  // Note: (infer E)[] syntax requires parenthesized type parsing support
  // Using simpler Array<infer E> syntax instead
  let result = parse_bind_and_check("type ArrayElement<T> = T extends Array<infer E> ? E : never;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check infer for tuple first" {
  let result = parse_bind_and_check("type First<T> = T extends [infer F, ...any[]] ? F : never;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Identifier Type Resolution Tests
// ============================================================================

///|
test "check identifier resolution in variable" {
  let result = parse_bind_and_check("const x: number = 10; const y = x + 5;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check identifier resolution with type annotation" {
  let result = parse_bind_and_check("let name: string = 'hello'; let greeting = name.toUpperCase();")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check identifier resolution in function" {
  let result = parse_bind_and_check("function add(a: number, b: number): number { return a + b; } const sum = add(1, 2);")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Call Expression Type Resolution Tests
// ============================================================================

///|
test "check call expression simple" {
  let result = parse_bind_and_check("function greet(name: string): string { return 'Hello ' + name; } greet('World');")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check call expression with multiple args" {
  let result = parse_bind_and_check("function sum(a: number, b: number, c: number): number { return a + b + c; } const result = sum(1, 2, 3);")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check call expression with optional params" {
  let result = parse_bind_and_check("function greet(name: string, title?: string): string { return 'Hello ' + name; } greet('World'); greet('World', 'Mr');")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Generic Type Tests
// ============================================================================

///|
test "check generic function declaration" {
  let result = parse_bind_and_check("function identity<T>(value: T): T { return value; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check generic type with constraint" {
  let result = parse_bind_and_check("function longest<T extends { length: number }>(a: T, b: T): T { return a.length >= b.length ? a : b; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check generic class declaration" {
  let result = parse_bind_and_check("class Box<T> { value: T; constructor(value: T) { this.value = value; } }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Type Guard Tests
// ============================================================================

///|
test "check typeof type guard" {
  let result = parse_bind_and_check("function process(x: string | number) { if (typeof x === 'string') { return x.toUpperCase(); } return x.toFixed(2); }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check instanceof type guard" {
  let result = parse_bind_and_check("class Animal {} class Dog extends Animal { bark() {} } function test(a: Animal) { if (a instanceof Dog) { a.bark(); } }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check null check type guard" {
  let result = parse_bind_and_check("function process(x: string | null) { if (x === null) { return 'empty'; } return x.toUpperCase(); }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check truthiness type guard" {
  let result = parse_bind_and_check("function process(x: string | undefined) { if (x) { return x.toUpperCase(); } return 'default'; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Semantic Validation Tests
// ============================================================================

///|
test "check return statement in function" {
  let result = parse_bind_and_check("function getName(): string { return 'hello'; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check control flow termination" {
  let result = parse_bind_and_check("function test(x: boolean): string { if (x) { return 'yes'; } else { return 'no'; } }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check abstract class declaration" {
  let result = parse_bind_and_check("abstract class Shape { abstract area(): number; }")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check const declaration" {
  let result = parse_bind_and_check("const PI: number = 3.14159;")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Type Error Tests - Assignment Type Mismatch
// ============================================================================

///|
test "check class property assignment type mismatch with literal should error" {
  // age property is declared as string, but constructor assigns a number literal
  let result = parse_bind_and_check(
    "class Person { age: string; constructor() { this.age = 42; } }",
  )
  match result {
    Ok(_) => {
      // This should have produced an error
      assert_true(false)
    }
    Err(diagnostics) => {
      // Expected: type error for assigning number to string
      assert_true(diagnostics.length() > 0)
      assert_true(diagnostics[0].message.contains("not assignable"))
    }
  }
}

// ============================================================================
// Property Lookup in Object Types Tests
// ============================================================================

///|
test "check property access on object literal" {
  let result = parse_bind_and_check(
    "const obj = { name: \"Alice\", age: 30 }; const n = obj.name; const a = obj.age;",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check property access on interface type" {
  let source =
    #|interface Person { name: string; age: number; }
    #|function greet(p: Person): string {
    #|  return p.name;
    #|}
  let result = parse_bind_and_check(source)
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check property access on class instance" {
  let source =
    #|class Person {
    #|  name: string;
    #|  age: number;
    #|  constructor(name: string, age: number) {
    #|    this.name = name;
    #|    this.age = age;
    #|  }
    #|}
    #|const p = new Person("Alice", 30);
    #|const n = p.name;
  let result = parse_bind_and_check(source)
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check method access on class instance" {
  let source =
    #|class Calculator {
    #|  add(a: number, b: number): number {
    #|    return a + b;
    #|  }
    #|}
    #|const calc = new Calculator();
    #|const result = calc.add(1, 2);
  let result = parse_bind_and_check(source)
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check array length property" {
  let result = parse_bind_and_check(
    "const arr = [1, 2, 3]; const len = arr.length;",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check string length property" {
  let result = parse_bind_and_check(
    "const str = \"hello\"; const len = str.length;",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check function length property" {
  let result = parse_bind_and_check(
    "function add(a: number, b: number): number { return a + b; } const len = add.length;",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check function name property" {
  let result = parse_bind_and_check(
    "function myFunc() {} const name = myFunc.name;",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check property access on union type with common property" {
  let source =
    #|interface Cat { name: string; meow(): void; }
    #|interface Dog { name: string; bark(): void; }
    #|function getName(pet: Cat | Dog): string {
    #|  return pet.name;
    #|}
  let result = parse_bind_and_check(source)
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check property access on intersection type" {
  let source =
    #|interface Named { name: string; }
    #|interface Aged { age: number; }
    #|function getInfo(obj: Named & Aged): string {
    #|  const n = obj.name;
    #|  const a = obj.age;
    #|  return n;
    #|}
  let result = parse_bind_and_check(source)
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check property access on any type" {
  let result = parse_bind_and_check(
    "const x: any = {}; const y = x.someProperty;",
  )
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check nested property access on interface" {
  let source =
    #|interface Address { city: string; zip: string; }
    #|interface Person { name: string; address: Address; }
    #|function getCity(p: Person): string {
    #|  return p.address.city;
    #|}
  let result = parse_bind_and_check(source)
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check property access with index signature" {
  let source =
    #|interface StringMap { [key: string]: number; }
    #|function getValue(map: StringMap): number {
    #|  return map.anyKey;
    #|}
  let result = parse_bind_and_check(source)
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "check chained method calls" {
  let source =
    #|class Builder {
    #|  value: string = "";
    #|  append(s: string): Builder {
    #|    this.value = this.value + s;
    #|    return this;
    #|  }
    #|  build(): string {
    #|    return this.value;
    #|  }
    #|}
    #|const result = new Builder().append("hello").append(" ").append("world").build();
  let result = parse_bind_and_check(source)
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}
