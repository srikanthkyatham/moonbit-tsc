// Glob pattern matching for TypeScript file discovery
// Supports standard glob patterns used in tsconfig.json

///|
/// Check if a path matches a glob pattern
/// Supports:
/// - `*` matches any sequence of characters except path separator
/// - `**` matches any sequence including path separators (directory wildcard)
/// - `?` matches any single character except path separator
/// - `[abc]` matches any character in the set
/// - `[!abc]` or `[^abc]` matches any character not in the set
pub fn glob_match(pattern : String, path : String) -> Bool {
  glob_match_impl(pattern, 0, path, 0)
}

///|
/// Internal implementation of glob matching
fn glob_match_impl(
  pattern : String,
  pi : Int,
  path : String,
  si : Int,
) -> Bool {
  let plen = pattern.length()
  let slen = path.length()

  // Base cases
  if pi >= plen && si >= slen {
    return true
  }
  if pi >= plen {
    return false
  }

  // Handle **
  if pi + 1 < plen && pattern[pi] == '*' && pattern[pi + 1] == '*' {
    // Skip the **
    let mut next_pi = pi + 2
    // Skip optional trailing /
    if next_pi < plen && pattern[next_pi] == '/' {
      next_pi = next_pi + 1
    }

    // ** at end matches everything
    if next_pi >= plen {
      return true
    }

    // Try matching the rest from every position
    for i = si; i <= slen; i = i + 1 {
      if glob_match_impl(pattern, next_pi, path, i) {
        return true
      }
    }
    return false
  }

  // Handle *
  if pattern[pi] == '*' {
    // Try matching 0 or more non-separator characters
    for i = si; i <= slen; i = i + 1 {
      if glob_match_impl(pattern, pi + 1, path, i) {
        return true
      }
      // Stop at path separator
      if i < slen && (path[i] == '/' || path[i] == '\\') {
        break
      }
    }
    return false
  }

  // No more path characters but pattern has more
  if si >= slen {
    return false
  }

  // Handle ?
  if pattern[pi] == '?' {
    // Match any single non-separator character
    if path[si] != '/' && path[si] != '\\' {
      return glob_match_impl(pattern, pi + 1, path, si + 1)
    }
    return false
  }

  // Handle [...]
  if pattern[pi] == '[' {
    let (matched, new_pi) = match_bracket(pattern, pi, path[si])
    if matched {
      return glob_match_impl(pattern, new_pi, path, si + 1)
    }
    return false
  }

  // Handle literal characters (normalize path separators)
  let pc = pattern[pi]
  let sc = path[si]
  if pc == sc || (pc == '/' && sc == '\\') || (pc == '\\' && sc == '/') {
    return glob_match_impl(pattern, pi + 1, path, si + 1)
  }

  false
}

///|
/// Match bracket expression [...]
/// Returns (matched, index after closing bracket)
fn match_bracket(pattern : String, pi : Int, c : Int) -> (Bool, Int) {
  let plen = pattern.length()
  let mut i = pi + 1 // Skip opening [
  let mut negate = false

  // Check for negation
  if i < plen && (pattern[i] == '!' || pattern[i] == '^') {
    negate = true
    i = i + 1
  }

  let mut matched = false
  let mut first = true

  while i < plen && (pattern[i] != ']' || first) {
    first = false
    let char_code = pattern[i]

    // Check for range a-z
    if i + 2 < plen && pattern[i + 1] == '-' && pattern[i + 2] != ']' {
      let range_end = pattern[i + 2]
      if c >= char_code && c <= range_end {
        matched = true
      }
      i = i + 3
    } else {
      if c == char_code {
        matched = true
      }
      i = i + 1
    }
  }

  // Skip closing bracket
  if i < plen && pattern[i] == ']' {
    i = i + 1
  }

  if negate {
    (not(matched), i)
  } else {
    (matched, i)
  }
}

///|
/// Check if a path matches any of the given patterns
pub fn matches_any_pattern(patterns : Array[String], path : String) -> Bool {
  for pattern in patterns {
    if glob_match(pattern, path) {
      return true
    }
  }
  false
}

///|
/// Check if a path should be excluded based on exclude patterns
/// Returns true if the path matches any exclude pattern
pub fn should_exclude(exclude_patterns : Array[String], path : String) -> Bool {
  for pattern in exclude_patterns {
    // For simple directory names like "node_modules", check if path contains it
    if not(pattern.contains("*")) && not(pattern.contains("?")) {
      if path.contains(pattern) {
        return true
      }
    } else if glob_match(pattern, path) {
      return true
    }
  }
  false
}

///|
/// Normalize a path for matching (convert backslashes to forward slashes)
pub fn normalize_path(path : String) -> String {
  let result = StringBuilder::new()
  for i = 0; i < path.length(); i = i + 1 {
    if path[i] == '\\' {
      result.write_char('/')
    } else {
      result.write_char(Int::unsafe_to_char(path[i]))
    }
  }
  result.to_string()
}

///|
/// Get the relative path from a base directory
pub fn get_relative_path(base_dir : String, full_path : String) -> String {
  let norm_base = normalize_path(base_dir)
  let norm_path = normalize_path(full_path)

  if norm_path.has_prefix(norm_base) {
    let start_idx = norm_base.length()
    if start_idx >= norm_path.length() {
      return ""
    }
    let rel = substring_from(norm_path, start_idx)
    if rel.has_prefix("/") {
      substring_from(rel, 1)
    } else {
      rel
    }
  } else {
    norm_path
  }
}

///|
/// Helper to get substring from index to end
fn substring_from(s : String, start : Int) -> String {
  if start >= s.length() {
    return ""
  }
  let result = StringBuilder::new()
  for i = start; i < s.length(); i = i + 1 {
    result.write_char(Int::unsafe_to_char(s[i]))
  }
  result.to_string()
}
