// Tests for path resolution

///|
test "is_relative_specifier - detects relative paths" {
  assert_true(is_relative_specifier("./foo"))
  assert_true(is_relative_specifier("../bar"))
  assert_true(is_relative_specifier("./"))
  assert_true(is_relative_specifier("../"))
  assert_false(is_relative_specifier("foo"))
  assert_false(is_relative_specifier("@scope/package"))
  assert_false(is_relative_specifier("/absolute"))
}

///|
test "is_absolute_specifier - detects absolute paths" {
  assert_true(is_absolute_specifier("/foo"))
  assert_true(is_absolute_specifier("/"))
  assert_false(is_absolute_specifier("./foo"))
  assert_false(is_absolute_specifier("foo"))
}

///|
test "is_bare_specifier - detects npm-style imports" {
  assert_true(is_bare_specifier("react"))
  assert_true(is_bare_specifier("@scope/package"))
  assert_true(is_bare_specifier("lodash/map"))
  assert_false(is_bare_specifier("./foo"))
  assert_false(is_bare_specifier("../bar"))
  assert_false(is_bare_specifier("/absolute"))
}

///|
test "normalize_specifier - removes extensions" {
  assert_eq(normalize_specifier("foo.ts"), "foo")
  assert_eq(normalize_specifier("bar.tsx"), "bar")
  assert_eq(normalize_specifier("baz"), "baz")
  assert_eq(normalize_specifier("path/to/file.ts"), "path/to/file")
}

///|
test "try_resolve_extensions - generates extension variants" {
  let variants = try_resolve_extensions("./foo")
  assert_eq(variants.length(), 6)
  assert_eq(variants[0], "./foo.ts")
  assert_eq(variants[1], "./foo.tsx")
  assert_eq(variants[2], "./foo.d.ts")
  assert_eq(variants[3], "./foo/index.ts")
  assert_eq(variants[4], "./foo/index.tsx")
  assert_eq(variants[5], "./foo/index.d.ts")
}

///|
test "resolve_module_path - with baseUrl only" {
  let options : CompilerOptions = {
    ..CompilerOptions::default(),
    base_url: Some("."),
  }
  let result = resolve_module_path(
    "utils/helper", "/project/src/index.ts", options,
  )
  assert_true(result is Some(_))
}

///|
test "resolve_module_path - skips relative imports" {
  let options : CompilerOptions = {
    ..CompilerOptions::default(),
    base_url: Some("."),
  }
  let result = resolve_module_path("./local", "/project/src/index.ts", options)
  assert_true(result is None)
}

///|
test "resolve_module_path - skips absolute imports" {
  let options : CompilerOptions = {
    ..CompilerOptions::default(),
    base_url: Some("."),
  }
  let result = resolve_module_path(
    "/absolute", "/project/src/index.ts", options,
  )
  assert_true(result is None)
}

///|
test "resolve_module_path - with paths mapping" {
  let paths : Map[String, Array[String]] = {}
  paths["@/*"] = ["./src/*"]
  let options : CompilerOptions = {
    ..CompilerOptions::default(),
    base_url: Some("/project"),
    paths: Some(paths),
  }
  let result = resolve_module_path(
    "@/utils/helper", "/project/src/index.ts", options,
  )
  guard result is Some(resolved) else {
    assert_true(false)
    return
  }
  assert_true(resolved.contains("src/utils/helper"))
}

///|
test "resolve_module_path - multiple path patterns" {
  let paths : Map[String, Array[String]] = {}
  paths["@/*"] = ["./src/*"]
  paths["@utils/*"] = ["./src/utils/*"]
  let options : CompilerOptions = {
    ..CompilerOptions::default(),
    base_url: Some("/project"),
    paths: Some(paths),
  }

  // First pattern
  let result1 = resolve_module_path(
    "@/components/Button", "/project/src/index.ts", options,
  )
  assert_true(result1 is Some(_))

  // Second pattern
  let result2 = resolve_module_path(
    "@utils/format", "/project/src/index.ts", options,
  )
  assert_true(result2 is Some(_))
}

