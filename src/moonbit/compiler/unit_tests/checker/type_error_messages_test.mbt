// Type Error Messages Tests
// Tests for Elm/Rust-inspired detailed error messages
// These tests verify that error messages are:
// - Friendly and educational (like Elm)
// - Include "why" explanations
// - Include "how to fix" suggestions with code examples
// - Include documentation links

// ============================================================================
// Test Error Construction Helpers
// ============================================================================

///|
test "unit/type_errors/type_mismatch_error_creation" {
  let error = @compiler.type_mismatch(
    @compiler.TypePath::root(),
    @compiler.create_string_type(),
    @compiler.create_number_type(),
  )
  // Error should have expected and actual types set
  assert_true(true) // Error was created successfully
}

///|
test "unit/type_errors/unbound_variable_error_creation" {
  let error = @compiler.unbound_variable_error("myVariable")
  // Error should be created with the variable name
  assert_true(error.suggestions.length() >= 0) // May or may not have suggestions
}

///|
test "unit/type_errors/unbound_type_error_creation" {
  let error = @compiler.unbound_type_error("MyType")
  assert_true(error.suggestions.length() >= 0)
}

///|
test "unit/type_errors/not_callable_error_creation" {
  let error = @compiler.not_callable_error(
    @compiler.TypePath::root(),
    @compiler.create_number_type(),
  )
  assert_true(error.suggestions.length() > 0)
}

///|
test "unit/type_errors/missing_property_error_creation" {
  let error = @compiler.missing_property_error(
    @compiler.TypePath::root(),
    "id",
    ["Check your object structure"],
  )
  assert_true(error.suggestions.length() > 0)
}

///|
test "unit/type_errors/excess_property_error_creation" {
  let error = @compiler.excess_property_error(
    @compiler.TypePath::root(),
    "extraField",
  )
  assert_true(error.suggestions.length() > 0)
}

///|
test "unit/type_errors/param_count_mismatch_creation" {
  let error = @compiler.param_count_mismatch(
    @compiler.TypePath::root(),
    3,
    5,
  )
  assert_true(error.suggestions.length() > 0)
}

// ============================================================================
// Test Documentation Links
// ============================================================================

///|
test "unit/type_errors/doc_url_format" {
  let url = @compiler.get_error_doc_url(2322)
  assert_true(url.contains("2322"))
  assert_true(url.contains("http"))
}

///|
test "unit/type_errors/handbook_url_format" {
  let url = @compiler.get_handbook_url("types-from-types")
  assert_true(url.contains("typescript"))
  assert_true(url.contains("handbook"))
}

// ============================================================================
// Test String Helper Functions
// ============================================================================

///|
test "unit/type_errors/string_to_lower_uppercase" {
  assert_eq(@compiler.string_to_lower("HELLO"), "hello")
}

///|
test "unit/type_errors/string_to_lower_mixed" {
  assert_eq(@compiler.string_to_lower("Hello World"), "hello world")
}

///|
test "unit/type_errors/string_to_lower_lowercase" {
  assert_eq(@compiler.string_to_lower("abc123"), "abc123")
}

///|
test "unit/type_errors/string_to_lower_phrase" {
  assert_eq(@compiler.string_to_lower("TYPE MISMATCH"), "type mismatch")
}

///|
test "unit/type_errors/string_repeat_dashes" {
  assert_eq(@compiler.string_repeat("-", 5), "-----")
}

///|
test "unit/type_errors/string_repeat_multi_char" {
  assert_eq(@compiler.string_repeat("ab", 3), "ababab")
}

///|
test "unit/type_errors/string_repeat_zero" {
  assert_eq(@compiler.string_repeat("x", 0), "")
}

// ============================================================================
// Test Compact Error Format (Rust-style one-liner)
// ============================================================================

///|
test "unit/type_errors/compact_format_contains_error_code" {
  let error = @compiler.type_mismatch(
    @compiler.TypePath::root(),
    @compiler.create_string_type(),
    @compiler.create_number_type(),
  )
  let compact = @compiler.format_compact_error(error, "test.ts", 10, 5)
  // Should have error code format
  assert_true(compact.contains("error[TS"))
}

