// Unit tests for TS5107: Option 'module={AMD|UMD}' is deprecated

///|
/// Helper to check source with specific module kind
fn check_with_module_kind(
  source : String,
  module_kind : @compiler.ModuleKind
) -> @compiler.CheckResult {
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          @compiler.check_source_file_with_options(
            bound,
            false,
            @compiler.Target::ES2015,
            module_kind~,
          )
        Err(diags) => Err(diags)
      }
    Err(diags) => Err(diags)
  }
}

test "TS5107: AMD module kind produces deprecation warning" {
  let source = "export default function foo() {}"

  let result = check_with_module_kind(source, @compiler.AMD)
  let diagnostics = match result {
    Ok(typed) => typed.diagnostics
    Err(diags) => diags
  }

  // Should have TS5107 error
  let has_ts5107 = diagnostics.iter().any(fn(d) { d.code == 5107 })
  assert_true(has_ts5107)

  // Check message contains "AMD"
  let mut found_message = ""
  for d in diagnostics {
    if d.code == 5107 {
      found_message = d.message
      break
    }
  }
  assert_true(found_message.contains("AMD"))
  assert_true(found_message.contains("deprecated"))
}

test "TS5107: UMD module kind produces deprecation warning" {
  let source = "export default function foo() {}"

  let result = check_with_module_kind(source, @compiler.UMD)
  let diagnostics = match result {
    Ok(typed) => typed.diagnostics
    Err(diags) => diags
  }

  // Should have TS5107 error
  let has_ts5107 = diagnostics.iter().any(fn(d) { d.code == 5107 })
  assert_true(has_ts5107)

  // Check message contains "UMD"
  let mut found_message = ""
  for d in diagnostics {
    if d.code == 5107 {
      found_message = d.message
      break
    }
  }
  assert_true(found_message.contains("UMD"))
  assert_true(found_message.contains("deprecated"))
}

test "TS5107: ESModule does not produce deprecation warning" {
  let source = "export default function foo() {}"

  let result = check_with_module_kind(source, @compiler.ESModule)
  let diagnostics = match result {
    Ok(typed) => typed.diagnostics
    Err(diags) => diags
  }

  // Should NOT have TS5107 error
  let has_ts5107 = diagnostics.iter().any(fn(d) { d.code == 5107 })
  assert_false(has_ts5107)
}

test "TS5107: CommonJS does not produce deprecation warning" {
  let source = "export default function foo() {}"

  let result = check_with_module_kind(source, @compiler.CommonJS)
  let diagnostics = match result {
    Ok(typed) => typed.diagnostics
    Err(diags) => diags
  }

  // Should NOT have TS5107 error
  let has_ts5107 = diagnostics.iter().any(fn(d) { d.code == 5107 })
  assert_false(has_ts5107)
}

test "TS5107: deprecation warning on empty file with AMD" {
  let source = ""

  let result = check_with_module_kind(source, @compiler.AMD)
  let diagnostics = match result {
    Ok(typed) => typed.diagnostics
    Err(diags) => diags
  }

  // Should still have TS5107 error even with empty file
  let has_ts5107 = diagnostics.iter().any(fn(d) { d.code == 5107 })
  assert_true(has_ts5107)
}

test "TS5107: deprecation warning on empty file with UMD" {
  let source = ""

  let result = check_with_module_kind(source, @compiler.UMD)
  let diagnostics = match result {
    Ok(typed) => typed.diagnostics
    Err(diags) => diags
  }

  // Should still have TS5107 error even with empty file
  let has_ts5107 = diagnostics.iter().any(fn(d) { d.code == 5107 })
  assert_true(has_ts5107)
}
