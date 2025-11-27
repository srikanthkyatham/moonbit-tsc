// Compilation Cache - stores compiled outputs to skip recompilation
// Uses content hash to detect changes
// Thread-safe with semaphore-based locking for concurrent access

///|
/// Cache entry for a compiled file
pub(all) struct CacheEntry {
  source_hash : Int64 // Hash of source content
  target : String // Compilation target (es5, es2015, etc.)
  source_map_enabled : Bool
  declaration_enabled : Bool
  javascript : String // Compiled output
  source_map : String? // Optional source map
  declaration : String? // Optional declaration
} derive(Show)

///|
/// Compilation cache - maps file paths to cached entries
/// Uses semaphore for thread-safe concurrent access
pub(all) struct CompilationCache {
  entries : Map[String, CacheEntry]
  mut hits : Int
  mut misses : Int
  lock : @semaphore.Semaphore // Binary semaphore (mutex) for thread safety
}

///|
/// Create a new empty cache with lock
pub fn CompilationCache::new() -> CompilationCache {
  {
    entries: {},
    hits: 0,
    misses: 0,
    lock: @semaphore.Semaphore::new(1), // Binary semaphore acts as mutex
  }
}

///|
/// Compute a simple hash of source content
/// Uses DJB2 hash algorithm for good distribution
pub fn hash_source(source : String) -> Int64 {
  let chars = source.to_array()
  let mut hash : Int64 = 5381L
  for c in chars {
    // hash * 33 + c
    hash = ((hash << 5) + hash) + c.to_int().to_int64()
  }
  hash
}

///|
/// Check if a cache entry is valid for the given parameters
fn is_entry_valid(
  entry : CacheEntry,
  source_hash : Int64,
  target : String,
  source_map : Bool,
  declaration : Bool,
) -> Bool {
  entry.source_hash == source_hash &&
  entry.target == target &&
  entry.source_map_enabled == source_map &&
  entry.declaration_enabled == declaration
}

///|
/// Try to get a cached compilation result (thread-safe)
/// Returns Some(CacheEntry) if found and valid, None otherwise
pub async fn get_cached(
  cache : CompilationCache,
  file_path : String,
  source : String,
  target : String,
  source_map : Bool,
  declaration : Bool,
) -> CacheEntry? {
  cache.lock.acquire()
  let result = get_cached_internal(
    cache,
    file_path,
    source,
    target,
    source_map,
    declaration,
  )
  cache.lock.release()
  result
}

///|
/// Internal get_cached without lock (called while holding lock)
fn get_cached_internal(
  cache : CompilationCache,
  file_path : String,
  source : String,
  target : String,
  source_map : Bool,
  declaration : Bool,
) -> CacheEntry? {
  let source_hash = hash_source(source)
  match cache.entries.get(file_path) {
    Some(entry) =>
      if is_entry_valid(entry, source_hash, target, source_map, declaration) {
        cache.hits = cache.hits + 1
        Some(entry)
      } else {
        cache.misses = cache.misses + 1
        None
      }
    None => {
      cache.misses = cache.misses + 1
      None
    }
  }
}

///|
/// Store a compilation result in the cache (thread-safe)
pub async fn put_cached(
  cache : CompilationCache,
  file_path : String,
  source : String,
  target : String,
  source_map_enabled : Bool,
  declaration_enabled : Bool,
  javascript : String,
  source_map : String?,
  declaration : String?,
) -> Unit {
  cache.lock.acquire()
  put_cached_internal(
    cache,
    file_path,
    source,
    target,
    source_map_enabled,
    declaration_enabled,
    javascript,
    source_map,
    declaration,
  )
  cache.lock.release()
}

///|
/// Internal put_cached without lock (called while holding lock)
fn put_cached_internal(
  cache : CompilationCache,
  file_path : String,
  source : String,
  target : String,
  source_map_enabled : Bool,
  declaration_enabled : Bool,
  javascript : String,
  source_map : String?,
  declaration : String?,
) -> Unit {
  let source_hash = hash_source(source)
  let entry = CacheEntry::{
    source_hash,
    target,
    source_map_enabled,
    declaration_enabled,
    javascript,
    source_map,
    declaration,
  }
  cache.entries[file_path] = entry
}

///|
/// Invalidate cache entry for a file (thread-safe)
pub async fn invalidate(cache : CompilationCache, file_path : String) -> Unit {
  cache.lock.acquire()
  cache.entries.remove(file_path)
  cache.lock.release()
}

///|
/// Invalidate all cache entries (thread-safe)
pub async fn clear(cache : CompilationCache) -> Unit {
  cache.lock.acquire()
  cache.entries.clear()
  cache.hits = 0
  cache.misses = 0
  cache.lock.release()
}

///|
/// Get cache statistics (thread-safe)
pub async fn get_stats(cache : CompilationCache) -> (Int, Int, Int) {
  cache.lock.acquire()
  let result = (cache.entries.length(), cache.hits, cache.misses)
  cache.lock.release()
  result
}

///|
/// Convert cache entry to CompileResponse
pub fn to_response(
  entry : CacheEntry,
  file_path : String,
) -> @protocol.CompileResponse {
  @protocol.CompileResponse::{
    file_path,
    success: true,
    javascript: entry.javascript,
    source_map: entry.source_map,
    declaration: entry.declaration,
    diagnostics: [],
    compile_time_ms: 0, // Cached, no compile time
  }
}
