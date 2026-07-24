// Statement-level synchronize-on-error recovery tests (tsc-style).
//
// After the first syntax error in a statement the parser must:
//   1. keep only that first diagnostic (no TS1128/TS1109/TS1005 cascade), and
//   2. skip to the next statement boundary (`;` at depth 0, unmatched `}`,
//      statement-starting keyword at the beginning of a line, or EOF)
// so that one syntax error produces one diagnostic cluster.
//
// Also covers the parse gaps that used to trigger the cascade: object-literal
// member forms (async/generator/literal-named/generic methods), interface and
// type-literal member names, `export =` assignments, keyword-named class
// members, namespace names, and `typeof` qualified names with reserved words.

// ============================================================================
// Core synchronize-on-error behavior
// ============================================================================

///|
test "generator method without name: one TS1003, no cascade" {
  // tsc reports only TS1003 (Identifier expected) at the '*'
  let diags = parse_diags("var v = { *() { } }")
  assert_eq(count_code(diags, 1003), 1)
  assert_false(has_code(diags, 1109))
  assert_false(has_code(diags, 1128))
  assert_eq(diags.length(), 1)
}

///|
test "keyword in object binding pattern: one TS1005, no cascade" {
  let diags = parse_diags("var { while } = { while: 1 }")
  assert_eq(count_code(diags, 1005), 1)
  assert_false(has_code(diags, 1109))
  assert_false(has_code(diags, 1128))
}

///|
test "reserved-word shorthand property: one TS1005, no cascade" {
  let diags = parse_diags("var v = { class };")
  assert_eq(count_code(diags, 1005), 1)
  assert_eq(diags.length(), 1)
}

///|
test "empty parenthesized expression: one TS1109, no cascade" {
  let diags = parse_diags("var v = ()({});")
  assert_eq(count_code(diags, 1109), 1)
  assert_eq(diags.length(), 1)
}

///|
test "bad tuple type: first error kept, later cascade dropped" {
  let diags = parse_diags("var v: [number,,]")
  assert_true(has_code(diags, 1110))
  assert_eq(diags.length(), 1)
}

///|
test "recovery resumes at next statement after failed statement" {
  // The second statement must parse cleanly after synchronization
  let diags = parse_diags("var v = { *() { } }\nvar w: string = \"x\";")
  assert_eq(diags.length(), 1)
  assert_eq(count_code(diags, 1003), 1)
}

///|
test "recovery inside block statement lists" {
  let diags = parse_diags("function f() { var v = { class }; return 1; }")
  assert_eq(count_code(diags, 1005), 1)
  assert_eq(diags.length(), 1)
}

///|
test "recovery inside switch case statement lists" {
  let diags = parse_diags(
    "switch (1) { case 1: var v = { class }; break; case 2: break; }",
  )
  assert_eq(count_code(diags, 1005), 1)
  assert_eq(diags.length(), 1)
}

///|
test "failed variable initializer still binds the declaration" {
  // The var statement keeps its declaration on recovery, so no cascade and
  // exactly one parser error; the next statement parses
  let diags = parse_diags("var v = { *() { } }\nv;")
  assert_eq(diags.length(), 1)
}

// ============================================================================
// export = expression (used to cascade TS1109/TS1128)
// ============================================================================

///|
test "export = identifier parses cleanly" {
  let diags = parse_diags("var x = 1;\nexport = x;")
  assert_eq(diags.length(), 0)
}

///|
test "export = dotted name parses cleanly" {
  let diags = parse_diags("import foo1 = require('./foo1');\nexport = foo1.x;")
  assert_eq(diags.length(), 0)
}

///|
test "export = literal parses cleanly" {
  let diags = parse_diags("export = 42;")
  assert_eq(diags.length(), 0)
}

///|
test "export = async function with import() parses cleanly" {
  let diags = parse_diags(
    "export = async function() {\n  const something = await import(\"./something\");\n};",
  )
  assert_eq(diags.length(), 0)
}

// ============================================================================
// Object-literal member forms (used to cascade)
// ============================================================================

