///| Unit tests for TS2873: This kind of expression is always falsy
///| Tests validation of always-falsy expressions in computed property names

test "TS2873: Empty string in OR expression should trigger error" {
  let source =
    #|var o = {
    #|    ["" || "default"]: 0
    #|};

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2873 = diagnostics.iter().any(fn(d) { d.code == 2873 })
      if has_ts2873 {
        println("✓ Empty string correctly detected as always falsy (TS2873)")
        assert_true(true)
      } else {
        println("Expected TS2873 error for empty string, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2873 error for empty string but got no errors")
      assert_false(true)
    }
  }
}

test "TS2873: Zero in OR expression should trigger error" {
  let source =
    #|var o = {
    #|    [0 || 42]: "value"
    #|};

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2873 = diagnostics.iter().any(fn(d) { d.code == 2873 })
      if has_ts2873 {
        println("✓ Zero correctly detected as always falsy (TS2873)")
        assert_true(true)
      } else {
        println("Expected TS2873 error for zero, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2873 error for zero but got no errors")
      assert_false(true)
    }
  }
}

test "TS2873: False in OR expression should trigger error" {
  let source =
    #|var o = {
    #|    [false || true]: "value"
    #|};

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2873 = diagnostics.iter().any(fn(d) { d.code == 2873 })
      if has_ts2873 {
        println("✓ False correctly detected as always falsy (TS2873)")
        assert_true(true)
      } else {
        println("Expected TS2873 error for false, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2873 error for false but got no errors")
      assert_false(true)
    }
  }
}

test "TS2873: Null in OR expression should trigger error" {
  let source =
    #|var o = {
    #|    [null || "default"]: "value"
    #|};

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2873 = diagnostics.iter().any(fn(d) { d.code == 2873 })
      if has_ts2873 {
        println("✓ Null correctly detected as always falsy (TS2873)")
        assert_true(true)
      } else {
        println("Expected TS2873 error for null, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2873 error for null but got no errors")
      assert_false(true)
    }
  }
}

test "TS2873: Non-empty string should NOT trigger error" {
  let source =
    #|var o = {
    #|    ["hello" || "world"]: "value"
    #|};

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ Non-empty string correctly NOT flagged as always falsy")
      assert_true(true)
    }
    Err(diagnostics) => {
      let has_ts2873 = diagnostics.iter().any(fn(d) { d.code == 2873 })
      if has_ts2873 {
        println("Non-empty string should NOT trigger TS2873, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        // Other errors are OK, just not TS2873
        println("✓ Non-empty string did not trigger TS2873 (other errors present)")
        assert_true(true)
      }
    }
  }
}

test "TS2873: Non-zero number should NOT trigger error" {
  let source =
    #|var o = {
    #|    [42 || 0]: "value"
    #|};

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ Non-zero number correctly NOT flagged as always falsy")
      assert_true(true)
    }
    Err(diagnostics) => {
      let has_ts2873 = diagnostics.iter().any(fn(d) { d.code == 2873 })
      if has_ts2873 {
        println("Non-zero number should NOT trigger TS2873, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        // Other errors are OK, just not TS2873
        println("✓ Non-zero number did not trigger TS2873 (other errors present)")
        assert_true(true)
      }
    }
  }
}

test "TS2873: True should NOT trigger error" {
  let source =
    #|var o = {
    #|    [true || false]: "value"
    #|};

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ True correctly NOT flagged as always falsy")
      assert_true(true)
    }
    Err(diagnostics) => {
      let has_ts2873 = diagnostics.iter().any(fn(d) { d.code == 2873 })
      if has_ts2873 {
        println("True should NOT trigger TS2873, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        // Other errors are OK, just not TS2873
        println("✓ True did not trigger TS2873 (other errors present)")
        assert_true(true)
      }
    }
  }
}

test "TS2873: Variable reference should NOT trigger error" {
  let source =
    #|var x = "";
    #|var o = {
    #|    [x || "default"]: "value"
    #|};

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ Variable reference correctly NOT flagged as always falsy")
      assert_true(true)
    }
    Err(diagnostics) => {
      let has_ts2873 = diagnostics.iter().any(fn(d) { d.code == 2873 })
      if has_ts2873 {
        println("Variable reference should NOT trigger TS2873, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        // Other errors are OK, just not TS2873
        println("✓ Variable reference did not trigger TS2873 (other errors present)")
        assert_true(true)
      }
    }
  }
}

test "TS2873: AND operator should NOT trigger error (only OR)" {
  let source =
    #|var o = {
    #|    ["" && "default"]: "value"
    #|};

  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("✓ AND operator correctly NOT flagged (TS2873 only for OR)")
      assert_true(true)
    }
    Err(diagnostics) => {
      let has_ts2873 = diagnostics.iter().any(fn(d) { d.code == 2873 })
      if has_ts2873 {
        println("AND operator should NOT trigger TS2873 (only for OR), but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        // Other errors are OK, just not TS2873
        println("✓ AND operator did not trigger TS2873 (other errors present)")
        assert_true(true)
      }
    }
  }
}

test "TS2873: Conformance test computedPropertyNames46_ES5" {
  let source =
    #|var o = {
    #|    ["" || 0]: 0
    #|};

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2873 = diagnostics.iter().any(fn(d) { d.code == 2873 })
      if has_ts2873 {
        println("✓ Conformance test 46 correctly detects TS2873")
        assert_true(true)
      } else {
        println("Expected TS2873 error for conformance test 46, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2873 error for conformance test 46 but got no errors")
      assert_false(true)
    }
  }
}

test "TS2873: Conformance test computedPropertyNames48_ES5" {
  let source =
    #|declare function extractIndexer<T>(p: { [n: number]: T }): T;
    #|extractIndexer({
    #|    ["" || 0]: ""
    #|});

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2873 = diagnostics.iter().any(fn(d) { d.code == 2873 })
      if has_ts2873 {
        println("✓ Conformance test 48 correctly detects TS2873")
        assert_true(true)
      } else {
        println("Expected TS2873 error for conformance test 48, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2873 error for conformance test 48 but got no errors")
      assert_false(true)
    }
  }
}
