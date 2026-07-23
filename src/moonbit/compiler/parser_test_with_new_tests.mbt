// Parser Tests
// Tests for the TypeScript parser (token stream -> AST)

// Helper function to create tokens from source

///|
fn tokens_from_source(source : String) -> Array[Token] {
  scan_all_v2(source, "test.ts")
}

///|
test "parse simple identifier" {
  let tokens = tokens_from_source("hello")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.file_path, "test.ts")
      assert_eq(source_file.statements.length(), 1)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse const declaration" {
  let tokens = tokens_from_source("const x = 42;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse let declaration" {
  let tokens = tokens_from_source("let count = 0;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse var declaration" {
  let tokens = tokens_from_source("var flag = true;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse function declaration" {
  let tokens = tokens_from_source("function greet() { }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        FunctionDeclaration(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse async function declaration" {
  let tokens = tokens_from_source("async function fetch() { }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        FunctionDeclaration(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse return statement" {
  let tokens = tokens_from_source("function test() { return 42; }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => assert_eq(source_file.statements.length(), 1)
    Err(_) => assert_true(false)
  }
}

///|
test "parse if statement" {
  let tokens = tokens_from_source("if (true) { }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        IfStatement(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse if-else statement" {
  let tokens = tokens_from_source("if (true) { } else { }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        IfStatement(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse binary expression" {
  let tokens = tokens_from_source("1 + 2")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExpressionStatement(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse complex binary expression" {
  let tokens = tokens_from_source("1 + 2 * 3")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExpressionStatement(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse array literal" {
  let tokens = tokens_from_source("[1, 2, 3]")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExpressionStatement(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse call expression" {
  let tokens = tokens_from_source("console.log(\"hello\")")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExpressionStatement(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse ternary expression" {
  let tokens = tokens_from_source("true ? 1 : 2")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExpressionStatement(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse multiple statements" {
  let tokens = tokens_from_source("const a = 1; const b = 2;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => assert_eq(source_file.statements.length(), 2)
    Err(_) => assert_true(false)
  }
}

///|
test "parse function with parameters" {
  let tokens = tokens_from_source("function add(a, b) { return a + b; }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        FunctionDeclaration(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse nested blocks" {
  let tokens = tokens_from_source("{ { const x = 1; } }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        BlockStatement(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse empty source" {
  let tokens = tokens_from_source("")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 0)
      assert_eq(source_file.file_path, "test.ts")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse while statement" {
  let tokens = tokens_from_source("while (true) { }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        WhileStatement(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse do-while statement" {
  let tokens = tokens_from_source("do { } while (true);")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        DoWhileStatement(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse for statement" {
  let tokens = tokens_from_source("for (let i = 0; i < 10; i++) { }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ForStatement(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse for-in statement" {
  let tokens = tokens_from_source("for (const key in obj) { }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ForInStatement(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse for-of statement" {
  let tokens = tokens_from_source("for (const item of array) { }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ForOfStatement(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse break statement" {
  let tokens = tokens_from_source("while (true) { break; }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => assert_eq(source_file.statements.length(), 1)
    Err(_) => assert_true(false)
  }
}

///|
test "parse continue statement" {
  let tokens = tokens_from_source("while (true) { continue; }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => assert_eq(source_file.statements.length(), 1)
    Err(_) => assert_true(false)
  }
}

///|
test "parse throw statement" {
  let tokens = tokens_from_source("throw x;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ThrowStatement(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse try-catch statement" {
  let tokens = tokens_from_source("try { } catch (e) { }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TryStatement(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse try-finally statement" {
  let tokens = tokens_from_source("try { } finally { }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TryStatement(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse try-catch-finally statement" {
  let tokens = tokens_from_source("try { } catch (e) { } finally { }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TryStatement(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse try-catch without variable" {
  let tokens = tokens_from_source("try { } catch { }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TryStatement(ts) =>
          match ts.catch_clause {
            Some(clause) =>
              // Catch clause should have no variable declaration
              assert_true(clause.variable_declaration is None)
            None => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse try-catch with object destructuring" {
  let tokens = tokens_from_source("try { } catch ({ message, name }) { }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TryStatement(ts) =>
          match ts.catch_clause {
            Some(clause) =>
              match clause.variable_declaration {
                Some(ObjectBindingPattern(pattern)) =>
                  // Should have 2 properties: message and name
                  assert_eq(pattern.properties.length(), 2)
                _ => assert_true(false)
              }
            None => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse try-catch with array destructuring" {
  let tokens = tokens_from_source("try { } catch ([first, second]) { }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TryStatement(ts) =>
          match ts.catch_clause {
            Some(clause) =>
              match clause.variable_declaration {
                Some(ArrayBindingPattern(pattern)) =>
                  // Should have 2 elements: first and second
                  assert_eq(pattern.elements.length(), 2)
                _ => assert_true(false)
              }
            None => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse try-catch with type annotation" {
  let tokens = tokens_from_source("try { } catch (e: unknown) { }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TryStatement(ts) =>
          match ts.catch_clause {
            Some(clause) =>
              match clause.variable_declaration {
                Some(Identifier(id)) =>
                  // Should have identifier 'e'
                  assert_eq(id.name, "e")
                _ => assert_true(false)
              }
            None => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse try-catch with Error type annotation" {
  let tokens = tokens_from_source(
    "try { } catch (err: Error) { console.log(err); }",
  )
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TryStatement(ts) =>
          match ts.catch_clause {
            Some(clause) =>
              match clause.variable_declaration {
                Some(Identifier(id)) => assert_eq(id.name, "err")
                _ => assert_true(false)
              }
            None => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse try-catch with empty parentheses" {
  let tokens = tokens_from_source("try { } catch () { }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TryStatement(ts) =>
          match ts.catch_clause {
            Some(clause) =>
              // Empty catch () should have no variable declaration
              assert_true(clause.variable_declaration is None)
            None => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse nested try-catch" {
  let tokens = tokens_from_source(
    "try { try { } catch (inner) { } } catch (outer) { }",
  )
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TryStatement(ts) =>
          match ts.catch_clause {
            Some(clause) =>
              match clause.variable_declaration {
                Some(Identifier(id)) => assert_eq(id.name, "outer")
                _ => assert_true(false)
              }
            None => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse nested loops" {
  let tokens = tokens_from_source(
    "for (let i = 0; i < 10; i++) { while (true) { break; } }",
  )
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ForStatement(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

// ============ Generic Interface Tests ============

///|
test "parse simple generic interface" {
  let tokens = tokens_from_source("interface Result<T> { data: T; }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        InterfaceDeclaration(decl) => {
          assert_eq(decl.name, "Result")
          // Check type parameters
          assert_eq(decl.type_parameters.length(), 1)
          assert_eq(decl.members.length(), 1)
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse generic interface with optional property" {
  let tokens = tokens_from_source("interface Result<T> { data?: T; }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        InterfaceDeclaration(decl) => {
          assert_eq(decl.name, "Result")
          assert_eq(decl.type_parameters.length(), 1)
          assert_eq(decl.members.length(), 1)
          // Verify the property is marked as optional
          match decl.members[0] {
            PropertyDeclaration(prop) => assert_true(prop.is_optional)
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse generic interface with multiple type parameters" {
  let tokens = tokens_from_source(
    "interface Response<T, E> { data: T; error?: E; }",
  )
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        InterfaceDeclaration(decl) => {
          assert_eq(decl.name, "Response")
          assert_eq(decl.type_parameters.length(), 2)
          assert_eq(decl.members.length(), 2)
          // First property (data) should not be optional
          match decl.members[0] {
            PropertyDeclaration(prop) => {
              assert_eq(prop.name.to_string(), "data")
              assert_true(!(prop.is_optional))
            }
            _ => assert_true(false)
          }
          // Second property (error) should be optional
          match decl.members[1] {
            PropertyDeclaration(prop) => {
              assert_eq(prop.name.to_string(), "error")
              assert_true(prop.is_optional)
            }
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse generic interface with constraint" {
  let tokens = tokens_from_source(
    "interface Container<T extends object> { value: T; }",
  )
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        InterfaceDeclaration(decl) => {
          assert_eq(decl.name, "Container")
          assert_eq(decl.type_parameters.length(), 1)
          // Type parameter should have a constraint
          assert_true(decl.type_parameters[0].constraint is Some(_))
          assert_eq(decl.members.length(), 1)
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse interface with mixed optional and required properties" {
  let tokens = tokens_from_source(
    "interface User { id: number; name: string; email?: string; age?: number; }",
  )
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        InterfaceDeclaration(decl) => {
          assert_eq(decl.name, "User")
          assert_eq(decl.members.length(), 4)
          // id - required
          match decl.members[0] {
            PropertyDeclaration(prop) => assert_true(!(prop.is_optional))
            _ => assert_true(false)
          }
          // name - required
          match decl.members[1] {
            PropertyDeclaration(prop) => assert_true(!(prop.is_optional))
            _ => assert_true(false)
          }
          // email - optional
          match decl.members[2] {
            PropertyDeclaration(prop) => assert_true(prop.is_optional)
            _ => assert_true(false)
          }
          // age - optional
          match decl.members[3] {
            PropertyDeclaration(prop) => assert_true(prop.is_optional)
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse generic interface with default type" {
  let tokens = tokens_from_source("interface Box<T = string> { value: T; }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        InterfaceDeclaration(decl) => {
          assert_eq(decl.name, "Box")
          assert_eq(decl.type_parameters.length(), 1)
          // Type parameter should have a default type
          assert_true(decl.type_parameters[0].default is Some(_))
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse interface extending another interface" {
  let tokens = tokens_from_source(
    "interface Admin extends User { permissions: string[]; }",
  )
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        InterfaceDeclaration(decl) => {
          assert_eq(decl.name, "Admin")
          assert_eq(decl.heritage_clauses.length(), 1)
          assert_eq(decl.members.length(), 1)
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse generic interface with nested generic type" {
  let tokens = tokens_from_source("interface Result<T> { data: Promise<T>; }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        InterfaceDeclaration(decl) => {
          assert_eq(decl.name, "Result")
          assert_eq(decl.type_parameters.length(), 1)
          assert_eq(decl.members.length(), 1)
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse interface with readonly optional property" {
  let tokens = tokens_from_source(
    "interface Config { readonly version?: string; }",
  )
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        InterfaceDeclaration(decl) => {
          assert_eq(decl.name, "Config")
          assert_eq(decl.members.length(), 1)
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse type alias with keyword property names in object type" {
  // Test that keywords like 'string', 'number', 'type' can be used as property names
  let tokens = tokens_from_source(
    "type FieldInfo = { type: string; string: () => string | null; number: number }",
  )
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TypeAliasDeclaration(decl) => {
          assert_eq(decl.name, "FieldInfo")
          // The type should be a TypeLiteral with 3 members
          match decl.type_node {
            TypeLiteral(tl) => assert_eq(tl.members.length(), 3)
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse function with inline object type using keyword property names" {
  // Test the original issue: inline object type with 'string' as property name
  let source =
    #|function typeCast(
    #|  field: {
    #|    type: string
    #|    string: () => string | null
    #|  },
    #|  next: () => void
    #|): void { }
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        FunctionDeclaration(decl) => {
          // Check function name
          match decl.name {
            Some(Identifier(id)) => assert_eq(id.name, "typeCast")
            _ => assert_true(false)
          }
          // Should have 2 parameters
          assert_eq(decl.parameters.length(), 2)
          // First parameter should have an inline object type
          match decl.parameters[0] {
            Parameter(param) =>
              // The type annotation should be a TypeLiteral
              match param.type_annotation {
                Some(TypeLiteral(tl)) =>
                  // Should have 2 properties: type and string
                  assert_eq(tl.members.length(), 2)
                _ => assert_true(false)
              }
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse type with various keyword property names" {
  // Test multiple different keyword property names
  let tokens = tokens_from_source(
    "type KeywordProps = { void: string; null: number; undefined: boolean; never: any }",
  )
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TypeAliasDeclaration(decl) =>
          match decl.type_node {
            TypeLiteral(tl) => assert_eq(tl.members.length(), 4)
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse member access with keyword property names" {
  // Test that keywords can be used as property names in member access expressions
  // e.g., field.type, field.string(), obj.class
  let tokens = tokens_from_source(
    "const x = field.type; const y = field.string(); const z = obj.class;",
  )
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) =>
      // Should have 3 variable statements
      assert_eq(source_file.statements.length(), 3)
    Err(_) => assert_true(false)
  }
}

///|
test "parse super call expression" {
  let tokens = tokens_from_source("super(scope, id, props)")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExpressionStatement(es) =>
          match es.expression {
            CallExpression(ce) =>
              match ce.expression {
                SuperExpression(_) => ()
                _ => assert_true(false)
              }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}
