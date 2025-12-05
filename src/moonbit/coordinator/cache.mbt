// Compilation Cache - stores compiled outputs to skip recompilation
// Uses content hash to detect changes
// Thread-safe with semaphore-based locking for concurrent access

// ============================================================================
// TsConfig Change Detection - invalidates cache when tsconfig.json changes
// ============================================================================

///|
/// Stores hash of tsconfig.json content for change detection
/// When tsconfig changes, all caches should be invalidated
pub(all) struct TsConfigTracker {
  mut config_hash : Int // Hash of tsconfig content
  mut config_path : String? // Path to tracked tsconfig
  lock : @semaphore.Semaphore
}

///|
/// Create a new tsconfig tracker
pub fn TsConfigTracker::new() -> TsConfigTracker {
  { config_hash: 0, config_path: None, lock: @semaphore.Semaphore::new(1) }
}

///|
/// Compute hash of tsconfig content using MoonBit's built-in Hash trait
/// Returns a stable hash for comparison
pub fn hash_tsconfig(content : String) -> Int {
  content.hash()
}

///|
/// Check if tsconfig has changed since last check
/// Returns true if config changed (cache should be invalidated)
/// Also updates the stored hash if changed
pub async fn TsConfigTracker::check_and_update(
  self : TsConfigTracker,
  config_path : String,
  config_content : String,
) -> Bool {
  self.lock.acquire()
  let new_hash = hash_tsconfig(config_content)
  let changed = match self.config_path {
    Some(existing_path) =>
      // Config changed if path changed OR content hash changed
      existing_path != config_path || self.config_hash != new_hash
    None =>
      // First time tracking - not a change, just initialization
      false
  }

  // Update stored values
  self.config_hash = new_hash
  self.config_path = Some(config_path)
  self.lock.release()
  changed
}

///|
/// Get the current config hash (thread-safe)
pub async fn TsConfigTracker::get_hash(self : TsConfigTracker) -> Int {
  self.lock.acquire()
  let hash = self.config_hash
  self.lock.release()
  hash
}

///|
/// Get the current config path (thread-safe)
pub async fn TsConfigTracker::get_path(self : TsConfigTracker) -> String? {
  self.lock.acquire()
  let path = self.config_path
  self.lock.release()
  path
}

///|
/// Reset the tracker (for testing or when switching projects)
pub async fn TsConfigTracker::reset(self : TsConfigTracker) -> Unit {
  self.lock.acquire()
  self.config_hash = 0
  self.config_path = None
  self.lock.release()
}

// ============================================================================
// Type Cache - stores exported types for cross-file type checking
// ============================================================================

///|
/// Cache for storing exported module types for cross-file type checking
/// This is similar to tsc-phoenix's TypeCache - stores types from compiled
/// files so they can be fed to dependent files during compilation.
pub(all) struct TypeCache {
  entries : Map[String, String] // file_path -> module_types_json
  lock : @semaphore.Semaphore
}

///|
/// Create a new empty type cache
pub fn TypeCache::new() -> TypeCache {
  { entries: {}, lock: @semaphore.Semaphore::new(1) }
}

///|
/// Store exported types for a module (thread-safe)
pub async fn TypeCache::put(
  self : TypeCache,
  file_path : String,
  module_types_json : String,
) -> Unit {
  self.lock.acquire()
  self.entries[file_path] = module_types_json
  self.lock.release()
}

///|
/// Get exported types for a module (thread-safe)
pub async fn TypeCache::get(self : TypeCache, file_path : String) -> String? {
  self.lock.acquire()
  let result = self.entries.get(file_path)
  self.lock.release()
  result
}

///|
/// Check if module types are cached (thread-safe)
pub async fn TypeCache::has(self : TypeCache, file_path : String) -> Bool {
  self.lock.acquire()
  let result = self.entries.contains(file_path)
  self.lock.release()
  result
}

///|
/// Get types for multiple modules at once (thread-safe)
/// Returns a map of file_path -> module_types_json for found entries
pub async fn TypeCache::get_many(
  self : TypeCache,
  file_paths : Array[String],
) -> Map[String, String] {
  self.lock.acquire()
  let result : Map[String, String] = {}
  for path in file_paths {
    match self.entries.get(path) {
      Some(types_json) => result[path] = types_json
      None => ()
    }
  }
  self.lock.release()
  result
}

///|
/// Build external types JSON from cached module types
/// Excludes files in the exclude list (files being compiled in current level)
pub async fn TypeCache::build_external_types_json(
  self : TypeCache,
  exclude : Array[String],
) -> String? {
  self.lock.acquire()

  // Build exclude set
  let exclude_set : Map[String, Bool] = {}
  for path in exclude {
    exclude_set[path] = true
  }

  // Build JSON from cached entries
  let sb = StringBuilder::new()
  sb.write_string("{\"modules\":{")
  let mut first = true
  for path, types_json in self.entries {
    // Skip excluded files
    if exclude_set.contains(path) {
      continue
    }
    if not(first) {
      sb.write_string(",")
    }
    first = false
    sb.write_string("\"")
    sb.write_string(escape_json_string_for_cache(path))
    sb.write_string("\":")
    sb.write_string(types_json)
  }
  sb.write_string("}}")
  self.lock.release()
  let result = sb.to_string()
  // Return None if no modules were added
  if first {
    None
  } else {
    Some(result)
  }
}

