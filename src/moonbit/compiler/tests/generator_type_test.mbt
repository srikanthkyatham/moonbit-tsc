// Generator Type Inference and Class Assignability Tests
// Tests for Generator type checking, class instance to TypeReference assignability

// ============================================================================
// Class Instance to TypeReference Assignability Tests
// ============================================================================

///|
test "class instance assigned to same class type" {
  let source =
    #|class Foo { x: number }
    #|const f: Foo = new Foo();
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Expected class instance to be assignable to its own type")
  }
}

///|
test "derived class instance assigned to base class type" {
  let source =
    #|class Foo { x: number }
    #|class Bar extends Foo { y: string }
    #|const bar: Bar = new Bar();
    #|const foo: Foo = bar;
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass - Bar extends Foo
    Err(_) => fail("Expected derived class to be assignable to base class")
  }
}

///|
test "declared derived class assigned to base class type" {
  let source =
    #|class Foo { x: number }
    #|class Bar extends Foo { y: string }
    #|declare const bar: Bar;
    #|const foo: Foo = bar;
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Expected declared derived class to be assignable to base class")
  }
}

// ============================================================================
// Generator Function Tests - Basic
// ============================================================================

///|
test "empty generator with Iterator return type" {
  let source =
    #|function* g(): Iterator<string> {
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass - empty generator is compatible
    Err(_) => fail("Expected empty generator to be compatible with Iterator")
  }
}

///|
test "empty generator with Iterable return type" {
  let source =
    #|function* g(): Iterable<number> {
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Expected empty generator to be compatible with Iterable")
  }
}

///|
test "empty generator with IterableIterator return type" {
  let source =
    #|function* g(): IterableIterator<boolean> {
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Expected empty generator to be compatible with IterableIterator")
  }
}

// ============================================================================
// Generator Function Tests - With Yields
// ============================================================================

///|
test "generator yielding correct type" {
  let source =
    #|function* g(): Iterator<number> {
    #|    yield 1;
    #|    yield 2;
    #|    yield 3;
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Expected generator yielding numbers to be compatible with Iterator<number>")
  }
}

///|
test "generator with bare yield statement" {
  let source =
    #|function* g(): IterableIterator<number> {
    #|    yield;
    #|    yield 42;
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass - bare yield doesn't affect type param
    Err(_) => fail("Expected generator with bare yield to be compatible")
  }
}

// ============================================================================
// Generator Function Tests - Class Inheritance in Yields
// ============================================================================

///|
test "generator yielding derived class for base class iterator" {
  let source =
    #|class Foo { x: number }
    #|class Bar extends Foo { y: string }
    #|function* g(): IterableIterator<Foo> {
    #|    yield new Bar();
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass - Bar extends Foo
    Err(_) => fail("Expected derived class yield to be compatible with base class iterator")
  }
}

///|
test "generator with bare yield and derived class" {
  let source =
    #|class Foo { x: number }
    #|class Bar extends Foo { y: string }
    #|function* g(): IterableIterator<Foo> {
    #|    yield;
    #|    yield new Bar();
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Expected generator with bare yield and derived class to pass")
  }
}

// ============================================================================
// Generator Function Tests - Return Statements
// ============================================================================

///|
test "generator with return value" {
  let source =
    #|function* g(): IterableIterator<number, number> {
    #|    return 0;
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass - return type is second type arg
    Err(_) => fail("Expected generator with return value to be compatible")
  }
}

///|
test "generator with yield and return" {
  let source =
    #|function* g(): IterableIterator<string, number> {
    #|    yield "hello";
    #|    return 42;
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Expected generator with yield and return to be compatible")
  }
}

// ============================================================================
// Generator Function Tests - Error Cases
// ============================================================================

///|
test "generator yielding incompatible type should error" {
  let source =
    #|function* g(): Iterator<number> {
    #|    yield "string";
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(typed) =>
      // Should have diagnostics about type incompatibility
      if typed.diagnostics.length() == 0 {
        fail("Expected type error for incompatible yield type")
      }
    Err(_) => () // Expected to have errors
  }
}

///|
test "unrelated class yield should error" {
  let source =
    #|class Foo { x: number }
    #|class Baz { z: boolean }
    #|function* g(): IterableIterator<Foo> {
    #|    yield new Baz();
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(typed) =>
      // Should have diagnostics about type incompatibility
      if typed.diagnostics.length() == 0 {
        fail("Expected type error for unrelated class yield")
      }
    Err(_) => () // Expected to have errors
  }
}

// ============================================================================
// Generator Method Tests
// ============================================================================

///|
test "generator method in class" {
  let source =
    #|class MyClass {
    #|    *generate(): Iterator<number> {
    #|        yield 1;
    #|        yield 2;
    #|    }
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Expected generator method to be compatible")
  }
}

///|
test "generator method with class inheritance" {
  let source =
    #|class Base { name: string }
    #|class Derived extends Base { id: number }
    #|class MyClass {
    #|    *generate(): Iterator<Base> {
    #|        yield new Derived();
    #|    }
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass - Derived extends Base
    Err(_) => fail("Expected generator method with derived class to pass")
  }
}

