// Unit tests for class instance spread functionality

test "spread class instance excludes methods" {
  let source =
    #|class C { p = 1; m() { } }
    #|let c: C = new C()
    #|let spreadC = { ...c }

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

test "spread class instance with typed target" {
  let source =
    #|class C { p = 1; m() { } }
    #|let c: C = new C()
    #|let spreadC: { p: number } = { ...c }

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

test "spread class instance only copies properties" {
  let source =
    #|class C { p = 1; m() { return 2 } }
    #|let c: C = new C()
    #|let spreadC = { ...c }
    #|let test: { p: number } = spreadC

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
