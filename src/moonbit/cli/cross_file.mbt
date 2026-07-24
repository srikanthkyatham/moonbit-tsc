// Cross-file import validation for multi-file compilations.
//
// When several files are compiled together, relative imports between them
// are resolved against the compiled file set (with .ts/.tsx/.d.ts extension
// and directory-index resolution) and the imported members are validated
// against the target module's exports. Imports that resolve to nothing in
// the file set are checked against the real filesystem before TS2307 is
// reported, so on-disk untyped targets (.js, .json) don't raise errors.
//
// Non-relative (bare) specifiers get node10-style resolution: ambient
// `declare module "..."` declarations in any compiled file, node_modules
// lookup within the compiled file set, then real-filesystem node_modules
// resolution (package.json types/typings/main, index files, @types with
// scoped-name mangling). The per-file checker emits an unconditional TS2307
// for bare specifiers, so resolutions found here suppress that diagnostic;
// resolutions landing on untyped .js files produce TS7016 under
// noImplicitAny instead.

///|
/// Check whether a resolved file provides no type information.
/// (.json is excluded: JSON imports get their own diagnostics
/// (TS2732/TS2823), never TS7016.)
fn is_untyped_resolution(path : String) -> Bool {
  path.has_suffix(".js") ||
  path.has_suffix(".jsx") ||
  path.has_suffix(".mjs") ||
  path.has_suffix(".cjs")
}

///|
/// Check whether a formatted diagnostic line is the checker's TS2304
/// ("Cannot find name") for a name declared in another compiled file's
/// `declare global { ... }` block
fn is_cross_file_global_name_diag(
  diag : String,
  global_names : Array[String],
) -> Bool {
  if !(diag.contains("TS2304")) {
    return false
  }
  for name in global_names {
    if diag.contains("'" + name + "'") {
      return true
    }
  }
  false
}

///|
/// Check whether a path is inside a node_modules directory
fn in_node_modules(path : String) -> Bool {
  path.contains("/node_modules/") || path.has_prefix("node_modules/")
}

///|
/// Check whether a formatted diagnostic line is the checker's TS2307 for one
/// of the given module specifiers
fn is_suppressed_module_not_found(
  diag : String,
  specifiers : Array[String],
) -> Bool {
  if !(diag.contains("TS2307")) {
    return false
  }
  for spec in specifiers {
    if diag.contains("'" + spec + "'") {
      return true
    }
  }
  false
}

