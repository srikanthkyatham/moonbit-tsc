///| Unit tests for the noImplicitAny diagnostic family
///| TS7006 (parameter), TS7019 (rest parameter), TS7031 (binding element),
///| TS7008 (member), TS7010/TS7013 (missing return annotation), TS7005 (variable)
///| noImplicitAny defaults ON (strict baseline behavior); disabled by
///| `@noImplicitAny: false` or `@strict: false` directives.

///|
fn nia_diagnostics(source : String) -> Array[@compiler.Diagnostic] {
  match parse_bind_check_errors(source) {
    Ok(_) => []
    Err(diagnostics) => diagnostics
  }
}

///|
fn nia_count(source : String, code : Int) -> Int {
  nia_diagnostics(source).iter().filter(fn(d) { d.code == code }).count()
}

// ============================================================================
// TS7006: Parameter implicitly has an 'any' type
// ============================================================================

test "TS7006: un-annotated function declaration parameter" {
  assert_eq(nia_count("function f(x) { return x; }", 7006), 1)
}

test "TS7006: mixed annotated and un-annotated parameters" {
  let diags = nia_diagnostics("function g(a: number, b) {}")
  assert_eq(diags.iter().filter(fn(d) { d.code == 7006 }).count(), 1)
  assert_true(
    diags.iter().any(fn(d) { d.code == 7006 && d.message.contains("'b'") }),
  )
}

test "TS7006: class method and constructor parameters" {
  let source =
    #|class C {
    #|  m(p) {}
    #|  constructor(q) {}
    #|  ok(r: number) {}
    #|}
  assert_eq(nia_count(source, 7006), 2)
}

test "TS7006: interface method signature parameter" {
  let source =
    #|interface I {
    #|  m(f1, f2: string): void;
    #|}
  assert_eq(nia_count(source, 7006), 1)
}

test "No TS7006: parameter with initializer (type inferred)" {
  assert_eq(nia_count("function f(x = 3) { return x; }", 7006), 0)
}

test "No TS7006: contextually typed callback parameter" {
  // Callback parameters get their types from context; must NOT be flagged
  assert_eq(nia_count("[1, 2, 3].map(v => v + 1);", 7006), 0)
}

test "No TS7006: with @noImplicitAny: false directive" {
  let source =
    #|// @noImplicitAny: false
    #|function f(x) { return x; }
  assert_eq(nia_count(source, 7006), 0)
}

test "No TS7006: with @strict: false directive" {
  let source =
    #|// @strict: false
    #|function f(x) { return x; }
  assert_eq(nia_count(source, 7006), 0)
}

// ============================================================================
// TS7019: Rest parameter implicitly has an 'any[]' type
// ============================================================================

test "TS7019: un-annotated rest parameter" {
  assert_eq(nia_count("function h(...rest) {}", 7019), 1)
}

test "No TS7019: annotated rest parameter" {
  assert_eq(nia_count("function h(...rest: number[]) {}", 7019), 0)
}

// ============================================================================
// TS7031: Binding element implicitly has an 'any' type
// ============================================================================

test "TS7031: object and array destructuring parameters" {
  let diags = nia_diagnostics("function d({a, b}, [c]) {}")
  assert_eq(diags.iter().filter(fn(d) { d.code == 7031 }).count(), 3)
}

test "No TS7031: annotated destructuring parameter" {
  assert_eq(
    nia_count("function d({a, b}: {a: number, b: string}) {}", 7031),
    0,
  )
}

// ============================================================================
// TS7008: Member implicitly has an 'any' type
// ============================================================================

test "TS7008: interface property without type" {
  let source =
    #|interface IFace {
    #|  member1;
    #|  member2: string;
    #|}
  assert_eq(nia_count(source, 7008), 1)
}

test "TS7008: ambient class public member without type" {
  let source =
    #|declare class C {
    #|  publicMember;
    #|  typedMember: string;
    #|}
  assert_eq(nia_count(source, 7008), 1)
}

test "No TS7008: ambient class private member without type" {
  let source =
    #|declare class C {
    #|  private privateMember;
    #|}
  assert_eq(nia_count(source, 7008), 0)
}

test "No TS7008: regular class property (control-flow inferred)" {
  // tsc does not report TS7008 for non-ambient class members
  let source =
    #|class C {
    #|  x = null;
    #|}
  assert_eq(nia_count(source, 7008), 0)
}

// ============================================================================
// TS7010 / TS7013: missing return-type annotation on signatures
// ============================================================================

test "TS7010: interface method without return annotation" {
  let source =
    #|interface IFace {
    #|  funcOfIFace();
    #|}
  assert_eq(nia_count(source, 7010), 1)
}

test "No TS7010: interface method with return annotation" {
  let source =
    #|interface IFace1 {
    #|  f1(): any;
    #|}
  assert_eq(nia_count(source, 7010), 0)
}

test "TS7010: declare function without return annotation" {
  assert_eq(nia_count("declare function df(x: number);", 7010), 1)
}

test "No TS7010: declare function with return annotation" {
  assert_eq(nia_count("declare function df(x: number): void;", 7010), 0)
}

test "No TS7010: regular function without return annotation (inferred)" {
  assert_eq(nia_count("function rf() { return 1; }", 7010), 0)
}

test "TS7013: interface construct signature without return annotation" {
  let source =
    #|interface IFace {
    #|  new ();
    #|}
  assert_eq(nia_count(source, 7013), 1)
}

// ============================================================================
// TS7005: Variable implicitly has an 'any' type
// ============================================================================

test "TS7005: declare var without type annotation" {
  assert_eq(nia_count("declare var foo;", 7005), 1)
}

test "No TS7005: declare var with type annotation" {
  assert_eq(nia_count("declare var foo: number;", 7005), 0)
}

test "No TS7005: regular var without annotation (control-flow typed)" {
  assert_eq(nia_count("var x;", 7005), 0)
}