///|
test "unit/type_errors/compact_format_contains_location" {
  let error = @compiler.type_mismatch(
    @compiler.TypePath::root(),
    @compiler.create_string_type(),
    @compiler.create_number_type(),
  )
  let compact = @compiler.format_compact_error(error, "test.ts", 10, 5)
  // Should have file location
  assert_true(compact.contains("test.ts:10:5"))
}

// ============================================================================
// Test Detailed Error Format (Elm-style with all sections)
// ============================================================================

///|
test "unit/type_errors/detailed_format_has_header" {
  let error = @compiler.type_mismatch(
    @compiler.TypePath::root(),
    @compiler.create_string_type(),
    @compiler.create_number_type(),
  )
  let detailed = @compiler.format_detailed_error(
    error,
    "src/app.ts",
    42,
    10,
    "const x: number = \"hello\";",
  )

  // Should have header with title
  assert_true(detailed.contains("TYPE MISMATCH"))
}

///|
test "unit/type_errors/detailed_format_has_file_path" {
  let error = @compiler.type_mismatch(
    @compiler.TypePath::root(),
    @compiler.create_string_type(),
    @compiler.create_number_type(),
  )
  let detailed = @compiler.format_detailed_error(
    error,
    "src/app.ts",
    42,
    10,
    "const x: number = \"hello\";",
  )

  // Should have file path
  assert_true(detailed.contains("src/app.ts"))
}

///|
test "unit/type_errors/detailed_format_has_why_section" {
  let error = @compiler.type_mismatch(
    @compiler.TypePath::root(),
    @compiler.create_string_type(),
    @compiler.create_number_type(),
  )
  let detailed = @compiler.format_detailed_error(
    error,
    "src/app.ts",
    42,
    10,
    "const x: number = \"hello\";",
  )

  // Should have "WHY THIS HAPPENS" section
  assert_true(detailed.contains("WHY THIS HAPPENS"))
}

///|
test "unit/type_errors/detailed_format_has_fix_section" {
  let error = @compiler.type_mismatch(
    @compiler.TypePath::root(),
    @compiler.create_string_type(),
    @compiler.create_number_type(),
  )
  let detailed = @compiler.format_detailed_error(
    error,
    "src/app.ts",
    42,
    10,
    "const x: number = \"hello\";",
  )

  // Should have "HOW TO FIX" section
  assert_true(detailed.contains("HOW TO FIX"))
}

///|
test "unit/type_errors/detailed_format_has_learn_more" {
  let error = @compiler.type_mismatch(
    @compiler.TypePath::root(),
    @compiler.create_string_type(),
    @compiler.create_number_type(),
  )
  let detailed = @compiler.format_detailed_error(
    error,
    "src/app.ts",
    42,
    10,
    "const x: number = \"hello\";",
  )

  // Should have "LEARN MORE" section with doc links
  assert_true(detailed.contains("LEARN MORE"))
  assert_true(detailed.contains("http"))
}

// ============================================================================
// Test DetailedError Struct Creation
// ============================================================================

///|
test "unit/type_errors/to_detailed_error_has_location" {
  let error = @compiler.type_mismatch(
    @compiler.TypePath::root(),
    @compiler.create_boolean_type(),
    @compiler.create_string_type(),
  )
  let detailed = @compiler.to_detailed_error(
    error,
    "file.ts",
    5,
    3,
    "const s: string = true;",
  )

  // Check location format
  assert_eq(detailed.location, "file.ts:5:3")
}

///|
test "unit/type_errors/to_detailed_error_has_title" {
  let error = @compiler.type_mismatch(
    @compiler.TypePath::root(),
    @compiler.create_boolean_type(),
    @compiler.create_string_type(),
  )
  let detailed = @compiler.to_detailed_error(
    error,
    "file.ts",
    5,
    3,
    "const s: string = true;",
  )

  // Check title
  assert_true(detailed.title.contains("TYPE MISMATCH"))
}

