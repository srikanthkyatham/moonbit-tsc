// Tests for Compilation Cache

///|
test "hash_source - same content produces same hash" {
  let source1 = "const x = 1;"
  let source2 = "const x = 1;"
  assert_eq(hash_source(source1), hash_source(source2))
}

///|
test "hash_source - different content produces different hash" {
  let source1 = "const x = 1;"
  let source2 = "const x = 2;"
  assert_true(hash_source(source1) != hash_source(source2))
}

///|
test "hash_source - empty string has consistent hash" {
  let hash1 = hash_source("")
  let hash2 = hash_source("")
  assert_eq(hash1, hash2)
}

///|
test "hash_source - whitespace matters" {
  let source1 = "const x=1;"
  let source2 = "const x = 1;"
  assert_true(hash_source(source1) != hash_source(source2))
}

///|
async test "cache - new cache is empty" {
  let cache = CompilationCache::new()
  let (size, hits, misses) = get_stats(cache)
  assert_eq(size, 0)
  assert_eq(hits, 0)
  assert_eq(misses, 0)
}

///|
async test "cache - miss on empty cache" {
  let cache = CompilationCache::new()
  let result = get_cached(
    cache, "/test.ts", "const x = 1;", "es2015", false, false,
  )
  assert_true(result is None)
  let (_, _, misses) = get_stats(cache)
  assert_eq(misses, 1)
}

///|
async test "cache - hit after put" {
  let cache = CompilationCache::new()
  let source = "const x = 1;"
  let file_path = "/test.ts"

  // Put entry
  put_cached(
    cache,
    file_path,
    source,
    "es2015",
    false,
    false,
    "var x = 1;",
    None,
    None,
    None,
  )

  // Get entry
  let result = get_cached(cache, file_path, source, "es2015", false, false)
  assert_true(result is Some(_))
  match result {
    Some(entry) => {
      assert_eq(entry.javascript, "var x = 1;")
      assert_eq(entry.target, "es2015")
    }
    None => assert_true(false)
  }
  let (size, hits, _) = get_stats(cache)
  assert_eq(size, 1)
  assert_eq(hits, 1)
}

///|
async test "cache - miss when source changes" {
  let cache = CompilationCache::new()
  let file_path = "/test.ts"

  // Put with original source
  put_cached(
    cache,
    file_path,
    "const x = 1;",
    "es2015",
    false,
    false,
    "var x = 1;",
    None,
    None,
    None,
  )

  // Get with different source
  let result = get_cached(
    cache, file_path, "const x = 2;", "es2015", false, false,
  )
  assert_true(result is None)
}

///|
async test "cache - miss when target changes" {
  let cache = CompilationCache::new()
  let source = "const x = 1;"
  let file_path = "/test.ts"

  // Put with es2015
  put_cached(
    cache,
    file_path,
    source,
    "es2015",
    false,
    false,
    "const x = 1;",
    None,
    None,
    None,
  )

  // Get with es5
  let result = get_cached(cache, file_path, source, "es5", false, false)
  assert_true(result is None)
}

///|
async test "cache - miss when source_map option changes" {
  let cache = CompilationCache::new()
  let source = "const x = 1;"
  let file_path = "/test.ts"

  // Put without source map
  put_cached(
    cache,
    file_path,
    source,
    "es2015",
    false,
    false,
    "const x = 1;",
    None,
    None,
    None,
  )

  // Get with source map
  let result = get_cached(cache, file_path, source, "es2015", true, false)
  assert_true(result is None)
}

///|
async test "cache - miss when declaration option changes" {
  let cache = CompilationCache::new()
  let source = "const x = 1;"
  let file_path = "/test.ts"

  // Put without declaration
  put_cached(
    cache,
    file_path,
    source,
    "es2015",
    false,
    false,
    "const x = 1;",
    None,
    None,
    None,
  )

  // Get with declaration
  let result = get_cached(cache, file_path, source, "es2015", false, true)
  assert_true(result is None)
}

///|
async test "cache - invalidate removes entry" {
  let cache = CompilationCache::new()
  let source = "const x = 1;"
  let file_path = "/test.ts"

  // Put entry
  put_cached(
    cache,
    file_path,
    source,
    "es2015",
    false,
    false,
    "const x = 1;",
    None,
    None,
    None,
  )

  // Verify it exists
  let result1 = get_cached(cache, file_path, source, "es2015", false, false)
  assert_true(result1 is Some(_))

  // Invalidate
  invalidate(cache, file_path)

  // Verify it's gone
  let result2 = get_cached(cache, file_path, source, "es2015", false, false)
  assert_true(result2 is None)
}

