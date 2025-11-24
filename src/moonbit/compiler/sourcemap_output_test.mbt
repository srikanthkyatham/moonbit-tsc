// Tests for source map output generation (inline and external)

/// Test base64 encoding of simple strings
test "base64_encode_simple encodes basic strings" {
  // Test empty string
  let result = base64_encode_simple("")
  assert_eq(result, "")

  // Test single character (padding with ==)
  let result2 = base64_encode_simple("A")
  assert_true(result2.contains("=="))

  // Test two characters (padding with =)
  let result3 = base64_encode_simple("AB")
  assert_true(result3.contains("="))
  assert_false(result3.contains("=="))

  // Test three characters (no padding)
  let result4 = base64_encode_simple("ABC")
  assert_false(result4.contains("="))
}

/// Test base64 encoding produces valid base64 characters
test "base64_encode_simple produces valid characters" {
  let input = "Hello, World!"
  let result = base64_encode_simple(input)

  // Should only contain valid base64 characters: A-Z, a-z, 0-9, +, /, =
  assert_true(result.length() > 0)

  // Verify no invalid characters (simple check)
  assert_false(result.contains(" "))
  assert_false(result.contains("\n"))
}

/// Test generating inline source map comment
test "generate_inline_sourcemap_comment creates proper comment" {
  let sourcemap = SourceMap::new()
  let comment = generate_inline_sourcemap_comment(sourcemap)

  // Should start with sourceMappingURL comment
  assert_true(comment.contains("//# sourceMappingURL="))

  // Should be a data URI
  assert_true(comment.contains("data:application/json"))

  // Should specify charset and base64 encoding
  assert_true(comment.contains("charset=utf-8"))
  assert_true(comment.contains("base64"))
}

/// Test generating external source map reference
test "generate_sourcemap_reference creates proper reference" {
  let comment = generate_sourcemap_reference("output.js.map")

  assert_eq(comment, "//# sourceMappingURL=output.js.map")
}

/// Test generating output with no source map
test "generate_output_with_sourcemap mode SourceMapMode::NoMap" {
  let js_code = "const x = 42;"
  let sourcemap = SourceMap::new()

  let output = generate_output_with_sourcemap(
    js_code,
    sourcemap,
    SourceMapMode::NoMap,
    "output.js"
  )

  // Should return JS code unchanged
  assert_eq(output.js_code, js_code)

  // Should have no source map
  match output.source_map {
    Some(_) => fail("Expected no source map in SourceMapMode::NoMap mode")
    None => ()  // Success
  }

  // Should have no map file name
  match output.map_file_name {
    Some(_) => fail("Expected no map file name in SourceMapMode::NoMap mode")
    None => ()  // Success
  }
}

/// Test generating output with inline source map
test "generate_output_with_sourcemap mode SourceMapMode::InlineMap" {
  let js_code = "const x = 42;"
  let builder = SourceMapBuilder::new()
  let _ = builder.add_source("test.ts")
  let sourcemap = builder.build(Some("output.js"))

  let output = generate_output_with_sourcemap(
    js_code,
    sourcemap,
    SourceMapMode::InlineMap,
    "output.js"
  )

  // Should have appended inline source map comment
  assert_true(output.js_code.contains("const x = 42;"))
  assert_true(output.js_code.contains("//# sourceMappingURL="))
  assert_true(output.js_code.contains("data:application/json"))
  assert_true(output.js_code.contains("base64"))

  // Should have source map in output
  match output.source_map {
    Some(sm) => {
      assert_eq(sm.version, 3)
      assert_eq(sm.sources.length(), 1)
      assert_eq(sm.sources[0], "test.ts")
    }
    None => fail("Expected source map in SourceMapMode::InlineMap mode")
  }

  // Should have no map file name
  match output.map_file_name {
    Some(_) => fail("Expected no map file name in SourceMapMode::InlineMap mode")
    None => ()  // Success
  }
}

