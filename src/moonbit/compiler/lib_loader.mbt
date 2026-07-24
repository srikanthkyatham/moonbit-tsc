// Standard-library loading (F1).
//
// Replaces the hardcoded `is_known_lib_type_name` whitelist with real lib.d.ts
// loading. The JavaScript-only standard libraries from the TypeScript
// repository (lib.es5.d.ts .. lib.esnext.d.ts and their by-feature files) are
// embedded as generated MoonBit string data (see lib_sources_gen.mbt, produced
// by tools/gen_embedded_libs.py). DOM / WebWorker / scripthost libs are NOT
// embedded (they are very large); for those names the checker keeps the old
// whitelist as a fallback.
//
// Design notes:
// - Sources are embedded (not read from disk) so the compiler stays a single
//   self-contained binary and `moon test` needs no external files.
// - Parsing is LAZY: a lib file is only scanned/parsed the first time a name
//   actually has to be looked up (i.e. after user-scope resolution failed).
//   Successful compilations therefore pay zero lib-parsing cost. Parsed
//   results are cached per lib file for the lifetime of the process.
// - Lib inheritance is not hardcoded: the `/// <reference lib="..." />`
//   directives inside the embedded sources are followed transitively,
//   mirroring tsc's own lib graph (src/lib/libs.json).

///|
/// The standard-library selection for a compilation: which lib files are
/// available for global name resolution.
pub(all) struct LibContext {
  libs : Array[String] // lib names as written (e.g. ["es2015"]); expanded lazily
  no_lib : Bool // --noLib / @noLib: no standard library at all
} derive(Debug)

///|
/// Lib selection derived from an ECMAScript target version (tsc's default
/// when no --lib is given).
pub fn LibContext::for_target(target : Target) -> LibContext {
  { libs: [default_lib_name_for_target(target)], no_lib: false }
}

///|
/// Explicit lib list (from --lib or an @lib test directive). Entries are
/// normalized to lower case; the "lib.xxx.d.ts" spelling is accepted too.
pub fn LibContext::from_libs(libs : Array[String]) -> LibContext {
  let normalized : Array[String] = []
  for l in libs {
    let name = normalize_lib_name(l)
    if name.length() > 0 {
      normalized.push(name)
    }
  }
  { libs: normalized, no_lib: false }
}

///|
/// No standard library at all (--noLib / @noLib: true).
pub fn LibContext::without_lib() -> LibContext {
  { libs: [], no_lib: true }
}

///|
/// Substring [start, end) of a string (character indices).
fn lib_substring(s : String, start : Int, end : Int) -> String {
  let chars = s.to_array()
  let sb = StringBuilder::new()
  let mut i = start
  while i < end && i < chars.length() {
    sb.write_char(chars[i])
    i = i + 1
  }
  sb.to_string()
}

///|
/// Normalize a lib name: lower-case, strip an optional "lib." prefix and
/// ".d.ts" suffix, so "lib.ES2015.Promise.d.ts" -> "es2015.promise".
fn normalize_lib_name(name : String) -> String {
  let mut n = name.to_lower()
  if n.has_prefix("lib.") {
    n = lib_substring(n, 4, n.length())
  }
  if n.has_suffix(".d.ts") {
    n = lib_substring(n, 0, n.length() - 5)
  }
  // "es6"/"es7" aliases used by tests and tsconfig
  match n {
    "es6" => "es2015"
    "es7" => "es2016"
    _ => n
  }
}

///|
/// Default lib file for a Target enum value (mirrors tsc's target->lib table;
/// the ".full" indirection is skipped because dom is not embedded).
pub fn default_lib_name_for_target(target : Target) -> String {
  match target {
    Target::ES5 => "es5"
    Target::ES2015 => "es2015"
    Target::ES2016 => "es2016"
    Target::ES2017 => "es2017"
    Target::ES2018 => "es2018"
    Target::ES2019 => "es2019"
    Target::ES2020 => "es2020"
    Target::ESNext => "esnext"
  }
}

///|
/// Default lib file for a raw --target string. Unlike `parse_target` (whose
/// Target enum stops at ES2020/ESNext), this maps the es2021..es2025 targets
/// to their real lib chains. No target at all means tsc's LatestStandard
/// (currently es2025).
pub fn default_lib_name_for_target_string(target : String?) -> String {
  match target {
    None => "es2025" // tsc default target is ScriptTarget.LatestStandard
    Some(t) =>
      match t.to_lower() {
        "es5" | "es3" => "es5"
        "es2015" | "es6" => "es2015"
        "es2016" | "es7" => "es2016"
        "es2017" => "es2017"
        "es2018" => "es2018"
        "es2019" => "es2019"
        "es2020" => "es2020"
        "es2021" => "es2021"
        "es2022" => "es2022"
        "es2023" => "es2023"
        "es2024" => "es2024"
        "es2025" => "es2025"
        "esnext" | "latest" => "esnext"
        // Mirror parse_target's fallback (unknown target behaves as es2015)
        _ => "es2015"
      }
  }
}

