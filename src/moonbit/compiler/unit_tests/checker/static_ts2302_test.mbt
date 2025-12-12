// Unit tests for TS2302: Static members cannot reference class type parameters
// Tests that static members using class type parameters are detected and reported

///|
test "TS2302 - static method with class type parameter in call expression" {
  let source =
    #|class C<T> {
    #|    static method() {
    #|        function foo<U>() { return ''; }
    #|        foo<T>();
    #|    }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2302 error but got no errors")
      assert_true(false)
    }
    Err(diagnostics) => {
      if has_diagnostic_code(diagnostics, 2302) {
        assert_true(true)
      } else {
        println("Expected TS2302 but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_true(false)
      }
    }
  }
}

///|
test "TS2302 - static method with class type parameter in new expression" {
  let source =
    #|class C<T> {
    #|    static method() {
    #|        class Box<U> { }
    #|        new Box<T>();
    #|    }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2302 error but got no errors")
      assert_true(false)
    }
    Err(diagnostics) => {
      if has_diagnostic_code(diagnostics, 2302) {
        assert_true(true)
      } else {
        println("Expected TS2302 but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_true(false)
      }
    }
  }
}

///|
test "TS2302 - static property initializer with class type parameter" {
  let source =
    #|function foo<T>() { return ''; }
    #|class C<T> {
    #|    static prop = foo<T>();
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2302 error but got no errors")
      assert_true(false)
    }
    Err(diagnostics) => {
      if has_diagnostic_code(diagnostics, 2302) {
        assert_true(true)
      } else {
        println("Expected TS2302 but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_true(false)
      }
    }
  }
}

///|
test "TS2302 - instance method with class type parameter should pass" {
  let source =
    #|class C<T> {
    #|    method() {
    #|        function foo<U>() { return ''; }
    #|        foo<T>();
    #|    }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      // Should NOT have TS2302 error - instance methods can use class type parameters
      if has_diagnostic_code(diagnostics, 2302) {
        println("Unexpected TS2302 error for instance method")
        assert_true(false)
      } else {
        // Other errors are acceptable
        assert_true(true)
      }
    }
  }
}

///|
test "TS2302 - static method with non-class type parameter should pass" {
  let source =
    #|class C<T> {
    #|    static method<U>() {
    #|        function foo<V>() { return ''; }
    #|        foo<U>();
    #|    }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      // Should NOT have TS2302 error - U is a method type parameter, not class type parameter
      if has_diagnostic_code(diagnostics, 2302) {
        println("Unexpected TS2302 error for method type parameter")
        assert_true(false)
      } else {
        // Other errors are acceptable
        assert_true(true)
      }
    }
  }
}

///|
test "TS2302 - constructor with class type parameter should pass" {
  let source =
    #|class C<T> {
    #|    constructor() {
    #|        function foo<U>() { return ''; }
    #|        foo<T>();
    #|    }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      // Should NOT have TS2302 error - constructors can use class type parameters
      if has_diagnostic_code(diagnostics, 2302) {
        println("Unexpected TS2302 error for constructor")
        assert_true(false)
      } else {
        // Other errors are acceptable
        assert_true(true)
      }
    }
  }
}

///|
test "TS2302 - nested static method with class type parameter" {
  let source =
    #|class C<T> {
    #|    static method() {
    #|        var obj = {
    #|            method() {
    #|                function foo<U>() { return ''; }
    #|                foo<T>();
    #|            }
    #|        };
    #|    }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2302 error but got no errors")
      assert_true(false)
    }
    Err(diagnostics) => {
      if has_diagnostic_code(diagnostics, 2302) {
        assert_true(true)
      } else {
        println("Expected TS2302 but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_true(false)
      }
    }
  }
}

///|
test "TS2302 - multiple class type parameters" {
  let source =
    #|class C<T, U> {
    #|    static method() {
    #|        function foo<V>() { return ''; }
    #|        foo<U>();
    #|    }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2302 error but got no errors")
      assert_true(false)
    }
    Err(diagnostics) => {
      if has_diagnostic_code(diagnostics, 2302) {
        assert_true(true)
      } else {
        println("Expected TS2302 but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_true(false)
      }
    }
  }
}
