// Wave 6 agent A parser-gap regression tests:
// - B8: class-property definite assignment assertion `p!: T` must keep its
//   type annotation and set has_definite_assignment
// - B11a: private-name accessors `get #x()` / `set #x(v)` must parse as
//   GetAccessor / SetAccessor (not as methods)
// - B11b: `{ new (); }` construct-signature members in type literals
// - T21 gap: generic call-signature members `{ <U>(x: U): U }` in type
//   literals (incl. function return position)

///|
/// Parse the source and return the single top-level statement.
fn parse_single_statement(source : String) -> @compiler.Node raise {
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      assert_eq(source_file.parse_diagnostics.length(), 0)
      assert_eq(source_file.statements.length(), 1)
      source_file.statements[0]
    }
    Err(_) => {
      fail("parse should succeed")
    }
  }
}

///|
/// Parse a `var x: {...}` statement and return the type-literal members.
fn parse_type_literal_members(source : String) -> Array[@compiler.Node] raise {
  match parse_single_statement(source) {
    @compiler.VariableStatement(vs) => {
      assert_eq(vs.declarations.length(), 1)
      match vs.declarations[0].type_annotation {
        Some(@compiler.TypeLiteral(tl)) => tl.members
        _ => fail("expected a TypeLiteral annotation")
      }
    }
    _ => fail("expected VariableStatement")
  }
}

///|
/// Parse a class declaration and return its members.
fn parse_class_members_of(source : String) -> Array[@compiler.Node] raise {
  match parse_single_statement(source) {
    @compiler.ClassDeclaration(c) => c.members
    _ => fail("expected ClassDeclaration")
  }
}

// ============================================================================
// B8: definite assignment assertion on class properties
// ============================================================================

///|
test "unit/parser/wave6/b8 - p!: T keeps annotation and sets flag" {
  let members = parse_class_members_of(
    (
      #|class C {
      #|  p!: number;
      #|}
    ),
  )
  assert_eq(members.length(), 1)
  match members[0] {
    @compiler.PropertyDeclaration(prop) => {
      assert_eq(prop.name, "p")
      assert_true(prop.has_definite_assignment)
      assert_true(!prop.is_optional)
      assert_true(prop.type_annotation is Some(_))
    }
    _ => fail("expected PropertyDeclaration")
  }
}

///|
test "unit/parser/wave6/b8 - modifiers + bang keep annotation" {
  let members = parse_class_members_of(
    (
      #|class C {
      #|  static s!: number;
      #|  private q!: string;
      #|}
    ),
  )
  assert_eq(members.length(), 2)
  for member in members {
    match member {
      @compiler.PropertyDeclaration(prop) => {
        assert_true(prop.has_definite_assignment)
        assert_true(prop.type_annotation is Some(_))
      }
      _ => fail("expected PropertyDeclaration")
    }
  }
}

///|
test "unit/parser/wave6/b8 - private name #p!: T" {
  let members = parse_class_members_of(
    (
      #|class C {
      #|  #p!: number;
      #|}
    ),
  )
  assert_eq(members.length(), 1)
  match members[0] {
    @compiler.PropertyDeclaration(prop) => {
      assert_eq(prop.name, "#p")
      assert_true(prop.has_definite_assignment)
      assert_true(prop.type_annotation is Some(_))
    }
    _ => fail("expected PropertyDeclaration")
  }
}

///|
test "unit/parser/wave6/b8 - optional property p?: T keeps annotation" {
  let members = parse_class_members_of(
    (
      #|class C {
      #|  p?: number;
      #|}
    ),
  )
  assert_eq(members.length(), 1)
  match members[0] {
    @compiler.PropertyDeclaration(prop) => {
      assert_eq(prop.name, "p")
      assert_true(prop.is_optional)
      assert_true(!prop.has_definite_assignment)
      assert_true(prop.type_annotation is Some(_))
    }
    _ => fail("expected PropertyDeclaration")
  }
}

// ============================================================================
// B11a: private-name accessors
// ============================================================================

///|
test "unit/parser/wave6/b11a - get/set #x parse as accessors" {
  let members = parse_class_members_of(
    (
      #|class C {
      #|  get #x(): number { return 1; }
      #|  set #x(v: number) { }
      #|}
    ),
  )
  assert_eq(members.length(), 2)
  match members[0] {
    @compiler.GetAccessor(g) => {
      assert_eq(g.name, "#x")
      assert_true(g.return_type is Some(_))
    }
    _ => fail("expected GetAccessor")
  }
  match members[1] {
    @compiler.SetAccessor(s) => assert_eq(s.name, "#x")
    _ => fail("expected SetAccessor")
  }
}