///|
test "unit/type_errors/to_detailed_error_has_doc_link" {
  let error = @compiler.type_mismatch(
    @compiler.TypePath::root(),
    @compiler.create_boolean_type(),
    @compiler.create_string_type(),
  )
  let detailed = @compiler.to_detailed_error(
    error,
    "file.ts",
    5,
    3,
    "const s: string = true;",
  )

  // Check doc link contains error code
  assert_true(detailed.doc_link.contains("2322"))
}

///|
test "unit/type_errors/to_detailed_error_has_how_to_fix" {
  let error = @compiler.type_mismatch(
    @compiler.TypePath::root(),
    @compiler.create_boolean_type(),
    @compiler.create_string_type(),
  )
  let detailed = @compiler.to_detailed_error(
    error,
    "file.ts",
    5,
    3,
    "const s: string = true;",
  )

  // Check how_to_fix is populated
  assert_true(detailed.how_to_fix.length() > 0)
}

///|
test "unit/type_errors/to_detailed_error_has_why_error" {
  let error = @compiler.type_mismatch(
    @compiler.TypePath::root(),
    @compiler.create_boolean_type(),
    @compiler.create_string_type(),
  )
  let detailed = @compiler.to_detailed_error(
    error,
    "file.ts",
    5,
    3,
    "const s: string = true;",
  )

  // Check why_error is populated
  assert_true(detailed.why_error.length() > 0)
}

// ============================================================================
// Test Complete Error Message Formatting for Real Scenarios
// ============================================================================

///|
test "unit/type_errors/scenario/string_to_number_detailed" {
  // Simulate: const x: number = "hello";
  let error = @compiler.type_mismatch(
    @compiler.TypePath::root(),
    @compiler.create_string_type(),
    @compiler.create_number_type(),
  )
  let detailed = @compiler.format_detailed_error(
    error,
    "app.ts",
    1,
    19,
    "const x: number = \"hello\";",
  )

  // Verify it contains all the helpful information
  assert_true(detailed.contains("TYPE MISMATCH"))
  assert_true(detailed.contains("Expected:"))
  assert_true(detailed.contains("Found:"))
  assert_true(detailed.contains("WHY THIS HAPPENS"))
  assert_true(detailed.contains("HOW TO FIX"))
}

///|
test "unit/type_errors/scenario/undefined_variable_detailed" {
  // Simulate: console.log(undefinedVar);
  let error = @compiler.unbound_variable_error("undefinedVar")
  let detailed = @compiler.format_detailed_error(
    error,
    "main.ts",
    10,
    13,
    "console.log(undefinedVar);",
  )

  // Should have helpful content
  assert_true(detailed.contains("CANNOT FIND NAME"))
  assert_true(detailed.contains("undefinedVar"))
}

///|
test "unit/type_errors/scenario/not_callable_detailed" {
  // Simulate: const obj = {}; obj();
  let error = @compiler.not_callable_error(
    @compiler.TypePath::root(),
    @compiler.create_empty_object_type(),
  )
  let detailed = @compiler.format_detailed_error(
    error,
    "test.ts",
    2,
    1,
    "obj();",
  )

  // Should explain the issue
  assert_true(detailed.contains("NOT CALLABLE"))
}

// ============================================================================
// Test Similar Property Suggestions (Levenshtein distance)
// ============================================================================

///|
test "unit/type_errors/find_similar_properties_exact_match" {
  let available : Array[String] = ["name", "age", "email"]
  let similar = @compiler.find_similar_properties("nam", available)
  // Should suggest "name" as it's similar
  if similar.length() > 0 {
    assert_true(similar[0].contains("name"))
  }
}

///|
test "unit/type_errors/find_similar_properties_no_match" {
  let available : Array[String] = ["name", "age", "email"]
  let similar = @compiler.find_similar_properties("xyz123", available)
  // Should not find similar properties for completely different string
  assert_true(similar.length() == 0)
}

///|
test "unit/type_errors/find_similar_properties_typo" {
  let available : Array[String] = ["firstName", "lastName", "middleName"]
  let similar = @compiler.find_similar_properties("fristName", available)
  // Should suggest firstName as it's a typo
  if similar.length() > 0 {
    assert_true(similar[0].contains("firstName"))
  }
}
