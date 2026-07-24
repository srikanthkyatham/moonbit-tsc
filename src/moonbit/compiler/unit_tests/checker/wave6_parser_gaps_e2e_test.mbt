// End-to-end checker tests for the wave-6 parser gap fixes:
// - B8: `p!: T` class properties keep their type AND stay exempt from TS2564
// - B11a: private-name accessors get/set #x behave as accessors
// - B11b/T21: construct/call signatures in type literals are checked

// ============================================================================
// B8: definite assignment assertion on class properties
// ============================================================================

///|
test "wave6/b8 - p!: T exempt from TS2564 under strict" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: true
      #|class C {
      #|  p!: number;
      #|}
    ),
  )
  match result {
    Ok(_) => ()
    Err(diagnostics) => assert_true(!has_diagnostic_code(diagnostics, 2564))
  }
}

///|
test "wave6/b8 - unasserted sibling still gets TS2564" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: true
      #|class C {
      #|  p!: number;
      #|  q: number;
      #|}
    ),
  )
  match result {
    Ok(_) => fail("Expected TS2564 for q")
    Err(diagnostics) => {
      assert_true(has_diagnostic_code(diagnostics, 2564))
      // Only q is flagged, not p
      let mut count = 0
      for d in diagnostics {
        if d.code == 2564 {
          count = count + 1
        }
      }
      assert_eq(count, 1)
    }
  }
}

///|
test "wave6/b8 - p!: T keeps its type for assignability" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: false
      #|class C {
      #|  p!: number;
      #|}
      #|let c = new C();
      #|let s: string = c.p;
    ),
  )
  match result {
    Ok(_) => fail("Expected TS2322: number not assignable to string")
    Err(diagnostics) => assert_true(has_diagnostic_code(diagnostics, 2322))
  }
}

// ============================================================================
// B11a: private-name accessors
// ============================================================================

///|
test "wave6/b11a - private accessor pair types member accesses" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: false
      #|class C {
      #|  get #x(): number { return 1; }
      #|  set #x(v: number) { }
      #|  m() {
      #|    this.#x = 5;
      #|    let a: number = this.#x;
      #|  }
      #|}
    ),
  )
  match result {
    Ok(_) => ()
    Err(diagnostics) => {
      // No error may be reported on either #x usage
      assert_true(!has_diagnostic_code(diagnostics, 2322))
      assert_true(!has_diagnostic_code(diagnostics, 2339))
    }
  }
}

///|
test "wave6/b11a - setter param with getter present has no TS7006" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: true
      #|class C {
      #|  get #method1() { return 0; }
      #|  set #method1(value) {}
      #|}
    ),
  )
  match result {
    Ok(_) => ()
    Err(diagnostics) => assert_true(!has_diagnostic_code(diagnostics, 7006))
  }
}

// ============================================================================
// B11b / T21: construct and call signatures in type literals
// ============================================================================

///|
test "wave6/b11b - construct signature return type is checked" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: false
      #|var x: { new (): number; };
      #|var s: string = new x();
    ),
  )
  match result {
    Ok(_) => fail("Expected TS2322: number not assignable to string")
    Err(diagnostics) => assert_true(has_diagnostic_code(diagnostics, 2322))
  }
}

///|
test "wave6/b11b - construct signature matching use is clean" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: false
      #|var x: { new (): number; };
      #|var n: number = new x();
    ),
  )
  match result {
    Ok(_) => ()
    Err(diagnostics) => assert_true(!has_diagnostic_code(diagnostics, 2322))
  }
}

///|
test "wave6/t21 - generic call signature member is applied" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: false
      #|var f: { <U>(x: U): U };
      #|var s: string = f(1);
    ),
  )
  match result {
    Ok(_) => fail("Expected TS2322: number not assignable to string")
    Err(diagnostics) => assert_true(has_diagnostic_code(diagnostics, 2322))
  }
}

///|
test "wave6/t21 - generic call signature matching use is clean" {
  let result = parse_bind_check_errors(
    (
      #|// @strict: false
      #|var f: { <U>(x: U): U };
      #|var n: number = f(1);
      #|var s: string = f("a");
    ),
  )
  match result {
    Ok(_) => ()
    Err(diagnostics) => assert_true(!has_diagnostic_code(diagnostics, 2322))
  }
}
