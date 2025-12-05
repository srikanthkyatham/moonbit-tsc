// Module Resolution - TypeScript-compatible Module Resolution Algorithm
// Implements Phase 4 of the TypeScript compiler feature gap:
// 1. File-based module resolution (relative imports)
// 2. Node.js module resolution algorithm
// 3. Path mapping (paths, baseUrl)
// 4. Re-export resolution
// 5. Cross-file symbol linking

// ============================================================================
// Module Resolution Strategy
// ============================================================================

///|
/// Module resolution strategy
pub enum ModuleResolutionKind {
  /// TypeScript's classic resolution (deprecated but still used)
  Classic
  /// Node.js resolution (node_modules lookup)
  Node
  /// Node.js ESM resolution (Node16/NodeNext)
  NodeNext
  /// Bundler-style resolution (no extensions required)
  Bundler
} derive(Show, Eq)

///|
/// Module resolution options
pub struct ModuleResolutionOptions {
  /// Resolution strategy
  strategy : ModuleResolutionKind
  /// Base URL for non-relative module names
  base_url : String?
  /// Path mapping patterns
  paths : Map[String, Array[String]]
  /// Root directories for resolving modules
  root_dirs : Array[String]
  /// Additional extensions to try
  extensions : Array[String]
  /// Whether to resolve JSON modules
  resolve_json_module : Bool
  /// Type roots for @types packages
  type_roots : Array[String]
} derive(Show)

///|
/// Default module resolution options
pub fn ModuleResolutionOptions::default() -> ModuleResolutionOptions {
  {
    strategy: Node,
    base_url: None,
    paths: Map::new(),
    root_dirs: [],
    extensions: [".ts", ".tsx", ".d.ts", ".js", ".jsx"],
    resolve_json_module: false,
    type_roots: ["node_modules/@types"],
  }
}

// ============================================================================
// Resolution Result
// ============================================================================

///|
/// Result of module resolution
pub struct ResolvedModule {
  /// Resolved file path (absolute)
  resolved_file_name : String
  /// Original module specifier
  original_path : String
  /// Whether this is an external library module (from node_modules)
  mut is_external_library_import : Bool
  /// Package ID if resolved from a package
  mut package_id : PackageId?
  /// Extension of the resolved file
  extension : String
} derive(Show)

///|
/// Package identifier
pub struct PackageId {
  name : String
  sub_module_name : String?
  version : String?
} derive(Show)

///|
/// Resolution failure reasons
pub enum ResolutionFailure {
  /// Module not found at any searched location
  ModuleNotFound(String, Array[String]) // specifier, searched_locations
  /// Relative import outside root directory
  OutsideRootDir(String)
  /// Invalid module specifier
  InvalidSpecifier(String)
  /// Circular dependency detected
  CircularDependency(Array[String]) // dependency chain
  /// Package.json exports don't match
  PackageExportsNotFound(String, String) // package, subpath
} derive(Show)

// ============================================================================
// Module Resolver
// ============================================================================

///|
/// Module resolver handles resolving import specifiers to file paths
pub struct ModuleResolver {
  /// Resolution options
  options : ModuleResolutionOptions
  /// Cache of resolved modules
  resolution_cache : Map[String, ResolvedModule]
  /// Failed resolution cache
  failed_lookups : Map[String, ResolutionFailure]
  /// Current directory context
  current_directory : String
} derive(Show)

///|
/// Create a new module resolver
pub fn ModuleResolver::new(
  options : ModuleResolutionOptions,
  current_directory : String,
) -> ModuleResolver {
  {
    options,
    resolution_cache: Map::new(),
    failed_lookups: Map::new(),
    current_directory,
  }
}

///|
/// Create with default options
pub fn ModuleResolver::with_defaults(
  current_directory : String,
) -> ModuleResolver {
  ModuleResolver::new(ModuleResolutionOptions::default(), current_directory)
}

// ============================================================================
// Main Resolution Entry Point
// ============================================================================

