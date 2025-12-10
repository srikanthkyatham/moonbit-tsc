// Unit tests for spread argument type checking

test "Spread argument with incompatible element type should give TS2345" {
  // Simple test - spread string[] into number[] rest parameter
  let source =
    #|function foo(...s: number[]) { }
    #|let arr: string[] = ["a", "b"];
    #|foo(...arr);
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

test "Multiple spread arguments should each be validated" {
  // Test with multiple spread arguments
  let source =
    #|function foo(...s: number[]) { }
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
