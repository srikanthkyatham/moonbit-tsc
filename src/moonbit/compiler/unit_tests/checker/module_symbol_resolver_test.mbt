// Module Symbol Resolver Unit Tests
// Tests for cross-file symbol linking and import/export resolution

// ============================================================================
// ExportedSymbol Tests
// ============================================================================

///|
test "unit/module-symbol-resolver/exported-symbol - create basic export" {
  let export_symbol = @compiler.ExportedSymbol::new("foo", "foo", 1)
  assert_eq(export_symbol.exported_name, "foo")
  assert_eq(export_symbol.symbol_id, 1)
  assert_eq(export_symbol.is_type_only, false)
}

///|
test "unit/module-symbol-resolver/exported-symbol - renamed export" {
  let export_symbol = @compiler.ExportedSymbol::new("myFoo", "foo", 2)
  assert_eq(export_symbol.exported_name, "myFoo")
  assert_eq(export_symbol.original_name, "foo")
}

///|
test "unit/module-symbol-resolver/exported-symbol - type-only export" {
  let export_symbol = @compiler.ExportedSymbol::new(
    "MyType",
    "MyType",
    3,
    is_type_only=true,
  )
  assert_eq(export_symbol.is_type_only, true)
}

///|
test "unit/module-symbol-resolver/exported-symbol - re-export" {
  let export_symbol = @compiler.ExportedSymbol::new(
    "utils",
    "utils",
    4,
    re_exported_from=Some("./utils"),
  )
  match export_symbol.re_exported_from {
    Some(path) => assert_eq(path, "./utils")
    None => assert_true(false)
  }
}

// ============================================================================
// ModuleExports Tests
// ============================================================================

///|
test "unit/module-symbol-resolver/module-exports - create empty" {
  let exports = @compiler.ModuleExports::empty("/project/src/index.ts")
  assert_eq(exports.module_path, "/project/src/index.ts")
  assert_eq(exports.get_export_names().length(), 0)
}

///|
test "unit/module-symbol-resolver/module-exports - add and get export" {
  let exports = @compiler.ModuleExports::empty("/project/src/utils.ts")
  let export_symbol = @compiler.ExportedSymbol::new("formatDate", "formatDate", 10)
  exports.add_export("formatDate", export_symbol)

  match exports.get_export("formatDate") {
    Some(exp) => assert_eq(exp.symbol_id, 10)
    None => assert_true(false)
  }
}

///|
test "unit/module-symbol-resolver/module-exports - has export" {
  let exports = @compiler.ModuleExports::empty("/project/src/helpers.ts")
  let export_symbol = @compiler.ExportedSymbol::new("helper", "helper", 20)
  exports.add_export("helper", export_symbol)

  assert_true(exports.has_export("helper"))
  assert_eq(exports.has_export("nonexistent"), false)
}

///|
test "unit/module-symbol-resolver/module-exports - get export names" {
  let exports = @compiler.ModuleExports::empty("/project/src/api.ts")

  let exp1 = @compiler.ExportedSymbol::new("fetchData", "fetchData", 30)
  let exp2 = @compiler.ExportedSymbol::new("postData", "postData", 31)

  exports.add_export("fetchData", exp1)
  exports.add_export("postData", exp2)

  let names = exports.get_export_names()
  assert_eq(names.length(), 2)
  assert_true(names.contains("fetchData"))
  assert_true(names.contains("postData"))
}

///|
test "unit/module-symbol-resolver/module-exports - default export" {
  let default_exp = @compiler.ExportedSymbol::new("default", "MyComponent", 100)
  let exports = @compiler.ModuleExports::with_default(
    "/project/src/component.ts",
    default_exp,
  )

  match exports.default_export {
    Some(def) => {
      assert_eq(def.original_name, "MyComponent")
      assert_eq(def.symbol_id, 100)
    }
    None => assert_true(false)
  }
}

// ============================================================================
// ImportBinding Tests
// ============================================================================

///|
test "unit/module-symbol-resolver/import-binding - named import" {
  let binding = @compiler.ImportBinding::new(
    "foo",
    50,
    "/project/src/utils.ts",
    "foo",
    @compiler.ImportBindingKind::named_import(),
  )
  assert_eq(binding.local_name, "foo")
  assert_eq(binding.kind, @compiler.ImportBindingKind::named_import())
}

