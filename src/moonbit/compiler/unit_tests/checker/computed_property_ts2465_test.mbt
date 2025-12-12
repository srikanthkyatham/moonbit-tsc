// Unit tests for TS2465: 'this' cannot be referenced in a computed property name
// Tests that 'this' usage in computed property names is detected and reported

///|
test "TS2465 - 'this' in property access within computed property name" {
  let source =
    #|class C {
    #|    prop = "key";
    #|    [this.prop]: number = 42;
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2465 error but got no errors")
      assert_true(false)
    }
    Err(diagnostics) => {
      if has_diagnostic_code(diagnostics, 2465) {
        assert_true(true)
      } else {
        println("Expected TS2465 but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_true(false)
      }
    }
  }
}

///|
test "TS2465 - 'this' in method call within computed property name" {
  let source =
    #|class C {
    #|    bar() {
    #|        return 0;
    #|    }
    #|    [this.bar()]() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2465 error but got no errors")
      assert_true(false)
    }
    Err(diagnostics) => {
      if has_diagnostic_code(diagnostics, 2465) {
        assert_true(true)
      } else {
        println("Expected TS2465 but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_true(false)
      }
    }
  }
}

///|
test "TS2465 - 'this' in getter computed property name" {
  let source =
    #|class C {
    #|    prop = "key";
    #|    get [this.prop]() {
    #|        return 42;
    #|    }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2465 error but got no errors")
      assert_true(false)
    }
    Err(diagnostics) => {
      if has_diagnostic_code(diagnostics, 2465) {
        assert_true(true)
      } else {
        println("Expected TS2465 but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_true(false)
      }
    }
  }
}

///|
test "TS2465 - 'this' in setter computed property name" {
  let source =
    #|class C {
    #|    prop = "key";
    #|    set [this.prop](value: number) { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2465 error but got no errors")
      assert_true(false)
    }
    Err(diagnostics) => {
      if has_diagnostic_code(diagnostics, 2465) {
        assert_true(true)
      } else {
        println("Expected TS2465 but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_true(false)
      }
    }
  }
}

///|
test "TS2465 - 'this' in nested expression within computed property name" {
  let source =
    #|class C {
    #|    x = 10;
    #|    [this.x + 5]: number = 42;
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2465 error but got no errors")
      assert_true(false)
    }
    Err(diagnostics) => {
      if has_diagnostic_code(diagnostics, 2465) {
        assert_true(true)
      } else {
        println("Expected TS2465 but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_true(false)
      }
    }
  }
}

///|
test "TS2465 - 'this' in conditional expression within computed property name" {
  let source =
    #|class C {
    #|    flag = true;
    #|    key = "a";
    #|    [this.flag ? this.key : "b"]: number = 42;
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2465 error but got no errors")
      assert_true(false)
    }
    Err(diagnostics) => {
      if has_diagnostic_code(diagnostics, 2465) {
        assert_true(true)
      } else {
        println("Expected TS2465 but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_true(false)
      }
    }
  }
}

///|
test "TS2465 - valid computed property without 'this'" {
  let source =
    #|const sym = Symbol();
    #|class C {
    #|    [sym]: number = 42;
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      // Should not have TS2465 error
      if has_diagnostic_code(diagnostics, 2465) {
        println("Unexpected TS2465 error for valid computed property without 'this'")
        assert_true(false)
      } else {
        // Other errors are fine
        assert_true(true)
      }
    }
  }
}

///|
test "TS2465 - valid computed property with string literal" {
  let source =
    #|class C {
    #|    ["key"]: number = 42;
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      // Should not have TS2465 error
      if has_diagnostic_code(diagnostics, 2465) {
        println("Unexpected TS2465 error for valid string literal computed property")
        assert_true(false)
      } else {
        // Other errors are fine
        assert_true(true)
      }
    }
  }
}

///|
test "TS2465 - valid method with regular identifier (no computed property)" {
  let source =
    #|class C {
    #|    method() {
    #|        return this.value;
    #|    }
    #|    value: number = 42;
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      // Should not have TS2465 error
      if has_diagnostic_code(diagnostics, 2465) {
        println("Unexpected TS2465 error for regular method with 'this' in body")
        assert_true(false)
      } else {
        // Other errors are acceptable
        assert_true(true)
      }
    }
  }
}