///|
test "unit/parser/wave6/b11a - static get/set #x parse as accessors" {
  let members = parse_class_members_of(
    (
      #|class C {
      #|  static get #x(): number { return 1; }
      #|  static set #x(v: number) { }
      #|}
    ),
  )
  assert_eq(members.length(), 2)
  match members[0] {
    @compiler.GetAccessor(g) => {
      assert_eq(g.name, "#x")
      assert_true(@debug.to_string(g.modifiers).contains("Static"))
    }
    _ => fail("expected GetAccessor")
  }
  match members[1] {
    @compiler.SetAccessor(s) => {
      assert_eq(s.name, "#x")
      assert_true(@debug.to_string(s.modifiers).contains("Static"))
    }
    _ => fail("expected SetAccessor")
  }
}

///|
test "unit/parser/wave6/b11a - decorated private accessors parse" {
  let members = parse_class_members_of(
    (
      #|class C {
      #|  @dec(1) get #m() { return 0; }
      #|  @dec(2) set #m(value) {}
      #|}
    ),
  )
  assert_eq(members.length(), 2)
  match members[0] {
    @compiler.GetAccessor(g) => {
      assert_eq(g.name, "#m")
      assert_eq(g.decorators.length(), 1)
    }
    _ => fail("expected GetAccessor")
  }
  match members[1] {
    @compiler.SetAccessor(s) => {
      assert_eq(s.name, "#m")
      assert_eq(s.decorators.length(), 1)
    }
    _ => fail("expected SetAccessor")
  }
}

// ============================================================================
// B11b: construct signatures in type literals
// ============================================================================

///|
test "unit/parser/wave6/b11b - new () without return type" {
  let members = parse_type_literal_members("var x: { new (); };")
  assert_eq(members.length(), 1)
  match members[0] {
    @compiler.MethodDeclaration(m) => {
      assert_eq(m.name, "new")
      assert_true(m.return_type is None)
    }
    _ => fail("expected construct-signature MethodDeclaration")
  }
}

///|
test "unit/parser/wave6/b11b - new (): T with return type" {
  let members = parse_type_literal_members("var x: { new (): number; };")
  assert_eq(members.length(), 1)
  match members[0] {
    @compiler.MethodDeclaration(m) => {
      assert_eq(m.name, "new")
      assert_true(m.return_type is Some(_))
    }
    _ => fail("expected construct-signature MethodDeclaration")
  }
}

///|
test "unit/parser/wave6/b11b - generic construct signature new <T>(x: T): T" {
  let members = parse_type_literal_members("var x: { new <T>(x: T): T; };")
  assert_eq(members.length(), 1)
  match members[0] {
    @compiler.MethodDeclaration(m) => {
      assert_eq(m.name, "new")
      assert_eq(m.type_parameters.length(), 1)
      assert_eq(m.parameters.length(), 1)
    }
    _ => fail("expected construct-signature MethodDeclaration")
  }
}

///|
test "unit/parser/wave6/b11b - new as plain property name" {
  let members = parse_type_literal_members("var x: { new: number };")
  assert_eq(members.length(), 1)
  match members[0] {
    @compiler.TypeLiteralProperty(p) => {
      assert_eq(p.name, "new")
      assert_true(p.type_node is Some(_))
    }
    _ => fail("expected TypeLiteralProperty")
  }
}

// ============================================================================
// T21 gap: call signatures in type literals
// ============================================================================

///|
test "unit/parser/wave6/t21 - plain call signature (x: number): string" {
  let members = parse_type_literal_members("var x: { (x: number): string };")
  assert_eq(members.length(), 1)
  match members[0] {
    @compiler.MethodDeclaration(m) => {
      assert_eq(m.name, "")
      assert_eq(m.parameters.length(), 1)
      assert_true(m.return_type is Some(_))
    }
    _ => fail("expected call-signature MethodDeclaration")
  }
}

///|
test "unit/parser/wave6/t21 - call signature without return type" {
  let members = parse_type_literal_members("var x: { (); };")
  assert_eq(members.length(), 1)
  match members[0] {
    @compiler.MethodDeclaration(m) => {
      assert_eq(m.name, "")
      assert_true(m.return_type is None)
    }
    _ => fail("expected call-signature MethodDeclaration")
  }
}

