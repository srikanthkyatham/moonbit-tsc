// Unit tests for virtual file splitting by @filename directives
// Tests split_by_filename_directives() function

///|
test "Split by filename directives - two files" {
  let source = #|// @filename: file1.ts
    #|const x = 42;
    #|// @filename: file2.ts
    #|const y = 100;

  match @compiler.split_by_filename_directives(source) {
    Some(file_set) => {
      assert_eq(file_set.files.length(), 2)
      assert_eq(file_set.files[0].filename, "file1.ts")
      assert_eq(file_set.files[1].filename, "file2.ts")
      assert_true(file_set.files[0].content.contains("const x = 42"))
      assert_true(file_set.files[1].content.contains("const y = 100"))
    }
    None => @test.fail("Should have found virtual files")
  }
}

///|
test "No @filename directives returns None" {
  let source = "const x = 42;"

  match @compiler.split_by_filename_directives(source) {
    None => () // Expected
    Some(_) => @test.fail("Should return None when no @filename directives")
  }
}

///|
test "Single @filename directive" {
  let source = #|// @filename: main.ts
    #|const x = 42;
    #|const y = 100;

  match @compiler.split_by_filename_directives(source) {
    Some(file_set) => {
      assert_eq(file_set.files.length(), 1)
      assert_eq(file_set.files[0].filename, "main.ts")
      assert_true(file_set.files[0].content.contains("const x = 42"))
      assert_true(file_set.files[0].content.contains("const y = 100"))
    }
    None => @test.fail("Should have found one virtual file")
  }
}

///|
test "Lines before first @filename are ignored" {
  let source = #|const ignored = 1;
    #|// @filename: main.ts
    #|const x = 42;

  match @compiler.split_by_filename_directives(source) {
    Some(file_set) => {
      assert_eq(file_set.files.length(), 1)
      assert_false(file_set.files[0].content.contains("ignored"))
      assert_true(file_set.files[0].content.contains("const x = 42"))
    }
    None => @test.fail("Should have found virtual file")
  }
}

///|
test "Empty content between @filename directives" {
  let source = #|// @filename: file1.ts
    #|// @filename: file2.ts
    #|const x = 42;

  match @compiler.split_by_filename_directives(source) {
    Some(file_set) => {
      assert_eq(file_set.files.length(), 2)
      // file1 should have empty or minimal content
      assert_eq(file_set.files[0].content.length() <= 1, true)
      // file2 should have the constant
      assert_true(file_set.files[1].content.contains("const x = 42"))
    }
    None => @test.fail("Should have found virtual files")
  }
}

///|
test "Multiple files with different content" {
  let source = #|// @filename: types.ts
    #|interface Foo { x: number; }
    #|// @filename: impl.ts
    #|const foo: Foo = { x: 42 };
    #|// @filename: test.ts
    #|console.log(foo.x);

  match @compiler.split_by_filename_directives(source) {
    Some(file_set) => {
      assert_eq(file_set.files.length(), 3)
      assert_true(file_set.files[0].content.contains("interface Foo"))
      assert_true(file_set.files[1].content.contains("const foo: Foo"))
      assert_true(file_set.files[2].content.contains("console.log"))
    }
    None => @test.fail("Should have found 3 virtual files")
  }
}

///|
test "Filename with spaces in value" {
  let source = #|// @filename:   main.ts
    #|const x = 42;

  match @compiler.split_by_filename_directives(source) {
    Some(file_set) => {
      assert_eq(file_set.files.length(), 1)
      // Filename should have spaces trimmed (based on our implementation)
      let filename = file_set.files[0].filename
      assert_true(filename.contains("main.ts"))
    }
    None => @test.fail("Should have found virtual file")
  }
}

///|
test "Track start line numbers" {
  let source = #|// Line 1
    #|// Line 2
    #|// @filename: file1.ts
    #|const x = 42;
    #|// @filename: file2.ts
    #|const y = 100;

  match @compiler.split_by_filename_directives(source) {
    Some(file_set) => {
      assert_eq(file_set.files.length(), 2)
      // First file starts at line 4 (line 3 is @filename directive)
      assert_eq(file_set.files[0].start_line, 4)
      // Second file starts at line 6 (line 5 is @filename directive)
      assert_eq(file_set.files[1].start_line, 6)
    }
    None => @test.fail("Should have found virtual files")
  }
}

///|
test "Filename directive with alternative spacing" {
  let source = #|// @filename : alt.ts
    #|const x = 42;

  match @compiler.split_by_filename_directives(source) {
    Some(file_set) => {
      assert_eq(file_set.files.length(), 1)
      assert_true(file_set.files[0].filename.contains("alt.ts"))
    }
    None => @test.fail("Should have found virtual file")
  }
}