///|
test "unit/module-symbol-resolver/import-binding - renamed import" {
  let binding = @compiler.ImportBinding::new(
    "myUtil",
    51,
    "/project/src/utils.ts",
    "util",
    @compiler.ImportBindingKind::named_import(),
  )
  assert_eq(binding.local_name, "myUtil")
  assert_eq(binding.imported_name, "util")
}

///|
test "unit/module-symbol-resolver/import-binding - default import" {
  let binding = @compiler.ImportBinding::new(
    "React",
    52,
    "react",
    "default",
    @compiler.ImportBindingKind::default_import(),
  )
  assert_eq(binding.kind, @compiler.ImportBindingKind::default_import())
  assert_eq(binding.local_name, "React")
}

///|
test "unit/module-symbol-resolver/import-binding - namespace import" {
  let binding = @compiler.ImportBinding::new(
    "utils",
    53,
    "./utils",
    "*",
    @compiler.ImportBindingKind::namespace_import(),
  )
  assert_eq(binding.kind, @compiler.ImportBindingKind::namespace_import())
  assert_eq(binding.imported_name, "*")
}

///|
test "unit/module-symbol-resolver/import-binding - type-only import" {
  let binding = @compiler.ImportBinding::new(
    "MyType",
    54,
    "./types",
    "MyType",
    @compiler.ImportBindingKind::named_import(),
    is_type_only=true,
  )
  assert_eq(binding.is_type_only, true)
}

// ============================================================================
// ModuleSymbolResolver Tests
// ============================================================================

///|
test "unit/module-symbol-resolver/resolver - create with defaults" {
  let resolver = @compiler.ModuleSymbolResolver::with_defaults("/project")
  // Should have no cached exports initially
  match resolver.get_exports("/some/module.ts") {
    Some(_) => assert_true(false)
    None => assert_true(true)
  }
}

///|
test "unit/module-symbol-resolver/resolver - register and get exports" {
  let module_resolver = @compiler.ModuleResolver::with_defaults("/project")
  let resolver = @compiler.ModuleSymbolResolver::new(module_resolver)

  let exports = @compiler.ModuleExports::empty("/project/src/utils.ts")
  let exp = @compiler.ExportedSymbol::new("helper", "helper", 100)
  exports.add_export("helper", exp)

  resolver.register_exports("/project/src/utils.ts", exports)

  match resolver.get_exports("/project/src/utils.ts") {
    Some(cached) => assert_true(cached.has_export("helper"))
    None => assert_true(false)
  }
}

///|
test "unit/module-symbol-resolver/resolver - add and get import bindings" {
  let module_resolver = @compiler.ModuleResolver::with_defaults("/project")
  let resolver = @compiler.ModuleSymbolResolver::new(module_resolver)

  let binding = @compiler.ImportBinding::new(
    "foo",
    1,
    "./utils",
    "foo",
    @compiler.ImportBindingKind::named_import(),
  )

  resolver.add_import_binding("/project/src/index.ts", binding)

  let bindings = resolver.get_import_bindings("/project/src/index.ts")
  assert_eq(bindings.length(), 1)
  assert_eq(bindings[0].local_name, "foo")
}

///|
test "unit/module-symbol-resolver/resolver - get bindings for unknown file" {
  let module_resolver = @compiler.ModuleResolver::with_defaults("/project")
  let resolver = @compiler.ModuleSymbolResolver::new(module_resolver)

  let bindings = resolver.get_import_bindings("/unknown/file.ts")
  assert_eq(bindings.length(), 0)
}

// ============================================================================
// Circular Dependency Detection Tests
// ============================================================================

///|
test "unit/module-symbol-resolver/circular - would be circular detection" {
  let module_resolver = @compiler.ModuleResolver::with_defaults("/project")
  let resolver = @compiler.ModuleSymbolResolver::new(module_resolver)

  // Initially not circular
  assert_eq(resolver.would_be_circular("/project/a.ts"), false)

  // Start processing
  resolver.start_processing("/project/a.ts")
  resolver.start_processing("/project/b.ts")

  // Now a.ts would be circular
  assert_true(resolver.would_be_circular("/project/a.ts"))
  assert_true(resolver.would_be_circular("/project/b.ts"))
  assert_eq(resolver.would_be_circular("/project/c.ts"), false)
}

