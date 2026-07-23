// Baseline Generator for E2E Tests
// Generates baseline output from compilation results

///|
/// Compilation result for a single file
pub(all) struct FileCompileResult {
  filename : String
  source : String
  javascript : String
  declaration : String?
  source_map : String?
  diagnostics : Array[@compiler.Diagnostic]
} derive(Debug)

///|
/// Generate JavaScript baseline from compilation results
/// Format: //// [source.ts] ////\n<source>\n//// [output.js] ////\n<js>
pub fn generate_js_baseline(
  source_files : Array[SourceUnit],
  results : Array[FileCompileResult],
) -> String {
  let sb = StringBuilder::new()

  // First, output all source files
  for source in source_files {
    sb.write_string("//// [")
    sb.write_string(source.filename)
    sb.write_string("] ////\n")
    sb.write_string(source.content)
    if !(source.content.has_suffix("\n")) {
      sb.write_char('\n')
    }
  }

  // Then, output all compiled JavaScript files
  for result in results {
    let js_filename = to_js_filename(result.filename)
    sb.write_string("//// [")
    sb.write_string(js_filename)
    sb.write_string("] ////\n")
    sb.write_string(result.javascript)
    if !(result.javascript.has_suffix("\n")) {
      sb.write_char('\n')
    }
  }
  sb.to_string()
}

///|
/// Generate declaration (.d.ts) baseline from compilation results
pub fn generate_dts_baseline(
  source_files : Array[SourceUnit],
  results : Array[FileCompileResult],
) -> String? {
  // Check if any results have declarations
  let has_declarations = results
    .iter()
    .any(fn(r) {
      match r.declaration {
        Some(_) => true
        None => false
      }
    })
  if !(has_declarations) {
    return None
  }
  let sb = StringBuilder::new()

  // First, output all source files
  for source in source_files {
    sb.write_string("//// [")
    sb.write_string(source.filename)
    sb.write_string("] ////\n")
    sb.write_string(source.content)
    if !(source.content.has_suffix("\n")) {
      sb.write_char('\n')
    }
  }

  // Then, output all declaration files
  for result in results {
    match result.declaration {
      Some(dts) => {
        let dts_filename = to_dts_filename(result.filename)
        sb.write_string("//// [")
        sb.write_string(dts_filename)
        sb.write_string("] ////\n")
        sb.write_string(dts)
        if !(dts.has_suffix("\n")) {
          sb.write_char('\n')
        }
      }
      None => ()
    }
  }
  Some(sb.to_string())
}

///|
/// Generate errors baseline from diagnostics
/// Format: file.ts(line,col): error TSxxxx: message
pub fn generate_errors_baseline(results : Array[FileCompileResult]) -> String? {
  // Collect all diagnostics
  let all_diagnostics : Array[@compiler.Diagnostic] = []
  for result in results {
    for diag in result.diagnostics {
      all_diagnostics.push(diag)
    }
  }
  if all_diagnostics.length() == 0 {
    return None
  }
  let sb = StringBuilder::new()

  // Output each diagnostic
  for diag in all_diagnostics {
    let loc = diag.location
    sb.write_string(loc.file_path)
    sb.write_char('(')
    sb.write_string(loc.start.line.to_string())
    sb.write_char(',')
    sb.write_string(loc.start.column.to_string())
    sb.write_string("): error TS")
    sb.write_string(diag.code.to_string())
    sb.write_string(": ")
    sb.write_string(diag.message)
    sb.write_char('\n')
  }
  Some(sb.to_string())
}

///|
/// Convert source filename to JavaScript filename
fn to_js_filename(filename : String) -> String {
  if filename.has_suffix(".ts") {
    filename[:filename.length() - 3].to_owned() + ".js"
  } else if filename.has_suffix(".tsx") {
    filename[:filename.length() - 4].to_owned() + ".js"
  } else {
    filename + ".js"
  }
}

///|
/// Convert source filename to declaration filename
fn to_dts_filename(filename : String) -> String {
  if filename.has_suffix(".ts") {
    filename[:filename.length() - 3].to_owned() + ".d.ts"
  } else if filename.has_suffix(".tsx") {
    filename[:filename.length() - 4].to_owned() + ".d.ts"
  } else {
    filename + ".d.ts"
  }
}

///|
/// Generate all baselines from compilation results
pub fn generate_all_baselines(
  source_files : Array[SourceUnit],
  results : Array[FileCompileResult],
) -> Baselines {
  let js = generate_js_baseline(source_files, results)
  let dts = generate_dts_baseline(source_files, results)
  let errors = generate_errors_baseline(results)

  // Note: .types and .symbols baselines require additional type checker info
  // which we'll implement later
  {
    js: Some(js),
    types: None, // TODO: Implement when type checker exposes this info
    symbols: None, // TODO: Implement when binder exposes this info
    errors,
    dts,
    js_map: None,
  } // TODO: Collect source maps if enabled
}

// Tests

///|
test "to_js_filename" {
  assert_eq(to_js_filename("test.ts"), "test.js")
  assert_eq(to_js_filename("test.tsx"), "test.js")
}

///|
test "to_dts_filename" {
  assert_eq(to_dts_filename("test.ts"), "test.d.ts")
  assert_eq(to_dts_filename("test.tsx"), "test.d.ts")
}

///|
test "generate js baseline" {
  let sources : Array[SourceUnit] = [
    { filename: "test.ts", content: "export const x = 1;" },
  ]
  let results : Array[FileCompileResult] = [
    {
      filename: "test.ts",
      source: "export const x = 1;",
      javascript: "export const x = 1;",
      declaration: None,
      source_map: None,
      diagnostics: [],
    },
  ]
  let baseline = generate_js_baseline(sources, results)
  assert_true(baseline.contains("//// [test.ts] ////"))
  assert_true(baseline.contains("//// [test.js] ////"))
}
