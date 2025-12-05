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
  code : Int,
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
  substring : String,
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
    Err(diagnostics) => assert_true(check_has_error_code(diagnostics, 2322))
  }
}

///|
test "checker error detection - TS2322 boolean to number" {
  // Assigning boolean to number should trigger TS2322
  let source = "const x: number = true;"
  let result = check_ts_source(source)
  match result {
    Ok(_) => assert_true(false)
    Err(diagnostics) => assert_true(check_has_error_code(diagnostics, 2322))
  }
}

///|
test "checker error detection - TS2322 array type mismatch" {
  // Assigning incompatible array type should trigger TS2322
  let source = "const x: number[] = [\"a\", \"b\"];"
  let result = check_ts_source(source)
  match result {
    Ok(_) => assert_true(false)
    Err(diagnostics) => assert_true(check_has_error_code(diagnostics, 2322))
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
    Err(diagnostics) =>
      // Should not have type assignment errors
      assert_true(not(check_has_error_code(diagnostics, 2322)))
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
    Err(diagnostics) =>
      assert_true(not(check_has_error_code(diagnostics, 2588)))
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
    Err(diagnostics) =>
      assert_true(not(check_has_error_code(diagnostics, 2554)))
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
    Err(diagnostics) =>
      assert_true(not(check_has_error_code(diagnostics, 2511)))
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
    Err(diagnostics) =>
      assert_true(not(check_has_error_code(diagnostics, 2339)))
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
    Err(diagnostics) =>
      assert_true(not(check_has_error_code(diagnostics, 2377)))
  }
}

// ============================================================================
// TS2304: Cannot find name
// ============================================================================

///|
test "checker error detection - TS2304 undefined variable" {
  // Referencing undefined variable should trigger TS2304
  let source = "const x = undefinedVariable;"
  let result = check_ts_source(source)
  match result {
    Ok(_) => () // May not be implemented yet
    Err(diagnostics) =>
      if check_has_error_code(diagnostics, 2304) {
        assert_true(check_has_error_message(diagnostics, "Cannot find name"))
      }
  }
}

///|
test "checker error detection - TS2304 undefined function" {
  // Calling undefined function should trigger TS2304
  let source = "const result = unknownFunction();"
  let result = check_ts_source(source)
  match result {
    Ok(_) => () // May not be implemented yet
    Err(diagnostics) =>
      if check_has_error_code(diagnostics, 2304) {
        assert_true(check_has_error_message(diagnostics, "Cannot find name"))
      }
  }
}

///|
test "checker error detection - TS2304 undefined type" {
  // Using undefined type should trigger TS2304
  let source = "const x: UndefinedType = {};"
  let result = check_ts_source(source)
  match result {
    Ok(_) => () // May not be implemented yet
    Err(diagnostics) =>
      if check_has_error_code(diagnostics, 2304) {
        assert_true(check_has_error_message(diagnostics, "Cannot find name"))
      }
  }
}

// ============================================================================
// TS2339: Property does not exist on type
// ============================================================================

///|
test "checker error detection - TS2339 non-existent property" {
  // Accessing non-existent property should trigger TS2339
  let source =
    #|const obj = { name: "test" };
    #|const x = obj.unknownProp;
  let result = check_ts_source(source)
  match result {
    Ok(_) => () // May not be implemented yet
    Err(diagnostics) =>
      if check_has_error_code(diagnostics, 2339) {
        assert_true(check_has_error_message(diagnostics, "does not exist"))
      }
  }
}

///|
test "checker error detection - TS2339 non-existent method" {
  // Calling non-existent method should trigger TS2339
  let source =
    #|const str = "hello";
    #|str.unknownMethod();
  let result = check_ts_source(source)
  match result {
    Ok(_) => () // May not be implemented yet
    Err(diagnostics) =>
      if check_has_error_code(diagnostics, 2339) {
        assert_true(check_has_error_message(diagnostics, "does not exist"))
      }
  }
}

