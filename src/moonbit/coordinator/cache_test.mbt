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
  assert_true(not(cache.has("/b.ts")))
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
      assert_true(not(json.contains("/b.ts")))
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

  assert_true(not(cache.has("/a.ts")))
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
