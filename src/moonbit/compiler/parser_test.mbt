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

// ============================================================================
// Import Declaration Tests
// ============================================================================

///|
test "parse default import" {
  let tokens = tokens_from_source("import foo from 'module';")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ImportDeclaration(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse named import" {
  let tokens = tokens_from_source("import { a, b } from 'module';")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ImportDeclaration(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse named import with alias" {
  let tokens = tokens_from_source("import { a as b } from 'module';")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ImportDeclaration(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse namespace import" {
  let tokens = tokens_from_source("import * as foo from 'module';")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ImportDeclaration(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse mixed import" {
  let tokens = tokens_from_source("import foo, { a, b } from 'module';")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ImportDeclaration(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse side-effect import" {
  let tokens = tokens_from_source("import 'module';")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ImportDeclaration(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Export Declaration Tests
// ============================================================================

///|
test "parse named export" {
  let tokens = tokens_from_source("export { a, b };")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExportDeclaration(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse named export with alias" {
  let tokens = tokens_from_source("export { a as b };")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExportDeclaration(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse re-export" {
  let tokens = tokens_from_source("export { a } from 'module';")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExportDeclaration(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse export all" {
  let tokens = tokens_from_source("export * from 'module';")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExportDeclaration(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse export default" {
  let tokens = tokens_from_source("export default 42;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExportAssignment(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse export const" {
  let tokens = tokens_from_source("export const x = 1;")
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

// ============================================================================
// Class Declaration Tests
// ============================================================================

///|
test "parse empty class" {
  let tokens = tokens_from_source("class Foo {}")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ClassDeclaration(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse class with extends" {
  let tokens = tokens_from_source("class Foo extends Bar {}")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ClassDeclaration(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse class with implements" {
  let tokens = tokens_from_source("class Foo implements IBar {}")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ClassDeclaration(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse class with constructor" {
  let tokens = tokens_from_source("class Foo { constructor() {} }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ClassDeclaration(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse class with method" {
  let tokens = tokens_from_source("class Foo { bar() {} }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ClassDeclaration(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse class with property" {
  let tokens = tokens_from_source("class Foo { bar; }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ClassDeclaration(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Interface Declaration Tests
// ============================================================================

///|
test "parse empty interface" {
  let tokens = tokens_from_source("interface IFoo {}")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        InterfaceDeclaration(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse interface with extends" {
  let tokens = tokens_from_source("interface IFoo extends IBar {}")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        InterfaceDeclaration(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse interface with multiple extends" {
  let tokens = tokens_from_source("interface IFoo extends IBar, IBaz {}")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        InterfaceDeclaration(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Enum Declaration Tests
// ============================================================================

///|
test "parse empty enum" {
  let tokens = tokens_from_source("enum Color {}")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        EnumDeclaration(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse enum with members" {
  let tokens = tokens_from_source("enum Color { Red, Green, Blue }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        EnumDeclaration(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse enum with initializers" {
  let tokens = tokens_from_source("enum Flags { None = 0, A = 1, B = 2 }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        EnumDeclaration(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Type Alias Declaration Tests
// ============================================================================

///|
test "parse simple type alias" {
  let tokens = tokens_from_source("type Foo = Bar;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TypeAliasDeclaration(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse string literal type" {
  let tokens = tokens_from_source("type Status = \"active\";")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TypeAliasDeclaration(type_alias) => {
          match type_alias.type_node {
            LiteralType(literal) => {
              match literal.literal {
                StringLiteral(_) => ()
                _ => assert_true(false)
              }
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
test "parse numeric literal type" {
  let tokens = tokens_from_source("type Answer = 42;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TypeAliasDeclaration(type_alias) => {
          match type_alias.type_node {
            LiteralType(literal) => {
              match literal.literal {
                NumericLiteral(_) => ()
                _ => assert_true(false)
              }
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
test "parse boolean literal type true" {
  let tokens = tokens_from_source("type AlwaysTrue = true;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TypeAliasDeclaration(type_alias) => {
          match type_alias.type_node {
            LiteralType(literal) => {
              match literal.literal {
                BooleanLiteral(bool) => assert_eq(bool.value, true)
                _ => assert_true(false)
              }
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
test "parse boolean literal type false" {
  let tokens = tokens_from_source("type AlwaysFalse = false;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TypeAliasDeclaration(type_alias) => {
          match type_alias.type_node {
            LiteralType(literal) => {
              match literal.literal {
                BooleanLiteral(bool) => assert_eq(bool.value, false)
                _ => assert_true(false)
              }
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
test "parse string literal union type" {
  let tokens = tokens_from_source("type Status = \"active\" | \"inactive\" | \"pending\";")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TypeAliasDeclaration(type_alias) => {
          match type_alias.type_node {
            UnionType(union) => {
              assert_eq(union.types.length(), 3)
              // Check that all are literal types
              for i = 0; i < union.types.length(); i = i + 1 {
                match union.types[i] {
                  LiteralType(literal) => {
                    match literal.literal {
                      StringLiteral(_) => ()
                      _ => assert_true(false)
                    }
                  }
                  _ => assert_true(false)
                }
              }
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
test "parse generic interface" {
  let tokens = tokens_from_source("interface Result<T, E> { value: T; error: E; }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        InterfaceDeclaration(iface) => {
          assert_eq(iface.name, "Result")
          assert_eq(iface.type_parameters.length(), 2)
          assert_eq(iface.type_parameters[0].name, "T")
          assert_eq(iface.type_parameters[1].name, "E")
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse arrow function type" {
  let tokens = tokens_from_source("type Handler = (event: string) => void;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TypeAliasDeclaration(type_alias) => {
          assert_eq(type_alias.name, "Handler")
          match type_alias.type_node {
            FunctionType(func_type) => {
              assert_eq(func_type.parameters.length(), 1)
              // Verify it's a function type with void return
              match func_type.return_type {
                KeywordType(keyword) => {
                  match keyword.kind {
                    Void => ()
                    _ => assert_true(false)
                  }
                }
                _ => assert_true(false)
              }
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
test "parse const enum" {
  let tokens = tokens_from_source("const enum Direction { Up, Down, Left, Right }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        EnumDeclaration(enum_decl) => {
          assert_eq(enum_decl.name, "Direction")
          assert_eq(enum_decl.is_const, true)
          assert_eq(enum_decl.members.length(), 4)
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse arrow function with return type annotation" {
  let tokens = tokens_from_source("const square = (x: number): number => x * x;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(var_stmt) => {
          assert_eq(var_stmt.declarations.length(), 1)
          let decl = var_stmt.declarations[0]
          match decl.initializer {
            Some(ArrowFunction(arrow)) => {
              assert_eq(arrow.parameters.length(), 1)
              // Verify return type is present
              match arrow.return_type {
                Some(_) => ()
                None => assert_true(false)
              }
            }
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
test "parse method call callback with arrow function" {
  let tokens = tokens_from_source("const doubled = numbers.map(x => x * 2);")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(_) => {
      // Just verify it parses successfully
      assert_true(true)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

// ============================================================================
// Switch Statement Tests
// ============================================================================

///|
test "parse empty switch" {
  let tokens = tokens_from_source("switch (x) {}")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        SwitchStatement(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse switch with case" {
  let tokens = tokens_from_source("switch (x) { case 1: break; }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        SwitchStatement(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse switch with default" {
  let tokens = tokens_from_source("switch (x) { default: break; }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        SwitchStatement(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse switch with multiple cases" {
  let tokens = tokens_from_source("switch (x) { case 1: return a; case 2: return b; default: return c; }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        SwitchStatement(_) => ()
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

// ===== Advanced Type System Tests =====

///|
test "parse indexed access type" {
  let tokens = tokens_from_source("type Name = Person['name'];")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TypeAliasDeclaration(decl) => {
          match decl.type_node {
            IndexedAccessType(_) => ()
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
test "parse indexed access with generic type" {
  let tokens = tokens_from_source("type Value<T, K> = T[K];")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TypeAliasDeclaration(decl) => {
          match decl.type_node {
            IndexedAccessType(_) => ()
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
test "parse conditional type" {
  let tokens = tokens_from_source("type IsString<T> = T extends string ? string : number;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TypeAliasDeclaration(decl) => {
          match decl.type_node {
            ConditionalType(_) => ()
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
test "parse conditional type with complex extends" {
  let tokens = tokens_from_source("type NonNullable<T> = T extends number ? string : T;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TypeAliasDeclaration(decl) => {
          match decl.type_node {
            ConditionalType(_) => ()
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
test "parse mapped type" {
  let tokens = tokens_from_source("type MyMap<K, T> = { [P in K]: T };")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TypeAliasDeclaration(decl) => {
          match decl.type_node {
            MappedType(_) => ()
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
test "parse mapped type with simple constraint" {
  let tokens = tokens_from_source("type MyMap<K> = { [P in K]: string };")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TypeAliasDeclaration(decl) => {
          match decl.type_node {
            MappedType(_) => ()
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

// ===== Type Assertion Expression Tests =====

///|
test "parse non-null assertion" {
  let tokens = tokens_from_source("const x = getValue()!;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(stmt) => {
          match stmt.declarations[0].initializer {
            Some(NonNullExpression(_)) => ()
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
test "parse non-null assertion on property access" {
  let tokens = tokens_from_source("const x = obj.property!;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(stmt) => {
          match stmt.declarations[0].initializer {
            Some(NonNullExpression(_)) => ()
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
test "parse as expression" {
  let tokens = tokens_from_source("const x = value as string;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(stmt) => {
          match stmt.declarations[0].initializer {
            Some(AsExpression(_)) => ()
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
test "parse as expression with complex type" {
  let tokens = tokens_from_source("const x = getValue() as Array[number];")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(stmt) => {
          match stmt.declarations[0].initializer {
            Some(AsExpression(_)) => ()
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
test "parse type assertion with angle brackets" {
  let tokens = tokens_from_source("const x = <string>getValue();")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(stmt) => {
          match stmt.declarations[0].initializer {
            Some(TypeAssertionExpression(_)) => ()
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
test "parse type assertion with complex type" {
  let tokens = tokens_from_source("const x = <Array[string]>getArray();")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(stmt) => {
          match stmt.declarations[0].initializer {
            Some(TypeAssertionExpression(_)) => ()
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
test "parse chained type assertions" {
  let tokens = tokens_from_source("const x = (value as any) as string;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(stmt) => {
          match stmt.declarations[0].initializer {
            Some(AsExpression(_)) => ()
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
test "parse combined non-null and as assertion" {
  let tokens = tokens_from_source("const x = getValue()! as string;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(stmt) => {
          match stmt.declarations[0].initializer {
            Some(AsExpression(ae)) => {
              match ae.expression {
                NonNullExpression(_) => ()
                _ => assert_true(false)
              }
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

// ============================================================================
// New Parser Feature Tests
// ============================================================================

// Unknown/Never Type Tests

///|
test "parse unknown type annotation" {
  let tokens = tokens_from_source("const x: unknown = null;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(stmt) => {
          match stmt.declarations[0].type_annotation {
            Some(KeywordType(kt)) => {
              match kt.kind {
                TypeKeyword::Unknown => ()
                _ => assert_true(false)
              }
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
test "parse never type annotation" {
  let tokens = tokens_from_source("function fail(): never { throw new Error(); }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        FunctionDeclaration(func) => {
          match func.return_type {
            Some(KeywordType(kt)) => {
              match kt.kind {
                TypeKeyword::Never => ()
                _ => assert_true(false)
              }
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

// Optional Chaining Tests

///|
test "parse optional property access" {
  let tokens = tokens_from_source("const x = obj?.prop;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(stmt) => {
          match stmt.declarations[0].initializer {
            Some(OptionalChain(_)) => ()
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
test "parse optional call expression" {
  let tokens = tokens_from_source("const x = func?.();")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(stmt) => {
          match stmt.declarations[0].initializer {
            Some(OptionalChain(_)) => ()
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
test "parse optional element access" {
  let tokens = tokens_from_source("const x = arr?.[0];")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(stmt) => {
          match stmt.declarations[0].initializer {
            Some(OptionalChain(_)) => ()
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

// Abstract Class Tests

///|
test "parse abstract class declaration" {
  let tokens = tokens_from_source("abstract class Animal { }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ClassDeclaration(cls) => {
          assert_true(cls.is_abstract)
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse non-abstract class declaration" {
  let tokens = tokens_from_source("class Dog { }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ClassDeclaration(cls) => {
          assert_true(not(cls.is_abstract))
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

// Await Expression Tests

///|
test "parse await expression" {
  let tokens = tokens_from_source("async function fetch() { const data = await getData(); }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        FunctionDeclaration(func) => {
          assert_true(func.is_async)
          match func.body {
            Some(BlockStatement(block)) => {
              assert_eq(block.statements.length(), 1)
              match block.statements[0] {
                VariableStatement(stmt) => {
                  match stmt.declarations[0].initializer {
                    Some(AwaitExpression(_)) => ()
                    _ => assert_true(false)
                  }
                }
                _ => assert_true(false)
              }
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

// Yield Expression Tests

///|
test "parse yield expression" {
  let tokens = tokens_from_source("function* gen() { yield 1; }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        FunctionDeclaration(func) => {
          assert_true(func.is_generator)
          match func.body {
            Some(BlockStatement(block)) => {
              assert_eq(block.statements.length(), 1)
              match block.statements[0] {
                ExpressionStatement(stmt) => {
                  match stmt.expression {
                    YieldExpression(ye) => {
                      assert_true(not(ye.is_delegate))
                    }
                    _ => assert_true(false)
                  }
                }
                _ => assert_true(false)
              }
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
test "parse yield delegate expression" {
  let tokens = tokens_from_source("function* gen() { yield* other(); }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        FunctionDeclaration(func) => {
          assert_true(func.is_generator)
          match func.body {
            Some(BlockStatement(block)) => {
              match block.statements[0] {
                ExpressionStatement(stmt) => {
                  match stmt.expression {
                    YieldExpression(ye) => {
                      assert_true(ye.is_delegate)
                    }
                    _ => assert_true(false)
                  }
                }
                _ => assert_true(false)
              }
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

// Generator Function Tests

///|
test "parse generator function declaration" {
  let tokens = tokens_from_source("function* generate() { }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        FunctionDeclaration(func) => {
          assert_true(func.is_generator)
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

// Decorator Tests

///|
test "parse class with simple decorator" {
  let tokens = tokens_from_source("@Component class MyClass { }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ClassDeclaration(cls) => {
          assert_eq(cls.decorators.length(), 1)
          match cls.decorators[0] {
            Decorator(_) => ()
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
test "parse class with decorator factory" {
  let tokens = tokens_from_source("@Injectable() class Service { }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ClassDeclaration(cls) => {
          assert_eq(cls.decorators.length(), 1)
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse class with multiple decorators" {
  let tokens = tokens_from_source("@Component @Serializable class Entity { }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ClassDeclaration(cls) => {
          assert_eq(cls.decorators.length(), 2)
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

// Namespace/Module Tests

///|
test "parse namespace declaration" {
  let tokens = tokens_from_source("namespace MyNamespace { }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ModuleDeclaration(mod_decl) => {
          assert_eq(mod_decl.name, "MyNamespace")
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse module declaration" {
  let tokens = tokens_from_source("module MyModule { }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ModuleDeclaration(mod_decl) => {
          assert_eq(mod_decl.name, "MyModule")
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse namespace with content" {
  let tokens = tokens_from_source("namespace Utils { const PI = 3.14; }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ModuleDeclaration(mod_decl) => {
          assert_eq(mod_decl.name, "Utils")
          match mod_decl.body {
            Some(BlockStatement(block)) => {
              assert_eq(block.statements.length(), 1)
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
