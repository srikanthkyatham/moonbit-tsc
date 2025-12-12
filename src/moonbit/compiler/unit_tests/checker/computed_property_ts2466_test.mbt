// Unit tests for TS2466: 'super' cannot be referenced in a computed property name
// Tests that 'super' usage in computed property names is detected and reported

///|
test "TS2466 - 'super' in method call within computed property name" {
  let source =
    #|class Base {
    #|    bar() { return 0; }
    #|}
    #|class C extends Base {
    #|    [super.bar()]() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2466 error but got no errors")
      assert_true(false)
    }
    Err(diagnostics) => {
      if has_diagnostic_code(diagnostics, 2466) {
        assert_true(true)
      } else {
        println("Expected TS2466 but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_true(false)
      }
    }
  }
}

///|
test "TS2466 - 'super' in property access within computed property name" {
  let source =
    #|class Base {
    #|    prop = "key";
    #|}
    #|class C extends Base {
    #|    [super.prop]: number = 42;
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2466 error but got no errors")
      assert_true(false)
    }
    Err(diagnostics) => {
      if has_diagnostic_code(diagnostics, 2466) {
        assert_true(true)
      } else {
        println("Expected TS2466 but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_true(false)
      }
    }
  }
}

///|
test "TS2466 - 'super' in nested object literal computed property" {
  let source =
    #|class Base {
    #|    bar() { return 0; }
    #|}
    #|class C extends Base {
    #|    [{ [super.bar()]: 1 }[0]]() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2466 error but got no errors")
      assert_true(false)
    }
    Err(diagnostics) => {
      if has_diagnostic_code(diagnostics, 2466) {
        assert_true(true)
      } else {
        println("Expected TS2466 but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_true(false)
      }
    }
  }
}

///|
test "TS2466 - 'super' in expression within computed property name" {
  let source =
    #|class Base {
    #|    x = 10;
    #|}
    #|class C extends Base {
    #|    [super.x + 5]: number = 42;
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2466 error but got no errors")
      assert_true(false)
    }
    Err(diagnostics) => {
      if has_diagnostic_code(diagnostics, 2466) {
        assert_true(true)
      } else {
        println("Expected TS2466 but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_true(false)
      }
    }
  }
}

///|
test "TS2466 - valid computed property without 'super'" {
  let source =
    #|const sym = Symbol();
    #|class Base {}
    #|class C extends Base {
    #|    [sym]() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      // Should not have TS2466 error
      if has_diagnostic_code(diagnostics, 2466) {
        println("Unexpected TS2466 error for valid computed property without 'super'")
        assert_true(false)
      } else {
        // Other errors are fine
        assert_true(true)
      }
    }
  }
}

///|
test "TS2466 - valid computed property with string literal" {
  let source =
    #|class Base {}
    #|class C extends Base {
    #|    ["key"]() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      // Should not have TS2466 error
      if has_diagnostic_code(diagnostics, 2466) {
        println("Unexpected TS2466 error for valid string literal computed property")
        assert_true(false)
      } else {
        // Other errors are fine
        assert_true(true)
      }
    }
  }
}

///|
test "TS2466 - 'super' in method body is valid (not in computed property)" {
  let source =
    #|class Base {
    #|    bar() { return 0; }
    #|}
    #|class C extends Base {
    #|    method() {
    #|        return super.bar();
    #|    }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      // Should not have TS2466 error - 'super' is allowed in method body
      if has_diagnostic_code(diagnostics, 2466) {
        println("Unexpected TS2466 error for 'super' in method body")
        assert_true(false)
      } else {
        // Other errors are acceptable
        assert_true(true)
      }
    }
  }
}

///|
test "TS2466 - 'super' in object literal computed property is valid" {
  let source =
    #|class Base {
    #|    bar() { return 0; }
    #|}
    #|class C extends Base {
    #|    foo() {
    #|        var obj = {
    #|            [super.bar()]() { }
    #|        };
    #|        return 0;
    #|    }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      // TS2466 doesn't apply to object literals, only class members
      // So we might get other errors, but not TS2466
      if has_diagnostic_code(diagnostics, 2466) {
        println("Unexpected TS2466 error for 'super' in object literal")
        assert_true(false)
      } else {
        // Other errors are acceptable
        assert_true(true)
      }
    }
  }
}
