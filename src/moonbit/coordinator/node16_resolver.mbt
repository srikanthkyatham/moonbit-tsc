// Node16/NodeNext module resolution (real filesystem)
//
// Implements the parts of TypeScript's node16/nodenext resolution that the
// node10 resolver (node_modules_resolver.mbt) does not cover:
// - package.json `exports` maps (which REPLACE main/types resolution),
//   including condition objects, wildcard patterns ("./*", "./x/*.js"),
//   trailing-slash keys, and blocked subpaths (null or no match)
// - package.json `imports` maps ("#..." specifiers)
// - package self-name resolution (nearest package.json with matching "name")
// - CJS/ESM file-format classification (.mts/.cts extensions and the
//   nearest package.json "type" field)
//
// Conditions applied, mirroring tsc: "types" and "node" are always active,
// plus "import" (ESM importer) or "require" (CJS importer); "default"
// always matches. Object keys are checked in declaration order.

// ============================================================================
// File-format classification
// ============================================================================

///|
/// Parsed package.json fields used by node16 resolution
pub(all) struct PackageJsonNode16 {
  name : String?
  types : String? // types/typings (first non-empty)
  main : String?
  type_field : String? // "module" | "commonjs"
  exports : Json?
  imports : Json?
} derive(Debug)

///|
/// Cache for node16 resolution lookups
pub(all) struct Node16Cache {
  /// directory -> parsed package.json (None = no package.json in that dir)
  package_json : Map[String, PackageJsonNode16?]
  /// (from_file|specifier|format) -> resolution
  entries : Map[String, ResolvedModule]
}

///|
pub fn Node16Cache::new() -> Node16Cache {
  { package_json: Map([]), entries: Map([]) }
}

///|
/// Extract a string field from a Json object, treating "" as absent
fn json_string_field(obj : Map[String, Json], field : String) -> String? {
  match obj.get(field) {
    Some(String(s)) => if s == "" { None } else { Some(s) }
    _ => None
  }
}

///|
/// Parse package.json content into the fields node16 resolution needs
pub fn parse_package_json_node16(content : String) -> PackageJsonNode16? {
  let json = try? @json.parse(content)
  match json {
    Ok(Object(obj)) => {
      let types = match json_string_field(obj, "types") {
        Some(t) => Some(t)
        None => json_string_field(obj, "typings")
      }
      Some(PackageJsonNode16::{
        name: json_string_field(obj, "name"),
        types,
        main: json_string_field(obj, "main"),
        type_field: json_string_field(obj, "type"),
        exports: obj.get("exports"),
        imports: obj.get("imports"),
      })
    }
    _ => None
  }
}

///|
/// Read and parse <dir>/package.json (cached; None when absent/unparseable)
async fn read_package_json_in(
  dir : String,
  cache : Node16Cache,
) -> PackageJsonNode16? raise Error {
  match cache.package_json.get(dir) {
    Some(cached) => return cached
    None => ()
  }
  let path = join_path(dir, "package.json")
  let result : PackageJsonNode16? = if is_regular_file(path) {
    let data = @fs.read_file(path)
    parse_package_json_node16(data.text())
  } else {
    None
  }
  cache.package_json[dir] = result
  result
}

///|
/// Find the nearest enclosing package.json walking up from `dir`.
/// Returns (directory containing it, parsed content).
async fn nearest_package_scope(
  dir : String,
  cache : Node16Cache,
) -> (String, PackageJsonNode16)? raise Error {
  let mut current = dir
  while current.length() > 0 {
    match read_package_json_in(current, cache) {
      Some(pkg) => return Some((current, pkg))
      None => ()
    }
    let parent = dirname(current)
    if parent == current {
      break
    }
    current = parent
  }
  None
}

///|
/// Classify a file as ESM or CJS following Node.js rules:
/// .mts/.mjs/.d.mts are always ESM; .cts/.cjs/.d.cts always CJS;
/// .ts/.tsx/.js/.d.ts follow the nearest package.json "type" field
/// ("module" -> ESM, anything else / no package.json -> CJS).
pub async fn classify_module_format_fs(
  path : String,
  cache : Node16Cache,
) -> @compiler.ModuleFormat raise Error {
  if path.has_suffix(".mts") || path.has_suffix(".mjs") {
    return @compiler.ModuleFormat::esm()
  }
  if path.has_suffix(".cts") || path.has_suffix(".cjs") {
    return @compiler.ModuleFormat::cjs()
  }
  match nearest_package_scope(dirname(path), cache) {
    Some((_, pkg)) =>
      if pkg.type_field == Some("module") {
        @compiler.ModuleFormat::esm()
      } else {
        @compiler.ModuleFormat::cjs()
      }
    None => @compiler.ModuleFormat::cjs()
  }
}

