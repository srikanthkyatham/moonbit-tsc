// Generic Method Parsing Tests
// Tests that the parser correctly handles generic methods in class declarations
// This includes methods with type parameters like foo<T>() and static generic methods

///|
/// Helper function to check if parsing succeeds (no errors)
fn generic_method_parse_succeeds(source : String) -> Bool {
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(_) => true
    Err(_) => false
  }
}

///|
/// Helper function to parse, bind, and check source code
fn generic_method_parse_bind_check(source : String) -> @compiler.CheckResult {
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
// Basic Generic Method Parsing Tests
// ============================================================================

///|
test "parser/generic-method - simple generic method no body" {
  // Generic method declaration without body (e.g., in interface or abstract)
  let source = "class C { foo<T>(); }"
  assert_true(generic_method_parse_succeeds(source))
}

///|
test "parser/generic-method - simple generic method with empty body" {
  // Generic method with empty body
  let source = "class C { foo<T>() {} }"
  assert_true(generic_method_parse_succeeds(source))
}

///|
test "parser/generic-method - generic method with parameter" {
  // Generic method with typed parameter
  let source = "class C { foo<T>(x: T) { return x; } }"
  assert_true(generic_method_parse_succeeds(source))
}

///|
test "parser/generic-method - generic method with return type" {
  // Generic method with return type annotation
  let source = "class C { foo<T>(x: T): T { return x; } }"
  assert_true(generic_method_parse_succeeds(source))
}

///|
test "parser/generic-method - generic method with multiple type params" {
  // Generic method with multiple type parameters
  let source = "class C { foo<T, U>(a: T, b: U): [T, U] { return [a, b]; } }"
  assert_true(generic_method_parse_succeeds(source))
}

///|
test "parser/generic-method - generic method with constraint" {
  // Generic method with type constraint
  let source = "class C { foo<T extends string>(x: T): T { return x; } }"
  assert_true(generic_method_parse_succeeds(source))
}

// ============================================================================
// Static Generic Method Tests
// ============================================================================

///|
test "parser/generic-method - static generic method" {
  // Static generic method
  let source = "class C { static foo<T>(x: T) { return x; } }"
  assert_true(generic_method_parse_succeeds(source))
}

///|
test "parser/generic-method - static generic method with return type" {
  // Static generic method with return type
  let source = "class C { static create<T>(value: T): T { return value; } }"
  assert_true(generic_method_parse_succeeds(source))
}

///|
test "parser/generic-method - static generic method no body" {
  // Static generic method declaration without body
  let source = "class C { static foo<T>(); }"
  assert_true(generic_method_parse_succeeds(source))
}

// ============================================================================
// Access Modifier + Generic Method Tests
// ============================================================================

///|
test "parser/generic-method - public generic method" {
  // Public generic method
  let source = "class C { public foo<T>(x: T) { return x; } }"
  assert_true(generic_method_parse_succeeds(source))
}

///|
test "parser/generic-method - private generic method" {
  // Private generic method
  let source = "class C { private foo<T>(x: T) { return x; } }"
  assert_true(generic_method_parse_succeeds(source))
}

///|
test "parser/generic-method - protected generic method" {
  // Protected generic method
  let source = "class C { protected foo<T>(x: T) { return x; } }"
  assert_true(generic_method_parse_succeeds(source))
}

///|
test "parser/generic-method - public static generic method" {
  // Public static generic method
  let source = "class C { public static foo<T>(x: T) { return x; } }"
  assert_true(generic_method_parse_succeeds(source))
}

///|
test "parser/generic-method - private static generic method" {
  // Private static generic method
  let source = "class C { private static foo<T>(x: T) { return x; } }"
  assert_true(generic_method_parse_succeeds(source))
}

// ============================================================================
// Multiple Generic Methods Tests
// ============================================================================

///|
test "parser/generic-method - multiple generic methods in class" {
  // Class with multiple generic methods
  let source =
    #|class C {
    #|  foo<T>(x: T): T { return x; }
    #|  bar<U>(y: U): U { return y; }
    #|  baz<V, W>(a: V, b: W): [V, W] { return [a, b]; }
    #|}
  assert_true(generic_method_parse_succeeds(source))
}

///|
test "parser/generic-method - mixed methods in class" {
  // Class with both generic and non-generic methods
  let source =
    #|class C {
    #|  regularMethod(x: number): number { return x; }
    #|  genericMethod<T>(x: T): T { return x; }
    #|  static staticRegular(): void {}
    #|  static staticGeneric<U>(y: U): U { return y; }
    #|}
  assert_true(generic_method_parse_succeeds(source))
}

// ============================================================================
// Generic Class with Generic Methods Tests
// ============================================================================

///|
test "parser/generic-method - generic class with generic method" {
  // Generic class containing a generic method
  let source = "class Container<T> { map<U>(fn: (x: T) => U): U[] { return []; } }"
  assert_true(generic_method_parse_succeeds(source))
}

///|
test "parser/generic-method - generic class with multiple generic methods" {
  // Generic class with multiple generic methods
  let source =
    #|class Container<T> {
    #|  value: T;
    #|  map<U>(fn: (x: T) => U): Container<U> { return new Container<U>(); }
    #|  flatMap<V>(fn: (x: T) => Container<V>): Container<V> { return fn(this.value); }
    #|}
  assert_true(generic_method_parse_succeeds(source))
}

// ============================================================================
// Edge Cases
// ============================================================================

///|
test "parser/generic-method - generic method with default type" {
  // Generic method with default type parameter
  let source = "class C { foo<T = string>(x: T): T { return x; } }"
  assert_true(generic_method_parse_succeeds(source))
}

///|
test "parser/generic-method - async generic method" {
  // Async generic method
  let source = "class C { async foo<T>(x: T): Promise<T> { return x; } }"
  assert_true(generic_method_parse_succeeds(source))
}

///|
test "parser/generic-method - readonly modifier with generic method" {
  // Class with readonly property and generic method
  let source =
    #|class C {
    #|  readonly name: string;
    #|  transform<T>(x: T): T { return x; }
    #|}
  assert_true(generic_method_parse_succeeds(source))
}

// ============================================================================
// Type Checking Tests for Generic Methods
// ============================================================================

///|
test "checker/generic-method - basic generic method type check" {
  let result = generic_method_parse_bind_check("class C { foo<T>(x: T): T { return x; } }")
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "checker/generic-method - static generic method type check" {
  let result = generic_method_parse_bind_check(
    "class C { static create<T>(value: T): T { return value; } }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "checker/generic-method - generic method with constraint type check" {
  let result = generic_method_parse_bind_check(
    "class C { foo<T extends { name: string }>(x: T): string { return x.name; } }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}
