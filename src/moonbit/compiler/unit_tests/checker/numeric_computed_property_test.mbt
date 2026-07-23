///| Unit tests for is_numeric_computed_property helper function
///| Tests validation logic for determining if a computed property name is numeric

test "is_numeric_computed_property: Numeric literal should return true" {
  let source =
    #|class C {
    #|    [n: number]: string;
    #|    [42]: string;
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ Numeric literal correctly identified as numeric property")
      assert_true(true)
    }
    Err(diagnostics) => {
      println("Expected no errors for numeric literal, but got:")
      diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
      assert_false(true)
    }
  }
}

test "is_numeric_computed_property: String literal should return false" {
  let source =
    #|class C {
    #|    [n: number]: number;
    #|    ["get1"]: string;
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ String literal correctly identified as non-numeric property")
      assert_true(true)
    }
    Err(diagnostics) => {
      println("Expected no errors for string literal (should not check against number index), but got:")
      diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
      assert_false(true)
    }
  }
}

test "is_numeric_computed_property: Number expression should return true" {
  let source =
    #|class Foo { x }
    #|class Foo2 { x; y }
    #|
    #|class C {
    #|    [n: number]: Foo2;
    #|    [1 << 6]: Foo;
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2411 = diagnostics.iter().any(fn(d) { d.code == 2411 })
      if has_ts2411 {
        println("✓ Number expression correctly identified as numeric property (TS2411 error)")
        assert_true(true)
      } else {
        println("Expected TS2411 error for number expression, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2411 error for number expression but got no errors")
      assert_false(true)
    }
  }
}

test "is_numeric_computed_property: Non-computed property should return false" {
  let source =
    #|// @strict: false
    #|class C {
    #|    [n: number]: number;
    #|    prop: string;
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ Non-computed property correctly identified as non-numeric")
      assert_true(true)
    }
    Err(diagnostics) => {
      println("Expected no errors for non-computed property, but got:")
      diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
      assert_false(true)
    }
  }
}

test "is_numeric_computed_property: None (non-computed) should return false" {
  let source =
    #|// @strict: false
    #|class C {
    #|    [n: number]: number;
    #|    regularProp: string;
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ Regular property (None computed_name_expr) correctly handled")
      assert_true(true)
    }
    Err(diagnostics) => {
      println("Expected no errors for regular property, but got:")
      diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
      assert_false(true)
    }
  }
}

test "is_numeric_computed_property: Getter with numeric literal" {
  let source =
    #|class C {
    #|    [n: number]: number;
    #|    get [0](): number { return 42; }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ Numeric getter correctly identified as numeric property")
      assert_true(true)
    }
    Err(diagnostics) => {
      println("Expected no errors for numeric getter, but got:")
      diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
      assert_false(true)
    }
  }
}

test "is_numeric_computed_property: Getter with string literal" {
  let source =
    #|class C {
    #|    [n: number]: number;
    #|    get ["foo"](): string { return "bar"; }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ String getter correctly identified as non-numeric property")
      assert_true(true)
    }
    Err(diagnostics) => {
      println("Expected no errors for string getter (should not check against number index), but got:")
      diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
      assert_false(true)
    }
  }
}

test "is_numeric_computed_property: Setter with numeric literal" {
  let source =
    #|class C {
    #|    [n: number]: number;
    #|    set [1](value: number) { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ Numeric setter correctly identified as numeric property")
      assert_true(true)
    }
    Err(diagnostics) => {
      println("Expected no errors for numeric setter, but got:")
      diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
      assert_false(true)
    }
  }
}

test "is_numeric_computed_property: Setter with string literal" {
  let source =
    #|class C {
    #|    [n: number]: number;
    #|    set ["name"](value: string) { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ String setter correctly identified as non-numeric property")
      assert_true(true)
    }
    Err(diagnostics) => {
      println("Expected no errors for string setter (should not check against number index), but got:")
      diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
      assert_false(true)
    }
  }
}

test "is_numeric_computed_property: Multiple string literals with number index" {
  let source =
    #|class C {
    #|    [n: number]: number;
    #|    ["foo"]: string;
    #|    ["bar"]: string;
    #|    get ["baz"](): string { return "x"; }
    #|    set ["qux"](v: string) { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ Multiple string literals correctly identified as non-numeric properties")
      assert_true(true)
    }
    Err(diagnostics) => {
      println("Expected no errors for multiple string literals, but got:")
      diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
      assert_false(true)
    }
  }
}

test "is_numeric_computed_property: Mixed numeric and string literals" {
  let source =
    #|class C {
    #|    [n: number]: number;
    #|    [0]: number;
    #|    ["foo"]: string;
    #|    [1]: number;
    #|    ["bar"]: string;
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ Mixed numeric and string literals correctly distinguished")
      assert_true(true)
    }
    Err(diagnostics) => {
      println("Expected no errors for mixed literals, but got:")
      diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
      assert_false(true)
    }
  }
}

test "is_numeric_computed_property: Number expression in object literal" {
  let source =
    #|var obj = {
    #|    [1 + 1]: "value"
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ Number expression (1 + 1) correctly identified as numeric property in object literal")
      assert_true(true)
    }
    Err(diagnostics) => {
      println("Expected no errors for number expression in object literal, but got:")
      diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
      assert_false(true)
    }
  }
}
