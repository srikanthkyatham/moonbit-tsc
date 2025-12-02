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
