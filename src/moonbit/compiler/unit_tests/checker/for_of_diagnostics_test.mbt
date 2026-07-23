// Unit tests for for-of loop diagnostic capture fixes
// Tests that diagnostics (TS2304, TS2322) are properly captured in add_for_of_variable_to_scope

///|
/// Helper function to check if a specific diagnostic code exists
fn has_for_of_diagnostic(
  diagnostics : Array[@compiler.Diagnostic],
  code : Int
) -> Bool {
  for diag in diagnostics {
    if diag.code == code {
      return true
    }
  }
  false
}

test "TS2304: Undeclared variable in for-of loop" {
  let source = "const arr: number[] = [1, 2, 3]; for (x of arr) {}"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => fail("Should report TS2304 for undeclared variable")
            Err(diagnostics) =>
              if !(has_for_of_diagnostic(diagnostics, 2304)) {
                fail("Should report TS2304 for undeclared variable 'x'")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS2322: Type mismatch in for-of with identifier" {
  let source = "const arr: number[] = [1, 2, 3]; let x: string; for (x of arr) {}"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => fail("Should report TS2322 for type mismatch")
            Err(diagnostics) =>
              if !(has_for_of_diagnostic(diagnostics, 2322)) {
                fail("Should report TS2322 for number -> string assignment")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS2322: Type mismatch in for-of with property access" {
  let source = "const obj = { prop: '' }; const arr: number[] = [1, 2, 3]; for (obj.prop of arr) {}"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => fail("Should report TS2322 for type mismatch in property access")
            Err(diagnostics) =>
              if !(has_for_of_diagnostic(diagnostics, 2322)) {
                fail("Should report TS2322 for number -> string assignment to property")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS2322: Type mismatch in for-of with element access" {
  let source = "const obj: { [key: string]: string } = {}; const arr: number[] = [1, 2, 3]; for (obj['key'] of arr) {}"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => fail("Should report TS2322 for type mismatch in element access")
            Err(diagnostics) =>
              if !(has_for_of_diagnostic(diagnostics, 2322)) {
                fail("Should report TS2322 for number -> string assignment to element")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "TS2588: Cannot assign to const in for-of" {
  let source = "const arr: number[] = [1, 2, 3]; const x = 0; for (x of arr) {}"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => fail("Should report TS2588 for assigning to const")
            Err(diagnostics) =>
              if !(has_for_of_diagnostic(diagnostics, 2588)) {
                fail("Should report TS2588 for assigning to const variable")
              }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "Valid for-of with matching types should pass" {
  let source = "const arr: number[] = [1, 2, 3]; let x: number; for (x of arr) {}"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => () // Should pass
            Err(diagnostics) => {
              // Print diagnostics for debugging
              let mut msg = "Unexpected errors:\n"
              for diag in diagnostics {
                msg = msg + "TS" + diag.code.to_string() + ": " + diag.message + "\n"
              }
              fail(msg)
            }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}

test "Valid for-of with property access should pass" {
  let source = "const obj = { prop: 0 }; const arr: number[] = [1, 2, 3]; for (obj.prop of arr) {}"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => () // Should pass
            Err(diagnostics) => {
              // Print diagnostics for debugging
              let mut msg = "Unexpected errors:\n"
              for diag in diagnostics {
                msg = msg + "TS" + diag.code.to_string() + ": " + diag.message + "\n"
              }
              fail(msg)
            }
          }
        Err(_) => fail("Binding failed")
      }
    Err(_) => fail("Parse failed")
  }
}
