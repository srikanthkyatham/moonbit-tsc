// Main Test Runner for E2E Tests
// Discovers, executes, and reports on transpile tests

///|
/// Configuration for the test runner
pub(all) struct RunnerConfig {
  test_dir : String // Root test directory
  baseline_dir : String // Baseline directory
  verbose : Bool // Show detailed output
  update_baselines : Bool // Update baselines instead of comparing
} derive(Debug)

///|
/// Default runner config
pub fn RunnerConfig::default() -> RunnerConfig {
  {
    test_dir: "e2e_tests/cases/transpile",
    baseline_dir: "e2e_tests/baselines/reference/transpile",
    verbose: false,
    update_baselines: false,
  }
}

///|
/// Discover transpile tests in the test directory
pub async fn discover_transpile_tests(
  test_dir : String,
) -> Array[String] raise Error {
  let files : Array[String] = []
  @fs.walk(test_dir, fn(_dir, entries) {
    for entry in entries {
      if entry.has_suffix(".ts") && !(entry.has_suffix(".d.ts")) {
        files.push(entry)
      }
    }
  })
  files
}

///|
/// Load a test case from a file
pub async fn load_test_case(
  test_dir : String,
  filename : String,
) -> TestCase raise Error {
  let path = test_dir + "/" + filename
  let data = @fs.read_file(path)
  let content = data.text()

  // Parse directives
  let directives = parse_directives(content)

  // Parse source files
  let test_name = extract_test_name(filename)
  let source_files = parse_multi_file_test(content, directives, filename)

  // Generate variants
  let variants = generate_variants(directives)
  { name: test_name, root_path: path, source_files, directives, variants }
}

///|
/// Extract test name from filename (remove .ts extension)
fn extract_test_name(filename : String) -> String {
  if filename.has_suffix(".ts") {
    filename[:filename.length() - 3].to_owned()
  } else {
    filename
  }
}

///|
/// Load a baseline file if it exists
pub async fn load_baseline(
  baseline_dir : String,
  test_name : String,
  variant : TestVariant,
  extension : String,
) -> String? raise Error {
  let filename = generate_baseline_filename(test_name, variant, extension)
  let path = baseline_dir + "/" + filename

  // Try to read the file - return None if it doesn't exist or is a directory
  let file_kind = @fs.kind(path)
  if file_kind == @fs.FileKind::Directory {
    return None
  }
  // Try to read - will raise if file doesn't exist
  try {
    let data = @fs.read_file(path)
    Some(data.text())
  } catch {
    _ => None
  }
}

///|
/// Run all transpile tests
pub async fn run_transpile_tests(
  config : RunnerConfig,
) -> TestSummary raise Error {
  // Discover test files
  let test_files = discover_transpile_tests(config.test_dir)
  if config.verbose {
    println("Discovered " + test_files.length().to_string() + " test files")
  }

  // Load and execute each test
  let results : Array[TestResult] = []
  for filename in test_files {
    // Load test case
    let test_case = load_test_case(config.test_dir, filename) catch {
      err => {
        results.push(TestResult::error(filename, err.to_string()))
        continue
      }
    }
    if config.verbose {
      println("Running: " + test_case.name)
    }

    // Execute test with baseline loader
    let _baseline_dir = config.baseline_dir
    let result = execute_test(test_case, fn(_name, _variant, _ext) {
      // Note: This is a sync wrapper - we'll need to handle this differently
      // For now, we'll load baselines before test execution
      None
    })

    // Print result
    if config.verbose {
      println(format_test_result(result))
    } else if result.passed {
      println(".")
    } else {
      println("F")
    }
    results.push(result)
  }
  if !(config.verbose) {
    println("") // Newline after dots
  }

  // Calculate summary
  let passed = results.iter().filter(fn(r) { r.passed }).count()
  let failed = results.length() - passed
  let summary = { total: results.length(), passed, failed, skipped: 0, results }

  // Print summary
  println(format_test_summary(summary))
  summary
}

///|
/// Run E2E tests with the given configuration
pub async fn run_e2e_tests(config : RunnerConfig) -> TestSummary raise Error {
  println("E2E Test Runner")
  println("===============")
  println("Test directory: " + config.test_dir)
  println("Baseline directory: " + config.baseline_dir)
  println("")
  let summary = run_transpile_tests(config)

  // Print final status
  if summary.failed > 0 {
    println("\nTests failed!")
  } else {
    println("\nAll tests passed!")
  }
  summary
}
