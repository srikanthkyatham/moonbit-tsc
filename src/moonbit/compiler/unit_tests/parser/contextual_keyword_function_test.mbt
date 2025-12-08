// Parser Tests - Contextual Keywords as Function Names
// Tests for allowing contextual keywords (from, as, of, await, yield) as function names
// Related to fix in commit: "fix: Allow contextual keywords as function names (partial fix)"

///|
/// Helper function to create tokens from source
fn tokens_from_source(source : String) -> Array[@compiler.Token] {
  @compiler.scan_all_v2(source, "test.ts")
}

///|
/// Helper to extract function name from FunctionDeclaration
fn get_function_name(node : @compiler.Node) -> String? {
  match node {
    @compiler.FunctionDeclaration(fd) =>
      match fd.name {
        Some(@compiler.Identifier(id)) => Some(id.name)
        _ => None
      }
    _ => None
  }
}

// ============================================================================
// Test: Contextual keyword "from" as function name
// ============================================================================

///|
test "parse function declaration with name 'from'" {
  let source = "function from() {}"
  let tokens = tokens_from_source(source)
  let result = @compiler.parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        @compiler.FunctionDeclaration(_) => {
          let name = get_function_name(source_file.statements[0])
          assert_eq(name, Some("from"))
        }
        _ => @test.fail("expected FunctionDeclaration")
      }
    }
    Err(_) => @test.fail("parse should succeed")
  }
}

///|
test "parse function declaration with name 'from' and type parameters" {
  let source = "function from<T>() {}"
  let tokens = tokens_from_source(source)
  let result = @compiler.parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        @compiler.FunctionDeclaration(fd) => {
          let name = get_function_name(source_file.statements[0])
          assert_eq(name, Some("from"))
          assert_eq(fd.type_parameters.length(), 1)
        }
        _ => @test.fail("expected FunctionDeclaration")
      }
    }
    Err(_) => @test.fail("parse should succeed")
  }
}

///|
test "parse function declaration with name 'from' and parameters" {
  let source = "function from(x: number): string { return 'hello'; }"
  let tokens = tokens_from_source(source)
  let result = @compiler.parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        @compiler.FunctionDeclaration(fd) => {
          let name = get_function_name(source_file.statements[0])
          assert_eq(name, Some("from"))
          assert_eq(fd.parameters.length(), 1)
          assert_true(fd.return_type is Some(_))
        }
        _ => @test.fail("expected FunctionDeclaration")
      }
    }
    Err(_) => @test.fail("parse should succeed")
  }
}

// ============================================================================
// Test: Contextual keyword "as" as function name
// ============================================================================

///|
test "parse function declaration with name 'as'" {
  let source = "function as() {}"
  let tokens = tokens_from_source(source)
  let result = @compiler.parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      let name = get_function_name(source_file.statements[0])
      assert_eq(name, Some("as"))
    }
    Err(_) => @test.fail("parse should succeed")
  }
}

///|
test "parse function declaration with name 'as' and type parameters" {
  let source = "function as<T, U>(x: T): U { return x as any as U; }"
  let tokens = tokens_from_source(source)
  let result = @compiler.parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        @compiler.FunctionDeclaration(fd) => {
          let name = get_function_name(source_file.statements[0])
          assert_eq(name, Some("as"))
          assert_eq(fd.type_parameters.length(), 2)
        }
        _ => @test.fail("expected FunctionDeclaration")
      }
    }
    Err(_) => @test.fail("parse should succeed")
  }
}

// ============================================================================
// Test: Contextual keyword "of" as function name
// ============================================================================

///|
test "parse function declaration with name 'of'" {
  let source = "function of() {}"
  let tokens = tokens_from_source(source)
  let result = @compiler.parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      let name = get_function_name(source_file.statements[0])
      assert_eq(name, Some("of"))
    }
    Err(_) => @test.fail("parse should succeed")
  }
}

///|
test "parse function declaration with name 'of' and rest parameters" {
  let source = "function of<T>(...items: T[]): T[] { return items; }"
  let tokens = tokens_from_source(source)
  let result = @compiler.parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        @compiler.FunctionDeclaration(fd) => {
          let name = get_function_name(source_file.statements[0])
          assert_eq(name, Some("of"))
          assert_eq(fd.type_parameters.length(), 1)
          assert_eq(fd.parameters.length(), 1)
        }
        _ => @test.fail("expected FunctionDeclaration")
      }
    }
    Err(_) => @test.fail("parse should succeed")
  }
}

// ============================================================================
// Test: Contextual keyword "await" as function name
// ============================================================================

///|
test "parse function declaration with name 'await'" {
  let source = "function await() {}"
  let tokens = tokens_from_source(source)
  let result = @compiler.parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      let name = get_function_name(source_file.statements[0])
      assert_eq(name, Some("await"))
    }
    Err(_) => @test.fail("parse should succeed")
  }
}

///|
test "parse async function declaration with name 'await'" {
  let source = "async function await() {}"
  let tokens = tokens_from_source(source)
  let result = @compiler.parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        @compiler.FunctionDeclaration(fd) => {
          let name = get_function_name(source_file.statements[0])
          assert_eq(name, Some("await"))
          assert_true(fd.is_async)
        }
        _ => @test.fail("expected FunctionDeclaration")
      }
    }
    Err(_) => @test.fail("parse should succeed")
  }
}

// ============================================================================
// Test: Contextual keyword "yield" as function name
// ============================================================================

///|
test "parse function declaration with name 'yield'" {
  let source = "function yield() {}"
  let tokens = tokens_from_source(source)
  let result = @compiler.parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      let name = get_function_name(source_file.statements[0])
      assert_eq(name, Some("yield"))
    }
    Err(_) => @test.fail("parse should succeed")
  }
}

