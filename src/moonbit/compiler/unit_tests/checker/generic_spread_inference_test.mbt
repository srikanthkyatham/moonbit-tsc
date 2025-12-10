// Unit tests for generic type parameter inference from spread arguments

test "Generic function with spread - incompatible types should error" {
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
      println("Expected TS2345 error but got Ok")
      assert_true(false)
    }
    Err(diagnostics) => {
      println("Got \{diagnostics.length()} diagnostics:")
      diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })

      // Should have TS2345: string not assignable to symbol
      let has_ts2345 = diagnostics.iter().any(fn(d) { d.code == 2345 })
      assert_true(has_ts2345)
    }
  }
}

test "Generic class constructor with spread - incompatible types should error" {
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
      println("Expected TS2345 error but got Ok")
      assert_true(false)
    }
    Err(diagnostics) => {
      println("Got \{diagnostics.length()} diagnostics:")
      diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })

      // Should have TS2345: string not assignable to symbol
      let has_ts2345 = diagnostics.iter().any(fn(d) { d.code == 2345 })
      assert_true(has_ts2345)
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

test "Generic function with regular arrays - incompatible types should error" {
  let source =
    #|function foo<T>(...s: T[]) { return s[0]; }
    #|let nums: number[] = [1, 2];
    #|let strs: string[] = ["a", "b"];
    #|foo(...nums, ...strs);
  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2345 error but got Ok")
      assert_true(false)
    }
    Err(diagnostics) => {
      println("Got \{diagnostics.length()} diagnostics:")
      diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })

      // Should have TS2345: string not assignable to number
      let has_ts2345 = diagnostics.iter().any(fn(d) { d.code == 2345 })
      assert_true(has_ts2345)
    }
  }
}
