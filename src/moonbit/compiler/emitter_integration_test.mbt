// Integration tests for end-to-end source map generation

///|
/// Helper to parse source and get tokens for source map tests
fn get_tokens_for_sourcemap(source : String) -> Array[Token] {
  scan_all_v2(source, "test.ts")
}

///|
/// Helper to compile TypeScript to JavaScript with source map support
fn compile_with_sourcemap(source : String) -> (String, SourceMap) {
  let tokens = get_tokens_for_sourcemap(source)
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let transform_ctx = TransformerContext::default()
      let builder = SourceMapBuilder::new()
      let emit_ctx = EmitterContext::with_source_map(builder, "test.ts")

      // Transform and emit each statement
      let mut result = ""
      for i = 0; i < source_file.statements.length(); i = i + 1 {
        let stmt = source_file.statements[i]
        let transformed_stmt = transform(stmt, transform_ctx)
        let emitted = emit(transformed_stmt, emit_ctx)
        result = result + emitted
        emit_ctx.emit_text(emitted)
        if i < source_file.statements.length() - 1 {
          result = result + "\n"
          emit_ctx.emit_newline()
        }
      }

      // Build the source map
      let sourcemap = match emit_ctx.source_map_builder {
        Some(b) => b.build(Some("test.js"))
        None => abort("Expected source_map_builder to exist")
      }
      (result, sourcemap)
    }
    Err(diagnostics) => {
      println("Failed to parse source:")
      for d in diagnostics {
        println("  \{d.message}")
      }
      ("", SourceMap::new())
    }
  }
}

///|
/// Test generating source maps for simple variable declaration
test "generate source map for variable declaration" {
  let source = "const x = 5;"
  let (js_code, sourcemap) = compile_with_sourcemap(source)

  // Verify the JavaScript output
  assert_true(js_code.contains("const"))
  assert_true(js_code.contains("x"))
  assert_true(js_code.contains("5"))

  // Verify source map metadata
  assert_eq(sourcemap.version, 3)
  assert_eq(sourcemap.sources.length(), 1)
  assert_eq(sourcemap.sources[0], "test.ts")

  // Should have encoded mappings
  assert_true(sourcemap.mappings.length() > 0)

  // Should have variable name in names array
  assert_true(sourcemap.names.contains("x"))
}

///|
/// Test generating source maps for function declaration
test "generate source map for function declaration" {
  let source = "function foo() { return 42; }"
  let (js_code, sourcemap) = compile_with_sourcemap(source)

  // Verify the JavaScript output
  assert_true(js_code.contains("function"))
  assert_true(js_code.contains("foo"))

  // Verify source map metadata
  assert_eq(sourcemap.version, 3)
  assert_eq(sourcemap.sources[0], "test.ts")

  // Should have function name in names array
  assert_true(sourcemap.names.contains("foo"))

  // Should have encoded mappings
  assert_true(sourcemap.mappings.length() > 0)
}

///|
/// Test source map position tracking across multiple statements
test "track positions across multiple statements" {
  let source = "const x = 1;\nconst y = 10;"
  let (js_code, sourcemap) = compile_with_sourcemap(source)

  // Verify both statements are present
  assert_true(js_code.contains("x"))
  assert_true(js_code.contains("y"))

  // Verify source map metadata
  assert_eq(sourcemap.version, 3)
  assert_eq(sourcemap.sources.length(), 1)
  assert_eq(sourcemap.sources[0], "test.ts")

  // Should have both variable names
  assert_true(sourcemap.names.contains("x"))
  assert_true(sourcemap.names.contains("y"))

  // Mappings should be encoded and non-empty
  assert_true(sourcemap.mappings.length() > 0)
}

///|
/// Test generating source map with call expressions
test "generate source map with call expressions" {
  let source = "console.log(x);"
  let (js_code, sourcemap) = compile_with_sourcemap(source)

  // Verify the JavaScript output
  assert_true(js_code.contains("console.log"))

  // Verify source map has mappings
  assert_true(sourcemap.mappings.length() > 0)

  // Property access "log" should be in names
  assert_true(sourcemap.names.contains("log"))
}

///|
/// Test generating source map with if statement
test "generate source map with if statement" {
  let source = "if (x > 0) { console.log(x); }"
  let (js_code, sourcemap) = compile_with_sourcemap(source)

  // Verify the JavaScript output
  assert_true(js_code.contains("if"))
  assert_true(js_code.contains("console.log"))

  // Verify source map has mappings
  assert_true(sourcemap.mappings.length() > 0)
}

///|
/// Test generating source map with for loop
test "generate source map with for loop" {
  let source = "for (let i = 0; i < 10; i++) { sum += i; }"
  let (js_code, sourcemap) = compile_with_sourcemap(source)

  // Verify the JavaScript output
  assert_true(js_code.contains("for"))

  // Verify source map has mappings for loop variable
  assert_true(sourcemap.names.contains("i"))

  // Should have multiple mappings
  assert_true(sourcemap.mappings.length() > 0)
}

///|
/// Test JSON serialization of source map
test "serialize source map to JSON" {
  let source = "const greeting = \"hello\";"
  let (_, sourcemap) = compile_with_sourcemap(source)

  // Convert to JSON
  let json = sourcemap.to_json()

  // Verify JSON structure
  assert_true(json.contains("\"version\": 3"))
  assert_true(json.contains("\"sources\": [\"test.ts\"]"))
  assert_true(json.contains("\"names\":"))
  assert_true(json.contains("\"mappings\":"))
}
