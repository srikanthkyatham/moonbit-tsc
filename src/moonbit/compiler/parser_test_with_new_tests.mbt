// Parser Tests
// Tests for the TypeScript parser (token stream -> AST)

// Helper function to create tokens from source

///|
fn tokens_from_source(source : String) -> Array[Token] {
  let scanner = Scanner::new(source, "test.ts")
  scan_all(scanner)
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
        TryStatement(ts) => {
          match ts.catch_clause {
            Some(clause) => {
              // Catch clause should have no variable declaration
              assert_true(clause.variable_declaration is None)
            }
            None => assert_true(false)
          }
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
        TryStatement(ts) => {
          match ts.catch_clause {
            Some(clause) => {
              match clause.variable_declaration {
                Some(ObjectBindingPattern(pattern)) => {
                  // Should have 2 properties: message and name
                  assert_eq(pattern.properties.length(), 2)
                }
                _ => assert_true(false)
              }
            }
            None => assert_true(false)
          }
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
        TryStatement(ts) => {
          match ts.catch_clause {
            Some(clause) => {
              match clause.variable_declaration {
                Some(ArrayBindingPattern(pattern)) => {
                  // Should have 2 elements: first and second
                  assert_eq(pattern.elements.length(), 2)
                }
                _ => assert_true(false)
              }
            }
            None => assert_true(false)
          }
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
        TryStatement(ts) => {
          match ts.catch_clause {
            Some(clause) => {
              match clause.variable_declaration {
                Some(Identifier(id)) => {
                  // Should have identifier 'e'
                  assert_eq(id.name, "e")
                }
                _ => assert_true(false)
              }
            }
            None => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse try-catch with Error type annotation" {
  let tokens = tokens_from_source("try { } catch (err: Error) { console.log(err); }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TryStatement(ts) => {
          match ts.catch_clause {
            Some(clause) => {
              match clause.variable_declaration {
                Some(Identifier(id)) => {
                  assert_eq(id.name, "err")
                }
                _ => assert_true(false)
              }
            }
            None => assert_true(false)
          }
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
        TryStatement(ts) => {
          match ts.catch_clause {
            Some(clause) => {
              // Empty catch () should have no variable declaration
              assert_true(clause.variable_declaration is None)
            }
            None => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse nested try-catch" {
  let tokens = tokens_from_source("try { try { } catch (inner) { } } catch (outer) { }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TryStatement(ts) => {
          match ts.catch_clause {
            Some(clause) => {
              match clause.variable_declaration {
                Some(Identifier(id)) => {
                  assert_eq(id.name, "outer")
                }
                _ => assert_true(false)
              }
            }
            None => assert_true(false)
          }
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
