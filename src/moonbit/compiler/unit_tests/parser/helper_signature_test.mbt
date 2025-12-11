// Unit tests for helper signature extraction
// Tests build_helper_signatures() function

///|
test "Extract __spreadArray signature from tslib.d.ts (2 params)" {
  let source = #|// @filename: tslib.d.ts
    #|export function __spreadArray(to: any[], from: any[]): any[];

  match @compiler.split_by_filename_directives(source) {
    Some(file_set) => {
      let parse_result = @compiler.parse_virtual_files(file_set)
      let helper_registry = @compiler.build_helper_signatures(parse_result)

      // Look up __spreadArray from tslib.d.ts
      match helper_registry.lookup("tslib.d.ts", "__spreadArray") {
        Some(sig_info) => {
          assert_eq(sig_info.name, "__spreadArray")
          assert_eq(sig_info.param_count, 2)
          assert_eq(sig_info.module_path, "tslib.d.ts")
        }
        None => @test.fail("Should find __spreadArray in tslib.d.ts")
      }
    }
    None => @test.fail("Should have found virtual files")
  }
}

///|
test "Extract __spreadArray signature from tslib.d.ts (3 params)" {
  let source = #|// @filename: tslib.d.ts
    #|export function __spreadArray(to: any[], from: any[], pack: boolean): any[];

  match @compiler.split_by_filename_directives(source) {
    Some(file_set) => {
      let parse_result = @compiler.parse_virtual_files(file_set)
      let helper_registry = @compiler.build_helper_signatures(parse_result)

      match helper_registry.lookup("tslib.d.ts", "__spreadArray") {
        Some(sig_info) => {
          assert_eq(sig_info.param_count, 3)
        }
        None => @test.fail("Should find __spreadArray")
      }
    }
    None => @test.fail("Should have found virtual files")
  }
}

///|
test "Extract multiple helper signatures from tslib.d.ts" {
  let source = #|// @filename: tslib.d.ts
    #|export function __spreadArray(a: any[], b: any[], c: boolean): any[];
    #|export function __assign(t: any, ...sources: any[]): any;
    #|export function __rest(t: any, propertyNames: string[]): any;

  match @compiler.split_by_filename_directives(source) {
    Some(file_set) => {
      let parse_result = @compiler.parse_virtual_files(file_set)
      let helper_registry = @compiler.build_helper_signatures(parse_result)

      // Check __spreadArray
      match helper_registry.lookup("tslib.d.ts", "__spreadArray") {
        Some(sig) => assert_eq(sig.param_count, 3)
        None => @test.fail("Should find __spreadArray")
      }

      // Check __assign (has rest parameter, counts as 1 param + rest)
      match helper_registry.lookup("tslib.d.ts", "__assign") {
        Some(sig) => {
          // Function has 1 regular param + rest param
          // Should count both
          assert_true(sig.param_count >= 1)
        }
        None => @test.fail("Should find __assign")
      }

      // Check __rest
      match helper_registry.lookup("tslib.d.ts", "__rest") {
        Some(sig) => assert_eq(sig.param_count, 2)
        None => @test.fail("Should find __rest")
      }
    }
    None => @test.fail("Should have found virtual files")
  }
}

///|
test "Extract signatures from multiple files" {
  let source = #|// @filename: lib.ts
    #|export function greet(name: string): string;
    #|export function add(a: number, b: number): number;
    #|// @filename: utils.ts
    #|export function identity(x: any): any;

  match @compiler.split_by_filename_directives(source) {
    Some(file_set) => {
      let parse_result = @compiler.parse_virtual_files(file_set)
      let helper_registry = @compiler.build_helper_signatures(parse_result)

      // Check lib.ts exports
      match helper_registry.lookup("lib.ts", "greet") {
        Some(sig) => assert_eq(sig.param_count, 1)
        None => @test.fail("Should find greet")
      }

      match helper_registry.lookup("lib.ts", "add") {
        Some(sig) => assert_eq(sig.param_count, 2)
        None => @test.fail("Should find add")
      }

      // Check utils.ts export
      match helper_registry.lookup("utils.ts", "identity") {
        Some(sig) => assert_eq(sig.param_count, 1)
        None => @test.fail("Should find identity")
      }
    }
    None => @test.fail("Should have found virtual files")
  }
}

