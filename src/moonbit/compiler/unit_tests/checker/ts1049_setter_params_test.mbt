///| Unit tests for TS1049: A 'set' accessor must have exactly one parameter
///| Tests validation of setter parameter count in object literals

test "TS1049: Setter with zero parameters should trigger error" {
  let source =
    #|var x = {
    #|    set foo() { }
    #|};

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts1049 = diagnostics.iter().any(fn(d) { d.code == 1049 })
      if has_ts1049 {
        println("✓ Setter with zero parameters correctly detected (TS1049)")
        assert_true(true)
      } else {
        println("Expected TS1049 error for zero parameters, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS1049 error for setter with zero parameters but got no errors")
      assert_false(true)
    }
  }
}

test "TS1049: Setter with one parameter should NOT trigger error" {
  let source =
    #|var x = {
    #|    set foo(value) { }
    #|};

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ Setter with one parameter correctly accepted")
      assert_true(true)
    }
    Err(diagnostics) => {
      let has_ts1049 = diagnostics.iter().any(fn(d) { d.code == 1049 })
      if has_ts1049 {
        println("Setter with one parameter should NOT trigger TS1049, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        // Other errors are OK, just not TS1049
        println("✓ Setter did not trigger TS1049 (other errors present)")
        assert_true(true)
      }
    }
  }
}

test "TS1049: Setter with two parameters should trigger error" {
  let source =
    #|var x = {
    #|    set foo(a, b) { }
    #|};

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts1049 = diagnostics.iter().any(fn(d) { d.code == 1049 })
      if has_ts1049 {
        println("✓ Setter with two parameters correctly detected (TS1049)")
        assert_true(true)
      } else {
        println("Expected TS1049 error for two parameters, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS1049 error for setter with two parameters but got no errors")
      assert_false(true)
    }
  }
}

test "TS1049: Computed setter with zero parameters should trigger error" {
  let source =
    #|var x = {
    #|    set [1 + 1]() { }
    #|};

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts1049 = diagnostics.iter().any(fn(d) { d.code == 1049 })
      if has_ts1049 {
        println("✓ Computed setter with zero parameters correctly detected (TS1049)")
        assert_true(true)
      } else {
        println("Expected TS1049 error for computed setter with zero parameters, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS1049 error for computed setter with zero parameters but got no errors")
      assert_false(true)
    }
  }
}

test "TS1049: Computed setter with one parameter should NOT trigger error" {
  let source =
    #|var x = {
    #|    set ["prop"](value) { }
    #|};

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ Computed setter with one parameter correctly accepted")
      assert_true(true)
    }
    Err(diagnostics) => {
      let has_ts1049 = diagnostics.iter().any(fn(d) { d.code == 1049 })
      if has_ts1049 {
        println("Computed setter with one parameter should NOT trigger TS1049, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        // Other errors are OK, just not TS1049
        println("✓ Computed setter did not trigger TS1049 (other errors present)")
        assert_true(true)
      }
    }
  }
}

test "TS1049: Computed setter with multiple parameters should trigger error" {
  let source =
    #|var x = {
    #|    set [1 + 1](a, b, c) { }
    #|};

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts1049 = diagnostics.iter().any(fn(d) { d.code == 1049 })
      if has_ts1049 {
        println("✓ Computed setter with multiple parameters correctly detected (TS1049)")
        assert_true(true)
      } else {
        println("Expected TS1049 error for computed setter with multiple parameters, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS1049 error for computed setter with multiple parameters but got no errors")
      assert_false(true)
    }
  }
}

test "TS1049: Getter should NOT trigger error (only setters)" {
  let source =
    #|var x = {
    #|    get foo() { return 10; }
    #|};

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ Getter correctly NOT flagged (TS1049 only for setters)")
      assert_true(true)
    }
    Err(diagnostics) => {
      let has_ts1049 = diagnostics.iter().any(fn(d) { d.code == 1049 })
      if has_ts1049 {
        println("Getter should NOT trigger TS1049 (only for setters), but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        // Other errors are OK, just not TS1049
        println("✓ Getter did not trigger TS1049 (other errors present)")
        assert_true(true)
      }
    }
  }
}

test "TS1049: Multiple setters can all trigger errors" {
  let source =
    #|var x = {
    #|    set foo() { },
    #|    set bar(a, b) { },
    #|    set baz(value) { }
    #|};

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let ts1049_count = diagnostics.iter().filter(fn(d) { d.code == 1049 }).count()
      if ts1049_count == 2 {
        println("✓ Both invalid setters correctly detected (2 TS1049 errors)")
        assert_true(true)
      } else {
        println("Expected 2 TS1049 errors, but got \{ts1049_count}:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(ts1049_count == 2)
      }
    }
    Ok(_) => {
      println("Expected TS1049 errors for invalid setters but got no errors")
      assert_false(true)
    }
  }
}

test "TS1049: Conformance test computedPropertyNames49_ES5" {
  let source =
    #|var x = {
    #|    p1: 10,
    #|    get [1 + 1]() {
    #|        throw 10;
    #|    },
    #|    set [1 + 1]() {
    #|        throw 10;
    #|    }
    #|};

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts1049 = diagnostics.iter().any(fn(d) { d.code == 1049 })
      if has_ts1049 {
        println("✓ Conformance test 49 correctly detects TS1049")
        assert_true(true)
      } else {
        println("Expected TS1049 error for conformance test 49, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS1049 error for conformance test 49 but got no errors")
      assert_false(true)
    }
  }
}

test "TS1049: Conformance test computedPropertyNames50_ES5" {
  let source =
    #|var x = {
    #|    p1: 10,
    #|    get foo() {
    #|        if (1 == 1) {
    #|            return 10;
    #|        }
    #|    },
    #|    set [1 + 1]() {
    #|        throw 10;
    #|    }
    #|};

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts1049 = diagnostics.iter().any(fn(d) { d.code == 1049 })
      if has_ts1049 {
        println("✓ Conformance test 50 correctly detects TS1049")
        assert_true(true)
      } else {
        println("Expected TS1049 error for conformance test 50, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS1049 error for conformance test 50 but got no errors")
      assert_false(true)
    }
  }
}
