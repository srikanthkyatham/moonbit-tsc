// Unit tests for compiler directive parsing
// Tests @importHelpers, @target, @filename, etc.

///|
test "Parse importHelpers directive" {
  let source = #|// @importHelpers: true
    #|const x = 42;

  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => {
      assert_eq(sf.compiler_directives.import_helpers, true)
    }
    Err(_) => @test.fail("Parse failed")
  }
}

///|
test "Parse target directive" {
  let source = #|// @target: es5
    #|const x = 42;

  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => {
      match sf.compiler_directives.target {
        Some(target) => assert_eq(target, "es5")
        None => @test.fail("Target not parsed")
      }
    }
    Err(_) => @test.fail("Parse failed")
  }
}

///|
test "Parse multiple compiler directives" {
  let source = #|// @importHelpers: true
    #|// @target: es2015
    #|// @noEmit: true
    #|const x = 42;

  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => {
      assert_eq(sf.compiler_directives.import_helpers, true)
      assert_eq(sf.compiler_directives.no_emit, true)
      match sf.compiler_directives.target {
        Some(target) => assert_eq(target, "es2015")
        None => @test.fail("Target not parsed")
      }
    }
    Err(_) => @test.fail("Parse failed")
  }
}

///|
test "Parse filename directive" {
  let source = #|// @filename: main.ts
    #|const x = 42;

  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => {
      match sf.compiler_directives.filename {
        Some(filename) => assert_eq(filename, "main.ts")
        None => @test.fail("Filename not parsed")
      }
    }
    Err(_) => @test.fail("Parse failed")
  }
}

///|
test "Parse isolatedModules directive" {
  let source = #|// @isolatedModules: true
    #|const x = 42;

  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => {
      assert_eq(sf.compiler_directives.isolated_modules, true)
    }
    Err(_) => @test.fail("Parse failed")
  }
}

///|
test "Parse noTypesAndSymbols directive" {
  let source = #|// @noTypesAndSymbols: true
    #|const x = 42;

  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => {
      assert_eq(sf.compiler_directives.no_types_and_symbols, true)
    }
    Err(_) => @test.fail("Parse failed")
  }
}

///|
test "Default directives when none specified" {
  let source = "const x = 42;"

  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => {
      assert_eq(sf.compiler_directives.import_helpers, false)
      assert_eq(sf.compiler_directives.no_emit, false)
      assert_eq(sf.compiler_directives.isolated_modules, false)
      assert_eq(sf.compiler_directives.no_types_and_symbols, false)
      match sf.compiler_directives.target {
        None => ()
        Some(_) => @test.fail("Target should be None")
      }
      match sf.compiler_directives.filename {
        None => ()
        Some(_) => @test.fail("Filename should be None")
      }
    }
    Err(_) => @test.fail("Parse failed")
  }
}

///|
test "Parse boolean directive without spaces" {
  let source = #|//@importHelpers:true
    #|const x = 42;

  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => {
      assert_eq(sf.compiler_directives.import_helpers, true)
    }
    Err(_) => @test.fail("Parse failed")
  }
}