///|
/// Resolve a module specifier from a containing file
pub fn ModuleResolver::resolve_module_name(
  self : ModuleResolver,
  module_name : String,
  containing_file : String,
) -> Result[ResolvedModule, ResolutionFailure] {
  // Create cache key
  let cache_key = containing_file + "|" + module_name

  // Check cache first
  match self.resolution_cache.get(cache_key) {
    Some(resolved) => return Ok(resolved)
    None => ()
  }

  // Check failed lookups cache
  match self.failed_lookups.get(cache_key) {
    Some(failure) => return Err(failure)
    None => ()
  }

  // Determine resolution strategy
  let result = if is_relative_path(module_name) {
    resolve_relative_module(self, module_name, containing_file)
  } else if is_rooted_path(module_name) {
    resolve_rooted_module(self, module_name)
  } else {
    // Non-relative module name - could be:
    // 1. Path-mapped module
    // 2. node_modules package
    // 3. Ambient module
    resolve_non_relative_module(self, module_name, containing_file)
  }

  // Cache the result
  match result {
    Ok(resolved) => {
      self.resolution_cache.set(cache_key, resolved)
      Ok(resolved)
    }
    Err(failure) => {
      self.failed_lookups.set(cache_key, failure)
      Err(failure)
    }
  }
}

// ============================================================================
// Path Classification
// ============================================================================

///|
/// Check if path is relative (starts with ./ or ../)
fn is_relative_path(path : String) -> Bool {
  path.has_prefix("./") || path.has_prefix("../") || path == "." || path == ".."
}

///|
/// Check if path is rooted (absolute path)
fn is_rooted_path(path : String) -> Bool {
  // Unix absolute path
  if path.has_prefix("/") {
    return true
  }
  // Windows absolute path (e.g., C:/)
  if path.length() >= 3 {
    let chars : Array[Char] = path.to_array()
    if chars.length() >= 3 && chars[1] == ':' && chars[2] == '/' {
      return true
    }
  }
  false
}

///|
/// Find last index of char in string
fn string_last_index_of(s : String, ch : Char) -> Int? {
  let chars : Array[Char] = s.to_array()
  for i = chars.length() - 1; i >= 0; i = i - 1 {
    if chars[i] == ch {
      return Some(i)
    }
  }
  None
}

///|
/// Find first index of char in string
fn string_index_of(s : String, ch : Char) -> Int? {
  let chars : Array[Char] = s.to_array()
  for i = 0; i < chars.length(); i = i + 1 {
    if chars[i] == ch {
      return Some(i)
    }
  }
  None
}

///|
/// String substring helper
fn string_substring(s : String, start : Int, end? : Int = -1) -> String {
  let chars : Array[Char] = s.to_array()
  let actual_end = if end < 0 { chars.length() } else { end }
  let result : Array[Char] = []
  for i = start; i < actual_end && i < chars.length(); i = i + 1 {
    result.push(chars[i])
  }
  String::from_array(result)
}

///|
/// Get directory name from file path
fn get_directory_path(file_path : String) -> String {
  match string_last_index_of(file_path, '/') {
    Some(idx) => string_substring(file_path, 0, end=idx)
    None => "."
  }
}

///|
/// Join path components
fn join_paths(base : String, relative : String) -> String {
  if base.is_empty() || base == "." {
    return relative
  }
  if relative.is_empty() {
    return base
  }
  let base_clean = if base.has_suffix("/") {
    string_substring(base, 0, end=base.length() - 1)
  } else {
    base
  }
  base_clean + "/" + relative
}

///|
/// Normalize path (resolve . and ..)
fn normalize_path(path : String) -> String {
  let parts = path.split("/")
  let result : Array[String] = []
  for part in parts {
    let part_str = part.to_string()
    if part_str == "." || part_str.is_empty() {
      continue
    } else if part_str == ".." {
      if result.length() > 0 && result[result.length() - 1] != ".." {
        let _ = result.pop()

      } else {
        result.push(part_str)
      }
    } else {
      result.push(part_str)
    }
  }
  let normalized = result.join("/")
  if path.has_prefix("/") {
    "/" + normalized
  } else {
    normalized
  }
}

///|
/// Get file extension
fn get_extension(path : String) -> String {
  match string_last_index_of(path, '.') {
    Some(idx) =>
      // Make sure it's after the last /
      match string_last_index_of(path, '/') {
        Some(slash_idx) if slash_idx > idx => ""
        _ => string_substring(path, idx)
      }
    None => ""
  }
}