///|
test "resolve_module_path - exact match path (no wildcard)" {
  let paths : Map[String, Array[String]] = {}
  paths["config"] = ["./src/config/index"]
  let options : CompilerOptions = {
    ..CompilerOptions::default(),
    base_url: Some("/project"),
    paths: Some(paths),
  }
  let result = resolve_module_path("config", "/project/src/index.ts", options)
  guard result is Some(resolved) else {
    assert_true(false)
    return
  }
  assert_true(resolved.contains("config/index"))
}

///|
test "resolve_module_path - no paths or baseUrl returns None" {
  let options = CompilerOptions::default()
  let result = resolve_module_path("utils", "/project/src/index.ts", options)
  assert_true(result is None)
}

// ============================================================================
// Node.js Module Resolution Tests
// ============================================================================

///|
test "parse_package_name - simple package" {
  let parsed = parse_package_name("lodash")
  assert_eq(parsed.package_name, "lodash")
  assert_eq(parsed.subpath, "")
}

///|
test "parse_package_name - package with subpath" {
  let parsed = parse_package_name("lodash/map")
  assert_eq(parsed.package_name, "lodash")
  assert_eq(parsed.subpath, "/map")
}

///|
test "parse_package_name - package with deep subpath" {
  let parsed = parse_package_name("lodash/fp/map")
  assert_eq(parsed.package_name, "lodash")
  assert_eq(parsed.subpath, "/fp/map")
}

///|
test "parse_package_name - scoped package" {
  let parsed = parse_package_name("@types/node")
  assert_eq(parsed.package_name, "@types/node")
  assert_eq(parsed.subpath, "")
}

///|
test "parse_package_name - scoped package with subpath" {
  let parsed = parse_package_name("@types/node/fs")
  assert_eq(parsed.package_name, "@types/node")
  assert_eq(parsed.subpath, "/fs")
}

///|
test "parse_package_name - scoped package with deep subpath" {
  let parsed = parse_package_name("@angular/core/testing/fakes")
  assert_eq(parsed.package_name, "@angular/core")
  assert_eq(parsed.subpath, "/testing/fakes")
}

///|
test "resolve_from_node_modules - skips relative paths" {
  fn file_exists(_path : String) -> Bool {
    false
  }

  fn read_file(_path : String) -> String? {
    None
  }

  let result = resolve_from_node_modules(
    "./local", "/project/src/index.ts", file_exists, read_file,
  )
  assert_true(result is None)
}

///|
test "resolve_from_node_modules - skips absolute paths" {
  fn file_exists(_path : String) -> Bool {
    false
  }

  fn read_file(_path : String) -> String? {
    None
  }

  let result = resolve_from_node_modules(
    "/absolute/path", "/project/src/index.ts", file_exists, read_file,
  )
  assert_true(result is None)
}

///|
test "resolve_from_node_modules - finds package with index.ts" {
  fn file_exists(path : String) -> Bool {
    path == "/project/node_modules/my-package/index.ts"
  }

  fn read_file(_path : String) -> String? {
    None
  }

  let result = resolve_from_node_modules(
    "my-package", "/project/src/index.ts", file_exists, read_file,
  )
  guard result is Some(resolved) else {
    assert_true(false)
    return
  }
  assert_eq(resolved, "/project/node_modules/my-package/index.ts")
}

///|
test "resolve_from_node_modules - finds package with types field" {
  fn file_exists(path : String) -> Bool {
    path == "/project/node_modules/typed-package/dist/types.d.ts"
  }

  fn read_file(path : String) -> String? {
    if path == "/project/node_modules/typed-package/package.json" {
      Some("{\"name\": \"typed-package\", \"types\": \"dist/types.d.ts\"}")
    } else {
      None
    }
  }

  let result = resolve_from_node_modules(
    "typed-package", "/project/src/index.ts", file_exists, read_file,
  )
  guard result is Some(resolved) else {
    assert_true(false)
    return
  }
  assert_eq(resolved, "/project/node_modules/typed-package/dist/types.d.ts")
}

///|
test "resolve_from_node_modules - finds package with subpath" {
  fn file_exists(path : String) -> Bool {
    path == "/project/node_modules/lodash/map.ts"
  }

  fn read_file(_path : String) -> String? {
    None
  }

  let result = resolve_from_node_modules(
    "lodash/map", "/project/src/index.ts", file_exists, read_file,
  )
  guard result is Some(resolved) else {
    assert_true(false)
    return
  }
  assert_eq(resolved, "/project/node_modules/lodash/map.ts")
}

