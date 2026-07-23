// Cross-file import validation for multi-file compilations.
//
// When several files are compiled together, relative imports between them
// are resolved against the compiled file set (with .ts/.tsx/.d.ts extension
// and directory-index resolution) and the imported members are validated
// against the target module's exports. Imports that resolve to nothing in
// the file set are checked against the real filesystem before TS2307 is
// reported, so on-disk untyped targets (.js, .json) don't raise errors.

///|
/// Validate relative imports across the compiled file set and append the
/// resulting diagnostics (TS2305/TS2306/TS2724/TS1192, plus TS2307 for
/// imports that don't exist on the real filesystem either) to the matching
/// per-file results.
async fn apply_cross_file_import_diagnostics(
  summary : @coordinator.CompilationSummary,
  files : Array[(String, String)],
) -> @coordinator.CompilationSummary {
  let validation = @compiler.validate_multi_file_imports(files)

  // Group the extra diagnostics by originating file
  let extra : Map[String, Array[String]] = Map([])
  fn add_diag(d : @compiler.Diagnostic) -> Unit {
    let formatted = @compiler.format_diagnostic_for_output(d)
    match extra.get(d.location.file_path) {
      Some(list) => list.push(formatted)
      None => extra.set(d.location.file_path, [formatted])
    }
  }

  for d in validation.diagnostics {
    add_diag(d)
  }

  // Unresolved relative imports: report TS2307 only when none of the
  // searched candidate paths exists on the real filesystem
  for u in validation.unresolved {
    let mut exists_on_disk = false
    for c in u.candidates {
      if @fs.exists(c) {
        exists_on_disk = true
        break
      }
    }
    if !(exists_on_disk) {
      add_diag(
        @compiler.create_module_not_found_diagnostic_with_location(
          u.specifier, u.location,
        ),
      )
    }
  }
  if extra.is_empty() {
    return summary
  }

  // Rebuild the results with the appended diagnostics
  let results : Array[@protocol.CompileResponse] = []
  for r in summary.results {
    match extra.get(r.file_path) {
      Some(diags) => {
        let combined = r.diagnostics.copy()
        for d in diags {
          combined.push(d)
        }
        results.push({ ..r, diagnostics: combined })
      }
      None => results.push(r)
    }
  }
  { ..summary, results, }
}
