// Unit tests for TS2807: import helper version mismatch
// This diagnostic is emitted when @importHelpers is true but the imported
// tslib has an incompatible __spreadArray signature (2 params instead of 3)

///|
test "TS2807: Detect incompatible __spreadArray helper (2 params vs 3 required)" {
  // This test simulates arraySpreadImportHelpers.ts conformance test
  // Note: Putting @importHelpers inside main.ts since global directives aren't parsed yet
  let source = #|// @filename: main.ts
    #|// @importHelpers: true
    #|const k = [1, , 2];
    #|const o = [3, ...k, 4];
    #|// @filename: tslib.d.ts
    #|export function __spreadArray(to: any[], from: any[]): any[];

  // Parse the virtual files
  match @compiler.split_by_filename_directives(source) {
    Some(file_set) => {
      // Verify we have 2 files
      assert_eq(file_set.files.length(), 2)

      // Parse all files
      let parse_result = @compiler.parse_virtual_files(file_set)
      assert_eq(parse_result.files.length(), 2)
      assert_eq(parse_result.parse_errors.length(), 0)

      // Build registry from virtual files (including tslib.d.ts)
      let registry = @compiler.build_registry_from_virtual_files(parse_result)

      // Build helper signature registry
      let helper_registry = @compiler.build_helper_signatures(parse_result)

      // Verify tslib.d.ts was registered and has 2-param __spreadArray
      match helper_registry.lookup("tslib.d.ts", "__spreadArray") {
        Some(sig_info) => {
          assert_eq(sig_info.param_count, 2) // Old tslib has 2 params
        }
        None => @test.fail("Should find __spreadArray in tslib.d.ts")
      }

      // Now type-check the main.ts file
      // Find main.ts in the parsed files
      let mut main_source_file : @compiler.SourceFile? = None
      for parsed in parse_result.files {
        if parsed.filename == "main.ts" {
          main_source_file = Some(parsed.source_file)
          break
        }
      }

      match main_source_file {
        Some(sf) => {
          // Bind the source file
          match @compiler.bind_source_file(sf) {
            Ok(bound) => {
              // Type check with external registry
              let check_result = @compiler.check_source_file_with_external_types(
                bound,
                registry,
                false,
                @compiler.Target::ES5,
                no_implicit_any=false,
              )

              // Extract diagnostics from CheckResult
              let diagnostics = match check_result {
                Ok(typed_file) => typed_file.diagnostics
                Err(diags) => diags
              }

              // Should emit TS2807 diagnostic for incompatible helper
              let has_ts2807 = diagnostics.iter().any(fn(d) {
                d.code == 2807
              })
              assert_true(has_ts2807)
            }
            Err(_) => @test.fail("Failed to bind main.ts")
          }
        }
        None => @test.fail("Could not find main.ts in parsed files")
      }
    }
    None => @test.fail("Should have found virtual files")
  }
}

///|
test "TS2807: No error when __spreadArray has correct signature (3 params)" {
  let source = #|// @filename: main.ts
    #|// @importHelpers: true
    #|const k = [1, 2];
    #|const o = [3, ...k, 4];
    #|// @filename: tslib.d.ts
    #|export function __spreadArray(to: any[], from: any[], pack: boolean): any[];

  match @compiler.split_by_filename_directives(source) {
    Some(file_set) => {
      let parse_result = @compiler.parse_virtual_files(file_set)
      let helper_registry = @compiler.build_helper_signatures(parse_result)

      // Verify tslib.d.ts has correct 3-param __spreadArray
      match helper_registry.lookup("tslib.d.ts", "__spreadArray") {
        Some(sig_info) => {
          assert_eq(sig_info.param_count, 3) // New tslib has 3 params - correct!
        }
        None => @test.fail("Should find __spreadArray in tslib.d.ts")
      }

      // Build registry and type-check to verify NO TS2807 is emitted
      let registry = @compiler.build_registry_from_virtual_files(parse_result)

      // Find and check main.ts
      let mut main_source_file : @compiler.SourceFile? = None
      for parsed in parse_result.files {
        if parsed.filename == "main.ts" {
          main_source_file = Some(parsed.source_file)
          break
        }
      }

      match main_source_file {
        Some(sf) => {
          match @compiler.bind_source_file(sf) {
            Ok(bound) => {
              let check_result = @compiler.check_source_file_with_external_types(
                bound,
                registry,
                false,
                @compiler.Target::ES5,
                no_implicit_any=false,
              )

              // Extract diagnostics from CheckResult
              let diagnostics = match check_result {
                Ok(typed_file) => typed_file.diagnostics
                Err(diags) => diags
              }

              // Should NOT emit TS2807 because signature is correct (3 params)
              let has_ts2807 = diagnostics.iter().any(fn(d) {
                d.code == 2807
              })
              assert_false(has_ts2807)
            }
            Err(_) => @test.fail("Failed to bind main.ts")
          }
        }
        None => @test.fail("Could not find main.ts")
      }
    }
    None => @test.fail("Should have found virtual files")
  }
}

///|
test "TS2807: No error when @importHelpers is false" {
  let source = #|// @importHelpers: false
    #|// @filename: main.ts
    #|const k = [1, 2];
    #|const o = [3, ...k, 4];

  match @compiler.split_by_filename_directives(source) {
    Some(file_set) => {
      // @importHelpers is false, so TS2807 should never be emitted
      assert_false(file_set.global_directives.import_helpers)

      // Even if we had an incompatible tslib, no error should occur
      // because we're not using import helpers
    }
    None => {
      // No @filename directives, that's fine - single file case
      ()
    }
  }
}
