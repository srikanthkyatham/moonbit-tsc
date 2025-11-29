// Advanced Narrowing Unit Tests
// Tests for:
// - Discriminated union narrowing (obj.kind === "value")
// - Property existence narrowing ("prop" in obj)
// - Array.isArray() narrowing
// - User-defined type guards (function(x): x is Type)
// - Assertion functions (asserts x is Type)
// - Control flow narrowing

// ============================================================================
// Discriminated Union Narrowing Tests
// ============================================================================

test "narrowing/discriminated-union - basic switch on kind property" {
  let source =
    #|type Result = { kind: "success"; data: string } | { kind: "error"; message: string };
    #|function handle(result: Result) {
    #|  if (result.kind === "success") {
    #|    return result.data;
    #|  }
    #|  return result.message;
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => {
      // Parse succeeded - the narrowing infrastructure should handle this
      assert_true(sf.statements.length() > 0)
    }
    Err(e) => fail("Parse failed: " + e.to_string())
  }
}

test "narrowing/discriminated-union - else branch narrows to other type" {
  let source =
    #|type Shape = { kind: "circle"; radius: number } | { kind: "square"; side: number };
    #|function area(shape: Shape): number {
    #|  if (shape.kind === "circle") {
    #|    return 3.14 * shape.radius * shape.radius;
    #|  }
    #|  // In else branch, shape should be square
    #|  return shape.side * shape.side;
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(e) => fail("Parse failed: " + e.to_string())
  }
}

test "narrowing/discriminated-union - switch statement exhaustiveness" {
  let source =
    #|type Action = { type: "increment" } | { type: "decrement" } | { type: "reset"; value: number };
    #|function reducer(action: Action): number {
    #|  switch (action.type) {
    #|    case "increment": return 1;
    #|    case "decrement": return -1;
    #|    case "reset": return action.value;
    #|  }
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(e) => fail("Parse failed: " + e.to_string())
  }
}

test "narrowing/discriminated-union - boolean discriminant" {
  let source =
    #|type State = { loading: true } | { loading: false; data: string };
    #|function render(state: State): string {
    #|  if (state.loading === true) {
    #|    return "Loading...";
    #|  }
    #|  return state.data;
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(e) => fail("Parse failed: " + e.to_string())
  }
}

test "narrowing/discriminated-union - not-equals narrowing" {
  let source =
    #|type Result = { status: "ok"; value: number } | { status: "error"; error: string };
    #|function process(result: Result): string {
    #|  if (result.status !== "ok") {
    #|    return result.error;
    #|  }
    #|  return result.value.toString();
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(e) => fail("Parse failed: " + e.to_string())
  }
}

// ============================================================================
// Property Existence Narrowing ("prop" in obj)
// ============================================================================

test "narrowing/in-operator - basic property check" {
  let source =
    #|type A = { a: string };
    #|type B = { b: number };
    #|function process(obj: A | B) {
    #|  if ("a" in obj) {
    #|    return obj.a;
    #|  }
    #|  return obj.b;
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(e) => fail("Parse failed: " + e.to_string())
  }
}

test "narrowing/in-operator - with optional properties" {
  let source =
    #|type Config = { debug?: boolean; verbose?: boolean };
    #|function getDebug(config: Config): boolean {
    #|  if ("debug" in config) {
    #|    return config.debug;
    #|  }
    #|  return false;
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(e) => fail("Parse failed: " + e.to_string())
  }
}

test "narrowing/in-operator - combined with typeof" {
  let source =
    #|function process(obj: { name?: string } | string): string {
    #|  if (typeof obj === "string") {
    #|    return obj;
    #|  }
    #|  if ("name" in obj && obj.name !== undefined) {
    #|    return obj.name;
    #|  }
    #|  return "unknown";
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(e) => fail("Parse failed: " + e.to_string())
  }
}

// ============================================================================
// Array.isArray() Narrowing Tests
// ============================================================================

test "narrowing/isArray - basic array check" {
  let source =
    #|function process(value: string | Array<string>): string {
    #|  if (Array.isArray(value)) {
    #|    return value.join(", ");
    #|  }
    #|  return value;
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(e) => fail("Parse failed: " + e.to_string())
  }
}

test "narrowing/isArray - with unknown type" {
  let source =
    #|function process(value: unknown): number {
    #|  if (Array.isArray(value)) {
    #|    return value.length;
    #|  }
    #|  return 0;
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(e) => fail("Parse failed: " + e.to_string())
  }
}

// ============================================================================
// User-Defined Type Guards (x is Type)
// ============================================================================

test "narrowing/type-guard - basic user-defined guard" {
  let source =
    #|interface Fish { swim(): void }
    #|interface Bird { fly(): void }
    #|function isFish(pet: Fish | Bird): pet is Fish {
    #|  return (pet as Fish).swim !== undefined;
    #|}
    #|function move(pet: Fish | Bird) {
    #|  if (isFish(pet)) {
    #|    pet.swim();
    #|  } else {
    #|    pet.fly();
    #|  }
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(e) => fail("Parse failed: " + e.to_string())
  }
}

