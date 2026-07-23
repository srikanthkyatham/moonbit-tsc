// Unit tests for type-only import/export semantics:
// - TS1361: '{0}' cannot be used as a value because it was imported using 'import type'
// - TS1362: '{0}' cannot be used as a value because it was exported using 'export type'
// - TS1363: A type-only import can specify a default import or named bindings, but not both
// - TS2206: The 'type' modifier cannot be used on a named import when 'import type' is used
// - TS2207: The 'type' modifier cannot be used on a named export when 'export type' is used
// - JS emit elision of type-only imports/exports

///|
/// Parse, bind and type-check a single source file (no external registry)
fn type_only_check(source : String) -> Array[@compiler.Diagnostic] {
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let diagnostics = source_file.parse_diagnostics.copy()
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match @compiler.check_source_file(bound) {
            Ok(_) => diagnostics
            Err(check_diags) => {
              for d in check_diags {
                diagnostics.push(d)
              }
              diagnostics
            }
          }
        Err(bind_diags) => {
          for d in bind_diags {
            diagnostics.push(d)
          }
          diagnostics
        }
      }
    }
    Err(diags) => diags
  }
}

///|
/// Parse, bind and type-check a source file against an external registry
fn type_only_check_with_registry(
  source : String,
  registry : @compiler.ExternalTypeRegistry,
) -> Array[@compiler.Diagnostic] {
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) =>
          match
            @compiler.check_source_file_with_external_types(
              bound,
              registry,
              false,
              @compiler.Target::ESNext,
            ) {
            Ok(_) => []
            Err(diags) => diags
          }
        Err(diags) => diags
      }
    Err(diags) => diags
  }
}

///|
fn type_only_has_code(
  diagnostics : Array[@compiler.Diagnostic],
  code : Int,
) -> Bool {
  for d in diagnostics {
    if d.code == code {
      return true
    }
  }
  false
}

///|
fn flavor_matches(
  actual : @compiler.TypeOnlyAliasFlavor,
  expected : @compiler.TypeOnlyAliasFlavor,
) -> Bool {
  actual == expected
}

// ============================================================================
// TS1361: type-only import used as a value
// ============================================================================

///|
test "TS1361: named type-only import used as a value" {
  let diags = type_only_check(
    (
      #|import type { A } from './a';
      #|new A();
    ),
  )
  assert_true(type_only_has_code(diags, 1361))
}

///|
test "TS1361: default type-only import used as a value" {
  let diags = type_only_check(
    (
      #|import type A from './a';
      #|let b = { A };
    ),
  )
  assert_true(type_only_has_code(diags, 1361))
}

///|
test "TS1361: namespace type-only import used as a value" {
  let diags = type_only_check(
    (
      #|import type * as types from './a';
      #|types.foo();
    ),
  )
  assert_true(type_only_has_code(diags, 1361))
}

///|
test "TS1361: inline type specifier used as a value" {
  let diags = type_only_check(
    (
      #|import { type A } from './a';
      #|new A();
    ),
  )
  assert_true(type_only_has_code(diags, 1361))
}

///|
test "TS1361: class extends of a type-only import" {
  let diags = type_only_check(
    (
      #|import type { C } from './types';
      #|class U extends C {}
    ),
  )
  assert_true(type_only_has_code(diags, 1361))
}

///|
test "no TS1361 for type positions and interface extends" {
  let diags = type_only_check(
    (
      #|import type { A, I } from './a';
      #|let x: A | null = null;
      #|interface Q extends I {}
      #|declare class B extends A {}
      #|let ctor: typeof A;
    ),
  )
  assert_false(type_only_has_code(diags, 1361))
  assert_false(type_only_has_code(diags, 1362))
}

///|
test "no TS1361 when a local value declaration merges with the import" {
  let diags = type_only_check(
    (
      #|import type { A } from './a';
      #|const A = 0;
      #|A;
    ),
  )
  assert_false(type_only_has_code(diags, 1361))
}

// ============================================================================
// TS1362: import of an `export type` export used as a value
// ============================================================================

///|
test "TS1362: value use of an import whose export was type-only" {
  // Simulate a module './a' whose export A was declared `export type { A }`
  let registry = @compiler.ExternalTypeRegistry::new()
  let module_types = @compiler.ModuleTypes::empty("a.ts")
  module_types.add_export(
    "A",
    @compiler.ExternalTypeInfo::any_value("A").with_flavor(
      @compiler.TypeOnlyAliasFlavor::ViaExportType,
    ),
  )
  registry.register_module("a.ts", module_types)
  let diags = type_only_check_with_registry(
    (
      #|import { A } from './a';
      #|new A();
    ),
    registry,
  )
  assert_true(type_only_has_code(diags, 1362))
}

///|
test "TS1361: value use of an import whose export re-exported an import type binding" {
  let registry = @compiler.ExternalTypeRegistry::new()
  let module_types = @compiler.ModuleTypes::empty("a.ts")
  module_types.add_export(
    "A",
    @compiler.ExternalTypeInfo::any_value("A").with_flavor(
      @compiler.TypeOnlyAliasFlavor::ViaImportType,
    ),
  )
  registry.register_module("a.ts", module_types)
  let diags = type_only_check_with_registry(
    (
      #|import { A } from './a';
      #|new A();
    ),
    registry,
  )
  assert_true(type_only_has_code(diags, 1361))
}

