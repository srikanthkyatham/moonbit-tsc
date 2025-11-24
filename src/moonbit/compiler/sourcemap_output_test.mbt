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
    SourceMapMode::no_map(),
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
    SourceMapMode::inline_map(),
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
    SourceMapMode::external_map(),
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
    SourceMapMode::inline_map(),
    "output.js"
  )

  let external_output = generate_output_with_sourcemap(
    js_code,
    sourcemap,
    SourceMapMode::external_map(),
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
    SourceMapMode::external_map(),
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

/// Test: Source map for class methods
test "sourcemap for class methods" {
  let builder = SourceMapBuilder::new()
  let _ = builder.add_source("class.ts")

  // Add mappings for class declaration and methods
  builder.add_mapping(0, 0, "class.ts", 0, 0, None)  // class keyword
  builder.add_mapping(0, 6, "class.ts", 0, 6, Some("Person"))  // class name
  builder.add_mapping(1, 2, "class.ts", 1, 2, Some("greet"))  // method name
  builder.add_mapping(1, 12, "class.ts", 1, 12, None)  // method params

  let sourcemap = builder.build(Some("class.js"))
  let json = sourcemap.to_json()

  // Verify sourcemap contains method mappings
  assert_true(json.contains("\"sources\""))
  assert_true(json.contains("class.ts"))
  assert_true(json.contains("\"names\""))
  assert_true(json.contains("Person"))
  assert_true(json.contains("greet"))
}

/// Test: Source map for property access chains
test "sourcemap for property access" {
  let builder = SourceMapBuilder::new()
  let _ = builder.add_source("access.ts")
  let _ = builder.add_name("user")
  let _ = builder.add_name("profile")
  let _ = builder.add_name("name")

  // Add mappings for: user.profile.name
  builder.add_mapping(0, 0, "access.ts", 0, 0, Some("user"))
  builder.add_mapping(0, 5, "access.ts", 0, 5, Some("profile"))
  builder.add_mapping(0, 13, "access.ts", 0, 13, Some("name"))

  let sourcemap = builder.build(Some("access.js"))
  let json = sourcemap.to_json()

  assert_true(json.contains("user"))
  assert_true(json.contains("profile"))
  assert_true(json.contains("name"))
}

/// Test: Source map for binary expressions
test "sourcemap for binary expressions" {
  let builder = SourceMapBuilder::new()
  let _ = builder.add_source("math.ts")
  let _ = builder.add_name("a")
  let _ = builder.add_name("b")

  // Add mappings for: a + b * 2
  builder.add_mapping(0, 0, "math.ts", 0, 0, Some("a"))
  builder.add_mapping(0, 4, "math.ts", 0, 4, Some("b"))

  let sourcemap = builder.build(Some("math.js"))
  let json = sourcemap.to_json()

  assert_true(json.contains("\"names\""))
  assert_true(json.contains("math.ts"))
}

/// Test: Source map with multiple files
test "sourcemap with multiple files" {
  let builder = SourceMapBuilder::new()
  let _ = builder.add_source("main.ts")
  let _ = builder.add_source("utils.ts")
  let _ = builder.add_name("main")
  let _ = builder.add_name("helper")

  // Mappings from main.ts
  builder.add_mapping(0, 0, "main.ts", 0, 0, Some("main"))
  builder.new_line()

  // Mappings from utils.ts
  builder.add_mapping(1, 0, "utils.ts", 0, 0, Some("helper"))

  let sourcemap = builder.build(Some("bundle.js"))
  let json = sourcemap.to_json()

  assert_true(json.contains("main.ts"))
  assert_true(json.contains("utils.ts"))
  assert_true(json.contains("main"))
  assert_true(json.contains("helper"))
}

/// Test: Complex nested structure sourcemap
test "sourcemap for nested structures" {
  let builder = SourceMapBuilder::new()
  let _ = builder.add_source("nested.ts")
  let _ = builder.add_name("obj")
  let _ = builder.add_name("nested")
  let _ = builder.add_name("value")

  // Object with nested properties
  builder.add_mapping(0, 0, "nested.ts", 0, 0, None)  // const keyword
  builder.add_mapping(0, 6, "nested.ts", 0, 6, Some("obj"))  // obj name
  builder.add_mapping(1, 2, "nested.ts", 1, 2, Some("nested"))  // nested property
  builder.add_mapping(2, 4, "nested.ts", 2, 4, Some("value"))  // deeply nested

  let sourcemap = builder.build(Some("nested.js"))
  let json = sourcemap.to_json()

  assert_true(json.contains("nested.ts"))
  assert_true(json.contains("obj"))
  assert_true(json.contains("nested"))
  assert_true(json.contains("value"))
}