///|
/// Validate imports across the compiled file set and append/remove the
/// resulting diagnostics on the matching per-file results:
/// - TS2305/TS2306/TS2724/TS1192 for member mismatches
/// - TS2307 for imports that exist neither in the file set nor on disk
/// - TS7016 for imports resolving to untyped .js under noImplicitAny
/// - suppression of the checker's unconditional bare-specifier TS2307 when
///   the specifier resolves (file set, ambient module, or node_modules)
async fn apply_cross_file_import_diagnostics(
  summary : @coordinator.CompilationSummary,
  files : Array[(String, String)],
  module_kind? : @compiler.ModuleKind = @compiler.ESModule,
) -> @coordinator.CompilationSummary {
  let node16 = @compiler.is_node_module_kind(module_kind)
  // node20/nodenext assume Node.js supports require() of ES modules: the
  // TS1479/TS1471 interop errors only apply to node16/node18
  let require_esm_errors = module_kind == @compiler.Node16
  // Under node16/nodenext, classify every compiled file as ESM or CJS
  // (extension, then nearest package.json "type" field) — this drives the
  // ESM extension rules and TS1479/TS1471 in the validator
  let node16_cache = @coordinator.Node16Cache::new()
  let file_formats : Map[String, @compiler.ModuleFormat] = Map([])
  if node16 {
    for f in files {
      file_formats.set(
        f.0,
        @coordinator.classify_module_format_fs(f.0, node16_cache),
      )
    }
  }
  let validation = @compiler.validate_multi_file_imports(
    files,
    node16=node16,
    cjs_require_esm_errors=require_esm_errors,
    file_formats=file_formats,
  )

  // Group the extra diagnostics by originating file
  let extra : Map[String, Array[String]] = Map([])
  fn add_diag(d : @compiler.Diagnostic) -> Unit {
    let formatted = @compiler.format_diagnostic_for_output(d)
    match extra.get(d.location.file_path) {
      Some(list) => list.push(formatted)
      None => extra.set(d.location.file_path, [formatted])
    }
  }

  // Checker-emitted TS2307s to remove, keyed by file path
  let suppress : Map[String, Array[String]] = Map([])
  fn add_suppression(file_path : String, specifier : String) -> Unit {
    match suppress.get(file_path) {
      Some(list) => list.push(specifier)
      None => suppress.set(file_path, [specifier])
    }
  }

  for d in validation.diagnostics {
    add_diag(d)
  }

  // Unresolved relative imports: check the searched candidate paths against
  // the real filesystem. A candidate that exists but is untyped (.js) is
  // TS7016 under noImplicitAny; no candidate on disk at all is TS2307.
  for u in validation.unresolved {
    let mut on_disk : String? = None
    for c in u.candidates {
      if @fs.exists(c) {
        on_disk = Some(c)
        break
      }
    }
    match on_disk {
      Some(found) =>
        if u.no_implicit_any && is_untyped_resolution(found) {
          add_diag(
            @compiler.create_untyped_module_diagnostic_with_location(u.specifier, found, u.location),
          )
        }
      None => add_diag(
        @compiler.create_module_not_found_diagnostic_with_location(
          u.specifier, u.location,
        ),
      )
    }
  }

  // Bare specifiers resolved within the file set or via an ambient module
  // declaration: suppress the checker's unconditional TS2307
  for r in validation.resolved_bare {
    add_suppression(r.file_path, r.specifier)
    match r.resolved_path {
      Some(path) =>
        if r.no_implicit_any && is_untyped_resolution(path) {
          add_diag(
            @compiler.create_untyped_module_diagnostic_with_location(r.specifier, path, r.location),
          )
        }
      None => () // ambient module: typed by declaration
    }
  }

  // Bare specifiers unresolved in the file set: try real-filesystem
  // node_modules resolution. node10: package.json types/main, index files,
  // @types. node16: exports/imports maps, self-name resolution, and
  // ESM/CJS-compatibility errors (TS1479/TS1471) on the resolved target.
  let fs_cache = @coordinator.ModuleResolutionCache::new()
  let node16_resolved_paths : Array[String] = []
  for u in validation.unresolved_bare {
    if !(@coordinator.is_bare_specifier(u.specifier)) {
      continue // rooted/URL specifiers: leave the checker's TS2307 in place
    }
    let resolution = if node16 {
      let importer_format = if u.importer_esm {
        @compiler.ModuleFormat::esm()
      } else {
        @compiler.ModuleFormat::cjs()
      }
      // Node 16/18 reject "#/"-prefixed imports map specifiers entirely
      // (nodenext/node20 allow them)
      if require_esm_errors && u.specifier.has_prefix("#/") {
        @coordinator.ResolvedModule::NotFound
      } else {
        @coordinator.resolve_import_node16(
          u.specifier, u.file_path, importer_format, node16_cache,
        )
      }
    } else {
      @coordinator.resolve_bare_import(u.specifier, u.file_path, fs_cache)
    }
    match resolution {
      Resolved(path) => {
        node16_resolved_paths.push(path)
        add_suppression(u.file_path, u.specifier)
        if u.no_implicit_any && is_untyped_resolution(path) {
          add_diag(
            @compiler.create_untyped_module_diagnostic_with_location(u.specifier, path, u.location),
          )
        }
        // node16/node18: a CJS-format file may not `import`/require an ES
        // module (node20+ supports require() of ESM)
        if node16 && require_esm_errors && !(u.type_only) {
          let target_format = @coordinator.classify_module_format_fs(
            path, node16_cache,
          )
          if target_format == @compiler.ModuleFormat::esm() {
            if u.require_like {
              add_diag(
                @compiler.create_require_of_esm_diagnostic(u.specifier, u.location),
              )
            } else if !(u.importer_esm) {
              add_diag(
                @compiler.create_cjs_import_of_esm_diagnostic(u.specifier, u.location),
              )
            }
          }
        }
      }
      NoTypes(_) | NotFound =>
        // Genuinely unresolvable: the checker already reports TS2307 for
        // import declarations; add it for the forms it doesn't cover
        // (import =, export ... from)
        if !(u.checker_reports) {
          add_diag(
            @compiler.create_module_not_found_diagnostic_with_location(
              u.specifier, u.location,
            ),
          )
        }
    }
  }
  // Cross-file `declare global` names: a compiled file outside node_modules
  // always contributes its globals; a node_modules file contributes only
  // when something actually pulls it into the program (an import that
  // resolved to it, or a /// <reference types=.../> directive) — mirroring
  // how tsc only includes node_modules files reachable from root files.
  let reachable : Map[String, Bool] = Map([])
  for r in validation.resolved_bare {
    match r.resolved_path {
      Some(p) => reachable.set(p, true)
      None => ()
    }
  }
  for p in node16_resolved_paths {
    reachable.set(p, true)
  }
  if node16 {
    for f in files {
      for entry in @coordinator.scan_types_references(f.1) {
        let (name, mode) = entry
        let format = match mode {
          Some("import") => @compiler.ModuleFormat::esm()
          Some("require") => @compiler.ModuleFormat::cjs()
          _ =>
            match file_formats.get(f.0) {
              Some(fmt) => fmt
              None => @compiler.ModuleFormat::cjs()
            }
        }
        match
          @coordinator.resolve_import_node16(name, f.0, format, node16_cache) {
          Resolved(p) => reachable.set(p, true)
          NoTypes(_) | NotFound => ()
        }
      }
    }
  }
  let global_names : Array[String] = []
  for entry in validation.global_value_names {
    let (declaring_file, name) = entry
    if !(in_node_modules(declaring_file)) ||
      reachable.get(declaring_file) is Some(_) {
      global_names.push(name)
    }
  }
  if extra.is_empty() && suppress.is_empty() && global_names.is_empty() {
    return summary
  }

  // Rebuild the results with the appended/suppressed diagnostics
  let results : Array[@protocol.CompileResponse] = []
  let mut successful = 0
  let mut failed = 0
  for r in summary.results {
    let filtered = match suppress.get(r.file_path) {
      Some(specs) =>
        r.diagnostics.filter(fn(d) {
          !(is_suppressed_module_not_found(d, specs))
        })
      None => r.diagnostics
    }
    // Names declared in another compiled file's `declare global` block are
    // genuinely in scope: drop the per-file checker's TS2304 for them
    let filtered = if global_names.is_empty() {
      filtered
    } else {
      filtered.filter(fn(d) {
        !(is_cross_file_global_name_diag(d, global_names))
      })
    }
    let combined = match extra.get(r.file_path) {
      Some(diags) => {
        let list = filtered.copy()
        for d in diags {
          list.push(d)
        }
        list
      }
      None => filtered
    }
    let mut has_errors = false
    for d in combined {
      if is_error_diagnostic(d) {
        has_errors = true
        break
      }
    }
    // Appended cross-file errors flip success off; a result that only
    // failed because of now-suppressed diagnostics counts as successful
    let success = if has_errors {
      false
    } else if suppress.get(r.file_path) is Some(_) ||
      filtered.length() < r.diagnostics.length() {
      true
    } else {
      r.success
    }
    results.push({ ..r, diagnostics: combined, success })
    if success {
      successful = successful + 1
    } else {
      failed = failed + 1
    }
  }
  { ..summary, results, successful, failed }
}
