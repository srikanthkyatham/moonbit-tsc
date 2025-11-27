// Path resolver for TypeScript module resolution
// Handles baseUrl and paths mapping from tsconfig.json

///|
/// Resolve a module specifier to a file path using tsconfig paths
/// Returns None if no mapping found
pub fn resolve_module_path(
  module_specifier : String,
  from_file : String,
  options : CompilerOptions,
) -> String? {
  // Try paths mapping first
  match resolve_with_paths(module_specifier, from_file, options) {
    Some(resolved) => return Some(resolved)
    None => ()
  }

  // Try baseUrl resolution
  match resolve_with_base_url(module_specifier, from_file, options) {
    Some(resolved) => return Some(resolved)
    None => ()
  }

  // No resolution found
  None
}

///|
/// Resolve using paths mapping
fn resolve_with_paths(
  module_specifier : String,
  from_file : String,
  options : CompilerOptions,
) -> String? {
  guard options.paths is Some(paths) else { return None }
  guard options.base_url is Some(base_url) else { return None }

  // Get directory of the file doing the import
  let from_dir = get_parent_directory(from_file)

  // Resolve baseUrl relative to tsconfig location (use from_dir as approximation)
  let resolved_base = if base_url.has_prefix("/") {
    base_url
  } else {
    join_path(from_dir, base_url)
  }

  // Try each path pattern
  for pattern, targets in paths {
    match try_match_path_pattern(pattern, module_specifier) {
      Some(matched_part) => {
        // Try each target path
        for target in targets {
          let resolved = resolve_path_target(
            target,
            matched_part,
            resolved_base,
          )
          // In a real implementation, we'd check if file exists
          // For now, just return the first match
          return Some(resolved)
        }
      }
      None => continue
    }
  }

  None
}

///|
/// Resolve using baseUrl
fn resolve_with_base_url(
  module_specifier : String,
  from_file : String,
  options : CompilerOptions,
) -> String? {
  guard options.base_url is Some(base_url) else { return None }

  // Skip relative imports
  if module_specifier.has_prefix("./") || module_specifier.has_prefix("../") {
    return None
  }

  // Skip absolute imports
  if module_specifier.has_prefix("/") {
    return None
  }

  // Get directory of the file doing the import
  let from_dir = get_parent_directory(from_file)

  // Resolve baseUrl relative to the file location (approximation)
  let resolved_base = if base_url.has_prefix("/") {
    base_url
  } else {
    join_path(from_dir, base_url)
  }

  // Combine baseUrl with module specifier
  Some(join_path(resolved_base, module_specifier))
}

///|
/// Try to match a path pattern like "@/*" or "utils/*"
/// Returns the matched wildcard portion if successful
fn try_match_path_pattern(
  pattern : String,
  specifier : String,
) -> String? {
  // Find the wildcard position in pattern
  let wildcard_idx = find_char(pattern, '*')

  match wildcard_idx {
    None => {
      // Exact match (no wildcard)
      if pattern == specifier {
        Some("")
      } else {
        None
      }
    }
    Some(idx) => {
      // Pattern has wildcard
      let prefix = @utils.substr(pattern, start=0, end=idx)
      let suffix = if idx + 1 < pattern.length() {
        @utils.substr(pattern, start=idx + 1)
      } else {
        ""
      }

      // Check if specifier matches pattern
      if specifier.has_prefix(prefix) {
        let after_prefix = @utils.substr(specifier, start=prefix.length())
        if suffix.length() == 0 {
          // Pattern ends with *, match rest
          Some(after_prefix)
        } else if after_prefix.has_suffix(suffix) {
          // Pattern has suffix after *, extract middle
          let middle_end = after_prefix.length() - suffix.length()
          Some(@utils.substr(after_prefix, start=0, end=middle_end))
        } else {
          None
        }
      } else {
        None
      }
    }
  }
}

