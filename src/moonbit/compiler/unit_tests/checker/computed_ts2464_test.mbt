// Unit tests for TS2464: A computed property name must be of type 'string', 'number', 'symbol', or 'any'
// Tests that computed property names with invalid types are detected and reported

///|
test "TS2464 - computed property with boolean type" {
  let source =
    #|var b: boolean = true;
    #|var v = {
    #|    [b]: 0
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2464 error but got no errors")
      assert_true(false)
    }
    Err(diagnostics) => {
      if has_diagnostic_code(diagnostics, 2464) {
        assert_true(true)
      } else {
        println("Expected TS2464 but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_true(false)
      }
    }
  }
}

///|
test "TS2464 - computed property with object type" {
  let source =
    #|var obj = { prop: "key" };
    #|var v = {
    #|    [obj]: 0
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2464 error but got no errors")
      assert_true(false)
    }
    Err(diagnostics) => {
      if has_diagnostic_code(diagnostics, 2464) {
        assert_true(true)
      } else {
        println("Expected TS2464 but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_true(false)
      }
    }
  }
}

///|
test "TS2464 - computed property with string type should pass" {
  let source =
    #|var s: string = "key";
    #|var v = {
    #|    [s]: 0
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      // Should NOT have TS2464 error - string is valid
      if has_diagnostic_code(diagnostics, 2464) {
        println("Unexpected TS2464 error for string type")
        assert_true(false)
      } else {
        // Other errors are acceptable
        assert_true(true)
      }
    }
  }
}

///|
test "TS2464 - computed property with number type should pass" {
  let source =
    #|var n: number = 42;
    #|var v = {
    #|    [n]: 0
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      // Should NOT have TS2464 error - number is valid
      if has_diagnostic_code(diagnostics, 2464) {
        println("Unexpected TS2464 error for number type")
        assert_true(false)
      } else {
        // Other errors are acceptable
        assert_true(true)
      }
    }
  }
}

///|
test "TS2464 - computed property with symbol type should pass" {
  let source =
    #|var sym: symbol = Symbol();
    #|var v = {
    #|    [sym]: 0
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      // Should NOT have TS2464 error - symbol is valid
      if has_diagnostic_code(diagnostics, 2464) {
        println("Unexpected TS2464 error for symbol type")
        assert_true(false)
      } else {
        // Other errors are acceptable
        assert_true(true)
      }
    }
  }
}

///|
test "TS2464 - computed property with any type should pass" {
  let source =
    #|var a: any = "key";
    #|var v = {
    #|    [a]: 0
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      // Should NOT have TS2464 error - any is valid
      if has_diagnostic_code(diagnostics, 2464) {
        println("Unexpected TS2464 error for any type")
        assert_true(false)
      } else {
        // Other errors are acceptable
        assert_true(true)
      }
    }
  }
}

///|
test "TS2464 - computed property with string literal type should pass" {
  let source =
    #|var v = {
    #|    ["literal"]: 0
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      // Should NOT have TS2464 error - string literal is valid
      if has_diagnostic_code(diagnostics, 2464) {
        println("Unexpected TS2464 error for string literal")
        assert_true(false)
      } else {
        // Other errors are acceptable
        assert_true(true)
      }
    }
  }
}

///|
test "TS2464 - computed property in class with boolean type" {
  let source =
    #|var b: boolean = true;
    #|class C {
    #|    [b] = 42;
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2464 or TS1166 error but got no errors")
      assert_true(false)
    }
    Err(diagnostics) => {
      // For class properties, TS1166 is checked first and is more specific
      // Either TS1166 or TS2464 is acceptable
      if has_diagnostic_code(diagnostics, 2464) || has_diagnostic_code(diagnostics, 1166) {
        assert_true(true)
      } else {
        println("Expected TS2464 or TS1166 but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_true(false)
      }
    }
  }
}