// ============================================================================
// Process-wide default selection (set once by the CLI from --target/--lib)
// ============================================================================

///|
/// Selection the CLI derived from its flags. When set, it is used whenever a
/// file has no @lib/@noLib directive of its own. When unset (unit tests,
/// library use), the checker derives the selection from its Target.
let default_lib_selection : Ref[LibContext?] = { val: None }

///|
pub fn set_default_lib_selection(ctx : LibContext?) -> Unit {
  default_lib_selection.val = ctx
}

///|
/// The lib context a checker should use when none was passed explicitly:
/// the CLI-configured selection if any, else the target's default libs.
pub fn resolve_default_lib_context(target : Target) -> LibContext {
  match default_lib_selection.val {
    Some(ctx) => ctx
    None => LibContext::for_target(target)
  }
}

// ============================================================================
// Lib expansion (follow /// <reference lib="..." /> directives)
// ============================================================================

///|
/// Extract the referenced lib names from a lib file's source text by scanning
/// for `<reference lib="..."` markers.
fn lib_references_in_source(source : String) -> Array[String] {
  let refs : Array[String] = []
  let chars = source.to_array()
  let marker = "<reference lib=\"".to_array()
  let mut i = 0
  while i <= chars.length() - marker.length() {
    let mut matches = true
    for j in 0..<marker.length() {
      if chars[i + j] != marker[j] {
        matches = false
        break
      }
    }
    if matches {
      let start = i + marker.length()
      let sb = StringBuilder::new()
      let mut k = start
      while k < chars.length() && chars[k] != '"' {
        sb.write_char(chars[k])
        k = k + 1
      }
      refs.push(sb.to_string())
      i = k
    }
    i = i + 1
  }
  refs
}

///|
/// Expand a lib selection to the transitive closure over the reference
/// directives of the embedded sources. Unknown libs (dom, webworker, ...)
/// are silently dropped — the whitelist fallback covers them.
pub fn expand_lib_selection(libs : Array[String]) -> Array[String] {
  let seen : @hashset.HashSet[String] = @hashset.HashSet([])
  let result : Array[String] = []
  let work : Array[String] = []
  for l in libs {
    work.push(normalize_lib_name(l))
  }
  while work.length() > 0 {
    let lib = match work.pop() {
      Some(l) => l
      None => break
    }
    if seen.contains(lib) {
      continue
    }
    seen.add(lib)
    match embedded_lib_source(lib) {
      Some(source) => {
        result.push(lib)
        for r in lib_references_in_source(source) {
          work.push(normalize_lib_name(r))
        }
      }
      None => () // not embedded (dom etc.) - whitelist fallback handles it
    }
  }
  result
}

// ============================================================================
// Global-name collection (parse lib files with the existing parser)
// ============================================================================

///|
/// The global names declared by one or more lib files, split by meaning.
priv struct LibGlobalNames {
  type_names : @hashset.HashSet[String] // interfaces, type aliases, classes, enums
  value_names : @hashset.HashSet[String] // vars, functions, classes, enums, namespaces
}

///|
fn LibGlobalNames::new() -> LibGlobalNames {
  { type_names: @hashset.HashSet([]), value_names: @hashset.HashSet([]) }
}

///|
/// Cache of parsed per-lib-file name sets (process lifetime).
let per_lib_names_cache : Map[String, LibGlobalNames] = Map([])

///|
/// Collect the global type/value names declared at the top level of a single
/// lib file, using the existing scanner + parser. Results are cached.
fn global_names_of_lib(lib : String) -> LibGlobalNames? {
  match per_lib_names_cache.get(lib) {
    Some(names) => Some(names)
    None =>
      match embedded_lib_source(lib) {
        None => None
        Some(source) => {
          let names = LibGlobalNames::new()
          let file_name = "lib." + lib + ".d.ts"
          let tokens = scan_all_v2(source, file_name)
          match parse_source_file(tokens, file_name) {
            Ok(source_file) =>
              collect_global_names_from_statements(source_file.statements, names)
            Err(_) => () // unparseable lib: fall back to the whitelist
          }
          // The parser still has gaps on a few lib.d.ts constructs (numeric
          // interface members, `x is T` predicates in function-type
          // parameters, `abstract new` constructor types); error recovery can
          // drop whole declarations after such a member. Supplement the AST
          // walk with a line-based scan: the lib files declare every global
          // at column 0, so this recovers exactly the missing names. Remove
          // once the parser handles all lib constructs.
          collect_global_names_from_text(source, names)
          per_lib_names_cache.set(lib, names)
          Some(names)
        }
      }
  }
}