// ============================================================================
// Relative Module Resolution
// ============================================================================

///|
/// Resolve a relative module specifier
fn resolve_relative_module(
  resolver : ModuleResolver,
  module_name : String,
  containing_file : String,
) -> Result[ResolvedModule, ResolutionFailure] {
  let containing_dir = get_directory_path(containing_file)
  let candidate = normalize_path(join_paths(containing_dir, module_name))

  // Try to resolve with various extensions
  let searched : Array[String] = []

  // First, try the exact path if it has an extension
  let ext = get_extension(module_name)
  if not(ext.is_empty()) {
    searched.push(candidate)
    if file_exists(candidate) {
      return Ok(create_resolved_module(candidate, module_name, false, ext))
    }
  }

  // Try each extension
  for extension in resolver.options.extensions {
    let with_ext = candidate + extension
    searched.push(with_ext)
    if file_exists(with_ext) {
      return Ok(create_resolved_module(with_ext, module_name, false, extension))
    }
  }

  // Try as directory with index file
  for extension in resolver.options.extensions {
    let index_path = join_paths(candidate, "index" + extension)
    searched.push(index_path)
    if file_exists(index_path) {
      return Ok(
        create_resolved_module(index_path, module_name, false, extension),
      )
    }
  }
  Err(ModuleNotFound(module_name, searched))
}

///|
/// Resolve a rooted (absolute) module path
fn resolve_rooted_module(
  resolver : ModuleResolver,
  module_name : String,
) -> Result[ResolvedModule, ResolutionFailure] {
  let searched : Array[String] = []

  // Try exact path
  let ext = get_extension(module_name)
  if not(ext.is_empty()) {
    searched.push(module_name)
    if file_exists(module_name) {
      return Ok(create_resolved_module(module_name, module_name, false, ext))
    }
  }

  // Try with extensions
  for extension in resolver.options.extensions {
    let with_ext = module_name + extension
    searched.push(with_ext)
    if file_exists(with_ext) {
      return Ok(create_resolved_module(with_ext, module_name, false, extension))
    }
  }

  // Try as directory
  for extension in resolver.options.extensions {
    let index_path = join_paths(module_name, "index" + extension)
    searched.push(index_path)
    if file_exists(index_path) {
      return Ok(
        create_resolved_module(index_path, module_name, false, extension),
      )
    }
  }
  Err(ModuleNotFound(module_name, searched))
}

// ============================================================================
// Non-Relative Module Resolution
// ============================================================================

///|
/// Resolve a non-relative module (package or path-mapped)
fn resolve_non_relative_module(
  resolver : ModuleResolver,
  module_name : String,
  containing_file : String,
) -> Result[ResolvedModule, ResolutionFailure] {
  let searched : Array[String] = []

  // 1. Try path mapping first
  match try_resolve_with_paths(resolver, module_name, containing_file) {
    Ok(resolved) => return Ok(resolved)
    Err(ModuleNotFound(_, locs)) => searched.append(locs)
    Err(other) => return Err(other)
  }

  // 2. Try baseUrl resolution
  match try_resolve_with_base_url(resolver, module_name) {
    Ok(resolved) => return Ok(resolved)
    Err(ModuleNotFound(_, locs)) => searched.append(locs)
    Err(other) => return Err(other)
  }

  // 3. Try node_modules resolution
  match resolver.options.strategy {
    Node | NodeNext =>
      match
        try_resolve_from_node_modules(resolver, module_name, containing_file) {
        Ok(resolved) => return Ok(resolved)
        Err(ModuleNotFound(_, locs)) => searched.append(locs)
        Err(other) => return Err(other)
      }
    Classic =>
      // Classic resolution walks up directory tree
      match try_resolve_classic(resolver, module_name, containing_file) {
        Ok(resolved) => return Ok(resolved)
        Err(ModuleNotFound(_, locs)) => searched.append(locs)
        Err(other) => return Err(other)
      }
    Bundler =>
      // Bundler mode - similar to Node but more lenient
      match
        try_resolve_from_node_modules(resolver, module_name, containing_file) {
        Ok(resolved) => return Ok(resolved)
        Err(ModuleNotFound(_, locs)) => searched.append(locs)
        Err(other) => return Err(other)
      }
  }
  Err(ModuleNotFound(module_name, searched))
}

