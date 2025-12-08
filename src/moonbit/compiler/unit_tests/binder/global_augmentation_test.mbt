// Global Augmentation Tests
// Tests for `declare global { }` blocks that add to the global scope

///|
/// Helper function to parse and bind source code
fn parse_and_bind_for_global_augmentation(
  source : String,
) -> Result[@compiler.BoundSourceFile, Array[@compiler.Diagnostic]] {
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) => @compiler.bind_source_file(source_file)
    Err(_) => Err([])
  }
}

// ============================================================================
// Global Augmentation Tests
// ============================================================================

///|
test "global augmentation basic" {
  // declare global { } adds to global scope
  let source =
    #|export const x = 1;
    #|declare global {
    #|  interface Window { myApp: string; }
    #|}
  let result = parse_and_bind_for_global_augmentation(source)
  match result {
    Ok(bound) =>
      // Should have one global augmentation
      assert_eq(bound.global_augmentations.length(), 1)
    Err(_) => assert_true(false)
  }
}

///|
test "global augmentation with import" {
  // declare global works in module with import
  let source =
    #|import { foo } from "bar";
    #|declare global {
    #|  var globalVar: number;
    #|}
  let result = parse_and_bind_for_global_augmentation(source)
  match result {
    Ok(bound) => assert_eq(bound.global_augmentations.length(), 1)
    Err(_) => assert_true(false)
  }
}

///|
test "multiple global augmentations" {
  // Multiple declare global blocks
  let source =
    #|export type T = string;
    #|declare global {
    #|  interface Window { app1: string; }
    #|}
    #|declare global {
    #|  interface Window { app2: number; }
    #|}
  let result = parse_and_bind_for_global_augmentation(source)
  match result {
    Ok(bound) => assert_eq(bound.global_augmentations.length(), 2)
    Err(_) => assert_true(false)
  }
}

///|
test "global augmentation SymbolConstructor interface" {
  // declare global with SymbolConstructor interface
  let source =
    #|declare global {
    #|  interface SymbolConstructor {
    #|    readonly obs: symbol
    #|  }
    #|}
  let result = parse_and_bind_for_global_augmentation(source)
  match result {
    Ok(bound) => {
      // Should have one global augmentation
      assert_eq(bound.global_augmentations.length(), 1)
      // SymbolConstructor should be in the augmentation declarations
      let aug = bound.global_augmentations[0]
      match aug.declarations.get("SymbolConstructor") {
        Some(sym) => {
          match sym.kind {
            @compiler.SymbolKind::Interface => ()
            _ => assert_true(false)
          }
          assert_eq(sym.declarations.length(), 1)
        }
        None => assert_true(false)
      }
      // SymbolConstructor should also be in global scope
      match bound.global_scope.symbols.get("SymbolConstructor") {
        Some(sym) => {
          match sym.kind {
            @compiler.SymbolKind::Interface => ()
            _ => assert_true(false)
          }
        }
        None => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "global augmentation interface merging" {
  // Direct interface and global augmentation should merge
  let source =
    #|interface Foo {
    #|  prop1: string;
    #|}
    #|declare global {
    #|  interface Foo {
    #|    prop2: number;
    #|  }
    #|}
  let result = parse_and_bind_for_global_augmentation(source)
  match result {
    Ok(bound) => {
      // Foo should be in global scope with merged declarations
      match bound.global_scope.symbols.get("Foo") {
        Some(sym) => {
          // Should have 2 declarations (one direct, one from global augmentation)
          assert_eq(sym.declarations.length(), 2)
        }
        None => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "global augmentation with multiple interfaces" {
  // Multiple interfaces in one global augmentation
  let source =
    #|declare global {
    #|  interface Foo { x: number; }
    #|  interface Bar { y: string; }
    #|}
  let result = parse_and_bind_for_global_augmentation(source)
  match result {
    Ok(bound) => {
      let aug = bound.global_augmentations[0]
      // Should have 2 declarations
      assert_eq(aug.declarations.length(), 2)
      // Both should be in global scope
      assert_true(bound.global_scope.symbols.contains("Foo"))
      assert_true(bound.global_scope.symbols.contains("Bar"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "global augmentation with variable declaration" {
  // Variable in global augmentation
  let source =
    #|declare global {
    #|  var globalX: number;
    #|}
  let result = parse_and_bind_for_global_augmentation(source)
  match result {
    Ok(bound) => {
      let aug = bound.global_augmentations[0]
      match aug.declarations.get("globalX") {
        Some(sym) => {
          match sym.kind {
            @compiler.SymbolKind::Variable => ()
            _ => assert_true(false)
          }
        }
        None => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "global augmentation with function declaration" {
  // Function in global augmentation
  let source =
    #|declare global {
    #|  function globalFunc(): void;
    #|}
  let result = parse_and_bind_for_global_augmentation(source)
  match result {
    Ok(bound) => {
      let aug = bound.global_augmentations[0]
      match aug.declarations.get("globalFunc") {
        Some(sym) => {
          match sym.kind {
            @compiler.SymbolKind::Function => ()
            _ => assert_true(false)
          }
        }
        None => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "global augmentation with namespace" {
  // Namespace in global augmentation
  let source =
    #|declare global {
    #|  namespace MyNamespace {
    #|    interface Inner { }
    #|  }
    #|}
  let result = parse_and_bind_for_global_augmentation(source)
  match result {
    Ok(bound) => {
      let aug = bound.global_augmentations[0]
      match aug.declarations.get("MyNamespace") {
        Some(sym) => {
          match sym.kind {
            @compiler.SymbolKind::Module => ()
            _ => assert_true(false)
          }
        }
        None => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}
