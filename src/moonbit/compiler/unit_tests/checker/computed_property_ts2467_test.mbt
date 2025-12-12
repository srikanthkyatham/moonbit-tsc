// Unit tests for TS2467: Type parameter references in computed property names
// Tests that type parameter references in computed property names are detected and reported

///|
test "TS2467 - class computed property with type parameter in call expression" {
  let source =
    #|function foo<T>() { return '' }
    #|class C<T> {
    #|    bar() {
    #|        return 0;
    #|    }
    #|    [foo<T>()]() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2467 error but got no errors")
      assert_true(false)
    }
    Err(diagnostics) => {
      if has_diagnostic_code(diagnostics, 2467) {
        assert_true(true)
      } else {
        println("Expected TS2467 but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_true(false)
      }
    }
  }
}

///|
test "TS2467 - interface computed property with type parameter" {
  let source =
    #|function foo<T>() { return '' }
    #|interface I<T> {
    #|    bar(): string;
    #|    [foo<T>()](): void;
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2467 error but got no errors")
      assert_true(false)
    }
    Err(diagnostics) => {
      if has_diagnostic_code(diagnostics, 2467) {
        assert_true(true)
      } else {
        println("Expected TS2467 but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_true(false)
      }
    }
  }
}

///|
test "TS2467 - class property with type parameter" {
  let source =
    #|function getProp<T>() { return 'key' }
    #|class C<T> {
    #|    [getProp<T>()]: number = 42;
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2467 error but got no errors")
      assert_true(false)
    }
    Err(diagnostics) => {
      if has_diagnostic_code(diagnostics, 2467) {
        assert_true(true)
      } else {
        println("Expected TS2467 but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_true(false)
      }
    }
  }
}

///|
test "TS2467 - multiple type parameters, one referenced" {
  let source =
    #|function foo<T, U>() { return '' }
    #|class C<T, U> {
    #|    [foo<T, string>()]() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2467 error but got no errors")
      assert_true(false)
    }
    Err(diagnostics) => {
      if has_diagnostic_code(diagnostics, 2467) {
        assert_true(true)
      } else {
        println("Expected TS2467 but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_true(false)
      }
    }
  }
}

///|
test "TS2467 - nested expression with type parameter in binary operation" {
  let source =
    #|function getId<T>() { return 'id' }
    #|class C<T> {
    #|    [getId<T>() + '2']() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2467 error but got no errors")
      assert_true(false)
    }
    Err(diagnostics) => {
      if has_diagnostic_code(diagnostics, 2467) {
        assert_true(true)
      } else {
        println("Expected TS2467 but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_true(false)
      }
    }
  }
}

///|
test "TS2467 - valid computed property without type parameter reference" {
  let source =
    #|const sym = Symbol();
    #|class C<T> {
    #|    [sym]() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      // Should not have TS2467 error
      if has_diagnostic_code(diagnostics, 2467) {
        println("Unexpected TS2467 error for valid computed property")
        assert_true(false)
      } else {
        // Other errors are fine
        assert_true(true)
      }
    }
  }
}

///|
test "TS2467 - valid call expression with non-type parameter" {
  let source =
    #|function foo<U>() { return '' }
    #|class C<T> {
    #|    [foo<string>()]() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      // Should not have TS2467 error when type parameter doesn't match
      if has_diagnostic_code(diagnostics, 2467) {
        println("Unexpected TS2467 error for non-matching type parameter")
        assert_true(false)
      } else {
        // Other errors are acceptable
        assert_true(true)
      }
    }
  }
}

///|
test "TS2467 - valid method body with type parameter (not in computed name)" {
  let source =
    #|function foo<T>() { return '' }
    #|class C<T> {
    #|    method() {
    #|        return foo<T>();
    #|    }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      // Should not have TS2467 error - type parameter in method body is allowed
      if has_diagnostic_code(diagnostics, 2467) {
        println("Unexpected TS2467 error for type parameter in method body")
        assert_true(false)
      } else {
        // Other errors are acceptable
        assert_true(true)
      }
    }
  }
}

///|
test "TS2467 - class without type parameters should not error" {
  let source =
    #|function foo<T>() { return '' }
    #|class C {
    #|    [foo<string>()]() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      // Should not have TS2467 error when class has no type parameters
      if has_diagnostic_code(diagnostics, 2467) {
        println("Unexpected TS2467 error for class without type parameters")
        assert_true(false)
      } else {
        // Other errors are acceptable
        assert_true(true)
      }
    }
  }
}