///|
/// Resolve a path target by replacing * with matched part
fn resolve_path_target(
  target : String,
  matched_part : String,
  base_url : String,
) -> String {
  // Replace * with matched part
  let resolved_target = replace_wildcard(target, matched_part)

  // Combine with baseUrl
  if resolved_target.has_prefix("/") {
    resolved_target
  } else {
    join_path(base_url, resolved_target)
  }
}

///|
/// Replace * in target with matched part
fn replace_wildcard(target : String, replacement : String) -> String {
  let result = StringBuilder::new()
  let mut i = 0
  while i < target.length() {
    if target[i] == '*' {
      result.write_string(replacement)
    } else {
      result.write_char(Int::unsafe_to_char(target[i]))
    }
    i = i + 1
  }
  result.to_string()
}

///|
/// Get parent directory from a path
fn get_parent_directory(path : String) -> String {
  let mut last_slash = -1
  for i = 0; i < path.length(); i = i + 1 {
    if path[i] == '/' || path[i] == '\\' {
      last_slash = i
    }
  }
  if last_slash <= 0 {
    "."
  } else {
    @utils.substr(path, start=0, end=last_slash)
  }
}

///|
/// Join two path segments
fn join_path(base : String, relative : String) -> String {
  if relative.has_prefix("/") {
    return relative
  }

  let base_clean = if base.has_suffix("/") || base.has_suffix("\\") {
    @utils.substr(base, start=0, end=base.length() - 1)
  } else {
    base
  }

  if relative.has_prefix("./") {
    base_clean + "/" + @utils.substr(relative, start=2)
  } else if relative.has_prefix("../") {
    let parent = get_parent_directory(base_clean)
    join_path(parent, @utils.substr(relative, start=3))
  } else {
    base_clean + "/" + relative
  }
}

///|
/// Find index of character in string
fn find_char(s : String, c : Char) -> Int? {
  let code = c.to_int()
  for i = 0; i < s.length(); i = i + 1 {
    if s[i] == code {
      return Some(i)
    }
  }
  None
}

///|
/// Check if a module specifier looks like a relative path
pub fn is_relative_specifier(specifier : String) -> Bool {
  specifier.has_prefix("./") || specifier.has_prefix("../")
}

///|
/// Check if a module specifier looks like an absolute path
pub fn is_absolute_specifier(specifier : String) -> Bool {
  specifier.has_prefix("/")
}

///|
/// Check if a module specifier looks like a bare specifier (npm package)
pub fn is_bare_specifier(specifier : String) -> Bool {
  not(is_relative_specifier(specifier)) && not(is_absolute_specifier(specifier))
}

///|
/// Normalize a module specifier (remove .ts/.tsx extension if present)
pub fn normalize_specifier(specifier : String) -> String {
  if specifier.has_suffix(".ts") {
    @utils.substr(specifier, start=0, end=specifier.length() - 3)
  } else if specifier.has_suffix(".tsx") {
    @utils.substr(specifier, start=0, end=specifier.length() - 4)
  } else {
    specifier
  }
}

///|
/// Try common TypeScript file extensions
pub fn try_resolve_extensions(path : String) -> Array[String] {
  [
    path + ".ts",
    path + ".tsx",
    path + ".d.ts",
    path + "/index.ts",
    path + "/index.tsx",
    path + "/index.d.ts",
  ]
}

// ============================================================================
// Node.js Module Resolution
// ============================================================================

///|
/// Parsed package name result
pub struct ParsedPackageName {
  package_name : String // e.g., "lodash" or "@types/node"
  subpath : String // e.g., "" or "/deep/import"
}

