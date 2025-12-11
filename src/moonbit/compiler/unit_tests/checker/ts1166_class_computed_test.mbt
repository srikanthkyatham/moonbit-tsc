// TS1166: Class Computed Property Name Validation
// Tests that class properties with computed names must use literal types or unique symbols
// Unlike TS2464 (for object literals), TS1166 is stricter and only accepts literal types

///|
/// Helper to check if any diagnostic has error code 1166
fn has_ts1166(diagnostics : Array[@compiler.Diagnostic]) -> Bool {
  for diag in diagnostics {
    if diag.code == 1166 {
      return true
    }
  }
  false
}

// ===== Valid Cases (should NOT emit TS1166) =====

test "TS1166: Number literal computed property - should pass" {
  let source = "class C { [0]: number; }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => () // Success
            Err(diagnostics) =>
              if has_ts1166(diagnostics) {
                fail("Should NOT report TS1166 for number literal")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS1166: String literal computed property - should pass" {
  let source = "class C { [\"\"]: number; }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => ()
            Err(diagnostics) =>
              if has_ts1166(diagnostics) {
                fail("Should NOT report TS1166 for string literal")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS1166: Template literal without substitutions - should pass" {
  let source = "class C { [`hello bye`]: number; }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => ()
            Err(diagnostics) =>
              if has_ts1166(diagnostics) {
                fail("Should NOT report TS1166 for template literal without substitutions")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS1166: Static property with number literal - should pass" {
  let source = "class C { static [0]: number; }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => ()
            Err(diagnostics) =>
              if has_ts1166(diagnostics) {
                fail("Should NOT report TS1166 for static property with literal")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS1166: Multiple literal computed properties - should pass" {
  let source = "class C { [0]: number; [\"prop\"]: string; [`template`]: any; }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => ()
            Err(diagnostics) =>
              if has_ts1166(diagnostics) {
                fail("Should NOT report TS1166 for multiple literal properties")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

// ===== Invalid Cases (should emit TS1166) =====

test "TS1166: Number variable - should error" {
  let source = "var n: number; class C { [n]: number; }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => fail("Should report TS1166 for number variable")
            Err(diagnostics) =>
              if not(has_ts1166(diagnostics)) {
                fail("Should report TS1166 for number variable")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS1166: String variable - should error" {
  let source = "var s: string; class C { [s]: string; }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => fail("Should report TS1166 for string variable")
            Err(diagnostics) =>
              if not(has_ts1166(diagnostics)) {
                fail("Should report TS1166 for string variable")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS1166: Any variable - should error" {
  let source = "var a: any; class C { [a]: number; }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => fail("Should report TS1166 for any variable")
            Err(diagnostics) =>
              if not(has_ts1166(diagnostics)) {
                fail("Should report TS1166 for any variable")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS1166: String concatenation expression - should error" {
  let source = "var s: string; class C { [s + s]: string; }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => fail("Should report TS1166 for expression")
            Err(diagnostics) =>
              if not(has_ts1166(diagnostics)) {
                fail("Should report TS1166 for expression")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS1166: Template literal with substitutions - should error" {
  let source = "var a: any; class C { [`hello ${a} bye`]: number; }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => fail("Should report TS1166 for template with substitutions")
            Err(diagnostics) =>
              if not(has_ts1166(diagnostics)) {
                fail("Should report TS1166 for template with substitutions")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS1166: Type assertion to any - should error" {
  let source = "class C { [<any>true]: number; }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => fail("Should report TS1166 for type assertion to any")
            Err(diagnostics) =>
              if not(has_ts1166(diagnostics)) {
                fail("Should report TS1166 for type assertion to any")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS1166: Static property with non-literal - should error" {
  let source = "var n: number; class C { static [n]: number; }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => fail("Should report TS1166 for static property with non-literal")
            Err(diagnostics) =>
              if not(has_ts1166(diagnostics)) {
                fail("Should report TS1166 for static property with non-literal")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS1166: Unary plus expression - should error" {
  let source = "var s: string; class C { [+s]: any; }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => fail("Should report TS1166 for unary expression")
            Err(diagnostics) =>
              if not(has_ts1166(diagnostics)) {
                fail("Should report TS1166 for unary expression")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS1166: Property with initializer and non-literal name - should error" {
  let source = "var n: number; class C { [n] = 5; }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => fail("Should report TS1166 for property with initializer and non-literal name")
            Err(diagnostics) =>
              if not(has_ts1166(diagnostics)) {
                fail("Should report TS1166 for property with initializer and non-literal name")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

// ===== Edge Cases =====

test "TS1166: Mixed valid and invalid properties" {
  let source = "var n: number; class C { [0]: number; [n]: string; }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => fail("Should report TS1166 for the invalid property")
            Err(diagnostics) =>
              if not(has_ts1166(diagnostics)) {
                fail("Should report TS1166 for the invalid property")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS1166: Regression - TS2464 types still valid in object literals" {
  let source = "var s: string; var n: number; var obj = { [s]: 0, [n]: 1 };"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => () // Object literals should still allow string/number variables
            Err(diagnostics) =>
              // Should NOT have TS1166 (wrong context) or TS2464 (valid for object literals)
              for diag in diagnostics {
                if diag.code == 1166 {
                  fail("Should NOT report TS1166 for object literal (use TS2464 instead)")
                }
                if diag.code == 2464 {
                  fail("Should NOT report TS2464 for string/number variables in object literals")
                }
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}
