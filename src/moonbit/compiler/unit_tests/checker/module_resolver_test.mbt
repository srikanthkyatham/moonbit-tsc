// Module Resolver Unit Tests
// Tests for TypeScript-compatible module resolution algorithm

// ============================================================================
// Path Classification Tests
// ============================================================================

///|
test "unit/module-resolver/classify - relative path ./" {
  let kind = @compiler.classify_module_specifier("./utils")
  let str = kind.to_string()
  assert_eq(str, "Relative")
}

///|
test "unit/module-resolver/classify - relative path ../" {
  let kind = @compiler.classify_module_specifier("../utils")
  let str = kind.to_string()
  assert_eq(str, "Relative")
}

///|
test "unit/module-resolver/classify - absolute path /" {
  let kind = @compiler.classify_module_specifier("/usr/lib/node_modules/lodash")
  let str = kind.to_string()
  assert_eq(str, "Absolute")
}

///|
test "unit/module-resolver/classify - package reference" {
  let kind = @compiler.classify_module_specifier("lodash")
  let str = kind.to_string()
  assert_eq(str, "Package")
}

///|
test "unit/module-resolver/classify - scoped package reference" {
  let kind = @compiler.classify_module_specifier("@types/node")
  let str = kind.to_string()
  assert_eq(str, "Package")
}

///|
test "unit/module-resolver/classify - URL import https" {
  let kind = @compiler.classify_module_specifier("https://example.com/mod.ts")
  let str = kind.to_string()
  assert_eq(str, "URL")
}

///|
test "unit/module-resolver/classify - URL import http" {
  let kind = @compiler.classify_module_specifier("http://example.com/mod.ts")
  let str = kind.to_string()
  assert_eq(str, "URL")
}

///|
test "unit/module-resolver/classify - dot only" {
  let kind = @compiler.classify_module_specifier(".")
  let str = kind.to_string()
  assert_eq(str, "Relative")
}

///|
test "unit/module-resolver/classify - double dot only" {
  let kind = @compiler.classify_module_specifier("..")
  let str = kind.to_string()
  assert_eq(str, "Relative")
}

// ============================================================================
// Module Resolver Creation Tests
// ============================================================================

///|
test "unit/module-resolver/create - resolver with defaults" {
  let resolver = @compiler.ModuleResolver::with_defaults("/project")
  assert_eq(resolver.current_directory, "/project")
}

// ============================================================================
// Module Resolution Tests (algorithm verification)
// ============================================================================