// ============================================================================
// Path Mapping Resolution
// ============================================================================

///|
/// Try to resolve using paths mapping
fn try_resolve_with_paths(
  resolver : ModuleResolver,
  module_name : String,
  _containing_file : String,
) -> Result[ResolvedModule, ResolutionFailure] {
  let searched : Array[String] = []
  for pattern_entry in resolver.options.paths {
    let pattern = pattern_entry.0
    let substitutions = pattern_entry.1

    // Check if pattern matches
    match match_pattern(pattern, module_name) {
      Some(matched_star) =>
        // Try each substitution
        for subst in substitutions {
          let resolved_path = substitute_pattern(subst, matched_star)
          let base_path = match resolver.options.base_url {
            Some(base) => join_paths(base, resolved_path)
            None => join_paths(resolver.current_directory, resolved_path)
          }

          // Try to resolve the substituted path
          match try_resolve_file(resolver, base_path) {
            Ok(resolved) => return Ok(resolved)
            Err(ModuleNotFound(_, locs)) => searched.append(locs)
            Err(_) => ()
          }
        }
      None => ()
    }
  }
  Err(ModuleNotFound(module_name, searched))
}

///|
/// Match a path pattern against a module name
/// Pattern can contain a single * wildcard
fn match_pattern(pattern : String, module_name : String) -> String? {
  match string_index_of(pattern, '*') {
    Some(star_idx) => {
      let prefix = string_substring(pattern, 0, end=star_idx)
      let suffix = string_substring(pattern, star_idx + 1)
      if module_name.has_prefix(prefix) && module_name.has_suffix(suffix) {
        let matched_len = module_name.length() -
          prefix.length() -
          suffix.length()
        if matched_len >= 0 {
          Some(
            string_substring(
              module_name,
              prefix.length(),
              end=prefix.length() + matched_len,
            ),
          )
        } else {
          None
        }
      } else {
        None
      }
    }
    None =>
      // Exact match
      if pattern == module_name {
        Some("")
      } else {
        None
      }
  }
}

///|
/// Substitute * in pattern with matched text
fn substitute_pattern(pattern : String, star_match : String) -> String {
  match string_index_of(pattern, '*') {
    Some(idx) => {
      let prefix = string_substring(pattern, 0, end=idx)
      let suffix = string_substring(pattern, idx + 1)
      prefix + star_match + suffix
    }
    None => pattern
  }
}

// ============================================================================
// BaseUrl Resolution
// ============================================================================

///|
/// Try to resolve using baseUrl
fn try_resolve_with_base_url(
  resolver : ModuleResolver,
  module_name : String,
) -> Result[ResolvedModule, ResolutionFailure] {
  match resolver.options.base_url {
    Some(base_url) => {
      let candidate = join_paths(base_url, module_name)
      try_resolve_file(resolver, candidate)
    }
    None => Err(ModuleNotFound(module_name, []))
  }
}

// ============================================================================
// Node Modules Resolution
// ============================================================================

///|
/// Try to resolve from node_modules directories
fn try_resolve_from_node_modules(
  resolver : ModuleResolver,
  module_name : String,
  containing_file : String,
) -> Result[ResolvedModule, ResolutionFailure] {
  let searched : Array[String] = []
  let mut current_dir = get_directory_path(containing_file)

  // Parse package name (handle scoped packages)
  let (package_name, subpath) = parse_package_name(module_name)

  // Walk up directory tree
  while true {
    let node_modules_path = join_paths(current_dir, "node_modules")
    let package_path = join_paths(node_modules_path, package_name)

    // Try to resolve from this node_modules
    match try_resolve_package(resolver, package_path, subpath, module_name) {
      Ok(resolved) => {
        resolved.is_external_library_import = true
        resolved.package_id = Some(PackageId::{
          name: package_name,
          sub_module_name: if subpath.is_empty() {
            None
          } else {
            Some(subpath)
          },
          version: None,
        })
        return Ok(resolved)
      }
      Err(ModuleNotFound(_, locs)) => searched.append(locs)
      Err(_) => ()
    }

    // Move up one directory
    let parent = get_directory_path(current_dir)
    if parent == current_dir || parent.is_empty() {
      break
    }
    current_dir = parent
  }
  Err(ModuleNotFound(module_name, searched))
}

