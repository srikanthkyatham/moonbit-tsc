// TS2449: Class used before its declaration - Comprehensive Test Suite
// Tests that the type checker correctly detects class self-references in computed property names
//
// TS2449: "Class '{0}' used before its declaration."
// Validates that a class doesn't reference itself in computed property names before declaration is complete

// ============================================================================
// TS2449: Class self-reference in computed property names
// ============================================================================

test "TS2449: static property reference in computed property name" {
  let source =
    #|class C1 {
    #|    static staticProp = 10;
    #|    [C1.staticProp]() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2449 = diagnostics.iter().any(fn(d) { d.code == 2449 })
      if has_ts2449 {
        println("✓ Class self-reference in computed property correctly detected (TS2449)")
        assert_true(true)
      } else {
        println("Expected TS2449 error for class self-reference, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2449 error for class self-reference but got no errors")
      assert_false(true)
    }
  }
}

test "TS2449: class name reference in computed property name" {
  let source =
    #|class C2 {
    #|    prop = 5;
    #|    [C2]() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2449 = diagnostics.iter().any(fn(d) { d.code == 2449 })
      if has_ts2449 {
        println("✓ Class name reference in computed property correctly detected (TS2449)")
        assert_true(true)
      } else {
        println("Expected TS2449 error for class name reference, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2449 error for class name reference but got no errors")
      assert_false(true)
    }
  }
}

test "TS2449: class property access in computed property name" {
  let source =
    #|class C3 {
    #|    [C3.name]() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2449 = diagnostics.iter().any(fn(d) { d.code == 2449 })
      if has_ts2449 {
        println("✓ Class property access in computed property correctly detected (TS2449)")
        assert_true(true)
      } else {
        println("Expected TS2449 error for class property access, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2449 error for class property access but got no errors")
      assert_false(true)
    }
  }
}

test "TS2449: static method call in computed property name" {
  let source =
    #|class C4 {
    #|    [C4.toString()]() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2449 = diagnostics.iter().any(fn(d) { d.code == 2449 })
      if has_ts2449 {
        println("✓ Static method call in computed property correctly detected (TS2449)")
        assert_true(true)
      } else {
        println("Expected TS2449 error for static method call, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2449 error for static method call but got no errors")
      assert_false(true)
    }
  }
}

test "TS2449: static method with call in computed property name" {
  let source =
    #|class C5 {
    #|    static method() { return "key"; }
    #|    [C5.method()]() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2449 = diagnostics.iter().any(fn(d) { d.code == 2449 })
      if has_ts2449 {
        println("✓ Static method with call in computed property correctly detected (TS2449)")
        assert_true(true)
      } else {
        println("Expected TS2449 error for static method with call, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2449 error for static method with call but got no errors")
      assert_false(true)
    }
  }
}

test "TS2449: class reference in property declaration" {
  let source =
    #|class C6 {
    #|    static key = "prop";
    #|    [C6.key] = 42;
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2449 = diagnostics.iter().any(fn(d) { d.code == 2449 })
      if has_ts2449 {
        println("✓ Class reference in property declaration correctly detected (TS2449)")
        assert_true(true)
      } else {
        println("Expected TS2449 error for class reference in property declaration, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2449 error for class reference in property declaration but got no errors")
      assert_false(true)
    }
  }
}

test "TS2449: multiple class self-references" {
  let source =
    #|class C7 {
    #|    static prop1 = 1;
    #|    static prop2 = 2;
    #|    [C7.prop1]() { }
    #|    [C7.prop2]() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let count = diagnostics.iter().filter(fn(d) { d.code == 2449 }).count()
      if count == 2 {
        println("✓ Multiple class self-references correctly detected (2 TS2449 errors)")
        assert_true(true)
      } else {
        println("Expected 2 TS2449 errors but got \{count}")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2449 errors for multiple class self-references but got no errors")
      assert_false(true)
    }
  }
}

