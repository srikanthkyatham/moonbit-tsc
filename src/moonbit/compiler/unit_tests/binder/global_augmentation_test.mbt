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
    Ok(bound) => {
      // Should have one global augmentation
      assert_eq(bound.global_augmentations.length(), 1)
    }
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
    Ok(bound) => {
      assert_eq(bound.global_augmentations.length(), 1)
    }
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
    Ok(bound) => {
      assert_eq(bound.global_augmentations.length(), 2)
    }
    Err(_) => assert_true(false)
  }
}
