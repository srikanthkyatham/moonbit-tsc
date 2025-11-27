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
        Some(FunctionExpression(fe)) =>
          // Should be function expression with block body
          match fe.body {
            BlockStatement(_) => assert_true(true)
            _ => assert_true(false)
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
    ForStatement(fs) =>
      match fs.initializer {
        Some(VariableStatement(vs)) => {
          // Should be converted to var
          assert_false(vs.is_const)
          assert_false(vs.is_let)
        }
        _ => assert_true(false)
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
    ForStatement(fs) =>
      match fs.initializer {
        Some(VariableStatement(vs)) =>
          // Should preserve let for ES2015+
          assert_true(vs.is_let)
        _ => assert_true(false)
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
    ClassDeclaration(cd) =>
      // Class should remain as ClassDeclaration
      // (Full ES5 downleveling to constructor functions not yet implemented)
      match cd.name {
        Some(Identifier(id)) => assert_eq(id.name, "Foo")
        _ => assert_true(false)
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
        Some(ObjectLiteralExpression(ole)) =>
          assert_eq(ole.properties.length(), 2)
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
/// Test: ES5 target - exponentiation to Math.pow
test "transform exponentiation to Math.pow for ES5" {
  let stmts = parse_source("const result = 2 ** 3;")
  let ctx = TransformerContext::es5()
  let transformed = transform(stmts[0], ctx)
  match transformed {
    VariableStatement(vs) => {
      let decl = vs.declarations[0]
      match decl.initializer {
        Some(CallExpression(ce)) =>
          // Should be converted to Math.pow(2, 3)
          match ce.expression {
            PropertyAccessExpression(pae) => {
              assert_eq(pae.name, "pow")
              match pae.expression {
                Identifier(id) => assert_eq(id.name, "Math")
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

///|
/// Test: ES2016 target - preserves exponentiation operator
test "transform preserves exponentiation for ES2016" {
  let stmts = parse_source("const result = 2 ** 3;")
  let ctx = TransformerContext::es2016()
  let transformed = transform(stmts[0], ctx)
  match transformed {
    VariableStatement(vs) => {
      let decl = vs.declarations[0]
      match decl.initializer {
        Some(BinaryExpression(be)) =>
          // Should preserve ** operator for ES2016+
          match be.operator {
            Exponentiate => assert_true(true)
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
/// Test: ES2015 target - exponentiation downleveled (< ES2016)
test "transform exponentiation to Math.pow for ES2015" {
  let stmts = parse_source("const result = x ** y;")
  let ctx = TransformerContext::es2015()
  let transformed = transform(stmts[0], ctx)
  match transformed {
    VariableStatement(vs) => {
      let decl = vs.declarations[0]
      match decl.initializer {
        Some(CallExpression(ce)) =>
          // Should be converted to Math.pow for ES2015 (< ES2016)
          match ce.expression {
            PropertyAccessExpression(pae) => assert_eq(pae.name, "pow")
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
/// Test: ES2019 target - nullish coalescing to conditional
test "transform nullish coalescing for ES2019" {
  let stmts = parse_source("const result = x ?? y;")
  let ctx = TransformerContext::es2019()
  let transformed = transform(stmts[0], ctx)
  match transformed {
    VariableStatement(vs) => {
      let decl = vs.declarations[0]
      match decl.initializer {
        Some(ConditionalExpression(_)) =>
          // Should be converted to conditional for ES2019 (< ES2020)
          assert_true(true)
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
/// Test: ES2020 target - preserves nullish coalescing
test "transform preserves nullish coalescing for ES2020" {
  let stmts = parse_source("const result = x ?? y;")
  let ctx = TransformerContext::es2020()
  let transformed = transform(stmts[0], ctx)
  match transformed {
    VariableStatement(vs) => {
      let decl = vs.declarations[0]
      match decl.initializer {
        Some(BinaryExpression(be)) =>
          // Should preserve ?? operator for ES2020+
          match be.operator {
            NullishCoalescing => assert_true(true)
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
/// Test: ESNext target - preserves nullish coalescing
test "transform preserves nullish coalescing for ESNext" {
  let stmts = parse_source("const result = a ?? b;")
  let ctx = TransformerContext::esnext()
  let transformed = transform(stmts[0], ctx)
  match transformed {
    VariableStatement(vs) => {
      let decl = vs.declarations[0]
      match decl.initializer {
        Some(BinaryExpression(be)) =>
          match be.operator {
            NullishCoalescing => assert_true(true)
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
/// Test: ES2019 target - optional chaining to conditional
test "transform optional chaining for ES2019" {
  let stmts = parse_source("const result = obj?.prop;")
  let ctx = TransformerContext::es2019()
  let transformed = transform(stmts[0], ctx)
  match transformed {
    VariableStatement(vs) => {
      let decl = vs.declarations[0]
      match decl.initializer {
        Some(ConditionalExpression(_)) =>
          // Should be converted to conditional for ES2019 (< ES2020)
          assert_true(true)
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
/// Test: ES2020 target - preserves optional chaining
test "transform preserves optional chaining for ES2020" {
  let stmts = parse_source("const result = obj?.prop;")
  let ctx = TransformerContext::es2020()
  let transformed = transform(stmts[0], ctx)
  match transformed {
    VariableStatement(vs) => {
      let decl = vs.declarations[0]
      match decl.initializer {
        Some(OptionalChain(_)) =>
          // Should preserve ?. for ES2020+
          assert_true(true)
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
/// Test: ES2017 target - preserves exponentiation
test "transform preserves exponentiation for ES2017" {
  let stmts = parse_source("const result = 2 ** 10;")
  let ctx = TransformerContext::es2017()
  let transformed = transform(stmts[0], ctx)
  match transformed {
    VariableStatement(vs) => {
      let decl = vs.declarations[0]
      match decl.initializer {
        Some(BinaryExpression(be)) =>
          match be.operator {
            Exponentiate => assert_true(true)
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
/// Test: ES2018 target - optional chaining downleveled
test "transform optional chaining for ES2018" {
  let stmts = parse_source("const result = foo?.bar;")
  let ctx = TransformerContext::es2018()
  let transformed = transform(stmts[0], ctx)
  match transformed {
    VariableStatement(vs) => {
      let decl = vs.declarations[0]
      match decl.initializer {
        Some(ConditionalExpression(_)) =>
          // Should be downleveled for ES2018 (< ES2020)
          assert_true(true)
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
/// Test: Target ordinal comparison
test "target ordinal values" {
  let es5 = TransformerContext::es5().target
  let es2015 = TransformerContext::es2015().target
  let es2016 = TransformerContext::es2016().target
  let es2017 = TransformerContext::es2017().target
  let es2018 = TransformerContext::es2018().target
  let es2019 = TransformerContext::es2019().target
  let es2020 = TransformerContext::es2020().target
  let esnext = TransformerContext::esnext().target
  assert_true(es5.ordinal() < es2015.ordinal())
  assert_true(es2015.ordinal() < es2016.ordinal())
  assert_true(es2016.ordinal() < es2017.ordinal())
  assert_true(es2017.ordinal() < es2018.ordinal())
  assert_true(es2018.ordinal() < es2019.ordinal())
  assert_true(es2019.ordinal() < es2020.ordinal())
  assert_true(es2020.ordinal() < esnext.ordinal())
}

///|
/// Test: Target supports helper
test "target supports method" {
  let es5 = TransformerContext::es5().target
  let es2015 = TransformerContext::es2015().target
  let es2016 = TransformerContext::es2016().target
  let es2019 = TransformerContext::es2019().target
  let es2020 = TransformerContext::es2020().target
  let esnext = TransformerContext::esnext().target

  // ES5 doesn't support ES2015 features
  assert_false(es5.supports(es2015))
  // ES2015 supports itself
  assert_true(es2015.supports(es2015))
  // ES2020 supports all previous features
  assert_true(es2020.supports(es2015))
  assert_true(es2020.supports(es2016))
  assert_true(es2020.supports(es2019))
  // ESNext supports everything
  assert_true(esnext.supports(es2020))
}

///|
/// Test: Target older_than helper
test "target older_than method" {
  let es5 = TransformerContext::es5().target
  let es2015 = TransformerContext::es2015().target
  let es2016 = TransformerContext::es2016().target
  let es2019 = TransformerContext::es2019().target
  let es2020 = TransformerContext::es2020().target
  let esnext = TransformerContext::esnext().target

  // ES5 is older than all ES2015+
  assert_true(es5.older_than(es2015))
  assert_true(es5.older_than(es2016))
  assert_true(es5.older_than(es2020))
  // ES2015 is older than ES2016 but not ES2015 itself
  assert_false(es2015.older_than(es2015))
  assert_true(es2015.older_than(es2016))
  // ES2019 is older than ES2020
  assert_true(es2019.older_than(es2020))
  // ESNext is not older than anything
  assert_false(esnext.older_than(es2020))
}

// ============================================================================
// String Enum Transformation Tests
// ============================================================================

///|
/// Test: Transform string enum preserves string values
test "transform string enum preserves values" {
  let source =
    #|enum Color {
    #|  Red = "RED",
    #|  Green = "GREEN",
    #|  Blue = "BLUE"
    #|}
  let stmts = parse_source(source)
  let transformed = transform_stmt(stmts[0])
  match transformed {
    VariableStatement(vs) => {
      assert_true(vs.is_const)
      let decl = vs.declarations[0]
      match decl.initializer {
        Some(ObjectLiteralExpression(ole)) => {
          assert_eq(ole.properties.length(), 3)
          // Check that string values are preserved
          match ole.properties[0] {
            PropertyAssignment(name, value, _) => {
              assert_eq(name, "Red")
              match value {
                StringLiteral(sl) => assert_eq(sl.value, "RED")
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

///|
/// Test: Transform mixed numeric and string enum
test "transform mixed enum with string and numeric values" {
  let source =
    #|enum Status {
    #|  Pending = 0,
    #|  Active = "ACTIVE",
    #|  Done = 2
    #|}
  let stmts = parse_source(source)
  let transformed = transform_stmt(stmts[0])
  match transformed {
    VariableStatement(vs) => {
      let decl = vs.declarations[0]
      match decl.initializer {
        Some(ObjectLiteralExpression(ole)) => {
          assert_eq(ole.properties.length(), 3)
          // Check second property is string
          match ole.properties[1] {
            PropertyAssignment(name, value, _) => {
              assert_eq(name, "Active")
              match value {
                StringLiteral(sl) => assert_eq(sl.value, "ACTIVE")
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

// ============================================================================
// Nested Namespace Transformation Tests
// ============================================================================

///|
/// Test: Transform nested namespace
test "transform nested namespace preserves structure" {
  let stmts = parse_source("namespace A.B { const x = 1; }")
  let transformed = transform_stmt(stmts[0])
  match transformed {
    ModuleDeclaration(outer) => {
      assert_eq(outer.name, "A")
      match outer.body {
        Some(ModuleDeclaration(inner)) => {
          assert_eq(inner.name, "B")
          match inner.body {
            Some(BlockStatement(_)) => assert_true(true)
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

// ============================================================================
// Export Assignment Transformation Tests
// ============================================================================

///|
/// Test: Transform export default expression
test "transform export default expression" {
  let stmts = parse_source("export default 42;")
  let transformed = transform_stmt(stmts[0])
  match transformed {
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

///|
/// Test: Transform export default with object literal
test "transform export default object" {
  let stmts = parse_source("export default { name: 'test' };")
  let transformed = transform_stmt(stmts[0])
  match transformed {
    ExportAssignment(ea) => {
      assert_false(ea.is_export_equals)
      match ea.expression {
        ObjectLiteralExpression(_) => assert_true(true)
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

// ============================================================================
// Parameter Properties Transformation Tests
// ============================================================================

///|
/// Test: Transform class with parameter properties generates property declarations
test "transform parameter properties generates properties" {
  let source =
    #|class Person {
    #|  constructor(public name: string, private age: number) {}
    #|}
  let stmts = parse_source(source)
  let transformed = transform_stmt(stmts[0])
  match transformed {
    ClassDeclaration(cd) => {
      // Should have 3 members: 2 properties + 1 constructor
      assert_eq(cd.members.length(), 3)
      // First two should be property declarations
      match cd.members[0] {
        PropertyDeclaration(pd) => assert_eq(pd.name, "name")
        _ => assert_true(false)
      }
      match cd.members[1] {
        PropertyDeclaration(pd) => assert_eq(pd.name, "age")
        _ => assert_true(false)
      }
      // Third should be constructor
      match cd.members[2] {
        ConstructorDeclaration(ctor) => {
          // Constructor should have parameters without access modifiers
          assert_eq(ctor.parameters.length(), 2)
          // Body should contain assignments
          match ctor.body {
            Some(BlockStatement(block)) => {
              // First 2 statements should be assignments
              assert_true(block.statements.length() >= 2)
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

///|
/// Test: Transform readonly parameter property
test "transform readonly parameter property" {
  let source =
    #|class Config {
    #|  constructor(readonly value: number) {}
    #|}
  let stmts = parse_source(source)
  let transformed = transform_stmt(stmts[0])
  match transformed {
    ClassDeclaration(cd) => {
      // Should have 2 members: 1 property + 1 constructor
      assert_eq(cd.members.length(), 2)
      match cd.members[0] {
        PropertyDeclaration(pd) => {
          assert_eq(pd.name, "value")
          // Should have readonly modifier
          let has_readonly = pd.modifiers.iter().any(fn(m) {
            match m {
              Readonly => true
              _ => false
            }
          })
          assert_true(has_readonly)
        }
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

// ============================================================================
// Dynamic Import Tests
// ============================================================================

///|
/// Test: Transform dynamic import preserves expression
test "transform dynamic import" {
  let stmts = parse_source("const m = import('./module.js');")
  let transformed = transform_stmt(stmts[0])
  match transformed {
    VariableStatement(vs) => {
      match vs.declarations[0].initializer {
        Some(ImportExpression(ie)) => {
          match ie.source {
            StringLiteral(sl) => assert_eq(sl.value, "./module.js")
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
/// Test: Transform dynamic import with await
test "transform dynamic import with await" {
  let stmts = parse_source("const m = await import('./async.js');")
  let transformed = transform_stmt(stmts[0])
  match transformed {
    VariableStatement(vs) => {
      match vs.declarations[0].initializer {
        Some(AwaitExpression(ae)) => {
          match ae.expression {
            ImportExpression(ie) => {
              match ie.source {
                StringLiteral(sl) => assert_eq(sl.value, "./async.js")
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

// ============================================================================
// JSX Transformation Tests
// ============================================================================

///|
/// Helper to transform with JSX classic mode
fn transform_jsx_classic(stmt : Node) -> Node {
  let ctx = TransformerContext::with_jsx(ES2015, Classic("React.createElement", "React.Fragment"))
  transform(stmt, ctx)
}

///|
/// Helper to transform with JSX automatic mode
fn transform_jsx_automatic(stmt : Node) -> Node {
  let ctx = TransformerContext::with_jsx(ES2015, Automatic("react"))
  transform(stmt, ctx)
}

///|
/// Helper to parse JSX source
fn parse_jsx_source(source : String) -> Array[Node] {
  let tokens = tokens_from_source(source)
  match parse_source_file(tokens, "test.tsx") {
    Ok(source_file) => source_file.statements
    Err(_) => abort("Failed to parse source")
  }
}

///|
test "JSX classic - simple element" {
  // <div /> -> React.createElement("div", null)
  let stmts = parse_jsx_source("const x = <div />;")
  let transformed = transform_jsx_classic(stmts[0])
  match transformed {
    VariableStatement(vs) => {
      match vs.declarations[0].initializer {
        Some(CallExpression(ce)) => {
          // Should be React.createElement
          match ce.expression {
            PropertyAccessExpression(pae) => {
              assert_eq(pae.name, "createElement")
            }
            _ => assert_true(false)
          }
          // First arg should be "div"
          match ce.arguments[0] {
            StringLiteral(sl) => assert_eq(sl.value, "div")
            _ => assert_true(false)
          }
          // Second arg should be null
          match ce.arguments[1] {
            NullLiteral(_) => assert_true(true)
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
test "JSX classic - element with props" {
  // <div className="foo" /> -> React.createElement("div", { className: "foo" })
  let stmts = parse_jsx_source("const x = <div className=\"foo\" />;")
  let transformed = transform_jsx_classic(stmts[0])
  match transformed {
    VariableStatement(vs) => {
      match vs.declarations[0].initializer {
        Some(CallExpression(ce)) => {
          // Second arg should be an object
          match ce.arguments[1] {
            ObjectLiteralExpression(ole) => {
              assert_eq(ole.properties.length(), 1)
              match ole.properties[0] {
                PropertyAssignment(name, _, _) => assert_eq(name, "className")
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

///|
test "JSX classic - element with children" {
  // <div>Hello</div> -> React.createElement("div", null, "Hello")
  let stmts = parse_jsx_source("const x = <div>Hello</div>;")
  let transformed = transform_jsx_classic(stmts[0])
  match transformed {
    VariableStatement(vs) => {
      match vs.declarations[0].initializer {
        Some(CallExpression(ce)) => {
          // Should have 3 arguments: type, props, child
          assert_true(ce.arguments.length() >= 3)
          // Third arg should be "Hello"
          match ce.arguments[2] {
            StringLiteral(sl) => assert_eq(sl.value, "Hello")
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
test "JSX classic - component (uppercase)" {
  // <MyComponent /> -> React.createElement(MyComponent, null)
  let stmts = parse_jsx_source("const x = <MyComponent />;")
  let transformed = transform_jsx_classic(stmts[0])
  match transformed {
    VariableStatement(vs) => {
      match vs.declarations[0].initializer {
        Some(CallExpression(ce)) => {
          // First arg should be identifier MyComponent (not string)
          match ce.arguments[0] {
            Identifier(id) => assert_eq(id.name, "MyComponent")
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
test "JSX automatic - simple element" {
  // <div /> -> _jsx("div", {})
  let stmts = parse_jsx_source("const x = <div />;")
  let transformed = transform_jsx_automatic(stmts[0])
  match transformed {
    VariableStatement(vs) => {
      match vs.declarations[0].initializer {
        Some(CallExpression(ce)) => {
          // Should be _jsx
          match ce.expression {
            Identifier(id) => assert_eq(id.name, "_jsx")
            _ => assert_true(false)
          }
          // First arg should be "div"
          match ce.arguments[0] {
            StringLiteral(sl) => assert_eq(sl.value, "div")
            _ => assert_true(false)
          }
          // Second arg should be object (props)
          match ce.arguments[1] {
            ObjectLiteralExpression(_) => assert_true(true)
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
test "JSX automatic - with children uses jsxs" {
  // <div><span /><span /></div> -> _jsxs("div", { children: [...] })
  let stmts = parse_jsx_source("const x = <div><span /><span /></div>;")
  let transformed = transform_jsx_automatic(stmts[0])
  match transformed {
    VariableStatement(vs) => {
      match vs.declarations[0].initializer {
        Some(CallExpression(ce)) => {
          // Should be _jsxs for multiple children
          match ce.expression {
            Identifier(id) => assert_eq(id.name, "_jsxs")
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
test "JSX preserve mode - keeps JSX" {
  let ctx = TransformerContext::with_jsx(ES2015, Preserve)
  let stmts = parse_jsx_source("const x = <div />;")
  let transformed = transform(stmts[0], ctx)
  match transformed {
    VariableStatement(vs) => {
      match vs.declarations[0].initializer {
        Some(JsxSelfClosingElement(_)) => assert_true(true)
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}