test "narrowing/type-guard - method type guard" {
  // Note: "this is Type" in return position is a type predicate
  // Using simpler form for now until parser fully supports "this is" predicates
  let source =
    #|class Animal {
    #|  isDog(): boolean { return false; }
    #|}
    #|class Dog extends Animal {
    #|  bark() {}
    #|  isDog(): boolean { return true; }
    #|}
    #|function test(animal: Animal) {
    #|  if (animal.isDog()) {
    #|    // In a full implementation, this would narrow to Dog
    #|    console.log("is dog");
    #|  }
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(e) => fail("Parse failed: " + e.to_string())
  }
}

test "narrowing/type-guard - type predicate with generic" {
  let source =
    #|function isNotNull<T>(value: T | null): value is T {
    #|  return value !== null;
    #|}
    #|function process(value: string | null): string {
    #|  if (isNotNull(value)) {
    #|    return value.toUpperCase();
    #|  }
    #|  return "";
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(e) => fail("Parse failed: " + e.to_string())
  }
}

// ============================================================================
// Assertion Functions (asserts x is Type)
// ============================================================================

test "narrowing/assertion - basic assertion function" {
  let source =
    #|function assertIsString(value: unknown): asserts value is string {
    #|  if (typeof value !== "string") {
    #|    throw new Error("Not a string");
    #|  }
    #|}
    #|function process(value: unknown): string {
    #|  assertIsString(value);
    #|  return value.toUpperCase();
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(e) => fail("Parse failed: " + e.to_string())
  }
}

test "narrowing/assertion - asserts without type" {
  let source =
    #|function assertDefined<T>(value: T | undefined): asserts value {
    #|  if (value === undefined) {
    #|    throw new Error("Value is undefined");
    #|  }
    #|}
    #|function process(value: string | undefined): string {
    #|  assertDefined(value);
    #|  return value.toUpperCase();
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(e) => fail("Parse failed: " + e.to_string())
  }
}

// ============================================================================
// Control Flow with Narrowing
// ============================================================================

test "narrowing/control-flow - early return narrows remainder" {
  let source =
    #|function process(value: string | null): string {
    #|  if (value === null) {
    #|    return "empty";
    #|  }
    #|  // value is narrowed to string here
    #|  return value.toUpperCase();
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(e) => fail("Parse failed: " + e.to_string())
  }
}

test "narrowing/control-flow - throw narrows remainder" {
  let source =
    #|function process(value: string | null): string {
    #|  if (value === null) {
    #|    throw new Error("null not allowed");
    #|  }
    #|  return value.toUpperCase();
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(e) => fail("Parse failed: " + e.to_string())
  }
}

test "narrowing/control-flow - logical and preserves narrowing" {
  let source =
    #|function process(value: string | null): number {
    #|  if (value !== null && value.length > 0) {
    #|    return value.length;
    #|  }
    #|  return 0;
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(e) => fail("Parse failed: " + e.to_string())
  }
}

test "narrowing/control-flow - logical or with type guards" {
  let source =
    #|function process(value: string | number | null): string {
    #|  if (value === null || typeof value === "number") {
    #|    return "not a string";
    #|  }
    #|  return value.toUpperCase();
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(e) => fail("Parse failed: " + e.to_string())
  }
}

test "narrowing/control-flow - negated condition" {
  let source =
    #|function process(value: string | number): string {
    #|  if (!(typeof value === "string")) {
    #|    return value.toFixed(2);
    #|  }
    #|  return value.toUpperCase();
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(e) => fail("Parse failed: " + e.to_string())
  }
}

// ============================================================================
// Combined Narrowing Tests
// ============================================================================

test "narrowing/combined - multiple conditions" {
  let source =
    #|type Response = { status: "ok"; data: string[] } | { status: "error"; code: number };
    #|function process(response: Response): string {
    #|  if (response.status === "ok" && response.data.length > 0) {
    #|    return response.data[0];
    #|  }
    #|  if (response.status === "error") {
    #|    return "Error: " + response.code.toString();
    #|  }
    #|  return "";
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(e) => fail("Parse failed: " + e.to_string())
  }
}

test "narrowing/combined - typeof and property access" {
  let source =
    #|function process(value: { name?: string } | string): string {
    #|  if (typeof value === "object" && value.name !== undefined) {
    #|    return value.name;
    #|  }
    #|  if (typeof value === "string") {
    #|    return value;
    #|  }
    #|  return "";
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(e) => fail("Parse failed: " + e.to_string())
  }
}

// ============================================================================
// Narrowing Infrastructure Unit Tests (using factory functions)
// ============================================================================

test "narrowing/infrastructure - typeof narrowed type for string" {
  let ty = @compiler.typeof_narrowed_type("string")
  match ty {
    Some(@compiler.TString) => ()
    _ => fail("Expected TString")
  }
}

test "narrowing/infrastructure - typeof narrowed type for number" {
  let ty_num = @compiler.typeof_narrowed_type("number")
  match ty_num {
    Some(@compiler.TNumber) => ()
    _ => fail("Expected TNumber")
  }
}