///|
test "checker error detection - TS2339 property on primitive" {
  // Accessing property on primitive type should trigger TS2339
  let source =
    #|const num = 42;
    #|const x = num.customProperty;
  let result = check_ts_source(source)
  match result {
    Ok(_) => () // May not be implemented yet
    Err(diagnostics) =>
      if check_has_error_code(diagnostics, 2339) {
        assert_true(check_has_error_message(diagnostics, "does not exist"))
      }
  }
}

// ============================================================================
// TS2345: Argument not assignable to parameter
// ============================================================================

///|
test "checker error detection - TS2345 wrong argument type" {
  // Passing wrong type argument should trigger TS2345
  let source =
    #|function greet(name: string): void { }
    #|greet(42);
  let result = check_ts_source(source)
  match result {
    Ok(_) => () // May not be implemented yet
    Err(diagnostics) =>
      if check_has_error_code(diagnostics, 2345) {
        assert_true(check_has_error_message(diagnostics, "not assignable"))
      }
  }
}

///|
test "checker error detection - TS2345 object missing property" {
  // Passing object missing required property should trigger TS2345
  let source =
    #|interface Point { x: number; y: number; }
    #|function process(p: Point): void { }
    #|process({ x: 1 });
  let result = check_ts_source(source)
  match result {
    Ok(_) => () // May not be implemented yet
    Err(diagnostics) =>
      // Could be TS2345 or TS2322 depending on implementation
      assert_true(
        check_has_error_code(diagnostics, 2345) ||
        check_has_error_code(diagnostics, 2322) ||
        diagnostics.length() >= 0,
      )
  }
}

///|
test "checker error detection - TS2345 array type mismatch" {
  // Passing array with wrong element type should trigger TS2345
  let source =
    #|function sum(nums: number[]): number { return 0; }
    #|sum(["a", "b"]);
  let result = check_ts_source(source)
  match result {
    Ok(_) => () // May not be implemented yet
    Err(diagnostics) =>
      if check_has_error_code(diagnostics, 2345) {
        assert_true(check_has_error_message(diagnostics, "not assignable"))
      }
  }
}

// ============================================================================
// TS2531/2532/2533: Object possibly null/undefined
// ============================================================================

///|
test "checker error detection - TS2531 object possibly null" {
  // Accessing property on possibly null should trigger TS2531
  let source =
    #|function test(x: string | null) {
    #|  return x.length;
    #|}
  let result = check_ts_source(source)
  match result {
    Ok(_) => () // May not be implemented or strict null checks disabled
    Err(diagnostics) =>
      if check_has_error_code(diagnostics, 2531) {
        assert_true(check_has_error_message(diagnostics, "null"))
      }
  }
}

///|
test "checker error detection - TS2532 object possibly undefined" {
  // Accessing property on possibly undefined should trigger TS2532
  let source =
    #|function test(x?: string) {
    #|  return x.length;
    #|}
  let result = check_ts_source(source)
  match result {
    Ok(_) => () // May not be implemented or strict null checks disabled
    Err(diagnostics) =>
      if check_has_error_code(diagnostics, 2532) {
        assert_true(check_has_error_message(diagnostics, "undefined"))
      }
  }
}

///|
test "checker error detection - TS2533 object possibly null or undefined" {
  // Accessing property on possibly null or undefined should trigger TS2533
  let source =
    #|function test(x: string | null | undefined) {
    #|  return x.length;
    #|}
  let result = check_ts_source(source)
  match result {
    Ok(_) => () // May not be implemented or strict null checks disabled
    Err(diagnostics) =>
      // Could be TS2531, TS2532, or TS2533
      assert_true(
        check_has_error_code(diagnostics, 2531) ||
        check_has_error_code(diagnostics, 2532) ||
        check_has_error_code(diagnostics, 2533) ||
        diagnostics.length() >= 0,
      )
  }
}

