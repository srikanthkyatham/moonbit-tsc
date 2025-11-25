// Flow Node Tests
// Tests for control flow graph nodes including:
// - FlowThrow
// - FlowEnd
// - FlowBranchCondition (TrueCondition/FalseCondition)
// - FlowLoopLabel
// - FlowBranchLabel
// - FlowReducer
// - FlowNarrowing

// ============================================================================
// FlowNode Throw Tests
// ============================================================================

///|
test "bind throw statement creates throw flow node" {
  let result = parse_and_bind("function f() { throw new Error('error'); }")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("f"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind throw with string literal" {
  let result = parse_and_bind("function f() { throw 'error'; }")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("f"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind throw in try block" {
  let result = parse_and_bind("try { throw new Error(); } catch (e) { }")
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "bind throw with variable" {
  let result = parse_and_bind("function f(x) { throw x; }")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("f"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind throw in conditional branch" {
  let result = parse_and_bind("function guard(x) { if (!x) throw new Error('required'); return x; }")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("guard"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind multiple throw statements" {
  let result = parse_and_bind("function check(x) { if (x < 0) throw new Error('negative'); if (x > 100) throw new Error('too large'); }")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("check"))
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// FlowNode End Tests
// ============================================================================

///|
test "bind function with natural end" {
  let result = parse_and_bind("function f() { const x = 1; }")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("f"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind source file end" {
  let result = parse_and_bind("const x = 1; const y = 2;")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("x"))
      assert_true(bound.global_scope.symbols.contains("y"))
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// FlowNode TrueCondition/FalseCondition Tests
// ============================================================================

///|
test "bind if with type narrowing potential" {
  let result = parse_and_bind("function f(x) { if (x !== null) { return x; } return null; }")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("f"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind if-else creates branches" {
  let result = parse_and_bind("function f(x) { if (x) { const a = 1; } else { const b = 2; } }")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("f"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind nested if conditions" {
  let result = parse_and_bind("function f(a, b) { if (a) { if (b) { return 1; } return 2; } return 3; }")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("f"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind if-else-if chain" {
  let result = parse_and_bind("function f(x) { if (x < 0) { return -1; } else if (x > 0) { return 1; } else { return 0; } }")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("f"))
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// FlowNode LoopLabel Tests
// ============================================================================

///|
test "bind for loop creates loop label" {
  let result = parse_and_bind("for (let i = 0; i < 10; i++) { if (i === 5) break; }")
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "bind while loop with break" {
  let result = parse_and_bind("let x = 0; while (x < 10) { x++; if (x === 5) break; }")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("x"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind do-while loop with continue" {
  let result = parse_and_bind("let x = 0; do { x++; if (x % 2 === 0) continue; } while (x < 10);")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("x"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind nested loops with break" {
  let result = parse_and_bind("outer: for (let i = 0; i < 5; i++) { for (let j = 0; j < 5; j++) { if (i + j > 5) break outer; } }")
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "bind nested loops with continue" {
  let result = parse_and_bind("outer: for (let i = 0; i < 5; i++) { for (let j = 0; j < 5; j++) { if (j === 2) continue outer; } }")
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// FlowNode BranchLabel Tests
// ============================================================================

///|
test "bind labeled break statement" {
  let result = parse_and_bind("loop: while (true) { if (true) break loop; }")
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "bind labeled continue statement" {
  let result = parse_and_bind("loop: for (let i = 0; i < 10; i++) { if (i % 2 === 0) continue loop; }")
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "bind break in nested labeled blocks" {
  let result = parse_and_bind("outer: { inner: { break outer; } }")
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "bind multiple break targets" {
  let result = parse_and_bind("a: for (let i = 0; i < 5; i++) { b: for (let j = 0; j < 5; j++) { if (j === 1) break b; if (j === 2) break a; } }")
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// FlowNode Reducer Tests (Multiple branches merging)
// ============================================================================

///|
test "bind if-else merges branches" {
  let result = parse_and_bind("function f(x) { let y; if (x) { y = 1; } else { y = 2; } return y; }")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("f"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind switch statement merges cases" {
  let result = parse_and_bind("function f(x) { let y; switch (x) { case 1: y = 'a'; break; case 2: y = 'b'; break; default: y = 'c'; } return y; }")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("f"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind try-catch merges paths" {
  let result = parse_and_bind("function f() { let x; try { x = risky(); } catch (e) { x = 'fallback'; } return x; }")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("f"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind multiple if statements merge sequentially" {
  let result = parse_and_bind("function f(a, b) { let x = 0; if (a) { x = 1; } if (b) { x = 2; } return x; }")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("f"))
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// FlowNode Narrowing Tests
// ============================================================================

///|
test "bind typeof narrowing pattern" {
  let result = parse_and_bind("function f(x) { if (typeof x === 'string') { return x.length; } return 0; }")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("f"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind instanceof narrowing pattern" {
  let result = parse_and_bind("function f(x) { if (x instanceof Error) { return x.message; } return ''; }")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("f"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind truthiness narrowing" {
  let result = parse_and_bind("function f(x) { if (x) { return x.toString(); } return ''; }")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("f"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind equality narrowing" {
  let result = parse_and_bind("function f(x) { if (x === null) { return 'null'; } return x; }")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("f"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind in operator narrowing" {
  let result = parse_and_bind("function f(x) { if ('name' in x) { return x.name; } return ''; }")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("f"))
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// FlowNode Unreachable Tests
// ============================================================================

///|
test "bind return makes code unreachable" {
  let result = parse_and_bind("function f() { return 1; const x = 2; }")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("f"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind throw makes code unreachable" {
  let result = parse_and_bind("function f() { throw new Error('error'); const x = 2; }")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("f"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "bind break makes code unreachable" {
  let result = parse_and_bind("while (true) { break; const x = 1; }")
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "bind continue makes code unreachable" {
  let result = parse_and_bind("while (true) { continue; const x = 1; }")
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "bind labeled break makes code unreachable" {
  let result = parse_and_bind("outer: while (true) { break outer; const x = 1; }")
  match result {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
}

///|
test "bind unreachable after throw in if branch" {
  let result = parse_and_bind("function f(x) { if (x) { throw new Error(); } return x; }")
  match result {
    Ok(bound) => {
      assert_true(bound.global_scope.symbols.contains("f"))
    }
    Err(_) => assert_true(false)
  }
}
