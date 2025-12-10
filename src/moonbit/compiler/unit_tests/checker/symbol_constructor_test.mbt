// Unit tests for Symbol() constructor type checking

test "Symbol() returns symbol type" {
  let result = parse_bind_check_errors("let s = Symbol(); let str: string = s;")
  match result {
    Ok(_) => assert_true(false) // Should have TS2322 error
    Err(diagnostics) => {
      // Should have TS2322 error: symbol not assignable to string
      let has_ts2322 = diagnostics.iter().any(fn(d) { d.code == 2322 })
      assert_true(has_ts2322)
    }
  }
}

test "Symbol() with description returns symbol type" {
  let result = parse_bind_check_errors("let s = Symbol('foo'); let str: string = s;")
  match result {
    Ok(_) => assert_true(false) // Should have TS2322 error
    Err(diagnostics) => {
      // Should have TS2322 error: symbol not assignable to string
      let has_ts2322 = diagnostics.iter().any(fn(d) { d.code == 2322 })
      assert_true(has_ts2322)
    }
  }
}

test "Symbol() in object literal preserves type" {
  let result = parse_bind_check_errors("let obj = { value: Symbol(), done: false }; let v: symbol = obj.value;")
  match result {
    Ok(_) => assert_true(true) // Should compile without errors
    Err(diagnostics) => {
      // Should not have any errors
      assert_eq(diagnostics.length(), 0)
    }
  }
}

test "Symbol() in array spread type checking" {
  // Create an array of symbols and try to spread into number array
  let source =
    #|let symbols: symbol[] = [Symbol(), Symbol()];
    #|let numbers: number[] = [...symbols];
  let result = parse_bind_check_errors(source)
  match result {
    Ok(_) => assert_true(false) // Should have TS2322 error
    Err(diagnostics) => {
      // Should have TS2322 error: symbol[] elements not assignable to number[]
      let has_ts2322 = diagnostics.iter().any(fn(d) { d.code == 2322 })
      assert_true(has_ts2322)
    }
  }
}
