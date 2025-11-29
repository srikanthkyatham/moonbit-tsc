// Module System Emitter Tests
// Tests for module output including:
// - ESM to CommonJS conversion in emitter
// - Module kind handling
// - Import/export emission

// ============================================================================
// EmitterContext Module Kind Tests
// ============================================================================

test "emitter/module_kind - default context uses ESModule" {
  let ctx = EmitterContext::default()
  match ctx.module_kind {
    ESModule => assert_true(true)
    _ => fail("Expected ESModule")
  }
}

test "emitter/module_kind - with_options sets ESModule" {
  let ctx = EmitterContext::with_options(ESModule, false)
  match ctx.module_kind {
    ESModule => assert_true(true)
    _ => fail("Expected ESModule")
  }
}

test "emitter/module_kind - with_options sets CommonJS" {
  let ctx = EmitterContext::with_options(CommonJS, false)
  match ctx.module_kind {
    CommonJS => assert_true(true)
    _ => fail("Expected CommonJS")
  }
}

test "emitter/module_kind - indent preserves module kind ESModule" {
  let ctx = EmitterContext::with_options(ESModule, false)
  let indented = ctx.indent()
  match indented.module_kind {
    ESModule => assert_true(true)
    _ => fail("Expected ESModule")
  }
}

test "emitter/module_kind - indent preserves module kind CommonJS" {
  let ctx = EmitterContext::with_options(CommonJS, false)
  let indented = ctx.indent()
  match indented.module_kind {
    CommonJS => assert_true(true)
    _ => fail("Expected CommonJS")
  }
}

// ============================================================================
// Source Map with Module Kind Tests
// ============================================================================

test "emitter/module_sourcemap - with_options_and_source_map preserves module kind CommonJS" {
  let builder = SourceMapBuilder::new()
  let ctx = EmitterContext::with_options_and_source_map(CommonJS, true, builder, "test.ts")
  match ctx.module_kind {
    CommonJS => assert_true(true)
    _ => fail("Expected CommonJS")
  }
  assert_eq(ctx.always_strict, true)
  assert_true(ctx.source_map_builder is Some(_))
}

test "emitter/module_sourcemap - ESModule with source map" {
  let builder = SourceMapBuilder::new()
  let ctx = EmitterContext::with_options_and_source_map(ESModule, false, builder, "input.ts")
  match ctx.module_kind {
    ESModule => assert_true(true)
    _ => fail("Expected ESModule")
  }
  match ctx.source_file {
    Some(file) => assert_eq(file, "input.ts")
    None => fail("Expected source file")
  }
}

// ============================================================================
// EmitterContext Text Emission Tests
// ============================================================================

test "emitter/emit_text - tracks column position" {
  let ctx = EmitterContext::with_options(ESModule, false)
  ctx.emit_text("const x")
  assert_eq(ctx.generated_column, 7)
}

test "emitter/emit_newline - increments line" {
  let ctx = EmitterContext::with_options(ESModule, false)
  ctx.emit_text("line1")
  ctx.emit_newline()
  assert_eq(ctx.generated_line, 1)
  assert_eq(ctx.generated_column, 0)
}

test "emitter/indent - increases indent level" {
  let ctx = EmitterContext::with_options(ESModule, false)
  assert_eq(ctx.indent_level, 0)
  let indented = ctx.indent()
  assert_eq(indented.indent_level, 1)
}

// ============================================================================
// Module Kind with es_module_interop Tests
// ============================================================================

test "emitter/es_module_interop - default is false" {
  let ctx = EmitterContext::default()
  assert_eq(ctx.es_module_interop, false)
}

test "emitter/es_module_interop - preserved after indent" {
  let ctx = EmitterContext::default()
  let indented = ctx.indent()
  assert_eq(indented.es_module_interop, false)
}
