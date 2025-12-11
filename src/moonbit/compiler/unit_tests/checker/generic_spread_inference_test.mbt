// Unit tests for generic type parameter inference from spread arguments

test "Generic function with spread - incompatible types should error TS2345" {
  // This test verifies that type compatibility checking detects symbol vs string mismatch
  let source =
    #|function foo<T>(...s: T[]) { return s[0]; }
    #|class SymbolIterator {
    #|  next() { return { value: Symbol(), done: false }; }
    #|  [Symbol.iterator]() { return this; }
    #|}
    #|class StringIterator {
    #|  next() { return { value: "", done: false }; }
    #|  [Symbol.iterator]() { return this; }
    #|}
    #|foo(...new SymbolIterator, ...new StringIterator);
  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2345 error for incompatible types but got no errors")
      assert_false(true)
    }
    Err(diagnostics) => {
      // Should get TS2345 error for type mismatch
      let has_ts2345 = diagnostics.iter().any(fn(d) { d.code == 2345 })
      if has_ts2345 {
        println("✓ Correctly detected incompatible types with TS2345")
        assert_true(true)
      } else {
        println("Expected TS2345 error but got: ")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
  }
}

test "Generic class constructor with spread - incompatible types should error TS2345" {
  // This test verifies that type compatibility checking works for constructors too
  let source =
    #|class Foo<T> {
    #|  constructor(...s: T[]) { }
    #|}
    #|class SymbolIterator {
    #|  next() { return { value: Symbol(), done: false }; }
    #|  [Symbol.iterator]() { return this; }
    #|}
    #|class StringIterator {
    #|  next() { return { value: "", done: false }; }
    #|  [Symbol.iterator]() { return this; }
    #|}
    #|new Foo(...new SymbolIterator, ...new StringIterator);
  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2345 error for incompatible types but got no errors")
      assert_false(true)
    }
    Err(diagnostics) => {
      // Should get TS2345 error for type mismatch
      let has_ts2345 = diagnostics.iter().any(fn(d) { d.code == 2345 })
      if has_ts2345 {
        println("✓ Correctly detected incompatible types with TS2345")
        assert_true(true)
      } else {
        println("Expected TS2345 error but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
  }
}

test "Generic function with spread - compatible types should pass" {
  let source =
    #|function foo<T>(...s: T[]) { return s[0]; }
    #|class SymbolIterator {
    #|  next() { return { value: Symbol(), done: false }; }
    #|  [Symbol.iterator]() { return this; }
    #|}
    #|foo(...new SymbolIterator, ...new SymbolIterator);
  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Expected no errors but got \{diagnostics.length()} diagnostics:")
      diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
      assert_false(true)
    }
  }
}

test "Generic function with regular arrays - incompatible types should error TS2345" {
  // This test verifies that type compatibility checking works for regular arrays too
  let source =
    #|function foo<T>(...s: T[]) { return s[0]; }
    #|let nums: number[] = [1, 2];
    #|let strs: string[] = ["a", "b"];
    #|foo(...nums, ...strs);
  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2345 error for incompatible types (number vs string) but got no errors")
      assert_false(true)
    }
    Err(diagnostics) => {
      // Should get TS2345 error for type mismatch
      let has_ts2345 = diagnostics.iter().any(fn(d) { d.code == 2345 })
      if has_ts2345 {
        println("✓ Correctly detected incompatible types (number vs string) with TS2345")
        assert_true(true)
      } else {
        println("Expected TS2345 error but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
  }
}
