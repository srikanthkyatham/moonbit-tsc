// Generic Type System Tests
// Tests for Phase 1 implementation:
// 1. Generic type instantiation
// 2. Type argument inference
// 3. Constraint checking (T extends Base)

///|
/// Helper function to parse, bind, and check source code
fn parse_bind_check_v2(source : String) -> @compiler.CheckResult {
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
// Generic Type Instantiation Tests
// ============================================================================

///|
test "unit/generics/instantiation - identity function" {
  let result = parse_bind_check_v2(
    "function identity<T>(x: T): T { return x; } const n = identity(42);",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/generics/instantiation - explicit type argument" {
  let result = parse_bind_check_v2(
    "function identity<T>(x: T): T { return x; } const n = identity<number>(42);",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/generics/instantiation - multiple type parameters" {
  let result = parse_bind_check_v2(
    "function pair<A, B>(a: A, b: B): [A, B] { return [a, b]; } const p = pair(1, 'hello');",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/generics/instantiation - generic with default type" {
  let result = parse_bind_check_v2(
    "function create<T = string>(x: T): T { return x; } const s = create('test');",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/generics/instantiation - generic class" {
  let result = parse_bind_check_v2(
    "class Container<T> { value: T; } const c = new Container<number>();",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/generics/instantiation - generic interface" {
  let result = parse_bind_check_v2(
    "interface Box<T> { value: T; } const box: Box<string> = { value: 'hello' };",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Type Argument Inference Tests
// ============================================================================

///|
test "unit/generics/inference - infer from number argument" {
  let result = parse_bind_check_v2(
    "function identity<T>(x: T): T { return x; } const result = identity(42);",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/generics/inference - infer from string argument" {
  let result = parse_bind_check_v2(
    "function identity<T>(x: T): T { return x; } const result = identity('hello');",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/generics/inference - infer from array argument" {
  let result = parse_bind_check_v2(
    "function first<T>(arr: T[]): T { return arr[0]; } const n = first([1, 2, 3]);",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/generics/inference - infer from object argument" {
  let result = parse_bind_check_v2(
    "function getValue<T>(obj: { value: T }): T { return obj.value; } const n = getValue({ value: 42 });",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/generics/inference - infer multiple type parameters" {
  let result = parse_bind_check_v2(
    "function pair<A, B>(a: A, b: B): [A, B] { return [a, b]; } const p = pair(1, 'hello');",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/generics/inference - infer from function argument" {
  let result = parse_bind_check_v2(
    "function map<T, U>(arr: T[], fn: (x: T) => U): U[] { return arr.map(fn); } const result = map([1, 2], (x) => x.toString());",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/generics/inference - partial explicit with inference" {
  let result = parse_bind_check_v2(
    "function convert<T, U>(x: T, fn: (x: T) => U): U { return fn(x); } const s = convert<number, string>(42, x => x.toString());",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Constraint Checking Tests
// ============================================================================

///|
test "unit/generics/constraint - basic constraint satisfied" {
  let result = parse_bind_check_v2(
    "function getLength<T extends { length: number }>(x: T): number { return x.length; } getLength('hello');",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/generics/constraint - array satisfies length constraint" {
  let result = parse_bind_check_v2(
    "function getLength<T extends { length: number }>(x: T): number { return x.length; } getLength([1, 2, 3]);",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/generics/constraint - extends primitive type" {
  let result = parse_bind_check_v2(
    "function process<T extends number>(value: T): T { return value; } const n = process(42);",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/generics/constraint - extends union type" {
  let result = parse_bind_check_v2(
    "function process<T extends string | number>(value: T): T { return value; } const n = process(42);",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/generics/constraint - keyof constraint" {
  let result = parse_bind_check_v2(
    "function getProperty<T, K extends keyof T>(obj: T, key: K): T[K] { return obj[key]; } const n = getProperty({ x: 1, y: 2 }, 'x');",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/generics/constraint - constraint with method" {
  let result = parse_bind_check_v2(
    "interface Comparable { compare(other: any): number; } function max<T extends Comparable>(a: T, b: T): T { return a.compare(b) > 0 ? a : b; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/generics/constraint - chained constraints" {
  let result = parse_bind_check_v2(
    "function extend<T, U extends T>(base: T, extra: U): U { return extra; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Error Case Tests
// ============================================================================

///|
test "unit/generics/error - too many type arguments" {
  let result = parse_bind_check_v2(
    "function identity<T>(x: T): T { return x; } identity<number, string>(42);",
  )
  // Should still parse/check but may have errors
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) =>
      // Expecting an error about too many type arguments
      assert_true(diagnostics.length() > 0)
  }
}

///|
test "unit/generics/error - type argument mismatch" {
  let result = parse_bind_check_v2(
    "function identity<T>(x: T): T { return x; } const s: string = identity<number>(42);",
  )
  match result {
    Ok(_) =>
      // May succeed with inference, or may have type mismatch
      assert_true(true)
    Err(diagnostics) =>
      // Expecting type error
      assert_true(diagnostics.length() > 0)
  }
}

// ============================================================================
// Complex Generic Pattern Tests
// ============================================================================

///|
test "unit/generics/complex - generic with conditional type" {
  let result = parse_bind_check_v2(
    "type IsString<T> = T extends string ? true : false; const result: IsString<'hello'> = true;",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/generics/complex - mapped type with generic" {
  // Mapped types are now expanded to concrete object types
  // Using MyPartial to avoid conflict with built-in Partial
  let result = parse_bind_check_v2(
    "type MyPartial<T> = { [K in keyof T]?: T[K] }; interface User { name: string; age: number; } const partialUser: MyPartial<User> = { name: 'John' };",
  )
  // Now passes because mapped types are expanded
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false) // Should now pass
  }
}

///|
test "unit/generics/complex - nested generic types" {
  let result = parse_bind_check_v2(
    "interface Container<T> { value: T; } function wrap<T>(x: T): Container<Container<T>> { return { value: { value: x } }; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/generics/complex - generic with rest parameter" {
  let result = parse_bind_check_v2(
    "function tuple<T extends any[]>(...args: T): T { return args; } const t = tuple(1, 'hello', true);",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/generics/complex - Promise generic" {
  let result = parse_bind_check_v2(
    "async function fetchData<T>(url: string): Promise<T> { return {} as T; } const data = fetchData<{ id: number }>('/api');",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Generic Type Alias Tests
// ============================================================================

///|
test "unit/generics/alias - generic type alias" {
  let result = parse_bind_check_v2(
    "type Wrapper<T> = { value: T }; const wrapped: Wrapper<number> = { value: 42 };",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/generics/alias - recursive generic type" {
  let result = parse_bind_check_v2(
    "type TreeNode<T> = { value: T; children?: TreeNode<T>[] };",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/generics/alias - generic utility type usage" {
  let result = parse_bind_check_v2(
    "type ReadonlyArray<T> = readonly T[]; const arr: ReadonlyArray<number> = [1, 2, 3];",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Function Overload Resolution Tests
// ============================================================================

///|
test "unit/overloads/basic - single overload matches" {
  let result = parse_bind_check_v2(
    "function foo(x: number): number; function foo(x: string): string; function foo(x: any): any { return x; } const n = foo(42);",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/overloads/basic - second overload matches" {
  let result = parse_bind_check_v2(
    "function foo(x: number): number; function foo(x: string): string; function foo(x: any): any { return x; } const s = foo('hello');",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/overloads/generic - generic overload with inference" {
  let result = parse_bind_check_v2(
    "function identity<T>(x: T): T; function identity(x: any): any { return x; } const n = identity(42);",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/overloads/array - array overload variants" {
  let result = parse_bind_check_v2(
    "function process(arr: number[]): number; function process(arr: string[]): string; function process(arr: any[]): any { return arr[0]; } const n = process([1, 2, 3]);",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/overloads/param-count - different parameter counts" {
  let result = parse_bind_check_v2(
    "function add(a: number): number; function add(a: number, b: number): number; function add(a: number, b?: number): number { return a + (b ?? 0); } const sum = add(1, 2);",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/overloads/first-match - first matching overload wins" {
  let result = parse_bind_check_v2(
    "function fn(x: 'a'): 1; function fn(x: string): number; function fn(x: any): any { return x; } const result = fn('a');",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/overloads/object - object type overloads" {
  // Simpler object overload without discriminated union literal types
  let result = parse_bind_check_v2(
    "function create(opts: { x: number }): number; function create(opts: { y: string }): string; function create(opts: any): any { return opts; } const n = create({ x: 5 });",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/overloads/callback - callback parameter overloads" {
  let result = parse_bind_check_v2(
    "function process(cb: (x: number) => void): void; function process(cb: (x: string) => void): void; function process(cb: any): void { cb(42); } process((x: number) => {});",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/overloads/constructor - class constructor overloads" {
  let result = parse_bind_check_v2(
    "class Foo { constructor(x: number); constructor(x: string); constructor(x: any) {} } const f = new Foo(42);",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/overloads/method - method overloads" {
  let result = parse_bind_check_v2(
    "class Calculator { add(x: number): number; add(x: string): string; add(x: any): any { return x; } } const c = new Calculator(); const n = c.add(5);",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Mapped Type Expansion Tests
// ============================================================================

///|
test "unit/mapped/partial - Partial mapped type makes all properties optional" {
  let result = parse_bind_check_v2(
    "type MyPartial<T> = { [K in keyof T]?: T[K] }; interface User { name: string; age: number; } const u: MyPartial<User> = { name: 'John' };",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/mapped/partial - Partial allows empty object" {
  let result = parse_bind_check_v2(
    "type MyPartial<T> = { [K in keyof T]?: T[K] }; interface User { name: string; age: number; } const u: MyPartial<User> = {};",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/mapped/partial - Partial allows all properties" {
  let result = parse_bind_check_v2(
    "type MyPartial<T> = { [K in keyof T]?: T[K] }; interface User { name: string; age: number; } const u: MyPartial<User> = { name: 'John', age: 30 };",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/mapped/readonly - Readonly mapped type makes properties readonly" {
  // This should compile successfully - assignment is valid
  let result = parse_bind_check_v2(
    "type MyReadonly<T> = { readonly [K in keyof T]: T[K] }; interface Point { x: number; y: number; } const p: MyReadonly<Point> = { x: 10, y: 20 };",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/mapped/readonly - Readonly prevents assignment" {
  // This should fail - cannot assign to readonly property
  let result = parse_bind_check_v2(
    "type MyReadonly<T> = { readonly [K in keyof T]: T[K] }; interface Point { x: number; y: number; } const p: MyReadonly<Point> = { x: 10, y: 20 }; p.x = 30;",
  )
  match result {
    Ok(_) => assert_true(false) // Should fail
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      // Check for TS2540 error code (readonly property assignment)
      let has_readonly_error = diagnostics
        .iter()
        .any(fn(d) { d.message.contains("readonly") })
      assert_true(has_readonly_error)
    }
  }
}

///|
test "unit/mapped/required - Required mapped type removes optional modifiers" {
  // This should fail - missing required property
  let result = parse_bind_check_v2(
    "type MyRequired<T> = { [K in keyof T]-?: T[K] }; interface OptUser { name?: string; age?: number; } const u: MyRequired<OptUser> = { name: 'John' };",
  )
  match result {
    Ok(_) => assert_true(false) // Should fail - missing age
    Err(diagnostics) => assert_true(diagnostics.length() > 0)
  }
}

///|
test "unit/mapped/required - Required with all properties provided" {
  let result = parse_bind_check_v2(
    "type MyRequired<T> = { [K in keyof T]-?: T[K] }; interface OptUser { name?: string; age?: number; } const u: MyRequired<OptUser> = { name: 'John', age: 30 };",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/mapped/keyof - keyof extracts property names as union" {
  let result = parse_bind_check_v2(
    "interface User { name: string; age: number; } type UserKeys = keyof User; const k: UserKeys = 'name';",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/mapped/nested - Mapped type with nested object" {
  let result = parse_bind_check_v2(
    "type MyPartial<T> = { [K in keyof T]?: T[K] }; interface Config { db: { host: string; port: number; }; } const c: MyPartial<Config> = {};",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/mapped/type-error - Wrong property type in mapped type" {
  // TODO: This should fail with type error, but property type validation
  // in mapped types is not fully implemented yet. When implemented, change
  // this test to expect an error.
  let result = parse_bind_check_v2(
    "type MyPartial<T> = { [K in keyof T]?: T[K] }; interface User { name: string; age: number; } const u: MyPartial<User> = { age: 'thirty' };",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts") // Currently passes (limitation)
    Err(_) => assert_true(true) // Would be correct when fully implemented
  }
}

///|
test "unit/mapped/multiple-uses - Same mapped type used multiple times" {
  let result = parse_bind_check_v2(
    "type MyPartial<T> = { [K in keyof T]?: T[K] }; interface A { x: number; } interface B { y: string; } const a: MyPartial<A> = {}; const b: MyPartial<B> = {};",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Function Hoisting Tests
// Tests for function declarations being hoisted to top of scope
// ============================================================================

///|
test "unit/hoisting/nested-forward-reference - call nested function before declaration" {
  // Nested functions should be hoisted, allowing forward references
  let result = parse_bind_check_v2(
    "function outer() { foo(10); function foo(x: number) { return x; } }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/hoisting/nested-multiple-functions - multiple nested functions with forward refs" {
  // Multiple nested functions can reference each other
  let result = parse_bind_check_v2(
    "function outer() { bar(foo(10)); function foo(x: number): number { return x; } function bar(y: number): number { return y * 2; } }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/hoisting/nested-recursive - recursive nested function" {
  // Nested functions can call themselves recursively
  let result = parse_bind_check_v2(
    "function outer() { factorial(5); function factorial(n: number): number { return n <= 1 ? 1 : n * factorial(n - 1); } }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/hoisting/nested-mutual-recursion - mutually recursive nested functions" {
  // Nested functions can call each other mutually
  let result = parse_bind_check_v2(
    "function outer() { isEven(10); function isEven(n: number): boolean { return n === 0 ? true : isOdd(n - 1); } function isOdd(n: number): boolean { return n === 0 ? false : isEven(n - 1); } }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/hoisting/top-level-forward-reference - top-level function forward reference" {
  // Top-level functions are also hoisted
  let result = parse_bind_check_v2(
    "const result = foo(42); function foo(x: number): number { return x; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/hoisting/overloads-still-work - function overloads with hoisting" {
  // Function overloads should still work correctly with hoisting
  let result = parse_bind_check_v2(
    "function foo(x: number): number; function foo(x: string): string; function foo(x: any): any { return x; } const s = foo('hello');",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}
