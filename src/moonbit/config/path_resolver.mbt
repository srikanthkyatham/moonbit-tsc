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
      let prefix = pattern.substring(start=0, end=idx)
      let suffix = if idx + 1 < pattern.length() {
        pattern.substring(start=idx + 1)
      } else {
        ""
      }

      // Check if specifier matches pattern
      if specifier.has_prefix(prefix) {
        let after_prefix = specifier.substring(start=prefix.length())
        if suffix.length() == 0 {
          // Pattern ends with *, match rest
          Some(after_prefix)
        } else if after_prefix.has_suffix(suffix) {
          // Pattern has suffix after *, extract middle
          let middle_end = after_prefix.length() - suffix.length()
          Some(after_prefix.substring(start=0, end=middle_end))
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
    path.substring(start=0, end=last_slash)
  }
}

///|
/// Join two path segments
fn join_path(base : String, relative : String) -> String {
  if relative.has_prefix("/") {
    return relative
  }

  let base_clean = if base.has_suffix("/") || base.has_suffix("\\") {
    base.substring(start=0, end=base.length() - 1)
  } else {
    base
  }

  if relative.has_prefix("./") {
    base_clean + "/" + relative.substring(start=2)
  } else if relative.has_prefix("../") {
    let parent = get_parent_directory(base_clean)
    join_path(parent, relative.substring(start=3))
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
    specifier.substring(start=0, end=specifier.length() - 3)
  } else if specifier.has_suffix(".tsx") {
    specifier.substring(start=0, end=specifier.length() - 4)
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