// ============================================================================
// Exports / imports map matching (pure)
// ============================================================================

///|
/// Result of looking up a subpath in an exports/imports map
pub(all) enum ExportsLookup {
  /// Matched: the (star-substituted) target string, e.g. "./index.js"
  Found(String)
  /// Explicitly blocked (null target) or not present in the map
  NoMatch
} derive(Debug, Eq)

///|
/// Count occurrences of '*' in a string
fn count_stars(s : String) -> Int {
  let mut n = 0
  for i = 0; i < s.length(); i = i + 1 {
    if s[i] == '*' {
      n = n + 1
    }
  }
  n
}

///|
/// Substitute the first '*' in `target` with `star`
fn substitute_star(target : String, star : String) -> String {
  for i = 0; i < target.length(); i = i + 1 {
    if target[i] == '*' {
      return target[:i].to_owned() + star + target[i + 1:].to_owned()
    }
  }
  // Legacy trailing-slash directory mapping: the target has no '*', so the
  // matched remainder is appended (e.g. "./src/" + "util.js").
  target + star
}

///|
/// Check whether a condition object key is active
fn condition_active(key : String, conditions : Array[String]) -> Bool {
  if key == "default" {
    return true
  }
  for c in conditions {
    if c == key {
      return true
    }
  }
  false
}

///|
/// Resolve a matched exports value (string / condition object / array /
/// null) to a target string. `star` is the wildcard match to substitute.
fn resolve_exports_target(
  value : Json,
  star : String?,
  conditions : Array[String],
) -> ExportsLookup {
  match value {
    String(target) => {
      let substituted = match star {
        Some(s) => substitute_star(target, s)
        None => target
      }
      Found(substituted)
    }
    Object(obj) => {
      // Condition object: first active key wins (keys in declaration order)
      for entry in obj {
        let (key, sub_value) = entry
        if condition_active(key, conditions) {
          match resolve_exports_target(sub_value, star, conditions) {
            Found(t) => return Found(t)
            NoMatch => return NoMatch // matched condition decides
          }
        }
      }
      NoMatch
    }
    Array(items) => {
      for item in items {
        match resolve_exports_target(item, star, conditions) {
          Found(t) => return Found(t)
          NoMatch => ()
        }
      }
      NoMatch
    }
    _ => NoMatch // null and other values block resolution
  }
}

///|
/// Match a subpath ("." or "./x/y") against an exports map key.
/// Returns Some(star_match?) on a match:
///   exact key            -> Some(None)
///   single-'*' pattern   -> Some(Some(matched_middle))
///   trailing-'/' key     -> Some(Some(rest)) (legacy directory mapping)
/// Keys with more than one '*' never match (Node treats them as invalid).
fn match_exports_key(key : String, subpath : String) -> String?? {
  if key == subpath {
    return Some(None)
  }
  let stars = count_stars(key)
  if stars == 1 {
    // Single wildcard: prefix + '*' + suffix
    let mut star_idx = -1
    for i = 0; i < key.length(); i = i + 1 {
      if key[i] == '*' {
        star_idx = i
        break
      }
    }
    let prefix = key[:star_idx].to_owned()
    let suffix = key[star_idx + 1:].to_owned()
    if subpath.length() >= prefix.length() + suffix.length() &&
      subpath.has_prefix(prefix) &&
      subpath.has_suffix(suffix) {
      let mid = subpath[prefix.length():subpath.length() - suffix.length()].to_owned()
      return Some(Some(mid))
    }
    return None
  }
  if stars == 0 && key.has_suffix("/") && subpath.has_prefix(key) {
    // Legacy trailing-slash key: remainder is appended to the target
    return Some(Some(subpath[key.length():].to_owned()))
  }
  None
}

