test "TS2411: Property type not assignable to index signature - getter" {
  let source =
    #|class Foo { x }
    #|class Foo2 { x; y }
    #|
    #|class C {
    #|    [s: string]: Foo2;
    #|    get prop1() { return new Foo }
    #|}

  let result = parse_bind_check_errors(source)

  match result {
    Err(diagnostics) => {
      let has_ts2411 = diagnostics.iter().any(fn(d) { d.code == 2411 })
      if has_ts2411 {
        println("✓ Correctly detected TS2411 for getter return type")
        assert_true(true)
      } else {
        println("Expected TS2411 error but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2411 error for getter but got no errors")
      assert_false(true)
    }
  }
}

test "TS2411: Property type not assignable to index signature - computed getter" {
  let source =
    #|class Foo { x }
    #|class Foo2 { x; y }
    #|
    #|class C {
    #|    [s: string]: Foo2;
    #|    get ["get1"]() { return new Foo }
    #|}

  let result = parse_bind_check_errors(source)

  match result {
    Err(diagnostics) => {
      let has_ts2411 = diagnostics.iter().any(fn(d) { d.code == 2411 })
      if has_ts2411 {
        println("✓ Correctly detected TS2411 for computed getter")
        assert_true(true)
      } else {
        println("Expected TS2411 error but got:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      }
    }
    Ok(_) => {
      println("Expected TS2411 error for computed getter but got no errors")
      assert_false(true)
    }
  }
}

test "TS2411: Property assignable to index signature - should pass" {
  let source =
    #|class Foo { x; y }
    #|
    #|class C {
    #|    [s: string]: Foo;
    #|    get prop1() { return new Foo }
    #|}

  let result = parse_bind_check_errors(source)

  match result {
    Ok(_) => {
      println("✓ Correctly allowed assignable property type")
      assert_true(true)
    }
    Err(diagnostics) => {
      let has_ts2411 = diagnostics.iter().any(fn(d) { d.code == 2411 })
      if has_ts2411 {
        println("Should not have TS2411 error when types match:")
        diagnostics.iter().each(fn(d) { println("  - TS\{d.code}: \{d.message}") })
        assert_false(true)
      } else {
        // Other errors are ok, just not TS2411
        println("✓ No TS2411 error")
        assert_true(true)
      }
    }
  }
}
