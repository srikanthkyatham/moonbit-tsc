// Debug test to trace generic type parameter flow

test "Debug: Simple generic function call" {
  let source =
    #|function foo<T>(x: T): T { return x; }
    #|foo(42);

  println("\n=== STARTING DEBUG TEST ===")
  let result = parse_bind_check_errors(source)
  println("=== DEBUG TEST COMPLETE ===\n")

  match result {
    Ok(_) => {
      println("Test passed - no errors (expected)")
      assert_true(true)
    }
    Err(diagnostics) => {
      println("Got \{diagnostics.length()} diagnostics:")
      diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
      assert_true(false)
    }
  }
}