///|
test "unit/parser/wave6/t21 - generic call signature <U>(x: U): U" {
  let members = parse_type_literal_members("var x: { <U>(x: U): U };")
  assert_eq(members.length(), 1)
  match members[0] {
    @compiler.MethodDeclaration(m) => {
      assert_eq(m.name, "")
      assert_eq(m.type_parameters.length(), 1)
      assert_eq(m.type_parameters[0].name, "U")
    }
    _ => fail("expected call-signature MethodDeclaration")
  }
}

///|
test "unit/parser/wave6/t21 - method signature without return type" {
  let members = parse_type_literal_members("var x: { m(); };")
  assert_eq(members.length(), 1)
  match members[0] {
    @compiler.MethodDeclaration(m) => {
      assert_eq(m.name, "m")
      assert_true(m.return_type is None)
    }
    _ => fail("expected MethodDeclaration")
  }
}

///|
test "unit/parser/wave6/t21 - generic method signature m<T>(x: T): T" {
  let members = parse_type_literal_members("var x: { m<T>(x: T): T };")
  assert_eq(members.length(), 1)
  match members[0] {
    @compiler.MethodDeclaration(m) => {
      assert_eq(m.name, "m")
      assert_eq(m.type_parameters.length(), 1)
    }
    _ => fail("expected MethodDeclaration")
  }
}

///|
test "unit/parser/wave6/t21 - type literal with call signature in return position" {
  let source =
    #|function f(): { <U>(x: U): U } {
    #|  return null as any;
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      assert_eq(source_file.parse_diagnostics.length(), 0)
      assert_eq(source_file.statements.length(), 1)
      match source_file.statements[0] {
        @compiler.FunctionDeclaration(fd) =>
          match fd.return_type {
            Some(@compiler.TypeLiteral(tl)) => assert_eq(tl.members.length(), 1)
            _ => fail("expected TypeLiteral return type")
          }
        _ => fail("expected FunctionDeclaration")
      }
    }
    Err(_) => fail("parse should succeed")
  }
}

// ============================================================================
// Expression-side generic signatures (discovered alongside T21's gap)
// ============================================================================

///|
test "unit/parser/wave6/expr - generic function expression" {
  match parse_single_statement("var f = function <U>(x: U): U { return x; };") {
    @compiler.VariableStatement(vs) =>
      match vs.declarations[0].initializer {
        Some(@compiler.FunctionExpression(fe)) => {
          assert_eq(fe.type_parameters.length(), 1)
          assert_eq(fe.type_parameters[0].name, "U")
        }
        _ => fail("expected FunctionExpression initializer")
      }
    _ => fail("expected VariableStatement")
  }
}

///|
test "unit/parser/wave6/expr - generic arrow function" {
  match parse_single_statement("var g = <T>(x: T) => x;") {
    @compiler.VariableStatement(vs) =>
      match vs.declarations[0].initializer {
        Some(@compiler.ArrowFunction(af)) => {
          assert_eq(af.type_parameters.length(), 1)
          assert_eq(af.type_parameters[0].name, "T")
          assert_eq(af.parameters.length(), 1)
        }
        _ => fail("expected ArrowFunction initializer")
      }
    _ => fail("expected VariableStatement")
  }
}

///|
test "unit/parser/wave6/expr - angle-bracket type assertion still parses" {
  match parse_single_statement("var a = <any>\"hello\";") {
    @compiler.VariableStatement(vs) =>
      match vs.declarations[0].initializer {
        Some(@compiler.TypeAssertionExpression(_)) => ()
        _ => fail("expected TypeAssertionExpression initializer")
      }
    _ => fail("expected VariableStatement")
  }
}

///|
test "unit/parser/wave6/expr - assertion on parenthesized expr still parses" {
  match parse_single_statement("var a = <number>(1 + 2);") {
    @compiler.VariableStatement(vs) =>
      match vs.declarations[0].initializer {
        Some(@compiler.TypeAssertionExpression(_)) => ()
        _ => fail("expected TypeAssertionExpression initializer")
      }
    _ => fail("expected VariableStatement")
  }
}

///|
test "unit/parser/wave6/recovery - stray at-sign before enum does not panic" {
  // parserErrorRecovery_ClassElement3: a bare `@` that fails to parse into a
  // decorator used to panic (decorators[0] on empty array) when followed by
  // an enum/interface/type/var declaration
  let source =
    #|namespace M {
    #|   @
    #|   enum E {
    #|   }
    #|}
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(_) => () // parsed with recovery
    Err(diagnostics) => assert_true(diagnostics.length() > 0) // graceful errors
  }
}