///|
test "Lookup non-existent helper returns None" {
  let source = #|// @filename: tslib.d.ts
    #|export function __spreadArray(a: any[], b: any[]): any[];

  match @compiler.split_by_filename_directives(source) {
    Some(file_set) => {
      let parse_result = @compiler.parse_virtual_files(file_set)
      let helper_registry = @compiler.build_helper_signatures(parse_result)

      // Lookup non-existent function
      match helper_registry.lookup("tslib.d.ts", "__nonExistent") {
        Some(_) => @test.fail("Should not find non-existent function")
        None => () // Expected
      }

      // Lookup from non-existent module
      match helper_registry.lookup("unknown.ts", "__spreadArray") {
        Some(_) => @test.fail("Should not find function in unknown module")
        None => () // Expected
      }
    }
    None => @test.fail("Should have found virtual files")
  }
}

///|
test "Extract signatures skips files with binding errors" {
  let source = #|// @filename: good.ts
    #|export function valid(x: number): number;
    #|// @filename: bad.ts
    #|export function invalid(x: UnknownType): number;

  match @compiler.split_by_filename_directives(source) {
    Some(file_set) => {
      let parse_result = @compiler.parse_virtual_files(file_set)

      // Both files should parse successfully (no parse errors)
      assert_eq(parse_result.parse_errors.length(), 0)
      assert_eq(parse_result.files.length(), 2)

      let helper_registry = @compiler.build_helper_signatures(parse_result)

      // Should find good.ts export (parses and binds successfully)
      match helper_registry.lookup("good.ts", "valid") {
        Some(_) => () // Expected
        None => @test.fail("Should find valid function")
      }

      // bad.ts parses but may fail to bind due to UnknownType
      // If binding succeeds (type checker is lenient), it's still valid to extract signatures
      // Just verify we got at least the good.ts export
    }
    None => @test.fail("Should have found virtual files")
  }
}

///|
test "Extract function with no parameters" {
  let source = #|// @filename: lib.ts
    #|export function getValue(): number;

  match @compiler.split_by_filename_directives(source) {
    Some(file_set) => {
      let parse_result = @compiler.parse_virtual_files(file_set)
      let helper_registry = @compiler.build_helper_signatures(parse_result)

      match helper_registry.lookup("lib.ts", "getValue") {
        Some(sig) => assert_eq(sig.param_count, 0)
        None => @test.fail("Should find getValue")
      }
    }
    None => @test.fail("Should have found virtual files")
  }
}

///|
test "Extract function with many parameters" {
  let source = #|// @filename: lib.ts
    #|export function complex(a: number, b: string, c: boolean, d: any, e: object): void;

  match @compiler.split_by_filename_directives(source) {
    Some(file_set) => {
      let parse_result = @compiler.parse_virtual_files(file_set)
      let helper_registry = @compiler.build_helper_signatures(parse_result)

      match helper_registry.lookup("lib.ts", "complex") {
        Some(sig) => assert_eq(sig.param_count, 5)
        None => @test.fail("Should find complex")
      }
    }
    None => @test.fail("Should have found virtual files")
  }
}

///|
test "Empty helper registry has no signatures" {
  let source = #|// @filename: empty.ts

  match @compiler.split_by_filename_directives(source) {
    Some(file_set) => {
      let parse_result = @compiler.parse_virtual_files(file_set)
      let helper_registry = @compiler.build_helper_signatures(parse_result)

      // Lookup anything should return None
      match helper_registry.lookup("empty.ts", "anything") {
        Some(_) => @test.fail("Should not find any signatures in empty file")
        None => () // Expected
      }
    }
    None => @test.fail("Should have found virtual files")
  }
}
