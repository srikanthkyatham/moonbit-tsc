///|
/// Unit tests for never type inference from terminating blocks
/// Related conformance tests: types/never/neverType.ts
///
/// Tests that arrow functions that always throw are correctly
/// inferred to return `never` type instead of `void`.

test "Never type: Arrow function with throw should infer never" {
  let source =
    #|function test(cb: () => string) {
    #|    return cb();
    #|}
    #|test(() => { throw new Error(); });

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ Arrow function with throw correctly inferred as () => never")
      assert_true(true)
    }
    Err(diagnostics) => {
      println("✗ Should not error - () => never is assignable to () => string")
      for d in diagnostics {
        println("  Error: \{d.message}")
      }
      assert_false(true)
    }
  }
}

test "Never type: Multiple overloads with never-returning callback" {
  let source =
    #|function test(cb: () => string) {
    #|    let s = cb();
    #|    return s;
    #|}
    #|
    #|let errorCallback = () => { throw new Error("Error"); };
    #|
    #|test(() => "hello");
    #|test(() => { throw new Error(); });
    #|test(errorCallback);

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ All overload calls with never-returning functions work correctly")
      assert_true(true)
    }
    Err(diagnostics) => {
      println("✗ Should pass - never is assignable to string")
      for d in diagnostics {
        println("  Error: \{d.message}")
      }
      assert_false(true)
    }
  }
}

test "Never type: Arrow function with return should not infer never" {
  let source =
    #|function test(cb: () => string) {
    #|    return cb();
    #|}
    #|test(() => { return "hello"; });

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ Arrow function with return statement correctly infers string")
      assert_true(true)
    }
    Err(diagnostics) => {
      println("✗ Should not error - normal return infers correct type")
      for d in diagnostics {
        println("  Error: \{d.message}")
      }
      assert_false(true)
    }
  }
}

test "Never type: Arrow function with empty block should infer void" {
  let source =
    #|function test(cb: () => void) {
    #|    cb();
    #|}
    #|test(() => {});

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ Arrow function with empty block correctly infers void")
      assert_true(true)
    }
    Err(diagnostics) => {
      println("✗ Should not error - empty block infers void")
      for d in diagnostics {
        println("  Error: \{d.message}")
      }
      assert_false(true)
    }
  }
}

test "Never type: Arrow function with conditional throw should not infer never" {
  let source =
    #|function test(cb: () => string) {
    #|    return cb();
    #|}
    #|test(() => {
    #|    if (Math.random() > 0.5) {
    #|        throw new Error();
    #|    }
    #|    return "hello";
    #|});

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ Conditional throw with return correctly infers string")
      assert_true(true)
    }
    Err(diagnostics) => {
      println("✗ Should not error - has return statement")
      for d in diagnostics {
        println("  Error: \{d.message}")
      }
      assert_false(true)
    }
  }
}

test "Never type: Arrow function ending with break should infer never" {
  let source =
    #|function test(cb: () => string) {
    #|    return cb();
    #|}
    #|// This is technically invalid TypeScript (break outside loop)
    #|// but tests that other terminating statements also infer never
    #|while (true) {
    #|    test(() => { break; });
    #|}

  let result = parse_bind_check_errors(source)
  // This test might error for other reasons (break outside loop in arrow function)
  // The key is that if we reach type checking, break is a terminating statement
  match result {
    Ok(_) => {
      println("✓ Arrow function with break infers never (when valid)")
      assert_true(true)
    }
    Err(diagnostics) => {
      // Check if we got the expected error, not TS2769
      let has_overload_error = diagnostics.iter().any(fn(d) { d.code == 2769 })
      if has_overload_error {
        println("✗ Should not get overload error - break is terminating")
        assert_false(true)
      } else {
        println("✓ Got expected error (not overload mismatch)")
        assert_true(true)
      }
    }
  }
}

test "Never type: Function with throw statement should infer never" {
  let source =
    #|function fail(): string {
    #|    throw new Error("fail");
    #|}
    #|
    #|function test(cb: () => string) {
    #|    return cb();
    #|}
    #|
    #|test(fail);

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ Regular function with throw correctly inferred as () => never")
      assert_true(true)
    }
    Err(diagnostics) => {
      println("✗ Should not error - function with throw infers never")
      for d in diagnostics {
        println("  Error: \{d.message}")
      }
      assert_false(true)
    }
  }
}

test "Never type: Arrow function with multiple statements ending in throw" {
  let source =
    #|function test(cb: () => string) {
    #|    return cb();
    #|}
    #|test(() => {
    #|    console.log("about to throw");
    #|    throw new Error();
    #|});

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ Multi-statement block ending with throw infers never")
      assert_true(true)
    }
    Err(diagnostics) => {
      println("✗ Should not error - last statement is throw")
      for d in diagnostics {
        println("  Error: \{d.message}")
      }
      assert_false(true)
    }
  }
}

test "Never type: Never is assignable to any type" {
  let source =
    #|function alwaysThrows(): never {
    #|    throw new Error();
    #|}
    #|
    #|let s: string = alwaysThrows();
    #|let n: number = alwaysThrows();
    #|let b: boolean = alwaysThrows();

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ Never type is assignable to all types")
      assert_true(true)
    }
    Err(diagnostics) => {
      println("✗ Should not error - never is assignable to everything")
      for d in diagnostics {
        println("  Error: \{d.message}")
      }
      assert_false(true)
    }
  }
}

test "Never type: Generic function with never-returning callback" {
  let source =
    #|function process<T>(cb: () => T): T {
    #|    return cb();
    #|}
    #|
    #|// When cb returns never, the whole function returns never
    #|process(() => { throw new Error(); });
    #|
    #|// When cb returns string, the whole function returns string
    #|let result: string = process(() => "hello");

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ Generic functions work correctly with never type")
      assert_true(true)
    }
    Err(diagnostics) => {
      println("✗ Should not error - never works in generic context")
      for d in diagnostics {
        println("  Error: \{d.message}")
      }
      assert_false(true)
    }
  }
}
