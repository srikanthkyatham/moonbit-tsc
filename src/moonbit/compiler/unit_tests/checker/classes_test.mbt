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
  let result = parse_bind_check_class("// @strict: false\nclass Point { x: number; y: number; }")
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
  let result = parse_bind_check_class("class Foo {} const f = new Foo();")
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
  let result = parse_bind_check_class("class Foo { readonly id: number = 1; }")
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
    "// @strict: false\nclass Animal { name: string; } class Dog extends Animal { bark(): void {} }",
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
    "// @strict: false\ninterface HasLength { length: number; } class List<T extends HasLength> { items: T[]; }",
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/classes/generic - extending generic class" {
  let result = parse_bind_check_class(
    "// @strict: false\nclass Base<T> { value: T; } class Derived<T> extends Base<T> { extra: string; }",
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
    "// @strict: false\nclass Node { value: number; next: Node; }",
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
test "unit/classes/circular - forward ref in class properties reports TS2729" {
  // Forward reference to uninitialized property should report TS2729
  let result = parse_bind_check_class("class Test { _b = this._a; _a = 3; }")
  match result {
    Ok(_) => assert_true(false) // Should have TS2729 error
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      let has_ts2729 = diagnostics.iter().any(fn(d) { d.code == 2729 })
      assert_true(has_ts2729)
    }
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

// ============================================================================
// Extends Null Tests
// ============================================================================

///|
test "unit/classes/extends-null - class extends null" {
  // Class extending null should not require super() call
  let result = parse_bind_check_class(
    (
      #|class NullProto extends null {
      #|  constructor() {
      #|    return {};
      #|  }
      #|}
    ),
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => {
      println("Errors: \{@debug.to_string(diagnostics)}")
      assert_true(false)
    }
  }
}

///|
test "unit/classes/extends-null - class extends null with properties" {
  // Class extending null with properties should work without super()
  let result = parse_bind_check_class(
    (
      #|// @strict: false
      #|class Dict extends null {
      #|  key: string;
      #|  value: number;
      #|}
    ),
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => {
      println("Errors: \{@debug.to_string(diagnostics)}")
      assert_true(false)
    }
  }
}

///|
test "unit/classes/extends-null - extends null should not have TS2565 error" {
  // Accessing this in constructor of extends null class should not require super() first
  let result = parse_bind_check_class(
    (
      #|class NullProto extends null {
      #|  private _t: number;
      #|  constructor() {
      #|    this._t = 10;
      #|  }
      #|}
    ),
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => {
      println("Errors: \{@debug.to_string(diagnostics)}")
      // Should not have TS2377 (super required) or TS2565 (property used before assigned)
      let has_ts2377 = diagnostics.iter().any(fn(d) { d.code == 2377 })
      let has_ts2565 = diagnostics.iter().any(fn(d) { d.code == 2565 })
      assert_true(!(has_ts2377) && !(has_ts2565))
    }
  }
}

// ============================================================================
// Super Call Detection Tests
// ============================================================================

///|
test "unit/classes/super-call - super call in object literal property value" {
  // super() call inside object literal property value should be detected
  let result = parse_bind_check_class(
    (
      #|// @strict: false
      #|class Base {
      #|  constructor(c: any) { }
      #|}
      #|class D extends Base {
      #|  private _t: number;
      #|  constructor() {
      #|    let x = {
      #|      k: super(undefined),
      #|      j: this._t,
      #|    }
      #|  }
      #|}
    ),
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => {
      println("Errors: \{@debug.to_string(diagnostics)}")
      assert_true(false)
    }
  }
}

///|
test "unit/classes/super-call - super call in nested expression" {
  // super() in nested expression should be detected
  let result = parse_bind_check_class(
    (
      #|class Base {
      #|  constructor(x: number) { }
      #|}
      #|class D extends Base {
      #|  constructor() {
      #|    const result = (super(42), 100);
      #|  }
      #|}
    ),
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => {
      println("Errors: \{@debug.to_string(diagnostics)}")
      assert_true(false)
    }
  }
}

///|
test "unit/classes/super-call - super call in array literal" {
  // super() in array literal should be detected
  let result = parse_bind_check_class(
    (
      #|class Base {
      #|  constructor(x: number) { }
      #|}
      #|class D extends Base {
      #|  constructor() {
      #|    const arr = [super(1), this];
      #|  }
      #|}
    ),
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => {
      println("Errors: \{@debug.to_string(diagnostics)}")
      assert_true(false)
    }
  }
}

///|
test "unit/classes/super-call - super call in conditional expression" {
  // super() in conditional expression should be detected
  let result = parse_bind_check_class(
    (
      #|class Base {
      #|  constructor(x: number) { }
      #|}
      #|class D extends Base {
      #|  constructor(cond: boolean) {
      #|    const x = cond ? super(1) : super(2);
      #|  }
      #|}
    ),
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => {
      println("Errors: \{@debug.to_string(diagnostics)}")
      assert_true(false)
    }
  }
}

///|
test "unit/classes/super-call - valid super before this access" {
  // Super must be called before accessing this - valid case
  let result = parse_bind_check_class(
    (
      #|class Base {
      #|  constructor() { }
      #|}
      #|class D extends Base {
      #|  private _t: number;
      #|  constructor() {
      #|    super();
      #|    this._t = 10;
      #|  }
      #|}
    ),
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => {
      println("Errors: \{@debug.to_string(diagnostics)}")
      assert_true(false)
    }
  }
}

// ============================================================================
// Var Hoisting Tests
// ============================================================================

///|
test "unit/classes/var-hoisting - var declaration hoisted in constructor" {
  // var declarations should be hoisted to the function scope
  let result = parse_bind_check_class(
    (
      #|declare var Factory: any;
      #|class Base {
      #|  constructor(c: any) { }
      #|}
      #|class D extends Base {
      #|  private _t: any;
      #|  constructor() {
      #|    super(i);
      #|    var s = {
      #|      t: this._t
      #|    }
      #|    var i = Factory.create(s);
      #|  }
      #|}
    ),
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => {
      println("Errors: \{@debug.to_string(diagnostics)}")
      assert_true(false)
    }
  }
}

///|
test "unit/classes/var-hoisting - var declaration hoisted in method" {
  // var declarations should be hoisted in methods too
  let result = parse_bind_check_class(
    (
      #|class Foo {
      #|  method() {
      #|    console.log(x);
      #|    var x = 10;
      #|  }
      #|}
    ),
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => {
      println("Errors: \{@debug.to_string(diagnostics)}")
      assert_true(false)
    }
  }
}

///|
test "unit/classes/ts2376 - no error for class without initialized properties" {
  // TS2376 should NOT be raised for classes without initialized properties
  let result = parse_bind_check_class(
    (
      #|class Base {
      #|  constructor(c: any) { }
      #|}
      #|class D extends Base {
      #|  private _t: any;
      #|  constructor() {
      #|    let x = {
      #|      k: super(undefined),
      #|      j: this._t,
      #|    }
      #|  }
      #|}
    ),
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => {
      println("Errors: \{@debug.to_string(diagnostics)}")
      assert_true(false)
    }
  }
}

///|
test "unit/classes/ts2376 - error for class with initialized properties" {
  // TS2376 SHOULD be raised for classes with initialized properties where super is not first
  let result = parse_bind_check_class(
    (
      #|class Base {
      #|  constructor(c: any) { }
      #|}
      #|class D extends Base {
      #|  private _t: number = 0;
      #|  constructor() {
      #|    let x = 1;
      #|    super(undefined);
      #|  }
      #|}
    ),
  )
  match result {
    Ok(_) => assert_true(false) // Should have TS2376 error
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      let has_ts2376 = diagnostics.iter().any(fn(d) { d.code == 2376 })
      assert_true(has_ts2376)
    }
  }
}

// ============================================================================
// TS17005 - Super in Extends Null Tests
// ============================================================================

///|
test "unit/classes/ts17005 - super call in extends null class reports error" {
  // TS17005: A constructor cannot contain a 'super' call when its class extends 'null'
  let result = parse_bind_check_class(
    (
      #|class D extends null {
      #|  private _t: any;
      #|  constructor() {
      #|    this._t;
      #|    super();
      #|  }
      #|}
    ),
  )
  match result {
    Ok(_) => assert_true(false) // Should have TS17005 error
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      let has_ts17005 = diagnostics.iter().any(fn(d) { d.code == 17005 })
      assert_true(has_ts17005)
    }
  }
}

