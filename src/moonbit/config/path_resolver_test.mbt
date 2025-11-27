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
  let result = resolve_module_path("utils/helper", "/project/src/index.ts", options)
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
  let result = resolve_module_path("/absolute", "/project/src/index.ts", options)
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
  let result = resolve_module_path("@/utils/helper", "/project/src/index.ts", options)
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
  let result1 = resolve_module_path("@/components/Button", "/project/src/index.ts", options)
  assert_true(result1 is Some(_))

  // Second pattern
  let result2 = resolve_module_path("@utils/format", "/project/src/index.ts", options)
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
    "./local",
    "/project/src/index.ts",
    file_exists,
    read_file,
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
    "/absolute/path",
    "/project/src/index.ts",
    file_exists,
    read_file,
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
    "my-package",
    "/project/src/index.ts",
    file_exists,
    read_file,
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
    "typed-package",
    "/project/src/index.ts",
    file_exists,
    read_file,
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
    "lodash/map",
    "/project/src/index.ts",
    file_exists,
    read_file,
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
    "@types/node",
    "/project/src/index.ts",
    file_exists,
    read_file,
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
    "shared-lib",
    "/project/packages/app/src/index.ts",
    file_exists,
    read_file,
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
    "non-existent-package",
    "/project/src/index.ts",
    file_exists,
    read_file,
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
    "external-lib",
    "/project/src/index.ts",
    options,
    file_exists,
    read_file,
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
    "my-lib",
    "/project/src/index.ts",
    options,
    file_exists,
    read_file,
  )
  guard result is Some(resolved) else {
    assert_true(false)
    return
  }
  // Paths mapping should take priority - should contain local path
  assert_true(resolved.contains("local-lib"))
}