///|
async test "cache - clear removes all entries" {
  let cache = CompilationCache::new()

  // Put multiple entries
  put_cached(
    cache,
    "/a.ts",
    "const a = 1;",
    "es2015",
    false,
    false,
    "const a = 1;",
    None,
    None,
    None,
  )
  put_cached(
    cache,
    "/b.ts",
    "const b = 2;",
    "es2015",
    false,
    false,
    "const b = 2;",
    None,
    None,
    None,
  )
  let (size1, _, _) = get_stats(cache)
  assert_eq(size1, 2)

  // Clear
  clear(cache)
  let (size2, hits, misses) = get_stats(cache)
  assert_eq(size2, 0)
  assert_eq(hits, 0)
  assert_eq(misses, 0)
}

///|
async test "cache - stores source map and declaration" {
  let cache = CompilationCache::new()
  let source = "export const x: number = 1;"
  let file_path = "/test.ts"
  put_cached(
    cache,
    file_path,
    source,
    "es2015",
    true,
    true,
    "export const x = 1;",
    Some("{\"version\":3}"),
    Some("export declare const x: number;"),
    None,
  )
  let result = get_cached(cache, file_path, source, "es2015", true, true)
  match result {
    Some(entry) => {
      assert_eq(entry.javascript, "export const x = 1;")
      assert_eq(entry.source_map, Some("{\"version\":3}"))
      assert_eq(entry.declaration, Some("export declare const x: number;"))
    }
    None => assert_true(false)
  }
}

///|
test "cache - to_response creates valid response" {
  let entry = CacheEntry::{
    source_hash: 12345L,
    target: "es2015",
    source_map_enabled: true,
    declaration_enabled: true,
    javascript: "const x = 1;",
    source_map: Some("{\"version\":3}"),
    declaration: Some("declare const x: number;"),
    module_types_json: None,
  }
  let response = to_response(entry, "/test.ts")
  assert_eq(response.file_path, "/test.ts")
  assert_eq(response.success, true)
  assert_eq(response.javascript, "const x = 1;")
  assert_eq(response.source_map, Some("{\"version\":3}"))
  assert_eq(response.declaration, Some("declare const x: number;"))
  assert_eq(response.compile_time_ms, 0L)
}

///|
async test "cache - multiple files" {
  let cache = CompilationCache::new()
  put_cached(
    cache,
    "/a.ts",
    "const a = 1;",
    "es2015",
    false,
    false,
    "const a = 1;",
    None,
    None,
    None,
  )
  put_cached(
    cache,
    "/b.ts",
    "const b = 2;",
    "es5",
    false,
    false,
    "var b = 2;",
    None,
    None,
    None,
  )
  put_cached(
    cache,
    "/c.ts",
    "const c = 3;",
    "es2015",
    true,
    false,
    "const c = 3;",
    Some("{}"),
    None,
    None,
  )
  let (size, _, _) = get_stats(cache)
  assert_eq(size, 3)

  // Verify each entry
  let a = get_cached(cache, "/a.ts", "const a = 1;", "es2015", false, false)
  let b = get_cached(cache, "/b.ts", "const b = 2;", "es5", false, false)
  let c = get_cached(cache, "/c.ts", "const c = 3;", "es2015", true, false)
  assert_true(a is Some(_))
  assert_true(b is Some(_))
  assert_true(c is Some(_))
}

///|
test "hash_source - long content" {
  let mut source = ""
  for i = 0; i < 1000; i = i + 1 {
    source = source + "const x" + i.to_string() + " = " + i.to_string() + ";\n"
  }
  let hash1 = hash_source(source)
  let hash2 = hash_source(source)
  assert_eq(hash1, hash2)
}

// ============================================================================
// TypeCache Tests
// ============================================================================

///|
async test "type_cache - new cache is empty" {
  let cache = TypeCache::new()
  let len = cache.length()
  assert_eq(len, 0)
}

