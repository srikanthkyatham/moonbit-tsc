// Tests for Source Map Generation

///|
/// Test creating an empty source map
test "SourceMap::new creates empty source map" {
  let sm = SourceMap::new()
  assert_eq(sm.version, 3)
  assert_eq(sm.file, None)
  assert_eq(sm.source_root, None)
  assert_eq(sm.sources.length(), 0)
  assert_eq(sm.sources_content, None)
  assert_eq(sm.names.length(), 0)
  assert_eq(sm.mappings, "")
}

///|
/// Test converting empty source map to JSON
test "SourceMap::to_json with empty map" {
  let sm = SourceMap::new()
  let json = sm.to_json()

  // Should contain version, empty sources, empty names, empty mappings
  assert_true(json.contains("\"version\": 3"))
  assert_true(json.contains("\"sources\": []"))
  assert_true(json.contains("\"names\": []"))
  assert_true(json.contains("\"mappings\": \"\""))
}

///|
/// Test converting source map with data to JSON
test "SourceMap::to_json with data" {
  let builder = SourceMapBuilder::new()

  // Add some sources and names
  let _ = builder.add_source("input.ts")
  let _ = builder.add_name("foo")
  let _ = builder.add_name("bar")
  let sm = builder.build(Some("output.js"))
  let json = sm.to_json()
  assert_true(json.contains("\"version\": 3"))
  assert_true(json.contains("\"file\": \"output.js\""))
  assert_true(json.contains("\"sources\": [\"input.ts\"]"))
  assert_true(json.contains("\"names\": [\"foo\", \"bar\"]"))
}

///|
/// Test JSON string escaping
test "escape_json_string handles special characters" {
  let s = "hello\"world"
  let result = escape_json_string(s)
  assert_true(result.contains("\\\""))
}

///|
/// Test creating a new SourceMapBuilder
test "SourceMapBuilder::new creates empty builder" {
  let builder = SourceMapBuilder::new()
  assert_eq(builder.sources.length(), 0)
  assert_eq(builder.names.length(), 0)
  assert_eq(builder.mappings.length(), 0)
  assert_eq(builder.generated_line, 0)
  assert_eq(builder.generated_column, 0)
}

///|
/// Test adding sources to builder
test "SourceMapBuilder::add_source" {
  let builder = SourceMapBuilder::new()
  let idx1 = builder.add_source("file1.ts")
  assert_eq(idx1, 0)
  assert_eq(builder.sources.length(), 1)
  assert_eq(builder.sources[0], "file1.ts")
  let idx2 = builder.add_source("file2.ts")
  assert_eq(idx2, 1)
  assert_eq(builder.sources.length(), 2)

  // Adding the same source again should return the same index
  let idx3 = builder.add_source("file1.ts")
  assert_eq(idx3, 0)
  assert_eq(builder.sources.length(), 2) // Length should not increase
}

///|
/// Test adding names to builder
test "SourceMapBuilder::add_name" {
  let builder = SourceMapBuilder::new()
  let idx1 = builder.add_name("foo")
  assert_eq(idx1, 0)
  assert_eq(builder.names.length(), 1)
  assert_eq(builder.names[0], "foo")
  let idx2 = builder.add_name("bar")
  assert_eq(idx2, 1)
  assert_eq(builder.names.length(), 2)

  // Adding the same name again should return the same index
  let idx3 = builder.add_name("foo")
  assert_eq(idx3, 0)
  assert_eq(builder.names.length(), 2) // Length should not increase
}

///|
/// Test adding mappings to builder
test "SourceMapBuilder::add_mapping" {
  let builder = SourceMapBuilder::new()
  builder.add_mapping(
    0, // generated_line
    0, // generated_column
    "test.ts", // source
    0, // original_line
    0, // original_column
    Some("foo"), // name
  )
  assert_eq(builder.mappings.length(), 1)
  assert_eq(builder.sources.length(), 1)
  assert_eq(builder.names.length(), 1)
  let mapping = builder.mappings[0]
  assert_eq(mapping.generated_line, 0)
  assert_eq(mapping.generated_column, 0)
  assert_eq(mapping.original_line, 0)
  assert_eq(mapping.original_column, 0)
  assert_eq(mapping.source_index, 0)
  match mapping.name_index {
    Some(idx) => assert_eq(idx, 0)
    None => fail("Expected name_index to be Some")
  }
}

///|
/// Test adding mapping without name
test "SourceMapBuilder::add_mapping without name" {
  let builder = SourceMapBuilder::new()
  builder.add_mapping(1, 5, "test.ts", 2, 10, None)
  assert_eq(builder.mappings.length(), 1)
  let mapping = builder.mappings[0]
  assert_eq(mapping.name_index, None)
}

///|
/// Test updating position
test "SourceMapBuilder::update_position" {
  let builder = SourceMapBuilder::new()
  builder.update_position(5, 10)
  assert_eq(builder.generated_line, 5)
  assert_eq(builder.generated_column, 10)
}

///|
/// Test new_line advances line and resets column
test "SourceMapBuilder::new_line" {
  let builder = SourceMapBuilder::new()
  builder.update_position(0, 20)
  builder.new_line()
  assert_eq(builder.generated_line, 1)
  assert_eq(builder.generated_column, 0)
}

///|
/// Test advance_column
test "SourceMapBuilder::advance_column" {
  let builder = SourceMapBuilder::new()
  builder.advance_column(5)
  assert_eq(builder.generated_column, 5)
  builder.advance_column(3)
  assert_eq(builder.generated_column, 8)
}

///|
/// Test VLQ encoding of zero
test "encode_vlq encodes zero" {
  let result = encode_vlq(0)
  assert_eq(result, "A") // 0 encodes to 'A'
}

