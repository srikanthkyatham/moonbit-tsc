// Integration tests for emitter with source map support

/// Test creating emitter context with source map support
test "EmitterContext::with_source_map creates context with builder" {
  let builder = SourceMapBuilder::new()
  let ctx = EmitterContext::with_source_map(builder, "test.ts")

  // Verify source file is set
  match ctx.source_file {
    Some(file) => assert_eq(file, "test.ts")
    None => fail("Expected source_file to be Some")
  }

  // Verify source map builder is set
  match ctx.source_map_builder {
    Some(_) => ()  // Success
    None => fail("Expected source_map_builder to be Some")
  }

  // Verify initial position
  assert_eq(ctx.generated_line, 0)
  assert_eq(ctx.generated_column, 0)
}

/// Test default emitter context has no source map
test "EmitterContext::default creates context without source map" {
  let ctx = EmitterContext::default()

  // Verify no source map builder
  match ctx.source_map_builder {
    Some(_) => fail("Expected source_map_builder to be None")
    None => ()  // Success
  }

  // Verify no source file
  match ctx.source_file {
    Some(_) => fail("Expected source_file to be None")
    None => ()  // Success
  }

  assert_eq(ctx.generated_line, 0)
  assert_eq(ctx.generated_column, 0)
}

/// Test position tracking with emit_text
test "EmitterContext::emit_text updates column position" {
  let ctx = EmitterContext::default()

  ctx.emit_text("const x = 5")
  assert_eq(ctx.generated_column, 11)

  ctx.emit_text(";")
  assert_eq(ctx.generated_column, 12)
}

/// Test position tracking with emit_newline
test "EmitterContext::emit_newline updates line and resets column" {
  let ctx = EmitterContext::default()

  ctx.emit_text("const x = 5;")
  assert_eq(ctx.generated_line, 0)
  assert_eq(ctx.generated_column, 12)

  ctx.emit_newline()
  assert_eq(ctx.generated_line, 1)
  assert_eq(ctx.generated_column, 0)

  ctx.emit_text("const y = 10;")
  assert_eq(ctx.generated_line, 1)
  assert_eq(ctx.generated_column, 13)
}

/// Test add_mapping with source map builder
test "EmitterContext::add_mapping adds mapping when builder exists" {
  let builder = SourceMapBuilder::new()
  let ctx = EmitterContext::with_source_map(builder, "input.ts")

  // Add a mapping at current position (0,0) -> original (0,0)
  ctx.add_mapping(0, 0, Some("x"))

  // Verify mapping was added to builder
  match ctx.source_map_builder {
    Some(b) => {
      assert_eq(b.mappings.length(), 1)
      let mapping = b.mappings[0]
      assert_eq(mapping.generated_line, 0)
      assert_eq(mapping.generated_column, 0)
      assert_eq(mapping.original_line, 0)
      assert_eq(mapping.original_column, 0)
    }
    None => fail("Expected source_map_builder to exist")
  }
}

/// Test add_mapping without source map builder does nothing
test "EmitterContext::add_mapping does nothing without builder" {
  let ctx = EmitterContext::default()

  // Should not crash - just do nothing
  ctx.add_mapping(0, 0, None)

  // Verify no builder was created
  match ctx.source_map_builder {
    Some(_) => fail("Expected source_map_builder to remain None")
    None => ()  // Success
  }
}

/// Test emitting simple code with position tracking
test "emit simple code with position tracking" {
  let builder = SourceMapBuilder::new()
  let ctx = EmitterContext::with_source_map(builder, "test.ts")

  // Simulate emitting: const x = 5;
  ctx.add_mapping(0, 0, Some("x"))  // Map const keyword
  ctx.emit_text("const ")  // 6 chars
  ctx.emit_text("x")        // 1 char
  ctx.emit_text(" = ")      // 3 chars
  ctx.emit_text("5")        // 1 char
  ctx.emit_text(";")        // 1 char
  // Total: 6 + 1 + 3 + 1 + 1 = 12 chars

  // Verify position after emission
  assert_eq(ctx.generated_line, 0)
  assert_eq(ctx.generated_column, 12)

  // Verify mapping was recorded
  match ctx.source_map_builder {
    Some(b) => {
      assert_eq(b.mappings.length(), 1)
    }
    None => fail("Expected source_map_builder to exist")
  }
}

/// Test building final source map from emitter context
test "build source map from emitter context" {
  let builder = SourceMapBuilder::new()
  let ctx = EmitterContext::with_source_map(builder, "input.ts")

  // Add some mappings
  ctx.add_mapping(0, 0, Some("foo"))
  ctx.emit_text("function foo")
  ctx.emit_text("() ")

  ctx.emit_text("{ ")
  ctx.add_mapping(1, 2, None)  // Map function body
  ctx.emit_text("return 42")
  ctx.emit_text("; ")
  ctx.emit_text("}")

  // Build the final source map
  match ctx.source_map_builder {
    Some(b) => {
      let sourcemap = b.build(Some("output.js"))

      assert_eq(sourcemap.version, 3)
      assert_eq(sourcemap.sources.length(), 1)
      assert_eq(sourcemap.sources[0], "input.ts")
      assert_eq(sourcemap.names.length(), 1)
      assert_eq(sourcemap.names[0], "foo")
      assert_true(sourcemap.mappings.length() > 0)
    }
    None => fail("Expected source_map_builder to exist")
  }
}

/// Test indent preserves source map context
test "EmitterContext::indent preserves source map builder" {
  let builder = SourceMapBuilder::new()
  let ctx = EmitterContext::with_source_map(builder, "test.ts")

  let indented_ctx = ctx.indent()

  assert_eq(indented_ctx.indent_level, 1)

  // Verify source map builder is preserved
  match indented_ctx.source_map_builder {
    Some(_) => ()  // Success
    None => fail("Expected source_map_builder to be preserved after indent")
  }

  match indented_ctx.source_file {
    Some(file) => assert_eq(file, "test.ts")
    None => fail("Expected source_file to be preserved after indent")
  }
}