///|
async test "type_cache - put and get" {
  let cache = TypeCache::new()
  let types_json = "{\"exports\":{\"x\":\"number\"}}"
  cache.put("/a.ts", types_json)
  let result = cache.get("/a.ts")
  assert_eq(result, Some(types_json))
}

///|
async test "type_cache - get returns None for missing" {
  let cache = TypeCache::new()
  let result = cache.get("/missing.ts")
  assert_true(result is None)
}

///|
async test "type_cache - has checks existence" {
  let cache = TypeCache::new()
  cache.put("/a.ts", "{}")
  assert_true(cache.has("/a.ts"))
  assert_true(!(cache.has("/b.ts")))
}

///|
async test "type_cache - get_many returns subset" {
  let cache = TypeCache::new()
  cache.put("/a.ts", "{\"a\":1}")
  cache.put("/b.ts", "{\"b\":2}")
  cache.put("/c.ts", "{\"c\":3}")
  let result = cache.get_many(["/a.ts", "/c.ts", "/missing.ts"])
  assert_eq(result.length(), 2)
  assert_eq(result.get("/a.ts"), Some("{\"a\":1}"))
  assert_eq(result.get("/c.ts"), Some("{\"c\":3}"))
  assert_true(result.get("/missing.ts") is None)
}

///|
async test "type_cache - build_external_types_json" {
  let cache = TypeCache::new()
  cache.put("/a.ts", "{\"exports\":{\"x\":\"number\"}}")
  cache.put("/b.ts", "{\"exports\":{\"y\":\"string\"}}")
  let result = cache.build_external_types_json([])
  assert_true(result is Some(_))
  match result {
    Some(json) => {
      // Should contain both modules
      assert_true(json.contains("/a.ts"))
      assert_true(json.contains("/b.ts"))
      assert_true(json.contains("modules"))
    }
    None => assert_true(false)
  }
}

///|
async test "type_cache - build_external_types_json excludes specified files" {
  let cache = TypeCache::new()
  cache.put("/a.ts", "{\"exports\":{\"x\":\"number\"}}")
  cache.put("/b.ts", "{\"exports\":{\"y\":\"string\"}}")
  cache.put("/c.ts", "{\"exports\":{\"z\":\"boolean\"}}")

  // Exclude /b.ts
  let result = cache.build_external_types_json(["/b.ts"])
  match result {
    Some(json) => {
      assert_true(json.contains("/a.ts"))
      assert_true(!(json.contains("/b.ts")))
      assert_true(json.contains("/c.ts"))
    }
    None => assert_true(false)
  }
}

///|
async test "type_cache - build_external_types_json returns None when empty" {
  let cache = TypeCache::new()
  let result = cache.build_external_types_json([])
  assert_true(result is None)
}

///|
async test "type_cache - build_external_types_json returns None when all excluded" {
  let cache = TypeCache::new()
  cache.put("/a.ts", "{}")
  cache.put("/b.ts", "{}")
  let result = cache.build_external_types_json(["/a.ts", "/b.ts"])
  assert_true(result is None)
}

///|
async test "type_cache - clear removes all entries" {
  let cache = TypeCache::new()
  cache.put("/a.ts", "{}")
  cache.put("/b.ts", "{}")
  assert_eq(cache.length(), 2)
  cache.clear()
  assert_eq(cache.length(), 0)
}

///|
async test "type_cache - invalidate removes specific entry" {
  let cache = TypeCache::new()
  cache.put("/a.ts", "{}")
  cache.put("/b.ts", "{}")
  cache.invalidate("/a.ts")
  assert_true(!(cache.has("/a.ts")))
  assert_true(cache.has("/b.ts"))
}

///|
async test "type_cache - overwrite existing entry" {
  let cache = TypeCache::new()
  cache.put("/a.ts", "{\"v\":1}")
  cache.put("/a.ts", "{\"v\":2}")
  let result = cache.get("/a.ts")
  assert_eq(result, Some("{\"v\":2}"))
  assert_eq(cache.length(), 1)
}

// ============================================================================
// TsConfigTracker Tests
// ============================================================================

///|
test "hash_tsconfig - same content produces same hash" {
  let config1 = "{\"compilerOptions\":{\"target\":\"es2015\"}}"
  let config2 = "{\"compilerOptions\":{\"target\":\"es2015\"}}"
  assert_eq(hash_tsconfig(config1), hash_tsconfig(config2))
}

