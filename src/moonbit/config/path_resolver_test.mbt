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