///|
/// Look up a subpath in a package.json `exports` (or `imports`) value.
/// `subpath` is "." or "./x/y" for exports, "#x" for imports.
pub fn lookup_exports(
  exports : Json,
  subpath : String,
  conditions : Array[String],
) -> ExportsLookup {
  match exports {
    Object(obj) => {
      // Determine map flavor: subpath keys start with "." (exports) or "#"
      // (imports); anything else means the object is a condition object
      // applying to the "." subpath only.
      let mut is_subpath_map = true
      for entry in obj {
        let (key, _) = entry
        if !(key.has_prefix(".")) && !(key.has_prefix("#")) {
          is_subpath_map = false
        }
        break
      }
      if !(is_subpath_map) {
        if subpath == "." {
          return resolve_exports_target(exports, None, conditions)
        }
        return NoMatch
      }
      // Exact key match first (keys containing '*' are patterns, never
      // exact matches — Node treats a literal lookup of such keys as
      // invalid, e.g. "./a/*/b/*" with two stars)
      if count_stars(subpath) == 0 {
        match obj.get(subpath) {
          Some(value) => return resolve_exports_target(value, None, conditions)
          None => ()
        }
      }
      // Pattern keys: best match = longest literal prefix
      let mut best_key : String? = None
      let mut best_star : String? = None
      let mut best_prefix_len = -1
      for entry in obj {
        let (key, _) = entry
        match match_exports_key(key, subpath) {
          Some(Some(star)) => {
            let mut prefix_len = key.length()
            for i = 0; i < key.length(); i = i + 1 {
              if key[i] == '*' {
                prefix_len = i
                break
              }
            }
            if prefix_len > best_prefix_len {
              best_prefix_len = prefix_len
              best_key = Some(key)
              best_star = Some(star)
            }
          }
          _ => ()
        }
      }
      match (best_key, best_star) {
        (Some(key), Some(star)) =>
          match obj.get(key) {
            Some(value) => resolve_exports_target(value, Some(star), conditions)
            None => NoMatch
          }
        _ => NoMatch
      }
    }
    // A bare string / array / null exports value applies to "." only
    _ =>
      if subpath == "." {
        resolve_exports_target(exports, None, conditions)
      } else {
        NoMatch
      }
  }
}

// ============================================================================
// Target -> file resolution
// ============================================================================

///|
/// Declaration-file / TypeScript-source candidates for a JS target path,
/// in tsc's substitution order
fn typed_candidates_for_target(target : String) -> Array[String] {
  let candidates : Array[String] = []
  if target.has_suffix(".mjs") {
    let base = target[:target.length() - 4].to_owned()
    candidates.push(base + ".mts")
    candidates.push(base + ".d.mts")
  } else if target.has_suffix(".cjs") {
    let base = target[:target.length() - 4].to_owned()
    candidates.push(base + ".cts")
    candidates.push(base + ".d.cts")
  } else if target.has_suffix(".js") {
    let base = target[:target.length() - 3].to_owned()
    candidates.push(base + ".ts")
    candidates.push(base + ".tsx")
    candidates.push(base + ".d.ts")
  } else if target.has_suffix(".jsx") {
    let base = target[:target.length() - 4].to_owned()
    candidates.push(base + ".tsx")
    candidates.push(base + ".d.ts")
  } else if target.has_suffix(".d.ts") ||
    target.has_suffix(".d.mts") ||
    target.has_suffix(".d.cts") ||
    target.has_suffix(".ts") ||
    target.has_suffix(".tsx") ||
    target.has_suffix(".mts") ||
    target.has_suffix(".cts") {
    // exports pointing directly at a TypeScript file
    candidates.push(target)
  }
  candidates
}

///|
/// Resolve an exports target ("./x.js", relative to the package directory)
/// to an actual file: typed candidates first, then the literal (JS) file.
/// Returns (path, is_typed).
async fn load_exports_target(
  package_dir : String,
  target : String,
) -> (String, Bool)? raise Error {
  if !(target.has_prefix("./")) {
    return None
  }
  let rel = target[2:].to_owned()
  for candidate in typed_candidates_for_target(rel) {
    let full = join_path(package_dir, candidate)
    if is_regular_file(full) {
      return Some((full, true))
    }
  }
  let literal = join_path(package_dir, rel)
  if is_regular_file(literal) {
    // Untyped only if it's a JS-family file; a literal .ts hit was already
    // covered by typed candidates
    return Some((literal, false))
  }
  None
}

// ============================================================================
// Main node16 resolution entry point
// ============================================================================

///|
/// Active condition names for an importer format
fn conditions_for_format(format : @compiler.ModuleFormat) -> Array[String] {
  match format {
    @compiler.ModuleFormat::ESM => ["node", "import", "types"]
    _ => ["node", "require", "types"]
  }
}

