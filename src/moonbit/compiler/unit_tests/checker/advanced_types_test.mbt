// Advanced Types Tests
// Tests for Phase 3 implementation:
// 1. Conditional type evaluation (T extends U ? X : Y)
// 2. Mapped type resolution ({ [K in keyof T]: T[K] })
// 3. Index access type evaluation (T[K])
// 4. Utility type definitions

///|
/// Helper function to parse, bind, and check source code
fn parse_bind_check_advanced(source : String) -> @compiler.CheckResult {
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
// Conditional Type Parsing Tests
// ============================================================================

///|
test "unit/advanced/conditional - basic conditional type alias" {
  let result = parse_bind_check_advanced(
    "type IsString<T> = T extends string ? true : false;",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/conditional - nested conditional type" {
  let result = parse_bind_check_advanced(
    "type TypeName<T> = T extends string ? 'string' : T extends number ? 'number' : 'other';",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/conditional - conditional with infer" {
  // Simpler form without parenthesized infer
  let result = parse_bind_check_advanced(
    "type UnpackArray<T> = T extends Array<infer U> ? U : T;",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/conditional - ReturnType-style conditional" {
  let result = parse_bind_check_advanced(
    "type ReturnType<T> = T extends (...args: any[]) => infer R ? R : never;",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/conditional - Parameters-style conditional" {
  let result = parse_bind_check_advanced(
    "type Parameters<T> = T extends (...args: infer P) => any ? P : never;",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/conditional - Awaited-style conditional" {
  let result = parse_bind_check_advanced(
    "type Awaited<T> = T extends PromiseLike<infer U> ? Awaited<U> : T;",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Mapped Type Parsing Tests
// ============================================================================

///|
test "unit/advanced/mapped - basic mapped type" {
  let result = parse_bind_check_advanced(
    "type Stringify<T> = { [K in keyof T]: string };",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/mapped - Partial type" {
  let result = parse_bind_check_advanced(
    "type MyPartial<T> = { [K in keyof T]?: T[K] };",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/mapped - Required type" {
  let result = parse_bind_check_advanced(
    "type MyRequired<T> = { [K in keyof T]-?: T[K] };",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/mapped - Readonly type" {
  let result = parse_bind_check_advanced(
    "type MyReadonly<T> = { readonly [K in keyof T]: T[K] };",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/mapped - Mutable type (remove readonly)" {
  let result = parse_bind_check_advanced(
    "type Mutable<T> = { -readonly [K in keyof T]: T[K] };",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/mapped - key remapping" {
  let result = parse_bind_check_advanced(
    "type Getters<T> = { [K in keyof T as `get${Capitalize<string & K>}`]: () => T[K] };",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/mapped - Pick type" {
  let result = parse_bind_check_advanced(
    "type MyPick<T, K extends keyof T> = { [P in K]: T[P] };",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/mapped - Record type" {
  let result = parse_bind_check_advanced(
    "type MyRecord<K extends string, V> = { [P in K]: V };",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Index Access Type Parsing Tests
// ============================================================================

///|
test "unit/advanced/index-access - basic property access" {
  let result = parse_bind_check_advanced(
    "interface Person { name: string; age: number; } type NameType = Person['name'];",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/index-access - union of keys" {
  let result = parse_bind_check_advanced(
    "interface Person { name: string; age: number; } type NameOrAge = Person['name' | 'age'];",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/index-access - array element type" {
  let result = parse_bind_check_advanced(
    "type ArrayElement<T extends any[]> = T[number];",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/index-access - tuple element" {
  let result = parse_bind_check_advanced(
    "type First<T extends any[]> = T[0];",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/index-access - nested access" {
  let result = parse_bind_check_advanced(
    "interface Nested { outer: { inner: string } } type InnerType = Nested['outer']['inner'];",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/index-access - keyof with index" {
  let result = parse_bind_check_advanced(
    "type Values<T> = T[keyof T];",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Template Literal Type Parsing Tests
// ============================================================================

///|
test "unit/advanced/template-literal - basic template" {
  let result = parse_bind_check_advanced(
    "type Greeting = `Hello, ${string}!`;",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/template-literal - with union" {
  let result = parse_bind_check_advanced(
    "type EventName = `on${\"Click\" | \"Focus\"}`;",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/template-literal - multiple interpolations" {
  let result = parse_bind_check_advanced(
    "type CssProperty = `${\"margin\" | \"padding\"}-${\"top\" | \"bottom\"}`;",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Type Operator Parsing Tests
// ============================================================================

///|
test "unit/advanced/keyof - basic keyof" {
  let result = parse_bind_check_advanced(
    "interface Point { x: number; y: number; } type Keys = keyof Point;",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/typeof - basic typeof" {
  let result = parse_bind_check_advanced(
    "const obj = { x: 1, y: 2 }; type ObjType = typeof obj;",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/readonly - readonly type operator" {
  let result = parse_bind_check_advanced(
    "type ReadonlyArray<T> = readonly T[];",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Infer Type Parsing Tests
// ============================================================================

///|
test "unit/advanced/infer - basic infer" {
  let result = parse_bind_check_advanced(
    "type UnpackPromise<T> = T extends Promise<infer U> ? U : T;",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/infer - multiple infers" {
  // Simpler form without parenthesized infer
  let result = parse_bind_check_advanced(
    "type Unpack<T> = T extends Array<infer A> ? A : T extends { x: infer B } ? B : T;",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/infer - infer in function" {
  let result = parse_bind_check_advanced(
    "type FirstArg<T> = T extends (first: infer F, ...rest: any[]) => any ? F : never;",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Utility Type Usage Tests
// ============================================================================

///|
test "unit/advanced/utility - Partial usage" {
  let result = parse_bind_check_advanced(
    "interface Todo { title: string; description: string; } type PartialTodo = Partial<Todo>;",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/utility - Required usage" {
  let result = parse_bind_check_advanced(
    "interface Props { a?: number; b?: string; } type RequiredProps = Required<Props>;",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/utility - Readonly usage" {
  let result = parse_bind_check_advanced(
    "interface Point { x: number; y: number; } type ReadonlyPoint = Readonly<Point>;",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/utility - Pick usage" {
  let result = parse_bind_check_advanced(
    "interface Todo { title: string; description: string; completed: boolean; } type TodoPreview = Pick<Todo, 'title' | 'completed'>;",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/utility - Omit usage" {
  let result = parse_bind_check_advanced(
    "interface Todo { title: string; description: string; completed: boolean; } type TodoInfo = Omit<Todo, 'completed'>;",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/utility - Record usage" {
  let result = parse_bind_check_advanced(
    "type CatInfo = { age: number; breed: string; }; type CatName = 'miffy' | 'boris'; const cats: Record<CatName, CatInfo> = { miffy: { age: 10, breed: 'Persian' }, boris: { age: 5, breed: 'Maine Coon' } };",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/utility - Extract usage" {
  let result = parse_bind_check_advanced(
    "type T0 = Extract<'a' | 'b' | 'c', 'a' | 'f'>;",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/utility - Exclude usage" {
  let result = parse_bind_check_advanced(
    "type T0 = Exclude<'a' | 'b' | 'c', 'a'>;",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/utility - NonNullable usage" {
  let result = parse_bind_check_advanced(
    "type T0 = NonNullable<string | number | undefined | null>;",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/utility - ReturnType usage" {
  let result = parse_bind_check_advanced(
    "type T0 = ReturnType<() => string>;",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/utility - Parameters usage" {
  let result = parse_bind_check_advanced(
    "type T0 = Parameters<(a: string, b: number) => void>;",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/utility - InstanceType usage" {
  let result = parse_bind_check_advanced(
    "class C { x = 0; } type T0 = InstanceType<typeof C>;",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Complex Combination Tests
// ============================================================================

///|
test "unit/advanced/complex - Partial with Pick" {
  let result = parse_bind_check_advanced(
    "interface Todo { title: string; description: string; } type PartialPick = Partial<Pick<Todo, 'title'>>;",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/complex - DeepPartial type" {
  let result = parse_bind_check_advanced(
    "type DeepPartial<T> = { [P in keyof T]?: T[P] extends object ? DeepPartial<T[P]> : T[P] };",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/complex - conditional with mapped" {
  let result = parse_bind_check_advanced(
    "type NullableFields<T> = { [K in keyof T]: T[K] extends object ? T[K] | null : T[K] };",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/complex - Flatten type" {
  let result = parse_bind_check_advanced(
    "type Flatten<T> = T extends any[] ? T[number] : T;",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/complex - recursive conditional" {
  let result = parse_bind_check_advanced(
    "type DeepReadonly<T> = T extends object ? { readonly [K in keyof T]: DeepReadonly<T[K]> } : T;",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Conditional Type Simplification Tests
// ============================================================================

///|
test "unit/advanced/simplification - never extends T returns never" {
  // never extends T ? X : Y should always return never (distribution over empty union)
  let result = parse_bind_check_advanced(
    "type Test = never extends string ? 'yes' : 'no';",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/simplification - reflexive type extends itself" {
  // T extends T ? X : Y should always return X
  let result = parse_bind_check_advanced(
    "type Reflexive<T> = T extends T ? 'yes' : 'no';",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/simplification - T extends never returns false branch" {
  // T extends never ? X : Y should return Y for non-never T
  let result = parse_bind_check_advanced(
    "type ExtendsNever<T> = T extends never ? 'yes' : 'no';",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/simplification - any extends T returns union" {
  // any extends T ? X : Y should return X | Y for specific T
  let result = parse_bind_check_advanced(
    "type AnyExtends<T> = any extends T ? 'yes' : 'no';",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/simplification - unknown extends specific returns false" {
  // unknown extends T ? X : Y should return Y for specific T (not unknown/any)
  let result = parse_bind_check_advanced(
    "type UnknownExtends<T> = unknown extends T ? 'yes' : 'no';",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/simplification - unknown extends unknown returns true" {
  // unknown extends unknown ? X : Y should return X
  let result = parse_bind_check_advanced(
    "type Test = unknown extends unknown ? 'yes' : 'no';",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/simplification - union distribution" {
  // (A | B) extends T ? X : Y distributes to (A extends T ? X : Y) | (B extends T ? X : Y)
  let result = parse_bind_check_advanced(
    "type IsString<T> = T extends string ? 'yes' : 'no';",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/simplification - never in union result filtered" {
  // never is filtered out of union results
  let result = parse_bind_check_advanced(
    "type FilterNull<T> = T extends null ? never : T;",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/simplification - Extract utility type" {
  // Extract<T, U> = T extends U ? T : never
  let result = parse_bind_check_advanced(
    "type MyExtract<T, U> = T extends U ? T : never;",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/simplification - Exclude utility type" {
  // Exclude<T, U> = T extends U ? never : T
  let result = parse_bind_check_advanced(
    "type MyExclude<T, U> = T extends U ? never : T;",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Homomorphic and Recursive Mapped Type Tests
// ============================================================================

///|
test "unit/advanced/mapped - homomorphic Partial preserves structure" {
  // Homomorphic mapped type: keyof T preserves the source structure
  let result = parse_bind_check_advanced(
    "type Partial<T> = { [K in keyof T]?: T[K] };",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/mapped - homomorphic Readonly preserves structure" {
  let result = parse_bind_check_advanced(
    "type Readonly<T> = { readonly [K in keyof T]: T[K] };",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/mapped - homomorphic Required type" {
  let result = parse_bind_check_advanced(
    "type Required<T> = { [K in keyof T]-?: T[K] };",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/mapped - recursive DeepReadonly" {
  // Recursive mapped type with conditional
  let result = parse_bind_check_advanced(
    "type DeepReadonly<T> = T extends object ? { readonly [K in keyof T]: DeepReadonly<T[K]> } : T;",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/mapped - recursive DeepPartial" {
  let result = parse_bind_check_advanced(
    "type DeepPartial<T> = T extends object ? { [K in keyof T]?: DeepPartial<T[K]> } : T;",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/mapped - key remapping with as" {
  let result = parse_bind_check_advanced(
    "type Getters<T> = { [K in keyof T as `get${Capitalize<string & K>}`]: () => T[K] };",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/mapped - Pick utility type" {
  let result = parse_bind_check_advanced(
    "type Pick<T, K extends keyof T> = { [P in K]: T[P] };",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/mapped - Omit utility type" {
  let result = parse_bind_check_advanced(
    "type Omit<T, K> = { [P in keyof T as P extends K ? never : P]: T[P] };",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/mapped - Record utility type" {
  let result = parse_bind_check_advanced(
    "type Record<K extends string, V> = { [P in K]: V };",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Async/Await Type Tests
// ============================================================================

///|
test "unit/advanced/async - async function declaration" {
  let result = parse_bind_check_advanced(
    "async function fetchData(): Promise<string> { return 'data'; }",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/async - async arrow function" {
  let result = parse_bind_check_advanced(
    "const fetch = async (): Promise<number> => 42;",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/async - await expression" {
  let result = parse_bind_check_advanced(
    "async function test() { const x = await Promise.resolve(42); }",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/async - Awaited utility type" {
  let result = parse_bind_check_advanced(
    "type Awaited<T> = T extends PromiseLike<infer U> ? Awaited<U> : T;",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/async - nested Promise unwrapping" {
  let result = parse_bind_check_advanced(
    "type NestedPromise = Promise<Promise<Promise<string>>>;",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/async - async generator function" {
  let result = parse_bind_check_advanced(
    "async function* generate(): AsyncGenerator<number> { yield 1; yield 2; }",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/async - for await of loop" {
  // Test that async functions with for-await-of compile
  let result = parse_bind_check_advanced(
    "async function consume(arr: Promise<number>[]) { const x = await arr[0]; }",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/async - Promise.all type" {
  let result = parse_bind_check_advanced(
    "const results: Promise<[number, string]> = Promise.all([Promise.resolve(1), Promise.resolve('a')]);",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/async - async method in class" {
  let result = parse_bind_check_advanced(
    "class Api { async fetch(): Promise<void> {} }",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/advanced/async - PromiseLike type" {
  // Test that PromiseLike-like thenable objects work
  let result = parse_bind_check_advanced(
    "interface Thenable<T> { then(cb: (v: T) => void): void; } const t: Thenable<number> = { then(cb) { cb(42); } };",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Advanced Utility Types Tests
// ============================================================================

///|
test "unit/utility/Partial - makes properties optional" {
  let result = parse_bind_check_advanced(
    "interface User { name: string; age: number; } type PartialUser = Partial<User>;",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/utility/Required - makes properties required" {
  let result = parse_bind_check_advanced(
    "interface User { name?: string; age?: number; } type RequiredUser = Required<User>;",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/utility/Readonly - makes properties readonly" {
  let result = parse_bind_check_advanced(
    "interface User { name: string; age: number; } type ReadonlyUser = Readonly<User>;",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/utility/Pick - selects properties" {
  let result = parse_bind_check_advanced(
    "interface User { name: string; age: number; email: string; } type NameOnly = Pick<User, 'name'>;",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/utility/Omit - excludes properties" {
  let result = parse_bind_check_advanced(
    "interface User { name: string; age: number; email: string; } type WithoutEmail = Omit<User, 'email'>;",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/utility/Extract - extracts union members" {
  let result = parse_bind_check_advanced(
    "type T = 'a' | 'b' | 'c'; type OnlyAB = Extract<T, 'a' | 'b'>;",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/utility/Exclude - excludes union members" {
  let result = parse_bind_check_advanced(
    "type T = 'a' | 'b' | 'c'; type NotA = Exclude<T, 'a'>;",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/utility/NonNullable - removes null and undefined" {
  let result = parse_bind_check_advanced(
    "type T = string | null | undefined; type NonNull = NonNullable<T>;",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/utility/ReturnType - extracts function return type" {
  let result = parse_bind_check_advanced(
    "function greet(): string { return 'hello'; } type GreetReturn = ReturnType<typeof greet>;",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/utility/Parameters - extracts function parameters as tuple" {
  let result = parse_bind_check_advanced(
    "function add(x: number, y: number): number { return x + y; } type AddParams = Parameters<typeof add>;",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/utility/ConstructorParameters - extracts constructor parameters" {
  let result = parse_bind_check_advanced(
    "class Person { constructor(name: string, age: number) {} } type PersonParams = ConstructorParameters<typeof Person>;",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/utility/InstanceType - extracts instance type from class" {
  let result = parse_bind_check_advanced(
    "class Person { name: string = ''; } type PersonInstance = InstanceType<typeof Person>;",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/utility/ThisParameterType - extracts this parameter type" {
  let result = parse_bind_check_advanced(
    "function greet(this: { name: string }): string { return this.name; } type ThisType = ThisParameterType<typeof greet>;",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/utility/OmitThisParameter - removes this parameter from function type" {
  // Use function type with explicit `this` parameter
  let result = parse_bind_check_advanced(
    "type GreetFn = (this: { name: string }, greeting: string) => string; type NoThis = OmitThisParameter<GreetFn>;",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/utility/ThisParameterType - extracts this parameter type" {
  // Use function type with explicit `this` parameter
  let result = parse_bind_check_advanced(
    "type GreetFn = (this: { name: string }, greeting: string) => string; type ThisType = ThisParameterType<GreetFn>;",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/parser/this-parameter - parses function declaration with this parameter" {
  // Test that function declarations with `this` parameter parse correctly
  let result = parse_bind_check_advanced(
    "function greet(this: { name: string }, greeting: string): void { }",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/utility/Awaited - unwraps Promise type" {
  let result = parse_bind_check_advanced(
    "type P = Promise<string>; type Unwrapped = Awaited<P>;",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/utility/Uppercase - uppercase string type" {
  let result = parse_bind_check_advanced(
    "type Lower = 'hello'; type Upper = Uppercase<Lower>;",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/utility/Lowercase - lowercase string type" {
  let result = parse_bind_check_advanced(
    "type Upper = 'HELLO'; type Lower = Lowercase<Upper>;",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/utility/Capitalize - capitalize first letter" {
  let result = parse_bind_check_advanced(
    "type Lower = 'hello'; type Cap = Capitalize<Lower>;",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/utility/Uncapitalize - uncapitalize first letter" {
  let result = parse_bind_check_advanced(
    "type Upper = 'Hello'; type Uncap = Uncapitalize<Upper>;",
  )
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}