///|
/// Test VLQ encoding of positive numbers
test "encode_vlq encodes positive numbers" {
  // 1 should encode to 'C' (2 in binary, then base64)
  let result = encode_vlq(1)
  assert_eq(result, "C")
}

///|
/// Test VLQ encoding of negative numbers
test "encode_vlq encodes negative numbers" {
  // -1 should encode to 'D' (3 in binary for negative, then base64)
  let result = encode_vlq(-1)
  assert_eq(result, "D")
}

///|
/// Test building source map from builder
test "SourceMapBuilder::build creates source map" {
  let builder = SourceMapBuilder::new()
  builder.add_mapping(0, 0, "test.ts", 0, 0, Some("foo"))
  let sm = builder.build(Some("output.js"))
  assert_eq(sm.version, 3)
  match sm.file {
    Some(f) => assert_eq(f, "output.js")
    None => fail("Expected file to be Some")
  }
  assert_eq(sm.sources.length(), 1)
  assert_eq(sm.names.length(), 1)
  // Mappings should be non-empty after encoding
  assert_true(sm.mappings.length() > 0)
}

///|
/// Test sorting mappings by line and column
test "sort_mappings sorts correctly" {
  let mappings : Array[SourceMapping] = []

  // Add mappings in random order
  let mapping1 = SourceMapping::new(2, 5, 0, 0, 0, None)
  mappings.push(mapping1)
  let mapping2 = SourceMapping::new(0, 10, 0, 0, 0, None)
  mappings.push(mapping2)
  let mapping3 = SourceMapping::new(0, 5, 0, 0, 0, None)
  mappings.push(mapping3)
  let sorted = sort_mappings(mappings)

  // Should be sorted by line first, then column
  assert_eq(sorted[0].generated_line, 0)
  assert_eq(sorted[0].generated_column, 5)
  assert_eq(sorted[1].generated_line, 0)
  assert_eq(sorted[1].generated_column, 10)
  assert_eq(sorted[2].generated_line, 2)
  assert_eq(sorted[2].generated_column, 5)
}

///|
/// Test encoding empty mappings
test "encode_mappings handles empty array" {
  let mappings : Array[SourceMapping] = []
  let result = encode_mappings(mappings)
  assert_eq(result, "")
}

///|
/// Test encoding single mapping
test "encode_mappings encodes single mapping" {
  let mappings : Array[SourceMapping] = []
  let mapping1 = SourceMapping::new(0, 0, 0, 0, 0, None)
  mappings.push(mapping1)
  let result = encode_mappings(mappings)
  // Should produce a non-empty VLQ encoded string
  assert_true(result.length() > 0)
  // First character should be a valid base64 character
  assert_true(result.contains("A"))
}

///|
/// Test generating inline source map comment
test "generate_inline_sourcemap_comment" {
  let sm = SourceMap::new()
  let comment = generate_inline_sourcemap_comment(sm)
  assert_true(comment.contains("//# sourceMappingURL=data:application/json"))
  assert_true(comment.contains("base64"))
}

///|
/// Test generating external source map reference
test "generate_sourcemap_reference" {
  let comment = generate_sourcemap_reference("output.js.map")
  assert_eq(comment, "//# sourceMappingURL=output.js.map")
}

///|
/// Test multiple mappings on same line
test "encode_mappings handles multiple mappings on same line" {
  let mappings : Array[SourceMapping] = []
  let mapping1 = SourceMapping::new(0, 0, 0, 0, 0, None)
  mappings.push(mapping1)
  let mapping2 = SourceMapping::new(0, 5, 0, 5, 0, None)
  mappings.push(mapping2)
  let result = encode_mappings(mappings)
  // Should contain comma separator between mappings on same line
  assert_true(result.contains(","))
}

///|
/// Test mappings on different lines
test "encode_mappings handles different lines" {
  let mappings : Array[SourceMapping] = []
  let mapping1 = SourceMapping::new(0, 0, 0, 0, 0, None)
  mappings.push(mapping1)
  let mapping2 = SourceMapping::new(1, 0, 1, 0, 0, None)
  mappings.push(mapping2)
  let result = encode_mappings(mappings)
  // Should contain semicolon separator between lines
  assert_true(result.contains(";"))
}

///|
/// Test complex scenario with multiple files and names
test "SourceMapBuilder complex scenario" {
  let builder = SourceMapBuilder::new()

  // Add mappings from multiple files
  builder.add_mapping(0, 0, "file1.ts", 0, 0, Some("main"))
  builder.add_mapping(0, 10, "file1.ts", 0, 10, Some("console"))
  builder.add_mapping(1, 0, "file2.ts", 5, 0, Some("helper"))
  assert_eq(builder.sources.length(), 2)
  assert_eq(builder.names.length(), 3)
  assert_eq(builder.mappings.length(), 3)
  let sm = builder.build(Some("bundle.js"))

  // Verify all sources and names are in the map
  assert_true(sm.sources.length() == 2)
  assert_true(sm.names.length() == 3)
  assert_true(sm.mappings.length() > 0)
}

///|
/// Test get_base64_char function
test "get_base64_char returns correct characters" {
  assert_eq(get_base64_char(0), 'A')
  assert_eq(get_base64_char(1), 'B')
  assert_eq(get_base64_char(25), 'Z')
  assert_eq(get_base64_char(26), 'a')
  assert_eq(get_base64_char(51), 'z')
  assert_eq(get_base64_char(52), '0')
  assert_eq(get_base64_char(61), '9')
  assert_eq(get_base64_char(62), '+')
  assert_eq(get_base64_char(63), '/')
}
