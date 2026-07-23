// T18 assignability tests: class-body methods participate in structural
// assignability (TS2322)
// 1. method parameter mismatches between classes are reported
// 2. method-syntax parameters compare bivariantly (narrowing allowed)
// 3. function-property syntax stays strictly checked
// 4. static members stay on the constructor side (never mixed into the
//    instance comparison)
// 5. methods may drop parameters; extra required parameters are rejected
// 6. inherited methods from base classes participate
// 7. recursive class types terminate (no stack overflow)

///|
/// Collect the diagnostic codes produced for a source snippet
fn t18_diag_codes(source : String) -> Array[Int] {
  match parse_bind_and_check(source) {
    Ok(_) => []
    Err(diags) => diags.map(fn(d) { d.code })
  }
}

// ============================================================================
// Method parameter comparison between classes (TS2322)
// ============================================================================

///|
test "class method with incompatible parameter type is not assignable" {
  let codes = t18_diag_codes(
    "class C { foo(x: number) {} }\nclass E { foo(x: string) {} }\ndeclare var e: E;\nlet c: C = e;",
  )
  assert_eq(codes, [2322])
}

///|
test "class method with identical signature is assignable" {
  let codes = t18_diag_codes(
    "class C { foo(x: number) {} }\nclass E { foo(x: number) {} }\ndeclare var e: E;\nlet c: C = e;",
  )
  assert_eq(codes, [])
}

///|
test "class missing a method required by the target is not assignable" {
  let codes = t18_diag_codes(
    "class C { foo(x: number) {} }\nclass E { }\ndeclare var e: E;\nlet c: C = e;",
  )
  assert_eq(codes, [2322])
}

// ============================================================================
// Method bivariance (parameter narrowing allowed for method syntax)
// ============================================================================

///|
test "method parameters compare bivariantly - narrowed parameter allowed" {
  let codes = t18_diag_codes(
    "class Animal { a: number = 1 }\n" +
    "class Dog extends Animal { d: number = 2 }\n" +
    "class C { foo(x: Animal): void {} }\n" +
    "class E { foo(x: Dog): void {} }\n" +
    "declare var e: E;\nlet c: C = e;",
  )
  assert_eq(codes, [])
}

///|
test "method parameters compare bivariantly - widened parameter allowed" {
  let codes = t18_diag_codes(
    "class Animal { a: number = 1 }\n" +
    "class Dog extends Animal { d: number = 2 }\n" +
    "class C { foo(x: Dog): void {} }\n" +
    "class E { foo(x: Animal): void {} }\n" +
    "declare var e: E;\nlet c: C = e;",
  )
  assert_eq(codes, [])
}

///|
test "unrelated method parameter types are incompatible in both directions" {
  let codes = t18_diag_codes(
    "class C { foo(x: number, y: number) {} }\n" +
    "class E { foo(x: number, y?: string) {} }\n" +
    "declare var e: E;\nlet c: C = e;",
  )
  assert_eq(codes, [2322])
}

// ============================================================================
// Parameter arity: dropping is fine, extra required parameters are not
// ============================================================================

///|
test "method may drop parameters" {
  let codes = t18_diag_codes(
    "class C { foo(x: number) {} }\nclass E { foo() {} }\ndeclare var e: E;\nlet c: C = e;",
  )
  assert_eq(codes, [])
}

///|
test "method with extra required parameter is not assignable" {
  let codes = t18_diag_codes(
    "class C { foo() {} }\nclass E { foo(x: number) {} }\ndeclare var e: E;\nlet c: C = e;",
  )
  assert_eq(codes, [2322])
}

///|
test "method with extra optional parameter is assignable" {
  let codes = t18_diag_codes(
    "class C { foo() {} }\nclass E { foo(x?: number) {} }\ndeclare var e: E;\nlet c: C = e;",
  )
  assert_eq(codes, [])
}

// ============================================================================
// Static side vs instance side
// ============================================================================

///|
test "static methods do not participate in instance assignability" {
  let codes = t18_diag_codes(
    "class C { static foo(x: number) {} }\nclass E { }\ndeclare var e: E;\nlet c: C = e;",
  )
  assert_eq(codes, [])
}

///|
test "static method does not satisfy an instance method requirement" {
  let codes = t18_diag_codes(
    "class C { foo(x: number) {} }\nclass E { static foo(x: number) {} }\ndeclare var e: E;\nlet c: C = e;",
  )
  assert_eq(codes, [2322])
}

// ============================================================================
// Inherited methods participate
// ============================================================================

///|
test "method inherited from a base class satisfies the target" {
  let codes = t18_diag_codes(
    "class Base { foo(x: number) {} }\nclass E extends Base { }\n" +
    "class C { foo(x: number) {} }\ndeclare var e: E;\nlet c: C = e;",
  )
  assert_eq(codes, [])
}

///|
test "incompatible method inherited from a base class is reported" {
  let codes = t18_diag_codes(
    "class Base { foo(x: string) {} }\nclass E extends Base { }\n" +
    "class C { foo(x: number) {} }\ndeclare var e: E;\nlet c: C = e;",
  )
  assert_eq(codes, [2322])
}

// ============================================================================
// Recursive class types terminate
// ============================================================================

///|
test "recursive class property types terminate and still report mismatches" {
  let codes = t18_diag_codes(
    "class C { p: C = null as any; x: number = 1 }\n" +
    "class E { p: E = null as any; x: string = 's' }\n" +
    "declare var e: E;\nlet c: C = e;",
  )
  assert_eq(codes, [2322])
}

///|
test "mutually recursive method parameter types are compatible" {
  let codes = t18_diag_codes(
    "class C { foo(x: C): void {} }\nclass E { foo(x: E): void {} }\ndeclare var e: E;\nlet c: C = e;",
  )
  assert_eq(codes, [])
}
