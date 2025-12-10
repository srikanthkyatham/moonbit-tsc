// Unit tests for TS2556: Spread to required parameter validation

test "Spread to function with required param before rest should give TS2556" {
  // Function has required param before rest, spread can't fill it
  let source =
    #|function foo(s1: number, ...s: number[]) { }
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

      // Should have TS2556: spread must be tuple or passed to rest parameter
      let has_ts2556 = diagnostics.iter().any(fn(d) { d.code == 2556 })
      assert_true(has_ts2556)
    }
  }
}

test "Spread with regular arg to function with required param should pass" {
  // Regular arg fills required param, spread goes to rest
  let source =
    #|function foo(s1: number, ...s: number[]) { }
    #|let arr: number[] = [2, 3];
    #|foo(1, ...arr);
  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(true) // Should pass
    Err(diagnostics) => {
      println("Expected no TS2556 but got \{diagnostics.length()} diagnostics:")
      diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
      // Should not have TS2556 error
      let has_ts2556 = diagnostics.iter().any(fn(d) { d.code == 2556 })
      assert_false(has_ts2556)
    }
  }
}

test "Spread to iterator with required param before rest should give TS2556" {
  // Iterator spread to function with required param
  let source =
    #|class SymbolIterator {
    #|  next() { return { value: Symbol(), done: false }; }
    #|  [Symbol.iterator]() { return this; }
    #|}
    #|function foo(s1: symbol, ...s: symbol[]) { }
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

      // Should have TS2556: spread must be tuple or passed to rest parameter
      let has_ts2556 = diagnostics.iter().any(fn(d) { d.code == 2556 })
      assert_true(has_ts2556)
    }
  }
}

test "Multiple spreads with some to required params should give TS2556" {
  // First spread maps to required param (position 0)
  let source =
    #|function foo(s1: number, ...s: number[]) { }
    #|let arr1: number[] = [1];
    #|let arr2: number[] = [2, 3];
    #|foo(...arr1, ...arr2);
  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => {
      println("Expected TS2556 error but got Ok")
      assert_true(false)
    }
    Err(diagnostics) => {
      println("Got \{diagnostics.length()} diagnostics:")
      diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })

      // Should have TS2556: spread must be tuple or passed to rest parameter
      let has_ts2556 = diagnostics.iter().any(fn(d) { d.code == 2556 })
      assert_true(has_ts2556)
    }
  }
}
