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
  let stmts = parse_source(
    "function foo(x: number): string { return \"hello\"; }",
  )
  let transformed = transform_stmt(stmts[0])
  match transformed {
    FunctionDeclaration(fd) =>
      match fd.return_type {
        None => assert_true(true)
        Some(_) => assert_true(false)
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
        Some(ObjectLiteralExpression(ole)) =>
          assert_eq(ole.properties.length(), 3)
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
    ClassDeclaration(cd) =>
      match cd.name {
        Some(Identifier(id)) => assert_eq(id.name, "Foo")
        _ => assert_true(false)
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
        Some(ArrayLiteralExpression(ale)) => assert_eq(ale.elements.length(), 3)
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
        Some(ObjectLiteralExpression(ole)) =>
          assert_eq(ole.properties.length(), 2)
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
/// Test: Transform arrow function without types
test "transform arrow function basic" {
  let stmts = parse_source("const add = (x, y) => x + y;")
  let transformed = transform_stmt(stmts[0])
  match transformed {
    VariableStatement(vs) => {
      let decl = vs.declarations[0]
      match decl.initializer {
        Some(ArrowFunction(af)) => assert_eq(af.parameters.length(), 2)
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
/// Test: Transform for loop
test "transform for loop" {
  let stmts = parse_source("for (let i = 0; i < 10; i++) {}")
  let transformed = transform_stmt(stmts[0])
  match transformed {
    ForStatement(fs) =>
      match fs.initializer {
        Some(VariableStatement(vs)) => assert_true(vs.is_let)
        _ => assert_true(false)
      }
    _ => assert_true(false)
  }
}

///|
/// Test: Transform if statement
test "transform if statement" {
  let stmts = parse_source("if (true) { const x = 1; }")
  let transformed = transform_stmt(stmts[0])
  match transformed {
    IfStatement(if_stmt) =>
      match if_stmt.then_statement {
        BlockStatement(bs) => assert_eq(bs.statements.length(), 1)
        _ => assert_true(false)
      }
    _ => assert_true(false)
  }
}

///|
/// Test: Transform return statement
test "transform return statement" {
  let stmts = parse_source("function test() { return 42; }")
  let transformed = transform_stmt(stmts[0])
  match transformed {
    FunctionDeclaration(fd) =>
      match fd.body {
        Some(BlockStatement(bs)) => {
          assert_eq(bs.statements.length(), 1)
          match bs.statements[0] {
            ReturnStatement(_) => assert_true(true)
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    _ => assert_true(false)
  }
}

///|
/// Test: Transform var declaration
test "transform var declaration" {
  let stmts = parse_source("var x = 10;")
  let transformed = transform_stmt(stmts[0])
  match transformed {
    VariableStatement(vs) => {
      assert_false(vs.is_const)
      assert_false(vs.is_let)
    }
    _ => assert_true(false)
  }
}

///|
/// Test: Transform while loop
test "transform while loop" {
  let stmts = parse_source("while (true) {}")
  let transformed = transform_stmt(stmts[0])
  match transformed {
    WhileStatement(ws) =>
      match ws.condition {
        BooleanLiteral(bl) => assert_eq(bl.value, true)
        _ => assert_true(false)
      }
    _ => assert_true(false)
  }
}

///|
/// Test: Transform binary expression
test "transform binary expression" {
  let stmts = parse_source("const result = 1 + 2;")
  let transformed = transform_stmt(stmts[0])
  match transformed {
    VariableStatement(vs) => {
      let decl = vs.declarations[0]
      match decl.initializer {
        Some(BinaryExpression(be)) =>
          match be.operator {
            Add => assert_true(true)
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
/// Test: Transform call expression
test "transform call expression" {
  let stmts = parse_source("const result = foo();")
  let transformed = transform_stmt(stmts[0])
  match transformed {
    VariableStatement(vs) => {
      let decl = vs.declarations[0]
      match decl.initializer {
        Some(CallExpression(_)) => assert_true(true)
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
/// Test: ES5 target - arrow function to regular function
test "transform arrow function to function for ES5" {
  let stmts = parse_source("const add = (x, y) => x + y;")
  let ctx = TransformerContext::es5()
  let transformed = transform(stmts[0], ctx)
  match transformed {
    VariableStatement(vs) => {
      let decl = vs.declarations[0]
      match decl.initializer {
        Some(FunctionExpression(fe)) =>
          // Should be converted to function expression
          assert_eq(fe.parameters.length(), 2)
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
/// Test: ES5 target - const to var
test "transform const to var for ES5" {
  let stmts = parse_source("const x = 42;")
  let ctx = TransformerContext::es5()
  let transformed = transform(stmts[0], ctx)
  match transformed {
    VariableStatement(vs) => {
      // Should be converted to var (not const)
      assert_false(vs.is_const)
      assert_false(vs.is_let)
    }
    _ => assert_true(false)
  }
}

///|
/// Test: ES5 target - let to var
test "transform let to var for ES5" {
  let stmts = parse_source("let x = 42;")
  let ctx = TransformerContext::es5()
  let transformed = transform(stmts[0], ctx)
  match transformed {
    VariableStatement(vs) => {
      // Should be converted to var (not let)
      assert_false(vs.is_const)
      assert_false(vs.is_let)
    }
    _ => assert_true(false)
  }
}

///|
/// Test: ES2015 target - preserves const
test "transform preserves const for ES2015" {
  let stmts = parse_source("const x = 42;")
  let ctx = TransformerContext::es2015()
  let transformed = transform(stmts[0], ctx)
  match transformed {
    VariableStatement(vs) =>
      // Should preserve const for ES2015+
      assert_true(vs.is_const)
    _ => assert_true(false)
  }
}

///|
/// Test: ES2015 target - preserves arrow function
test "transform preserves arrow function for ES2015" {
  let stmts = parse_source("const add = (x, y) => x + y;")
  let ctx = TransformerContext::es2015()
  let transformed = transform(stmts[0], ctx)
  match transformed {
    VariableStatement(vs) => {
      let decl = vs.declarations[0]
      match decl.initializer {
        Some(ArrowFunction(_)) =>
          // Should remain as arrow function for ES2015+
          assert_true(true)
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
/// Test: ES5 target - arrow function with block body
test "transform arrow function with block body for ES5" {
  let stmts = parse_source("const add = (x, y) => { return x + y; };")
  let ctx = TransformerContext::es5()
  let transformed = transform(stmts[0], ctx)
  match transformed {
    VariableStatement(vs) => {
      let decl = vs.declarations[0]
      match decl.initializer {
        Some(FunctionExpression(fe)) => {
          // Should be function expression with block body
          match fe.body {
            BlockStatement(_) => assert_true(true)
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
/// Test: ES5 target - nested const/let in for loop
test "transform for loop with const for ES5" {
  let stmts = parse_source("for (const i = 0; i < 10; i++) {}")
  let ctx = TransformerContext::es5()
  let transformed = transform(stmts[0], ctx)
  match transformed {
    ForStatement(fs) => {
      match fs.initializer {
        Some(VariableStatement(vs)) => {
          // Should be converted to var
          assert_false(vs.is_const)
          assert_false(vs.is_let)
        }
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
/// Test: ES2015 target - preserves let in for loop
test "transform preserves let in for loop for ES2015" {
  let stmts = parse_source("for (let i = 0; i < 10; i++) {}")
  let ctx = TransformerContext::es2015()
  let transformed = transform(stmts[0], ctx)
  match transformed {
    ForStatement(fs) => {
      match fs.initializer {
        Some(VariableStatement(vs)) => {
          // Should preserve let for ES2015+
          assert_true(vs.is_let)
        }
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
/// Test: Multiple variable declarations ES5
test "transform multiple const declarations for ES5" {
  let stmts = parse_source("const x = 1, y = 2, z = 3;")
  let ctx = TransformerContext::es5()
  let transformed = transform(stmts[0], ctx)
  match transformed {
    VariableStatement(vs) => {
      // All should be converted to var
      assert_false(vs.is_const)
      assert_eq(vs.declarations.length(), 3)
    }
    _ => assert_true(false)
  }
}

///|
/// Test: ES5 target - class should remain but remove type annotations
test "transform class preserves structure for ES5" {
  let stmts = parse_source("class Foo {}")
  let ctx = TransformerContext::es5()
  let transformed = transform(stmts[0], ctx)
  match transformed {
    ClassDeclaration(cd) => {
      // Class should remain as ClassDeclaration
      // (Full ES5 downleveling to constructor functions not yet implemented)
      match cd.name {
        Some(Identifier(id)) => assert_eq(id.name, "Foo")
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
/// Test: Enum transformation preserves for all targets
test "transform enum to const object for all targets" {
  let stmts = parse_source("enum Status { Active, Inactive }")
  let ctx = TransformerContext::es2015()
  let transformed = transform(stmts[0], ctx)
  match transformed {
    VariableStatement(vs) => {
      // Enums always become const objects regardless of target
      assert_true(vs.is_const)
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