///|
test "resolve_from_node_modules - finds scoped package" {
  fn file_exists(path : String) -> Bool {
    path == "/project/node_modules/@types/node/index.d.ts"
  }

  fn read_file(_path : String) -> String? {
    None
  }

  let result = resolve_from_node_modules(
    "@types/node", "/project/src/index.ts", file_exists, read_file,
  )
  guard result is Some(resolved) else {
    assert_true(false)
    return
  }
  assert_eq(resolved, "/project/node_modules/@types/node/index.d.ts")
}

///|
test "resolve_from_node_modules - climbs directory tree" {
  // Package is in parent's node_modules, not child's
  fn file_exists(path : String) -> Bool {
    path == "/project/node_modules/shared-lib/index.ts"
  }

  fn read_file(_path : String) -> String? {
    None
  }

  let result = resolve_from_node_modules(
    "shared-lib", "/project/packages/app/src/index.ts", file_exists, read_file,
  )
  guard result is Some(resolved) else {
    assert_true(false)
    return
  }
  assert_eq(resolved, "/project/node_modules/shared-lib/index.ts")
}

///|
test "resolve_from_node_modules - returns None when not found" {
  fn file_exists(_path : String) -> Bool {
    false
  }

  fn read_file(_path : String) -> String? {
    None
  }

  let result = resolve_from_node_modules(
    "non-existent-package", "/project/src/index.ts", file_exists, read_file,
  )
  assert_true(result is None)
}

///|
test "resolve_module_full - node_modules resolution without baseUrl" {
  // Without baseUrl, bare specifiers go to node_modules
  let options = CompilerOptions::default()
  fn file_exists(path : String) -> Bool {
    path == "/project/node_modules/external-lib/index.ts"
  }

  fn read_file(_path : String) -> String? {
    None
  }

  // Should resolve bare specifier via node_modules
  let result = resolve_module_full(
    "external-lib", "/project/src/index.ts", options, file_exists, read_file,
  )
  guard result is Some(resolved) else {
    assert_true(false)
    return
  }
  assert_eq(resolved, "/project/node_modules/external-lib/index.ts")
}

///|
test "resolve_module_full - paths take priority over node_modules" {
  let paths : Map[String, Array[String]] = {}
  paths["my-lib"] = ["./src/local-lib"]
  let options : CompilerOptions = {
    ..CompilerOptions::default(),
    base_url: Some("/project"),
    paths: Some(paths),
  }
  fn file_exists(_path : String) -> Bool {
    true // Both local and node_modules would match
  }

  fn read_file(_path : String) -> String? {
    None
  }

  let result = resolve_module_full(
    "my-lib", "/project/src/index.ts", options, file_exists, read_file,
  )
  guard result is Some(resolved) else {
    assert_true(false)
    return
  }
  // Paths mapping should take priority - should contain local path
  assert_true(resolved.contains("local-lib"))
}

// ============================================================================
// Package.json Exports Field Tests
// ============================================================================

///|
test "resolve_package_exports - simple string export" {
  let package_json = "{\"name\": \"my-pkg\", \"exports\": \"./dist/index.js\"}"
  fn file_exists(path : String) -> Bool {
    path == "/pkg/dist/index.d.ts"
  }

  let result = resolve_package_exports(package_json, "", file_exists, "/pkg")
  guard result is Some(resolved) else {
    assert_true(false)
    return
  }
  assert_eq(resolved, "/pkg/dist/index.d.ts")
}

///|
test "resolve_package_exports - subpath exports" {
  let package_json = "{\"name\": \"my-pkg\", \"exports\": {\".\":\"./dist/index.js\", \"./utils\": \"./dist/utils.js\"}}"
  fn file_exists(path : String) -> Bool {
    path == "/pkg/dist/utils.d.ts"
  }

  let result = resolve_package_exports(
    package_json, "./utils", file_exists, "/pkg",
  )
  guard result is Some(resolved) else {
    assert_true(false)
    return
  }
  assert_eq(resolved, "/pkg/dist/utils.d.ts")
}