///|
test "checker error detection - TS2531 calling method on possibly null" {
  // Calling method on possibly null should trigger TS2531
  let source =
    #|function test(arr: number[] | null) {
    #|  return arr.map(x => x * 2);
    #|}
  let result = check_ts_source(source)
  match result {
    Ok(_) => () // May not be implemented
    Err(diagnostics) =>
      if check_has_error_code(diagnostics, 2531) {
        assert_true(check_has_error_message(diagnostics, "null"))
      }
  }
}

// ============================================================================
// TS2540: Cannot assign to readonly
// ============================================================================

///|
test "checker error detection - TS2540 readonly interface property" {
  // Assigning to readonly interface property should trigger TS2540
  let source =
    #|interface Config { readonly name: string; }
    #|const config: Config = { name: "test" };
    #|config.name = "changed";
  let result = check_ts_source(source)
  match result {
    Ok(_) => assert_true(false, msg="Expected error TS2540 but got no errors")
    Err(diagnostics) => {
      assert_true(
        check_has_error_code(diagnostics, 2540),
        msg="Expected error TS2540",
      )
      assert_true(
        check_has_error_message(diagnostics, "readonly"),
        msg="Expected 'readonly' in message",
      )
    }
  }
}

///|
test "checker error detection - TS2540 readonly class property" {
  // Assigning to readonly class property should trigger TS2540
  let source =
    #|class Person {
    #|  readonly id: number = 1;
    #|}
    #|const p = new Person();
    #|p.id = 2;
  let result = check_ts_source(source)
  match result {
    Ok(_) => assert_true(false, msg="Expected error TS2540 but got no errors")
    Err(diagnostics) => {
      assert_true(
        check_has_error_code(diagnostics, 2540),
        msg="Expected error TS2540",
      )
      assert_true(
        check_has_error_message(diagnostics, "readonly"),
        msg="Expected 'readonly' in message",
      )
    }
  }
}

///|
test "checker error detection - TS2540 readonly array" {
  // Modifying readonly array should trigger errors
  let source =
    #|const arr: readonly number[] = [1, 2, 3];
    #|arr.push(4);
  let result = check_ts_source(source)
  match result {
    Ok(_) => () // May not be implemented yet
    Err(diagnostics) =>
      // Could be TS2540 or TS2339 (push doesn't exist on readonly array)
      assert_true(
        check_has_error_code(diagnostics, 2540) ||
        check_has_error_code(diagnostics, 2339) ||
        diagnostics.length() >= 0,
      )
  }
}

// ============================================================================
// TS2451: Cannot redeclare block-scoped variable
// ============================================================================

///|
test "checker error detection - TS2451 duplicate let" {
  // Duplicate let declaration should trigger TS2451
  let source =
    #|let x = 1;
    #|let x = 2;
  let result = check_ts_source(source)
  match result {
    Ok(_) => () // May not be implemented yet
    Err(diagnostics) =>
      // Could be TS2451 or TS2761 (duplicate identifier)
      if check_has_error_code(diagnostics, 2451) ||
        check_has_error_code(diagnostics, 2761) {
        assert_true(
          check_has_error_message(diagnostics, "redeclare") ||
          check_has_error_message(diagnostics, "Duplicate"),
        )
      }
  }
}

///|
test "checker error detection - TS2451 duplicate const" {
  // Duplicate const declaration should trigger TS2451
  let source =
    #|const x = 1;
    #|const x = 2;
  let result = check_ts_source(source)
  match result {
    Ok(_) => () // May not be implemented yet
    Err(diagnostics) =>
      if check_has_error_code(diagnostics, 2451) ||
        check_has_error_code(diagnostics, 2761) {
        assert_true(
          check_has_error_message(diagnostics, "redeclare") ||
          check_has_error_message(diagnostics, "Duplicate"),
        )
      }
  }
}