///|
/// Parse package name from module specifier
/// Handles scoped packages like @types/node
fn parse_package_name(module_name : String) -> (String, String) {
  if module_name.has_prefix("@") {
    // Scoped package: @scope/package/subpath
    match string_index_of(module_name, '/') {
      Some(first_slash) => {
        let after_first = string_substring(module_name, first_slash + 1)
        match string_index_of(after_first, '/') {
          Some(second_slash) => {
            let package_end = first_slash + 1 + second_slash
            (
              string_substring(module_name, 0, end=package_end),
              string_substring(module_name, package_end + 1),
            )
          }
          None => (module_name, "")
        }
      }
      None => (module_name, "")
    }
  } else {
    // Regular package: package/subpath
    match string_index_of(module_name, '/') {
      Some(slash_idx) =>
        (
          string_substring(module_name, 0, end=slash_idx),
          string_substring(module_name, slash_idx + 1),
        )
      None => (module_name, "")
    }
  }
}

///|
/// Try to resolve a package from its directory
fn try_resolve_package(
  resolver : ModuleResolver,
  package_path : String,
  subpath : String,
  original_module : String,
) -> Result[ResolvedModule, ResolutionFailure] {
  let searched : Array[String] = []
  if subpath.is_empty() {
    // Try package.json main field
    let package_json_path = join_paths(package_path, "package.json")
    searched.push(package_json_path)
    match read_package_json_main(package_json_path) {
      Some(main_path) => {
        let full_path = join_paths(package_path, main_path)
        match try_resolve_file(resolver, full_path) {
          Ok(resolved) => return Ok(resolved)
          Err(ModuleNotFound(_, locs)) => searched.append(locs)
          Err(_) => ()
        }
      }
      None => ()
    }

    // Try index files
    for ext in resolver.options.extensions {
      let index_path = join_paths(package_path, "index" + ext)
      searched.push(index_path)
      if file_exists(index_path) {
        return Ok(
          create_resolved_module(index_path, original_module, true, ext),
        )
      }
    }
  } else {
    // Resolve subpath within package
    let full_subpath = join_paths(package_path, subpath)
    match try_resolve_file(resolver, full_subpath) {
      Ok(resolved) => return Ok(resolved)
      Err(ModuleNotFound(_, locs)) => searched.append(locs)
      Err(_) => ()
    }
  }
  Err(ModuleNotFound(original_module, searched))
}

///|
/// Read main field from package.json
/// Returns the main entry point path if found
fn read_package_json_main(package_json_path : String) -> String? {
  // This would need actual file system access
  // For now, return common defaults
  if file_exists(package_json_path) {
    // In a real implementation, parse JSON and extract:
    // 1. "main" field
    // 2. "types" or "typings" field (for TypeScript)
    // 3. "exports" field (for modern packages)
    None
  } else {
    None
  }
}

// ============================================================================
// Classic Resolution (TypeScript legacy)
// ============================================================================

///|
/// Classic resolution - walks up directory tree looking for module
fn try_resolve_classic(
  resolver : ModuleResolver,
  module_name : String,
  containing_file : String,
) -> Result[ResolvedModule, ResolutionFailure] {
  let searched : Array[String] = []
  let mut current_dir = get_directory_path(containing_file)
  while true {
    // Try resolving in current directory
    let candidate = join_paths(current_dir, module_name)
    match try_resolve_file(resolver, candidate) {
      Ok(resolved) => return Ok(resolved)
      Err(ModuleNotFound(_, locs)) => searched.append(locs)
      Err(_) => ()
    }

    // Move up
    let parent = get_directory_path(current_dir)
    if parent == current_dir || parent.is_empty() {
      break
    }
    current_dir = parent
  }
  Err(ModuleNotFound(module_name, searched))
}

