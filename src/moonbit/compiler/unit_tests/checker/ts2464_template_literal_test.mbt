// TS2464: Template Literal Support in Computed Property Names
// Tests that template literals are accepted as valid computed property names

///|
/// Helper to check if any diagnostic has error code 2464
fn has_ts2464(diagnostics : Array[@compiler.Diagnostic]) -> Bool {
  for diag in diagnostics {
    if diag.code == 2464 {
      return true
    }
  }
  false
}

test "TS2464: Template literal without substitutions - should pass" {
  let source = "var obj = { [`hello bye`]: 0 };"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => () // Success - no errors expected
            Err(diagnostics) =>
              if has_ts2464(diagnostics) {
                fail("Should NOT report TS2464 for template literal without substitutions")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS2464: Template literal with substitutions - should pass" {
  let source = "var a: any; var obj = { [`hello ${a} bye`]: 0 };"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => ()
            Err(diagnostics) =>
              if has_ts2464(diagnostics) {
                fail("Should NOT report TS2464 for template literal with substitutions")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS2464: Template literal in method name - should pass" {
  let source = "var obj = { [`hello bye`]() { } };"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => ()
            Err(diagnostics) =>
              if has_ts2464(diagnostics) {
                fail("Should NOT report TS2464 for template literal in method")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS2464: Template literal in getter - should pass" {
  let source = "var obj = { get [`hello bye`]() { return 0; } };"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => ()
            Err(diagnostics) =>
              if has_ts2464(diagnostics) {
                fail("Should NOT report TS2464 for template literal in getter")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS2464: Template literal in setter - should pass" {
  let source = "var obj = { set [`hello bye`](v) { } };"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => ()
            Err(diagnostics) =>
              if has_ts2464(diagnostics) {
                fail("Should NOT report TS2464 for template literal in setter")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS2464: String/number/symbol/any types still valid" {
  let source = "var s: string; var n: number; var sym: symbol; var a: any; var obj = { [s]: 0, [n]: 1, [sym]: 2, [a]: 3 };"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => ()
            Err(diagnostics) =>
              if has_ts2464(diagnostics) {
                fail("Should NOT report TS2464 for string/number/symbol/any types")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS2464: Boolean type should still error" {
  let source = "var b: boolean; var obj = { [b]: 0 };"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => fail("Should report TS2464 for boolean type")
            Err(diagnostics) =>
              if not(has_ts2464(diagnostics)) {
                fail("Should report TS2464 for boolean type")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS2464: Object type should still error" {
  let source = "var obj1 = {}; var obj2 = { [obj1]: 0 };"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => fail("Should report TS2464 for object type")
            Err(diagnostics) =>
              if not(has_ts2464(diagnostics)) {
                fail("Should report TS2464 for object type")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS2464: Union of valid types should work" {
  let source = "var u: string | number | symbol; var obj = { [u]: 0 };"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => ()
            Err(diagnostics) =>
              if has_ts2464(diagnostics) {
                fail("Should NOT report TS2464 for union of valid types")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS2464: Union with invalid type should error" {
  let source = "var u: string | boolean; var obj = { [u]: 0 };"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => fail("Should report TS2464 for union with invalid type")
            Err(diagnostics) =>
              if not(has_ts2464(diagnostics)) {
                fail("Should report TS2464 for union with invalid type")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS2464: Type assertion to valid type should work" {
  let source = "var obj = { [<any>true]: 0, [<string>123]: 1 };"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => ()
            Err(diagnostics) =>
              if has_ts2464(diagnostics) {
                fail("Should NOT report TS2464 for type assertion to valid type")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS2464: String expressions should work" {
  let source = "var s: string; var n: number; var obj = { [s + s]: 0, [s + n]: 1 };"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => ()
            Err(diagnostics) =>
              if has_ts2464(diagnostics) {
                fail("Should NOT report TS2464 for string expressions")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS2464: Multiple template literals should work" {
  let source = "var a: any; var obj = { [`prop1`]: 1, [`prop${a}`]: 2, [`method`]() { }, get [`getter`]() { return 0; }, set [`setter`](v) { } };"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => ()
            Err(diagnostics) =>
              if has_ts2464(diagnostics) {
                fail("Should NOT report TS2464 for multiple template literals")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}
