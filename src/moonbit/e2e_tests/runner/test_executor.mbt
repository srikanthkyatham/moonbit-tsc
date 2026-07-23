// Test Executor for E2E Tests
// Compiles test cases and compares against baselines

///|
/// Build CompileOptions from test directives and variant
pub fn build_compile_options(
  directives : TestDirectives,
  variant : TestVariant,
) -> @compiler.CompileOptions {
  // Parse target
  let target = @compiler.parse_target(variant.target)

  // Parse module kind
  let module_kind : @compiler.ModuleKind = if variant.module_kind == "commonjs" {
    @compiler.CommonJS
  } else {
    @compiler.ESModule
  }

  // Determine declaration settings
  let declaration = directives.declaration
  let source_map = directives.source_map || directives.inline_source_map
  @compiler.CompileOptions::{
    target,
    module_kind,
    source_map,
    inline_source_map: directives.inline_source_map,
    inline_sources: directives.inline_sources,
    declaration,
    strict: directives.strict,
    always_strict: directives.always_strict,
    isolated_modules: directives.isolated_modules,
    exact_optional_property_types: false,
    no_unchecked_indexed_access: false,
    verbatim_module_syntax: directives.verbatim_module_syntax,
    no_emit: directives.no_emit,
    es_module_interop: directives.es_module_interop,
    import_helpers: false,
    no_implicit_any: directives.no_implicit_any,
    strict_null_checks: directives.strict_null_checks,
    no_implicit_this: false,
    no_unused_locals: false,
    no_unused_parameters: false,
    no_implicit_returns: false,
    no_fallthrough_cases_in_switch: false,
    strict_property_initialization: false,
  }
}

///|
/// Compile a single source file
pub fn compile_file(
  source : SourceUnit,
  options : @compiler.CompileOptions,
) -> FileCompileResult {
  let result = @compiler.compile_source(
    source.content,
    source.filename,
    options,
  )
  {
    filename: source.filename,
    source: source.content,
    javascript: result.javascript,
    declaration: result.declaration,
    source_map: result.source_map,
    diagnostics: result.diagnostics,
  }
}

///|
/// Compile all source files in a test case
pub fn compile_test_case(
  test_case : TestCase,
  variant : TestVariant,
) -> Array[FileCompileResult] {
  let options = build_compile_options(test_case.directives, variant)
  let results : Array[FileCompileResult] = []
  for source in test_case.source_files {
    let result = compile_file(source, options)
    results.push(result)
  }
  results
}

///|
/// Compare two baselines and return diffs
pub fn compare_baselines(
  actual : Baselines,
  expected : Baselines,
) -> Array[BaselineDiff] {
  let diffs : Array[BaselineDiff] = []

  // Compare JavaScript output
  match (actual.js, expected.js) {
    (Some(act), Some(exp)) =>
      if normalize_baseline(act) != normalize_baseline(exp) {
        diffs.push({ baseline_type: "js", expected: exp, actual: act })
      }
    (None, Some(exp)) =>
      diffs.push({ baseline_type: "js", expected: exp, actual: "" })
    (Some(act), None) =>
      diffs.push({ baseline_type: "js", expected: "", actual: act })
    (None, None) => ()
  }

  // Compare declaration output
  match (actual.dts, expected.dts) {
    (Some(act), Some(exp)) =>
      if normalize_baseline(act) != normalize_baseline(exp) {
        diffs.push({ baseline_type: "dts", expected: exp, actual: act })
      }
    (None, Some(exp)) =>
      diffs.push({ baseline_type: "dts", expected: exp, actual: "" })
    (Some(act), None) =>
      diffs.push({ baseline_type: "dts", expected: "", actual: act })
    (None, None) => ()
  }

  // Compare error output
  match (actual.errors, expected.errors) {
    (Some(act), Some(exp)) =>
      if normalize_baseline(act) != normalize_baseline(exp) {
        diffs.push({ baseline_type: "errors", expected: exp, actual: act })
      }
    (None, Some(exp)) =>
      diffs.push({ baseline_type: "errors", expected: exp, actual: "" })
    (Some(act), None) =>
      diffs.push({ baseline_type: "errors", expected: "", actual: act })
    (None, None) => ()
  }

  // TODO: Compare types and symbols when implemented
  diffs
}

///|
/// Normalize baseline for comparison (trim trailing whitespace, normalize line endings)
fn normalize_baseline(content : String) -> String {
  let lines = content.split("\n")
  let normalized : Array[String] = []
  for line in lines {
    // trim_end returns StringView, convert to String
    let trimmed = line.trim_end(chars=" \t\r")
    normalized.push(trimmed.to_owned())
  }
  // Remove trailing empty lines
  while normalized.length() > 0 &&
        normalized[normalized.length() - 1].length() == 0 {
    let _ = normalized.pop()

  }
  normalized.iter().collect().join("\n")
}

///|
/// Execute a single test case for all variants
pub fn execute_test(
  test_case : TestCase,
  load_baseline : (String, TestVariant, String) -> String?,
) -> TestResult {
  // If no variants, use default
  let variants = if test_case.variants.length() > 0 {
    test_case.variants
  } else {
    [TestVariant::default()]
  }

  // Execute each variant
  for variant in variants {
    // Compile the test
    let results = compile_test_case(test_case, variant)

    // Generate actual baselines
    let actual = generate_all_baselines(test_case.source_files, results)

    // Load expected baselines
    let expected_js = load_baseline(test_case.name, variant, ".js")
    let expected_dts = load_baseline(test_case.name, variant, ".d.ts")
    let expected_errors = load_baseline(test_case.name, variant, ".errors.txt")
    let expected = Baselines::{
      js: expected_js,
      types: None,
      symbols: None,
      errors: expected_errors,
      dts: expected_dts,
      js_map: None,
    }

    // Compare
    let diffs = compare_baselines(actual, expected)
    if diffs.length() > 0 {
      return TestResult::failed(test_case.name, Some(variant), diffs)
    }
  }
  TestResult::passed(test_case.name)
}

// Tests

///|
test "build compile options" {
  let directives = TestDirectives::{
    ..TestDirectives::default(),
    declaration: true,
    strict: true,
  }
  let variant = TestVariant::{
    target: "es2015",
    module_kind: "commonjs",
    declaration_map: None,
  }
  let options = build_compile_options(directives, variant)
  assert_true(options.declaration)
  assert_true(options.strict)
  assert_eq(options.module_kind, @compiler.CommonJS)
}

///|
test "normalize baseline" {
  let content = "line1  \nline2\t\nline3\n\n"
  let normalized = normalize_baseline(content)
  assert_eq(normalized, "line1\nline2\nline3")
}