// ============================================================================
// File Resolution Helpers
// ============================================================================

///|
/// Try to resolve a file path with various extensions
fn try_resolve_file(
  resolver : ModuleResolver,
  path : String,
) -> Result[ResolvedModule, ResolutionFailure] {
  let searched : Array[String] = []
  let normalized = normalize_path(path)

  // Try exact path if it has extension
  let ext = get_extension(normalized)
  if not(ext.is_empty()) {
    searched.push(normalized)
    if file_exists(normalized) {
      return Ok(create_resolved_module(normalized, path, false, ext))
    }
  }

  // Try with TypeScript extensions
  for extension in resolver.options.extensions {
    let with_ext = normalized + extension
    searched.push(with_ext)
    if file_exists(with_ext) {
      return Ok(create_resolved_module(with_ext, path, false, extension))
    }
  }

  // Try as directory with index
  for extension in resolver.options.extensions {
    let index = join_paths(normalized, "index" + extension)
    searched.push(index)
    if file_exists(index) {
      return Ok(create_resolved_module(index, path, false, extension))
    }
  }
  Err(ModuleNotFound(path, searched))
}

///|
/// Create a resolved module record
fn create_resolved_module(
  resolved_file : String,
  original_path : String,
  is_external : Bool,
  extension : String,
) -> ResolvedModule {
  {
    resolved_file_name: resolved_file,
    original_path,
    is_external_library_import: is_external,
    package_id: None,
    extension,
  }
}

///|
/// Check if a file exists (placeholder - needs actual FS access)
fn file_exists(_path : String) -> Bool {
  // TODO: Implement actual file existence check
  // This will be connected to the file system layer
  false
}

// ============================================================================
// Module Specifier Classification
// ============================================================================

///|
/// Classify a module specifier
pub enum ModuleSpecifierKind {
  /// Relative path: ./foo, ../bar
  Relative
  /// Absolute path: /foo/bar
  Absolute
  /// Package reference: lodash, @types/node
  Package
  /// URL import: https://example.com/mod.ts
  URL
} derive(Show, Eq)

///|
/// Classify a module specifier
pub fn classify_module_specifier(specifier : String) -> ModuleSpecifierKind {
  if is_relative_path(specifier) {
    Relative
  } else if is_rooted_path(specifier) {
    Absolute
  } else if specifier.has_prefix("http://") || specifier.has_prefix("https://") {
    URL
  } else {
    Package
  }
}

// ============================================================================
// Resolution Diagnostics
// ============================================================================

///|
/// Create diagnostic for module not found
pub fn create_module_not_found_diagnostic(
  specifier : String,
  containing_file : String,
  searched : Array[String],
) -> Diagnostic {
  let searched_display : Array[String] = []
  let max_display = 5
  for i = 0; i < searched.length() && i < max_display; i = i + 1 {
    searched_display.push(searched[i])
  }
  let searched_str = if searched.length() > max_display {
    searched_display.join("\n  ") +
    "\n  ... and " +
    (searched.length() - max_display).to_string() +
    " more locations"
  } else {
    searched_display.join("\n  ")
  }
  Diagnostic::{
    category: DiagnosticCategory::Error,
    code: 2307, // TS2307: Cannot find module
    message: "Cannot find module '" +
    specifier +
    "' or its corresponding type declarations.\nSearched locations:\n  " +
    searched_str,
    location: SourceLocation::{
      file_path: containing_file,
      start: Position::{ line: 0, column: 0, offset: 0 },
      end: Position::{ line: 0, column: 0, offset: 0 },
    },
  }
}

///|
/// Create diagnostic for circular dependency
pub fn create_circular_dependency_diagnostic(
  chain : Array[String],
  containing_file : String,
) -> Diagnostic {
  Diagnostic::{
    category: DiagnosticCategory::Warning,
    code: 0, // No specific TS code for circular deps
    message: "Circular dependency detected: " + chain.join(" -> "),
    location: SourceLocation::{
      file_path: containing_file,
      start: Position::{ line: 0, column: 0, offset: 0 },
      end: Position::{ line: 0, column: 0, offset: 0 },
    },
  }
}
