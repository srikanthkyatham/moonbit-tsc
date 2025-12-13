///| Unit tests for TS2466: 'super' cannot be referenced in a computed property name
///| Tests validation of super expressions in computed property names

test "TS2466: Super call in object literal computed property should trigger error" {
  let source =
    #|class Base {}
    #|class C extends Base {
    #|    constructor() {
    #|        super();
    #|        var obj = {
    #|            [(super(), "prop")]() { }
    #|        };
    #|    }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2466 = diagnostics.iter().any(fn(d) { d.code == 2466 })
      if has_ts2466 {
        println("✓ Super call in object literal computed property correctly detected (TS2466)")
        assert_true(true)
      } else {
        println("Expected TS2466 error for super() in computed property, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2466 error for super() in computed property but got no errors")
      assert_false(true)
    }
  }
}

test "TS2466: Super member access in class method should trigger error" {
  let source =
    #|class Base {
    #|    bar() { return 0; }
    #|}
    #|class C extends Base {
    #|    [super.bar()]() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2466 = diagnostics.iter().any(fn(d) { d.code == 2466 })
      if has_ts2466 {
        println("✓ Super member access in class method correctly detected (TS2466)")
        assert_true(true)
      } else {
        println("Expected TS2466 error for super.bar() in computed property, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2466 error for super.bar() in computed property but got no errors")
      assert_false(true)
    }
  }
}

test "TS2466: Super in nested object literal should trigger error" {
  let source =
    #|class Base {
    #|    bar() { return 0; }
    #|}
    #|class C extends Base {
    #|    [{ [super.bar()]: 1 }[0]]() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2466 = diagnostics.iter().any(fn(d) { d.code == 2466 })
      if has_ts2466 {
        println("✓ Super in nested object literal correctly detected (TS2466)")
        assert_true(true)
      } else {
        println("Expected TS2466 error for nested super, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2466 error for nested super but got no errors")
      assert_false(true)
    }
  }
}

test "TS2466: Super call in comma expression should trigger error" {
  let source =
    #|class Base {}
    #|class C extends Base {
    #|    [(super(), "prop")]() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2466 = diagnostics.iter().any(fn(d) { d.code == 2466 })
      if has_ts2466 {
        println("✓ Super call in comma expression correctly detected (TS2466)")
        assert_true(true)
      } else {
        println("Expected TS2466 error for super() in comma expression, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2466 error for super() in comma expression but got no errors")
      assert_false(true)
    }
  }
}

test "TS2466: Super in object literal computed assignment should trigger error" {
  let source =
    #|class Base {
    #|    bar() { return 0; }
    #|}
    #|class C extends Base {
    #|    foo() {
    #|        var obj = {
    #|            [super.bar()]: 123
    #|        };
    #|    }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2466 = diagnostics.iter().any(fn(d) { d.code == 2466 })
      if has_ts2466 {
        println("✓ Super in object literal computed assignment correctly detected (TS2466)")
        assert_true(true)
      } else {
        println("Expected TS2466 error for super in computed assignment, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2466 error for super in computed assignment but got no errors")
      assert_false(true)
    }
  }
}

test "TS2466: Super in object literal computed getter should trigger error" {
  let source =
    #|class Base {
    #|    bar() { return 0; }
    #|}
    #|class C extends Base {
    #|    foo() {
    #|        var obj = {
    #|            get [super.bar()]() { return 1; }
    #|        };
    #|    }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2466 = diagnostics.iter().any(fn(d) { d.code == 2466 })
      if has_ts2466 {
        println("✓ Super in object literal computed getter correctly detected (TS2466)")
        assert_true(true)
      } else {
        println("Expected TS2466 error for super in computed getter, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2466 error for super in computed getter but got no errors")
      assert_false(true)
    }
  }
}

test "TS2466: Super in object literal computed setter should trigger error" {
  let source =
    #|class Base {
    #|    bar() { return 0; }
    #|}
    #|class C extends Base {
    #|    foo() {
    #|        var obj = {
    #|            set [super.bar()](value) { }
    #|        };
    #|    }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2466 = diagnostics.iter().any(fn(d) { d.code == 2466 })
      if has_ts2466 {
        println("✓ Super in object literal computed setter correctly detected (TS2466)")
        assert_true(true)
      } else {
        println("Expected TS2466 error for super in computed setter, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2466 error for super in computed setter but got no errors")
      assert_false(true)
    }
  }
}

test "TS2466: Regular property name should NOT trigger error" {
  let source =
    #|class Base {
    #|    bar() { return 0; }
    #|}
    #|class C extends Base {
    #|    [123]() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ Regular computed property correctly accepted")
      assert_true(true)
    }
    Err(diagnostics) => {
      let has_ts2466 = diagnostics.iter().any(fn(d) { d.code == 2466 })
      if has_ts2466 {
        println("Regular computed property should NOT trigger TS2466, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        // Other errors are OK, just not TS2466
        println("✓ Regular computed property did not trigger TS2466 (other errors present)")
        assert_true(true)
      }
    }
  }
}

test "TS2466: Super in method body should NOT trigger error" {
  let source =
    #|class Base {
    #|    bar() { return 0; }
    #|}
    #|class C extends Base {
    #|    foo() {
    #|        return super.bar();
    #|    }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ Super in method body correctly accepted")
      assert_true(true)
    }
    Err(diagnostics) => {
      let has_ts2466 = diagnostics.iter().any(fn(d) { d.code == 2466 })
      if has_ts2466 {
        println("Super in method body should NOT trigger TS2466, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        // Other errors are OK, just not TS2466
        println("✓ Super in method body did not trigger TS2466 (other errors present)")
        assert_true(true)
      }
    }
  }
}

test "TS2466: Conformance test computedPropertyNames30_ES5" {
  let source =
    #|class Base {}
    #|class C extends Base {
    #|    constructor() {
    #|        super();
    #|        () => {
    #|            var obj = {
    #|                [(super(), "prop")]() { }
    #|            };
    #|        }
    #|    }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2466 = diagnostics.iter().any(fn(d) { d.code == 2466 })
      if has_ts2466 {
        println("✓ Conformance test 30 correctly detects TS2466")
        assert_true(true)
      } else {
        println("Expected TS2466 error for conformance test 30, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2466 error for conformance test 30 but got no errors")
      assert_false(true)
    }
  }
}
