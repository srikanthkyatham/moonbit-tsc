///| Unit tests for TS2300: Duplicate identifier
///| Tests validation of duplicate property names in object literals

test "TS2300: Duplicate regular properties should trigger error" {
  let source =
    #|var obj = {
    #|    foo: 1,
    #|    bar: 2,
    #|    foo: 3
    #|};

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let ts2300_count = diagnostics.iter().filter(fn(d) { d.code == 2300 }).count()
      if ts2300_count == 2 {
        println("✓ Duplicate properties correctly detected (2 TS2300 errors)")
        assert_true(true)
      } else {
        println("Expected 2 TS2300 errors, but got \{ts2300_count}:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(ts2300_count == 2)
      }
    }
    Ok(_) => {
      println("Expected TS2300 errors for duplicate properties but got no errors")
      assert_false(true)
    }
  }
}

test "TS2300: Duplicate getters should trigger error" {
  let source =
    #|var obj = {
    #|    get foo() { return 1; },
    #|    get bar() { return 2; },
    #|    get foo() { return 3; }
    #|};

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let ts2300_count = diagnostics.iter().filter(fn(d) { d.code == 2300 }).count()
      if ts2300_count == 2 {
        println("✓ Duplicate getters correctly detected (2 TS2300 errors)")
        assert_true(true)
      } else {
        println("Expected 2 TS2300 errors, but got \{ts2300_count}:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(ts2300_count == 2)
      }
    }
    Ok(_) => {
      println("Expected TS2300 errors for duplicate getters but got no errors")
      assert_false(true)
    }
  }
}

test "TS2300: Three duplicate properties should trigger error" {
  let source =
    #|var obj = {
    #|    foo: 1,
    #|    foo: 2,
    #|    foo: 3
    #|};

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let ts2300_count = diagnostics.iter().filter(fn(d) { d.code == 2300 }).count()
      if ts2300_count == 3 {
        println("✓ Three duplicates correctly detected (3 TS2300 errors)")
        assert_true(true)
      } else {
        println("Expected 3 TS2300 errors, but got \{ts2300_count}:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(ts2300_count == 3)
      }
    }
    Ok(_) => {
      println("Expected TS2300 errors for three duplicates but got no errors")
      assert_false(true)
    }
  }
}

test "TS2300: Non-duplicate properties should NOT trigger error" {
  let source =
    #|var obj = {
    #|    foo: 1,
    #|    bar: 2,
    #|    baz: 3
    #|};

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ Non-duplicate properties correctly accepted")
      assert_true(true)
    }
    Err(diagnostics) => {
      let has_ts2300 = diagnostics.iter().any(fn(d) { d.code == 2300 })
      if has_ts2300 {
        println("Non-duplicate properties should NOT trigger TS2300, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        println("✓ Non-duplicate properties did not trigger TS2300 (other errors present)")
        assert_true(true)
      }
    }
  }
}

test "TS2300: Different property types should NOT trigger error" {
  let source =
    #|var obj = {
    #|    foo: 1,
    #|    bar: "hello",
    #|    baz: true
    #|};

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ Different property types correctly accepted")
      assert_true(true)
    }
    Err(diagnostics) => {
      let has_ts2300 = diagnostics.iter().any(fn(d) { d.code == 2300 })
      if has_ts2300 {
        println("Different property types should NOT trigger TS2300, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        println("✓ Different property types did not trigger TS2300 (other errors present)")
        assert_true(true)
      }
    }
  }
}

test "TS2300: Conformance test computedPropertyNames49_ES5" {
  let source =
    #|var x = {
    #|    p1: 10,
    #|    get [1 + 1]() {
    #|        throw 10;
    #|    },
    #|    get [1 + 1]() {
    #|        return 10;
    #|    },
    #|    set [1 + 1]() {
    #|        throw 10;
    #|    },
    #|    get foo() {
    #|        if (1 == 1) {
    #|            return 10;
    #|        }
    #|    },
    #|    get foo() {
    #|        if (2 == 2) {
    #|            return 20;
    #|        }
    #|    },
    #|    p2: 20
    #|};

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let ts2300_count = diagnostics.iter().filter(fn(d) { d.code == 2300 }).count()
      if ts2300_count == 2 {
        println("✓ Conformance test 49 correctly detects 2 TS2300 errors")
        assert_true(true)
      } else {
        println("Expected 2 TS2300 errors for conformance test 49, but got \{ts2300_count}:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(ts2300_count == 2)
      }
    }
    Ok(_) => {
      println("Expected TS2300 errors for conformance test 49 but got no errors")
      assert_false(true)
    }
  }
}

test "TS2300: Conformance test computedPropertyNames50_ES5" {
  let source =
    #|var x = {
    #|    p1: 10,
    #|    get foo() {
    #|        if (1 == 1) {
    #|            return 10;
    #|        }
    #|    },
    #|    get [1 + 1]() {
    #|        throw 10;
    #|    },
    #|    set [1 + 1]() {
    #|        throw 10;
    #|    },
    #|    get [1 + 1]() {
    #|        return 10;
    #|    },
    #|    get foo() {
    #|        if (2 == 2) {
    #|            return 20;
    #|        }
    #|    },
    #|    p2: 20
    #|};

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let ts2300_count = diagnostics.iter().filter(fn(d) { d.code == 2300 }).count()
      if ts2300_count == 2 {
        println("✓ Conformance test 50 correctly detects 2 TS2300 errors")
        assert_true(true)
      } else {
        println("Expected 2 TS2300 errors for conformance test 50, but got \{ts2300_count}:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(ts2300_count == 2)
      }
    }
    Ok(_) => {
      println("Expected TS2300 errors for conformance test 50 but got no errors")
      assert_false(true)
    }
  }
}
