// Unit tests for TS2464 validation in interface computed properties
// Tests validation of computed property names in interfaces

///|
test "TS2464 - Interface with object computed property should error" {
  let source =
    #|const obj = {};
    #|interface I {
    #|  [obj]: string;
    #|}
    #|const x: I = { };

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
test "TS2464 - Interface with valid symbol computed property should pass" {
  let source =
    #|interface I {
    #|  [Symbol.iterator]: string;
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Expected no errors but got \{diagnostics.length()} diagnostics:")
      diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
      assert_true(false)
    }
  }
}

///|
test "TS2464 - Interface with string literal computed property should pass" {
  let source =
    #|interface I {
    #|  ["key"]: string;
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Expected no errors but got \{diagnostics.length()} diagnostics:")
      diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
      assert_true(false)
    }
  }
}

///|
test "TS2464 - Interface with number literal computed property should pass" {
  let source =
    #|interface I {
    #|  [42]: string;
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Expected no errors but got \{diagnostics.length()} diagnostics:")
      diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
      assert_true(false)
    }
  }
}

///|
test "TS2464 - Interface with method having invalid computed name should error" {
  let source =
    #|const obj = {};
    #|interface I {
    #|  [obj](x: number): string;
    #|}
    #|const x: I = null as any;

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