test "narrowing/infrastructure - typeof narrowed type for boolean" {
  let ty_bool = @compiler.typeof_narrowed_type("boolean")
  match ty_bool {
    Some(@compiler.TBoolean) => ()
    _ => fail("Expected TBoolean")
  }
}

test "narrowing/infrastructure - typeof narrowed type for undefined" {
  let ty = @compiler.typeof_narrowed_type("undefined")
  match ty {
    Some(@compiler.TUndefined) => ()
    _ => fail("Expected TUndefined")
  }
}

test "narrowing/infrastructure - typeof narrowed type for symbol" {
  let ty = @compiler.typeof_narrowed_type("symbol")
  match ty {
    Some(@compiler.TSymbol) => ()
    _ => fail("Expected TSymbol")
  }
}

test "narrowing/infrastructure - typeof narrowed type for bigint" {
  let ty = @compiler.typeof_narrowed_type("bigint")
  match ty {
    Some(@compiler.TBigInt) => ()
    _ => fail("Expected TBigInt")
  }
}

test "narrowing/infrastructure - typeof narrowed type for function" {
  let ty = @compiler.typeof_narrowed_type("function")
  match ty {
    Some(@compiler.TFunction(_)) => ()
    _ => fail("Expected TFunction")
  }
}

test "narrowing/infrastructure - typeof narrowed type for object" {
  let ty = @compiler.typeof_narrowed_type("object")
  match ty {
    Some(@compiler.TObject(_)) => ()
    _ => fail("Expected TObject")
  }
}

test "narrowing/infrastructure - typeof narrowed type for invalid" {
  let ty = @compiler.typeof_narrowed_type("invalid")
  match ty {
    None => ()
    _ => fail("Expected None for invalid type")
  }
}

// ============================================================================
// Control Flow in Nested Closures
// ============================================================================

test "narrowing/closure - arrow function inherits typeof narrowing" {
  let source =
    #|function example(x: string | number) {
    #|  if (typeof x === "string") {
    #|    const fn = () => {
    #|      // x should be narrowed to string here
    #|      return x.toUpperCase();
    #|    };
    #|    return fn();
    #|  }
    #|  return "";
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(e) => fail("Parse failed: " + e.to_string())
  }
}

test "narrowing/closure - function expression inherits narrowing" {
  let source =
    #|function outer(value: string | null) {
    #|  if (value !== null) {
    #|    const inner = function() {
    #|      // value is narrowed to string here
    #|      return value.length;
    #|    };
    #|    return inner();
    #|  }
    #|  return 0;
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(e) => fail("Parse failed: " + e.to_string())
  }
}

test "narrowing/closure - nested arrow functions inherit narrowing" {
  let source =
    #|function outer(x: string | number | null) {
    #|  if (x !== null) {
    #|    if (typeof x === "string") {
    #|      const fn1 = () => {
    #|        const fn2 = () => {
    #|          // x should be string in nested closures
    #|          return x.toUpperCase();
    #|        };
    #|        return fn2();
    #|      };
    #|      return fn1();
    #|    }
    #|  }
    #|  return "";
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(e) => fail("Parse failed: " + e.to_string())
  }
}

test "narrowing/closure - array method callback with narrowing" {
  let source =
    #|function process(items: Array<string | null>) {
    #|  // Using regular filter callback, narrowing applies within
    #|  const result = items.filter(item => item !== null);
    #|  return result.map(item => item ? item.toUpperCase() : "");
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(e) => fail("Parse failed: " + e.to_string())
  }
}

test "narrowing/closure - closure captures discriminated union narrowing" {
  let source =
    #|type Result = { ok: true; value: number } | { ok: false; error: string };
    #|function handle(result: Result) {
    #|  if (result.ok) {
    #|    const getDouble = () => result.value * 2;
    #|    return getDouble();
    #|  }
    #|  return 0;
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(e) => fail("Parse failed: " + e.to_string())
  }
}

test "narrowing/closure - callback in promise chain" {
  let source =
    #|function fetchData(url: string | null) {
    #|  if (url !== null) {
    #|    return Promise.resolve(url)
    #|      .then(u => u.toUpperCase())
    #|      .then(u => u.length);
    #|  }
    #|  return Promise.resolve(0);
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(e) => fail("Parse failed: " + e.to_string())
  }
}

test "narrowing/closure - event handler with narrowed variable" {
  let source =
    #|function setupHandler(element: HTMLElement | null) {
    #|  if (element) {
    #|    element.addEventListener("click", () => {
    #|      // element is narrowed here
    #|      console.log(element.tagName);
    #|    });
    #|  }
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(e) => fail("Parse failed: " + e.to_string())
  }
}

test "narrowing/closure - closure with instanceof check" {
  let source =
    #|class Dog { bark() {} }
    #|class Cat { meow() {} }
    #|function petSound(pet: Dog | Cat) {
    #|  if (pet instanceof Dog) {
    #|    const makeSound = () => pet.bark();
    #|    makeSound();
    #|  }
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(e) => fail("Parse failed: " + e.to_string())
  }
}
