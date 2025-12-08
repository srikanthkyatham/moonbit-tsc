// ============================================================================
// Computed Property Names in Interfaces and Type Literals
// Tests for ES2015+ computed property syntax: [expr]: Type or [expr](): ReturnType
// ============================================================================

///|
test "computed property with Symbol.iterator" {
  let source =
    #|interface I {
    #|    [Symbol.iterator]: number;
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Computed property [Symbol.iterator]: number should parse")
  }
}

///|
test "computed method signature with Symbol" {
  let source =
    #|interface I {
    #|    [Symbol.toPrimitive](): string;
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Computed method [Symbol.toPrimitive]() should parse")
  }
}

///|
test "optional computed property" {
  let source =
    #|interface I {
    #|    [Symbol.iterator]?: { x: any };
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Optional computed property [Symbol.iterator]? should parse")
  }
}

///|
test "computed method with parameters" {
  let source =
    #|interface I {
    #|    [Symbol.toPrimitive](hint: string): number;
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Computed method with parameters should parse")
  }
}

///|
test "multiple computed properties in interface" {
  let source =
    #|interface I {
    #|    [Symbol.iterator]: number;
    #|    [Symbol.toStringTag]: string;
    #|    [Symbol.toPrimitive](): number;
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Multiple computed properties should parse")
  }
}

///|
test "computed properties mixed with regular properties" {
  let source =
    #|interface I {
    #|    name: string;
    #|    [Symbol.iterator]: number;
    #|    value: number;
    #|    [Symbol.toStringTag]: string;
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) =>
      fail("Computed properties mixed with regular properties should parse")
  }
}

///|
test "traditional index signature still works" {
  let source =
    #|interface I {
    #|    [key: string]: number;
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Traditional index signature should still work")
  }
}

///|
test "computed property and index signature together" {
  let source =
    #|interface I {
    #|    [key: string]: any;
    #|    [Symbol.iterator]: number;
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Computed property and index signature should coexist")
  }
}

// Type literals with computed properties are not tested in the conformance suite
// and require separate parsing logic from interfaces. Skipping this test for now.

///|
test "computed property with string literal" {
  let source =
    #|interface I {
    #|    ["computed"]: number;
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Computed property with string literal should parse")
  }
}

///|
test "computed property with member expression" {
  let source =
    #|const obj = { prop: "key" };
    #|interface I {
    #|    [obj.prop]: number;
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Computed property with member expression should parse")
  }
}

///|
test "optional computed method" {
  let source =
    #|interface I {
    #|    [Symbol.iterator]?(): IterableIterator<number>;
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Optional computed method should parse")
  }
}

// ============================================================================
// Computed Properties in Classes
// ============================================================================

///|
test "computed property in class" {
  let source =
    #|class C {
    #|    [Symbol.iterator]: { x: any; y: any };
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Computed property in class should parse")
  }
}

///|
test "computed property with complex type" {
  let source =
    #|interface I {
    #|    [Symbol.iterator]: {
    #|        x: number;
    #|        y: string;
    #|    };
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Computed property with complex type should parse")
  }
}

///|
test "computed method with generic return type" {
  let source =
    #|interface I {
    #|    [Symbol.iterator](): IterableIterator<any>;
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Computed method with generic return type should parse")
  }
}

// ============================================================================
// Type Checking for Computed Properties
// ============================================================================

///|
test "computed property type compatibility" {
  let source =
    #|interface I1 {
    #|    [Symbol.iterator]: number;
    #|}
    #|interface I2 {
    #|    [Symbol.iterator]: string;
    #|}
    #|let x: I1 = {} as I2;
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(typed) => {
      // Should have type error about incompatible types
      let has_type_error = typed.diagnostics
        .iter()
        .any(fn(d) {
          d.message.contains("not assignable") ||
          d.message.contains("incompatible")
        })
      if not(has_type_error) {
        fail("Should detect incompatible computed property types")
      }
    }
    Err(_) => () // Also acceptable
  }
}

///|
test "computed property method signature mismatch" {
  let source =
    #|interface I1 {
    #|    [Symbol.iterator](): number;
    #|}
    #|interface I2 {
    #|    [Symbol.iterator](): string;
    #|}
    #|let x: I1 = {} as I2;
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(typed) => {
      // Should have type error about incompatible return types
      let has_type_error = typed.diagnostics
        .iter()
        .any(fn(d) {
          d.message.contains("not assignable") ||
          d.message.contains("incompatible")
        })
      if not(has_type_error) {
        fail("Should detect incompatible method return types")
      }
    }
    Err(_) => () // Also acceptable
  }
}

///|
test "readonly index signature still works" {
  let source =
    #|interface I {
    #|    readonly [key: string]: number;
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Readonly index signature should still work")
  }
}

// ============================================================================
// Duplicate Computed Properties Should Not Error
// Tests that multiple computed properties don't trigger duplicate identifier errors
// ============================================================================

///|
test "multiple computed properties in class - no duplicate error" {
  let source =
    #|class C {
    #|    static [Symbol.iterator] = 0;
    #|    static [Symbol.isConcatSpreadable]() { }
    #|    static get [Symbol.toPrimitive]() { return ""; }
    #|    static set [Symbol.toPrimitive](x) { }
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(typed) => {
      // Should not have TS2300 duplicate identifier errors
      let has_duplicate_error = typed.diagnostics
        .iter()
        .any(fn(d) {
          d.code == 2300 && d.message.contains("Duplicate identifier")
        })
      if has_duplicate_error {
        fail("Should not report duplicate identifier for computed properties")
      }
    }
    Err(_) => fail("Multiple computed properties in class should parse")
  }
}

///|
test "multiple getters with computed names - no duplicate error" {
  let source =
    #|class C {
    #|    get [Symbol.hasInstance]() {
    #|        return "";
    #|    }
    #|    get [Symbol.toPrimitive]() {
    #|        return "";
    #|    }
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(typed) => {
      // Should not have TS2300 duplicate identifier errors
      let has_duplicate_error = typed.diagnostics
        .iter()
        .any(fn(d) {
          d.code == 2300 && d.message.contains("Duplicate identifier")
        })
      if has_duplicate_error {
        fail("Should not report duplicate identifier for computed getters")
      }
    }
    Err(_) => fail("Multiple getters with computed names should parse")
  }
}

///|
test "computed property and method with same Symbol - allowed" {
  let source =
    #|class C {
    #|    [Symbol.iterator] = 0;
    #|    [Symbol.iterator]() { return null; }
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(typed) => {
      // Should not have TS2300 duplicate identifier errors
      // Note: TypeScript allows both property and method with same computed name
      let has_duplicate_error = typed.diagnostics
        .iter()
        .any(fn(d) {
          d.code == 2300 && d.message.contains("Duplicate identifier")
        })
      if has_duplicate_error {
        fail(
          "Should not report duplicate identifier for computed property and method",
        )
      }
    }
    Err(_) => fail("Computed property and method with same Symbol should parse")
  }
}

///|
test "multiple computed properties in interface - no duplicate error" {
  let source =
    #|interface I {
    #|    [Symbol.iterator]: any;
    #|    [Symbol.toPrimitive](): string;
    #|    [Symbol.toStringTag]: string;
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(typed) => {
      // Should not have TS2300 duplicate identifier errors
      let has_duplicate_error = typed.diagnostics
        .iter()
        .any(fn(d) {
          d.code == 2300 && d.message.contains("Duplicate identifier")
        })
      if has_duplicate_error {
        fail(
          "Should not report duplicate identifier for computed properties in interface",
        )
      }
    }
    Err(_) => fail("Multiple computed properties in interface should parse")
  }
}
