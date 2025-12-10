// Unit tests for TS2556: Spread argument validation

test "Spread into function without rest parameter should give TS2556" {
  // Function has no rest parameter, spread should error
  let source =
    #|function foo(a: number, b: number) { }
    #|let arr: number[] = [1, 2];
    #|foo(...arr);
  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2556 error but got Ok")
      assert_true(false)
    }
    Err(diagnostics) => {
      println("Got \{diagnostics.length()} diagnostics:")
      diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })

      // Should have TS2556: spread must be passed to rest parameter
      let has_ts2556 = diagnostics.iter().any(fn(d) { d.code == 2556 })
      assert_true(has_ts2556)
    }
  }
}

test "Spread to rest parameter should pass" {
  // Function has rest parameter, spread should work
  let source =
    #|function foo(...s: number[]) { }
    #|let arr: number[] = [1, 2];
    #|foo(...arr);
  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true) // Should pass
    Err(diagnostics) => {
      println("Expected no errors but got \{diagnostics.length()} diagnostics:")
      diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
      // Should not have TS2556 error
      let has_ts2556 = diagnostics.iter().any(fn(d) { d.code == 2556 })
      assert_false(has_ts2556)
    }
  }
}

test "Spread with iterator into function without rest parameter should give TS2556" {
  // Iterator spread into function without rest parameter
  let source =
    #|class SymbolIterator {
    #|  next() { return { value: Symbol(), done: false }; }
    #|  [Symbol.iterator]() { return this; }
    #|}
    #|function foo(a: symbol) { }
    #|foo(...new SymbolIterator);
  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2556 error but got Ok")
      assert_true(false)
    }
    Err(diagnostics) => {
      println("Got \{diagnostics.length()} diagnostics:")
      diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })

      // Should have TS2556: spread must be passed to rest parameter
      let has_ts2556 = diagnostics.iter().any(fn(d) { d.code == 2556 })
      assert_true(has_ts2556)
    }
  }
}

test "Spread with iterator into rest parameter should pass" {
  // Iterator spread into function with rest parameter
  let source =
    #|class SymbolIterator {
    #|  next() { return { value: Symbol(), done: false }; }
    #|  [Symbol.iterator]() { return this; }
    #|}
    #|function foo(...s: symbol[]) { }
    #|foo(...new SymbolIterator);
  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true) // Should pass
    Err(diagnostics) => {
      println("Expected no errors but got \{diagnostics.length()} diagnostics:")
      diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
      // Should not have TS2556 error
      let has_ts2556 = diagnostics.iter().any(fn(d) { d.code == 2556 })
      assert_false(has_ts2556)
    }
  }
}

test "Multiple spreads into rest parameter should pass" {
  // Multiple spreads into function with rest parameter
  let source =
    #|function foo(...s: number[]) { }
    #|let arr1: number[] = [1, 2];
    #|let arr2: number[] = [3, 4];
    #|foo(...arr1, ...arr2);
  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true) // Should pass
    Err(diagnostics) => {
      println("Expected no errors but got \{diagnostics.length()} diagnostics:")
      diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
      // Should not have TS2556 error
      let has_ts2556 = diagnostics.iter().any(fn(d) { d.code == 2556 })
      assert_false(has_ts2556)
    }
  }
}