///|
test "async object method parses cleanly" {
  let diags = parse_diags("var o = { async m() { return 1; } };")
  assert_eq(diags.length(), 0)
}

///|
test "async generator object method parses cleanly" {
  let diags = parse_diags("var o = { async *m() { yield 1; } };")
  assert_eq(diags.length(), 0)
}

///|
test "async computed-name object method parses cleanly" {
  let diags = parse_diags("var k = \"m\";\nvar o = { async [k]() { } };")
  assert_eq(diags.length(), 0)
}

///|
test "async as plain property name still works" {
  let diags = parse_diags(
    "var o = { async: 1 };\nvar p = { async };\nvar q = { async() { } };",
  )
  assert_eq(diags.length(), 0)
}

///|
test "string-named object method parses cleanly" {
  let diags = parse_diags("var o = { \"constructor\"() { } };")
  assert_eq(diags.length(), 0)
}

///|
test "numeric-named object method parses cleanly" {
  let diags = parse_diags("var o = { 0() { } };")
  assert_eq(diags.length(), 0)
}

///|
test "generator method with string name parses cleanly" {
  let diags = parse_diags("var o = { *\"g\"() { } };")
  assert_eq(diags.length(), 0)
}

///|
test "generic object method parses cleanly" {
  let diags = parse_diags("var b = { foo<T>(x: T) { return x; } };")
  assert_eq(diags.length(), 0)
}

///|
test "accessors with keyword and literal names parse cleanly" {
  let diags = parse_diags(
    "const c1 = {\n  get constructor() { return },\n  set constructor(value) {}\n};\nvar c2 = { get \"a b\"() { return 1; }, get 0() { return 1; } };",
  )
  assert_eq(diags.length(), 0)
}

///|
test "missing comma between object properties: TS1005 ',' expected" {
  let diags = parse_diags("var b = {\n  \"a b\": 1\n  \"a b\": 2\n};")
  assert_eq(count_code(diags, 1005), 1)
  assert_false(has_code(diags, 1128))
}

///|
test "bare return in object method body parses cleanly" {
  let diags = parse_diags("var v = { get foo() { return } };")
  assert_eq(diags.length(), 0)
}

// ============================================================================
// Interface / type-literal member names (used to cascade)
// ============================================================================

///|
test "interface string-named property signature parses cleanly" {
  let diags = parse_diags("interface I {\n  \"E\";\n}")
  assert_eq(diags.length(), 0)
}

///|
test "interface string-named method signature parses cleanly" {
  let diags = parse_diags("interface I {\n  \"E\"();\n}")
  assert_eq(diags.length(), 0)
}

///|
test "interface numeric-named members parse cleanly" {
  let diags = parse_diags("interface I {\n  0: string;\n  1(): void;\n}")
  assert_eq(diags.length(), 0)
}

///|
test "interface keyword member names with ASI parse cleanly" {
  // Two property signatures named 'protected' and 'p' (tsc: no error)
  let diags = parse_diags("interface I {\n   protected\n   p\n}")
  assert_eq(diags.length(), 0)
}

///|
test "type literal numeric-named members parse cleanly" {
  let diags = parse_diags("var a: {\n  1: number;\n  \"a b\": string;\n}")
  assert_eq(diags.length(), 0)
}

// ============================================================================
// Keyword-named class members and typeof qualified names
// ============================================================================

///|
test "class methods with reserved-word names parse cleanly" {
  let diags = parse_diags(
    "class Controller {\n  create() { }\n  delete() { }\n  var() { }\n}",
  )
  assert_eq(diags.length(), 0)
}

///|
test "typeof qualified name with reserved words parses cleanly" {
  let diags = parse_diags(
    "class C {\n  delete() { }\n}\ninterface I {\n  d: typeof C.prototype.delete;\n}",
  )
  assert_eq(diags.length(), 0)
}

// ============================================================================
// namespace/module names and ASI
// ============================================================================

///|
test "namespace with predefined type name parses cleanly" {
  let diags = parse_diags("namespace number {\n}")
  assert_eq(diags.length(), 0)
}

///|
test "module identifier followed by in-expression is not a declaration" {
  let diags = parse_diags("let module = 10;\nmodule in {}")
  assert_eq(diags.length(), 0)
}