/// Test generating output with external source map
test "generate_output_with_sourcemap mode SourceMapMode::ExternalMap" {
  let js_code = "const x = 42;"
  let builder = SourceMapBuilder::new()
  let _ = builder.add_source("test.ts")
  let sourcemap = builder.build(Some("output.js"))

  let output = generate_output_with_sourcemap(
    js_code,
    sourcemap,
    SourceMapMode::ExternalMap,
    "output.js"
  )

  // Should have appended external source map reference
  assert_true(output.js_code.contains("const x = 42;"))
  assert_true(output.js_code.contains("//# sourceMappingURL=output.js.map"))

  // Should NOT contain inline base64 data
  assert_false(output.js_code.contains("data:application/json"))
  assert_false(output.js_code.contains("base64"))

  // Should have source map in output
  match output.source_map {
    Some(sm) => {
      assert_eq(sm.version, 3)
      assert_eq(sm.sources[0], "test.ts")
    }
    None => fail("Expected source map in SourceMapMode::ExternalMap mode")
  }

  // Should have map file name
  match output.map_file_name {
    Some(name) => assert_eq(name, "output.js.map")
    None => fail("Expected map file name in SourceMapMode::ExternalMap mode")
  }
}

/// Test inline vs external source map differences
test "inline vs external source map output differs" {
  let js_code = "const greeting = \"hello\";"
  let builder = SourceMapBuilder::new()
  let _ = builder.add_source("input.ts")
  let sourcemap = builder.build(Some("output.js"))

  let inline_output = generate_output_with_sourcemap(
    js_code,
    sourcemap,
    SourceMapMode::InlineMap,
    "output.js"
  )

  let external_output = generate_output_with_sourcemap(
    js_code,
    sourcemap,
    SourceMapMode::ExternalMap,
    "output.js"
  )

  // SourceMapMode::InlineMap should be longer (contains full base64-encoded map)
  assert_true(inline_output.js_code.length() > external_output.js_code.length())

  // SourceMapMode::ExternalMap should reference .map file
  assert_true(external_output.js_code.contains(".map"))

  // SourceMapMode::InlineMap should contain data URI
  assert_true(inline_output.js_code.contains("data:"))
}

/// Test source map output with complex code
test "generate_output_with_sourcemap with multi-line code" {
  let js_code = "function add(a, b) {\n  return a + b;\n}"
  let builder = SourceMapBuilder::new()
  let _ = builder.add_source("math.ts")
  builder.add_mapping(0, 0, "math.ts", 0, 0, Some("add"))
  let sourcemap = builder.build(Some("math.js"))

  let output = generate_output_with_sourcemap(
    js_code,
    sourcemap,
    SourceMapMode::ExternalMap,
    "math.js"
  )

  // Original code should be preserved
  assert_true(output.js_code.contains("function add"))
  assert_true(output.js_code.contains("return a + b"))

  // Source map reference should be appended
  assert_true(output.js_code.contains("//# sourceMappingURL=math.js.map"))

  // Source map should have the mapping
  match output.source_map {
    Some(sm) => {
      assert_true(sm.names.contains("add"))
      assert_true(sm.mappings.length() > 0)
    }
    None => fail("Expected source map")
  }
}

/// Test that base64 encoding handles various input sizes
test "base64_encode_simple handles different input sizes" {
  // 1 byte (needs ==)
  let result1 = base64_encode_simple("a")
  assert_true(result1.length() == 4)
  assert_true(result1.contains("=="))

  // 2 bytes (needs =)
  let result2 = base64_encode_simple("ab")
  assert_true(result2.length() == 4)
  assert_true(result2.contains("="))
  assert_false(result2.contains("=="))

  // 3 bytes (no padding)
  let result3 = base64_encode_simple("abc")
  assert_true(result3.length() == 4)
  assert_false(result3.contains("="))

  // 4 bytes
  let result4 = base64_encode_simple("abcd")
  assert_true(result4.length() == 8)

  // 5 bytes
  let result5 = base64_encode_simple("abcde")
  assert_true(result5.length() == 8)

  // 6 bytes
  let result6 = base64_encode_simple("abcdef")
  assert_true(result6.length() == 8)
  assert_false(result6.contains("="))
}

/// Test inline source map with actual JSON content
test "inline source map includes actual JSON data" {
  let builder = SourceMapBuilder::new()
  let _ = builder.add_source("app.ts")
  let _ = builder.add_name("main")
  builder.add_mapping(0, 0, "app.ts", 0, 0, Some("main"))

  let sourcemap = builder.build(Some("app.js"))
  let comment = generate_inline_sourcemap_comment(sourcemap)

  // The comment should contain the base64-encoded source map
  assert_true(comment.length() > 50)  // Should be substantial
  assert_true(comment.contains("sourceMappingURL"))
}
