// E2E Test Runner Types

///|
/// A source unit in a test (single file in a multi-file test)
pub(all) struct SourceUnit {
  filename : String
  content : String
} derive(Debug)

///|
/// Test directives parsed from comment lines
pub(all) struct TestDirectives {
  mut target : Array[String] // @target: es5,es2015,esnext
  mut module_kind : Array[String] // @module: commonjs,esnext
  mut declaration : Bool // @declaration: true
  mut declaration_map : Array[Bool] // @declarationMap: true,false
  mut source_map : Bool // @sourceMap: true
  mut inline_source_map : Bool // @inlineSourceMap: true
  mut inline_sources : Bool // @inlineSources: true
  mut strict : Bool // @strict: true
  mut no_emit : Bool // @noEmit: true
  mut jsx : String // @jsx: react
  mut filenames : Array[String] // @filename: file.ts
  mut es_module_interop : Bool // @esModuleInterop: true
  mut always_strict : Bool // @alwaysStrict: true
  mut no_implicit_any : Bool // @noImplicitAny: true
  mut strict_null_checks : Bool // @strictNullChecks: true
  mut verbatim_module_syntax : Bool // @verbatimModuleSyntax: true
  mut isolated_modules : Bool // @isolatedModules: true
} derive(Debug)

///|
/// Default test directives
pub fn TestDirectives::default() -> TestDirectives {
  {
    target: [],
    module_kind: [],
    declaration: false,
    declaration_map: [],
    source_map: false,
    inline_source_map: false,
    inline_sources: false,
    strict: false,
    no_emit: false,
    jsx: "",
    filenames: [],
    es_module_interop: false,
    always_strict: false,
    no_implicit_any: false,
    strict_null_checks: false,
    verbatim_module_syntax: false,
    isolated_modules: false,
  }
}

///|
/// A test variant (combination of directive values for parameterized tests)
pub(all) struct TestVariant {
  target : String
  module_kind : String
  declaration_map : Bool?
} derive(Debug, Eq)

///|
/// Default test variant
pub fn TestVariant::default() -> TestVariant {
  { target: "es2015", module_kind: "esnext", declaration_map: None }
}

///|
/// Format variant as string for baseline filename
pub fn TestVariant::to_param_string(self : TestVariant) -> String {
  let parts : Array[String] = []
  if self.target != "" && self.target != "es2015" {
    parts.push("target=" + self.target)
  }
  if self.module_kind != "" && self.module_kind != "esnext" {
    parts.push("module=" + self.module_kind)
  }
  match self.declaration_map {
    Some(v) => parts.push("declarationMap=" + v.to_string())
    None => ()
  }
  if parts.length() == 0 {
    ""
  } else {
    "(" + parts.iter().collect().join(",") + ")"
  }
}

///|
/// A test case representing a single test file
pub(all) struct TestCase {
  name : String
  root_path : String
  source_files : Array[SourceUnit]
  directives : TestDirectives
  variants : Array[TestVariant]
} derive(Debug)

///|
/// Baseline outputs for a test
pub(all) struct Baselines {
  js : String?
  types : String?
  symbols : String?
  errors : String?
  dts : String?
  js_map : String?
} derive(Debug)

///|
/// Empty baselines
pub fn Baselines::empty() -> Baselines {
  {
    js: None,
    types: None,
    symbols: None,
    errors: None,
    dts: None,
    js_map: None,
  }
}

///|
/// A diff between expected and actual baseline
pub(all) struct BaselineDiff {
  baseline_type : String // "js", "types", "symbols", "errors", "dts"
  expected : String
  actual : String
} derive(Debug)

///|
/// Result of running a single test
pub(all) struct TestResult {
  name : String
  variant : TestVariant?
  passed : Bool
  diffs : Array[BaselineDiff]
  error_message : String?
} derive(Debug)

///|
/// Create a passed test result
pub fn TestResult::passed(name : String) -> TestResult {
  { name, variant: None, passed: true, diffs: [], error_message: None }
}

///|
/// Create a passed test result with variant
pub fn TestResult::passed_with_variant(
  name : String,
  variant : TestVariant,
) -> TestResult {
  { name, variant: Some(variant), passed: true, diffs: [], error_message: None }
}

///|
/// Create a failed test result
pub fn TestResult::failed(
  name : String,
  variant : TestVariant?,
  diffs : Array[BaselineDiff],
) -> TestResult {
  { name, variant, passed: false, diffs, error_message: None }
}

///|
/// Create a failed test result with error message
pub fn TestResult::error(name : String, message : String) -> TestResult {
  {
    name,
    variant: None,
    passed: false,
    diffs: [],
    error_message: Some(message),
  }
}

///|
/// Summary of test run
pub(all) struct TestSummary {
  total : Int
  passed : Int
  failed : Int
  skipped : Int
  results : Array[TestResult]
} derive(Debug)
