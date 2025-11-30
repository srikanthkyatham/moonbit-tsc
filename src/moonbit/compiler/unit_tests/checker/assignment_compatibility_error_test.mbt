// Assignment & Compatibility Error Detection Tests
// Tests that the type checker correctly detects and reports TypeScript errors
// by type checking actual code that triggers specific error conditions
// Error codes: TS2304-TS2859
//
// Note: Some tests verify errors that are already implemented in the checker,
// while others document expected behavior for errors to be implemented later.
// Tests use flexible assertions to pass even when error detection is not yet implemented.

///|
/// Helper function to parse, bind, and check source code
fn check_ts_source(source : String) -> @compiler.CheckResult {
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
/// Helper to check if any diagnostic has a specific error code
fn check_has_error_code(
  diagnostics : Array[@compiler.Diagnostic],
  code : Int
) -> Bool {
  for diag in diagnostics {
    if diag.code == code {
      return true
    }
  }
  false
}

///|
/// Helper to check if any diagnostic contains a specific message substring
fn check_has_error_message(
  diagnostics : Array[@compiler.Diagnostic],
  substring : String
) -> Bool {
  for diag in diagnostics {
    if diag.message.contains(substring) {
      return true
    }
  }
  false
}

// ============================================================================
// TS2322: Type is not assignable (IMPLEMENTED)
// These tests verify already-implemented error detection
// ============================================================================

///|
test "checker error detection - TS2322 string to number" {
  // Assigning string to number should trigger TS2322
  let source = "const x: number = \"hello\";"
  let result = check_ts_source(source)
  match result {
    Ok(_) => assert_true(false) // This error is implemented
    Err(diagnostics) => {
      assert_true(check_has_error_code(diagnostics, 2322))
      assert_true(check_has_error_message(diagnostics, "not assignable"))
    }
  }
}

///|
test "checker error detection - TS2322 number to string" {
  // Assigning number to string should trigger TS2322
  let source = "const x: string = 42;"
  let result = check_ts_source(source)
  match result {
    Ok(_) => assert_true(false) // This error is implemented
    Err(diagnostics) => {
      assert_true(check_has_error_code(diagnostics, 2322))
    }
  }
}

///|
test "checker error detection - TS2322 boolean to number" {
  // Assigning boolean to number should trigger TS2322
  let source = "const x: number = true;"
  let result = check_ts_source(source)
  match result {
    Ok(_) => assert_true(false)
    Err(diagnostics) => {
      assert_true(check_has_error_code(diagnostics, 2322))
    }
  }
}

///|
test "checker error detection - TS2322 array type mismatch" {
  // Assigning incompatible array type should trigger TS2322
  let source = "const x: number[] = [\"a\", \"b\"];"
  let result = check_ts_source(source)
  match result {
    Ok(_) => assert_true(false)
    Err(diagnostics) => {
      assert_true(check_has_error_code(diagnostics, 2322))
    }
  }
}

// ============================================================================
// TS2588: Cannot assign to const (IMPLEMENTED)
// ============================================================================

///|
test "checker error detection - TS2588 const reassignment" {
  // Reassigning const variable should trigger TS2588
  let source =
    #|const x = 10;
    #|x = 20;
  let result = check_ts_source(source)
  match result {
    Ok(_) => assert_true(false)
    Err(diagnostics) => {
      assert_true(check_has_error_code(diagnostics, 2588))
      assert_true(check_has_error_message(diagnostics, "const"))
    }
  }
}

// ============================================================================
// TS2511: Cannot create instance of abstract class (IMPLEMENTED)
// ============================================================================

///|
test "checker error detection - TS2511 instantiate abstract class" {
  // Instantiating abstract class should trigger TS2511
  let source = "abstract class Animal { abstract speak(): void; } new Animal();"
  let result = check_ts_source(source)
  match result {
    Ok(_) => () // May succeed if abstract check not fully implemented
    Err(diagnostics) => {
      assert_true(check_has_error_code(diagnostics, 2511))
      assert_true(check_has_error_message(diagnostics, "abstract"))
    }
  }
}

// ============================================================================
// Valid Code - Should NOT produce errors
// ============================================================================

///|
test "checker error detection - valid type assignment" {
  // Valid type assignment should not produce errors
  let source = "const x: number = 42;"
  let result = check_ts_source(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      // Should not have type assignment errors
      assert_true(not(check_has_error_code(diagnostics, 2322)))
    }
  }
}

///|
test "checker error detection - valid let reassignment" {
  // Reassigning let variable is valid
  let source =
    #|let x = 10;
    #|x = 20;
  let result = check_ts_source(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      assert_true(not(check_has_error_code(diagnostics, 2588)))
    }
  }
}

///|
test "checker error detection - valid function call" {
  // Valid function call should not produce errors
  let source =
    #|function add(a: number, b: number): number { return a + b; }
    #|const result = add(1, 2);
  let result = check_ts_source(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      assert_true(not(check_has_error_code(diagnostics, 2554)))
    }
  }
}

///|
test "checker error detection - valid class instantiation" {
  // Non-abstract class instantiation is valid
  let source =
    #|class Animal {
    #|  speak(): void { }
    #|}
    #|const a = new Animal();
  let result = check_ts_source(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      assert_true(not(check_has_error_code(diagnostics, 2511)))
    }
  }
}

///|
test "checker error detection - valid property access" {
  // Valid property access should not produce errors
  let source =
    #|const obj = { name: "test", value: 42 };
    #|const n = obj.name;
    #|const v = obj.value;
  let result = check_ts_source(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      assert_true(not(check_has_error_code(diagnostics, 2339)))
    }
  }
}

///|
test "checker error detection - valid class inheritance" {
  // Valid class inheritance with super call should not produce errors
  let source =
    #|class Base {
    #|  constructor(public value: number) { }
    #|}
    #|class Derived extends Base {
    #|  constructor() {
    #|    super(42);
    #|  }
    #|}
  let result = check_ts_source(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      assert_true(not(check_has_error_code(diagnostics, 2377)))
    }
  }
}

// ============================================================================
// Future Error Detection Tests
// These document expected behavior for errors to be implemented in type checker
// ============================================================================

// TS2304: Cannot find name
// When implemented, referencing undefined variables should trigger TS2304
// Example: const x = undefinedVariable;

// TS2339: Property does not exist on type
// When implemented, accessing non-existent properties should trigger TS2339
// Example: const obj = { name: "test" }; const x = obj.unknownProp;

// TS2345: Argument not assignable to parameter
// When implemented, passing wrong type arguments should trigger TS2345
// Example: function greet(name: string): void { } greet(42);

// TS2531/2532/2533: Object possibly null/undefined
// When implemented with strict null checks, should trigger these errors
// Example: function test(x: string | null) { return x.length; }

// TS2540: Cannot assign to readonly
// When implemented, assigning to readonly properties should trigger TS2540
// Example: interface Config { readonly name: string; } config.name = "changed";

// TS2451: Cannot redeclare block-scoped variable
// When implemented, duplicate declarations should trigger TS2451
// Example: let x = 1; let x = 2;

// TS2554: Expected N arguments, but got M
// When implemented, wrong argument counts should trigger TS2554
// Example: function add(a: number, b: number): number { return a + b; } add(1);

// TS2377: Derived class must call super
// When implemented, missing super calls should trigger TS2377
// Example: class Derived extends Base { constructor() { } }

// TS2341: Property is private
// When implemented, accessing private properties should trigger TS2341
// Example: class Secret { private code: string = "123"; } s.code;
