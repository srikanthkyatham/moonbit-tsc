// Module Augmentation Tests
// Tests for distinguishing between module augmentation and ambient module declarations

///|
/// Helper function to parse and bind source code
fn parse_and_bind_for_augmentation(
  source : String,
) -> Result[@compiler.BoundSourceFile, Array[@compiler.Diagnostic]] {
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) => @compiler.bind_source_file(source_file)
    Err(_) => Err([])
  }
}

///|
test "augmentation with import" {
  let source =
    #|import { foo } from "bar";
    #|declare module "express" { interface Request { user?: string; } }
  let result = parse_and_bind_for_augmentation(source)
  match result {
    Ok(bound) => {
      assert_eq(bound.module_augmentations.length(), 1)
      assert_eq(bound.module_augmentations[0].module_name, "express")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "ambient in script" {
  let source =
    #|declare module "lodash" { export function map(): void; }
  let result = parse_and_bind_for_augmentation(source)
  match result {
    Ok(bound) => {
      assert_eq(bound.module_augmentations.length(), 0)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "augmentation with export" {
  let source =
    #|export const x = 1;
    #|declare module "lib" { interface Opts { y?: boolean; } }
  let result = parse_and_bind_for_augmentation(source)
  match result {
    Ok(bound) => {
      assert_eq(bound.module_augmentations.length(), 1)
    }
    Err(_) => assert_true(false)
  }
}