///|
test "unit/module-resolver/resolve - relative module produces ModuleNotFound" {
  let resolver = @compiler.ModuleResolver::with_defaults("/project")
  let result = resolver.resolve_module_name("./utils", "/project/src/index.ts")

  // Since file_exists returns false, we expect ModuleNotFound
  match result {
    Err(@compiler.ModuleNotFound(specifier, _searched)) =>
      assert_eq(specifier, "./utils")
    Ok(_) => assert_true(false)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/module-resolver/resolve - node_modules package searches correctly" {
  let resolver = @compiler.ModuleResolver::with_defaults("/project/src")
  let result = resolver.resolve_module_name("lodash", "/project/src/index.ts")
  match result {
    Err(@compiler.ModuleNotFound(specifier, searched)) => {
      assert_eq(specifier, "lodash")
      // Should have searched in node_modules directories
      let has_node_modules = searched
        .iter()
        .any(fn(s) { s.contains("node_modules") })
      assert_true(has_node_modules)
    }
    Ok(_) => assert_true(false)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/module-resolver/resolve - scoped package @types/node" {
  let resolver = @compiler.ModuleResolver::with_defaults("/project")
  let result = resolver.resolve_module_name(
    "@types/node", "/project/src/index.ts",
  )
  match result {
    Err(@compiler.ModuleNotFound(specifier, searched)) => {
      assert_eq(specifier, "@types/node")
      // Should have searched for scoped package correctly
      let has_types = searched.iter().any(fn(s) { s.contains("@types/node") })
      assert_true(has_types)
    }
    Ok(_) => assert_true(false)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/module-resolver/resolve - scoped package with subpath @angular/core/testing" {
  let resolver = @compiler.ModuleResolver::with_defaults("/project")
  let result = resolver.resolve_module_name(
    "@angular/core/testing", "/project/src/app.ts",
  )
  match result {
    Err(@compiler.ModuleNotFound(specifier, searched)) => {
      assert_eq(specifier, "@angular/core/testing")
      // Should have searched for package with subpath
      let has_angular = searched
        .iter()
        .any(fn(s) { s.contains("@angular/core") })
      assert_true(has_angular)
    }
    Ok(_) => assert_true(false)
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Extension Resolution Tests
// ============================================================================

///|
test "unit/module-resolver/extensions - tries all configured extensions" {
  let resolver = @compiler.ModuleResolver::with_defaults("/project")
  let result = resolver.resolve_module_name("./utils", "/project/src/index.ts")
  match result {
    Err(@compiler.ModuleNotFound(_, searched)) => {
      let has_ts = searched.iter().any(fn(s) { s.has_suffix(".ts") })
      let has_tsx = searched.iter().any(fn(s) { s.has_suffix(".tsx") })
      let has_dts = searched.iter().any(fn(s) { s.has_suffix(".d.ts") })
      assert_true(has_ts)
      assert_true(has_tsx)
      assert_true(has_dts)
    }
    Ok(_) => assert_true(false)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/module-resolver/extensions - tries index files in directories" {
  let resolver = @compiler.ModuleResolver::with_defaults("/project")
  let result = resolver.resolve_module_name(
    "./components", "/project/src/index.ts",
  )
  match result {
    Err(@compiler.ModuleNotFound(_, searched)) => {
      // Should have tried index files
      let has_index = searched.iter().any(fn(s) { s.contains("/index.") })
      assert_true(has_index)
    }
    Ok(_) => assert_true(false)
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Diagnostic Creation Tests
// ============================================================================

///|
test "unit/module-resolver/diagnostic - module not found diagnostic" {
  let diagnostic = @compiler.create_module_not_found_diagnostic(
    "./missing",
    "/project/src/index.ts",
    ["/project/src/missing.ts", "/project/src/missing.tsx"],
  )
  assert_eq(diagnostic.code, 2307)
  assert_true(diagnostic.message.contains("./missing"))
  assert_eq(diagnostic.location.file_path, "/project/src/index.ts")
}

///|
test "unit/module-resolver/diagnostic - circular dependency diagnostic" {
  let diagnostic = @compiler.create_circular_dependency_diagnostic(
    ["a.ts", "b.ts", "c.ts", "a.ts"],
    "/project/a.ts",
  )
  assert_true(diagnostic.message.contains("Circular dependency"))
  assert_true(diagnostic.message.contains("->"))
}

// ============================================================================
// Resolution Caching Tests
// ============================================================================

///|
test "unit/module-resolver/cache - caches failed lookups" {
  let resolver = @compiler.ModuleResolver::with_defaults("/project")

  // First resolution attempt
  let _result1 = resolver.resolve_module_name(
    "./missing", "/project/src/index.ts",
  )

  // Check that failed lookups cache has an entry
  let cache_key = "/project/src/index.ts|./missing"
  let cached_failure = resolver.failed_lookups.get(cache_key)
  match cached_failure {
    Some(_) => assert_true(true)
    None => assert_true(false)
  }
}

// ============================================================================
// Module Resolution Options Tests
// ============================================================================

///|
test "unit/module-resolver/options - default options have correct values" {
  let options = @compiler.ModuleResolutionOptions::default()
  assert_eq(options.extensions.length(), 5)
  assert_eq(options.resolve_json_module, false)
  assert_eq(options.type_roots.length(), 1)
}

///|
test "unit/module-resolver/options - extensions include TypeScript and JavaScript" {
  let options = @compiler.ModuleResolutionOptions::default()
  assert_true(options.extensions.contains(".ts"))
  assert_true(options.extensions.contains(".tsx"))
  assert_true(options.extensions.contains(".d.ts"))
  assert_true(options.extensions.contains(".js"))
  assert_true(options.extensions.contains(".jsx"))
}

// ============================================================================
// Path Normalization Tests
// ============================================================================

///|
test "unit/module-resolver/normalize - resolves .. in paths" {
  let resolver = @compiler.ModuleResolver::with_defaults("/project")
  // Test with path containing . and ..
  let result = resolver.resolve_module_name(
    "./foo/../bar", "/project/src/index.ts",
  )
  match result {
    Err(@compiler.ModuleNotFound(_, searched)) => {
      // The normalized path should have resolved the ..
      let has_bar = searched.iter().any(fn(s) { s.contains("/src/bar") })
      assert_true(has_bar)
    }
    Ok(_) => assert_true(false)
    Err(_) => assert_true(false)
  }
}

///|
test "unit/module-resolver/normalize - handles deep relative paths" {
  let resolver = @compiler.ModuleResolver::with_defaults("/project")
  let result = resolver.resolve_module_name(
    "../../shared/utils", "/project/src/features/auth/login.ts",
  )
  match result {
    Err(@compiler.ModuleNotFound(_, searched)) => {
      // Should resolve to /project/src/shared/utils
      let has_shared = searched
        .iter()
        .any(fn(s) { s.contains("/src/shared/utils") })
      assert_true(has_shared)
    }
    Ok(_) => assert_true(false)
    Err(_) => assert_true(false)
  }
}