///|
test "resolve_package_exports - conditional exports with types" {
  let package_json = "{\"name\": \"my-pkg\", \"exports\": {\".\": {\"types\": \"./types/index.d.ts\", \"import\": \"./dist/index.mjs\"}}}"
  fn file_exists(path : String) -> Bool {
    path == "/pkg/types/index.d.ts" || path == "/pkg/dist/index.mjs"
  }

  let result = resolve_package_exports(package_json, "", file_exists, "/pkg")
  guard result is Some(resolved) else {
    assert_true(false)
    return
  }
  // Should prefer "types" condition
  assert_eq(resolved, "/pkg/types/index.d.ts")
}

///|
test "resolve_package_exports - conditional exports fallback to import" {
  let package_json = "{\"name\": \"my-pkg\", \"exports\": {\".\": {\"types\": \"./types/index.d.ts\", \"import\": \"./dist/index.mjs\"}}}"
  fn file_exists(path : String) -> Bool {
    // types file doesn't exist, only import .d.mts exists
    path == "/pkg/dist/index.d.mts"
  }

  let result = resolve_package_exports(package_json, "", file_exists, "/pkg")
  guard result is Some(resolved) else {
    assert_true(false)
    return
  }
  // Should fallback to import and find .d.mts
  assert_eq(resolved, "/pkg/dist/index.d.mts")
}

///|
test "resolve_package_exports - wildcard pattern" {
  let package_json = "{\"name\": \"my-pkg\", \"exports\": {\"./*\": \"./dist/*.js\"}}"
  fn file_exists(path : String) -> Bool {
    path == "/pkg/dist/utils.d.ts"
  }

  let result = resolve_package_exports(
    package_json, "./utils", file_exists, "/pkg",
  )
  guard result is Some(resolved) else {
    assert_true(false)
    return
  }
  assert_eq(resolved, "/pkg/dist/utils.d.ts")
}

///|
test "resolve_package_exports - wildcard with conditional" {
  let package_json = "{\"name\": \"my-pkg\", \"exports\": {\"./*\": {\"types\": \"./types/*.d.ts\", \"import\": \"./dist/*.mjs\"}}}"
  fn file_exists(path : String) -> Bool {
    path == "/pkg/types/helpers.d.ts"
  }

  let result = resolve_package_exports(
    package_json, "./helpers", file_exists, "/pkg",
  )
  guard result is Some(resolved) else {
    assert_true(false)
    return
  }
  assert_eq(resolved, "/pkg/types/helpers.d.ts")
}

///|
test "resolve_package_exports - null export (private)" {
  let package_json = "{\"name\": \"my-pkg\", \"exports\": {\".\": \"./index.js\", \"./internal\": null}}"
  fn file_exists(path : String) -> Bool {
    path == "/pkg/internal/secret.js"
  }

  let result = resolve_package_exports(
    package_json, "./internal", file_exists, "/pkg",
  )
  // Should return None because ./internal is explicitly null (private)
  assert_true(result is None)
}

///|
test "resolve_package_exports - no exports field returns None" {
  let package_json = "{\"name\": \"my-pkg\", \"main\": \"./index.js\"}"
  fn file_exists(_path : String) -> Bool {
    true
  }

  let result = resolve_package_exports(package_json, "", file_exists, "/pkg")
  // No exports field, should return None
  assert_true(result is None)
}

///|
test "resolve_package_exports - subpath without ./ prefix" {
  let package_json = "{\"name\": \"my-pkg\", \"exports\": {\".\": \"./index.js\", \"./utils\": \"./dist/utils.js\"}}"
  fn file_exists(path : String) -> Bool {
    path == "/pkg/dist/utils.d.ts"
  }

  // Test with subpath that doesn't have "./" prefix
  let result = resolve_package_exports(
    package_json, "/utils", file_exists, "/pkg",
  )
  guard result is Some(resolved) else {
    assert_true(false)
    return
  }
  assert_eq(resolved, "/pkg/dist/utils.d.ts")
}

