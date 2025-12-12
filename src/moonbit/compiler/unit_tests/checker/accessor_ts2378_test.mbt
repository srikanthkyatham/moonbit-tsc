// Unit tests for TS2378: Get accessor must return a value
// Tests that get accessors without return statements are detected and reported

///|
test "TS2378 - get accessor with empty body" {
  let source =
    #|class C {
    #|    get value() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2378 error but got no errors")
      assert_true(false)
    }
    Err(diagnostics) => {
      if has_diagnostic_code(diagnostics, 2378) {
        assert_true(true)
      } else {
        println("Expected TS2378 but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_true(false)
      }
    }
  }
}

///|
test "TS2378 - static get accessor with empty body" {
  let source =
    #|class C {
    #|    static get value() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2378 error but got no errors")
      assert_true(false)
    }
    Err(diagnostics) => {
      if has_diagnostic_code(diagnostics, 2378) {
        assert_true(true)
      } else {
        println("Expected TS2378 but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_true(false)
      }
    }
  }
}

///|
test "TS2378 - get accessor with computed name and empty body" {
  let source =
    #|var accessorName = "accessor";
    #|class C {
    #|    get [accessorName]() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2378 error but got no errors")
      assert_true(false)
    }
    Err(diagnostics) => {
      if has_diagnostic_code(diagnostics, 2378) {
        assert_true(true)
      } else {
        println("Expected TS2378 but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_true(false)
      }
    }
  }
}

///|
test "TS2378 - get accessor with return statement should pass" {
  let source =
    #|class C {
    #|    get value() { return 42; }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      // Should not have TS2378 error
      if has_diagnostic_code(diagnostics, 2378) {
        println("Unexpected TS2378 error for get accessor with return")
        assert_true(false)
      } else {
        // Other errors are acceptable
        assert_true(true)
      }
    }
  }
}

///|
test "TS2378 - get accessor with return in if statement" {
  let source =
    #|class C {
    #|    get value() {
    #|        if (true) {
    #|            return 42;
    #|        }
    #|    }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      // Should not have TS2378 error - has return in if statement
      if has_diagnostic_code(diagnostics, 2378) {
        println("Unexpected TS2378 error for get accessor with return in if")
        assert_true(false)
      } else {
        // Other errors are acceptable
        assert_true(true)
      }
    }
  }
}

///|
test "TS2378 - set accessor without return should pass" {
  let source =
    #|class C {
    #|    set value(v: number) { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      // Should NOT have TS2378 error - TS2378 only applies to get accessors
      if has_diagnostic_code(diagnostics, 2378) {
        println("Unexpected TS2378 error for set accessor")
        assert_true(false)
      } else {
        // Other errors are acceptable
        assert_true(true)
      }
    }
  }
}

///|
test "TS2378 - regular method without return should pass" {
  let source =
    #|class C {
    #|    method() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      // Should NOT have TS2378 error - only get accessors require return
      if has_diagnostic_code(diagnostics, 2378) {
        println("Unexpected TS2378 error for regular method")
        assert_true(false)
      } else {
        // Other errors are acceptable
        assert_true(true)
      }
    }
  }
}

///|
test "TS2378 - get accessor with return in try block" {
  let source =
    #|class C {
    #|    get value() {
    #|        try {
    #|            return 42;
    #|        } catch (e) {
    #|            return 0;
    #|        }
    #|    }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      // Should not have TS2378 error
      if has_diagnostic_code(diagnostics, 2378) {
        println("Unexpected TS2378 error for get accessor with return in try")
        assert_true(false)
      } else {
        // Other errors are acceptable
        assert_true(true)
      }
    }
  }
}

///|
test "TS2378 - abstract get accessor without body should pass" {
  let source =
    #|abstract class C {
    #|    abstract get value(): number;
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      // Should NOT have TS2378 error - abstract accessors don't need bodies
      if has_diagnostic_code(diagnostics, 2378) {
        println("Unexpected TS2378 error for abstract get accessor")
        assert_true(false)
      } else {
        // Other errors are acceptable
        assert_true(true)
      }
    }
  }
}