///|
/// Resolve a package directory's entry using node16 rules: an `exports`
/// field REPLACES main/types/index resolution; without one, the node10
/// package entry logic applies. Returns Resolved / NotFound; `untyped_out`
/// collects an untyped (JS) hit as a fallback.
async fn resolve_package_dir_node16(
  package_dir : String,
  subpath : String, // "." or "./x"
  conditions : Array[String],
  cache : Node16Cache,
  untyped_out : Array[String],
) -> String? raise Error {
  match read_package_json_in(package_dir, cache) {
    Some(pkg) =>
      match pkg.exports {
        Some(exports) =>
          match lookup_exports(exports, subpath, conditions) {
            Found(target) =>
              match load_exports_target(package_dir, target) {
                Some((path, typed)) => {
                  if typed {
                    return Some(path)
                  }
                  untyped_out.push(path)
                  return None
                }
                None => return None
              }
            NoMatch => return None // blocked: exports replaces main/types
          }
        None => ()
      }
    None => ()
  }
  // No exports map: node10-style package entry (types/typings/main/index)
  let sub : String? = if subpath == "." {
    None
  } else {
    Some(subpath[2:].to_owned())
  }
  match resolve_package_entry(package_dir, sub, true) {
    Some(typed) => return Some(typed)
    None => ()
  }
  match resolve_package_entry(package_dir, sub, false) {
    Some(untyped) => untyped_out.push(untyped)
    None => ()
  }
  None
}

///|
/// Resolve a bare or "#"-prefixed import specifier under node16/nodenext
/// rules. `importer_format` selects the "import"/"require" condition.
pub async fn resolve_import_node16(
  specifier : String,
  from_file : String,
  importer_format : @compiler.ModuleFormat,
  cache : Node16Cache,
) -> ResolvedModule raise Error {
  let format_tag = match importer_format {
    @compiler.ModuleFormat::ESM => "esm"
    _ => "cjs"
  }
  let cache_key = from_file + "|" + specifier + "|" + format_tag
  match cache.entries.get(cache_key) {
    Some(result) => return result
    None => ()
  }
  fn done(result : ResolvedModule) -> ResolvedModule {
    cache.entries[cache_key] = result
    result
  }

  let conditions = conditions_for_format(importer_format)
  let from_dir = dirname(from_file)
  let untyped : Array[String] = []

  // "#..." specifiers: nearest package.json `imports` map
  if specifier.has_prefix("#") {
    match nearest_package_scope(from_dir, cache) {
      Some((scope_dir, pkg)) =>
        match pkg.imports {
          Some(imports) =>
            match lookup_exports(imports, specifier, conditions) {
              Found(target) =>
                if target.has_prefix("./") {
                  match load_exports_target(scope_dir, target) {
                    Some((path, typed)) =>
                      if typed {
                        return done(Resolved(path))
                      } else {
                        untyped.push(path)
                      }
                    None => ()
                  }
                } else {
                  // imports may remap to another package
                  return done(
                    resolve_import_node16(
                      target, from_file, importer_format, cache,
                    ),
                  )
                }
              NoMatch => ()
            }
          None => ()
        }
      None => ()
    }
    if untyped.length() > 0 {
      return done(Resolved(untyped[0]))
    }
    return done(NotFound)
  }
  let (package_name, subpath_opt) = parse_package_specifier(specifier)
  let subpath = match subpath_opt {
    Some(sub) => "./" + sub
    None => "."
  }

  // Package self-name resolution: nearest package.json whose "name"
  // matches and which has an exports map
  match nearest_package_scope(from_dir, cache) {
    Some((scope_dir, pkg)) =>
      if pkg.name == Some(package_name) && pkg.exports is Some(exports) {
        match lookup_exports(exports, subpath, conditions) {
          Found(target) =>
            match load_exports_target(scope_dir, target) {
              Some((path, _)) => return done(Resolved(path))
              None => return done(NotFound)
            }
          NoMatch => return done(NotFound) // blocked by omission
        }
      }
    None => ()
  }

  // node_modules walk-up: the package itself, then its @types counterpart
  let types_package = "@types/" + mangle_scoped_name(package_name)
  let mut current_dir = from_dir
  let mut found_package_dir : String? = None
  while current_dir.length() > 0 {
    let node_modules_path = join_path(current_dir, "node_modules")
    for candidate_name in [package_name, types_package] {
      let package_path = join_path(node_modules_path, candidate_name)
      if is_directory(package_path) {
        if candidate_name == package_name && found_package_dir is None {
          found_package_dir = Some(package_path)
        }
        match
          resolve_package_dir_node16(
            package_path, subpath, conditions, cache, untyped,
          ) {
          Some(path) => return done(Resolved(path))
          None => ()
        }
      }
    }
    let parent = dirname(current_dir)
    if parent == current_dir {
      break
    }
    current_dir = parent
  }
  if untyped.length() > 0 {
    return done(Resolved(untyped[0]))
  }
  match found_package_dir {
    Some(dir) => done(NoTypes(dir))
    None => done(NotFound)
  }
}