///|
test "resolve_from_node_modules - uses exports field" {
  fn file_exists(path : String) -> Bool {
    path == "/project/node_modules/modern-pkg/dist/index.d.ts"
  }

  fn read_file(path : String) -> String? {
    if path == "/project/node_modules/modern-pkg/package.json" {
      Some(
        "{\"name\": \"modern-pkg\", \"exports\": {\".\": {\"types\": \"./dist/index.d.ts\", \"import\": \"./dist/index.mjs\"}}}",
      )
    } else {
      None
    }
  }

  let result = resolve_from_node_modules(
    "modern-pkg", "/project/src/index.ts", file_exists, read_file,
  )
  guard result is Some(resolved) else {
    assert_true(false)
    return
  }
  assert_eq(resolved, "/project/node_modules/modern-pkg/dist/index.d.ts")
}

///|
test "resolve_from_node_modules - exports subpath" {
  fn file_exists(path : String) -> Bool {
    path == "/project/node_modules/modern-pkg/dist/utils.d.ts"
  }

  fn read_file(path : String) -> String? {
    if path == "/project/node_modules/modern-pkg/package.json" {
      Some(
        "{\"name\": \"modern-pkg\", \"exports\": {\".\": \"./index.js\", \"./utils\": \"./dist/utils.js\"}}",
      )
    } else {
      None
    }
  }

  let result = resolve_from_node_modules(
    "modern-pkg/utils", "/project/src/index.ts", file_exists, read_file,
  )
  guard result is Some(resolved) else {
    assert_true(false)
    return
  }
  assert_eq(resolved, "/project/node_modules/modern-pkg/dist/utils.d.ts")
}

///|
test "resolve_from_node_modules - exports takes priority over direct file" {
  // When both exports and direct file exist, exports should win
  fn file_exists(path : String) -> Bool {
    path == "/project/node_modules/dual-pkg/lib/index.d.ts" ||
    path == "/project/node_modules/dual-pkg/utils.ts"
  }

  fn read_file(path : String) -> String? {
    if path == "/project/node_modules/dual-pkg/package.json" {
      // exports maps ./utils to lib/index.d.ts, not utils.ts
      Some(
        "{\"name\": \"dual-pkg\", \"exports\": {\"./utils\": \"./lib/index.js\"}}",
      )
    } else {
      None
    }
  }

  let result = resolve_from_node_modules(
    "dual-pkg/utils", "/project/src/index.ts", file_exists, read_file,
  )
  guard result is Some(resolved) else {
    assert_true(false)
    return
  }
  // Should use exports mapping, not direct file
  assert_eq(resolved, "/project/node_modules/dual-pkg/lib/index.d.ts")
}

///|
test "parse_exports_field - handles nested conditionals" {
  let package_json = "{\"exports\": {\".\": {\"types\": \"./types.d.ts\", \"import\": {\"types\": \"./esm/types.d.ts\", \"default\": \"./esm/index.mjs\"}}}}"
  fn file_exists(path : String) -> Bool {
    path == "/pkg/types.d.ts"
  }

  let result = resolve_package_exports(package_json, "", file_exists, "/pkg")
  guard result is Some(resolved) else {
    assert_true(false)
    return
  }
  // Should find top-level types first
  assert_eq(resolved, "/pkg/types.d.ts")
}

// ============================================================================
// Package.json Imports Field Tests (Self-referencing with #)
// ============================================================================

///|
test "is_imports_specifier - detects # imports" {
  assert_true(is_imports_specifier("#internal"))
  assert_true(is_imports_specifier("#utils/helpers"))
  assert_false(is_imports_specifier("lodash"))
  assert_false(is_imports_specifier("./local"))
  assert_false(is_imports_specifier("@scope/pkg"))
}

///|
test "resolve_package_imports - simple import" {
  fn file_exists(path : String) -> Bool {
    path == "/project/src/internal/index.ts"
  }

  fn read_file(path : String) -> String? {
    if path == "/project/package.json" {
      Some(
        "{\"name\": \"my-project\", \"imports\": {\"#internal\": \"./src/internal/index.ts\"}}",
      )
    } else {
      None
    }
  }

  let result = resolve_package_imports(
    "#internal", "/project/src/app/main.ts", file_exists, read_file,
  )
  guard result is Some(resolved) else {
    assert_true(false)
    return
  }
  assert_eq(resolved, "/project/src/internal/index.ts")
}