///|
/// Clear all cached types (thread-safe)
pub async fn TypeCache::clear(self : TypeCache) -> Unit {
  self.lock.acquire()
  self.entries.clear()
  self.lock.release()
}

///|
/// Get number of cached entries (thread-safe)
pub async fn TypeCache::length(self : TypeCache) -> Int {
  self.lock.acquire()
  let len = self.entries.length()
  self.lock.release()
  len
}

///|
/// Invalidate a specific cache entry (thread-safe)
pub async fn TypeCache::invalidate(
  self : TypeCache,
  file_path : String,
) -> Unit {
  self.lock.acquire()
  self.entries.remove(file_path)
  self.lock.release()
}

///|
/// Helper to escape JSON strings for cache
fn escape_json_string_for_cache(s : String) -> String {
  let sb = StringBuilder::new()
  for c in s {
    match c {
      '"' => sb.write_string("\\\"")
      '\\' => sb.write_string("\\\\")
      '\n' => sb.write_string("\\n")
      '\r' => sb.write_string("\\r")
      '\t' => sb.write_string("\\t")
      _ => sb.write_char(c)
    }
  }
  sb.to_string()
}

// ============================================================================
// Compilation Cache - stores compiled outputs to skip recompilation
// ============================================================================

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
  module_types_json : String? // Optional module types JSON for cross-file type checking
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
  { entries: {}, hits: 0, misses: 0, lock: @semaphore.Semaphore::new(1) } // Binary semaphore acts as mutex
}

///|
/// Compute a simple hash of source content
/// Uses DJB2 hash algorithm for good distribution
pub fn hash_source(source : String) -> Int64 {
  let chars = source.to_array()
  let mut hash : Int64 = 5381L
  for c in chars {
    // hash * 33 + c
    hash = (hash << 5) + hash + c.to_int().to_int64()
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
    cache, file_path, source, target, source_map, declaration,
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
  module_types_json : String?,
) -> Unit {
  cache.lock.acquire()
  put_cached_internal(
    cache, file_path, source, target, source_map_enabled, declaration_enabled, javascript,
    source_map, declaration, module_types_json,
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
  module_types_json : String?,
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
    module_types_json,
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
    module_types_json: entry.module_types_json,
  }
}

// ============================================================================
// Cache Manager - coordinates all caches with tsconfig-aware invalidation
// ============================================================================

///|
/// Unified cache manager that handles all caches and tsconfig change detection
/// When tsconfig.json changes, all caches are automatically invalidated
pub(all) struct CacheManager {
  type_cache : TypeCache
  compilation_cache : CompilationCache
  tsconfig_tracker : TsConfigTracker
  mut invalidation_count : Int // Track number of invalidations for debugging
}

///|
/// Create a new cache manager with all caches initialized
pub fn CacheManager::new() -> CacheManager {
  {
    type_cache: TypeCache::new(),
    compilation_cache: CompilationCache::new(),
    tsconfig_tracker: TsConfigTracker::new(),
    invalidation_count: 0,
  }
}

///|
/// Check if tsconfig has changed and invalidate all caches if needed
/// Call this before each compilation to ensure cache consistency
/// Returns true if caches were invalidated
pub async fn CacheManager::check_tsconfig_and_invalidate(
  self : CacheManager,
  config_path : String,
  config_content : String,
) -> Bool {
  let changed = self.tsconfig_tracker.check_and_update(
    config_path, config_content,
  )
  if changed {
    // Invalidate all caches
    self.type_cache.clear()
    clear(self.compilation_cache)
    self.invalidation_count = self.invalidation_count + 1
  }
  changed
}

///|
/// Get the type cache for storing/retrieving module types
pub fn CacheManager::get_type_cache(self : CacheManager) -> TypeCache {
  self.type_cache
}

///|
/// Get the compilation cache for storing/retrieving compiled outputs
pub fn CacheManager::get_compilation_cache(
  self : CacheManager,
) -> CompilationCache {
  self.compilation_cache
}

///|
/// Get the tsconfig tracker
pub fn CacheManager::get_tsconfig_tracker(
  self : CacheManager,
) -> TsConfigTracker {
  self.tsconfig_tracker
}

///|
/// Get the number of times caches have been invalidated due to tsconfig changes
pub fn CacheManager::get_invalidation_count(self : CacheManager) -> Int {
  self.invalidation_count
}

///|
/// Clear all caches manually (useful for testing or forced refresh)
pub async fn CacheManager::clear_all(self : CacheManager) -> Unit {
  self.type_cache.clear()
  clear(self.compilation_cache)
  self.tsconfig_tracker.reset()
}

///|
/// Get combined statistics from all caches
/// Returns (type_cache_entries, compilation_cache_entries, compilation_hits, compilation_misses, invalidations)
pub async fn CacheManager::get_stats(
  self : CacheManager,
) -> (Int, Int, Int, Int, Int) {
  let type_entries = self.type_cache.length()
  let (comp_entries, hits, misses) = get_stats(self.compilation_cache)
  (type_entries, comp_entries, hits, misses, self.invalidation_count)
}
