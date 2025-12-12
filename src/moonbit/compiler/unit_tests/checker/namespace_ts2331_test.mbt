// Unit tests for TS2331 validation - 'this' in module/namespace body
// Tests that 'this' cannot be referenced in namespace or module declarations

///|
test "TS2331 - 'this' in namespace computed property should error" {
  let source =
    #|namespace M {
    #|  var obj = {
    #|    [this.bar]: 0
    #|  }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2331 error but got no errors")
      assert_true(false)
    }
    Err(diagnostics) => {
      if has_diagnostic_code(diagnostics, 2331) {
        assert_true(true)
      } else {
        println("Expected TS2331 but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_true(false)
      }
    }
  }
}

///|
test "TS2331 - 'this' in namespace variable initializer should error" {
  let source =
    #|namespace N {
    #|  var x = this;
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2331 error but got no errors")
      assert_true(false)
    }
    Err(diagnostics) => {
      if has_diagnostic_code(diagnostics, 2331) {
        assert_true(true)
      } else {
        println("Expected TS2331 but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_true(false)
      }
    }
  }
}

///|
test "TS2331 - 'this' in module body should error" {
  let source =
    #|module M {
    #|  export var obj = {
    #|    prop: this.value
    #|  };
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2331 error but got no errors")
      assert_true(false)
    }
    Err(diagnostics) => {
      if has_diagnostic_code(diagnostics, 2331) {
        assert_true(true)
      } else {
        println("Expected TS2331 but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_true(false)
      }
    }
  }
}

///|
test "TS2331 - 'this' in nested namespace should error" {
  let source =
    #|namespace Outer {
    #|  namespace Inner {
    #|    var x = this.prop;
    #|  }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2331 error but got no errors")
      assert_true(false)
    }
    Err(diagnostics) => {
      if has_diagnostic_code(diagnostics, 2331) {
        assert_true(true)
      } else {
        println("Expected TS2331 but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_true(false)
      }
    }
  }
}

///|
test "TS2331 - 'this' in function inside namespace should pass" {
  let source =
    #|namespace M {
    #|  export function foo() {
    #|    return this;
    #|  }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      // Should not have TS2331 error - 'this' is allowed in function body
      if has_diagnostic_code(diagnostics, 2331) {
        println("Unexpected TS2331 error for 'this' in function inside namespace")
        assert_true(false)
      } else {
        // Other errors are fine (e.g., implicit 'this' type)
        assert_true(true)
      }
    }
  }
}

///|
test "TS2331 - 'this' in class method inside namespace should pass" {
  let source =
    #|namespace M {
    #|  export class C {
    #|    method() {
    #|      return this.value;
    #|    }
    #|    value: number = 42;
    #|  }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      // Should not have TS2331 error - 'this' is allowed in class methods
      if has_diagnostic_code(diagnostics, 2331) {
        println("Unexpected TS2331 error for 'this' in class method inside namespace")
        assert_true(false)
      } else {
        // Other errors are fine
        println("Got non-TS2331 errors (acceptable):")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_true(true)
      }
    }
  }
}

///|
test "TS2331 - 'this' in arrow function inside namespace should pass" {
  let source =
    #|namespace M {
    #|  export const foo = () => this;
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      // Should not have TS2331 error - arrow functions capture 'this' from enclosing scope
      // However, since the enclosing scope is a namespace, it might have other issues
      if has_diagnostic_code(diagnostics, 2331) {
        println("Unexpected TS2331 error for 'this' in arrow function inside namespace")
        assert_true(false)
      } else {
        // Other errors are acceptable
        assert_true(true)
      }
    }
  }
}
