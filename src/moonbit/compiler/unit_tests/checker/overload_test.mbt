// Overload Checking Unit Tests
// Tests for:
// - TS2394: Overload signature compatibility with implementation
// - TS2391: Missing implementation for non-ambient overloads
// - TS2383: Ambient/non-ambient mismatch
// - Overload collection functionality

// ============================================================================
// TS2391: Missing Implementation Tests
// ============================================================================

///|
test "overload/TS2391 - missing implementation for non-ambient overloads" {
  let source =
    #|function foo(x: string): string;
    #|function foo(x: number): number;
  // No implementation follows - should error
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let overloads_map = @compiler.collect_overloads(source_file.statements, false)
      match overloads_map.get("foo") {
        Some(overloads) => {
          let result = @compiler.validate_overloads(overloads)
          assert_eq(result.is_valid, false)
          assert_true(result.errors.length() > 0)
          assert_eq(result.errors[0].code, 2391)
        }
        None => fail("Expected to find foo overloads")
      }
    }
    Err(_) => fail("Parse failed")
  }
}

///|
test "overload/TS2391 - ambient overloads don't require implementation" {
  let source =
    #|declare function foo(x: string): string;
    #|declare function foo(x: number): number;
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let overloads_map = @compiler.collect_overloads(source_file.statements, false)
      match overloads_map.get("foo") {
        Some(overloads) => {
          let result = @compiler.validate_overloads(overloads)
          // Ambient declarations don't need implementation
          assert_eq(result.is_valid, true)
        }
        None => fail("Expected to find foo overloads")
      }
    }
    Err(_) => fail("Parse failed")
  }
}

///|
test "overload/TS2391 - valid overloads with implementation" {
  let source =
    #|function foo(x: string): string;
    #|function foo(x: number): number;
    #|function foo(x: string | number): string | number {
    #|  return x;
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let overloads_map = @compiler.collect_overloads(source_file.statements, false)
      match overloads_map.get("foo") {
        Some(overloads) => {
          let result = @compiler.validate_overloads(overloads)
          assert_eq(result.is_valid, true)
        }
        None => fail("Expected to find foo overloads")
      }
    }
    Err(_) => fail("Parse failed")
  }
}

// ============================================================================
// TS2383: Ambient Mismatch Tests
// ============================================================================

///|
test "overload/TS2383 - mixed ambient and non-ambient overloads" {
  let source =
    #|declare function foo(x: string): string;
    #|function foo(x: number): number;
    #|function foo(x: string | number): string | number {
    #|  return x;
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let overloads_map = @compiler.collect_overloads(source_file.statements, false)
      match overloads_map.get("foo") {
        Some(overloads) => {
          let result = @compiler.validate_overloads(overloads)
          // Should detect ambient mismatch
          let has_ambient_error = result.errors
            .iter()
            .any(fn(e) { e.code == 2383 })
          assert_true(has_ambient_error)
        }
        None => fail("Expected to find foo overloads")
      }
    }
    Err(_) => fail("Parse failed")
  }
}

///|
test "overload/TS2383 - all ambient is valid" {
  let source =
    #|declare function foo(x: string): string;
    #|declare function foo(x: number): number;
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let overloads_map = @compiler.collect_overloads(source_file.statements, false)
      match overloads_map.get("foo") {
        Some(overloads) => {
          let result = @compiler.validate_overloads(overloads)
          // All ambient is valid (no TS2383)
          let has_ambient_error = result.errors
            .iter()
            .any(fn(e) { e.code == 2383 })
          assert_eq(has_ambient_error, false)
        }
        None => fail("Expected to find foo overloads")
      }
    }
    Err(_) => fail("Parse failed")
  }
}

///|
test "overload/TS2383 - all non-ambient with impl is valid" {
  let source =
    #|function foo(x: string): string;
    #|function foo(x: number): number;
    #|function foo(x: string | number): string | number {
    #|  return x;
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let overloads_map = @compiler.collect_overloads(source_file.statements, false)
      match overloads_map.get("foo") {
        Some(overloads) => {
          let result = @compiler.validate_overloads(overloads)
          // All non-ambient is valid (no TS2383)
          let has_ambient_error = result.errors
            .iter()
            .any(fn(e) { e.code == 2383 })
          assert_eq(has_ambient_error, false)
        }
        None => fail("Expected to find foo overloads")
      }
    }
    Err(_) => fail("Parse failed")
  }
}

// ============================================================================
// TS2394: Overload Compatibility Tests
// ============================================================================

///|
test "overload/TS2394 - implementation requires more params than overload" {
  let source =
    #|function foo(x: string): string;
    #|function foo(x: string, y: number): string {
    #|  return x;
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let overloads_map = @compiler.collect_overloads(source_file.statements, false)
      match overloads_map.get("foo") {
        Some(overloads) => {
          let result = @compiler.validate_overloads(overloads)
          // Implementation requires 2 params, but overload only provides 1
          let has_compat_error = result.errors
            .iter()
            .any(fn(e) { e.code == 2394 })
          assert_true(has_compat_error)
        }
        None => fail("Expected to find foo overloads")
      }
    }
    Err(_) => fail("Parse failed")
  }
}

///|
test "overload/TS2394 - implementation with optional params is valid" {
  let source =
    #|function foo(x: string): string;
    #|function foo(x: string, y?: number): string {
    #|  return x;
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let overloads_map = @compiler.collect_overloads(source_file.statements, false)
      match overloads_map.get("foo") {
        Some(overloads) => {
          let result = @compiler.validate_overloads(overloads)
          // Implementation has optional second param, so it's compatible
          assert_eq(result.is_valid, true)
        }
        None => fail("Expected to find foo overloads")
      }
    }
    Err(_) => fail("Parse failed")
  }
}