///|
/// Parse a bare specifier into package name and subpath
/// Handles scoped packages like @types/node/fs
pub fn parse_package_name(specifier : String) -> ParsedPackageName {
  // Handle scoped packages (@scope/name)
  if specifier.has_prefix("@") {
    // Find first slash after scope
    let first_slash = find_char_from(specifier, '/', 1)
    match first_slash {
      None => {
        // Just @scope with no package name - invalid, treat as package
        { package_name: specifier, subpath: "" }
      }
      Some(scope_end) => {
        // Find second slash (after package name)
        let second_slash = find_char_from(specifier, '/', scope_end + 1)
        match second_slash {
          None => {
            // @scope/name with no subpath
            { package_name: specifier, subpath: "" }
          }
          Some(pkg_end) => {
            // @scope/name/subpath
            let package_name = @utils.substr(specifier, start=0, end=pkg_end)
            let subpath = @utils.substr(specifier, start=pkg_end)
            { package_name, subpath }
          }
        }
      }
    }
  } else {
    // Non-scoped package
    let slash_idx = find_char(specifier, '/')
    match slash_idx {
      None => {
        // Just package name
        { package_name: specifier, subpath: "" }
      }
      Some(idx) => {
        // package/subpath
        let package_name = @utils.substr(specifier, start=0, end=idx)
        let subpath = @utils.substr(specifier, start=idx)
        { package_name, subpath }
      }
    }
  }
}

///|
/// Find character in string starting from a given index
fn find_char_from(s : String, c : Char, start : Int) -> Int? {
  let code = c.to_int()
  for i = start; i < s.length(); i = i + 1 {
    if s[i] == code {
      return Some(i)
    }
  }
  None
}

///|
/// Resolve a bare specifier from node_modules
/// Climbs directory tree looking for node_modules/package
pub fn resolve_from_node_modules(
  specifier : String,
  from_file : String,
  file_exists : (String) -> Bool,
  read_file : (String) -> String?,
) -> String? {
  // Skip relative and absolute paths
  if is_relative_specifier(specifier) || is_absolute_specifier(specifier) {
    return None
  }

  // Parse the package name and subpath
  let parsed = parse_package_name(specifier)

  // Start from the directory containing the importing file
  let mut current_dir = get_parent_directory(from_file)

  // Climb the directory tree
  // Stop when we hit "." (no more parent) or "/" (root) or empty string
  while current_dir.length() > 0 && current_dir != "/" && current_dir != "." {
    let node_modules_path = join_path(current_dir, "node_modules")
    let package_path = join_path(node_modules_path, parsed.package_name)

    // Try to resolve from this node_modules directory
    match try_resolve_package(
      package_path,
      parsed.subpath,
      file_exists,
      read_file,
    ) {
      Some(resolved) => return Some(resolved)
      None => ()
    }

    // Move up to parent directory
    let parent = get_parent_directory(current_dir)
    // Stop if we're not making progress (would cause infinite loop)
    if parent == current_dir {
      break
    }
    current_dir = parent
  }

  // Also check root node_modules
  let root_package_path = join_path("/node_modules", parsed.package_name)
  try_resolve_package(root_package_path, parsed.subpath, file_exists, read_file)
}

///|
/// Try to resolve a package at the given path
fn try_resolve_package(
  package_path : String,
  subpath : String,
  file_exists : (String) -> Bool,
  read_file : (String) -> String?,
) -> String? {
  if subpath.length() > 0 {
    // Has subpath, try direct resolution
    let full_path = package_path + subpath
    // Try TypeScript extensions first
    for ext_path in try_resolve_extensions(full_path) {
      if file_exists(ext_path) {
        return Some(ext_path)
      }
    }
    // Try JS extensions for declaration files
    for ext in [".js", ".mjs", ".cjs"] {
      let js_path = full_path + ext
      if file_exists(js_path) {
        return Some(js_path)
      }
    }
    // Try as-is (might already have extension)
    if file_exists(full_path) {
      return Some(full_path)
    }
    return None
  }

  // No subpath - need to find entry point from package.json
  let package_json_path = join_path(package_path, "package.json")

  // Try to read and parse package.json
  match read_file(package_json_path) {
    Some(content) => {
      // Try to find types/main field
      match get_package_entry_point(content, file_exists, package_path) {
        Some(entry) => return Some(entry)
        None => ()
      }
    }
    None => ()
  }

  // Fallback: try index files
  for ext_path in try_resolve_extensions(package_path) {
    if file_exists(ext_path) {
      return Some(ext_path)
    }
  }

  None
}

