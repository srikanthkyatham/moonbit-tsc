///| Unit tests for TS2466 arrow function depth validation
///| Tests that TS2466 only applies in arrow function contexts, not constructors/methods
///| This validates the fix for computedPropertyNames28_ES5.ts and computedPropertyNames28_ES6.ts

// Test 1: Object literal with super() in constructor should PASS (not in arrow function)
test "TS2466: Object literal with super() in constructor should pass" {
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
    Ok(_) => {
      println("✓ Object literal with super() in constructor correctly passes (not in arrow function)")
      assert_true(true)
    }
    Err(diagnostics) => {
      let has_ts2466 = diagnostics.iter().any(fn(d) { d.code == 2466 })
      if has_ts2466 {
        println("✗ Object literal with super() in constructor should NOT trigger TS2466 (arrow_function_depth=0)")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        // Other errors are OK, just not TS2466
        println("✓ Object literal with super() in constructor did not trigger TS2466 (other errors present)")
        assert_true(true)
      }
    }
  }
}

// Test 2: Object literal with super() in arrow function should ERROR with TS2466
test "TS2466: Object literal with super() in arrow function should error" {
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
        println("✓ Object literal with super() in arrow function correctly triggers TS2466")
        assert_true(true)
      } else {
        println("✗ Expected TS2466 error for super() in arrow function object literal, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("✗ Expected TS2466 error for super() in arrow function object literal but got no errors")
      assert_false(true)
    }
  }
}

// Test 3: Object literal with super() in regular method should PASS
test "TS2466: Object literal with super() in regular method should pass" {
  let source =
    #|class Base {}
    #|class C extends Base {
    #|    method() {
    #|        var obj = {
    #|            [(super(), "prop")]() { }
    #|        };
    #|    }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ Object literal with super() in regular method correctly passes")
      assert_true(true)
    }
    Err(diagnostics) => {
      let has_ts2466 = diagnostics.iter().any(fn(d) { d.code == 2466 })
      if has_ts2466 {
        println("✗ Object literal with super() in regular method should NOT trigger TS2466")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        println("✓ Object literal with super() in regular method did not trigger TS2466 (other errors present)")
        assert_true(true)
      }
    }
  }
}

// Test 4: Class member computed property with super() should ERROR with TS2466
test "TS2466: Class member computed property with super() should error" {
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
        println("✓ Class member computed property with super() correctly triggers TS2466")
        assert_true(true)
      } else {
        println("✗ Expected TS2466 error for class member computed property with super(), but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("✗ Expected TS2466 error for class member computed property with super() but got no errors")
      assert_false(true)
    }
  }
}

// Test 5: Object literal with super.property in constructor should PASS
test "TS2466: Object literal with super.property in constructor should pass" {
  let source =
    #|class Base {
    #|    prop = "key";
    #|}
    #|class C extends Base {
    #|    constructor() {
    #|        super();
    #|        var obj = {
    #|            [super.prop]: 123
    #|        };
    #|    }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ Object literal with super.property in constructor correctly passes")
      assert_true(true)
    }
    Err(diagnostics) => {
      let has_ts2466 = diagnostics.iter().any(fn(d) { d.code == 2466 })
      if has_ts2466 {
        println("✗ Object literal with super.property in constructor should NOT trigger TS2466")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        println("✓ Object literal with super.property in constructor did not trigger TS2466 (other errors present)")
        assert_true(true)
      }
    }
  }
}

// Test 6: Object literal with super.method() in arrow function should PASS (not a bare super call)
test "TS2466: Object literal with super.method() in arrow function should pass (not bare super call)" {
  let source =
    #|class Base {
    #|    bar() { return "key"; }
    #|}
    #|class C extends Base {
    #|    constructor() {
    #|        super();
    #|        () => {
    #|            var obj = {
    #|                [super.bar()]: 123
    #|            };
    #|        }
    #|    }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ Object literal with super.method() in arrow function correctly passes (not bare super call)")
      assert_true(true)
    }
    Err(diagnostics) => {
      let has_ts2466 = diagnostics.iter().any(fn(d) { d.code == 2466 })
      if has_ts2466 {
        println("✗ Object literal with super.method() in arrow function should NOT trigger TS2466 (only bare super() calls)")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        println("✓ Object literal with super.method() in arrow function did not trigger TS2466 (other errors present)")
        assert_true(true)
      }
    }
  }
}