///|
/// Walk the top-level statements of a lib .d.ts file and record every
/// declared global name. Only declaration statements can introduce globals;
/// parser error-recovery junk (expression statements etc.) is ignored.
fn collect_global_names_from_statements(
  statements : Array[Node],
  names : LibGlobalNames,
) -> Unit {
  for stmt in statements {
    match stmt {
      InterfaceDeclaration(iface) => names.type_names.add(iface.name)
      TypeAliasDeclaration(type_alias) => names.type_names.add(type_alias.name)
      ClassDeclaration(class_decl) =>
        match class_decl.name {
          Some(Identifier(id)) => {
            names.type_names.add(id.name)
            names.value_names.add(id.name)
          }
          _ => ()
        }
      EnumDeclaration(enum_decl) => {
        names.type_names.add(enum_decl.name)
        names.value_names.add(enum_decl.name)
      }
      ModuleDeclaration(mod_decl) => {
        // e.g. `declare namespace Intl { ... }`: usable as a value and in
        // qualified type names (Intl.NumberFormat)
        names.type_names.add(mod_decl.name)
        names.value_names.add(mod_decl.name)
      }
      FunctionDeclaration(func) =>
        match func.name {
          Some(Identifier(id)) => names.value_names.add(id.name)
          _ => ()
        }
      VariableStatement(vs) =>
        for decl in vs.declarations {
          match decl.name {
            Identifier(id) => names.value_names.add(id.name)
            _ => ()
          }
        }
      _ => ()
    }
  }
}

///|
/// The characters that can end a declared name in a lib file header line.
fn is_lib_name_end_char(c : Char) -> Bool {
  c == '<' || c == ' ' || c == '{' || c == '(' || c == ':' || c == ';' ||
  c == '=' || c == '\t' || c == '\r'
}

///|
/// Read the identifier that follows `prefix` on `line` (or None if the line
/// does not start with the prefix).
fn lib_decl_name_after(line : Array[Char], prefix : String) -> String? {
  let p = prefix.to_array()
  if line.length() <= p.length() {
    return None
  }
  for j in 0..<p.length() {
    if line[j] != p[j] {
      return None
    }
  }
  let sb = StringBuilder::new()
  let mut i = p.length()
  while i < line.length() && !is_lib_name_end_char(line[i]) {
    sb.write_char(line[i])
    i = i + 1
  }
  let name = sb.to_string()
  if name.length() > 0 {
    Some(name)
  } else {
    None
  }
}

///|
/// Line-based fallback collection of top-level lib declarations. The
/// TypeScript lib sources declare every global at column 0 with one of a
/// handful of prefixes, so this is precise even where the parser's error
/// recovery drops declarations.
fn collect_global_names_from_text(
  source : String,
  names : LibGlobalNames,
) -> Unit {
  let type_prefixes = ["interface ", "type ", "declare type "]
  let value_prefixes = [
    "declare var ", "declare let ", "declare const ", "declare function ",
  ]
  let both_prefixes = ["declare namespace ", "declare class ", "declare enum "]
  let line : Array[Char] = []
  let chars = source.to_array()
  let mut idx = 0
  while idx <= chars.length() {
    if idx == chars.length() || chars[idx] == '\n' {
      for prefix in type_prefixes {
        match lib_decl_name_after(line, prefix) {
          Some(name) => names.type_names.add(name)
          None => ()
        }
      }
      for prefix in value_prefixes {
        match lib_decl_name_after(line, prefix) {
          Some(name) => names.value_names.add(name)
          None => ()
        }
      }
      for prefix in both_prefixes {
        match lib_decl_name_after(line, prefix) {
          Some(name) => {
            names.type_names.add(name)
            names.value_names.add(name)
          }
          None => ()
        }
      }
      line.clear()
    } else {
      line.push(chars[idx])
    }
    idx = idx + 1
  }
}

///|
/// Cache of expanded+unioned name sets per lib selection.
let selection_names_cache : Map[String, LibGlobalNames] = Map([])

///|
fn selection_cache_key(libs : Array[String]) -> String {
  let sorted = libs.copy()
  sorted.sort()
  let sb = StringBuilder::new()
  for l in sorted {
    sb.write_string(l)
    sb.write_char(',')
  }
  sb.to_string()
}