///|
/// Extract entry point from package.json content
/// Looks for: types, typings, main (in that order for TypeScript)
fn get_package_entry_point(
  package_json_content : String,
  file_exists : (String) -> Bool,
  package_path : String,
) -> String? {
  // Try to find "types" field
  match extract_json_string_field(package_json_content, "types") {
    Some(types_path) => {
      let full_path = join_path(package_path, types_path)
      if file_exists(full_path) {
        return Some(full_path)
      }
    }
    None => ()
  }

  // Try to find "typings" field (older convention)
  match extract_json_string_field(package_json_content, "typings") {
    Some(typings_path) => {
      let full_path = join_path(package_path, typings_path)
      if file_exists(full_path) {
        return Some(full_path)
      }
    }
    None => ()
  }

  // Try to find "main" field
  match extract_json_string_field(package_json_content, "main") {
    Some(main_path) => {
      let full_path = join_path(package_path, main_path)
      // For main, also try .d.ts alongside .js
      if full_path.has_suffix(".js") {
        let dts_path = @utils.substr(full_path, start=0, end=full_path.length() -
            3) +
          ".d.ts"
        if file_exists(dts_path) {
          return Some(dts_path)
        }
      }
      if file_exists(full_path) {
        return Some(full_path)
      }
      // Try with TypeScript extensions
      for ext_path in try_resolve_extensions(
        @utils.substr(full_path, start=0, end=full_path.length() - 3),
      ) {
        if file_exists(ext_path) {
          return Some(ext_path)
        }
      }
    }
    None => ()
  }

  None
}

///|
/// Simple JSON string field extractor
/// Looks for "fieldName": "value" pattern
fn extract_json_string_field(json : String, field_name : String) -> String? {
  // Build search pattern: "fieldName"
  let pattern = "\"" + field_name + "\""
  let pattern_start = find_substring(json, pattern)

  match pattern_start {
    None => None
    Some(start_idx) => {
      // Find the colon after the field name
      let after_field = start_idx + pattern.length()
      let colon_idx = find_char_from(json, ':', after_field)

      match colon_idx {
        None => None
        Some(colon) => {
          // Find the opening quote of the value
          let quote_start = find_char_from(json, '"', colon + 1)

          match quote_start {
            None => None
            Some(value_start) => {
              // Find the closing quote
              let quote_end = find_char_from(json, '"', value_start + 1)

              match quote_end {
                None => None
                Some(value_end) =>
                  Some(
                    @utils.substr(json, start=value_start + 1, end=value_end),
                  )
              }
            }
          }
        }
      }
    }
  }
}

///|
/// Find a substring in a string
fn find_substring(haystack : String, needle : String) -> Int? {
  if needle.length() == 0 {
    return Some(0)
  }
  if needle.length() > haystack.length() {
    return None
  }

  for i = 0; i <= haystack.length() - needle.length(); i = i + 1 {
    let mut matched = true
    for j = 0; j < needle.length(); j = j + 1 {
      if haystack[i + j] != needle[j] {
        matched = false
        break
      }
    }
    if matched {
      return Some(i)
    }
  }
  None
}

///|
/// Resolve module with full algorithm including node_modules
/// This is the main entry point for module resolution
pub fn resolve_module_full(
  module_specifier : String,
  from_file : String,
  options : CompilerOptions,
  file_exists : (String) -> Bool,
  read_file : (String) -> String?,
) -> String? {
  // 1. Try paths mapping first (highest priority)
  match resolve_with_paths(module_specifier, from_file, options) {
    Some(resolved) => return Some(resolved)
    None => ()
  }

  // 2. Try baseUrl resolution
  match resolve_with_base_url(module_specifier, from_file, options) {
    Some(resolved) => return Some(resolved)
    None => ()
  }

  // 3. For bare specifiers, try node_modules resolution
  if is_bare_specifier(module_specifier) {
    match resolve_from_node_modules(
      module_specifier,
      from_file,
      file_exists,
      read_file,
    ) {
      Some(resolved) => return Some(resolved)
      None => ()
    }
  }

  // No resolution found
  None
}
