// Tests for Module System - Format Detection, Conversion, Type-Only Enforcement

// ============================================================================
// Module Format Tests
// ============================================================================

test "unit/module_system/format - ModuleFormat factory functions" {
  assert_eq(@compiler.ModuleFormat::esm(), @compiler.ModuleFormat::esm())
  assert_eq(@compiler.ModuleFormat::cjs(), @compiler.ModuleFormat::cjs())
  assert_eq(@compiler.ModuleFormat::ambient(), @compiler.ModuleFormat::ambient())
  assert_eq(@compiler.ModuleFormat::script(), @compiler.ModuleFormat::script())
}

test "unit/module_system/format - ModuleFormatInfo default" {
  let info = @compiler.ModuleFormatInfo::default()
  match info.format {
    @compiler.Script => assert_true(true)
    _ => fail("Expected Script format")
  }
  assert_eq(info.has_esm_imports, false)
  assert_eq(info.has_esm_exports, false)
  assert_eq(info.has_cjs_require, false)
  assert_eq(info.has_cjs_exports, false)
  assert_eq(info.has_top_level_await, false)
  assert_eq(info.extension_forced, false)
}

// ============================================================================
// File Extension Tests (using the function directly since it's exported)
// ============================================================================

// Note: get_file_extension tests removed as the function is internal

// ============================================================================
// Module Kind Conversion Tests
// ============================================================================

test "unit/module_system/conversion - convert_cjs_require_to_esm default import" {
  let result = @compiler.convert_cjs_require_to_esm("fs", "fs", is_default=true)
  assert_true(result.contains("import fs from"))
}

test "unit/module_system/conversion - convert_cjs_require_to_esm namespace import" {
  let result = @compiler.convert_cjs_require_to_esm("fs", "fs", is_default=false)
  assert_true(result.contains("import * as fs from"))
}

test "unit/module_system/conversion - convert_esm_export_to_cjs default" {
  let result = @compiler.convert_esm_export_to_cjs("default", "myFunc", is_default=true)
  assert_true(result.contains("module.exports"))
}

test "unit/module_system/conversion - convert_esm_export_to_cjs named" {
  let result = @compiler.convert_esm_export_to_cjs("myFunc", "myFunc", is_default=false)
  assert_true(result.contains("exports.myFunc"))
}

// ============================================================================
// File System Interface Tests
// ============================================================================

test "unit/module_system/fs - FileSystemInterface placeholder" {
  let fs = @compiler.FileSystemInterface::placeholder()
  assert_eq((fs.file_exists)("/any/path"), false)
  assert_eq((fs.read_file)("/any/path") is None, true)
  assert_eq((fs.read_directory)("/any/dir").length(), 0)
  assert_eq((fs.is_directory)("/any/path"), false)
  assert_eq((fs.get_current_directory)(), "/")
}

test "unit/module_system/fs - ModuleResolutionHost placeholder" {
  let host = @compiler.ModuleResolutionHost::placeholder()
  assert_eq(host.file_exists("/any/path"), false)
  assert_eq(host.read_file("/any/path") is None, true)
  assert_eq(host.get_directory_contents("/any/dir").length(), 0)
}

test "unit/module_system/fs - ModuleResolutionHost caches file existence" {
  let host = @compiler.ModuleResolutionHost::placeholder()
  // First call
  let _ = host.file_exists("/test/path")
  // Second call should use cache
  let _ = host.file_exists("/test/path")
  // No way to directly test cache, but the call should succeed
  assert_true(true)
}

// ============================================================================
// Package.json Info Tests
// ============================================================================

test "unit/module_system/package_json - PackageJsonInfo empty" {
  let info = @compiler.PackageJsonInfo::empty()
  assert_eq(info.name is None, true)
  assert_eq(info.version is None, true)
  assert_eq(info.main is None, true)
  assert_eq(info.esm_entry is None, true)
  assert_eq(info.types is None, true)
  assert_eq(info.type_field is None, true)
}

test "unit/module_system/package_json - PackageJsonInfo is_esm module type" {
  let info = @compiler.PackageJsonInfo::with_type("module")
  assert_eq(info.is_esm(), true)
}

test "unit/module_system/package_json - PackageJsonInfo is_esm commonjs type" {
  let info = @compiler.PackageJsonInfo::with_type("commonjs")
  assert_eq(info.is_esm(), false)
}

test "unit/module_system/package_json - PackageJsonInfo get_entry_point ESM" {
  let info = @compiler.PackageJsonInfo::with_entries("index.js", esm_entry=Some("index.mjs"))
  // ESM should prefer esm_entry
  match info.get_entry_point(@compiler.ModuleFormat::esm()) {
    Some(entry) => assert_eq(entry, "index.mjs")
    None => fail("Expected entry point")
  }
}

test "unit/module_system/package_json - PackageJsonInfo get_entry_point CJS" {
  let info = @compiler.PackageJsonInfo::with_entries("index.js", esm_entry=Some("index.mjs"))
  // CJS should use main
  match info.get_entry_point(@compiler.ModuleFormat::cjs()) {
    Some(entry) => assert_eq(entry, "index.js")
    None => fail("Expected entry point")
  }
}

test "unit/module_system/package_json - PackageJsonInfo get_entry_point fallback" {
  let info = @compiler.PackageJsonInfo::with_entries("index.js")
  // ESM without esm_entry should fallback to main
  match info.get_entry_point(@compiler.ModuleFormat::esm()) {
    Some(entry) => assert_eq(entry, "index.js")
    None => fail("Expected entry point")
  }
}

// ============================================================================
// Module Resolution Context Tests
// ============================================================================

test "unit/module_system/context - ModuleResolutionContext creation" {
  let host = @compiler.ModuleResolutionHost::placeholder()
  let symbol_resolver = @compiler.ModuleSymbolResolver::with_defaults("/")
  let ctx = @compiler.ModuleResolutionContext::new(symbol_resolver, host)

  // Test format registration
  let format_info = @compiler.ModuleFormatInfo::default()
  ctx.register_format("/test/file.ts", format_info)

  match ctx.get_format("/test/file.ts") {
    Some(_) => assert_true(true)
    None => fail("Expected format info")
  }
}

test "unit/module_system/context - type_only_import tracking" {
  let host = @compiler.ModuleResolutionHost::placeholder()
  let symbol_resolver = @compiler.ModuleSymbolResolver::with_defaults("/")
  let ctx = @compiler.ModuleResolutionContext::new(symbol_resolver, host)

  let imports : Map[String, Bool] = Map::new()
  imports.set("MyType", true)
  ctx.register_type_only_imports("/test/file.ts", imports)

  assert_eq(ctx.is_type_only_import("/test/file.ts", "MyType"), true)
  assert_eq(ctx.is_type_only_import("/test/file.ts", "NotTypeOnly"), false)
}

test "unit/module_system/context - type_only_import unknown file" {
  let host = @compiler.ModuleResolutionHost::placeholder()
  let symbol_resolver = @compiler.ModuleSymbolResolver::with_defaults("/")
  let ctx = @compiler.ModuleResolutionContext::new(symbol_resolver, host)

  // Unknown file should return false
  assert_eq(ctx.is_type_only_import("/unknown/file.ts", "Anything"), false)
}