///|
test "unit/classes/ts17005 - extends null without super is OK" {
  // Class extending null should NOT require super() call
  let result = parse_bind_check_class(
    (
      #|class D extends null {
      #|  private _t: any;
      #|  constructor() {
      #|    this._t = 10;
      #|  }
      #|}
    ),
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => {
      println("Errors: \{@debug.to_string(diagnostics)}")
      assert_true(false)
    }
  }
}

// ============================================================================
// TS17009 - Arrow Function This Tests
// ============================================================================

///|
test "unit/classes/ts17009 - this in arrow function before super" {
  // this inside arrow function before super() should NOT raise TS17009
  // (only direct this in constructor should be checked)
  let result = parse_bind_check_class(
    (
      #|class Base {
      #|  constructor(c: any) { }
      #|}
      #|class D extends Base {
      #|  private _t: any;
      #|  constructor() {
      #|    let x = () => { this._t };
      #|    x();
      #|    super(undefined);
      #|  }
      #|}
    ),
  )
  match result {
    Ok(typed) => assert_eq(typed.file_path, "test.ts")
    Err(diagnostics) => {
      println("Errors: \{@debug.to_string(diagnostics)}")
      // Should NOT have TS17009 error for arrow function this
      let has_ts17009 = diagnostics.iter().any(fn(d) { d.code == 17009 })
      assert_true(!(has_ts17009))
    }
  }
}

