// Unit tests for TS2411: Property type not assignable to index signature

test "TS2411: Property with incompatible type should error" {
  let source =
    #|class C {
    #|    [s: string]: number;
    #|    x: number;
    #|    y: string;
    #|}

  let result = parse_bind_check_errors(source)

  match result {
    Err(diagnostics) => {
      let has_ts2411 = diagnostics.iter().any(fn(d) { d.code == 2411 })
      if has_ts2411 {
        println("✓ TS2411: Property with incompatible type correctly errors")
        assert_true(true)
      } else {
        println("Expected TS2411 error but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2411 error but got no errors")
      assert_false(true)
    }
  }
}

test "TS2411: Getter with incompatible return type should error" {
  let source =
    #|class Foo { x }
    #|class Foo2 { x; y }
    #|
    #|class C {
    #|    [s: string]: Foo2;
    #|    get prop1() { return new Foo }
    #|}

  let result = parse_bind_check_errors(source)

  match result {
    Err(diagnostics) => {
      let has_ts2411 = diagnostics.iter().any(fn(d) { d.code == 2411 })
      if has_ts2411 {
        println("✓ TS2411: Getter with incompatible return type correctly errors")
        assert_true(true)
      } else {
        println("Expected TS2411 error but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2411 error but got no errors")
      assert_false(true)
    }
  }
}

test "TS2411: Computed getter with incompatible return type should error" {
  let source =
    #|class Foo { x }
    #|class Foo2 { x; y }
    #|
    #|class C {
    #|    [s: string]: Foo2;
    #|    get ["get1"]() { return new Foo }
    #|}

  let result = parse_bind_check_errors(source)

  match result {
    Err(diagnostics) => {
      let has_ts2411 = diagnostics.iter().any(fn(d) { d.code == 2411 })
      if has_ts2411 {
        println("✓ TS2411: Computed getter with incompatible type correctly errors")
        assert_true(true)
      } else {
        println("Expected TS2411 error but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2411 error but got no errors")
      assert_false(true)
    }
  }
}

test "TS2411: Compatible property types should pass" {
  let source =
    #|class C {
    #|    [s: string]: number;
    #|    x: number;
    #|    y: number;
    #|}

  let result = parse_bind_check_errors(source)

  match result {
    Ok(_) => {
      println("✓ TS2411: Compatible property types correctly pass")
      assert_true(true)
    }
    Err(diagnostics) => {
      let has_ts2411 = diagnostics.iter().any(fn(d) { d.code == 2411 })
      if has_ts2411 {
        println("Should not have TS2411 error when types are compatible:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        println("✓ TS2411: No false positive")
        assert_true(true)
      }
    }
  }
}

test "TS2411: Compatible getter should pass" {
  let source =
    #|class Foo { x; y }
    #|
    #|class C {
    #|    [s: string]: Foo;
    #|    get prop1() { return new Foo }
    #|}

  let result = parse_bind_check_errors(source)

  match result {
    Ok(_) => {
      println("✓ TS2411: Compatible getter correctly passes")
      assert_true(true)
    }
    Err(diagnostics) => {
      let has_ts2411 = diagnostics.iter().any(fn(d) { d.code == 2411 })
      if has_ts2411 {
        println("Should not have TS2411 error when getter type is compatible:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        println("✓ TS2411: No false positive for getter")
        assert_true(true)
      }
    }
  }
}

test "TS2411: No index signature should not validate" {
  let source =
    #|class C {
    #|    x: number;
    #|    y: string;
    #|}

  let result = parse_bind_check_errors(source)

  match result {
    Ok(_) => {
      println("✓ TS2411: No validation when no index signature")
      assert_true(true)
    }
    Err(diagnostics) => {
      let has_ts2411 = diagnostics.iter().any(fn(d) { d.code == 2411 })
      if has_ts2411 {
        println("Should not validate without index signature:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        println("✓ TS2411: No false positive without index signature")
        assert_true(true)
      }
    }
  }
}

test "TS2411: Static members should not be validated" {
  let source =
    #|class C {
    #|    [s: string]: () => number;
    #|    static ["computed"]() { return 42; }
    #|    static regularMethod() { return 1; }
    #|    static prop: string = "test";
    #|}

  let result = parse_bind_check_errors(source)

  match result {
    Ok(_) => {
      println("✓ TS2411: Static members correctly skipped")
      assert_true(true)
    }
    Err(diagnostics) => {
      let has_ts2411 = diagnostics.iter().any(fn(d) { d.code == 2411 })
      if has_ts2411 {
        println("Should not validate static members:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        println("✓ TS2411: No false positive for static members")
        assert_true(true)
      }
    }
  }
}

test "TS2411: Static computed method should pass (computedPropertyNames41)" {
  let source =
    #|class Foo { x }
    #|class Foo2 { x; y }
    #|
    #|class C {
    #|    [s: string]: () => Foo2;
    #|    static [""]() { return new Foo }
    #|}

  let result = parse_bind_check_errors(source)

  match result {
    Ok(_) => {
      println("✓ TS2411: computedPropertyNames41 correctly passes")
      assert_true(true)
    }
    Err(diagnostics) => {
      let has_ts2411 = diagnostics.iter().any(fn(d) { d.code == 2411 })
      if has_ts2411 {
        println("computedPropertyNames41 should pass (static method):")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        println("✓ TS2411: No false positive for computedPropertyNames41")
        assert_true(true)
      }
    }
  }
}

// Tests for computed property validation

test "TS2411: Computed property with string literal should error" {
  let source =
    #|class Foo { x }
    #|class Foo2 { x; y }
    #|
    #|class C {
    #|    [s: string]: Foo2;
    #|    [""]: Foo;
    #|}

  let result = parse_bind_check_errors(source)

  match result {
    Err(diagnostics) => {
      let has_ts2411 = diagnostics.iter().any(fn(d) { d.code == 2411 })
      if has_ts2411 {
        println("✓ TS2411: Computed property with string literal correctly errors")
        assert_true(true)
      } else {
        println("Expected TS2411 error but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2411 error but got no errors")
      assert_false(true)
    }
  }
}

test "TS2411: Computed property with compatible type should pass" {
  let source =
    #|class Foo { x; y }
    #|
    #|class C {
    #|    [s: string]: Foo;
    #|    [""]: Foo;
    #|}

  let result = parse_bind_check_errors(source)

  match result {
    Ok(_) => {
      println("✓ TS2411: Computed property with compatible type correctly passes")
      assert_true(true)
    }
    Err(diagnostics) => {
      let has_ts2411 = diagnostics.iter().any(fn(d) { d.code == 2411 })
      if has_ts2411 {
        println("Should not have TS2411 error when computed property type is compatible:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        println("✓ TS2411: No false positive for compatible computed property")
        assert_true(true)
      }
    }
  }
}

test "TS2411: Computed getter with string literal should error" {
  let source =
    #|class Foo { x }
    #|class Foo2 { x; y }
    #|
    #|class C {
    #|    [s: string]: Foo2;
    #|    get ["get1"]() { return new Foo }
    #|}

  let result = parse_bind_check_errors(source)

  match result {
    Err(diagnostics) => {
      let has_ts2411 = diagnostics.iter().any(fn(d) { d.code == 2411 })
      if has_ts2411 {
        println("✓ TS2411: Computed getter with string literal correctly errors")
        assert_true(true)
      } else {
        println("Expected TS2411 error but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2411 error but got no errors")
      assert_false(true)
    }
  }
}

test "TS2411: Computed getter with compatible type should pass" {
  let source =
    #|class Foo { x; y }
    #|
    #|class C {
    #|    [s: string]: Foo;
    #|    get ["get1"]() { return new Foo }
    #|}

  let result = parse_bind_check_errors(source)

  match result {
    Ok(_) => {
      println("✓ TS2411: Computed getter with compatible type correctly passes")
      assert_true(true)
    }
    Err(diagnostics) => {
      let has_ts2411 = diagnostics.iter().any(fn(d) { d.code == 2411 })
      if has_ts2411 {
        println("Should not have TS2411 error when computed getter type is compatible:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        println("✓ TS2411: No false positive for compatible computed getter")
        assert_true(true)
      }
    }
  }
}

test "TS2411: Computed getter with numeric expression should error" {
  let source =
    #|class Foo { x }
    #|class Foo2 { x; y }
    #|
    #|class C {
    #|    [s: string]: Foo2;
    #|    get [1 << 6]() { return new Foo }
    #|}

  let result = parse_bind_check_errors(source)

  match result {
    Err(diagnostics) => {
      let has_ts2411 = diagnostics.iter().any(fn(d) { d.code == 2411 })
      if has_ts2411 {
        println("✓ TS2411: Computed getter with numeric expression correctly errors")
        assert_true(true)
      } else {
        println("Expected TS2411 error but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2411 error but got no errors")
      assert_false(true)
    }
  }
}

test "TS2411: Computed property with numeric literal should error" {
  let source =
    #|class Foo { x }
    #|class Foo2 { x; y }
    #|
    #|class C {
    #|    [s: string]: Foo2;
    #|    [42]: Foo;
    #|}

  let result = parse_bind_check_errors(source)

  match result {
    Err(diagnostics) => {
      let has_ts2411 = diagnostics.iter().any(fn(d) { d.code == 2411 })
      if has_ts2411 {
        println("✓ TS2411: Computed property with numeric literal correctly errors")
        assert_true(true)
      } else {
        println("Expected TS2411 error but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2411 error but got no errors")
      assert_false(true)
    }
  }
}

test "TS2411: Static computed property should not error" {
  let source =
    #|class Foo { x }
    #|class Foo2 { x; y }
    #|
    #|class C {
    #|    [s: string]: Foo2;
    #|    static [""]: Foo;
    #|}

  let result = parse_bind_check_errors(source)

  match result {
    Ok(_) => {
      println("✓ TS2411: Static computed property correctly passes")
      assert_true(true)
    }
    Err(diagnostics) => {
      let has_ts2411 = diagnostics.iter().any(fn(d) { d.code == 2411 })
      if has_ts2411 {
        println("Should not have TS2411 error for static computed property:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        println("✓ TS2411: No false positive for static computed property")
        assert_true(true)
      }
    }
  }
}

test "TS2411: Static computed getter should not error" {
  let source =
    #|class Foo { x }
    #|class Foo2 { x; y }
    #|
    #|class C {
    #|    [s: string]: Foo2;
    #|    static get ["prop"]() { return new Foo }
    #|}

  let result = parse_bind_check_errors(source)

  match result {
    Ok(_) => {
      println("✓ TS2411: Static computed getter correctly passes")
      assert_true(true)
    }
    Err(diagnostics) => {
      let has_ts2411 = diagnostics.iter().any(fn(d) { d.code == 2411 })
      if has_ts2411 {
        println("Should not have TS2411 error for static computed getter:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        println("✓ TS2411: No false positive for static computed getter")
        assert_true(true)
      }
    }
  }
}

test "TS2411: Multiple computed properties with mixed compatibility" {
  let source =
    #|class Foo { x }
    #|class Foo2 { x; y }
    #|
    #|class C {
    #|    [s: string]: Foo2;
    #|    [""]: Foo;
    #|    ["valid"]: Foo2;
    #|    [42]: Foo;
    #|}

  let result = parse_bind_check_errors(source)

  match result {
    Err(diagnostics) => {
      let ts2411_count = diagnostics
        .iter()
        .filter(fn(d) { d.code == 2411 })
        .fold(init=0, fn(count, _d) { count + 1 })
      if ts2411_count == 2 {
        println("✓ TS2411: Multiple computed properties correctly report 2 errors")
        assert_true(true)
      } else {
        println("Expected 2 TS2411 errors but got \{ts2411_count}:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2411 errors but got no errors")
      assert_false(true)
    }
  }
}

test "TS2411: Computed property and getter combined" {
  let source =
    #|class Foo { x }
    #|class Foo2 { x; y }
    #|
    #|class C {
    #|    [s: string]: Foo2;
    #|    [""]: Foo;
    #|    get ["get1"]() { return new Foo }
    #|}

  let result = parse_bind_check_errors(source)

  match result {
    Err(diagnostics) => {
      let ts2411_count = diagnostics
        .iter()
        .filter(fn(d) { d.code == 2411 })
        .fold(init=0, fn(count, _d) { count + 1 })
      if ts2411_count == 2 {
        println("✓ TS2411: Computed property and getter both correctly error")
        assert_true(true)
      } else {
        println("Expected 2 TS2411 errors but got \{ts2411_count}:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2411 errors but got no errors")
      assert_false(true)
    }
  }
}
// ============================================================================
// SETTER VALIDATION TESTS
// ============================================================================

test "TS2411: Setter with incompatible type should error" {
  let source =
    #|class Foo { x }
    #|class Foo2 { x; y }
    #|
    #|class C {
    #|    [s: string]: Foo2;
    #|    set prop(p: Foo) { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2411 = diagnostics.iter().any(fn(d) { d.code == 2411 })
      if has_ts2411 {
        println("✓ TS2411: Setter with incompatible type correctly errors")
        assert_true(true)
      } else {
        println("Expected TS2411 error but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2411 error but got no errors")
      assert_false(true)
    }
  }
}

test "TS2411: Setter with compatible type should pass" {
  let source =
    #|class Foo { x }
    #|class Foo2 { x; y }
    #|
    #|class C {
    #|    [s: string]: Foo2;
    #|    set prop(p: Foo2) { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2411 = diagnostics.iter().any(fn(d) { d.code == 2411 })
      if has_ts2411 {
        println("Expected setter to pass but got TS2411:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        println("✓ TS2411: Setter with compatible type correctly passes (other errors ok)")
        assert_true(true)
      }
    }
    Ok(_) => {
      println("✓ TS2411: Setter with compatible type correctly passes")
      assert_true(true)
    }
  }
}

test "TS2411: Static setter should not be validated" {
  let source =
    #|class Foo { x }
    #|class Foo2 { x; y }
    #|
    #|class C {
    #|    [s: string]: Foo2;
    #|    static set prop(p: Foo) { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2411 = diagnostics.iter().any(fn(d) { d.code == 2411 })
      if has_ts2411 {
        println("Static setter should not be validated but got TS2411:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        println("✓ TS2411: Static setter correctly skipped (other errors ok)")
        assert_true(true)
      }
    }
    Ok(_) => {
      println("✓ TS2411: Static setter correctly skipped")
      assert_true(true)
    }
  }
}

test "TS2411: Computed setter with string literal should error" {
  let source =
    #|class Foo { x }
    #|class Foo2 { x; y }
    #|
    #|class C {
    #|    [s: string]: Foo2;
    #|    set ["prop"](p: Foo) { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2411 = diagnostics.iter().any(fn(d) { d.code == 2411 })
      if has_ts2411 {
        println("✓ TS2411: Computed setter with string literal correctly errors")
        assert_true(true)
      } else {
        println("Expected TS2411 error but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2411 error but got no errors")
      assert_false(true)
    }
  }
}

test "TS2411: Static computed setter should not be validated" {
  let source =
    #|class Foo { x }
    #|class Foo2 { x; y }
    #|
    #|class C {
    #|    [s: string]: Foo2;
    #|    static set ["prop"](p: Foo) { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2411 = diagnostics.iter().any(fn(d) { d.code == 2411 })
      if has_ts2411 {
        println("Static computed setter should not be validated but got TS2411:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        println("✓ TS2411: Static computed setter correctly skipped")
        assert_true(true)
      }
    }
    Ok(_) => {
      println("✓ TS2411: Static computed setter correctly skipped")
      assert_true(true)
    }
  }
}

// ============================================================================
// NUMBER INDEX SIGNATURE TESTS
// ============================================================================

test "TS2411: Property with numeric literal and number index should error" {
  let source =
    #|class Foo { x }
    #|class Foo2 { x; y }
    #|
    #|class C {
    #|    [n: number]: Foo2;
    #|    [42]: Foo;
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2411 = diagnostics.iter().any(fn(d) { d.code == 2411 })
      if has_ts2411 {
        println("✓ TS2411: Numeric property correctly errors with number index")
        assert_true(true)
      } else {
        println("Expected TS2411 error but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2411 error but got no errors")
      assert_false(true)
    }
  }
}

test "TS2411: Property with numeric literal and compatible number index should pass" {
  let source =
    #|class Foo { x }
    #|class Foo2 { x; y }
    #|
    #|class C {
    #|    [n: number]: Foo2;
    #|    [42]: Foo2;
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2411 = diagnostics.iter().any(fn(d) { d.code == 2411 })
      if has_ts2411 {
        println("Expected numeric property to pass but got TS2411:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        println("✓ TS2411: Numeric property with compatible type correctly passes")
        assert_true(true)
      }
    }
    Ok(_) => {
      println("✓ TS2411: Numeric property with compatible type correctly passes")
      assert_true(true)
    }
  }
}

test "TS2411: Getter with numeric expression and number index should error" {
  let source =
    #|class Foo { x }
    #|class Foo2 { x; y }
    #|
    #|class C {
    #|    [n: number]: Foo2;
    #|    get [1 << 6]() { return new Foo }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2411 = diagnostics.iter().any(fn(d) { d.code == 2411 })
      if has_ts2411 {
        println("✓ TS2411: Numeric getter correctly errors with number index")
        assert_true(true)
      } else {
        println("Expected TS2411 error but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2411 error but got no errors")
      assert_false(true)
    }
  }
}

test "TS2411: Setter with numeric literal and number index should error" {
  let source =
    #|class Foo { x }
    #|class Foo2 { x; y }
    #|
    #|class C {
    #|    [n: number]: Foo2;
    #|    set [42](p: Foo) { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2411 = diagnostics.iter().any(fn(d) { d.code == 2411 })
      if has_ts2411 {
        println("✓ TS2411: Numeric setter correctly errors with number index")
        assert_true(true)
      } else {
        println("Expected TS2411 error but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2411 error but got no errors")
      assert_false(true)
    }
  }
}

test "TS2411: Setter with numeric literal and compatible number index should pass" {
  let source =
    #|class Foo { x }
    #|class Foo2 { x; y }
    #|
    #|class C {
    #|    [n: number]: Foo2;
    #|    set [42](p: Foo2) { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2411 = diagnostics.iter().any(fn(d) { d.code == 2411 })
      if has_ts2411 {
        println("Expected numeric setter to pass but got TS2411:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        println("✓ TS2411: Numeric setter with compatible type correctly passes")
        assert_true(true)
      }
    }
    Ok(_) => {
      println("✓ TS2411: Numeric setter with compatible type correctly passes")
      assert_true(true)
    }
  }
}

// ============================================================================
// INHERITANCE WITH SETTER TESTS
// ============================================================================

test "TS2411: Derived class setter vs base class string index should error" {
  let source =
    #|class Foo { x }
    #|class Foo2 { x; y }
    #|
    #|class C {
    #|    [s: string]: Foo2;
    #|}
    #|
    #|class D extends C {
    #|    set ["prop"](p: Foo) { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2411 = diagnostics.iter().any(fn(d) { d.code == 2411 })
      if has_ts2411 {
        println("✓ TS2411: Derived setter vs base index correctly errors")
        assert_true(true)
      } else {
        println("Expected TS2411 error but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2411 error but got no errors")
      assert_false(true)
    }
  }
}

test "TS2411: Base class setter vs derived class string index should error" {
  let source =
    #|class Foo { x }
    #|class Foo2 { x; y }
    #|
    #|class C {
    #|    set ["prop"](p: Foo) { }
    #|}
    #|
    #|class D extends C {
    #|    [s: string]: Foo2;
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2411 = diagnostics.iter().any(fn(d) { d.code == 2411 })
      if has_ts2411 {
        println("✓ TS2411: Base setter vs derived index correctly errors")
        assert_true(true)
      } else {
        println("Expected TS2411 error but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2411 error but got no errors")
      assert_false(true)
    }
  }
}

test "TS2411: Multiple setters and getters with mixed compatibility" {
  let source =
    #|class Foo { x }
    #|class Foo2 { x; y }
    #|
    #|class C {
    #|    [s: string]: Foo2;
    #|    get ["get1"]() { return new Foo }
    #|    set ["set1"](p: Foo) { }
    #|    get ["get2"]() { return new Foo2 }
    #|    set ["set2"](p: Foo2) { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let ts2411_count = diagnostics
        .iter()
        .filter(fn(d) { d.code == 2411 })
        .fold(init=0, fn(count, _d) { count + 1 })
      if ts2411_count == 2 {
        println("✓ TS2411: Multiple accessors correctly report 2 errors (incompatible getter and setter)")
        assert_true(true)
      } else {
        println("Expected 2 TS2411 errors but got \{ts2411_count}:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2411 errors but got no errors")
      assert_false(true)
    }
  }
}

test "TS2411: Derived class with both getter and setter vs base index" {
  let source =
    #|class Foo { x }
    #|class Foo2 { x; y }
    #|
    #|class C {
    #|    [s: string]: Foo2;
    #|}
    #|
    #|class D extends C {
    #|    get ["prop"]() { return new Foo }
    #|    set ["prop"](p: Foo) { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let ts2411_count = diagnostics
        .iter()
        .filter(fn(d) { d.code == 2411 })
        .fold(init=0, fn(count, _d) { count + 1 })
      if ts2411_count == 2 {
        println("✓ TS2411: Both getter and setter correctly error against base index")
        assert_true(true)
      } else {
        println("Expected 2 TS2411 errors but got \{ts2411_count}:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2411 errors but got no errors")
      assert_false(true)
    }
  }
}