///|
test "hash_tsconfig - different content produces different hash" {
  let config1 = "{\"compilerOptions\":{\"target\":\"es2015\"}}"
  let config2 = "{\"compilerOptions\":{\"target\":\"es5\"}}"
  assert_true(hash_tsconfig(config1) != hash_tsconfig(config2))
}

///|
test "hash_tsconfig - whitespace matters" {
  let config1 = "{\"target\":\"es2015\"}"
  let config2 = "{ \"target\": \"es2015\" }"
  assert_true(hash_tsconfig(config1) != hash_tsconfig(config2))
}

///|
async test "tsconfig_tracker - new tracker has no config" {
  let tracker = TsConfigTracker::new()
  let path = tracker.get_path()
  assert_true(path is None)
}

///|
async test "tsconfig_tracker - first check does not report change" {
  let tracker = TsConfigTracker::new()
  let config = "{\"compilerOptions\":{\"target\":\"es2015\"}}"

  // First check should not report change (initialization)
  let changed = tracker.check_and_update("/project/tsconfig.json", config)
  assert_eq(changed, false)

  // But hash should be stored
  let hash = tracker.get_hash()
  assert_eq(hash, hash_tsconfig(config))
}

///|
async test "tsconfig_tracker - same content does not report change" {
  let tracker = TsConfigTracker::new()
  let config = "{\"compilerOptions\":{\"target\":\"es2015\"}}"

  // Initialize
  let _ = tracker.check_and_update("/project/tsconfig.json", config)

  // Same content should not report change
  let changed = tracker.check_and_update("/project/tsconfig.json", config)
  assert_eq(changed, false)
}

///|
async test "tsconfig_tracker - different content reports change" {
  let tracker = TsConfigTracker::new()
  let config1 = "{\"compilerOptions\":{\"target\":\"es2015\"}}"
  let config2 = "{\"compilerOptions\":{\"target\":\"es5\"}}"

  // Initialize
  let _ = tracker.check_and_update("/project/tsconfig.json", config1)

  // Different content should report change
  let changed = tracker.check_and_update("/project/tsconfig.json", config2)
  assert_eq(changed, true)
}

///|
async test "tsconfig_tracker - different path reports change" {
  let tracker = TsConfigTracker::new()
  let config = "{\"compilerOptions\":{\"target\":\"es2015\"}}"

  // Initialize with first path
  let _ = tracker.check_and_update("/project1/tsconfig.json", config)

  // Different path should report change (even with same content)
  let changed = tracker.check_and_update("/project2/tsconfig.json", config)
  assert_eq(changed, true)
}

///|
async test "tsconfig_tracker - reset clears state" {
  let tracker = TsConfigTracker::new()
  let config = "{\"compilerOptions\":{\"target\":\"es2015\"}}"

  // Initialize
  let _ = tracker.check_and_update("/project/tsconfig.json", config)

  // Reset
  tracker.reset()

  // After reset, should have no path
  let path = tracker.get_path()
  assert_true(path is None)

  // And hash should be 0
  let hash = tracker.get_hash()
  assert_eq(hash, 0)
}

///|
async test "tsconfig_tracker - hash updates after change" {
  let tracker = TsConfigTracker::new()
  let config1 = "{\"target\":\"es2015\"}"
  let config2 = "{\"target\":\"es5\"}"

  // Initialize
  let _ = tracker.check_and_update("/tsconfig.json", config1)
  let hash1 = tracker.get_hash()

  // Change content
  let _ = tracker.check_and_update("/tsconfig.json", config2)
  let hash2 = tracker.get_hash()

  // Hashes should be different
  assert_true(hash1 != hash2)
  assert_eq(hash2, hash_tsconfig(config2))
}

// ============================================================================
// CacheManager Tests
// ============================================================================

///|
async test "cache_manager - new manager has empty caches" {
  let manager = CacheManager::new()
  let (type_entries, comp_entries, hits, misses, invalidations) = manager.get_stats()
  assert_eq(type_entries, 0)
  assert_eq(comp_entries, 0)
  assert_eq(hits, 0)
  assert_eq(misses, 0)
  assert_eq(invalidations, 0)
}

///|
async test "cache_manager - check_tsconfig_and_invalidate on first call" {
  let manager = CacheManager::new()
  let config = "{\"compilerOptions\":{\"target\":\"es2015\"}}"

  // First call should not invalidate (initialization)
  let invalidated = manager.check_tsconfig_and_invalidate(
    "/tsconfig.json", config,
  )
  assert_eq(invalidated, false)
  assert_eq(manager.get_invalidation_count(), 0)
}