///|
test "unit/classes/ts17009 - direct this before super reports error" {
  // Direct this access in constructor before super() should raise TS17009
  let result = parse_bind_check_class(
    (
      #|class Base {
      #|  constructor(c: any) { }
      #|}
      #|class D extends Base {
      #|  private _t: any;
      #|  constructor() {
      #|    this._t;
      #|    super(undefined);
      #|  }
      #|}
    ),
  )
  match result {
    Ok(_) => assert_true(false) // Should have TS17009 error
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      let has_ts17009 = diagnostics.iter().any(fn(d) { d.code == 17009 })
      assert_true(has_ts17009)
    }
  }
}

///|
test "unit/classes/ts17009 - this in object literal before super reports error" {
  // this in object literal value before super() should raise TS17009
  let result = parse_bind_check_class(
    (
      #|class Base {
      #|  constructor(c: any) { }
      #|}
      #|class D extends Base {
      #|  private _t: any;
      #|  constructor() {
      #|    let x = {
      #|      j: this._t,
      #|    }
      #|    super(undefined);
      #|  }
      #|}
    ),
  )
  match result {
    Ok(_) => assert_true(false) // Should have TS17009 error
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      let has_ts17009 = diagnostics.iter().any(fn(d) { d.code == 17009 })
      assert_true(has_ts17009)
    }
  }
}

///|
test "unit/classes/ts17009 - this in super() arguments reports error" {
  // this inside super() arguments should raise TS17009
  // because arguments are evaluated BEFORE super() completes
  let result = parse_bind_check_class(
    (
      #|class Base {
      #|  constructor(c: any) { }
      #|}
      #|class D extends Base {
      #|  private _t: any;
      #|  constructor() {
      #|    super(this);
      #|  }
      #|}
    ),
  )
  match result {
    Ok(_) => assert_true(false) // Should have TS17009 error
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      let has_ts17009 = diagnostics.iter().any(fn(d) { d.code == 17009 })
      assert_true(has_ts17009)
    }
  }
}

///|
test "unit/classes/ts17009 - this._t in super() arguments reports error" {
  // this.property inside super() arguments should raise TS17009
  let result = parse_bind_check_class(
    (
      #|class Base {
      #|  constructor(c: any) { }
      #|}
      #|class D extends Base {
      #|  private _t: any;
      #|  constructor() {
      #|    super(this._t);
      #|  }
      #|}
    ),
  )
  match result {
    Ok(_) => assert_true(false) // Should have TS17009 error
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      let has_ts17009 = diagnostics.iter().any(fn(d) { d.code == 17009 })
      assert_true(has_ts17009)
    }
  }
}
