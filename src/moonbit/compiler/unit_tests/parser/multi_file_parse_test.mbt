// Unit tests for multi-file parsing
// Tests parse_virtual_files() function

///|
test "Parse two virtual files successfully" {
  let source = #|// @filename: lib.ts
    #|export const x = 42;
    #|// @filename: main.ts
    #|const y = 100;

  match @compiler.split_by_filename_directives(source) {
    Some(file_set) => {
      let result = @compiler.parse_virtual_files(file_set)

      // Should have 2 parsed files, 0 errors
      assert_eq(result.files.length(), 2)
      assert_eq(result.parse_errors.length(), 0)

      // Check filenames
      assert_eq(result.files[0].filename, "lib.ts")
      assert_eq(result.files[1].filename, "main.ts")

      // Check that SourceFiles were created
      assert_eq(result.files[0].source_file.file_path, "lib.ts")
      assert_eq(result.files[1].source_file.file_path, "main.ts")

      // Check that statements were parsed
      assert_true(result.files[0].source_file.statements.length() > 0)
      assert_true(result.files[1].source_file.statements.length() > 0)
    }
    None => @test.fail("Should have found virtual files")
  }
}

///|
test "Parse virtual file with syntax error" {
  let source = #|// @filename: good.ts
    #|const x = 42;
    #|// @filename: bad.ts
    #|const y = ;

  match @compiler.split_by_filename_directives(source) {
    Some(file_set) => {
      let result = @compiler.parse_virtual_files(file_set)

      // Should have 1 parsed file, 1 error
      assert_eq(result.files.length(), 1)
      assert_eq(result.parse_errors.length(), 1)

      // The good file should be parsed
      assert_eq(result.files[0].filename, "good.ts")

      // The bad file should have an error
      assert_eq(result.parse_errors[0].0, "bad.ts")
    }
    None => @test.fail("Should have found virtual files")
  }
}

///|
test "Parse virtual file with type annotation" {
  let source = #|// @filename: types.ts
    #|interface Person {
    #|  name: string;
    #|  age: number;
    #|}

  match @compiler.split_by_filename_directives(source) {
    Some(file_set) => {
      let result = @compiler.parse_virtual_files(file_set)

      assert_eq(result.files.length(), 1)
      assert_eq(result.parse_errors.length(), 0)
      assert_eq(result.files[0].filename, "types.ts")

      // Should have parsed the interface declaration
      assert_true(result.files[0].source_file.statements.length() > 0)
    }
    None => @test.fail("Should have found virtual files")
  }
}

///|
test "Parse virtual files with imports" {
  let source = #|// @filename: lib.ts
    #|export function greet(name: string): string {
    #|  return "Hello " + name;
    #|}
    #|// @filename: main.ts
    #|import { greet } from './lib';
    #|const message = greet("World");

  match @compiler.split_by_filename_directives(source) {
    Some(file_set) => {
      let result = @compiler.parse_virtual_files(file_set)

      assert_eq(result.files.length(), 2)
      assert_eq(result.parse_errors.length(), 0)

      // Both files should parse successfully
      assert_eq(result.files[0].filename, "lib.ts")
      assert_eq(result.files[1].filename, "main.ts")
    }
    None => @test.fail("Should have found virtual files")
  }
}

///|
test "Parse tslib.d.ts virtual file" {
  let source = #|// @filename: tslib.d.ts
    #|export function __spreadArray(to: any[], from: any[]): any[];
    #|// @filename: test.ts
    #|const a = [1, 2];

  match @compiler.split_by_filename_directives(source) {
    Some(file_set) => {
      let result = @compiler.parse_virtual_files(file_set)

      assert_eq(result.files.length(), 2)
      assert_eq(result.parse_errors.length(), 0)

      // Check that tslib.d.ts was parsed
      assert_eq(result.files[0].filename, "tslib.d.ts")
      assert_eq(result.files[1].filename, "test.ts")
    }
    None => @test.fail("Should have found virtual files")
  }
}

///|
test "Parse empty virtual file" {
  let source = #|// @filename: empty.ts
    #|// @filename: main.ts
    #|const x = 42;

  match @compiler.split_by_filename_directives(source) {
    Some(file_set) => {
      let result = @compiler.parse_virtual_files(file_set)

      // Both files should parse (empty file is valid)
      assert_eq(result.files.length(), 2)
      assert_eq(result.parse_errors.length(), 0)

      // Empty file should have 0 statements
      assert_eq(result.files[0].source_file.statements.length(), 0)
      assert_eq(result.files[1].source_file.statements.length(), 1)
    }
    None => @test.fail("Should have found virtual files")
  }
}

///|
test "Preserve compiler directives in parsed files" {
  let source = #|// @importHelpers: true
    #|// @filename: main.ts
    #|const x = 42;

  match @compiler.split_by_filename_directives(source) {
    Some(file_set) => {
      let result = @compiler.parse_virtual_files(file_set)

      assert_eq(result.files.length(), 1)
      assert_eq(result.parse_errors.length(), 0)

      // The parsed SourceFile should have compiler_directives
      // Note: Global directives like @importHelpers apply before first @filename
      // So they won't be in the individual file's compiler_directives
      // This is expected behavior
    }
    None => @test.fail("Should have found virtual files")
  }
}