///|
test "resolve_package_imports - wildcard pattern" {
  fn file_exists(path : String) -> Bool {
    path == "/project/src/utils/format.ts"
  }

  fn read_file(path : String) -> String? {
    if path == "/project/package.json" {
      Some(
        "{\"name\": \"my-project\", \"imports\": {\"#utils/*\": \"./src/utils/*.ts\"}}",
      )
    } else {
      None
    }
  }

  let result = resolve_package_imports(
    "#utils/format", "/project/src/app/main.ts", file_exists, read_file,
  )
  guard result is Some(resolved) else {
    assert_true(false)
    return
  }
  assert_eq(resolved, "/project/src/utils/format.ts")
}

///|
test "resolve_package_imports - conditional import" {
  fn file_exists(path : String) -> Bool {
    path == "/project/src/internal/types.d.ts"
  }

  fn read_file(path : String) -> String? {
    if path == "/project/package.json" {
      Some(
        "{\"name\": \"my-project\", \"imports\": {\"#internal\": {\"types\": \"./src/internal/types.d.ts\", \"default\": \"./src/internal/index.js\"}}}",
      )
    } else {
      None
    }
  }

  let result = resolve_package_imports(
    "#internal", "/project/src/app/main.ts", file_exists, read_file,
  )
  guard result is Some(resolved) else {
    assert_true(false)
    return
  }
  assert_eq(resolved, "/project/src/internal/types.d.ts")
}

///|
test "resolve_package_imports - nested package.json" {
  // Package.json is in a parent directory
  fn file_exists(path : String) -> Bool {
    path == "/project/src/lib/helpers.ts"
  }

  fn read_file(path : String) -> String? {
    if path == "/project/package.json" {
      Some(
        "{\"name\": \"my-project\", \"imports\": {\"#lib/*\": \"./src/lib/*.ts\"}}",
      )
    } else {
      None
    }
  }

  let result = resolve_package_imports(
    "#lib/helpers", "/project/packages/app/src/index.ts", file_exists, read_file,
  )
  guard result is Some(resolved) else {
    assert_true(false)
    return
  }
  assert_eq(resolved, "/project/src/lib/helpers.ts")
}

///|
test "resolve_package_imports - no imports field returns None" {
  fn file_exists(_path : String) -> Bool {
    true
  }

  fn read_file(path : String) -> String? {
    if path == "/project/package.json" {
      Some("{\"name\": \"my-project\"}")
    } else {
      None
    }
  }

  let result = resolve_package_imports(
    "#internal", "/project/src/main.ts", file_exists, read_file,
  )
  assert_true(result is None)
}

///|
test "resolve_package_imports - no package.json returns None" {
  fn file_exists(_path : String) -> Bool {
    true
  }

  fn read_file(_path : String) -> String? {
    None
  }

  let result = resolve_package_imports(
    "#internal", "/project/src/main.ts", file_exists, read_file,
  )
  assert_true(result is None)
}

///|
test "resolve_module_full - imports take priority" {
  let options = CompilerOptions::default()
  fn file_exists(path : String) -> Bool {
    path == "/project/src/internal/index.ts" ||
    path == "/project/node_modules/internal/index.ts"
  }

  fn read_file(path : String) -> String? {
    if path == "/project/package.json" {
      Some(
        "{\"name\": \"my-project\", \"imports\": {\"#internal\": \"./src/internal/index.ts\"}}",
      )
    } else {
      None
    }
  }

  let result = resolve_module_full(
    "#internal", "/project/src/app/main.ts", options, file_exists, read_file,
  )
  guard result is Some(resolved) else {
    assert_true(false)
    return
  }
  // Should use imports, not node_modules
  assert_eq(resolved, "/project/src/internal/index.ts")
}

///|
test "resolve_package_imports - deep wildcard" {
  fn file_exists(path : String) -> Bool {
    path == "/project/src/components/ui/Button.tsx"
  }

  fn read_file(path : String) -> String? {
    if path == "/project/package.json" {
      Some(
        "{\"name\": \"my-project\", \"imports\": {\"#components/*\": \"./src/components/*.tsx\"}}",
      )
    } else {
      None
    }
  }

  let result = resolve_package_imports(
    "#components/ui/Button", "/project/src/app/main.ts", file_exists, read_file,
  )
  guard result is Some(resolved) else {
    assert_true(false)
    return
  }
  assert_eq(resolved, "/project/src/components/ui/Button.tsx")
}