///|
async test "cache_manager - check_tsconfig_and_invalidate clears caches on change" {
  let manager = CacheManager::new()
  let config1 = "{\"target\":\"es2015\"}"
  let config2 = "{\"target\":\"es5\"}"

  // Initialize
  let _ = manager.check_tsconfig_and_invalidate("/tsconfig.json", config1)

  // Add some data to caches
  manager.get_type_cache().put("/a.ts", "{}")
  put_cached(
    manager.get_compilation_cache(),
    "/b.ts",
    "const x = 1;",
    "es2015",
    false,
    false,
    "const x = 1;",
    None,
    None,
    None,
  )

  // Verify data is there
  let (type_entries1, comp_entries1, _, _, _) = manager.get_stats()
  assert_eq(type_entries1, 1)
  assert_eq(comp_entries1, 1)

  // Change tsconfig - should invalidate
  let invalidated = manager.check_tsconfig_and_invalidate(
    "/tsconfig.json", config2,
  )
  assert_eq(invalidated, true)
  assert_eq(manager.get_invalidation_count(), 1)

  // Caches should be empty
  let (type_entries2, comp_entries2, _, _, _) = manager.get_stats()
  assert_eq(type_entries2, 0)
  assert_eq(comp_entries2, 0)
}

///|
async test "cache_manager - no invalidation when config unchanged" {
  let manager = CacheManager::new()
  let config = "{\"target\":\"es2015\"}"

  // Initialize
  let _ = manager.check_tsconfig_and_invalidate("/tsconfig.json", config)

  // Add data
  manager.get_type_cache().put("/a.ts", "{}")

  // Same config - should not invalidate
  let invalidated = manager.check_tsconfig_and_invalidate(
    "/tsconfig.json", config,
  )
  assert_eq(invalidated, false)

  // Data should still be there
  let (type_entries, _, _, _, _) = manager.get_stats()
  assert_eq(type_entries, 1)
}

///|
async test "cache_manager - clear_all resets everything" {
  let manager = CacheManager::new()

  // Initialize and add data
  let _ = manager.check_tsconfig_and_invalidate("/tsconfig.json", "{}")
  manager.get_type_cache().put("/a.ts", "{}")
  put_cached(
    manager.get_compilation_cache(),
    "/b.ts",
    "x",
    "es2015",
    false,
    false,
    "x",
    None,
    None,
    None,
  )

  // Clear all
  manager.clear_all()

  // Everything should be reset
  let (type_entries, comp_entries, _, _, _) = manager.get_stats()
  assert_eq(type_entries, 0)
  assert_eq(comp_entries, 0)

  // Tsconfig tracker should also be reset
  let path = manager.get_tsconfig_tracker().get_path()
  assert_true(path is None)
}

///|
async test "cache_manager - multiple invalidations tracked" {
  let manager = CacheManager::new()

  // Initialize
  let _ = manager.check_tsconfig_and_invalidate("/tsconfig.json", "{\"v\":1}")

  // Make several changes
  let _ = manager.check_tsconfig_and_invalidate("/tsconfig.json", "{\"v\":2}")
  let _ = manager.check_tsconfig_and_invalidate("/tsconfig.json", "{\"v\":3}")
  let _ = manager.check_tsconfig_and_invalidate("/tsconfig.json", "{\"v\":4}")

  // Should have 3 invalidations (first call doesn't count)
  assert_eq(manager.get_invalidation_count(), 3)
}

///|
async test "cache_manager - path change triggers invalidation" {
  let manager = CacheManager::new()
  let config = "{\"target\":\"es2015\"}"

  // Initialize with first path
  let _ = manager.check_tsconfig_and_invalidate(
    "/project1/tsconfig.json", config,
  )
  manager.get_type_cache().put("/a.ts", "{}")

  // Different path (switching projects) should invalidate
  let invalidated = manager.check_tsconfig_and_invalidate(
    "/project2/tsconfig.json", config,
  )
  assert_eq(invalidated, true)

  // Cache should be cleared
  let (type_entries, _, _, _, _) = manager.get_stats()
  assert_eq(type_entries, 0)
}
