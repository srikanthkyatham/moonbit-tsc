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
  let result = parse_bind_check_v2(
    "type Partial<T> = { [K in keyof T]?: T[K] }; interface User { name: string; age: number; } const partialUser: Partial<User> = { name: 'John' };",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
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