///|
test "bare return before close brace parses cleanly" {
  let diags = parse_diags("function f() { return }")
  assert_eq(diags.length(), 0)
}

///|
test "return with ASI newline keeps no-argument form" {
  let diags = parse_diags("function f() {\n  return\n  1;\n}")
  assert_eq(diags.length(), 0)
}

// ============================================================================
// Statement/expression forms that used to abort the statement
// ============================================================================

///|
test "for-in with predeclared identifier parses cleanly" {
  let diags = parse_diags("let i: string;\nlet a = [1];\nfor (i in a) { }")
  assert_eq(diags.length(), 0)
}

///|
test "for await of parses cleanly" {
  let diags = parse_diags(
    "async function foo(x: any) {\n  for await (const y of x) {}\n}",
  )
  assert_eq(diags.length(), 0)
}

///|
test "for await with async as binding identifier parses cleanly" {
  let diags = parse_diags(
    "async function foo(x: any) {\n  var async;\n  for await (async of x) {}\n}",
  )
  assert_eq(diags.length(), 0)
}

///|
test "new.target with property access parses cleanly" {
  let diags = parse_diags(
    "function f() {\n  if (new.target.marked === true) { }\n}",
  )
  assert_eq(diags.length(), 0)
}

///|
test "import.meta statement parses cleanly" {
  let diags = parse_diags("if (import.meta.foo) {\n  import.meta.foo();\n}")
  assert_eq(diags.length(), 0)
}

///|
test "import equals with keyword binding and qualified keyword name" {
  let diags = parse_diags(
    "declare namespace foo { const await: any; }\nimport await = foo.await;",
  )
  assert_eq(diags.length(), 0)
}

///|
test "class extends call expression parses cleanly" {
  let diags = parse_diags(
    "declare function Ctor<T>(): T;\nclass C1 extends Ctor<number>() { x: string }",
  )
  assert_eq(diags.length(), 0)
}

///|
test "interface member named new parses cleanly" {
  let diags = parse_diags("interface C {\n  foo;\n  new;\n}")
  assert_eq(diags.length(), 0)
}

///|
test "interface construct signature still parses" {
  let diags = parse_diags("interface C {\n  new (x: number): C;\n  new <T>(x: T): C;\n}")
  assert_eq(diags.length(), 0)
}

///|
test "this type in constraints and return types parses cleanly" {
  let diags = parse_diags(
    "declare class B {\n  check<T extends this>(p: T): boolean;\n  self(): this;\n}",
  )
  assert_eq(diags.length(), 0)
}

///|
test "class named with contextual keyword parses cleanly" {
  let diags = parse_diags("class abstract {\n  foo() { return 1; }\n}")
  assert_eq(diags.length(), 0)
}

///|
test "class extends class expression chain parses cleanly" {
  let diags = parse_diags(
    "let C = class extends class extends class { a = 1 } { b = 2 } { c = 3 };",
  )
  assert_eq(diags.length(), 0)
}

///|
test "class extends identifier-name keyword parses cleanly" {
  let diags = parse_diags(
    "declare const await: any;\ndeclare class C extends await {}",
  )
  assert_eq(diags.length(), 0)
}

///|
test "typeof this in type position parses cleanly" {
  let diags = parse_diags(
    "class C {\n  m() {\n    type T = typeof this;\n  }\n}",
  )
  assert_eq(diags.length(), 0)
}

///|
test "parenthesized this type parses cleanly" {
  let diags = parse_diags("interface I {\n  e: (((this)));\n  c: this | Date;\n}")
  assert_eq(diags.length(), 0)
}

///|
test "type predicates in function type return positions" {
  let diags = parse_diags(
    "var g: (x: any) => x is string;\ninterface I {\n  j: (x: any) => x is this;\n}",
  )
  assert_eq(diags.length(), 0)
}

///|
test "qualified type name starting with predefined keyword namespace" {
  let diags = parse_diags(
    "declare namespace string {\n  interface X { }\n}\nvar x: string.X;",
  )
  assert_eq(diags.length(), 0)
}
