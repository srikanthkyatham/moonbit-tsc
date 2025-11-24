// Transformer tests
// Tests TypeScript to JavaScript transformation

///|
/// Helper to transform a single statement
fn transform_stmt(stmt : Node) -> Node {
  let ctx = TransformerContext::default()
  transform(stmt, ctx)
}

///|
/// Helper to parse and get statements for testing
fn parse_source(source : String) -> Array[Node] {
  let tokens = tokens_from_source(source)
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => source_file.statements
    Err(_) => abort("Failed to parse source")
  }
}

///|
/// Test: Transform variable with type annotation - type should be removed
test "transform variable with type" {
  let stmts = parse_source("const x: number = 42;")
  let transformed = transform_stmt(stmts[0])

  match transformed {
    VariableStatement(vs) => {
      let decl = vs.declarations[0]
      match decl.type_annotation {
        None => assert_true(true)
        Some(_) => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
/// Test: Transform function with type annotations
test "transform function with types" {
  let stmts = parse_source("function foo(x: number): string { return \"hello\"; }")

  let transformed = transform_stmt(stmts[0])
  match transformed {
    FunctionDeclaration(fd) => {
      match fd.return_type {
        None => assert_true(true)
        Some(_) => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
/// Test: Transform interface - should be removed
test "transform interface" {
  let stmts = parse_source("interface IFoo { x: number; }")

  // Interface should transform to EmptyStatement
  let transformed = transform_stmt(stmts[0])
  match transformed {
    EmptyStatement(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
/// Test: Transform type alias - should be removed
test "transform type alias" {
  let stmts = parse_source("type Foo = string;")

  // Type alias should transform to EmptyStatement
  let transformed = transform_stmt(stmts[0])
  match transformed {
    EmptyStatement(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
/// Test: Transform enum - should become const object
test "transform enum" {
  let stmts = parse_source("enum Color { Red, Green, Blue }")

  let transformed = transform_stmt(stmts[0])
  match transformed {
    VariableStatement(vs) => {
      assert_true(vs.is_const)
      let decl = vs.declarations[0]
      match decl.initializer {
        Some(ObjectLiteralExpression(ole)) => {
          assert_eq(ole.properties.length(), 3)
        }
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
/// Test: Transform class - basic transformation
test "transform class" {
  let stmts = parse_source("class Foo {}")

  let transformed = transform_stmt(stmts[0])
  match transformed {
    ClassDeclaration(cd) => {
      match cd.name {
        Some(Identifier(id)) => assert_eq(id.name, "Foo")
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
/// Test: Transform simple expression - should remain unchanged
test "transform simple expression" {
  let stmts = parse_source("const x = 42;")
  let transformed = transform_stmt(stmts[0])

  match transformed {
    VariableStatement(vs) => {
      let decl = vs.declarations[0]
      match decl.initializer {
        Some(NumericLiteral(nl)) => assert_eq(nl.value, "42")
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
/// Test: Transform array literal - should remain unchanged
test "transform array literal" {
  let stmts = parse_source("const arr = [1, 2, 3];")
  let transformed = transform_stmt(stmts[0])

  match transformed {
    VariableStatement(vs) => {
      let decl = vs.declarations[0]
      match decl.initializer {
        Some(ArrayLiteralExpression(ale)) => {
          assert_eq(ale.elements.length(), 3)
        }
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
/// Test: Transform object literal - should remain unchanged
test "transform object literal" {
  let stmts = parse_source("const obj = { x: 1, y: 2 };")
  let transformed = transform_stmt(stmts[0])

  match transformed {
    VariableStatement(vs) => {
      let decl = vs.declarations[0]
      match decl.initializer {
        Some(ObjectLiteralExpression(ole)) => {
          assert_eq(ole.properties.length(), 2)
        }
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}