///|
/// The union of global names declared by a lib selection (after expansion).
fn global_names_of_selection(libs : Array[String]) -> LibGlobalNames {
  let key = selection_cache_key(libs)
  match selection_names_cache.get(key) {
    Some(names) => names
    None => {
      let union = LibGlobalNames::new()
      for lib in expand_lib_selection(libs) {
        match global_names_of_lib(lib) {
          Some(names) => {
            for n in names.type_names.iter() {
              union.type_names.add(n)
            }
            for n in names.value_names.iter() {
              union.value_names.add(n)
            }
          }
          None => ()
        }
      }
      selection_names_cache.set(key, union)
      union
    }
  }
}

///|
/// Does the selected standard library declare `name` as a TYPE (interface,
/// type alias, class, enum, namespace)?
pub fn lib_has_type_name(ctx : LibContext, name : String) -> Bool {
  if ctx.no_lib {
    return false
  }
  global_names_of_selection(ctx.libs).type_names.contains(name)
}

///|
/// Does the selected standard library declare `name` as a VALUE (var,
/// function, class, enum, namespace)?
pub fn lib_has_value_name(ctx : LibContext, name : String) -> Bool {
  if ctx.no_lib {
    return false
  }
  global_names_of_selection(ctx.libs).value_names.contains(name)
}

///|
/// Cheap syntactic check: does the selection include a full es2015-or-later
/// major lib? Lets hot paths skip lib parsing entirely for the common
/// targets (the ES2015 collection/symbol/promise globals are all present
/// from es2015 on).
pub fn lib_selection_is_es2015_plus(ctx : LibContext) -> Bool {
  if ctx.no_lib {
    return false
  }
  for l in ctx.libs {
    match normalize_lib_name(l) {
      "es2015"
      | "es2016"
      | "es2017"
      | "es2018"
      | "es2019"
      | "es2020"
      | "es2021"
      | "es2022"
      | "es2023"
      | "es2024"
      | "es2025"
      | "esnext" => return true
      _ => ()
    }
  }
  false
}

// ============================================================================
// The full embedded universe (for "change your lib" suggestions)
// ============================================================================

///|
/// All embedded libs as one selection ("what any ES lib could provide").
fn universe_names() -> LibGlobalNames {
  global_names_of_selection(embedded_lib_names())
}

///|
/// Is `name` a TYPE in some embedded (JS-only) standard lib?
pub fn lib_universe_has_type_name(name : String) -> Bool {
  universe_names().type_names.contains(name)
}

///|
/// Is `name` a VALUE in some embedded (JS-only) standard lib?
pub fn lib_universe_has_value_name(name : String) -> Bool {
  universe_names().value_names.contains(name)
}

///|
/// Major lib versions in ascending order, used to find the earliest lib
/// providing a name (for the "'es2015' or later" part of TS2583/TS2585).
fn lib_major_versions() -> Array[String] {
  [
    "es5", "es2015", "es2016", "es2017", "es2018", "es2019", "es2020", "es2021",
    "es2022", "es2023", "es2024", "es2025", "esnext",
  ]
}

///|
/// Earliest major lib version whose chain declares `name` (as value when
/// `as_value` is true, as type otherwise), e.g. "es2015" for Promise.
pub fn earliest_lib_version_for_name(name : String, as_value : Bool) -> String? {
  for major in lib_major_versions() {
    let names = global_names_of_selection([major])
    let found = if as_value {
      names.value_names.contains(name)
    } else {
      names.type_names.contains(name)
    }
    if found {
      return Some(major)
    }
  }
  None
}

///|
/// The names for which tsc suggests changing the target library (TS2583)
/// instead of a plain TS2304. Mirrors getCannotFindNameDiagnosticForName in
/// typescript's checker.ts.
pub fn is_lib_change_suggestion_name(name : String) -> Bool {
  match name {
    "Map"
    | "Set"
    | "Promise"
    | "Symbol"
    | "WeakMap"
    | "WeakSet"
    | "Iterator"
    | "AsyncIterator"
    | "SharedArrayBuffer"
    | "Atomics"
    | "AsyncIterable"
    | "AsyncIterableIterator"
    | "AsyncGenerator"
    | "AsyncGeneratorFunction"
    | "BigInt"
    | "Reflect"
    | "BigInt64Array"
    | "BigUint64Array" => true
    _ => false
  }
}

///|
/// The global types tsc requires at checker startup; each missing one gets a
/// TS2318 "Cannot find global type" when compiling with noLib.
pub fn fundamental_global_type_names() -> Array[String] {
  [
    "Array", "Boolean", "CallableFunction", "Function", "IArguments",
    "NewableFunction", "Number", "Object", "RegExp", "String",
  ]
}
