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
test "computed property with member expression in interface (TS1169)" {
  let source =
    #|const obj = { prop: "key" };
    #|interface I {
    #|    [obj.prop]: number;
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => fail("Expected TS1169 error for non-literal computed property in interface")
    Err(_) => () // Expected to fail with TS1169
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
test "computed property and method with same Symbol - should error" {
  let source =
    #|class C {
    #|    [Symbol.iterator] = 0;
    #|    [Symbol.iterator]() { return null; }
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(typed) => {
      // Should have TS2300 duplicate identifier error
      // Note: TypeScript does NOT allow duplicate computed property names
      // Verified with tsc 5.9.3: reports "TS2300: Duplicate identifier '[Symbol.iterator]'"
      // Our compiler correctly detects this and reports it during binding phase
      let has_duplicate_error = typed.diagnostics
        .iter()
        .any(fn(d) {
          d.code == 2300 && d.message.contains("Duplicate identifier")
        })
      if not(has_duplicate_error) {
        fail(
          "Should report TS2300 duplicate identifier for same computed property name",
        )
      }
    }
    Err(diagnostics) => {
      // Binding errors cause Err result - check for TS2300 in diagnostics
      let has_duplicate_error = diagnostics
        .iter()
        .any(fn(d) {
          d.code == 2300 && d.message.contains("Duplicate identifier")
        })
      if not(has_duplicate_error) {
        fail("Should report TS2300 during binding for duplicate Symbol property")
      }
    }
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

// ============================================================================
// Computed Properties in Type Literals
// Tests that computed properties work in type literals (object types)
// ============================================================================

///|
test "computed property in type literal" {
  let source =
    #|var obj: {
    #|    [Symbol.isConcatSpreadable]: string;
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Computed property in type literal should parse")
  }
}

///|
test "multiple computed properties in type literal" {
  let source =
    #|type T = {
    #|    [Symbol.iterator]: number;
    #|    [Symbol.toStringTag]: string;
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Multiple computed properties in type literal should parse")
  }
}

///|
test "optional computed property in type literal" {
  let source =
    #|type T = {
    #|    [Symbol.iterator]?: number;
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Optional computed property in type literal should parse")
  }
}

///|
test "readonly computed property in type literal" {
  let source =
    #|type T = {
    #|    readonly [Symbol.iterator]: number;
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Readonly computed property in type literal should parse")
  }
}

///|
test "computed property and index signature in type literal" {
  let source =
    #|type T = {
    #|    [key: string]: any;
    #|    [Symbol.iterator]: number;
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) =>
      fail(
        "Computed property and index signature in type literal should coexist",
      )
  }
}

///|
test "computed property with member access expression" {
  let source =
    #|const key = Symbol.iterator;
    #|type T = {
    #|    [key]: number;
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Computed property with identifier should parse")
  }
}

// ============================================================================
// Symbol Properties Should Not Be Checked Against Index Signatures
// Tests that Symbol properties (computed properties) are in a separate namespace
// from string/number properties and should not be validated against index signatures
// ============================================================================

///|
test "Symbol property with string index signature - no conflict" {
  let source =
    #|interface I1 {
    #|    [Symbol.toStringTag]: string;
    #|    [key: string]: number;
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(typed) => {
      // Should NOT have TS2745 error about property incompatible with index signature
      let has_index_sig_error = typed.diagnostics
        .iter()
        .any(fn(d) {
          d.code == 2745 &&
          d.message.contains("not assignable to") &&
          d.message.contains("index type")
        })
      if has_index_sig_error {
        fail(
          "Symbol properties should not be checked against string index signatures",
        )
      }
    }
    Err(_) => fail("Symbol property with string index signature should parse")
  }
}

///|
test "Symbol property with number index signature - no conflict" {
  let source =
    #|interface I2 {
    #|    [Symbol.toStringTag]: string;
    #|    [key: number]: boolean;
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(typed) => {
      let has_index_sig_error = typed.diagnostics
        .iter()
        .any(fn(d) {
          d.code == 2745 &&
          d.message.contains("not assignable to") &&
          d.message.contains("index type")
        })
      if has_index_sig_error {
        fail(
          "Symbol properties should not be checked against number index signatures",
        )
      }
    }
    Err(_) => fail("Symbol property with number index signature should parse")
  }
}

///|
test "Multiple Symbol properties with index signatures - no conflict" {
  let source =
    #|declare const mySymbol: unique symbol;
    #|interface I3 {
    #|    [mySymbol]: string;
    #|    [Symbol.iterator]: number;
    #|    [key: string]: boolean;
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(typed) => {
      let has_index_sig_error = typed.diagnostics
        .iter()
        .any(fn(d) {
          d.code == 2745 &&
          d.message.contains("not assignable to") &&
          d.message.contains("index type")
        })
      if has_index_sig_error {
        fail(
          "Multiple Symbol properties should not conflict with index signatures",
        )
      }
    }
    Err(_) =>
      fail("Multiple Symbol properties with index signature should parse")
  }
}