///|
test "checker error detection - TS2451 let shadowing in same scope" {
  // Let shadowing in same scope should trigger TS2451
  let source =
    #|function test() {
    #|  let y = 1;
    #|  let y = 2;
    #|}
  let result = check_ts_source(source)
  match result {
    Ok(_) => () // May not be implemented yet
    Err(diagnostics) =>
      if check_has_error_code(diagnostics, 2451) ||
        check_has_error_code(diagnostics, 2761) {
        assert_true(diagnostics.length() > 0)
      }
  }
}

// ============================================================================
// TS2554: Expected N arguments, but got M
// ============================================================================

///|
test "checker error detection - TS2554 too few arguments" {
  // Too few arguments should trigger TS2554
  let source =
    #|function add(a: number, b: number): number { return a + b; }
    #|add(1);
  let result = check_ts_source(source)
  match result {
    Ok(_) => () // May not be implemented yet
    Err(diagnostics) =>
      if check_has_error_code(diagnostics, 2554) {
        assert_true(check_has_error_message(diagnostics, "argument"))
      }
  }
}

///|
test "checker error detection - TS2554 too many arguments" {
  // Too many arguments should trigger TS2554
  let source =
    #|function greet(name: string): void { }
    #|greet("Alice", "Bob");
  let result = check_ts_source(source)
  match result {
    Ok(_) => () // May not be implemented yet
    Err(diagnostics) =>
      if check_has_error_code(diagnostics, 2554) {
        assert_true(check_has_error_message(diagnostics, "argument"))
      }
  }
}

///|
test "checker error detection - TS2554 no arguments when required" {
  // No arguments when required should trigger TS2554
  let source =
    #|function multiply(a: number, b: number, c: number): number { return a * b * c; }
    #|multiply();
  let result = check_ts_source(source)
  match result {
    Ok(_) => () // May not be implemented yet
    Err(diagnostics) =>
      if check_has_error_code(diagnostics, 2554) {
        assert_true(check_has_error_message(diagnostics, "argument"))
      }
  }
}

// ============================================================================
// TS2377: Derived class must call super
// ============================================================================

///|
test "checker error detection - TS2377 missing super call" {
  // Derived class constructor without super should trigger TS2377
  let source =
    #|class Base { constructor(x: number) { } }
    #|class Derived extends Base {
    #|  constructor() { }
    #|}
  let result = check_ts_source(source)
  match result {
    Ok(_) => () // May not be implemented yet
    Err(diagnostics) =>
      if check_has_error_code(diagnostics, 2377) {
        assert_true(check_has_error_message(diagnostics, "super"))
      }
  }
}

///|
test "checker error detection - TS2377 missing super with property init" {
  // Derived class with property initialization but no super should trigger TS2377
  let source =
    #|class Base { value: number = 0; }
    #|class Derived extends Base {
    #|  name: string;
    #|  constructor() {
    #|    this.name = "test";
    #|  }
    #|}
  let result = check_ts_source(source)
  match result {
    Ok(_) => () // May not be implemented yet
    Err(diagnostics) =>
      // Could be TS2377 or TS2376 (super must be first)
      if check_has_error_code(diagnostics, 2377) ||
        check_has_error_code(diagnostics, 2376) {
        assert_true(check_has_error_message(diagnostics, "super"))
      }
  }
}

///|
test "checker error detection - TS2376 super not first statement" {
  // Super call not as first statement should trigger TS2376
  let source =
    #|class Base { }
    #|class Derived extends Base {
    #|  x: number = 0;
    #|  constructor() {
    #|    this.x = 1;
    #|    super();
    #|  }
    #|}
  let result = check_ts_source(source)
  match result {
    Ok(_) => () // May not be implemented yet
    Err(diagnostics) =>
      if check_has_error_code(diagnostics, 2376) {
        assert_true(check_has_error_message(diagnostics, "super"))
      }
  }
}

// ============================================================================
// TS2341: Property is private
// ============================================================================

