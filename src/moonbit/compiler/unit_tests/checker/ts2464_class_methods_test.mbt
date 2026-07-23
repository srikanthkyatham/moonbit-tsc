// TS2464: Class Method/Accessor Computed Property Name Validation
// Tests that class methods, getters, and setters with computed names must use string/number/symbol/any types
// Unlike TS1166 (for class properties), TS2464 is less strict and accepts general string/number types

///|
/// Helper to check if any diagnostic has error code 2464
fn has_ts2464_method(diagnostics : Array[@compiler.Diagnostic]) -> Bool {
  for diag in diagnostics {
    if diag.code == 2464 {
      return true
    }
  }
  false
}

// ===== Valid Cases for Methods (should NOT emit TS2464) =====

test "TS2464: Number literal computed method - should pass" {
  let source = "class C { [0]() {} }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => () // Success
            Err(diagnostics) =>
              if has_ts2464_method(diagnostics) {
                fail("Should NOT report TS2464 for number literal method")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS2464: String literal computed method - should pass" {
  let source = "class C { [\"method\"]() {} }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => ()
            Err(diagnostics) =>
              if has_ts2464_method(diagnostics) {
                fail("Should NOT report TS2464 for string literal method")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS2464: Number variable computed method - should pass" {
  let source = "var n: number; class C { [n]() {} }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => ()
            Err(diagnostics) =>
              if has_ts2464_method(diagnostics) {
                fail("Should NOT report TS2464 for number variable method")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS2464: String variable computed method - should pass" {
  let source = "var s: string; class C { [s]() {} }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => ()
            Err(diagnostics) =>
              if has_ts2464_method(diagnostics) {
                fail("Should NOT report TS2464 for string variable method")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS2464: Any variable computed method - should pass" {
  let source = "var a: any; class C { [a]() {} }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => ()
            Err(diagnostics) =>
              if has_ts2464_method(diagnostics) {
                fail("Should NOT report TS2464 for any variable method")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

// ===== Valid Cases for Getters (should NOT emit TS2464) =====

test "TS2464: Number variable computed getter - should pass" {
  let source = "var n: number; class C { get [n]() { return 1; } }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => ()
            Err(diagnostics) =>
              if has_ts2464_method(diagnostics) {
                fail("Should NOT report TS2464 for number variable getter")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS2464: String variable computed getter - should pass" {
  let source = "var s: string; class C { get [s]() { return 1; } }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => ()
            Err(diagnostics) =>
              if has_ts2464_method(diagnostics) {
                fail("Should NOT report TS2464 for string variable getter")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

// ===== Valid Cases for Setters (should NOT emit TS2464) =====

test "TS2464: Number variable computed setter - should pass" {
  let source = "var n: number; class C { set [n](value: any) {} }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => ()
            Err(diagnostics) =>
              if has_ts2464_method(diagnostics) {
                fail("Should NOT report TS2464 for number variable setter")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS2464: String variable computed setter - should pass" {
  let source = "var s: string; class C { set [s](value: any) {} }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => ()
            Err(diagnostics) =>
              if has_ts2464_method(diagnostics) {
                fail("Should NOT report TS2464 for string variable setter")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

// ===== Invalid Cases for Methods (should emit TS2464) =====

test "TS2464: Boolean variable computed method - should error" {
  let source = "var b: boolean; class C { [b]() {} }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => fail("Should report TS2464 for boolean variable method")
            Err(diagnostics) =>
              if !(has_ts2464_method(diagnostics)) {
                fail("Should report TS2464 for boolean variable method")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS2464: Object variable computed method - should error" {
  let source = "var obj: object; class C { [obj]() {} }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => fail("Should report TS2464 for object variable method")
            Err(diagnostics) =>
              if !(has_ts2464_method(diagnostics)) {
                fail("Should report TS2464 for object variable method")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS2464: Boolean literal computed method - should error" {
  let source = "class C { [true]() {} }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => fail("Should report TS2464 for boolean literal method")
            Err(diagnostics) =>
              if !(has_ts2464_method(diagnostics)) {
                fail("Should report TS2464 for boolean literal method")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

// ===== Invalid Cases for Getters (should emit TS2464) =====

test "TS2464: Boolean variable computed getter - should error" {
  let source = "var b: boolean; class C { get [b]() { return 1; } }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => fail("Should report TS2464 for boolean variable getter")
            Err(diagnostics) =>
              if !(has_ts2464_method(diagnostics)) {
                fail("Should report TS2464 for boolean variable getter")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS2464: Object variable computed getter - should error" {
  let source = "var obj: object; class C { get [obj]() { return 1; } }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => fail("Should report TS2464 for object variable getter")
            Err(diagnostics) =>
              if !(has_ts2464_method(diagnostics)) {
                fail("Should report TS2464 for object variable getter")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

// ===== Invalid Cases for Setters (should emit TS2464) =====

test "TS2464: Boolean variable computed setter - should error" {
  let source = "var b: boolean; class C { set [b](value: any) {} }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => fail("Should report TS2464 for boolean variable setter")
            Err(diagnostics) =>
              if !(has_ts2464_method(diagnostics)) {
                fail("Should report TS2464 for boolean variable setter")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS2464: Object variable computed setter - should error" {
  let source = "var obj: object; class C { set [obj](value: any) {} }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => fail("Should report TS2464 for object variable setter")
            Err(diagnostics) =>
              if !(has_ts2464_method(diagnostics)) {
                fail("Should report TS2464 for object variable setter")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

// ===== Static Methods/Accessors =====

test "TS2464: Static method with number variable - should pass" {
  let source = "var n: number; class C { static [n]() {} }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => ()
            Err(diagnostics) =>
              if has_ts2464_method(diagnostics) {
                fail("Should NOT report TS2464 for static method with number variable")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS2464: Static method with boolean variable - should error" {
  let source = "var b: boolean; class C { static [b]() {} }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => fail("Should report TS2464 for static method with boolean variable")
            Err(diagnostics) =>
              if !(has_ts2464_method(diagnostics)) {
                fail("Should report TS2464 for static method with boolean variable")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

// ===== Mixed Cases =====

test "TS2464: Multiple methods - valid and invalid" {
  let source = "var n: number; var b: boolean; class C { [n]() {} [b]() {} }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => fail("Should report TS2464 for the invalid method")
            Err(diagnostics) =>
              if !(has_ts2464_method(diagnostics)) {
                fail("Should report TS2464 for the invalid method")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS2464: Getter and setter with same computed name" {
  let source = "var s: string; class C { get [s]() { return 1; } set [s](v: any) {} }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => ()
            Err(diagnostics) =>
              if has_ts2464_method(diagnostics) {
                fail("Should NOT report TS2464 for getter/setter with string variable")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}