// ============================================================================
// Object Literal Generator Tests
// ============================================================================

///|
test "object with generator method" {
  let source =
    #|const obj = {
    #|    *gen(): Iterator<number> {
    #|        yield 1;
    #|    }
    #|};
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Expected object with generator method to pass")
  }
}

///|
test "yield* from object with Symbol.iterator" {
  let source =
    #|function* g(): IterableIterator<number> {
    #|    yield * {
    #|        *[Symbol.iterator]() {
    #|            yield 1;
    #|            yield 2;
    #|        }
    #|    };
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Expected yield* from Symbol.iterator to pass")
  }
}

///|
test "yield* from object with Symbol.iterator and function type" {
  let source =
    #|function* g(): IterableIterator<(x: string) => number> {
    #|    yield * {
    #|        *[Symbol.iterator]() {
    #|            yield x => x.length;
    #|        }
    #|    };
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Expected yield* from Symbol.iterator with function type to pass")
  }
}

///|
test "yield* from variable with Symbol.iterator" {
  let source =
    #|const obj = {
    #|    *[Symbol.iterator]() {
    #|        yield (x: string) => x.length;
    #|    }
    #|};
    #|function* g(): IterableIterator<(x: string) => number> {
    #|    yield * obj;
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Expected yield* from variable with Symbol.iterator to pass")
  }
}

///|
test "generator with Symbol.iterator and overload resolution" {
  let source =
    #|declare function foo<T, U>(x: T, fun: () => Iterable<(x: T) => U>, fun2: (y: U) => T): T;
    #|
    #|foo("", function* () {
    #|    yield* {
    #|        *[Symbol.iterator]() {
    #|            yield x => x.length;
    #|        }
    #|    }
    #|}, p => undefined);
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Expected overload resolution with Symbol.iterator to pass")
  }
}

///|
test "generator type inference with nested Symbol.iterator" {
  let source =
    #|function* gen() {
    #|    yield* {
    #|        *[Symbol.iterator]() {
    #|            yield (x: number) => x * 2;
    #|        }
    #|    };
    #|}
    #|const result = gen();
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass - type should be inferred correctly
    Err(_) => fail("Expected generator with nested Symbol.iterator to pass")
  }
}

///|
test "Iterator/Iterable conflict - different types should error" {
  let source =
    #|interface BadGenerator extends Iterator<number>, Iterable<string> { }
    #|function* g(): BadGenerator { }
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Err(diagnostics) => {
      // Should have TS2322 error about type incompatibility
      let has_ts2322 = diagnostics.any(
        fn(d) { d.message.contains("not assignable") },
      )
      if not(has_ts2322) {
        fail(
          "Expected TS2322 error for conflicting Iterator<number> and Iterable<string>",
        )
      }
    }
    Ok(_) =>
      fail(
        "Expected error for interface with conflicting Iterator<number> and Iterable<string>",
      )
  }
}

///|
test "Iterator/Iterable conflict - same types should pass" {
  let source =
    #|interface GoodGenerator extends Iterator<string>, Iterable<string> { }
    #|function* g(): GoodGenerator {
    #|    yield "hello";
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass when Iterator and Iterable have same type
    Err(_) =>
      fail(
        "Expected to pass when Iterator<string> and Iterable<string> have matching types",
      )
  }
}

///|
test "Iterator/Iterable conflict - complex types" {
  let source =
    #|interface ConflictGen extends Iterator<{x: number}>, Iterable<{y: string}> { }
    #|function* g(): ConflictGen { }
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Err(diagnostics) => {
      let has_error = diagnostics.any(
        fn(d) { d.message.contains("not assignable") },
      )
      if not(has_error) {
        fail("Expected error for conflicting object types in Iterator/Iterable")
      }
    }
    Ok(_) =>
      fail(
        "Expected error for interface with conflicting complex types in Iterator/Iterable",
      )
  }
}

///|
test "Iterator/Iterable conflict - function types" {
  let source =
    #|interface FnConflictGen extends Iterator<(x: number) => string>, Iterable<(x: string) => number> { }
    #|function* g(): FnConflictGen { }
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Err(diagnostics) => {
      let has_error = diagnostics.any(
        fn(d) { d.message.contains("not assignable") },
      )
      if not(has_error) {
        fail(
          "Expected error for conflicting function types in Iterator/Iterable",
        )
      }
    }
    Ok(_) =>
      fail(
        "Expected error for interface with conflicting function types in Iterator/Iterable",
      )
  }
}

///|
test "Iterator/Iterable conflict - empty generator" {
  let source =
    #|interface EmptyConflict extends Iterator<number>, Iterable<string> { }
    #|function* g(): EmptyConflict {
    #|    // Empty generator - should still detect the conflict
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Err(diagnostics) => {
      let has_error = diagnostics.any(
        fn(d) { d.message.contains("not assignable") },
      )
      if not(has_error) {
        fail("Expected error even for empty generator with conflicting types")
      }
    }
    Ok(_) =>
      fail(
        "Expected error for empty generator with conflicting Iterator/Iterable",
      )
  }
}