test "TS2449: class reference in binary expression" {
  let source =
    #|class C8 {
    #|    static value = 10;
    #|    [C8.value + 5]() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2449 = diagnostics.iter().any(fn(d) { d.code == 2449 })
      if has_ts2449 {
        println("✓ Class reference in binary expression correctly detected (TS2449)")
        assert_true(true)
      } else {
        println("Expected TS2449 error for class reference in binary expression, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2449 error for class reference in binary expression but got no errors")
      assert_false(true)
    }
  }
}

// ============================================================================
// TS2449: Valid cases that should NOT trigger the error
// ============================================================================

test "TS2449: using different class should NOT error" {
  let source =
    #|class C1 {
    #|    static staticProp = 10;
    #|}
    #|class C2 {
    #|    [C1.staticProp]() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2449 = diagnostics.iter().any(fn(d) { d.code == 2449 })
      if has_ts2449 {
        println("Unexpected TS2449 error for different class reference:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        println("✓ Different class reference correctly allowed (no TS2449)")
        assert_true(true)
      }
    }
    Ok(_) => {
      println("✓ Different class reference correctly allowed (no errors)")
      assert_true(true)
    }
  }
}

test "TS2449: string literal should NOT error" {
  let source =
    #|class C3 {
    #|    ["literal"]() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2449 = diagnostics.iter().any(fn(d) { d.code == 2449 })
      if has_ts2449 {
        println("Unexpected TS2449 error for string literal:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        println("✓ String literal correctly allowed (no TS2449)")
        assert_true(true)
      }
    }
    Ok(_) => {
      println("✓ String literal correctly allowed (no errors)")
      assert_true(true)
    }
  }
}

test "TS2449: number literal should NOT error" {
  let source =
    #|class C4 {
    #|    [42]() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2449 = diagnostics.iter().any(fn(d) { d.code == 2449 })
      if has_ts2449 {
        println("Unexpected TS2449 error for number literal:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        println("✓ Number literal correctly allowed (no TS2449)")
        assert_true(true)
      }
    }
    Ok(_) => {
      println("✓ Number literal correctly allowed (no errors)")
      assert_true(true)
    }
  }
}

test "TS2449: external variable should NOT error" {
  let source =
    #|const external = "key";
    #|class C5 {
    #|    [external]() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2449 = diagnostics.iter().any(fn(d) { d.code == 2449 })
      if has_ts2449 {
        println("Unexpected TS2449 error for external variable:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        println("✓ External variable correctly allowed (no TS2449)")
        assert_true(true)
      }
    }
    Ok(_) => {
      println("✓ External variable correctly allowed (no errors)")
      assert_true(true)
    }
  }
}

test "TS2449: template literal should NOT error" {
  let source =
    #|class C6 {
    #|    [`computed`]() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2449 = diagnostics.iter().any(fn(d) { d.code == 2449 })
      if has_ts2449 {
        println("Unexpected TS2449 error for template literal:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        println("✓ Template literal correctly allowed (no TS2449)")
        assert_true(true)
      }
    }
    Ok(_) => {
      println("✓ Template literal correctly allowed (no errors)")
      assert_true(true)
    }
  }
}

test "TS2449: expression without class reference should NOT error" {
  let source =
    #|class C7 {
    #|    [1 + 1]() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2449 = diagnostics.iter().any(fn(d) { d.code == 2449 })
      if has_ts2449 {
        println("Unexpected TS2449 error for expression without class reference:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        println("✓ Expression without class reference correctly allowed (no TS2449)")
        assert_true(true)
      }
    }
    Ok(_) => {
      println("✓ Expression without class reference correctly allowed (no errors)")
      assert_true(true)
    }
  }
}

// ============================================================================
// TS2449: Conformance test case
// ============================================================================

