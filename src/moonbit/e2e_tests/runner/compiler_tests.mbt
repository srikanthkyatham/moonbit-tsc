// Compiler Tests for E2E Tests
// Tests compiler test cases from e2e_tests/cases/compiler/

///|
/// Test compiling 2dArrays.ts
test "compile 2dArrays.ts" {
  let source =
    #|// @strict: false
    #|class Cell {
    #|}
    #|
    #|class Ship {
    #|    isSunk: boolean;
    #|}
    #|
    #|class Board {
    #|    ships: Ship[];
    #|    cells: Cell[];
    #|
    #|    private allShipsSunk() {
    #|        return this.ships.every(function (val) { return val.isSunk; });
    #|    }
    #|}
  let options = @compiler.CompileOptions::{
    target: @compiler.ES5,
    module_kind: @compiler.CommonJS,
    declaration: false,
    source_map: false,
    inline_source_map: false,
    inline_sources: false,
    strict: false,
    always_strict: false,
    isolated_modules: false,
    exact_optional_property_types: false,
    no_unchecked_indexed_access: false,
    verbatim_module_syntax: false,
    no_emit: false,
    es_module_interop: false,
    import_helpers: false,
    no_implicit_any: false,
    strict_null_checks: false,
    no_implicit_this: false,
    no_unused_locals: false,
    no_unused_parameters: false,
    no_implicit_returns: false,
    no_fallthrough_cases_in_switch: false,
    strict_property_initialization: false,
  }
  let result = @compiler.compile_source(source, "2dArrays.ts", options)

  // Verify no errors
  assert_eq(result.diagnostics.length(), 0)

  // Verify JavaScript output contains expected class definitions
  assert_true(result.javascript.contains("Cell"))
  assert_true(result.javascript.contains("Ship"))
  assert_true(result.javascript.contains("Board"))
  assert_true(result.javascript.contains("allShipsSunk"))
}

///|
/// Test compiling accessorsEmit.ts
test "compile accessorsEmit.ts" {
  let source =
    #|class Result { }
    #|
    #|class Test {
    #|    get Property(): Result {
    #|        var x = 1;
    #|        return null;
    #|    }
    #|}
    #|
    #|class Test2 {
    #|    get Property() {
    #|        var x = 1;
    #|        return null;
    #|    }
    #|}
  let options = @compiler.CompileOptions::{
    target: @compiler.ES5,
    module_kind: @compiler.CommonJS,
    declaration: false,
    source_map: false,
    inline_source_map: false,
    inline_sources: false,
    strict: false,
    always_strict: false,
    isolated_modules: false,
    exact_optional_property_types: false,
    no_unchecked_indexed_access: false,
    verbatim_module_syntax: false,
    no_emit: false,
    es_module_interop: false,
    import_helpers: false,
    no_implicit_any: false,
    strict_null_checks: false,
    no_implicit_this: false,
    no_unused_locals: false,
    no_unused_parameters: false,
    no_implicit_returns: false,
    no_fallthrough_cases_in_switch: false,
    strict_property_initialization: false,
  }
  let result = @compiler.compile_source(source, "accessorsEmit.ts", options)

  // Verify no errors
  assert_eq(result.diagnostics.length(), 0)

  // Verify JavaScript output contains expected class definitions
  assert_true(result.javascript.contains("Result"))
  assert_true(result.javascript.contains("Test"))
  assert_true(result.javascript.contains("Test2"))
  assert_true(result.javascript.contains("Property"))
}

///|
/// Test compiling acceptableAlias1.ts (namespace import aliases)
test "compile acceptableAlias1.ts" {
  let source =
    #|namespace M {
    #|    export namespace N {
    #|    }
    #|    export import X = N;
    #|}
    #|
    #|import r = M.X;
  let options = @compiler.CompileOptions::{
    target: @compiler.ES5,
    module_kind: @compiler.CommonJS,
    declaration: false,
    source_map: false,
    inline_source_map: false,
    inline_sources: false,
    strict: false,
    always_strict: false,
    isolated_modules: false,
    exact_optional_property_types: false,
    no_unchecked_indexed_access: false,
    verbatim_module_syntax: false,
    no_emit: false,
    es_module_interop: false,
    import_helpers: false,
    no_implicit_any: false,
    strict_null_checks: false,
    no_implicit_this: false,
    no_unused_locals: false,
    no_unused_parameters: false,
    no_implicit_returns: false,
    no_fallthrough_cases_in_switch: false,
    strict_property_initialization: false,
  }
  let result = @compiler.compile_source(source, "acceptableAlias1.ts", options)

  // Verify no errors
  assert_eq(result.diagnostics.length(), 0)

  // Verify JavaScript output contains namespace M
  // Note: import aliases (import X = N, import r = M.X) are type-only
  // and don't emit any JavaScript code
  assert_true(result.javascript.contains("var M"))
}
