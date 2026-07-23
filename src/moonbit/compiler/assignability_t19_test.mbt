// T19 assignability tests:
// 1. wrapper object types (Boolean/Number/String/Object) vs primitives
// 2. nominal enum assignability
// 3. strictNullChecks exclusion of undefined/null

///|
/// Collect the diagnostic codes produced for a source snippet
fn t19_diag_codes(source : String) -> Array[Int] {
  match parse_bind_and_check(source) {
    Ok(_) => []
    Err(diags) => diags.map(fn(d) { d.code })
  }
}

// ============================================================================
// Wrapper object -> primitive (TS2322)
// ============================================================================

///|
test "Boolean wrapper is not assignable to boolean primitive" {
  let codes = t19_diag_codes(
    "var x = true;\ndeclare var a: Boolean;\nx = a;",
  )
  assert_eq(codes, [2322])
}

///|
test "Number wrapper is not assignable to number primitive" {
  let codes = t19_diag_codes(
    "var x = 0;\ndeclare var a: Number;\nx = a;",
  )
  assert_eq(codes, [2322])
}

///|
test "String wrapper is not assignable to string primitive" {
  let codes = t19_diag_codes(
    "var x = 'a';\ndeclare var a: String;\nx = a;",
  )
  assert_eq(codes, [2322])
}

///|
test "primitives are assignable to their wrapper object types" {
  let codes = t19_diag_codes(
    "declare var b: Boolean;\ndeclare var n: Number;\ndeclare var s: String;\nb = true;\nn = 1;\ns = 'x';",
  )
  assert_eq(codes, [])
}

///|
test "wrapper-typed values expose primitive properties" {
  let codes = t19_diag_codes(
    "declare var s: String;\nvar len: number = s.length;\ns.charAt(0);",
  )
  assert_eq(codes, [])
}

// ============================================================================
// The global Object type (TS2322 / TS2696)
// ============================================================================

///|
test "type hiding Object.toString with void return is not assignable to Object" {
  let codes = t19_diag_codes(
    "interface I { toString(): void; }\ndeclare var i: I;\ndeclare var o: Object;\no = i;",
  )
  assert_eq(codes, [2322])
}

///|
test "Object is assignable to interface with void-returning toString" {
  let codes = t19_diag_codes(
    "interface I { toString(): void; }\ndeclare var i: I;\ndeclare var o: Object;\ni = o;",
  )
  assert_eq(codes, [])
}

///|
test "Object is not assignable to interface with number-returning toString (TS2696)" {
  let codes = t19_diag_codes(
    "interface I { toString(): number; }\ndeclare var i: I;\ndeclare var o: Object;\ni = o;",
  )
  assert_eq(codes, [2696])
}

///|
test "Object is not assignable to call-signature types" {
  let codes = t19_diag_codes(
    "interface I { (): void; }\ndeclare var i: I;\ndeclare var o: Object;\ni = o;",
  )
  assert_eq(codes, [2322])
}

///|
test "everything ordinary is assignable to Object" {
  let codes = t19_diag_codes(
    "declare var o: Object;\no = 1;\no = 'x';\no = true;\no = {};\no = { a: 1 };",
  )
  assert_eq(codes, [])
}

// ============================================================================
// Enum assignability (nominal)
// ============================================================================

///|
test "another enum's member is not assignable" {
  let codes = t19_diag_codes(
    "enum E { A, B }\nenum F { A }\ndeclare var e: E;\ne = F.A;",
  )
  assert_eq(codes, [2322])
}

///|
test "own enum member and enum value are assignable" {
  let codes = t19_diag_codes(
    "enum E { A, B }\ndeclare var e: E;\ne = E.A;\ne = E.B;\ne = e;",
  )
  assert_eq(codes, [])
}

///|
test "numeric enum is assignable to number and any" {
  let codes = t19_diag_codes(
    "enum E { A }\ndeclare var e: E;\nvar n: number = e;\nvar a: any = e;\nn = E.A;",
  )
  assert_eq(codes, [])
}

///|
test "plain number is assignable to a numeric enum" {
  let codes = t19_diag_codes(
    "enum E { A, B }\ndeclare var e: E;\ndeclare var n: number;\ne = n;",
  )
  assert_eq(codes, [])
}

///|
test "numeric literal matching a member value is assignable to enum" {
  let codes = t19_diag_codes(
    "enum E { A, B }\ndeclare var e: E;\ne = 1;\nvar e2: E = 0;",
  )
  assert_eq(codes, [])
}

///|
test "numeric literal not matching any member is not assignable to enum" {
  let codes = t19_diag_codes(
    "enum E { A, B }\ndeclare var e: E;\ne = 5;\ne = -1;",
  )
  assert_eq(codes, [2322, 2322])
}

///|
test "string and object literals are not assignable to a numeric enum" {
  let codes = t19_diag_codes(
    "enum E { A }\ndeclare var e: E;\ne = '';\ne = {};",
  )
  assert_eq(codes, [2322, 2322])
}

///|
test "enum is not assignable to string or a different class" {
  let codes = t19_diag_codes(
    "enum E { A }\ndeclare var e: E;\nvar s: string = e;",
  )
  assert_eq(codes, [2322])
}

///|
test "enum member type annotation behaves as the enum type" {
  let codes = t19_diag_codes(
    "enum E { A, B }\ndeclare var m: E.A;\ndeclare var e: E;\ne = m;\nm = E.B;\nvar n: number = m;",
  )
  assert_eq(codes, [])
}

// ============================================================================
// strictNullChecks exclusion (TS2322)
// ============================================================================

///|
test "undefined is not assignable to non-nullable types under strict null checks" {
  // strict defaults to ON (matching the conformance baselines)
  let codes = t19_diag_codes(
    "var a: number = 0;\nvar b: string = '';\nvar c: boolean = true;\ndeclare var u: undefined;\na = u;\nb = u;\nc = u;",
  )
  assert_eq(codes, [2322, 2322, 2322])
}

///|
test "null is not assignable to a numeric enum under strict null checks" {
  let codes = t19_diag_codes(
    "enum E { A }\ndeclare var e: E;\ne = null;\ne = undefined;",
  )
  assert_eq(codes, [2322, 2322])
}

///|
test "undefined stays assignable without strict null checks" {
  let codes = t19_diag_codes(
    "// @strict: false\nvar a: number = 0;\ndeclare var u: undefined;\na = u;\na = null;",
  )
  assert_eq(codes, [])
}

///|
test "undefined is assignable to unions containing undefined and to void" {
  let codes = t19_diag_codes(
    "var a: number | undefined = undefined;\nvar b: void = undefined;\ndeclare var u: undefined;\na = u;",
  )
  assert_eq(codes, [])
}

///|
test "optional parameters and properties accept undefined under strict null checks" {
  let codes = t19_diag_codes(
    "function f(x?: number) {}\nf(undefined);\nf();\ninterface I { p?: number }\nvar i: I = { p: undefined };",
  )
  assert_eq(codes, [])
}

///|
test "non-null assertion strips undefined" {
  let codes = t19_diag_codes(
    "declare var u: number | undefined;\nvar n: number = u!;",
  )
  assert_eq(codes, [])
}

// ============================================================================
// Related: TS2352 assertions and trailing-dot numerals
// ============================================================================

///|
test "casting null to void is a suspicious conversion (TS2352)" {
  let codes = t19_diag_codes("var v: void;\nv = <void>null;")
  assert_eq(codes, [2352])
}

///|
test "trailing-dot numeric literals parse" {
  let codes = t19_diag_codes("var a: number = 1.;\nvar b: number = 1.0;")
  assert_eq(codes, [])
}