// ============================================================================
// Type-only flavor extraction from export declarations
// ============================================================================

///|
test "extract_module_types: export type marks exports ViaExportType" {
  let source =
    #|class A {}
    #|export type { A };
  let tokens = @compiler.scan_all_v2(source, "a.ts")
  match @compiler.parse_source_file(tokens, "a.ts") {
    Ok(sf) =>
      match @compiler.bind_source_file(sf) {
        Ok(bound) => {
          let module_types = @compiler.extract_module_types(bound, "a.ts")
          match module_types.get_export("A") {
            Some(info) =>
              assert_true(
                flavor_matches(
                  info.type_only_flavor,
                  @compiler.TypeOnlyAliasFlavor::ViaExportType,
                ),
              )
            None => @test.fail("expected export 'A' to be extracted")
          }
        }
        Err(_) => @test.fail("bind failed")
      }
    Err(_) => @test.fail("parse failed")
  }
}

///|
test "extract_module_types: re-exported import type binding is ViaImportType" {
  let source =
    #|import type { C } from './b';
    #|export { C as D };
  let tokens = @compiler.scan_all_v2(source, "c.ts")
  match @compiler.parse_source_file(tokens, "c.ts") {
    Ok(sf) =>
      match @compiler.bind_source_file(sf) {
        Ok(bound) => {
          let module_types = @compiler.extract_module_types(bound, "c.ts")
          match module_types.get_export("D") {
            Some(info) =>
              assert_true(
                flavor_matches(
                  info.type_only_flavor,
                  @compiler.TypeOnlyAliasFlavor::ViaImportType,
                ),
              )
            None => @test.fail("expected export 'D' to be extracted")
          }
        }
        Err(_) => @test.fail("bind failed")
      }
    Err(_) => @test.fail("parse failed")
  }
}

///|
test "extract_module_types: local value merge cancels type-only flavor" {
  let source =
    #|import { A } from './a';
    #|const A = 0;
    #|export { A };
  let tokens = @compiler.scan_all_v2(source, "b.ts")
  match @compiler.parse_source_file(tokens, "b.ts") {
    Ok(sf) =>
      match @compiler.bind_source_file(sf) {
        Ok(bound) => {
          let module_types = @compiler.extract_module_types(bound, "b.ts")
          match module_types.get_export("A") {
            Some(info) =>
              assert_true(
                flavor_matches(
                  info.type_only_flavor,
                  @compiler.TypeOnlyAliasFlavor::NotTypeOnlyAlias,
                ),
              )
            None => @test.fail("expected export 'A' to be extracted")
          }
        }
        Err(_) => @test.fail("bind failed")
      }
    Err(_) => @test.fail("parse failed")
  }
}

// ============================================================================
// TS1363 / TS2206 / TS2207 grammar checks
// ============================================================================

///|
test "TS1363: type-only import with both default and named bindings" {
  let diags = type_only_check(
    (
      #|import type A, { B, C } from './a';
    ),
  )
  assert_true(type_only_has_code(diags, 1363))
}

///|
test "no TS1363 for regular mixed import or plain import type" {
  let diags = type_only_check(
    (
      #|import A, { B } from './a';
      #|import type D from './d';
      #|import type { E } from './e';
    ),
  )
  assert_false(type_only_has_code(diags, 1363))
}

///|
test "TS2206: type modifier inside import type statement" {
  let diags = type_only_check(
    (
      #|import type { type T } from './a';
    ),
  )
  assert_true(type_only_has_code(diags, 2206))
}

///|
test "TS2207: type modifier inside export type statement" {
  let diags = type_only_check(
    (
      #|export type { type T } from './a';
    ),
  )
  assert_true(type_only_has_code(diags, 2207))
}

///|
test "no TS2206/TS2207 for inline type modifiers on regular statements" {
  let diags = type_only_check(
    (
      #|import { type T } from './a';
      #|export { type T };
    ),
  )
  assert_false(type_only_has_code(diags, 2206))
  assert_false(type_only_has_code(diags, 2207))
}

// ============================================================================
// JS emit elision
// ============================================================================

///|
test "emit: import type statements are elided" {
  let source =
    #|import type { A } from './a';
    #|import { type B, v } from './a';
    #|export type { A };
    #|export { type B };
    #|console.log(v);
  let result = @compiler.compile_source(
    source,
    "test.ts",
    @compiler.CompileOptions::default(),
  )
  assert_false(result.javascript.contains("A"))
  assert_false(result.javascript.contains("type"))
  // The value import must survive
  assert_true(result.javascript.contains("v"))
}

///|
test "emit: fully type-only named import list is dropped entirely" {
  let source =
    #|import { type A, type B } from './a';
    #|let x = 1;
  let result = @compiler.compile_source(
    source,
    "test.ts",
    @compiler.CompileOptions::default(),
  )
  assert_false(result.javascript.contains("import"))
}