///|
test "unit/module-symbol-resolver/circular - finish processing removes from stack" {
  let module_resolver = @compiler.ModuleResolver::with_defaults("/project")
  let resolver = @compiler.ModuleSymbolResolver::new(module_resolver)

  resolver.start_processing("/project/a.ts")
  resolver.start_processing("/project/b.ts")

  assert_true(resolver.would_be_circular("/project/a.ts"))

  resolver.finish_processing("/project/a.ts")

  assert_eq(resolver.would_be_circular("/project/a.ts"), false)
  assert_true(resolver.would_be_circular("/project/b.ts"))
}

///|
test "unit/module-symbol-resolver/circular - get dependency chain" {
  let module_resolver = @compiler.ModuleResolver::with_defaults("/project")
  let resolver = @compiler.ModuleSymbolResolver::new(module_resolver)

  resolver.start_processing("/project/a.ts")
  resolver.start_processing("/project/b.ts")
  resolver.start_processing("/project/c.ts")

  let chain = resolver.get_dependency_chain()
  assert_eq(chain.length(), 3)
  assert_eq(chain[0], "/project/a.ts")
  assert_eq(chain[1], "/project/b.ts")
  assert_eq(chain[2], "/project/c.ts")
}

// ============================================================================
// Import Linking Tests
// ============================================================================

///|
test "unit/module-symbol-resolver/link - link named import success" {
  let module_resolver = @compiler.ModuleResolver::with_defaults("/project")
  let resolver = @compiler.ModuleSymbolResolver::new(module_resolver)

  // Setup exports
  let exports = @compiler.ModuleExports::empty("/project/src/utils.ts")
  let exp = @compiler.ExportedSymbol::new("helper", "helper", 42)
  exports.add_export("helper", exp)
  resolver.register_exports("/project/src/utils.ts", exports)

  // Setup import binding
  let binding = @compiler.ImportBinding::new(
    "helper",
    1,
    "/project/src/utils.ts",
    "helper",
    @compiler.ImportBindingKind::named_import(),
  )
  resolver.add_import_binding("/project/src/index.ts", binding)

  // Link imports
  let diagnostics = resolver.link_imports("/project/src/index.ts")
  assert_eq(diagnostics.length(), 0)

  // Check that binding was resolved
  let bindings = resolver.get_import_bindings("/project/src/index.ts")
  match bindings[0].resolved_symbol_id {
    Some(id) => assert_eq(id, 42)
    None => assert_true(false)
  }
}

///|
test "unit/module-symbol-resolver/link - link named import not found" {
  let module_resolver = @compiler.ModuleResolver::with_defaults("/project")
  let resolver = @compiler.ModuleSymbolResolver::new(module_resolver)

  // Setup exports (without the imported symbol)
  let exports = @compiler.ModuleExports::empty("/project/src/utils.ts")
  resolver.register_exports("/project/src/utils.ts", exports)

  // Setup import binding for non-existent export
  let binding = @compiler.ImportBinding::new(
    "nonexistent",
    1,
    "/project/src/utils.ts",
    "nonexistent",
    @compiler.ImportBindingKind::named_import(),
  )
  resolver.add_import_binding("/project/src/index.ts", binding)

  // Link imports - should produce diagnostic
  let diagnostics = resolver.link_imports("/project/src/index.ts")
  assert_eq(diagnostics.length(), 1)
  assert_eq(diagnostics[0].code, 2305) // TS2305
  assert_true(diagnostics[0].message.contains("nonexistent"))
}

///|
test "unit/module-symbol-resolver/link - link default import success" {
  let module_resolver = @compiler.ModuleResolver::with_defaults("/project")
  let resolver = @compiler.ModuleSymbolResolver::new(module_resolver)

  // Setup exports with default
  let default_exp = @compiler.ExportedSymbol::new("default", "MyComponent", 99)
  let exports = @compiler.ModuleExports::with_default(
    "/project/src/component.ts",
    default_exp,
  )
  resolver.register_exports("/project/src/component.ts", exports)

  // Setup default import binding
  let binding = @compiler.ImportBinding::new(
    "MyComponent",
    1,
    "/project/src/component.ts",
    "default",
    @compiler.ImportBindingKind::default_import(),
  )
  resolver.add_import_binding("/project/src/app.ts", binding)

  // Link imports
  let diagnostics = resolver.link_imports("/project/src/app.ts")
  assert_eq(diagnostics.length(), 0)

  // Check resolution
  let bindings = resolver.get_import_bindings("/project/src/app.ts")
  match bindings[0].resolved_symbol_id {
    Some(id) => assert_eq(id, 99)
    None => assert_true(false)
  }
}