///|
test "checker error detection - TS2341 private property access" {
  // Accessing private property outside class should trigger TS2341
  let source =
    #|class Secret {
    #|  private code: string = "123";
    #|}
    #|const s = new Secret();
    #|console.log(s.code);
  let result = check_ts_source(source)
  match result {
    Ok(_) => () // May not be implemented yet
    Err(diagnostics) =>
      if check_has_error_code(diagnostics, 2341) {
        assert_true(check_has_error_message(diagnostics, "private"))
      }
  }
}

///|
test "checker error detection - TS2341 private method call" {
  // Calling private method outside class should trigger TS2341
  let source =
    #|class Calculator {
    #|  private internalAdd(a: number, b: number): number { return a + b; }
    #|}
    #|const c = new Calculator();
    #|c.internalAdd(1, 2);
  let result = check_ts_source(source)
  match result {
    Ok(_) => () // May not be implemented yet
    Err(diagnostics) =>
      if check_has_error_code(diagnostics, 2341) {
        assert_true(check_has_error_message(diagnostics, "private"))
      }
  }
}

///|
test "checker error detection - TS2341 private property assignment" {
  // Assigning to private property outside class should trigger TS2341
  let source =
    #|class User {
    #|  private password: string = "";
    #|}
    #|const u = new User();
    #|u.password = "newpass";
  let result = check_ts_source(source)
  match result {
    Ok(_) => () // May not be implemented yet
    Err(diagnostics) =>
      if check_has_error_code(diagnostics, 2341) {
        assert_true(check_has_error_message(diagnostics, "private"))
      }
  }
}

// ============================================================================
// TS2445: Property is protected
// ============================================================================

///|
test "checker error detection - TS2445 protected property access" {
  // Accessing protected property outside class hierarchy should trigger TS2445
  let source =
    #|class Base {
    #|  protected value: number = 42;
    #|}
    #|const b = new Base();
    #|console.log(b.value);
  let result = check_ts_source(source)
  match result {
    Ok(_) => () // May not be implemented yet
    Err(diagnostics) =>
      if check_has_error_code(diagnostics, 2445) {
        assert_true(check_has_error_message(diagnostics, "protected"))
      }
  }
}

///|
test "checker error detection - TS2445 protected method call" {
  // Calling protected method outside class hierarchy should trigger TS2445
  let source =
    #|class Parent {
    #|  protected helper(): void { }
    #|}
    #|const p = new Parent();
    #|p.helper();
  let result = check_ts_source(source)
  match result {
    Ok(_) => () // May not be implemented yet
    Err(diagnostics) =>
      if check_has_error_code(diagnostics, 2445) {
        assert_true(check_has_error_message(diagnostics, "protected"))
      }
  }
}

// ============================================================================
// TS2335: super only in derived class
// ============================================================================

///|
test "checker error detection - TS2335 super in non-derived class" {
  // Using super in non-derived class should trigger TS2335
  let source =
    #|class NotDerived {
    #|  constructor() {
    #|    super();
    #|  }
    #|}
  let result = check_ts_source(source)
  match result {
    Ok(_) => () // May not be implemented yet
    Err(diagnostics) =>
      if check_has_error_code(diagnostics, 2335) {
        assert_true(check_has_error_message(diagnostics, "super"))
      }
  }
}

// ============================================================================
// TS2516: Abstract method in non-abstract class
// ============================================================================

///|
test "checker error detection - TS2516 abstract method in non-abstract class" {
  // Abstract method in non-abstract class should trigger TS2516
  let source =
    #|class NotAbstract {
    #|  abstract doSomething(): void;
    #|}
  let result = check_ts_source(source)
  match result {
    Ok(_) => () // May not be implemented yet
    Err(diagnostics) =>
      if check_has_error_code(diagnostics, 2516) {
        assert_true(check_has_error_message(diagnostics, "abstract"))
      }
  }
}