///|
test "Regular property SHOULD be checked against index signature" {
  let source =
    #|interface I {
    #|    name: string;
    #|    [key: string]: number;
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(typed) => {
      // Regular properties SHOULD be validated against index signatures
      // This should have a TS2745 error because string property 'name' conflicts with string index signature
      let has_expected_error = typed.diagnostics
        .iter()
        .any(fn(d) {
          d.code == 2745 &&
          d.message.contains("name") &&
          d.message.contains("not assignable to")
        })
      if not(has_expected_error) {
        fail(
          "Regular properties SHOULD be validated against index signatures (this is a control test)",
        )
      }
    }
    Err(_) => () // Also acceptable - parse error
  }
}

// ============================================================================
// TS2464: Computed Property Name Type Validation
// Tests that computed property names must be of type 'string', 'number', 'symbol', or 'any'
// ============================================================================

///|
test "TS2464: Computed property with typeof Symbol should error" {
  let source =
    #|var s = Symbol;
    #|var x = {
    #|    [s]: 0
    #|};
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(typed) => {
      let has_ts2464 = typed.diagnostics
        .iter()
        .any(fn(d) {
          d.code == 2464 &&
          d.message.contains(
            "A computed property name must be of type 'string', 'number', 'symbol', or 'any'",
          )
        })
      if not(has_ts2464) {
        fail("Should report TS2464 for computed property with typeof Symbol")
      }
    }
    Err(_) => () // Also acceptable
  }
}

///|
test "TS2464: Computed method with typeof Symbol should error" {
  let source =
    #|var s = Symbol;
    #|var x = {
    #|    [s]() { }
    #|};
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(typed) => {
      let has_ts2464 = typed.diagnostics
        .iter()
        .any(fn(d) {
          d.code == 2464 &&
          d.message.contains(
            "A computed property name must be of type 'string', 'number', 'symbol', or 'any'",
          )
        })
      if not(has_ts2464) {
        fail("Should report TS2464 for computed method with typeof Symbol")
      }
    }
    Err(_) => () // Also acceptable
  }
}

///|
test "TS2464: Computed getter with typeof Symbol should error" {
  let source =
    #|var s = Symbol;
    #|var x = {
    #|    get [s]() { return 0; }
    #|};
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(typed) => {
      let has_ts2464 = typed.diagnostics
        .iter()
        .any(fn(d) {
          d.code == 2464 &&
          d.message.contains(
            "A computed property name must be of type 'string', 'number', 'symbol', or 'any'",
          )
        })
      if not(has_ts2464) {
        fail("Should report TS2464 for computed getter with typeof Symbol")
      }
    }
    Err(_) => () // Also acceptable
  }
}

///|
test "TS2464: Computed setter with typeof Symbol should error" {
  let source =
    #|var s = Symbol;
    #|var x = {
    #|    set [s](v) { }
    #|};
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(typed) => {
      let has_ts2464 = typed.diagnostics
        .iter()
        .any(fn(d) {
          d.code == 2464 &&
          d.message.contains(
            "A computed property name must be of type 'string', 'number', 'symbol', or 'any'",
          )
        })
      if not(has_ts2464) {
        fail("Should report TS2464 for computed setter with typeof Symbol")
      }
    }
    Err(_) => () // Also acceptable
  }
}

///|
test "TS2464: Computed property with Symbol.iterator (valid) should pass" {
  let source =
    #|var x = {
    #|    [Symbol.iterator]: 0
    #|};
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(typed) => {
      let has_ts2464 = typed.diagnostics
        .iter()
        .any(fn(d) { d.code == 2464 })
      if has_ts2464 {
        fail(
          "Should NOT report TS2464 for computed property with Symbol.iterator (symbol type)",
        )
      }
    }
    Err(_) => fail("Computed property with Symbol.iterator should parse")
  }
}

///|
test "TS2464: Computed property with string literal (valid) should pass" {
  let source =
    #|var x = {
    #|    ["key"]: 0
    #|};
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(typed) => {
      let has_ts2464 = typed.diagnostics
        .iter()
        .any(fn(d) { d.code == 2464 })
      if has_ts2464 {
        fail("Should NOT report TS2464 for computed property with string literal")
      }
    }
    Err(_) => fail("Computed property with string literal should parse")
  }
}

///|
test "TS2464: Computed property with number literal (valid) should pass" {
  let source =
    #|var x = {
    #|    [42]: 0
    #|};
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(typed) => {
      let has_ts2464 = typed.diagnostics
        .iter()
        .any(fn(d) { d.code == 2464 })
      if has_ts2464 {
        fail("Should NOT report TS2464 for computed property with number literal")
      }
    }
    Err(_) => fail("Computed property with number literal should parse")
  }
}
