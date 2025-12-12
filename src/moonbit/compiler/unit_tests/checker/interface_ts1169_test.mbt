// Unit tests for TS1169: Interface computed property names must be literal or unique symbol types
// Tests that non-literal computed property names in interfaces are detected and reported

///|
test "TS1169 - interface with non-literal function call result" {
  let source =
    #|function foo() { return '' }
    #|interface I {
    #|    [foo()]: string;
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS1169 error but got no errors")
      assert_true(false)
    }
    Err(diagnostics) => {
      if has_diagnostic_code(diagnostics, 1169) {
        assert_true(true)
      } else {
        println("Expected TS1169 but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_true(false)
      }
    }
  }
}

///|
test "TS1169 - interface with binary expression result" {
  let source =
    #|interface I {
    #|    ["" + ""]: string;
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS1169 error but got no errors")
      assert_true(false)
    }
    Err(diagnostics) => {
      if has_diagnostic_code(diagnostics, 1169) {
        assert_true(true)
      } else {
        println("Expected TS1169 but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_true(false)
      }
    }
  }
}

///|
test "TS1169 - interface with member expression (obj.prop)" {
  let source =
    #|const obj = { prop: "key" };
    #|interface I {
    #|    [obj.prop]: number;
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS1169 error but got no errors")
      assert_true(false)
    }
    Err(diagnostics) => {
      if has_diagnostic_code(diagnostics, 1169) {
        assert_true(true)
      } else {
        println("Expected TS1169 but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_true(false)
      }
    }
  }
}

///|
test "TS1169 - interface with valid string literal" {
  let source =
    #|interface I {
    #|    ["literal"]: string;
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      // Should not have TS1169 error - string literals are allowed
      if has_diagnostic_code(diagnostics, 1169) {
        println("Unexpected TS1169 error for string literal")
        assert_true(false)
      } else {
        // Other errors are acceptable
        assert_true(true)
      }
    }
  }
}

///|
test "TS1169 - interface with valid number literal" {
  let source =
    #|interface I {
    #|    [42]: string;
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      // Should not have TS1169 error - number literals are allowed
      if has_diagnostic_code(diagnostics, 1169) {
        println("Unexpected TS1169 error for number literal")
        assert_true(false)
      } else {
        // Other errors are acceptable
        assert_true(true)
      }
    }
  }
}

///|
test "TS1169 - interface with valid template literal (no substitutions)" {
  let source =
    #|interface I {
    #|    [`key`]: string;
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      // Should not have TS1169 error - template literals without substitutions are literals
      if has_diagnostic_code(diagnostics, 1169) {
        println("Unexpected TS1169 error for template literal without substitutions")
        assert_true(false)
      } else {
        // Other errors are acceptable
        assert_true(true)
      }
    }
  }
}

///|
test "TS1169 - interface method with non-literal computed name" {
  let source =
    #|function foo() { return '' }
    #|interface I {
    #|    [foo()](): void;
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS1169 error but got no errors")
      assert_true(false)
    }
    Err(diagnostics) => {
      if has_diagnostic_code(diagnostics, 1169) {
        assert_true(true)
      } else {
        println("Expected TS1169 but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_true(false)
      }
    }
  }
}

///|
test "TS1169 - class with non-literal computed name should NOT trigger TS1169" {
  let source =
    #|function foo() { return '' }
    #|class C {
    #|    [foo()]: string;
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      // Should NOT have TS1169 error - TS1169 only applies to interfaces
      if has_diagnostic_code(diagnostics, 1169) {
        println("Unexpected TS1169 error for class (TS1169 is interface-only)")
        assert_true(false)
      } else {
        // Other errors (like TS1166 for classes) are expected
        assert_true(true)
      }
    }
  }
}

///|
test "TS1169 - interface with Symbol.iterator should pass" {
  let source =
    #|interface I {
    #|    [Symbol.iterator]: number;
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      // Should not have TS1169 error - Symbol is allowed
      if has_diagnostic_code(diagnostics, 1169) {
        println("Unexpected TS1169 error for Symbol")
        assert_true(false)
      } else {
        // Other errors are acceptable
        assert_true(true)
      }
    }
  }
}