test "TS2449: conformance test computedPropertyNamesWithStaticProperty" {
  let source =
    #|class Foo {
    #|    static ["x"]() { }
    #|    static get ["y"]() {
    #|        return 1;
    #|    }
    #|    static set ["y"](v: number) {
    #|    }
    #|}
    #|var x = new Foo();
    #|
    #|class Bar {
    #|    static [""]() { }
    #|    static get [""]() {
    #|        return 1;
    #|    }
    #|    static set [""](v: number) {
    #|    }
    #|}
    #|var y = new Bar();
    #|
    #|class Baz {
    #|    static [0]() { }
    #|    static get [0]() {
    #|        return 1;
    #|    }
    #|    static set [0](v: number) {
    #|    }
    #|}
    #|var z = new Baz();
    #|
    #|class Bam {
    #|    static [0 as number]() { }
    #|    static get [0 as number]() {
    #|        return 1;
    #|    }
    #|    static set [0 as number](v: number) {
    #|    }
    #|}
    #|
    #|class C1 {
    #|    static staticProp = 10;
    #|    [C1.staticProp]() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2449 = diagnostics.iter().any(fn(d) { d.code == 2449 })
      if has_ts2449 {
        println("✓ Conformance test: C1 self-reference correctly detected (TS2449)")
        assert_true(true)
      } else {
        println("Expected TS2449 error for C1 self-reference in conformance test, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2449 error for C1 self-reference in conformance test but got no errors")
      assert_false(true)
    }
  }
}

// ============================================================================
// TS2449: Edge cases
// ============================================================================

test "TS2449: parenthesized class reference" {
  let source =
    #|class C9 {
    #|    static prop = 5;
    #|    [(C9).prop]() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2449 = diagnostics.iter().any(fn(d) { d.code == 2449 })
      if has_ts2449 {
        println("✓ Parenthesized class reference correctly detected (TS2449)")
        assert_true(true)
      } else {
        println("Expected TS2449 error for parenthesized class reference, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2449 error for parenthesized class reference but got no errors")
      assert_false(true)
    }
  }
}

test "TS2449: class reference in conditional expression" {
  let source =
    #|class C10 {
    #|    static flag = true;
    #|    [C10.flag ? "a" : "b"]() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2449 = diagnostics.iter().any(fn(d) { d.code == 2449 })
      if has_ts2449 {
        println("✓ Class reference in conditional expression correctly detected (TS2449)")
        assert_true(true)
      } else {
        println("Expected TS2449 error for class reference in conditional, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2449 error for class reference in conditional but got no errors")
      assert_false(true)
    }
  }
}

test "TS2449: nested property access" {
  let source =
    #|class C11 {
    #|    static nested = { key: "prop" };
    #|    [C11.nested.key]() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2449 = diagnostics.iter().any(fn(d) { d.code == 2449 })
      if has_ts2449 {
        println("✓ Nested property access correctly detected (TS2449)")
        assert_true(true)
      } else {
        println("Expected TS2449 error for nested property access, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2449 error for nested property access but got no errors")
      assert_false(true)
    }
  }
}

test "TS2449: class reference in array access" {
  let source =
    #|class C12 {
    #|    static arr = ["a", "b", "c"];
    #|    [C12.arr[0]]() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2449 = diagnostics.iter().any(fn(d) { d.code == 2449 })
      if has_ts2449 {
        println("✓ Class reference in array access correctly detected (TS2449)")
        assert_true(true)
      } else {
        println("Expected TS2449 error for class reference in array access, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2449 error for class reference in array access but got no errors")
      assert_false(true)
    }
  }
}

test "TS2449: class reference in call expression" {
  let source =
    #|class C13 {
    #|    static getKey() { return "key"; }
    #|    [C13.getKey()]() { }
    #|}

  let result = parse_bind_check_errors(source)
  match result {
    Err(diagnostics) => {
      let has_ts2449 = diagnostics.iter().any(fn(d) { d.code == 2449 })
      if has_ts2449 {
        println("✓ Class reference in call expression correctly detected (TS2449)")
        assert_true(true)
      } else {
        println("Expected TS2449 error for class reference in call expression, but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2449 error for class reference in call expression but got no errors")
      assert_false(true)
    }
  }
}