///|
test "overload/TS2394 - overload has more params than implementation" {
  let source =
    #|function foo(x: string, y: number): string;
    #|function foo(x: string): string {
    #|  return x;
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let overloads_map = @compiler.collect_overloads(source_file.statements, false)
      match overloads_map.get("foo") {
        Some(overloads) => {
          let result = @compiler.validate_overloads(overloads)
          // Overload has 2 params, but implementation only has 1
          let has_compat_error = result.errors
            .iter()
            .any(fn(e) { e.code == 2394 })
          assert_true(has_compat_error)
        }
        None => fail("Expected to find foo overloads")
      }
    }
    Err(_) => fail("Parse failed")
  }
}

///|
test "overload/TS2394 - rest parameter in implementation handles more params" {
  let source =
    #|function foo(x: string, y: number): string;
    #|function foo(...args: any[]): string {
    #|  return "";
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let overloads_map = @compiler.collect_overloads(source_file.statements, false)
      match overloads_map.get("foo") {
        Some(overloads) => {
          let result = @compiler.validate_overloads(overloads)
          // Rest parameter can handle any number of args
          assert_eq(result.is_valid, true)
        }
        None => fail("Expected to find foo overloads")
      }
    }
    Err(_) => fail("Parse failed")
  }
}

// ============================================================================
// Valid Overload Patterns Tests
// ============================================================================

///|
test "overload/valid - simple two-overload function" {
  let source =
    #|function greet(x: string): string;
    #|function greet(x: number): string;
    #|function greet(x: string | number): string {
    #|  return "Hello " + x;
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let overloads_map = @compiler.collect_overloads(source_file.statements, false)
      match overloads_map.get("greet") {
        Some(overloads) => {
          let result = @compiler.validate_overloads(overloads)
          assert_eq(result.is_valid, true)
        }
        None => fail("Expected to find greet overloads")
      }
    }
    Err(_) => fail("Parse failed")
  }
}

///|
test "overload/valid - multiple overloads with different arities" {
  let source =
    #|function create(): object;
    #|function create(name: string): object;
    #|function create(name: string, age: number): object;
    #|function create(name?: string, age?: number): object {
    #|  return {};
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let overloads_map = @compiler.collect_overloads(source_file.statements, false)
      match overloads_map.get("create") {
        Some(overloads) => {
          let result = @compiler.validate_overloads(overloads)
          assert_eq(result.is_valid, true)
        }
        None => fail("Expected to find create overloads")
      }
    }
    Err(_) => fail("Parse failed")
  }
}

// ============================================================================
// Overload Collection Tests
// ============================================================================

///|
test "overload/collection - collects multiple signatures" {
  let source =
    #|function foo(x: string): string;
    #|function foo(x: number): number;
    #|function foo(x: string | number): string | number {
    #|  return x;
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let overloads_map = @compiler.collect_overloads(source_file.statements, false)
      match overloads_map.get("foo") {
        Some(overloads) => {
          assert_eq(overloads.signatures.length(), 2)
          assert_true(overloads.implementation is Some(_))
        }
        None => fail("Expected to find foo overloads")
      }
    }
    Err(_) => fail("Parse failed")
  }
}

///|
test "overload/collection - separate functions are separate" {
  let source =
    #|function foo(x: string): string;
    #|function foo(x: number): number;
    #|function foo(x: string | number): string | number { return x; }
    #|function bar(y: boolean): boolean;
    #|function bar(y: boolean): boolean { return y; }
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let overloads_map = @compiler.collect_overloads(source_file.statements, false)
      assert_true(overloads_map.get("foo") is Some(_))
      assert_true(overloads_map.get("bar") is Some(_))
    }
    Err(_) => fail("Parse failed")
  }
}

///|
test "overload/collection - single function no overloads" {
  let source =
    #|function foo(x: string): string {
    #|  return x;
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let overloads_map = @compiler.collect_overloads(source_file.statements, false)
      match overloads_map.get("foo") {
        Some(overloads) => {
          // Only implementation, no signatures
          assert_eq(overloads.signatures.length(), 0)
          assert_true(overloads.implementation is Some(_))
        }
        None => fail("Expected to find foo")
      }
    }
    Err(_) => fail("Parse failed")
  }
}

///|
test "overload/collection - only signature no implementation" {
  let source =
    #|function foo(x: string): string;
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let overloads_map = @compiler.collect_overloads(source_file.statements, false)
      match overloads_map.get("foo") {
        Some(overloads) => {
          assert_eq(overloads.signatures.length(), 1)
          assert_true(overloads.implementation is None)
        }
        None => fail("Expected to find foo")
      }
    }
    Err(_) => fail("Parse failed")
  }
}

///|
test "overload/collection - function overloads properties" {
  let source =
    #|function foo(x: string): string;
    #|function foo(x: number): number;
    #|function foo(x: string | number): string | number { return x; }
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let overloads_map = @compiler.collect_overloads(source_file.statements, false)
      match overloads_map.get("foo") {
        Some(overloads) => {
          assert_eq(overloads.name, "foo")
          assert_eq(overloads.signatures.length(), 2)
          // First signature should have 1 parameter
          assert_eq(overloads.signatures[0].parameters.length(), 1)
          // Second signature should have 1 parameter
          assert_eq(overloads.signatures[1].parameters.length(), 1)
        }
        None => fail("Expected to find foo")
      }
    }
    Err(_) => fail("Parse failed")
  }
}