// Test 7: Nested arrow function - object literal with super() should ERROR with TS2466
test "TS2466: Nested arrow function object literal with super() should error" {
  let source =
    #|class Base {}
    #|class C extends Base {
    #|    method() {
    #|        const fn1 = () => {
    #|            const fn2 = () => {
    #|                var obj = {
    #|                    [(super(), "prop")]() { }
    #|                };
    #|            };
    #|        };
    #|    }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2466 = diagnostics.iter().any(fn(d) { d.code == 2466 })
      if has_ts2466 {
        println("✓ Nested arrow function object literal with super() correctly triggers TS2466")
        assert_true(true)
      } else {
        println("✗ Expected TS2466 error for super() in nested arrow function object literal, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("✗ Expected TS2466 error for super() in nested arrow function object literal but got no errors")
      assert_false(true)
    }
  }
}

// Test 8: Object literal computed getter with super() in constructor should PASS
test "TS2466: Object literal computed getter with super() in constructor should pass" {
  let source =
    #|class Base {}
    #|class C extends Base {
    #|    constructor() {
    #|        super();
    #|        var obj = {
    #|            get [(super(), "prop")]() { return 1; }
    #|        };
    #|    }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ Object literal computed getter with super() in constructor correctly passes")
      assert_true(true)
    }
    Err(diagnostics) => {
      let has_ts2466 = diagnostics.iter().any(fn(d) { d.code == 2466 })
      if has_ts2466 {
        println("✗ Object literal computed getter with super() in constructor should NOT trigger TS2466")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        println("✓ Object literal computed getter with super() in constructor did not trigger TS2466 (other errors present)")
        assert_true(true)
      }
    }
  }
}

// Test 9: Object literal computed setter with super() in constructor should PASS
test "TS2466: Object literal computed setter with super() in constructor should pass" {
  let source =
    #|class Base {}
    #|class C extends Base {
    #|    constructor() {
    #|        super();
    #|        var obj = {
    #|            set [(super(), "prop")](value) { }
    #|        };
    #|    }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ Object literal computed setter with super() in constructor correctly passes")
      assert_true(true)
    }
    Err(diagnostics) => {
      let has_ts2466 = diagnostics.iter().any(fn(d) { d.code == 2466 })
      if has_ts2466 {
        println("✗ Object literal computed setter with super() in constructor should NOT trigger TS2466")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        println("✓ Object literal computed setter with super() in constructor did not trigger TS2466 (other errors present)")
        assert_true(true)
      }
    }
  }
}

// Test 10: Object literal computed method with super() in constructor should PASS
test "TS2466: Object literal computed method with super() in constructor should pass" {
  let source =
    #|class Base {}
    #|class C extends Base {
    #|    constructor() {
    #|        super();
    #|        var obj = {
    #|            [(super(), "method")]() { return 42; }
    #|        };
    #|    }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ Object literal computed method with super() in constructor correctly passes")
      assert_true(true)
    }
    Err(diagnostics) => {
      let has_ts2466 = diagnostics.iter().any(fn(d) { d.code == 2466 })
      if has_ts2466 {
        println("✗ Object literal computed method with super() in constructor should NOT trigger TS2466")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        println("✓ Object literal computed method with super() in constructor did not trigger TS2466 (other errors present)")
        assert_true(true)
      }
    }
  }
}

// Test 11: Conformance test computedPropertyNames28_ES5 exact reproduction
test "TS2466: Conformance test computedPropertyNames28_ES5 should pass" {
  let source =
    #|// @target: es5
    #|class Base {
    #|}
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
    Ok(_) => {
      println("✓ Conformance test computedPropertyNames28_ES5 correctly passes")
      assert_true(true)
    }
    Err(diagnostics) => {
      let has_ts2466 = diagnostics.iter().any(fn(d) { d.code == 2466 })
      if has_ts2466 {
        println("✗ Conformance test computedPropertyNames28_ES5 should NOT trigger TS2466")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        println("✓ Conformance test computedPropertyNames28_ES5 did not trigger TS2466 (other errors present)")
        assert_true(true)
      }
    }
  }
}

// Test 12: Conformance test computedPropertyNames28_ES6 exact reproduction
test "TS2466: Conformance test computedPropertyNames28_ES6 should pass" {
  let source =
    #|// @target: es6
    #|class Base {
    #|}
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
    Ok(_) => {
      println("✓ Conformance test computedPropertyNames28_ES6 correctly passes")
      assert_true(true)
    }
    Err(diagnostics) => {
      let has_ts2466 = diagnostics.iter().any(fn(d) { d.code == 2466 })
      if has_ts2466 {
        println("✗ Conformance test computedPropertyNames28_ES6 should NOT trigger TS2466")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        println("✓ Conformance test computedPropertyNames28_ES6 did not trigger TS2466 (other errors present)")
        assert_true(true)
      }
    }
  }
}
