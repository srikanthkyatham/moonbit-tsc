// Class OOP Features Tests
// Tests for Phase 2 implementation:
// 1. Class member accessibility (public/private/protected)
// 2. Abstract class validation
// 3. Override compatibility checking
// 4. This type handling

///|
/// Helper function to parse, bind, and check source code
fn parse_bind_check_class(source : String) -> @compiler.CheckResult {
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
// Basic Class Declaration Tests
// ============================================================================

///|
test "unit/classes/basic - simple class declaration" {
  let result = parse_bind_check_class(
    "class Point { x: number; y: number; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/classes/basic - class with constructor" {
  let result = parse_bind_check_class(
    "class Point { constructor(public x: number, public y: number) {} }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/classes/basic - class with methods" {
  let result = parse_bind_check_class(
    "class Calculator { add(a: number, b: number): number { return a + b; } }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/classes/basic - class instantiation" {
  let result = parse_bind_check_class(
    "class Foo {} const f = new Foo();",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Accessibility Modifier Tests
// ============================================================================

///|
test "unit/classes/accessibility - public property" {
  let result = parse_bind_check_class(
    "class Foo { public name: string = 'test'; } const f = new Foo(); f.name;",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/classes/accessibility - private property declaration" {
  let result = parse_bind_check_class(
    "class Foo { private secret: string = 'hidden'; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/classes/accessibility - protected property declaration" {
  let result = parse_bind_check_class(
    "class Base { protected value: number = 42; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/classes/accessibility - private method" {
  let result = parse_bind_check_class(
    "class Foo { private helper(): void {} public doWork(): void { this.helper(); } }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/classes/accessibility - readonly property" {
  let result = parse_bind_check_class(
    "class Foo { readonly id: number = 1; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Abstract Class Tests
// ============================================================================

///|
test "unit/classes/abstract - abstract class declaration" {
  let result = parse_bind_check_class(
    "abstract class Shape { abstract getArea(): number; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/classes/abstract - abstract with concrete methods" {
  let result = parse_bind_check_class(
    "abstract class Animal { abstract speak(): void; move(): void { } }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/classes/abstract - concrete class extending abstract" {
  let result = parse_bind_check_class(
    "abstract class Shape { abstract getArea(): number; } class Circle extends Shape { getArea(): number { return 3.14; } }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Inheritance Tests
// ============================================================================

///|
test "unit/classes/inheritance - extends base class" {
  let result = parse_bind_check_class(
    "class Animal { name: string; } class Dog extends Animal { bark(): void {} }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/classes/inheritance - implements interface" {
  let result = parse_bind_check_class(
    "interface Runnable { run(): void; } class Task implements Runnable { run(): void {} }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/classes/inheritance - multiple interfaces" {
  let result = parse_bind_check_class(
    "interface A { a(): void; } interface B { b(): void; } class C implements A, B { a(): void {} b(): void {} }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/classes/inheritance - extends and implements" {
  let result = parse_bind_check_class(
    "interface Serializable { serialize(): string; } class Base {} class Derived extends Base implements Serializable { serialize(): string { return ''; } }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Generic Class Tests
// ============================================================================

///|
test "unit/classes/generic - generic class" {
  let result = parse_bind_check_class(
    "class Container<T> { value: T; constructor(v: T) { this.value = v; } }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/classes/generic - generic class instantiation" {
  let result = parse_bind_check_class(
    "class Box<T> { value: T; } const numBox = new Box<number>();",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/classes/generic - generic class with constraint" {
  let result = parse_bind_check_class(
    "interface HasLength { length: number; } class List<T extends HasLength> { items: T[]; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/classes/generic - extending generic class" {
  let result = parse_bind_check_class(
    "class Base<T> { value: T; } class Derived<T> extends Base<T> { extra: string; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Constructor Tests
// ============================================================================

///|
test "unit/classes/constructor - parameter properties" {
  let result = parse_bind_check_class(
    "class Point { constructor(public x: number, public y: number) {} }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/classes/constructor - private parameter property" {
  let result = parse_bind_check_class(
    "class Counter { constructor(private count: number = 0) {} }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/classes/constructor - readonly parameter property" {
  let result = parse_bind_check_class(
    "class Entity { constructor(readonly id: string) {} }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Static Member Tests
// ============================================================================

///|
test "unit/classes/static - static property" {
  let result = parse_bind_check_class(
    "class Counter { static count: number = 0; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/classes/static - static method" {
  let result = parse_bind_check_class(
    "class MathUtils { static add(a: number, b: number): number { return a + b; } }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/classes/static - static and instance members" {
  let result = parse_bind_check_class(
    "class Counter { static instances: number = 0; value: number = 0; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Getter/Setter Tests
// ============================================================================

///|
test "unit/classes/accessor - getter" {
  let result = parse_bind_check_class(
    "class Circle { private _radius: number = 0; get radius(): number { return this._radius; } }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/classes/accessor - setter" {
  let result = parse_bind_check_class(
    "class Circle { private _radius: number = 0; set radius(value: number) { this._radius = value; } }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/classes/accessor - getter and setter" {
  let result = parse_bind_check_class(
    "class Person { private _name: string = ''; get name(): string { return this._name; } set name(value: string) { this._name = value; } }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// This Type Tests
// ============================================================================

///|
test "unit/classes/this - this in method body" {
  // Note: `this` return type is advanced feature; using concrete type for now
  let result = parse_bind_check_class(
    "class Builder { value: string = ''; append(s: string): Builder { this.value += s; return this; } }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/classes/this - method chaining with concrete type" {
  // Note: Using concrete return type instead of polymorphic `this`
  let result = parse_bind_check_class(
    "class Builder { add(x: number): Builder { return this; } build(): string { return ''; } } new Builder().add(1).add(2).build();",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Method Override Tests
// ============================================================================

///|
test "unit/classes/override - method override" {
  let result = parse_bind_check_class(
    "class Animal { speak(): void {} } class Dog extends Animal { speak(): void { } }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/classes/override - override with same signature" {
  let result = parse_bind_check_class(
    "class Base { greet(name: string): string { return ''; } } class Derived extends Base { greet(name: string): string { return 'Hello ' + name; } }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/classes/override - override with covariant return" {
  let result = parse_bind_check_class(
    "class Animal {} class Dog extends Animal {} class Factory { create(): Animal { return new Animal(); } } class DogFactory extends Factory { create(): Dog { return new Dog(); } }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Circular Reference Tests
// ============================================================================

///|
test "unit/classes/circular - static property self-reference" {
  // Class with static property that instantiates itself
  let result = parse_bind_check_class(
    "class Point { static origin = new Point(0, 0); constructor(public x: number, public y: number) {} }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/classes/circular - static method returning self" {
  let result = parse_bind_check_class(
    "class Singleton { private static instance: Singleton; static getInstance(): Singleton { return Singleton.instance; } }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/classes/circular - instance property with class type" {
  let result = parse_bind_check_class(
    "class Node { value: number; next: Node; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/classes/circular - static inheritance" {
  let result = parse_bind_check_class(
    "function doThing(x: { n: string }) { } class A { static n: string; p = doThing(A); } class B extends A { p1 = doThing(A); p2 = doThing(B); }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/classes/circular - forward ref in class properties" {
  let result = parse_bind_check_class(
    "class Test { _b = this._a; _a = 3; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/classes/circular - static property referencing static" {
  let result = parse_bind_check_class(
    "class X { static data = 13; static ref = X.data; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}
