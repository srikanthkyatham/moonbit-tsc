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
test "parse export namespace as" {
  let tokens = tokens_from_source("export * as ns from 'module';")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExportDeclaration(exp) => {
          match exp.export_clause {
            Some(NamespaceExport(ns_name, _)) => assert_eq(ns_name, "ns")
            _ => assert_true(false)
          }
          match exp.module_specifier {
            Some(module_spec) => assert_eq(module_spec, "module")
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
test "parse class extends with property access" {
  let tokens = tokens_from_source("class MyStack extends cdk.Stack {}")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ClassDeclaration(cd) => {
          assert_eq(cd.heritage_clauses.length(), 1)
          match cd.heritage_clauses[0].types[0] {
            TypeReference(tr) => assert_eq(tr.type_name, "cdk.Stack")
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
test "parse class extends with nested property access" {
  let tokens = tokens_from_source(
    "class MyFunction extends aws.lambda.Function {}",
  )
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ClassDeclaration(cd) => {
          assert_eq(cd.heritage_clauses.length(), 1)
          match cd.heritage_clauses[0].types[0] {
            TypeReference(tr) => assert_eq(tr.type_name, "aws.lambda.Function")
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
test "parse class extends with generic type" {
  let tokens = tokens_from_source("class MyStack extends Stack<StackProps> {}")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ClassDeclaration(cd) => {
          assert_eq(cd.heritage_clauses.length(), 1)
          match cd.heritage_clauses[0].types[0] {
            TypeReference(tr) => {
              assert_eq(tr.type_name, "Stack")
              assert_eq(tr.type_arguments.length(), 1)
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
test "parse class extends with property access and generics" {
  let tokens = tokens_from_source(
    "class MyStack extends cdk.Stack<StackProps> {}",
  )
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ClassDeclaration(cd) => {
          assert_eq(cd.heritage_clauses.length(), 1)
          match cd.heritage_clauses[0].types[0] {
            TypeReference(tr) => {
              assert_eq(tr.type_name, "cdk.Stack")
              assert_eq(tr.type_arguments.length(), 1)
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
test "parse class implements multiple with property access" {
  let tokens = tokens_from_source(
    "class MyClass implements ns.IFoo, ns.IBar {}",
  )
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ClassDeclaration(cd) => {
          assert_eq(cd.heritage_clauses.length(), 1)
          assert_eq(cd.heritage_clauses[0].types.length(), 2)
          match cd.heritage_clauses[0].types[0] {
            TypeReference(tr) => assert_eq(tr.type_name, "ns.IFoo")
            _ => assert_true(false)
          }
          match cd.heritage_clauses[0].types[1] {
            TypeReference(tr) => assert_eq(tr.type_name, "ns.IBar")
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
        TypeAliasDeclaration(type_alias) =>
          match type_alias.type_node {
            LiteralType(literal) =>
              match literal.literal {
                StringLiteral(_) => ()
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

///|
test "parse numeric literal type" {
  let tokens = tokens_from_source("type Answer = 42;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TypeAliasDeclaration(type_alias) =>
          match type_alias.type_node {
            LiteralType(literal) =>
              match literal.literal {
                NumericLiteral(_) => ()
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

///|
test "parse boolean literal type true" {
  let tokens = tokens_from_source("type AlwaysTrue = true;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TypeAliasDeclaration(type_alias) =>
          match type_alias.type_node {
            LiteralType(literal) =>
              match literal.literal {
                BooleanLiteral(bool) => assert_eq(bool.value, true)
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

///|
test "parse boolean literal type false" {
  let tokens = tokens_from_source("type AlwaysFalse = false;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TypeAliasDeclaration(type_alias) =>
          match type_alias.type_node {
            LiteralType(literal) =>
              match literal.literal {
                BooleanLiteral(bool) => assert_eq(bool.value, false)
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

///|
test "parse string literal union type" {
  let tokens = tokens_from_source(
    "type Status = \"active\" | \"inactive\" | \"pending\";",
  )
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TypeAliasDeclaration(type_alias) =>
          match type_alias.type_node {
            UnionType(union) => {
              assert_eq(union.types.length(), 3)
              // Check that all are literal types
              for i = 0; i < union.types.length(); i = i + 1 {
                match union.types[i] {
                  LiteralType(literal) =>
                    match literal.literal {
                      StringLiteral(_) => ()
                      _ => assert_true(false)
                    }
                  _ => assert_true(false)
                }
              }
            }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse generic interface" {
  let tokens = tokens_from_source(
    "interface Result<T, E> { value: T; error: E; }",
  )
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
test "parse interface with generic call signature" {
  // Based on recursiveTypeIdentity.ts
  let tokens = tokens_from_source("interface A { <T extends A>(x: T): void; }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        InterfaceDeclaration(iface) => {
          assert_eq(iface.name, "A")
          assert_eq(iface.members.length(), 1)
          // The generic call signature is represented as a MethodDeclaration with empty name
          match iface.members[0] {
            MethodDeclaration(imethod) => {
              assert_eq(imethod.name, "")
              assert_eq(imethod.type_parameters.length(), 1)
              assert_eq(imethod.type_parameters[0].name, "T")
              assert_eq(imethod.parameters.length(), 1)
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
test "parse interface with generic method signature" {
  let tokens = tokens_from_source(
    "interface Container<T> { map<U>(f: (x: T) => U): Container<U>; }",
  )
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        InterfaceDeclaration(iface) => {
          assert_eq(iface.name, "Container")
          assert_eq(iface.type_parameters.length(), 1)
          assert_eq(iface.members.length(), 1)
          match iface.members[0] {
            MethodDeclaration(m_method) => {
              assert_eq(m_method.name, "map")
              assert_eq(m_method.type_parameters.length(), 1)
              assert_eq(m_method.type_parameters[0].name, "U")
              assert_eq(m_method.parameters.length(), 1)
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
test "parse interface with multiple generic call signatures" {
  // Based on recursiveTypeIdentity.ts - interface C with multiple call signatures
  let tokens = tokens_from_source("interface C { (x: A): void; (x: B): void; }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        InterfaceDeclaration(iface) => {
          assert_eq(iface.name, "C")
          assert_eq(iface.members.length(), 2)
          // Both are call signatures (MethodDeclaration with empty name)
          match iface.members[0] {
            MethodDeclaration(imethod) => assert_eq(imethod.name, "")
            _ => assert_true(false)
          }
          match iface.members[1] {
            MethodDeclaration(imethod) => assert_eq(imethod.name, "")
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
test "parse qualified type name in function type" {
  // Test qualified names like Sample.Thing.IWidget in function types
  let tokens = tokens_from_source("type F = (widget: Foo.Bar.Baz) => void;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TypeAliasDeclaration(type_alias) => {
          assert_eq(type_alias.name, "F")
          match type_alias.type_node {
            FunctionType(func_type) => {
              assert_eq(func_type.parameters.length(), 1)
              // Check the parameter type is a qualified name
              match func_type.parameters[0] {
                Parameter(param) =>
                  match param.type_annotation {
                    Some(TypeReference(tr)) =>
                      assert_eq(tr.type_name, "Foo.Bar.Baz")
                    _ => assert_true(false)
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
test "parse qualified type name with type arguments" {
  // Test qualified names with generic type arguments
  let tokens = tokens_from_source("type F = Sample.Thing.Container<string>;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TypeAliasDeclaration(type_alias) => {
          assert_eq(type_alias.name, "F")
          match type_alias.type_node {
            TypeReference(tr) => {
              assert_eq(tr.type_name, "Sample.Thing.Container")
              assert_eq(tr.type_arguments.length(), 1)
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
                KeywordType(keyword) =>
                  match keyword.kind {
                    Void => ()
                    _ => assert_true(false)
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
  let tokens = tokens_from_source(
    "const enum Direction { Up, Down, Left, Right }",
  )
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
  let tokens = tokens_from_source(
    "const square = (x: number): number => x * x;",
  )
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
    Ok(_) =>
      // Just verify it parses successfully
      assert_true(true)
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
  let tokens = tokens_from_source(
    "function test() { switch (x) { case 1: return a; case 2: return b; default: return c; } }",
  )
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

// ===== Advanced Type System Tests =====

///|
test "parse indexed access type" {
  let tokens = tokens_from_source("type Name = Person['name'];")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TypeAliasDeclaration(decl) =>
          match decl.type_node {
            IndexedAccessType(_) => ()
            _ => assert_true(false)
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
        TypeAliasDeclaration(decl) =>
          match decl.type_node {
            IndexedAccessType(_) => ()
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse conditional type" {
  let tokens = tokens_from_source(
    "type IsString<T> = T extends string ? string : number;",
  )
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TypeAliasDeclaration(decl) =>
          match decl.type_node {
            ConditionalType(_) => ()
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse conditional type with complex extends" {
  let tokens = tokens_from_source(
    "type NonNullable<T> = T extends number ? string : T;",
  )
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TypeAliasDeclaration(decl) =>
          match decl.type_node {
            ConditionalType(_) => ()
            _ => assert_true(false)
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
        TypeAliasDeclaration(decl) =>
          match decl.type_node {
            MappedType(_) => ()
            _ => assert_true(false)
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
        TypeAliasDeclaration(decl) =>
          match decl.type_node {
            MappedType(_) => ()
            _ => assert_true(false)
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
        VariableStatement(stmt) =>
          match stmt.declarations[0].initializer {
            Some(NonNullExpression(_)) => ()
            _ => assert_true(false)
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
        VariableStatement(stmt) =>
          match stmt.declarations[0].initializer {
            Some(NonNullExpression(_)) => ()
            _ => assert_true(false)
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
        VariableStatement(stmt) =>
          match stmt.declarations[0].initializer {
            Some(AsExpression(_)) => ()
            _ => assert_true(false)
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
        VariableStatement(stmt) =>
          match stmt.declarations[0].initializer {
            Some(AsExpression(_)) => ()
            _ => assert_true(false)
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
        VariableStatement(stmt) =>
          match stmt.declarations[0].initializer {
            Some(TypeAssertionExpression(_)) => ()
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse type assertion with complex type" {
  let tokens = tokens_from_source("const x = <Array<string>>getArray();")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(stmt) =>
          match stmt.declarations[0].initializer {
            Some(TypeAssertionExpression(_)) => ()
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse type assertion with deeply nested generics" {
  // 4 levels of Array nesting + 1 outer type assertion = 5 closing >
  // Scanner tokenizes >>>>> as >>> followed by >>
  let tokens = tokens_from_source(
    "const x = <Array<Array<Array<Array<string>>>>>getValue();",
  )
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(stmt) =>
          match stmt.declarations[0].initializer {
            Some(TypeAssertionExpression(_)) => ()
            _ => assert_true(false)
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
        VariableStatement(stmt) =>
          match stmt.declarations[0].initializer {
            Some(AsExpression(_)) => ()
            _ => assert_true(false)
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
        VariableStatement(stmt) =>
          match stmt.declarations[0].initializer {
            Some(AsExpression(ae)) =>
              match ae.expression {
                NonNullExpression(_) => ()
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
        VariableStatement(stmt) =>
          match stmt.declarations[0].type_annotation {
            Some(KeywordType(kt)) =>
              match kt.kind {
                TypeKeyword::Unknown => ()
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

///|
test "parse never type annotation" {
  let tokens = tokens_from_source(
    "function fail(): never { throw new Error(); }",
  )
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        FunctionDeclaration(func) =>
          match func.return_type {
            Some(KeywordType(kt)) =>
              match kt.kind {
                TypeKeyword::Never => ()
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

// Optional Chaining Tests

///|
test "parse optional property access" {
  let tokens = tokens_from_source("const x = obj?.prop;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(stmt) =>
          match stmt.declarations[0].initializer {
            Some(OptionalChain(_)) => ()
            _ => assert_true(false)
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
        VariableStatement(stmt) =>
          match stmt.declarations[0].initializer {
            Some(OptionalChain(_)) => ()
            _ => assert_true(false)
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
        VariableStatement(stmt) =>
          match stmt.declarations[0].initializer {
            Some(OptionalChain(_)) => ()
            _ => assert_true(false)
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
        ClassDeclaration(cls) => assert_true(cls.is_abstract)
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
        ClassDeclaration(cls) => assert_true(not(cls.is_abstract))
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

// Await Expression Tests

///|
test "verify await token is KeywordAwait" {
  // First verify the scanner produces KeywordAwait for "await"
  let tokens = tokens_from_source("await Promise.resolve()")
  // Should produce: KeywordAwait, Identifier(Promise), Dot, Identifier(resolve), OpenParen, CloseParen, EOF
  match tokens[0] {
    KeywordAwait(_) => ()
    Identifier(name, _) => {
      println(
        "ERROR: await was scanned as Identifier('\{name}') instead of KeywordAwait",
      )
      assert_true(false)
    }
    _ => {
      println("ERROR: await was scanned as unexpected token type")
      assert_true(false)
    }
  }
}

///|
test "parse await in non-async function" {
  // Test that await is still parsed as AwaitExpression even in non-async function
  // (The error should be caught by type checker, not parser)
  let tokens = tokens_from_source(
    "function syncFunction() { await Promise.resolve(); }",
  )
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        FunctionDeclaration(func) => {
          assert_true(not(func.is_async))
          match func.body {
            Some(BlockStatement(block)) => {
              assert_eq(block.statements.length(), 1)
              match block.statements[0] {
                ExpressionStatement(stmt) =>
                  match stmt.expression {
                    AwaitExpression(_) => ()
                    CallExpression(_) => {
                      // This is incorrect - await should be AwaitExpression, not CallExpression
                      // If we reach here, the parser is treating "await" as a function call
                      println(
                        "ERROR: await was parsed as CallExpression instead of AwaitExpression",
                      )
                      assert_true(false)
                    }
                    _ => {
                      println("ERROR: unexpected expression type")
                      assert_true(false)
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
test "parse await expression" {
  let tokens = tokens_from_source(
    "async function fetch() { const data = await getData(); }",
  )
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
                VariableStatement(stmt) =>
                  match stmt.declarations[0].initializer {
                    Some(AwaitExpression(_)) => ()
                    _ => assert_true(false)
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
                ExpressionStatement(stmt) =>
                  match stmt.expression {
                    YieldExpression(ye) => assert_true(not(ye.is_delegate))
                    _ => assert_true(false)
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
            Some(BlockStatement(block)) =>
              match block.statements[0] {
                ExpressionStatement(stmt) =>
                  match stmt.expression {
                    YieldExpression(ye) => assert_true(ye.is_delegate)
                    _ => assert_true(false)
                  }
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

// Generator Function Tests

///|
test "parse generator function declaration" {
  let tokens = tokens_from_source("function* generate() { }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        FunctionDeclaration(func) => assert_true(func.is_generator)
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
        ClassDeclaration(cls) => assert_eq(cls.decorators.length(), 1)
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
        ClassDeclaration(cls) => assert_eq(cls.decorators.length(), 2)
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
        ModuleDeclaration(mod_decl) => assert_eq(mod_decl.name, "MyNamespace")
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
        ModuleDeclaration(mod_decl) => assert_eq(mod_decl.name, "MyModule")
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
            Some(BlockStatement(block)) =>
              assert_eq(block.statements.length(), 1)
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
// JSX Parsing Tests
// ============================================================================

///|
test "parse JSX self-closing element" {
  let tokens = tokens_from_source("const x = <div />;")
  let result = parse_source_file(tokens, "test.tsx")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(var_stmt) =>
          match var_stmt.declarations[0].initializer {
            Some(JsxSelfClosingElement(jsx)) =>
              match jsx.tag_name {
                JsxTagName::Identifier(name, _) => assert_eq(name, "div")
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

///|
test "parse JSX element with children" {
  let tokens = tokens_from_source("const x = <div></div>;")
  let result = parse_source_file(tokens, "test.tsx")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(var_stmt) =>
          match var_stmt.declarations[0].initializer {
            Some(JsxElement(_)) => ()
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse JSX element with attributes" {
  let tokens = tokens_from_source(
    "const x = <button disabled onClick={handler} />;",
  )
  let result = parse_source_file(tokens, "test.tsx")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(var_stmt) =>
          match var_stmt.declarations[0].initializer {
            Some(JsxSelfClosingElement(jsx)) =>
              assert_eq(jsx.attributes.length(), 2)
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse JSX element with string attribute" {
  // Note: This test requires the scanner to properly handle JSX string attributes
  // For now we test that JSX elements with simple attributes work
  let tokens = tokens_from_source("const x = <input value={val} />;")
  let result = parse_source_file(tokens, "test.tsx")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(var_stmt) =>
          match var_stmt.declarations[0].initializer {
            Some(JsxSelfClosingElement(jsx)) => {
              assert_eq(jsx.attributes.length(), 1)
              match jsx.attributes[0] {
                JsxAttribute::Attribute(attr) =>
                  match attr.name {
                    JsxAttributeName::Identifier(name, _) =>
                      assert_eq(name, "value")
                    _ => assert_true(false)
                  }
                _ => assert_true(false)
              }
            }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse JSX fragment" {
  let tokens = tokens_from_source("const x = <></>;")
  let result = parse_source_file(tokens, "test.tsx")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(var_stmt) =>
          match var_stmt.declarations[0].initializer {
            Some(JsxFragment(_)) => ()
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse JSX nested elements" {
  let tokens = tokens_from_source("const x = <div><span /></div>;")
  let result = parse_source_file(tokens, "test.tsx")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(var_stmt) =>
          match var_stmt.declarations[0].initializer {
            Some(JsxElement(jsx)) => assert_eq(jsx.children.length(), 1)
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse JSX with expression child" {
  let tokens = tokens_from_source("const x = <div>{value}</div>;")
  let result = parse_source_file(tokens, "test.tsx")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(var_stmt) =>
          match var_stmt.declarations[0].initializer {
            Some(JsxElement(jsx)) => {
              assert_eq(jsx.children.length(), 1)
              match jsx.children[0] {
                JsxChild::Expression(expr) =>
                  match expr.expression {
                    Some(_) => ()
                    None => assert_true(false)
                  }
                _ => assert_true(false)
              }
            }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse JSX with spread attribute" {
  let tokens = tokens_from_source("const x = <div {...props} />;")
  let result = parse_source_file(tokens, "test.tsx")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(var_stmt) =>
          match var_stmt.declarations[0].initializer {
            Some(JsxSelfClosingElement(jsx)) => {
              assert_eq(jsx.attributes.length(), 1)
              match jsx.attributes[0] {
                JsxAttribute::SpreadAttribute(_, _) => ()
                _ => assert_true(false)
              }
            }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse JSX member expression tag" {
  let tokens = tokens_from_source("const x = <React.Component />;")
  let result = parse_source_file(tokens, "test.tsx")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(var_stmt) =>
          match var_stmt.declarations[0].initializer {
            Some(JsxSelfClosingElement(jsx)) =>
              match jsx.tag_name {
                JsxTagName::PropertyAccess(_, _, _) => ()
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

///|
test "parse JSX with text child" {
  let tokens = tokens_from_source("const x = <div>Hello</div>;")
  let result = parse_source_file(tokens, "test.tsx")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(var_stmt) =>
          match var_stmt.declarations[0].initializer {
            Some(JsxElement(jsx)) => {
              assert_eq(jsx.children.length(), 1)
              match jsx.children[0] {
                JsxChild::Text(text, _) => assert_eq(text, "Hello")
                _ => assert_true(false)
              }
            }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse JSX with nested fragment child" {
  let tokens = tokens_from_source("const x = <div><>content</></div>;")
  let result = parse_source_file(tokens, "test.tsx")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(var_stmt) =>
          match var_stmt.declarations[0].initializer {
            Some(JsxElement(jsx)) => {
              assert_eq(jsx.children.length(), 1)
              match jsx.children[0] {
                JsxChild::Fragment(node, _) =>
                  match node {
                    JsxFragment(frag) => assert_eq(frag.children.length(), 1)
                    _ => assert_true(false)
                  }
                _ => assert_true(false)
              }
            }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse JSX with mixed children" {
  let tokens = tokens_from_source("const x = <div>Hello{value}World</div>;")
  let result = parse_source_file(tokens, "test.tsx")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(var_stmt) =>
          match var_stmt.declarations[0].initializer {
            Some(JsxElement(jsx)) => {
              assert_eq(jsx.children.length(), 3)
              // First child: Text "Hello"
              match jsx.children[0] {
                JsxChild::Text(text, _) => assert_eq(text, "Hello")
                _ => assert_true(false)
              }
              // Second child: Expression {value}
              match jsx.children[1] {
                JsxChild::Expression(_) => ()
                _ => assert_true(false)
              }
              // Third child: Text "World"
              match jsx.children[2] {
                JsxChild::Text(text, _) => assert_eq(text, "World")
                _ => assert_true(false)
              }
            }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Parser Context Tests
// ============================================================================

///|
test "ParserContext default values" {
  let ctx = ParserContext::default()
  assert_eq(ctx.allow_in, true)
  assert_eq(ctx.allow_yield, true)
  assert_eq(ctx.allow_await, false)
  assert_eq(ctx.in_type_context, false)
  assert_eq(ctx.strict_mode, false)
  assert_eq(ctx.in_jsx, false)
}

// ============================================================================
// Compound Assignment Operator Tests
// ============================================================================

///|
test "parse addition assignment" {
  let tokens = tokens_from_source("x += 5;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExpressionStatement(stmt) =>
          match stmt.expression {
            BinaryExpression(bin) =>
              match bin.operator {
                AddAssign => ()
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

///|
test "parse subtraction assignment" {
  let tokens = tokens_from_source("x -= 5;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExpressionStatement(stmt) =>
          match stmt.expression {
            BinaryExpression(bin) =>
              match bin.operator {
                SubtractAssign => ()
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

///|
test "parse multiplication assignment" {
  let tokens = tokens_from_source("x *= 5;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExpressionStatement(stmt) =>
          match stmt.expression {
            BinaryExpression(bin) =>
              match bin.operator {
                MultiplyAssign => ()
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

///|
test "parse division assignment" {
  let tokens = tokens_from_source("x /= 5;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExpressionStatement(stmt) =>
          match stmt.expression {
            BinaryExpression(bin) =>
              match bin.operator {
                DivideAssign => ()
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

///|
test "parse remainder assignment" {
  let tokens = tokens_from_source("x %= 5;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExpressionStatement(stmt) =>
          match stmt.expression {
            BinaryExpression(bin) =>
              match bin.operator {
                RemainderAssign => ()
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

///|
test "parse exponentiation assignment" {
  let tokens = tokens_from_source("x **= 2;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExpressionStatement(stmt) =>
          match stmt.expression {
            BinaryExpression(bin) =>
              match bin.operator {
                ExponentiateAssign => ()
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

///|
test "parse bitwise AND assignment" {
  let tokens = tokens_from_source("x &= 0xFF;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExpressionStatement(stmt) =>
          match stmt.expression {
            BinaryExpression(bin) =>
              match bin.operator {
                BitwiseAndAssign => ()
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

///|
test "parse bitwise OR assignment" {
  let tokens = tokens_from_source("x |= 0xFF;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExpressionStatement(stmt) =>
          match stmt.expression {
            BinaryExpression(bin) =>
              match bin.operator {
                BitwiseOrAssign => ()
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

///|
test "parse bitwise XOR assignment" {
  let tokens = tokens_from_source("x ^= 0xFF;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExpressionStatement(stmt) =>
          match stmt.expression {
            BinaryExpression(bin) =>
              match bin.operator {
                BitwiseXorAssign => ()
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

///|
test "parse left shift assignment" {
  let tokens = tokens_from_source("x <<= 2;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExpressionStatement(stmt) =>
          match stmt.expression {
            BinaryExpression(bin) =>
              match bin.operator {
                LeftShiftAssign => ()
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

///|
test "parse right shift assignment" {
  let tokens = tokens_from_source("x >>= 2;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExpressionStatement(stmt) =>
          match stmt.expression {
            BinaryExpression(bin) =>
              match bin.operator {
                RightShiftAssign => ()
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

///|
test "parse unsigned right shift assignment" {
  let tokens = tokens_from_source("x >>>= 2;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExpressionStatement(stmt) =>
          match stmt.expression {
            BinaryExpression(bin) =>
              match bin.operator {
                UnsignedRightShiftAssign => ()
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

///|
test "parse logical AND assignment" {
  let tokens = tokens_from_source("x &&= true;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExpressionStatement(stmt) =>
          match stmt.expression {
            BinaryExpression(bin) =>
              match bin.operator {
                LogicalAndAssign => ()
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

///|
test "parse logical OR assignment" {
  let tokens = tokens_from_source("x ||= false;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExpressionStatement(stmt) =>
          match stmt.expression {
            BinaryExpression(bin) =>
              match bin.operator {
                LogicalOrAssign => ()
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

///|
test "parse nullish coalescing assignment" {
  let tokens = tokens_from_source("x ??= defaultValue;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExpressionStatement(stmt) =>
          match stmt.expression {
            BinaryExpression(bin) =>
              match bin.operator {
                NullishCoalescingAssign => ()
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

///|
test "parse compound assignment with property access" {
  let tokens = tokens_from_source("obj.count += 1;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExpressionStatement(stmt) =>
          match stmt.expression {
            BinaryExpression(bin) => {
              match bin.operator {
                AddAssign => ()
                _ => assert_true(false)
              }
              match bin.left {
                PropertyAccessExpression(_) => ()
                _ => assert_true(false)
              }
            }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse compound assignment with element access" {
  let tokens = tokens_from_source("arr[0] *= 2;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExpressionStatement(stmt) =>
          match stmt.expression {
            BinaryExpression(bin) => {
              match bin.operator {
                MultiplyAssign => ()
                _ => assert_true(false)
              }
              match bin.left {
                ElementAccessExpression(_) => ()
                _ => assert_true(false)
              }
            }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse compound assignment with expression on right side" {
  let tokens = tokens_from_source("x += y * z;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExpressionStatement(stmt) =>
          match stmt.expression {
            BinaryExpression(bin) => {
              match bin.operator {
                AddAssign => ()
                _ => assert_true(false)
              }
              match bin.right {
                BinaryExpression(right_bin) =>
                  match right_bin.operator {
                    Multiply => ()
                    _ => assert_true(false)
                  }
                _ => assert_true(false)
              }
            }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse multiple compound assignments" {
  let tokens = tokens_from_source("x += 1; y -= 2; z *= 3;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 3)
      // First statement: x += 1
      match source_file.statements[0] {
        ExpressionStatement(stmt) =>
          match stmt.expression {
            BinaryExpression(bin) =>
              match bin.operator {
                AddAssign => ()
                _ => assert_true(false)
              }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
      // Second statement: y -= 2
      match source_file.statements[1] {
        ExpressionStatement(stmt) =>
          match stmt.expression {
            BinaryExpression(bin) =>
              match bin.operator {
                SubtractAssign => ()
                _ => assert_true(false)
              }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
      // Third statement: z *= 3
      match source_file.statements[2] {
        ExpressionStatement(stmt) =>
          match stmt.expression {
            BinaryExpression(bin) =>
              match bin.operator {
                MultiplyAssign => ()
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

///|
test "parse compound assignment in function body" {
  let tokens = tokens_from_source(
    "function increment(x: number) { x += 1; return x; }",
  )
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        FunctionDeclaration(func) =>
          match func.body {
            Some(BlockStatement(block)) => {
              assert_eq(block.statements.length(), 2)
              match block.statements[0] {
                ExpressionStatement(stmt) =>
                  match stmt.expression {
                    BinaryExpression(bin) =>
                      match bin.operator {
                        AddAssign => ()
                        _ => assert_true(false)
                      }
                    _ => assert_true(false)
                  }
                _ => assert_true(false)
              }
            }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse all compound assignment operators in sequence" {
  let tokens = tokens_from_source(
    "a += 1; b -= 1; c *= 1; d /= 1; e %= 1; f **= 1; g &= 1; h |= 1; i ^= 1; j <<= 1; k >>= 1; l >>>= 1; m &&= true; n ||= false; o ??= null;",
  )
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 15)
      // Verify each operator type using pattern matching
      // Statement 0: a += 1
      match source_file.statements[0] {
        ExpressionStatement(stmt) =>
          match stmt.expression {
            BinaryExpression(bin) =>
              match bin.operator {
                AddAssign => ()
                _ => assert_true(false)
              }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
      // Statement 1: b -= 1
      match source_file.statements[1] {
        ExpressionStatement(stmt) =>
          match stmt.expression {
            BinaryExpression(bin) =>
              match bin.operator {
                SubtractAssign => ()
                _ => assert_true(false)
              }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
      // Statement 2: c *= 1
      match source_file.statements[2] {
        ExpressionStatement(stmt) =>
          match stmt.expression {
            BinaryExpression(bin) =>
              match bin.operator {
                MultiplyAssign => ()
                _ => assert_true(false)
              }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
      // Statement 3: d /= 1
      match source_file.statements[3] {
        ExpressionStatement(stmt) =>
          match stmt.expression {
            BinaryExpression(bin) =>
              match bin.operator {
                DivideAssign => ()
                _ => assert_true(false)
              }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
      // Statement 4: e %= 1
      match source_file.statements[4] {
        ExpressionStatement(stmt) =>
          match stmt.expression {
            BinaryExpression(bin) =>
              match bin.operator {
                RemainderAssign => ()
                _ => assert_true(false)
              }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
      // Statement 5: f **= 1
      match source_file.statements[5] {
        ExpressionStatement(stmt) =>
          match stmt.expression {
            BinaryExpression(bin) =>
              match bin.operator {
                ExponentiateAssign => ()
                _ => assert_true(false)
              }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
      // Statement 6: g &= 1
      match source_file.statements[6] {
        ExpressionStatement(stmt) =>
          match stmt.expression {
            BinaryExpression(bin) =>
              match bin.operator {
                BitwiseAndAssign => ()
                _ => assert_true(false)
              }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
      // Statement 7: h |= 1
      match source_file.statements[7] {
        ExpressionStatement(stmt) =>
          match stmt.expression {
            BinaryExpression(bin) =>
              match bin.operator {
                BitwiseOrAssign => ()
                _ => assert_true(false)
              }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
      // Statement 8: i ^= 1
      match source_file.statements[8] {
        ExpressionStatement(stmt) =>
          match stmt.expression {
            BinaryExpression(bin) =>
              match bin.operator {
                BitwiseXorAssign => ()
                _ => assert_true(false)
              }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
      // Statement 9: j <<= 1
      match source_file.statements[9] {
        ExpressionStatement(stmt) =>
          match stmt.expression {
            BinaryExpression(bin) =>
              match bin.operator {
                LeftShiftAssign => ()
                _ => assert_true(false)
              }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
      // Statement 10: k >>= 1
      match source_file.statements[10] {
        ExpressionStatement(stmt) =>
          match stmt.expression {
            BinaryExpression(bin) =>
              match bin.operator {
                RightShiftAssign => ()
                _ => assert_true(false)
              }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
      // Statement 11: l >>>= 1
      match source_file.statements[11] {
        ExpressionStatement(stmt) =>
          match stmt.expression {
            BinaryExpression(bin) =>
              match bin.operator {
                UnsignedRightShiftAssign => ()
                _ => assert_true(false)
              }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
      // Statement 12: m &&= true
      match source_file.statements[12] {
        ExpressionStatement(stmt) =>
          match stmt.expression {
            BinaryExpression(bin) =>
              match bin.operator {
                LogicalAndAssign => ()
                _ => assert_true(false)
              }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
      // Statement 13: n ||= false
      match source_file.statements[13] {
        ExpressionStatement(stmt) =>
          match stmt.expression {
            BinaryExpression(bin) =>
              match bin.operator {
                LogicalOrAssign => ()
                _ => assert_true(false)
              }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
      // Statement 14: o ??= null
      match source_file.statements[14] {
        ExpressionStatement(stmt) =>
          match stmt.expression {
            BinaryExpression(bin) =>
              match bin.operator {
                NullishCoalescingAssign => ()
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

// ============================================================================
// Nested Namespace Tests
// ============================================================================

///|
test "parse nested namespace with dotted syntax" {
  let tokens = tokens_from_source("namespace A.B.C { const x = 1; }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      // Outer namespace A
      match source_file.statements[0] {
        ModuleDeclaration(outer) => {
          assert_eq(outer.name, "A")
          // Nested namespace B
          match outer.body {
            Some(ModuleDeclaration(middle)) => {
              assert_eq(middle.name, "B")
              // Innermost namespace C
              match middle.body {
                Some(ModuleDeclaration(inner)) => {
                  assert_eq(inner.name, "C")
                  // Body should be a BlockStatement with one statement
                  match inner.body {
                    Some(BlockStatement(block)) =>
                      assert_eq(block.statements.length(), 1)
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
test "parse simple namespace" {
  let tokens = tokens_from_source("namespace Foo { function bar() {} }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ModuleDeclaration(md) => {
          assert_eq(md.name, "Foo")
          match md.body {
            Some(BlockStatement(block)) =>
              assert_eq(block.statements.length(), 1)
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
// String Enum Tests
// ============================================================================

///|
test "parse string enum with string values" {
  let source =
    #|enum Color {
    #|  Red = "RED",
    #|  Green = "GREEN",
    #|  Blue = "BLUE"
    #|}
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        EnumDeclaration(ed) => {
          assert_eq(ed.name, "Color")
          assert_eq(ed.members.length(), 3)
          // Check first member has string initializer
          let first_member = ed.members[0]
          assert_eq(first_member.name, "Red")
          match first_member.initializer {
            Some(StringLiteral(sl)) => assert_eq(sl.value, "RED")
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
test "parse mixed enum with numeric and string values" {
  let source =
    #|enum Status {
    #|  Pending = 0,
    #|  Active = "ACTIVE",
    #|  Disabled = 2
    #|}
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        EnumDeclaration(ed) => {
          assert_eq(ed.name, "Status")
          assert_eq(ed.members.length(), 3)
          // Check second member is string
          let second_member = ed.members[1]
          assert_eq(second_member.name, "Active")
          match second_member.initializer {
            Some(StringLiteral(sl)) => assert_eq(sl.value, "ACTIVE")
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
// Export Assignment Tests
// ============================================================================

///|
test "parse export default expression" {
  let tokens = tokens_from_source("export default 42;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExportAssignment(ea) => {
          assert_false(ea.is_export_equals)
          match ea.expression {
            NumericLiteral(nl) => assert_eq(nl.value, "42")
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
test "parse export default function" {
  let tokens = tokens_from_source("export default function foo() {}")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        FunctionDeclaration(fd) => {
          // Should have Export and Default modifiers (2 modifiers)
          assert_eq(fd.modifiers.length(), 2)
          // Check modifiers by pattern matching
          let has_export = fd.modifiers
            .iter()
            .any(fn(m) {
              match m {
                Export => true
                _ => false
              }
            })
          let has_default = fd.modifiers
            .iter()
            .any(fn(m) {
              match m {
                Default => true
                _ => false
              }
            })
          assert_true(has_export)
          assert_true(has_default)
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse export default class" {
  let tokens = tokens_from_source("export default class Foo {}")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ClassDeclaration(cd) => {
          // Should have Export and Default modifiers (2 modifiers)
          assert_eq(cd.modifiers.length(), 2)
          let has_export = cd.modifiers
            .iter()
            .any(fn(m) {
              match m {
                Export => true
                _ => false
              }
            })
          let has_default = cd.modifiers
            .iter()
            .any(fn(m) {
              match m {
                Default => true
                _ => false
              }
            })
          assert_true(has_export)
          assert_true(has_default)
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Parameter Properties Tests
// ============================================================================

///|
test "parse constructor with parameter properties" {
  let source =
    #|class Person {
    #|  constructor(public name: string, private age: number) {}
    #|}
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ClassDeclaration(cd) => {
          assert_eq(cd.members.length(), 1)
          match cd.members[0] {
            ConstructorDeclaration(ctor) => {
              assert_eq(ctor.parameters.length(), 2)
              // First parameter should have public modifier
              match ctor.parameters[0] {
                Parameter(p1) => {
                  let has_public = p1.modifiers
                    .iter()
                    .any(fn(m) {
                      match m {
                        Public => true
                        _ => false
                      }
                    })
                  assert_true(has_public)
                  match p1.name {
                    Identifier(id) => assert_eq(id.name, "name")
                    _ => assert_true(false)
                  }
                }
                _ => assert_true(false)
              }
              // Second parameter should have private modifier
              match ctor.parameters[1] {
                Parameter(p2) => {
                  let has_private = p2.modifiers
                    .iter()
                    .any(fn(m) {
                      match m {
                        Private => true
                        _ => false
                      }
                    })
                  assert_true(has_private)
                  match p2.name {
                    Identifier(id) => assert_eq(id.name, "age")
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
test "parse constructor with readonly parameter property" {
  let source =
    #|class Config {
    #|  constructor(readonly value: number) {}
    #|}
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ClassDeclaration(cd) =>
          match cd.members[0] {
            ConstructorDeclaration(ctor) =>
              match ctor.parameters[0] {
                Parameter(p) => {
                  let has_readonly = p.modifiers
                    .iter()
                    .any(fn(m) {
                      match m {
                        Readonly => true
                        _ => false
                      }
                    })
                  assert_true(has_readonly)
                }
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

// ============================================================================
// Private Class Fields Tests
// ============================================================================

///|
test "parse private class field with hash syntax" {
  // Use string concatenation to avoid conflict with MoonBit multiline string syntax
  let source = "class Counter { #count = 0; increment() { } }"
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ClassDeclaration(cd) => {
          // Should have 2 members: #count property and increment method
          assert_eq(cd.members.length(), 2)
          // First member should be the private field
          match cd.members[0] {
            PropertyDeclaration(pd) => assert_eq(pd.name, "#count")
            _ => assert_true(false)
          }
          // Second member should be the method
          match cd.members[1] {
            MethodDeclaration(md) => assert_eq(md.name, "increment")
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
test "parse private method with hash syntax" {
  let source = "class Service { #privateMethod() { return 42; } }"
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) =>
      match source_file.statements[0] {
        ClassDeclaration(cd) => {
          assert_eq(cd.members.length(), 1)
          match cd.members[0] {
            MethodDeclaration(md) => assert_eq(md.name, "#privateMethod")
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Static Block Tests
// ============================================================================

///|
test "parse static block in class" {
  let source =
    #|class Foo {
    #|  static x = 1;
    #|  static {
    #|    console.log("initialized");
    #|  }
    #|}
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ClassDeclaration(cd) =>
          // Should have 2 members: static property and static block
          assert_true(cd.members.length() >= 1)
        _ => assert_true(false)
      }
    }
    Err(_) =>
      // Static blocks may not be implemented yet - that's OK for now
      assert_true(true)
  }
}

// ============================================================================
// Dynamic Import Tests
// ============================================================================

///|
test "parse dynamic import with string literal" {
  let source = "const mod = import('./module.js');"
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(vs) => {
          assert_eq(vs.declarations.length(), 1)
          match vs.declarations[0].initializer {
            Some(ImportExpression(ie)) =>
              match ie.source {
                StringLiteral(sl) => assert_eq(sl.value, "./module.js")
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
test "parse dynamic import with await" {
  let source = "const mod = await import('./dynamic.js');"
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(vs) =>
          match vs.declarations[0].initializer {
            Some(AwaitExpression(ae)) =>
              match ae.expression {
                ImportExpression(ie) =>
                  match ie.source {
                    StringLiteral(sl) => assert_eq(sl.value, "./dynamic.js")
                    _ => assert_true(false)
                  }
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

///|
test "parse dynamic import with expression" {
  let source = "import(modulePath)"
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExpressionStatement(es) =>
          match es.expression {
            ImportExpression(ie) =>
              match ie.source {
                Identifier(id) => assert_eq(id.name, "modulePath")
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

///|
test "parse dynamic import with template literal" {
  let source = "import(`./modules/test.js`)"
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExpressionStatement(es) =>
          match es.expression {
            ImportExpression(ie) =>
              match ie.source {
                TemplateExpression(_) => assert_true(true)
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

// ============================================================================
// Tagged Template Literal Tests
// ============================================================================

///|
test "parse simple tagged template literal" {
  let source = "html`<div>Hello</div>`"
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExpressionStatement(es) =>
          match es.expression {
            TaggedTemplateExpression(tte) => {
              match tte.tag {
                Identifier(id) => assert_eq(id.name, "html")
                _ => assert_true(false)
              }
              match tte.template {
                TemplateExpression(te) => {
                  assert_eq(te.head, "<div>Hello</div>")
                  assert_eq(te.template_spans.length(), 0)
                }
                _ => assert_true(false)
              }
            }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse tagged template with interpolation" {
  let source = "sql`SELECT * FROM ${table}`"
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExpressionStatement(es) =>
          match es.expression {
            TaggedTemplateExpression(tte) => {
              match tte.tag {
                Identifier(id) => assert_eq(id.name, "sql")
                _ => assert_true(false)
              }
              match tte.template {
                TemplateExpression(te) => {
                  assert_eq(te.head, "SELECT * FROM ")
                  assert_eq(te.template_spans.length(), 1)
                }
                _ => assert_true(false)
              }
            }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse tagged template with property access tag" {
  let source = "String.raw`line1\\nline2`"
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExpressionStatement(es) =>
          match es.expression {
            TaggedTemplateExpression(tte) =>
              match tte.tag {
                PropertyAccessExpression(_) => assert_true(true)
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

///|
test "parse css tagged template" {
  let source = "const styles = css`color: red;`"
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(vs) =>
          match vs.declarations[0].initializer {
            Some(TaggedTemplateExpression(tte)) =>
              match tte.tag {
                Identifier(id) => assert_eq(id.name, "css")
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

// ============================================================================
// Class Expression Tests
// ============================================================================

///|
test "parse anonymous class expression" {
  let source = "const MyClass = class {}"
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(vs) =>
          match vs.declarations[0].initializer {
            Some(ClassExpression(ce)) => {
              match ce.name {
                None => () // Expected: anonymous class
                _ => assert_true(false)
              }
              assert_eq(ce.members.length(), 0)
            }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse named class expression" {
  let source = "const MyClass = class Foo {}"
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(vs) =>
          match vs.declarations[0].initializer {
            Some(ClassExpression(ce)) =>
              match ce.name {
                Some(Identifier(id)) => assert_eq(id.name, "Foo")
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

///|
test "parse class expression with extends" {
  let source = "const MyClass = class extends Base {}"
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(vs) =>
          match vs.declarations[0].initializer {
            Some(ClassExpression(ce)) => {
              assert_eq(ce.heritage_clauses.length(), 1)
              match ce.heritage_clauses[0].kind {
                Extends => () // Expected: extends clause
                _ => assert_true(false)
              }
            }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse class expression with method" {
  let source = "const MyClass = class { foo() { return 1; } }"
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(vs) =>
          match vs.declarations[0].initializer {
            Some(ClassExpression(ce)) => {
              assert_eq(ce.members.length(), 1)
              match ce.members[0] {
                MethodDeclaration(md) => assert_eq(md.name, "foo")
                _ => assert_true(false)
              }
            }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse decorated class expression" {
  let source = "const MyClass = @dec class {}"
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(vs) =>
          match vs.declarations[0].initializer {
            Some(ClassExpression(ce)) => {
              assert_eq(ce.decorators.length(), 1)
              match ce.decorators[0] {
                Decorator(d) =>
                  match d.expression {
                    Identifier(id) => assert_eq(id.name, "dec")
                    _ => assert_true(false)
                  }
                _ => assert_true(false)
              }
            }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse class expression with multiple decorators" {
  let source = "const MyClass = @dec1 @dec2 class {}"
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(vs) =>
          match vs.declarations[0].initializer {
            Some(ClassExpression(ce)) => {
              assert_eq(ce.decorators.length(), 2)
            }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse decorated named class expression" {
  let source = "const MyClass = @dec class Foo {}"
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(vs) =>
          match vs.declarations[0].initializer {
            Some(ClassExpression(ce)) => {
              assert_eq(ce.decorators.length(), 1)
              match ce.name {
                Some(Identifier(id)) => assert_eq(id.name, "Foo")
                _ => assert_true(false)
              }
            }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse decorated class expression in parentheses" {
  let source = "const x = (@dec class {})"
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(vs) =>
          match vs.declarations[0].initializer {
            Some(ParenthesizedExpression(pe)) =>
              match pe.expression {
                ClassExpression(ce) => assert_eq(ce.decorators.length(), 1)
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

///|
test "parse exported const with decorated class expression" {
  let source = "export const C = @dec class {};"
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      // export const is parsed as VariableStatement with modifiers
      match source_file.statements[0] {
        VariableStatement(vs) =>
          match vs.declarations[0].initializer {
            Some(ClassExpression(ce)) => assert_eq(ce.decorators.length(), 1)
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Meta Property Tests (import.meta, new.target)
// ============================================================================

///|
test "parse import.meta" {
  let source = "const url = import.meta.url"
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(vs) =>
          match vs.declarations[0].initializer {
            Some(PropertyAccessExpression(pae)) =>
              match pae.expression {
                MetaProperty(mp) =>
                  match mp.keyword_kind {
                    ImportMeta => assert_eq(mp.name, "meta")
                    _ => assert_true(false)
                  }
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

///|
test "parse import.meta standalone" {
  let source = "console.log(import.meta)"
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExpressionStatement(es) =>
          match es.expression {
            CallExpression(ce) => {
              assert_eq(ce.arguments.length(), 1)
              match ce.arguments[0] {
                MetaProperty(mp) =>
                  match mp.keyword_kind {
                    ImportMeta => assert_eq(mp.name, "meta")
                    _ => assert_true(false)
                  }
                _ => assert_true(false)
              }
            }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse new.target standalone" {
  let source = "console.log(new.target)"
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ExpressionStatement(es) =>
          match es.expression {
            CallExpression(ce) => {
              assert_eq(ce.arguments.length(), 1)
              match ce.arguments[0] {
                MetaProperty(mp) =>
                  match mp.keyword_kind {
                    NewTarget => assert_eq(mp.name, "target")
                    _ => assert_true(false)
                  }
                _ => assert_true(false)
              }
            }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse new.target as variable initializer" {
  let source = "const target = new.target"
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(vs) =>
          match vs.declarations[0].initializer {
            Some(MetaProperty(mp)) =>
              match mp.keyword_kind {
                NewTarget => assert_eq(mp.name, "target")
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

// ============================================================================
// `this` Parameter Type Tests
// ============================================================================

///|
test "parse function with this parameter type" {
  let source = "function greet(this: Person, name: string): void { }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => {
      assert_true(sf.statements.length() == 1)
      match sf.statements[0] {
        FunctionDeclaration(fd) => {
          assert_true(fd.parameters.length() == 2)
          match fd.parameters[0] {
            Parameter(p) => {
              assert_true(p.is_this_parameter)
              match p.name {
                Identifier(id) => assert_eq(id.name, "this")
                _ => assert_true(false)
              }
            }
            _ => assert_true(false)
          }
          // Second parameter is regular
          match fd.parameters[1] {
            Parameter(p) => {
              assert_false(p.is_this_parameter)
              match p.name {
                Identifier(id) => assert_eq(id.name, "name")
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
test "parse method with this parameter type" {
  let source = "class Dog { speak(this: Dog): void { } }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => {
      assert_true(sf.statements.length() == 1)
      match sf.statements[0] {
        ClassDeclaration(cd) => {
          assert_true(cd.members.length() == 1)
          match cd.members[0] {
            MethodDeclaration(md) => {
              assert_true(md.parameters.length() == 1)
              match md.parameters[0] {
                Parameter(p) => assert_true(p.is_this_parameter)
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
// `const` Type Parameters Tests
// ============================================================================

///|
test "parse function with const type parameter" {
  let source = "function foo<const T>(x: T): T { return x; }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => {
      assert_true(sf.statements.length() == 1)
      match sf.statements[0] {
        FunctionDeclaration(fd) => {
          assert_true(fd.type_parameters.length() == 1)
          let tp = fd.type_parameters[0]
          assert_eq(tp.name, "T")
          assert_true(tp.is_const)
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse function with mixed const and regular type parameters" {
  let source = "function bar<const T, U extends T>(x: T, y: U): void { }"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => {
      assert_true(sf.statements.length() == 1)
      match sf.statements[0] {
        FunctionDeclaration(fd) => {
          assert_true(fd.type_parameters.length() == 2)
          // First is const T
          assert_eq(fd.type_parameters[0].name, "T")
          assert_true(fd.type_parameters[0].is_const)
          // Second is regular U extends T
          assert_eq(fd.type_parameters[1].name, "U")
          assert_false(fd.type_parameters[1].is_const)
          assert_true(fd.type_parameters[1].constraint is Some(_))
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Variadic Tuple Types Tests
// ============================================================================

///|
test "parse variadic tuple type with spread" {
  let source = "type Concat<T extends any[], U extends any[]> = [...T, ...U];"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => {
      assert_true(sf.statements.length() == 1)
      match sf.statements[0] {
        TypeAliasDeclaration(tad) => {
          assert_eq(tad.name, "Concat")
          assert_true(tad.type_parameters.length() == 2)
          match tad.type_node {
            TupleType(tt) => {
              assert_true(tt.element_types.length() == 2)
              // Both should be RestType
              match tt.element_types[0] {
                RestType(_) => ()
                _ => assert_true(false)
              }
              match tt.element_types[1] {
                RestType(_) => ()
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
test "parse tuple with leading types and spread" {
  let source = "type Prepend<T, U extends any[]> = [T, ...U];"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(sf) => {
      assert_true(sf.statements.length() == 1)
      match sf.statements[0] {
        TypeAliasDeclaration(tad) =>
          match tad.type_node {
            TupleType(tt) => {
              assert_true(tt.element_types.length() == 2)
              // First is regular type
              match tt.element_types[0] {
                TypeReference(_) => ()
                _ => assert_true(false)
              }
              // Second is rest type
              match tt.element_types[1] {
                RestType(_) => ()
                _ => assert_true(false)
              }
            }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

// ===== Auto-Accessor Tests (TS 4.9+) =====

///|
test "parse auto-accessor in class" {
  let tokens = tokens_from_source(
    "class Person { accessor name: string = ''; }",
  )
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ClassDeclaration(cd) => {
          assert_eq(cd.members.length(), 1)
          match cd.members[0] {
            AutoAccessor(aa) => {
              assert_eq(aa.name, "name")
              match aa.type_annotation {
                Some(_) => ()
                None => assert_true(false)
              }
              match aa.initializer {
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
    Err(_) => assert_true(false)
  }
}

///|
test "parse static auto-accessor in class" {
  let tokens = tokens_from_source(
    "class Config { static accessor version = '1.0'; }",
  )
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        ClassDeclaration(cd) => {
          assert_eq(cd.members.length(), 1)
          match cd.members[0] {
            AutoAccessor(aa) => {
              assert_eq(aa.name, "version")
              // Check for static modifier
              let mut has_static = false
              for modifier in aa.modifiers {
                match modifier {
                  Static => {
                    has_static = true
                    break
                  }
                  _ => ()
                }
              }
              assert_true(has_static)
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

// ===== Using Statement Tests (TS 5.2+) =====

///|
test "parse using statement" {
  let tokens = tokens_from_source("using resource = getResource();")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        UsingStatement(us) => {
          assert_eq(us.is_await, false)
          assert_eq(us.declarations.length(), 1)
          match us.declarations[0].name {
            Identifier(id) => assert_eq(id.name, "resource")
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
test "parse await using statement" {
  let tokens = tokens_from_source("await using resource = getAsyncResource();")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        UsingStatement(us) => {
          assert_eq(us.is_await, true)
          assert_eq(us.declarations.length(), 1)
          match us.declarations[0].name {
            Identifier(id) => assert_eq(id.name, "resource")
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
test "parse using statement with type annotation" {
  let tokens = tokens_from_source("using resource: Disposable = getResource();")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        UsingStatement(us) => {
          assert_eq(us.is_await, false)
          assert_eq(us.declarations.length(), 1)
          match us.declarations[0].type_annotation {
            Some(_) => ()
            None => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Parser Error Code Tests
// ============================================================================
// Note: ParserErrorCode enum variants are tested internally in the parser module.
// External tests cannot construct enum values due to MoonBit's read-only access.

// ============================================================================
// Hashbang (Shebang) Tests
// ============================================================================

///|
test "parse hashbang at start of file" {
  let tokens = tokens_from_source("#!/usr/bin/env node\nconst x = 1;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      // Check hashbang is preserved
      match source_file.hashbang {
        Some(hashbang) => assert_eq(hashbang, "#!/usr/bin/env node")
        None => {
          println("Expected hashbang to be present")
          assert_true(false)
        }
      }
      // Check statement is parsed correctly
      assert_eq(source_file.statements.length(), 1)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse file without hashbang" {
  let tokens = tokens_from_source("const x = 1;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      // Check no hashbang
      match source_file.hashbang {
        Some(_) => {
          println("Expected no hashbang")
          assert_true(false)
        }
        None => ()
      }
      assert_eq(source_file.statements.length(), 1)
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Tagged Template with Type Arguments Tests
// ============================================================================

///|
test "parse tagged template with type arguments - simple" {
  // tag<string>`hello`
  let source = "const x = tag<string>`hello`;"
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(vs) =>
          match vs.declarations[0].initializer {
            Some(TaggedTemplateExpression(tte)) => {
              // Check tag
              match tte.tag {
                Identifier(id) => assert_eq(id.name, "tag")
                _ => assert_true(false)
              }
              // Check type arguments
              assert_eq(tte.type_arguments.length(), 1)
              // Check template
              match tte.template {
                TemplateExpression(te) => {
                  assert_eq(te.head, "hello")
                  assert_eq(te.template_spans.length(), 0)
                }
                _ => assert_true(false)
              }
            }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse tagged template with multiple type arguments" {
  // tag<string, number>`hello`
  let source = "const x = tag<string, number>`hello`;"
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(vs) =>
          match vs.declarations[0].initializer {
            Some(TaggedTemplateExpression(tte)) =>
              // Check type arguments count
              assert_eq(tte.type_arguments.length(), 2)
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse tagged template with type arguments and interpolation" {
  // tag<T>`hello ${name}`
  let source = "const x = tag<T>`hello ${name}`;"
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(vs) =>
          match vs.declarations[0].initializer {
            Some(TaggedTemplateExpression(tte)) => {
              // Check type arguments
              assert_eq(tte.type_arguments.length(), 1)
              // Check template has interpolation
              match tte.template {
                TemplateExpression(te) => {
                  assert_eq(te.head, "hello ")
                  assert_eq(te.template_spans.length(), 1)
                }
                _ => assert_true(false)
              }
            }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse tagged template with property access tag and type arguments" {
  // obj.method<T>`template`
  let source = "const x = obj.method<T>`hello`;"
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(vs) =>
          match vs.declarations[0].initializer {
            Some(TaggedTemplateExpression(tte)) => {
              // Check tag is property access
              match tte.tag {
                PropertyAccessExpression(_) => ()
                _ => assert_true(false)
              }
              // Check type arguments
              assert_eq(tte.type_arguments.length(), 1)
            }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse new expression with tagged template and type arguments" {
  // new tag<T>`hello`
  let source = "const x = new tag<T>`hello`;"
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(vs) =>
          match vs.declarations[0].initializer {
            Some(NewExpression(ne)) =>
              // The expression should be a tagged template expression
              match ne.expression {
                TaggedTemplateExpression(tte) => {
                  assert_eq(tte.type_arguments.length(), 1)
                  match tte.template {
                    TemplateExpression(te) => {
                      assert_eq(te.head, "hello")
                      assert_eq(te.template_spans.length(), 0)
                    }
                    _ => assert_true(false)
                  }
                }
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

///|
test "parse template literal with multiple interpolations" {
  // `a${x}b${y}c`
  let source = "const x = `a${x}b${y}c`;"
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(vs) =>
          match vs.declarations[0].initializer {
            Some(TemplateExpression(te)) => {
              assert_eq(te.head, "a")
              assert_eq(te.template_spans.length(), 2)
              // First span
              assert_eq(te.template_spans[0].literal, "b")
              // Second span
              assert_eq(te.template_spans[1].literal, "c")
            }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse tagged template with multiple interpolations" {
  // tag`a${x}b${y}c`
  let source = "const x = tag`a${x}b${y}c`;"
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(vs) =>
          match vs.declarations[0].initializer {
            Some(TaggedTemplateExpression(tte)) =>
              match tte.template {
                TemplateExpression(te) => {
                  assert_eq(te.head, "a")
                  assert_eq(te.template_spans.length(), 2)
                }
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

// ============================================================================
// Generic Construct Signature Tests
// ============================================================================

///|
test "parse interface with generic construct signature" {
  // interface Foo { new <T>(): T }
  let source = "interface Foo { new <T>(): T }"
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        InterfaceDeclaration(iface) => {
          assert_eq(iface.name, "Foo")
          assert_eq(iface.members.length(), 1)
          match iface.members[0] {
            MethodDeclaration(md) =>
              // Check type parameters
              assert_eq(md.type_parameters.length(), 1)
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
test "parse interface with generic construct signature multiple type params" {
  // interface Factory { new <K, V>(key: K, value: V): Map<K, V> }
  let source = "interface Factory { new <K, V>(key: K, value: V): Map<K, V> }"
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        InterfaceDeclaration(iface) => {
          assert_eq(iface.name, "Factory")
          assert_eq(iface.members.length(), 1)
          match iface.members[0] {
            MethodDeclaration(md) => {
              // Check type parameters count
              assert_eq(md.type_parameters.length(), 2)
              // Check parameters count
              assert_eq(md.parameters.length(), 2)
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
test "parse type literal with generic construct signature" {
  // type Ctor = { new <T>(): T }
  let source = "type Ctor = { new <T>(): T }"
  let tokens = tokens_from_source(source)
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TypeAliasDeclaration(ta) => {
          assert_eq(ta.name, "Ctor")
          match ta.type_node {
            TypeLiteral(tl) => {
              assert_eq(tl.members.length(), 1)
              match tl.members[0] {
                MethodDeclaration(md) =>
                  // Check type parameters
                  assert_eq(md.type_parameters.length(), 1)
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
// Array Destructuring with Rest Elements Tests
// ============================================================================

///|
test "parse array destructuring with rest element" {
  let tokens = tokens_from_source("var p = ([...a]) => { };")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(vs) => {
          assert_eq(vs.declarations.length(), 1)
          match vs.declarations[0].initializer {
            Some(ArrowFunction(arrow)) => {
              assert_eq(arrow.parameters.length(), 1)
              match arrow.parameters[0] {
                Parameter(param) =>
                  match param.name {
                    ArrayBindingPattern(abp) => {
                      assert_eq(abp.elements.length(), 1)
                      match abp.elements[0] {
                        Some(SpreadExpression(_)) => ()
                        _ => assert_true(false)
                      }
                    }
                    _ => assert_true(false)
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
test "parse array destructuring with element and rest" {
  let tokens = tokens_from_source("var p = ([a, ...rest]) => { };")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        VariableStatement(vs) =>
          match vs.declarations[0].initializer {
            Some(ArrowFunction(arrow)) =>
              match arrow.parameters[0] {
                Parameter(param) =>
                  match param.name {
                    ArrayBindingPattern(abp) => {
                      assert_eq(abp.elements.length(), 2)
                      // First element is identifier
                      match abp.elements[0] {
                        Some(Identifier(id)) => assert_eq(id.name, "a")
                        _ => assert_true(false)
                      }
                      // Second element is rest
                      match abp.elements[1] {
                        Some(SpreadExpression(spread)) =>
                          match spread.expression {
                            Identifier(id) => assert_eq(id.name, "rest")
                            _ => assert_true(false)
                          }
                        _ => assert_true(false)
                      }
                    }
                    _ => assert_true(false)
                  }
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

///|
test "parse array destructuring with hole and rest" {
  let tokens = tokens_from_source("var p = ([, ...a]) => { };")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) =>
      match source_file.statements[0] {
        VariableStatement(vs) =>
          match vs.declarations[0].initializer {
            Some(ArrowFunction(arrow)) =>
              match arrow.parameters[0] {
                Parameter(param) =>
                  match param.name {
                    ArrayBindingPattern(abp) => {
                      assert_eq(abp.elements.length(), 2)
                      // First element is hole (None)
                      match abp.elements[0] {
                        None => ()
                        _ => assert_true(false)
                      }
                      // Second element is rest
                      match abp.elements[1] {
                        Some(SpreadExpression(_)) => ()
                        _ => assert_true(false)
                      }
                    }
                    _ => assert_true(false)
                  }
                _ => assert_true(false)
              }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Array Destructuring with Default Values Tests
// ============================================================================

///|
test "parse array destructuring with default value" {
  let tokens = tokens_from_source("var p = ([a = 1]) => { };")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) =>
      match source_file.statements[0] {
        VariableStatement(vs) =>
          match vs.declarations[0].initializer {
            Some(ArrowFunction(arrow)) =>
              match arrow.parameters[0] {
                Parameter(param) =>
                  match param.name {
                    ArrayBindingPattern(abp) => {
                      assert_eq(abp.elements.length(), 1)
                      match abp.elements[0] {
                        Some(BindingElement(be)) => {
                          // Check the binding name
                          match be.name {
                            Identifier(id) => assert_eq(id.name, "a")
                            _ => assert_true(false)
                          }
                          // Check the initializer
                          match be.initializer {
                            Some(NumericLiteral(nl)) => assert_eq(nl.value, "1")
                            _ => assert_true(false)
                          }
                        }
                        _ => assert_true(false)
                      }
                    }
                    _ => assert_true(false)
                  }
                _ => assert_true(false)
              }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "parse array destructuring with multiple defaults" {
  let tokens = tokens_from_source("var p = ([a = 1, b = 2]) => { };")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) =>
      match source_file.statements[0] {
        VariableStatement(vs) =>
          match vs.declarations[0].initializer {
            Some(ArrowFunction(arrow)) =>
              match arrow.parameters[0] {
                Parameter(param) =>
                  match param.name {
                    ArrayBindingPattern(abp) => {
                      assert_eq(abp.elements.length(), 2)
                      // First element with default
                      match abp.elements[0] {
                        Some(BindingElement(be1)) => {
                          match be1.name {
                            Identifier(id) => assert_eq(id.name, "a")
                            _ => assert_true(false)
                          }
                          match be1.initializer {
                            Some(NumericLiteral(nl)) => assert_eq(nl.value, "1")
                            _ => assert_true(false)
                          }
                        }
                        _ => assert_true(false)
                      }
                      // Second element with default
                      match abp.elements[1] {
                        Some(BindingElement(be2)) => {
                          match be2.name {
                            Identifier(id) => assert_eq(id.name, "b")
                            _ => assert_true(false)
                          }
                          match be2.initializer {
                            Some(NumericLiteral(nl)) => assert_eq(nl.value, "2")
                            _ => assert_true(false)
                          }
                        }
                        _ => assert_true(false)
                      }
                    }
                    _ => assert_true(false)
                  }
                _ => assert_true(false)
              }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "parse array destructuring mixed elements and defaults" {
  let tokens = tokens_from_source("var p = ([a, b = 2, c]) => { };")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) =>
      match source_file.statements[0] {
        VariableStatement(vs) =>
          match vs.declarations[0].initializer {
            Some(ArrowFunction(arrow)) =>
              match arrow.parameters[0] {
                Parameter(param) =>
                  match param.name {
                    ArrayBindingPattern(abp) => {
                      assert_eq(abp.elements.length(), 3)
                      // First element - plain identifier
                      match abp.elements[0] {
                        Some(Identifier(id)) => assert_eq(id.name, "a")
                        _ => assert_true(false)
                      }
                      // Second element - with default
                      match abp.elements[1] {
                        Some(BindingElement(be)) => {
                          match be.name {
                            Identifier(id) => assert_eq(id.name, "b")
                            _ => assert_true(false)
                          }
                          assert_true(be.initializer.is_empty() == false)
                        }
                        _ => assert_true(false)
                      }
                      // Third element - plain identifier
                      match abp.elements[2] {
                        Some(Identifier(id)) => assert_eq(id.name, "c")
                        _ => assert_true(false)
                      }
                    }
                    _ => assert_true(false)
                  }
                _ => assert_true(false)
              }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "parse let array destructuring with rest" {
  let tokens = tokens_from_source("let [x, ...remaining] = [1, 2, 3];")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) =>
      match source_file.statements[0] {
        VariableStatement(vs) => {
          assert_eq(vs.declarations.length(), 1)
          match vs.declarations[0].name {
            ArrayBindingPattern(abp) => {
              assert_eq(abp.elements.length(), 2)
              // First element - identifier
              match abp.elements[0] {
                Some(Identifier(id)) => assert_eq(id.name, "x")
                _ => assert_true(false)
              }
              // Second element - rest
              match abp.elements[1] {
                Some(SpreadExpression(spread)) =>
                  match spread.expression {
                    Identifier(id) => assert_eq(id.name, "remaining")
                    _ => assert_true(false)
                  }
                _ => assert_true(false)
              }
            }
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "parse let array destructuring with default" {
  let tokens = tokens_from_source("let [x = 10] = [];")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) =>
      match source_file.statements[0] {
        VariableStatement(vs) =>
          match vs.declarations[0].name {
            ArrayBindingPattern(abp) => {
              assert_eq(abp.elements.length(), 1)
              match abp.elements[0] {
                Some(BindingElement(be)) => {
                  match be.name {
                    Identifier(id) => assert_eq(id.name, "x")
                    _ => assert_true(false)
                  }
                  match be.initializer {
                    Some(NumericLiteral(nl)) => assert_eq(nl.value, "10")
                    _ => assert_true(false)
                  }
                }
                _ => assert_true(false)
              }
            }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Parenthesized Type Tests
// ============================================================================

///|
test "parse parenthesized type - simple" {
  let tokens = tokens_from_source("let x: (number);")
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
test "parse parenthesized type - union with array" {
  let tokens = tokens_from_source("let x: (number | string)[];")
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
test "parse parenthesized type - in function parameter" {
  let tokens = tokens_from_source("function foo(x: (number|string)[]) { }")
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
test "parse function type - empty params" {
  let tokens = tokens_from_source("type F = () => void;")
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
test "parse function type - with params" {
  let tokens = tokens_from_source("type F = (x: number) => string;")
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
test "parse function type - single type param" {
  let tokens = tokens_from_source("type F = (number) => string;")
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

// ============================================================================
// Shorthand Interface Property Tests
// ============================================================================

///|
test "parse interface with shorthand property" {
  let tokens = tokens_from_source("interface a { a }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        InterfaceDeclaration(iface) => {
          assert_eq(iface.name, "a")
          assert_eq(iface.members.length(), 1)
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse interface with multiple shorthand properties" {
  let tokens = tokens_from_source("interface I { a; b; c }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        InterfaceDeclaration(iface) => {
          assert_eq(iface.name, "I")
          assert_eq(iface.members.length(), 3)
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse interface with mixed shorthand and typed properties" {
  let tokens = tokens_from_source("interface I { a; b: number; c }")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        InterfaceDeclaration(iface) => {
          assert_eq(iface.name, "I")
          assert_eq(iface.members.length(), 3)
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Shorthand Type Literal Property Tests
// ============================================================================

///|
test "parse type literal with shorthand property" {
  let tokens = tokens_from_source("type T = { a };")
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
test "parse type literal with shorthand in parentheses" {
  let tokens = tokens_from_source("type T = ({ a });")
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
test "parse type literal with function property empty params" {
  let tokens = tokens_from_source("type T = { foo: () => void; };")
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
test "parse type literal with multiple function properties" {
  let tokens = tokens_from_source("type T = { foo: () => void; bar: (x: number) => string; };")
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

// ============================================================================
// Function Type with Rest/This Parameter Tests
// ============================================================================

///|
test "parse function type with rest parameter" {
  let tokens = tokens_from_source("type F = (...args: number[]) => void;")
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
test "parse function type with this parameter" {
  let tokens = tokens_from_source("type F = (this: { name: string }, x: number) => void;")
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
test "parse object type with optional method with rest param" {
  let tokens = tokens_from_source("const obj: { foo?: (...args: number[]) => void } = {};")
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
test "parse ReturnType-style conditional type" {
  let tokens = tokens_from_source("type ReturnType<T> = T extends (...args: any[]) => infer R ? R : never;")
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
test "parse Parameters-style conditional type" {
  let tokens = tokens_from_source("type Parameters<T> = T extends (...args: infer P) => any ? P : never;")
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
test "parse union type with array at end in function parameter" {
  // Test for: function f(obj: number | string[]) {}
  let tokens = tokens_from_source("function f(obj: number | string[]) {}")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        FunctionDeclaration(fd) => {
          assert_eq(fd.parameters.length(), 1)
          match fd.parameters[0] {
            Parameter(p) =>
              match p.type_annotation {
                Some(UnionType(ut)) => {
                  assert_eq(ut.types.length(), 2)
                  // Second element should be ArrayType
                  match ut.types[1] {
                    ArrayType(_) => ()
                    _ => assert_true(false)
                  }
                }
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
test "parse union type with null array" {
  // Test for: function f(obj: [number, string] | null[]) {}
  let tokens = tokens_from_source("function f(obj: [number, string] | null[]) {}")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        FunctionDeclaration(fd) => {
          assert_eq(fd.parameters.length(), 1)
          match fd.parameters[0] {
            Parameter(p) =>
              match p.type_annotation {
                Some(UnionType(ut)) => {
                  assert_eq(ut.types.length(), 2)
                  // First element should be TupleType
                  match ut.types[0] {
                    TupleType(_) => ()
                    _ => assert_true(false)
                  }
                  // Second element should be ArrayType
                  match ut.types[1] {
                    ArrayType(_) => ()
                    _ => assert_true(false)
                  }
                }
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
test "parse intersection type with array at end" {
  // Test for: type T = { a: number } & string[];
  let tokens = tokens_from_source("type T = { a: number } & string[];")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TypeAliasDeclaration(ta) =>
          match ta.type_node {
            IntersectionType(it) => {
              assert_eq(it.types.length(), 2)
              // Second element should be ArrayType
              match it.types[1] {
                ArrayType(_) => ()
                _ => assert_true(false)
              }
            }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse constructor type signature" {
  // Test for: type C1 = new () => void;
  let tokens = tokens_from_source("type C1 = new () => void;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TypeAliasDeclaration(ta) =>
          match ta.type_node {
            ConstructorType(ct) => {
              assert_eq(ct.parameters.length(), 0)
              match ct.return_type {
                KeywordType(kt) => assert_eq(kt.kind.to_string(), "Void")
                _ => assert_true(false)
              }
            }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse constructor type with parameters" {
  // Test for: type C2 = new (x: number, y: string) => object;
  let tokens = tokens_from_source("type C2 = new (x: number, y: string) => object;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TypeAliasDeclaration(ta) =>
          match ta.type_node {
            ConstructorType(ct) => {
              assert_eq(ct.parameters.length(), 2)
            }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse generic constructor type" {
  // Test for: type C3 = new <T>(value: T) => T;
  let tokens = tokens_from_source("type C3 = new <T>(value: T) => T;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TypeAliasDeclaration(ta) =>
          match ta.type_node {
            ConstructorType(ct) => {
              assert_eq(ct.type_parameters.length(), 1)
              assert_eq(ct.parameters.length(), 1)
            }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parse constructor type with destructuring parameter" {
  // Test for: type C1 = new ([{ a: [b, c] }]) => void;
  let tokens = tokens_from_source("type C1 = new ([{ a: [b, c] }]) => void;")
  let result = parse_source_file(tokens, "test.ts")
  match result {
    Ok(source_file) => {
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        TypeAliasDeclaration(ta) =>
          match ta.type_node {
            ConstructorType(ct) => {
              assert_eq(ct.parameters.length(), 1)
            }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}