///|
test "parse generator function declaration with name 'yield'" {
  let source = "function* yield() {}"
  let tokens = tokens_from_source(source)
  let result = @compiler.parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        @compiler.FunctionDeclaration(fd) => {
          let name = get_function_name(source_file.statements[0])
          assert_eq(name, Some("yield"))
          assert_true(fd.is_generator)
        }
        _ => @test.fail("expected FunctionDeclaration")
      }
    }
    Err(_) => @test.fail("parse should succeed")
  }
}

// ============================================================================
// Test: Other contextual keywords that should work as function names
// ============================================================================

///|
test "parse function declaration with name 'declare'" {
  let source = "function declare() {}"
  let tokens = tokens_from_source(source)
  let result = @compiler.parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      let name = get_function_name(source_file.statements[0])
      assert_eq(name, Some("declare"))
    }
    Err(_) => @test.fail("parse should succeed")
  }
}

///|
test "parse function declaration with name 'async'" {
  let source = "function async() {}"
  let tokens = tokens_from_source(source)
  let result = @compiler.parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      let name = get_function_name(source_file.statements[0])
      assert_eq(name, Some("async"))
    }
    Err(_) => @test.fail("parse should succeed")
  }
}

///|
test "parse function declaration with name 'using'" {
  let source = "function using() {}"
  let tokens = tokens_from_source(source)
  let result = @compiler.parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      let name = get_function_name(source_file.statements[0])
      assert_eq(name, Some("using"))
    }
    Err(_) => @test.fail("parse should succeed")
  }
}

///|
test "parse function declaration with name 'type'" {
  let source = "function type() {}"
  let tokens = tokens_from_source(source)
  let result = @compiler.parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      let name = get_function_name(source_file.statements[0])
      assert_eq(name, Some("type"))
    }
    Err(_) => @test.fail("parse should succeed")
  }
}

///|
test "parse function declaration with name 'readonly'" {
  let source = "function readonly() {}"
  let tokens = tokens_from_source(source)
  let result = @compiler.parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      let name = get_function_name(source_file.statements[0])
      assert_eq(name, Some("readonly"))
    }
    Err(_) => @test.fail("parse should succeed")
  }
}

// ============================================================================
// Test: Multiple functions with contextual keyword names
// ============================================================================

///|
test "parse multiple function declarations with contextual keyword names" {
  let source = "function from() {}\nfunction as() {}\nfunction of() {}"
  let tokens = tokens_from_source(source)
  let result = @compiler.parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 3)
      let name1 = get_function_name(source_file.statements[0])
      let name2 = get_function_name(source_file.statements[1])
      let name3 = get_function_name(source_file.statements[2])
      assert_eq(name1, Some("from"))
      assert_eq(name2, Some("as"))
      assert_eq(name3, Some("of"))
    }
    Err(_) => @test.fail("parse should succeed")
  }
}

// ============================================================================
// Test: Contextual keywords after type alias (original bug scenario)
// ============================================================================

///|
test "parse function with contextual keyword name after type alias" {
  let source = "type A = { x: number }\nfunction from() {}"
  let tokens = tokens_from_source(source)
  let result = @compiler.parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 2)

      // First statement should be TypeAliasDeclaration
      match source_file.statements[0] {
        @compiler.TypeAliasDeclaration(_) => ()
        _ => @test.fail("expected TypeAliasDeclaration")
      }

      // Second statement should be FunctionDeclaration with name "from"
      let name = get_function_name(source_file.statements[1])
      assert_eq(name, Some("from"))
    }
    Err(_) => @test.fail("parse should succeed")
  }
}

///|
test "parse function with contextual keyword name and generic params after type alias" {
  let source = "type InteropObservable<T> = { subscribe(): void }\nfunction from<T>(obs: InteropObservable<T>) {}"
  let tokens = tokens_from_source(source)
  let result = @compiler.parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 2)

      // Second statement should be FunctionDeclaration with name "from"
      match source_file.statements[1] {
        @compiler.FunctionDeclaration(fd) => {
          let name = get_function_name(source_file.statements[1])
          assert_eq(name, Some("from"))
          assert_eq(fd.type_parameters.length(), 1)
          assert_eq(fd.parameters.length(), 1)
        }
        _ => @test.fail("expected FunctionDeclaration")
      }
    }
    Err(_) => @test.fail("parse should succeed")
  }
}

// ============================================================================
// Test: Regular function names still work (regression test)
// ============================================================================

///|
test "parse function declaration with regular name" {
  let source = "function myFunction() {}"
  let tokens = tokens_from_source(source)
  let result = @compiler.parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      let name = get_function_name(source_file.statements[0])
      assert_eq(name, Some("myFunction"))
    }
    Err(_) => @test.fail("parse should succeed")
  }
}

///|
test "parse function declaration with regular name and complex signature" {
  let source = "function processData<T, U>(input: T, mapper: (x: T) => U): U[] { return []; }"
  let tokens = tokens_from_source(source)
  let result = @compiler.parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        @compiler.FunctionDeclaration(fd) => {
          let name = get_function_name(source_file.statements[0])
          assert_eq(name, Some("processData"))
          assert_eq(fd.type_parameters.length(), 2)
          assert_eq(fd.parameters.length(), 2)
        }
        _ => @test.fail("expected FunctionDeclaration")
      }
    }
    Err(_) => @test.fail("parse should succeed")
  }
}

///|
test "parse anonymous function expression" {
  let source = "const f = function() {}"
  let tokens = tokens_from_source(source)
  let result = @compiler.parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      // Should parse as variable statement containing function expression
      match source_file.statements[0] {
        @compiler.VariableStatement(_) => ()
        _ => @test.fail("expected VariableStatement")
      }
    }
    Err(_) => @test.fail("parse should succeed")
  }
}