///|
test "unit/module-symbol-resolver/link - link default import not found" {
  let module_resolver = @compiler.ModuleResolver::with_defaults("/project")
  let resolver = @compiler.ModuleSymbolResolver::new(module_resolver)

  // Setup exports WITHOUT default
  let exports = @compiler.ModuleExports::empty("/project/src/utils.ts")
  resolver.register_exports("/project/src/utils.ts", exports)

  // Setup default import binding
  let binding = @compiler.ImportBinding::new(
    "Utils",
    1,
    "/project/src/utils.ts",
    "default",
    @compiler.ImportBindingKind::default_import(),
  )
  resolver.add_import_binding("/project/src/app.ts", binding)

  // Link imports - should produce diagnostic
  let diagnostics = resolver.link_imports("/project/src/app.ts")
  assert_eq(diagnostics.length(), 1)
  assert_eq(diagnostics[0].code, 1192) // TS1192
  assert_true(diagnostics[0].message.contains("no default export"))
}

///|
test "unit/module-symbol-resolver/link - link namespace import" {
  let module_resolver = @compiler.ModuleResolver::with_defaults("/project")
  let resolver = @compiler.ModuleSymbolResolver::new(module_resolver)

  // Setup exports
  let exports = @compiler.ModuleExports::empty("/project/src/utils.ts")
  let exp = @compiler.ExportedSymbol::new("helper", "helper", 10)
  exports.add_export("helper", exp)
  resolver.register_exports("/project/src/utils.ts", exports)

  // Setup namespace import binding
  let binding = @compiler.ImportBinding::new(
    "utils",
    1,
    "/project/src/utils.ts",
    "*",
    @compiler.ImportBindingKind::namespace_import(),
  )
  resolver.add_import_binding("/project/src/app.ts", binding)

  // Link imports
  let diagnostics = resolver.link_imports("/project/src/app.ts")
  assert_eq(diagnostics.length(), 0)

  // Namespace import should have special marker
  let bindings = resolver.get_import_bindings("/project/src/app.ts")
  match bindings[0].resolved_symbol_id {
    Some(id) => assert_eq(id, -2) // Namespace marker
    None => assert_true(false)
  }
}

// ============================================================================
// Module Resolution Integration Tests
// ============================================================================

///|
test "unit/module-symbol-resolver/resolve - resolve import path" {
  let module_resolver = @compiler.ModuleResolver::with_defaults("/project")
  let resolver = @compiler.ModuleSymbolResolver::new(module_resolver)

  // Test relative path resolution (will fail since file doesn't exist)
  let result = resolver.resolve_import("./utils", "/project/src/index.ts")
  match result {
    Ok(_) => assert_true(false) // Should fail since file doesn't exist
    Err(@compiler.ModuleNotFound(specifier, _)) => assert_eq(specifier, "./utils")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Re-export Resolution Tests
// ============================================================================

///|
test "unit/module-symbol-resolver/reexport - resolve all exports basic" {
  let module_resolver = @compiler.ModuleResolver::with_defaults("/project")
  let resolver = @compiler.ModuleSymbolResolver::new(module_resolver)

  // Setup exports
  let exports = @compiler.ModuleExports::empty("/project/src/utils.ts")
  let exp1 = @compiler.ExportedSymbol::new("foo", "foo", 1)
  let exp2 = @compiler.ExportedSymbol::new("bar", "bar", 2)
  exports.add_export("foo", exp1)
  exports.add_export("bar", exp2)
  resolver.register_exports("/project/src/utils.ts", exports)

  // Get all exports
  let all_exports = resolver.resolve_all_exports("/project/src/utils.ts")
  assert_eq(all_exports.length(), 2)
  match all_exports.get("foo") {
    Some(exp) => assert_eq(exp.symbol_id, 1)
    None => assert_true(false)
  }
  match all_exports.get("bar") {
    Some(exp) => assert_eq(exp.symbol_id, 2)
    None => assert_true(false)
  }
}

///|
test "unit/module-symbol-resolver/reexport - resolve all exports empty" {
  let module_resolver = @compiler.ModuleResolver::with_defaults("/project")
  let resolver = @compiler.ModuleSymbolResolver::new(module_resolver)

  // Module not registered
  let all_exports = resolver.resolve_all_exports("/project/src/unknown.ts")
  assert_eq(all_exports.length(), 0)
}
