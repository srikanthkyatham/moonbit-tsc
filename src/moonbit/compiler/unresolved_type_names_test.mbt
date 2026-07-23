// Tests for TS2304 "Cannot find name" reporting on unresolved type
// references in type position (see unresolved_type_names.mbt and
// report_unresolved_type_name in checker.mbt)

///|
/// Helper: type-check source and return all TS2304 diagnostics
fn ts2304_diagnostics(source : String) -> Array[Diagnostic] {
  let tokens = tokens_from_source(source)
  let result = match parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match bind_source_file(source_file) {
        Ok(bound) => check_source_file(bound)
        Err(diagnostics) => Err(diagnostics)
      }
    Err(diagnostics) => Err(diagnostics)
  }
  let diagnostics = match result {
    Ok(typed) => typed.diagnostics
    Err(diags) => diags
  }
  diagnostics.filter(fn(d) { d.code == 2304 })
}

// ============================================================================
// Positive cases: TS2304 must be reported
// ============================================================================

///|
test "TS2304 for unknown type name" {
  let diags = ts2304_diagnostics("var x: Foo;")
  assert_eq(diags.length(), 1)
  assert_eq(diags[0].message, "Cannot find name 'Foo'.")
}

///|
test "TS2304 for misspelled builtin bool" {
  let diags = ts2304_diagnostics("var x: bool;")
  assert_eq(diags.length(), 1)
  assert_eq(diags[0].message, "Cannot find name 'bool'.")
}

///|
test "TS2304 for capitalized Null and Undefined" {
  let diags = ts2304_diagnostics("var x: Null;\nvar y: Undefined;")
  assert_eq(diags.length(), 2)
}

///|
test "TS2304 for unknown generic type name" {
  let diags = ts2304_diagnostics("var x: Wrapper<number>;")
  assert_eq(diags.length(), 1)
  assert_eq(diags[0].message, "Cannot find name 'Wrapper'.")
}

///|
test "TS2304 reported once per location (no duplicates)" {
  let diags = ts2304_diagnostics("var x: Foo;")
  assert_eq(diags.length(), 1)
}

///|
test "TS2304 for unknown names in function signature" {
  let diags = ts2304_diagnostics(
    "function h(a: Baz): Qux { return null as any; }",
  )
  assert_eq(diags.length(), 2)
}

// ============================================================================
// Negative cases: no TS2304 (must not produce false positives)
// ============================================================================

///|
test "no TS2304 for lib global types" {
  let diags = ts2304_diagnostics(
    (
      #|var a: Array<number>;
      #|var p: Promise<string>;
      #|var r: Record<string, number>;
      #|var pt: Partial<Record<string, number>>;
      #|var d: Date;
      #|var re: RegExp;
      #|var e: Error;
      #|var f: Function;
      #|var o: Object;
      #|var ro: ReadonlyArray<number>;
      #|var pk: PropertyKey;
      #|var ta: TemplateStringsArray;
      #|var ab: ArrayBuffer;
      #|var u8: Uint8Array;
      #|var el: HTMLElement;
    ),
  )
  assert_eq(diags.length(), 0)
}

///|
test "no TS2304 for in-scope type parameters" {
  let diags = ts2304_diagnostics(
    (
      #|function f<T>(x: T): T { let y: T = x; return y; }
      #|interface I<T> { x: T; f(y: T): T; m<U>(z: U): U; }
      #|type A<T> = T[];
      #|type Cond<T> = T extends Array<infer E> ? E : never;
      #|type M<T> = { [K in keyof T]: T[K] };
      #|class C<T> { v: T; constructor(v: T) { this.v = v; } }
      #|declare function df<T>(x: T): T;
    ),
  )
  assert_eq(diags.length(), 0)
}

///|
test "no TS2304 for forward-referenced declarations" {
  let diags = ts2304_diagnostics(
    (
      #|var fwd: Later;
      #|interface Later { a: number; }
      #|var fwdc: LaterClass;
      #|class LaterClass { b: number = 1; }
      #|var fwda: LaterAlias;
      #|type LaterAlias = string;
      #|var fwde: LaterEnum;
      #|enum LaterEnum { A, B }
    ),
  )
  assert_eq(diags.length(), 0)
}

///|
test "no TS2304 for imported type names" {
  let diags = ts2304_diagnostics(
    (
      #|import { Thing } from "./other";
      #|import type { OnlyType } from "./other";
      #|import DefaultThing from "./other";
      #|import * as ns from "./other";
      #|var a: Thing;
      #|var b: OnlyType;
      #|var c: DefaultThing;
    ),
  )
  assert_eq(diags.length(), 0)
}

///|
test "no TS2304 for declare global augmentations" {
  let diags = ts2304_diagnostics(
    (
      #|declare global {
      #|  interface GlobalThing { a: number; }
      #|}
      #|var g: GlobalThing;
      #|export {};
    ),
  )
  assert_eq(diags.length(), 0)
}

///|
test "no TS2304 for namespace-local declarations" {
  let diags = ts2304_diagnostics(
    (
      #|namespace NS {
      #|  export interface X { n: number; }
      #|  export var v: X;
      #|}
      #|var nsx: NS.X;
    ),
  )
  assert_eq(diags.length(), 0)
}

///|
test "no TS2304 for shorthand type literal member" {
  // { foo; } means foo: any in tsc, not a reference to a type named foo
  let diags = ts2304_diagnostics("var a: { foo; };\nlet nested: { ki };")
  assert_eq(diags.length(), 0)
}

///|
test "no TS2304 for intrinsic keyword" {
  let diags = ts2304_diagnostics(
    "type MyUppercase<S extends string> = intrinsic;",
  )
  assert_eq(diags.length(), 0)
}

///|
test "no TS2304 for value name used as type (tsc reports TS2749 instead)" {
  let diags = ts2304_diagnostics("var someVar = 1;\nvar x: someVar;")
  assert_eq(diags.length(), 0)
}

// ============================================================================
// collect_declared_type_names unit tests
// ============================================================================

///|
fn collect_names_from_source(source : String) -> @hashset.HashSet[String] {
  let tokens = tokens_from_source(source)
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => collect_declared_type_names(source_file.statements)
    Err(_) => @hashset.HashSet([])
  }
}

///|
test "collect_declared_type_names gathers declarations and type parameters" {
  let names = collect_names_from_source(
    (
      #|interface I<T> { x: T; }
      #|type A<U> = U[];
      #|class C<V> {}
      #|enum E { A }
      #|namespace N { export type Inner = string; }
      #|function f<W>(x: W): W { return x; }
      #|import { Imported } from "./m";
      #|var value = 1;
      #|type Cond<X> = X extends Array<infer R> ? R : never;
      #|type M<Y> = { [K in keyof Y]: Y[K] };
    ),
  )
  for expected in [
    "I", "T", "A", "U", "C", "V", "E", "N", "Inner", "f", "W", "Imported", "value",
    "Cond", "X", "R", "M", "Y", "K",
  ] {
    assert_true(names.contains(expected))
  }
  assert_false(names.contains("NotDeclared"))
}

///|
test "collect_declared_type_names walks nested expressions" {
  let names = collect_names_from_source(
    (
      #|var g = function inner(x: number): number { return x; };
      #|var h = (obj as SomeType);
      #|var k = (x: AType) => x;
    ),
  )
  assert_true(names.contains("g"))
  assert_true(names.contains("inner"))
  assert_true(names.contains("h"))
  assert_true(names.contains("k"))
  assert_true(names.contains("x"))
}
