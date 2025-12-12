// Unit tests for Symbol.keyFor builtin method

///|
test "Symbol.keyFor should be defined with correct signature" {
  let source =
    #|const key = Symbol.keyFor(Symbol.for("myKey"));

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
test "Symbol.keyFor in interface computed property should error TS2464" {
  let source =
    #|interface I {
    #|  [Symbol.keyFor]: string;
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
test "Symbol.keyFor should accept symbol argument" {
  let source =
    #|const sym = Symbol("test");
    #|const key = Symbol.keyFor(sym);

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
test "Symbol.keyFor return type should be string | undefined" {
  let source =
    #|const key: string | undefined = Symbol.keyFor(Symbol.for("test"));

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