// ============================================================================
// Triple-slash <reference types="..." resolution-mode="..."> loading
// ============================================================================

///|
/// Extract an attribute value (attr="value") from a directive line
fn extract_directive_attribute(line : String, attr : String) -> String? {
  let needle = attr + "=\""
  let mut idx = -1
  let n = needle.length()
  for i = 0; i + n <= line.length(); i = i + 1 {
    let mut matches = true
    for j = 0; j < n; j = j + 1 {
      if line[i + j] != needle[j] {
        matches = false
        break
      }
    }
    if matches {
      // attribute name must not be preceded by a letter or '-' (so "lib"
      // doesn't match inside "no-default-lib", or "mode" inside
      // "resolution-mode")
      if i > 0 {
        let prev = line[i - 1]
        let is_word = (prev >= 'a' && prev <= 'z') ||
          (prev >= 'A' && prev <= 'Z') ||
          prev == '-'
        if is_word {
          continue
        }
      }
      idx = i
      break
    }
  }
  if idx == -1 {
    return None
  }
  let start = idx + n
  for k = start; k < line.length(); k = k + 1 {
    if line[k] == '"' {
      return Some(line[start:k].to_owned())
    }
  }
  None
}

///|
/// Scan a source file's leading comment lines for
/// `/// <reference types="X" resolution-mode="Y"? />` directives.
/// Returns (types_name, resolution_mode?) pairs.
pub fn scan_types_references(source : String) -> Array[(String, String?)] {
  let result : Array[(String, String?)] = []
  for raw_line in source.split("\n") {
    let line = raw_line.to_owned()
    // trim leading whitespace
    let mut start = 0
    while start < line.length() &&
          (line[start] == ' ' || line[start] == '\t' || line[start] == '\r') {
      start = start + 1
    }
    let trimmed = line[start:].to_owned()
    if trimmed.is_empty() {
      continue
    }
    if trimmed.has_prefix("///") {
      let content = trimmed[3:].to_owned()
      if content.contains("<reference") {
        match extract_directive_attribute(content, "types") {
          Some(name) => {
            let mode = extract_directive_attribute(content, "resolution-mode")
            result.push((name, mode))
          }
          None => ()
        }
      }
      continue
    }
    if trimmed.has_prefix("//") {
      continue // other comments/directives may precede references
    }
    break // first real code line ends the directive prologue
  }
  result
}

///|
/// Resolve `/// <reference types=... />` directives across a file set using
/// node16 resolution (the resolution-mode attribute selects the
/// "import"/"require" condition; default is the referencing file's own
/// format). Returns newly loaded (path, source) pairs not already in the
/// file set.
pub async fn load_node16_types_references(
  files : Array[(String, String)],
  cache : Node16Cache,
) -> Array[(String, String)] raise Error {
  let existing : Map[String, Bool] = Map([])
  for f in files {
    existing.set(f.0, true)
  }
  let loaded : Array[(String, String)] = []
  for f in files {
    let (path, source) = f
    for entry in scan_types_references(source) {
      let (name, mode) = entry
      let format = match mode {
        Some("import") => @compiler.ModuleFormat::esm()
        Some("require") => @compiler.ModuleFormat::cjs()
        _ => classify_module_format_fs(path, cache)
      }
      match resolve_import_node16(name, path, format, cache) {
        Resolved(resolved_path) =>
          if existing.get(resolved_path) is None {
            existing.set(resolved_path, true)
            if is_regular_file(resolved_path) {
              let data = @fs.read_file(resolved_path)
              loaded.push((resolved_path, data.text()))
            }
          }
        NoTypes(_) | NotFound => ()
      }
    }
  }
  loaded
}
