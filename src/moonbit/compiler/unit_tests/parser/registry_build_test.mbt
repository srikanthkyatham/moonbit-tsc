// Unit tests for building ExternalTypeRegistry from virtual files

///|
test "Build registry from single tslib.d.ts file" {
  let source = #|// @filename: tslib.d.ts
    #|export function __spreadArray(to: any[], from: any[]): any[];

  match @compiler.split_by_filename_directives(source) {
    Some(file_set) => {
      let parse_result = @compiler.parse_virtual_files(file_set)
      let registry = @compiler.build_registry_from_virtual_files(parse_result)

      // Check that tslib.d.ts was registered
      match registry.get_module("tslib.d.ts") {
        Some(module_types) => {
          assert_eq(module_types.module_path, "tslib.d.ts")
        }
        None => @test.fail("tslib.d.ts should be registered")
      }

      // Check that "tslib" mapping was created
      let resolved = registry.resolve_module("tslib")
      assert_eq(resolved, "tslib.d.ts")
    }
    None => @test.fail("Should have found virtual files")
  }
}

///|
test "Build registry from multiple files" {
  let source = #|// @filename: lib.ts
    #|export const x = 42;
    #|// @filename: main.ts
    #|import { x } from './lib';

  match @compiler.split_by_filename_directives(source) {
    Some(file_set) => {
      let parse_result = @compiler.parse_virtual_files(file_set)
      let registry = @compiler.build_registry_from_virtual_files(parse_result)

      // Both files should be registered
      match registry.get_module("lib.ts") {
        Some(_) => ()
        None => @test.fail("lib.ts should be registered")
      }

      match registry.get_module("main.ts") {
        Some(_) => ()
        None => @test.fail("main.ts should be registered")
      }
    }
    None => @test.fail("Should have found virtual files")
  }
}

///|
test "Build registry skips files with parse errors" {
  let source = #|// @filename: good.ts
    #|const x = 42;
    #|// @filename: bad.ts
    #|const y = ;

  match @compiler.split_by_filename_directives(source) {
    Some(file_set) => {
      let parse_result = @compiler.parse_virtual_files(file_set)

      // Should have 1 parse error
      assert_eq(parse_result.parse_errors.length(), 1)

      let registry = @compiler.build_registry_from_virtual_files(parse_result)

      // Only good.ts should be registered
      match registry.get_module("good.ts") {
        Some(_) => ()
        None => @test.fail("good.ts should be registered")
      }

      // bad.ts should NOT be registered
      match registry.get_module("bad.ts") {
        Some(_) => @test.fail("bad.ts should not be registered due to parse error")
        None => () // Expected
      }
    }
    None => @test.fail("Should have found virtual files")
  }
}

///|
test "Registry resolves tslib correctly" {
  let source = #|// @filename: tslib.d.ts
    #|export function __spreadArray(a: any[], b: any[], c: boolean): any[];
    #|// @filename: test.ts
    #|const x = [1, 2];

  match @compiler.split_by_filename_directives(source) {
    Some(file_set) => {
      let parse_result = @compiler.parse_virtual_files(file_set)
      let registry = @compiler.build_registry_from_virtual_files(parse_result)

      // "tslib" should resolve to "tslib.d.ts"
      assert_eq(registry.resolve_module("tslib"), "tslib.d.ts")

      // Other modules resolve to themselves
      assert_eq(registry.resolve_module("test.ts"), "test.ts")
      assert_eq(registry.resolve_module("unknown"), "unknown")
    }
    None => @test.fail("Should have found virtual files")
  }
}

///|
test "Build registry from empty file set" {
  let source = #|// @filename: empty.ts

  match @compiler.split_by_filename_directives(source) {
    Some(file_set) => {
      let parse_result = @compiler.parse_virtual_files(file_set)
      let registry = @compiler.build_registry_from_virtual_files(parse_result)

      // empty.ts should be registered even though it's empty
      match registry.get_module("empty.ts") {
        Some(_) => ()
        None => @test.fail("empty.ts should be registered")
      }
    }
    None => @test.fail("Should have found virtual files")
  }
}
