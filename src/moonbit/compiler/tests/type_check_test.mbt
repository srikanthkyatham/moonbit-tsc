// Type Check API Tests
// Tests for the type_check.mbt convenience functions

///|
test "type_check simple variable declaration" {
  let result = @compiler.type_check("const x = 42;", "test.ts")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => fail("Expected successful type check")
  }
}

///|
test "type_check with type annotation" {
  let result = @compiler.type_check("const x: number = 42;", "test.ts")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => fail("Expected successful type check")
  }
}

///|
test "type_check string type" {
  let result = @compiler.type_check(
    "const name: string = \"hello\";", "test.ts",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => fail("Expected successful type check")
  }
}

///|
test "type_check boolean type" {
  let result = @compiler.type_check("const flag: boolean = true;", "test.ts")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => fail("Expected successful type check")
  }
}

///|
test "type_check function declaration" {
  let source = "function add(a: number, b: number): number { return a + b; }"
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => fail("Expected successful type check")
  }
}

///|
test "type_check arrow function" {
  let source = "const add = (a: number, b: number): number => a + b;"
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => fail("Expected successful type check")
  }
}

///|
test "type_check interface" {
  let source = "interface Person { name: string; age: number; }"
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => fail("Expected successful type check")
  }
}

///|
test "type_check class" {
  let source = "class Point { x: number; y: number; constructor(x: number, y: number) { this.x = x; this.y = y; } }"
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => fail("Expected successful type check")
  }
}

///|
test "type_check union type" {
  let source = "let value: string | number = 42;"
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => fail("Expected successful type check")
  }
}

///|
test "type_check array type" {
  let source = "const numbers: number[] = [1, 2, 3];"
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => fail("Expected successful type check")
  }
}

///|
test "type_check_with_all_diagnostics returns typed file on success" {
  let (typed_file, diagnostics) = @compiler.type_check_with_all_diagnostics(
    "const x = 42;", "test.ts",
  )
  match typed_file {
    Some(typed) => assert_eq(typed.file_path, "test.ts")
    None => fail("Expected typed file")
  }
  // May or may not have diagnostics (warnings)
  let _ = diagnostics

}

///|
test "format_diagnostic from type check errors" {
  // Create a diagnostic by type checking invalid code
  let result = @compiler.type_check("const x: number = \"hello\";", "test.ts")
  match result {
    Ok(typed) =>
      // If there are diagnostics, test formatting
      if typed.diagnostics.length() > 0 {
        let formatted = @compiler.format_diagnostic(typed.diagnostics[0])
        assert_true(formatted.length() > 0)
      }
    Err(diagnostics) =>
      // Errors - test formatting
      if diagnostics.length() > 0 {
        let formatted = @compiler.format_diagnostic(diagnostics[0])
        assert_true(formatted.length() > 0)
      }
  }
}

///|
test "type_check multiple statements" {
  let source =
    #|const a = 1;
    #|const b = 2;
    #|const c = a + b;
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => fail("Expected successful type check")
  }
}

///|
test "type_check if statement" {
  let source =
    #|const x = 10;
    #|if (x > 5) {
    #|  const y = x * 2;
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => fail("Expected successful type check")
  }
}

///|
test "type_check for loop" {
  let source =
    #|for (let i = 0; i < 10; i++) {
    #|  const x = i * 2;
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => fail("Expected successful type check")
  }
}

///|
test "type_check generic function" {
  let source = "function identity<T>(x: T): T { return x; }"
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => fail("Expected successful type check")
  }
}

///|
test "type_check enum declaration" {
  let source = "enum Color { Red, Green, Blue }"
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => fail("Expected successful type check")
  }
}

///|
test "type_check type alias" {
  let source = "type StringOrNumber = string | number;"
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => fail("Expected successful type check")
  }
}

// ============================================================================
// Integration Test: Type check small.ts file from disk
// ============================================================================

///|
async test "type_check small.ts file from disk" {
  // Read the TypeScript file from disk
  let source = @fs.read_file("test_memory_files/small.ts").text()
  println(source)
  let result = @compiler.type_check(source, "small.ts")
  match result {
    Ok(typed) => {
      assert_eq(typed.file_path, "small.ts")
      // Verify that we have type information for the file
      assert_true(typed.statements.length() > 0)
    }
    Err(diagnostics) => {
      // Print diagnostics for debugging
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println(@compiler.format_diagnostic(diagnostics[i]))
      }
      fail("Expected successful type check for small.ts")
    }
  }
}
